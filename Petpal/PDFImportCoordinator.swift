// PDFImportCoordinator.swift
// Shared import: vet visit (Health) and shelter adoption (Add / Edit pet).
// Supports PDF files, camera photos, and photo library images (Vision OCR → same parsers).

import Combine
import Foundation
import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

enum ShelterImportSheetTarget: Equatable {
    case newPet
    case existingPet(UUID)
}

private enum FileImportPipeline: Equatable {
    case vetVisit
    case shelterNewPet
    case shelterExistingPet(petId: UUID, displayName: String, species: String)
}

/// Delivery path for **Add Visit** (`VetVisitEditorView`): inline form fill instead of `PDFImportReviewView`.
enum AddVisitImportOutcome {
    case parsed(VetRecordParserResponse)
    /// No OCR text, unscannable PDF, or importer/file error — user can enter manually.
    case documentUnreadable
    case pdfReadFailed(String)
    case apiNotConfigured
    /// Parser/network failure; user can call `retryLastExtraction()` while the handler remains installed.
    case apiFailedNeedsRetry
    case imageProcessingFailed(String)
}

@MainActor
final class PDFImportCoordinator: ObservableObject {
    static let shared = PDFImportCoordinator()

    @Published var showFileImporter = false
    @Published var showLoadingSheet = false
    @Published var loadingPrimaryMessage: String = "Reading your document..."
    @Published var showReviewSheet = false
    @Published var showManualVisitSheet = false

    @Published var reviewForm: PDFImportReviewFormState?
    @Published var successToast: String?

    @Published var showShelterReviewSheet = false
    @Published var shelterReviewForm: ShelterImportReviewFormState?
    @Published var shelterSheetTarget: ShelterImportSheetTarget = .newPet

    @Published var showScannedImageAlert = false
    @Published var showAPIFailureAlert = false
    @Published var showJsonManualAlert = false
    @Published var showShelterJsonManualAlert = false
    @Published var showPDFReadAlert = false
    @Published var pdfReadAlertMessage = ""

    @Published var showImagePicker = false
    @Published var imagePickerSource: ImagePickerSource = .camera
    @Published var showImportSourcePicker = false
    @Published var importSourcePickerTitle: String = ""
    @Published var importSourcePickerSubtitle: String = ""
    @Published var showOCRNoTextAlert = false

    #if canImport(UIKit)
    /// Last camera/photo-library image for a **vet visit** import (not used for PDF). Cleared after the visit is saved or the flow is cancelled/fails.
    @Published var sourceImage: UIImage? = nil
    #endif

    /// Bytes of the last vet-visit PDF successfully read (for vaccine certificate source attachments). Cleared when starting a new import or after a successful save path consumes it.
    private(set) var lastVetImportPDFData: Data?

    /// Bytes of the last shelter PDF successfully read. Cleared when starting a shelter import or after `ShelterImportReviewView` consumes it.
    private(set) var lastShelterImportPDFData: Data?

    private var petsForImport: [Pet] = []
    private var lastExtractedText: String?
    private var activePipeline: FileImportPipeline = .vetVisit
    private var lastRetryPipeline: FileImportPipeline = .vetVisit
    private var addVisitFormImportHandler: ((AddVisitImportOutcome) -> Void)?

    private init() {}

    // MARK: - Vet visit (Health)

    func requestPick(pets: [Pet]) {
        addVisitFormImportHandler = nil
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        lastVetImportPDFData = nil
        lastShelterImportPDFData = nil
        activePipeline = .vetVisit
        lastRetryPipeline = .vetVisit
        petsForImport = pets
        importSourcePickerTitle = "Import Vet Record"
        importSourcePickerSubtitle = "Choose how to add your record"
        showImportSourcePicker = true
    }

    /// Opens the three-option import sheet for the Add Visit form; results are delivered to `handler` instead of `PDFImportReviewView`.
    func beginAddVisitImport(pets: [Pet], handler: @escaping (AddVisitImportOutcome) -> Void) {
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        lastVetImportPDFData = nil
        lastShelterImportPDFData = nil
        addVisitFormImportHandler = handler
        activePipeline = .vetVisit
        lastRetryPipeline = .vetVisit
        petsForImport = pets
        importSourcePickerTitle = "Add receipt"
        importSourcePickerSubtitle = "Choose how to add your document"
        showImportSourcePicker = true
    }

    func clearAddVisitImportHandler() {
        addVisitFormImportHandler = nil
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        lastVetImportPDFData = nil
        lastShelterImportPDFData = nil
    }

    private func deliverAddVisit(_ outcome: AddVisitImportOutcome, endImportSession: Bool = true) {
        switch outcome {
        case .parsed, .apiFailedNeedsRetry:
            break
        default:
            #if canImport(UIKit)
            sourceImage = nil
            #endif
        }
        let callback = addVisitFormImportHandler
        if endImportSession { addVisitFormImportHandler = nil }
        callback?(outcome)
    }

    /// Opens the three-option import sheet (photo / library / PDF) for the active pet’s vet record flow.
    func showImportSourceOptionsVetRecord(pets: [Pet]) {
        requestPick(pets: pets)
    }

    func userChoseTakePhotoForImport() {
        showImportSourcePicker = false
        imagePickerSource = .camera
        showImagePicker = true
    }

    func userChosePhotoLibraryForImport() {
        showImportSourcePicker = false
        imagePickerSource = .photoLibrary
        showImagePicker = true
    }

    func userChoseImportPDFFromSheet() {
        showImportSourcePicker = false
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        showFileImporter = true
    }

    func userCancelledImportSourcePicker() {
        showImportSourcePicker = false
        switch activePipeline {
        case .vetVisit:
            clearAddVisitImportHandler()
        case .shelterNewPet, .shelterExistingPet:
            clearShelterImportSnapshot()
        }
    }

    func userCancelledImagePicker() {
        showImagePicker = false
        switch activePipeline {
        case .vetVisit:
            clearAddVisitImportHandler()
        case .shelterNewPet, .shelterExistingPet:
            clearShelterImportSnapshot()
        }
    }

    /// After camera or library returns a `UIImage`, runs Vision OCR then the same parser path as PDF.
    func handleImageSelected(_ image: UIImage) {
        #if canImport(UIKit)
        switch activePipeline {
        case .vetVisit:
            sourceImage = image
            lastVetImportPDFData = nil
        case .shelterNewPet, .shelterExistingPet:
            sourceImage = image
            lastShelterImportPDFData = nil
        }
        #endif
        Task { await processPickedImage(image) }
    }

    #if canImport(UIKit)
    func clearVetVisitSourceImage() {
        sourceImage = nil
    }
    #endif

    func clearShelterImportSnapshot() {
        lastShelterImportPDFData = nil
        #if canImport(UIKit)
        sourceImage = nil
        #endif
    }

    private func processPickedImage(_ image: UIImage) async {
        showImagePicker = false
        switch activePipeline {
        case .vetVisit:
            loadingPrimaryMessage = "Reading your document..."
        case .shelterNewPet, .shelterExistingPet:
            loadingPrimaryMessage = "Reading your records..."
        }
        showLoadingSheet = true
        do {
            let text = try await VisionOCRService.extractText(from: image)
            lastExtractedText = text
            switch activePipeline {
            case .vetVisit:
                await runParseOnly(text: text)
            case .shelterNewPet, .shelterExistingPet:
                await runShelterParseOnly(text: text, pipeline: activePipeline)
            }
        } catch VisionOCRService.OCRError.noTextFound {
            showLoadingSheet = false
            lastShelterImportPDFData = nil
            #if canImport(UIKit)
            switch activePipeline {
            case .vetVisit, .shelterNewPet, .shelterExistingPet:
                sourceImage = nil
            }
            #endif
            if addVisitFormImportHandler != nil {
                deliverAddVisit(.documentUnreadable)
            } else {
                showOCRNoTextAlert = true
            }
        } catch {
            showLoadingSheet = false
            lastShelterImportPDFData = nil
            #if canImport(UIKit)
            switch activePipeline {
            case .vetVisit, .shelterNewPet, .shelterExistingPet:
                sourceImage = nil
            }
            #endif
            if addVisitFormImportHandler != nil {
                deliverAddVisit(.imageProcessingFailed(error.localizedDescription))
            } else {
                pdfReadAlertMessage = error.localizedDescription
                showPDFReadAlert = true
            }
        }
    }

    // MARK: - Shelter (Add / Edit pet)

    func requestShelterPickNewPet() {
        lastShelterImportPDFData = nil
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        activePipeline = .shelterNewPet
        lastRetryPipeline = .shelterNewPet
        petsForImport = []
        importSourcePickerTitle = "Import from Breeder or Rescue"
        importSourcePickerSubtitle = "Choose how to add your record"
        showImportSourcePicker = true
    }

    func requestShelterPickForExistingPet(petId: UUID, displayName: String, species: String) {
        lastShelterImportPDFData = nil
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        activePipeline = .shelterExistingPet(petId: petId, displayName: displayName, species: species)
        lastRetryPipeline = activePipeline
        petsForImport = []
        importSourcePickerTitle = "Import from Breeder or Rescue"
        importSourcePickerSubtitle = "Choose how to add your record"
        showImportSourcePicker = true
    }

    func showImportSourceOptionsShelterNewPet() {
        requestShelterPickNewPet()
    }

    func showImportSourceOptionsShelterExistingPet(petId: UUID, displayName: String, species: String) {
        requestShelterPickForExistingPet(petId: petId, displayName: displayName, species: species)
    }

    func handleFileImporterFinished(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            if addVisitFormImportHandler != nil {
                deliverAddVisit(.pdfReadFailed(error.localizedDescription))
            } else {
                pdfReadAlertMessage = error.localizedDescription
                showPDFReadAlert = true
            }
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await routePickedPDF(url: url) }
        }
    }

    func retryLastExtraction() {
        guard let text = lastExtractedText else { return }
        Task {
            switch lastRetryPipeline {
            case .vetVisit:
                guard ActivePetResolver.resolvedPetId(pets: petsForImport) != nil else { return }
                await runParseOnly(text: text)
            case .shelterNewPet, .shelterExistingPet:
                await runShelterParseOnly(text: text, pipeline: lastRetryPipeline)
            }
        }
    }

    func dismissReviewCanceled() {
        showReviewSheet = false
        reviewForm = nil
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        lastVetImportPDFData = nil
        lastShelterImportPDFData = nil
    }

    func dismissReviewSaved(vaccineCount: Int = 0, medicationReminderCount: Int = 0, messageOverride: String? = nil) {
        showReviewSheet = false
        reviewForm = nil
        if let messageOverride {
            successToast = messageOverride
        } else {
            successToast = Self.visitSavedToastLine(vaccineCount: vaccineCount, medicationReminderCount: medicationReminderCount)
        }
        scheduleClearToast()
    }

    static func visitSavedToastLine(vaccineCount: Int, medicationReminderCount: Int) -> String {
        if vaccineCount == 0 && medicationReminderCount == 0 {
            return "Visit saved ✓"
        }
        var parts: [String] = ["Visit saved"]
        if vaccineCount > 0 {
            parts.append("\(vaccineCount) vaccines added")
        }
        if medicationReminderCount > 0 {
            parts.append("\(medicationReminderCount) reminders created")
        }
        return parts.joined(separator: " · ") + " ✓"
    }

    /// Shown from `VetVisitEditorView` after save (same copy as import review dismiss).
    func presentVisitOutcomeToast(vaccineCount: Int, medicationReminderCount: Int) {
        successToast = Self.visitSavedToastLine(vaccineCount: vaccineCount, medicationReminderCount: medicationReminderCount)
        scheduleClearToast()
    }

    /// Generic success banner (e.g. profile merge after vet import).
    func showTransientSuccessToast(_ message: String) {
        successToast = message
        scheduleClearToast()
    }

    /// Clears PDF snapshot after a successful vet visit save (visit photo already cleared separately).
    func clearVetImportPDFSnapshot() {
        lastVetImportPDFData = nil
    }

    func dismissShelterReviewCanceled() {
        showShelterReviewSheet = false
        shelterReviewForm = nil
        clearShelterImportSnapshot()
    }

    func dismissShelterReviewSavedNewPet() {
        showShelterReviewSheet = false
        shelterReviewForm = nil
        successToast = "Pet profile created from breeder or rescue records ✓"
        scheduleClearToast()
        NotificationCenter.default.post(name: .petpalDismissAddPetAfterShelterImport, object: nil)
    }

    func dismissShelterReviewSavedExistingPet() {
        showShelterReviewSheet = false
        shelterReviewForm = nil
        successToast = "Profile updated from breeder or rescue records ✓"
        scheduleClearToast()
        NotificationCenter.default.post(name: .petpalDismissEditPetAfterShelterImport, object: nil)
    }

    private func scheduleClearToast() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            self?.successToast = nil
        }
    }

    func openManualVisitEntry() {
        showJsonManualAlert = false
        showManualVisitSheet = true
    }

    func dismissManualVisit() {
        showManualVisitSheet = false
    }

    // MARK: - Routing

    private func routePickedPDF(url: URL) async {
        switch activePipeline {
        case .vetVisit:
            await processVetVisitPDF(url: url)
        case .shelterNewPet:
            await processShelterPDF(url: url, pipeline: .shelterNewPet)
        case .shelterExistingPet(let petId, let displayName, let species):
            await processShelterPDF(
                url: url,
                pipeline: .shelterExistingPet(petId: petId, displayName: displayName, species: species)
            )
        }
    }

    private func processVetVisitPDF(url: URL) async {
        #if canImport(UIKit)
        sourceImage = nil
        #endif
        guard let petId = ActivePetResolver.resolvedPetId(pets: petsForImport) else {
            let msg = "Select a pet for the Health tab (banner or pet switcher) before importing a PDF."
            if addVisitFormImportHandler != nil {
                deliverAddVisit(.pdfReadFailed(msg))
            } else {
                pdfReadAlertMessage = msg
                showPDFReadAlert = true
            }
            return
        }

        let petName = FeaturePetScope.currentPetName(pets: petsForImport)
        let species = petsForImport.first(where: { $0.id == petId })?.species ?? "Dog"

        loadingPrimaryMessage = addVisitFormImportHandler != nil ? "Reading your document..." : "Reading your vet record..."
        showLoadingSheet = true
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let extraction = PetpalPDFImporter.extractFullText(from: url)
        guard let text = extraction.text else {
            showLoadingSheet = false
            if addVisitFormImportHandler != nil {
                if extraction.error == .noExtractableText {
                    deliverAddVisit(.documentUnreadable)
                } else if extraction.error == .passwordProtected {
                    deliverAddVisit(.pdfReadFailed("This PDF is password-protected. Remove the password and try again."))
                } else {
                    deliverAddVisit(.pdfReadFailed(extraction.error?.localizedDescription ?? "Could not read this PDF."))
                }
            } else {
                if extraction.error == .noExtractableText {
                    showScannedImageAlert = true
                } else if extraction.error == .passwordProtected {
                    pdfReadAlertMessage = "This PDF is password-protected. Remove the password and try again."
                    showPDFReadAlert = true
                } else {
                    pdfReadAlertMessage = extraction.error?.localizedDescription ?? "Could not read this PDF."
                    showPDFReadAlert = true
                }
            }
            return
        }

        lastExtractedText = text
        lastRetryPipeline = .vetVisit
        if case .vetVisit = activePipeline {
            lastVetImportPDFData = try? Data(contentsOf: url)
        }
        await runParseOnly(text: text, petName: petName, petSpecies: species)
    }

    private func processShelterPDF(url: URL, pipeline: FileImportPipeline) async {
        loadingPrimaryMessage = "Reading your records..."
        showLoadingSheet = true
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }

        let extraction = PetpalPDFImporter.extractFullText(from: url)
        guard let text = extraction.text else {
            showLoadingSheet = false
            if extraction.error == .noExtractableText {
                showScannedImageAlert = true
            } else if extraction.error == .passwordProtected {
                pdfReadAlertMessage = "This PDF is password-protected. Remove the password and try again."
                showPDFReadAlert = true
            } else {
                pdfReadAlertMessage = extraction.error?.localizedDescription ?? "Could not read this PDF."
                showPDFReadAlert = true
            }
            return
        }

        lastExtractedText = text
        lastRetryPipeline = pipeline
        lastShelterImportPDFData = try? Data(contentsOf: url)
        await runShelterParseOnly(text: text, pipeline: pipeline)
    }

    private func runParseOnly(text: String, petName: String? = nil, petSpecies: String? = nil) async {
        showLoadingSheet = true
        if addVisitFormImportHandler != nil {
            loadingPrimaryMessage = "Reading your document..."
        } else {
            loadingPrimaryMessage = "Reading your vet record..."
        }
        let name = petName ?? FeaturePetScope.currentPetName(pets: petsForImport)
        let spec = petSpecies ?? (petsForImport.first { $0.id == ActivePetResolver.resolvedPetId(pets: petsForImport) }?.species ?? "Dog")

        let response = await VetRecordParserService.parse(
            pdfText: text,
            petDisplayName: name,
            petSpecies: spec
        )

        switch response {
        case .failure(let error):
            showLoadingSheet = false
            if addVisitFormImportHandler != nil {
                if case .noAPIConfigured = error {
                    deliverAddVisit(.apiNotConfigured)
                } else {
                    deliverAddVisit(.apiFailedNeedsRetry, endImportSession: false)
                }
                return
            }
            if case .noAPIConfigured = error {
                pdfReadAlertMessage = "Add your Claude API key in Settings (or configure the Vet AI proxy) to import PDFs."
                showPDFReadAlert = true
            } else {
                showAPIFailureAlert = true
            }
        case .success(let envelope):
            showLoadingSheet = false
            if addVisitFormImportHandler != nil {
                deliverAddVisit(.parsed(envelope))
                return
            }
            let shouldShowReview =
                envelope.structuredDecodeSucceeded
                || envelope.result.hasMeaningfulExtractedContent

            if shouldShowReview {
                reviewForm = PDFImportReviewFormState(from: envelope.result)
                showReviewSheet = true
            } else {
                showJsonManualAlert = true
            }
        }
    }

    private func runShelterParseOnly(text: String, pipeline: FileImportPipeline) async {
        showLoadingSheet = true
        loadingPrimaryMessage = "Reading your records..."

        let name: String
        let spec: String
        switch pipeline {
        case .shelterNewPet:
            name = "New pet"
            spec = "Dog"
        case .shelterExistingPet(_, let dn, let sp):
            name = dn.isEmpty ? "Pet" : dn
            spec = sp.isEmpty ? "Dog" : sp
        case .vetVisit:
            name = "Pet"
            spec = "Dog"
        }

        let response = await ShelterRecordParserService.parse(
            pdfText: text,
            petDisplayName: name,
            petSpecies: spec
        )

        switch response {
        case .failure(let error):
            showLoadingSheet = false
            if case .noAPIConfigured = error {
                pdfReadAlertMessage = "Add your Claude API key in Settings (or configure the Vet AI proxy) to import PDFs."
                showPDFReadAlert = true
            } else {
                showAPIFailureAlert = true
            }
        case .success(let envelope):
            showLoadingSheet = false
            let shouldShow =
                envelope.structuredDecodeSucceeded
                || envelope.result.hasMeaningfulExtractedContent

            if shouldShow {
                shelterReviewForm = ShelterImportReviewFormState(from: envelope.result)
                switch pipeline {
                case .shelterNewPet:
                    shelterSheetTarget = .newPet
                case .shelterExistingPet(let petId, _, _):
                    shelterSheetTarget = .existingPet(petId)
                case .vetVisit:
                    shelterSheetTarget = .newPet
                }
                showShelterReviewSheet = true
            } else {
                showShelterJsonManualAlert = true
            }
        }
    }
}

extension Notification.Name {
    /// Posted after shelter import creates a pet so `AddPetView` can dismiss.
    static let petpalDismissAddPetAfterShelterImport = Notification.Name("petpalDismissAddPetAfterShelterImport")
    /// Posted after shelter import updates a pet so `EditPetView` can dismiss.
    static let petpalDismissEditPetAfterShelterImport = Notification.Name("petpalDismissEditPetAfterShelterImport")
}

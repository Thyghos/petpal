// MilestoneGeneratorSheet.swift
// Pick any milestone type and generate a card on demand (manual `MilestoneRecord`).

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import Photos
#endif

#if os(iOS)
struct MilestoneGeneratorPreviewSession: Identifiable {
    let id = UUID()
    let pet: Pet
    let milestoneType: MilestoneType
    let draft: MilestoneRecord
    let selectedPhotoData: Data?
    let restorePhotoPickerForType: MilestoneType?

    enum AfterCommit: Equatable {
        case standard(MilestoneType, photoData: Data?)
        case custom
    }

    let afterCommit: AfterCommit
}

/// Holds `MilestoneGeneratorPreviewSession` on the navigation path so we never rely on a parallel
/// `@State` dictionary — after the photo `fullScreenCover` dismisses, SwiftUI can apply `path` and
/// auxiliary state out of sync, which produced a permanent `ProgressView()` until the sheet reopened.
final class MilestonePreviewSessionBox: Hashable {
    let value: MilestoneGeneratorPreviewSession
    init(_ value: MilestoneGeneratorPreviewSession) { self.value = value }
    static func == (lhs: MilestonePreviewSessionBox, rhs: MilestonePreviewSessionBox) -> Bool { lhs === rhs }
    func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

/// Which picker to show — used as the single `fullScreenCover(item:)` key.
enum PhotoPickerMode: String, Identifiable {
    case library
    case camera
    var id: String { rawValue }
}
#endif

struct MilestoneGeneratorSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    var onFinished: (MilestoneRecord) -> Void
    var onCancel: () -> Void

    @State private var loadingType: MilestoneType?

    #if os(iOS)
    enum Step: Hashable {
        case photoPrompt(MilestoneType)
        case customComposer
        /// Pushed on top of photo prompt or custom composer so “Edit” pops one level only.
        /// Session is carried by reference on `Step` so path and payload cannot desync (see `MilestonePreviewSessionBox`).
        case cardPreview(session: MilestonePreviewSessionBox)
    }

    @State private var path: [Step] = []
    @State private var customTitle = ""
    @State private var customNote = ""
    @State private var customPhoto: UIImage?

    // Single fullScreenCover for ALL picker presentations (avoids nested-sheet bug).
    @State private var activePicker: PhotoPickerMode?
    @State private var pickerIsForCustom = false

    /// Fallback when `path` briefly drops `.photoPrompt` during photo-picker dismiss (before opening preview).
    @State private var photoPromptLockedType: MilestoneType?

    private enum CustomComposerField: Hashable {
        case title
        case note
    }

    @FocusState private var customComposerFocusedField: CustomComposerField?
    #endif

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var activePet: Pet? {
        guard let id = ActivePetResolver.resolvedPetId(pets: sortedPets) else { return nil }
        return sortedPets.first { $0.id == id }
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if activePet == nil {
                    ContentUnavailableView(
                        "Select a pet",
                        systemImage: "pawprint",
                        description: Text("Choose an active pet, then try again.")
                    )
                } else {
                    List {
                        ForEach(MilestoneType.manualGeneratorCases) { type in
                            Button {
                                handleTypeTap(type)
                            } label: {
                                HStack(spacing: 14) {
                                    Text(type.emoji)
                                        .font(.title2)
                                    Text(type.displayName)
                                        .foregroundStyle(Color("BrandDark"))
                                    Spacer(minLength: 8)
                                    if loadingType == type {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .disabled(loadingType != nil)
                        }
                    }
                }
            }
            .navigationTitle("Generate a card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        onCancel()
                        dismiss()
                    }
                }
            }
            #if os(iOS)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .photoPrompt(let type):
                    photoPromptView(for: type)
                case .customComposer:
                    customComposerView
                case .cardPreview(let box):
                    MilestoneGeneratorCardPreviewView(
                        session: box.value,
                        onCreate: {
                            Task { await commitFromPreview(box.value) }
                        },
                        onExit: {
                            // Back → “Generate a card” root inside this sheet (not milestones).
                            exitPreviewToGeneratorRoot()
                        },
                        onEdit: {
                            popPreviewOnly()
                        }
                    )
                    .id(box.value.id)
                }
            }
            #endif
        }
        #if os(iOS)
        .fullScreenCover(item: $activePicker) { mode in
            switch mode {
            case .library:
                ImagePickerView(
                    source: .photoLibrary,
                    onImageSelected: { image in
                        activePicker = nil
                        handlePickedImage(image, forCustom: pickerIsForCustom)
                    },
                    onCancel: {
                        activePicker = nil
                    }
                )
                .ignoresSafeArea()
            case .camera:
                ImagePickerView(
                    source: .camera,
                    onImageSelected: { image in
                        activePicker = nil
                        handlePickedImage(image, forCustom: pickerIsForCustom)
                    },
                    onCancel: {
                        activePicker = nil
                    }
                )
                .ignoresSafeArea()
            }
        }
        #endif
    }

    // MARK: - Pushed views (navigation, not sheets)

    #if os(iOS)
    private func photoPromptView(for type: MilestoneType) -> some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 20)

            Text("Add a photo for this card")
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color("BrandDark"))

            Text("(optional)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                // CHOOSE PHOTO — LEFT
                Button {
                    pickerIsForCustom = false
                    activePicker = .library
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                        Text("Choose Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color("BrandOrange"))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                // TAKE PHOTO — RIGHT
                Button {
                    pickerIsForCustom = false
                    activePicker = .camera
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)
                        Text("Take Photo")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(Color("BrandDark"))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 20)

            Button {
                openStandardPreview(type: type, photoData: nil, pickedUIImage: nil)
            } label: {
                Text("Skip — no photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add Photo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var customComposerView: some View {
        Form {
            Section {
                TextField("What are you celebrating?", text: $customTitle)
                    .focused($customComposerFocusedField, equals: .title)
                    .onChange(of: customTitle) { _, new in
                        if new.count > 40 { customTitle = String(new.prefix(40)) }
                    }
                TextField("Add a note (optional)", text: $customNote, axis: .vertical)
                    .focused($customComposerFocusedField, equals: .note)
                    .lineLimit(2...5)
                    .onChange(of: customNote) { _, new in
                        if new.count > 80 { customNote = String(new.prefix(80)) }
                    }
            } header: {
                Text("Your card")
            }

            Section {
                if let img = customPhoto {
                    HStack {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Spacer()
                        Button("Remove", role: .destructive) {
                            customPhoto = nil
                        }
                        .font(.subheadline)
                    }
                }

                // Each button is its OWN Form row — no shared HStack.
                Button {
                    pickerIsForCustom = true
                    activePicker = .library
                } label: {
                    Label("Choose Photo", systemImage: "photo.on.rectangle.angled")
                }

                Button {
                    pickerIsForCustom = true
                    activePicker = .camera
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                }
            } header: {
                Text("Photo (optional)")
            }

            Section {
                Button {
                    presentCustomPreview()
                } label: {
                    Label("Preview card", systemImage: "rectangle.and.text.magnifyingglass")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .disabled(customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingType != nil)

                Button {
                    Task { await createCustomCard() }
                } label: {
                    Text("Create card without preview")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .disabled(customTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || loadingType != nil)
            } footer: {
                Text("Preview shows the layout before saving. The fun line may update slightly after you create the card.")
                    .font(.caption)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Custom Moment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissCustomComposerKeyboard()
                }
                .font(.body.weight(.semibold))
            }
        }
    }

    // MARK: - Actions

    private func handlePickedImage(_ image: UIImage, forCustom: Bool) {
        if forCustom {
            customPhoto = image
        } else {
            Task { await handleStandardPhotoPicked(image) }
        }
    }

    private func resetCustomForm() {
        dismissCustomComposerKeyboard()
        customTitle = ""
        customNote = ""
        customPhoto = nil
    }

    /// Clears focus + first responder so the form can scroll freely after preview / pickers.
    private func dismissCustomComposerKeyboard() {
        customComposerFocusedField = nil
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func handleTypeTap(_ type: MilestoneType) {
        if type == .custom {
            photoPromptLockedType = nil
            resetCustomForm()
            path.append(.customComposer)
        } else {
            photoPromptLockedType = type
            path.append(.photoPrompt(type))
        }
    }

    @MainActor
    private func handleStandardPhotoPicked(_ image: UIImage) async {
        let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData()
        // Let the picker `fullScreenCover` finish tearing down so `path` / navigation state settle.
        await Task.yield()
        let typeFromPath = path.compactMap({ step -> MilestoneType? in
            if case .photoPrompt(let t) = step { return t }
            return nil
        }).last
        guard let type = typeFromPath ?? photoPromptLockedType else { return }
        openStandardPreview(type: type, photoData: data, pickedUIImage: image)
    }

    private func openStandardPreview(type: MilestoneType, photoData: Data?, pickedUIImage: UIImage?) {
        guard let pet = activePet else { return }
        let draft = makeDraftMilestoneRecord(pet: pet, type: type, photoData: photoData, customTitle: nil, customNote: nil)
        let dataForPreview = photoData ?? pickedUIImage.flatMap { $0.jpegData(compressionQuality: 0.9) ?? $0.pngData() }
        let session = MilestoneGeneratorPreviewSession(
            pet: pet,
            milestoneType: type,
            draft: draft,
            selectedPhotoData: dataForPreview,
            restorePhotoPickerForType: type,
            afterCommit: .standard(type, photoData: photoData)
        )
        pushCardPreviewDestination(session: session)
    }

    private func presentCustomPreview() {
        dismissCustomComposerKeyboard()
        guard let pet = activePet else { return }
        let title = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let photoData = customPhoto.flatMap { $0.jpegData(compressionQuality: 0.9) ?? $0.pngData() }
        let draft = makeDraftMilestoneRecord(pet: pet, type: .custom, photoData: photoData, customTitle: title, customNote: customNote)
        let session = MilestoneGeneratorPreviewSession(
            pet: pet,
            milestoneType: .custom,
            draft: draft,
            selectedPhotoData: photoData,
            restorePhotoPickerForType: nil,
            afterCommit: .custom
        )
        pushCardPreviewDestination(session: session)
    }

    /// Preview is a normal navigation push so “Edit” pops one level (photo prompt or custom composer).
    private func pushCardPreviewDestination(session: MilestoneGeneratorPreviewSession) {
        if case .cardPreview = path.last {
            path.removeLast()
        }
        path.append(.cardPreview(session: MilestonePreviewSessionBox(session)))
    }

    private func popPreviewOnly() {
        dismissCustomComposerKeyboard()
        if case .cardPreview = path.last {
            path.removeLast()
        }
    }

    /// Preview toolbar Back: return to milestone-type list (“Generate a card”), stay in the sheet.
    private func exitPreviewToGeneratorRoot() {
        dismissCustomComposerKeyboard()
        photoPromptLockedType = nil
        path.removeAll()
    }

    @MainActor
    private func commitFromPreview(_ session: MilestoneGeneratorPreviewSession) async {
        popPreviewOnly()
        switch session.afterCommit {
        case .standard(let type, let data):
            await generate(type, photoData: data, customTitle: nil, customNote: nil)
        case .custom:
            await createCustomCard()
        }
    }

    private func makeDraftMilestoneRecord(
        pet: Pet,
        type: MilestoneType,
        photoData: Data?,
        customTitle: String?,
        customNote: String?
    ) -> MilestoneRecord {
        let year = Calendar.current.component(.year, from: Date())
        let displayName = pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Your Pet" : pet.name
        if type == .custom {
            let trimmedNote = (customNote ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let note: String? = trimmedNote.isEmpty ? nil : trimmedNote
            let trimmedTitle = (customTitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return MilestoneRecord(
                petId: pet.id,
                milestoneType: MilestoneType.custom.rawValue,
                triggeredDate: Date(),
                year: year,
                funStatLine: note,
                wasAutoTriggered: false,
                cardPhotoData: photoData,
                customCardTitle: trimmedTitle.isEmpty ? nil : trimmedTitle
            )
        }
        return MilestoneRecord(
            petId: pet.id,
            milestoneType: type.rawValue,
            triggeredDate: Date(),
            year: year,
            funStatLine: MilestoneCardView.fallbackStatLine(for: type, petName: displayName),
            wasAutoTriggered: false,
            cardPhotoData: photoData,
            customCardTitle: nil
        )
    }

    @MainActor
    private func createCustomCard() async {
        guard let pet = activePet else { return }
        let title = customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        loadingType = .custom
        let photoData = customPhoto.flatMap { $0.jpegData(compressionQuality: 0.9) ?? $0.pngData() }
        let record = await MilestoneCheckService.shared.createManualMilestone(
            for: pet,
            type: .custom,
            context: modelContext,
            cardPhotoData: photoData,
            customCardTitle: title,
            customFunStatLine: customNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyString
        )
        loadingType = nil
        resetCustomForm()
        onFinished(record)
        dismiss()
    }
    #endif

    #if !os(iOS)
    private func handleTypeTap(_ type: MilestoneType) {
        Task { await generate(type, photoData: nil, customTitle: nil, customNote: nil) }
    }
    #endif

    private func generate(
        _ type: MilestoneType,
        photoData: Data?,
        customTitle: String?,
        customNote: String?
    ) async {
        guard let pet = activePet else { return }
        loadingType = type
        let record = await MilestoneCheckService.shared.createManualMilestone(
            for: pet,
            type: type,
            context: modelContext,
            cardPhotoData: photoData,
            customCardTitle: customTitle,
            customFunStatLine: customNote
        )
        loadingType = nil
        onFinished(record)
        dismiss()
    }
}

// MARK: - Preview (pushed via navigationDestination)

#if os(iOS)
struct MilestoneGeneratorCardPreviewView: View {
    let session: MilestoneGeneratorPreviewSession
    let onCreate: () -> Void
    /// Returns to the “Generate a card” type list (stays inside the generator sheet).
    let onExit: () -> Void
    /// Pops preview only — back to add-photo / custom form for this card.
    let onEdit: () -> Void

    @Environment(\.displayScale) private var displayScale

    @State private var renderedImage: UIImage?
    @State private var isRendering = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""
    @State private var showSaveAlert = false

    private var selectedUIImage: UIImage? {
        session.selectedPhotoData.flatMap { UIImage(data: $0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ZoomableCardPreview(
                    naturalWidth: 1080,
                    naturalHeight: 1920,
                    pinchHintAppStorageKey: "hasSeenMilestoneGeneratorZoomHint",
                    hintResetToken: session.id
                ) { fitW, fitH in
                    MilestoneCardView(
                        pet: session.pet,
                        milestone: session.milestoneType,
                        record: session.draft,
                        selectedPhoto: selectedUIImage,
                        displayWidth: fitW,
                        displayHeight: fitH
                    )
                    .environment(\.displayScale, displayScale)
                }

                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(Color("BrandDark"))
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Label("Save to Photos", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(Color("BrandDark"))
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(renderedImage == nil && !isRendering)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                Text("For preset milestones, the one-liner may change slightly after you create the card—AI replaces the placeholder.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Preview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Back", action: onExit)
                    .accessibilityHint("Goes to the Generate a card list. Does not return to Milestones.")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create Card", action: onCreate)
            }
        }
        .alert(saveAlertTitle, isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
        .onAppear { scheduleRender() }
    }

    private func scheduleRender() {
        renderedImage = nil
        isRendering = true
        Task { @MainActor in
            let img = MilestoneCardRenderer.snapshot(
                pet: session.pet,
                milestone: session.milestoneType,
                record: session.draft,
                selectedPhoto: selectedUIImage,
                displayScale: displayScale
            )
            renderedImage = img
            isRendering = false
        }
    }

    @MainActor
    private func saveToPhotos() async {
        let image = renderedImage ?? MilestoneCardRenderer.snapshot(
            pet: session.pet,
            milestone: session.milestoneType,
            record: session.draft,
            selectedPhoto: selectedUIImage,
            displayScale: displayScale
        )
        guard let image else { return }

        let status = await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { s in
                continuation.resume(returning: s)
            }
        }
        guard status == .authorized || status == .limited else {
            saveAlertTitle = "Photos Access Needed"
            saveAlertMessage = "Allow Petpal to add photos in Settings to save your milestone card."
            showSaveAlert = true
            return
        }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            HapticManager.shared.success()
            saveAlertTitle = "Saved!"
            saveAlertMessage = "Your milestone card has been saved to your Camera Roll."
            showSaveAlert = true
        } catch {
            saveAlertTitle = "Could Not Save"
            saveAlertMessage = error.localizedDescription
            showSaveAlert = true
        }
    }
}

private extension String {
    var nilIfEmptyString: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
#endif

// MainTabView.swift
// Root tab navigation for Petpal (replaces tile-grid `HomeView` as app root).

import SwiftUI
import SwiftData
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if os(iOS)
import UniformTypeIdentifiers
#endif

/// Drives main `TabView` selection and deep links from the Pet tab into Health (e.g. Reminders).
@MainActor
final class MainTabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
    /// When `true`, `HealthTabView` presents `RemindersView` once after switching to the Health tab.
    @Published var shouldPresentHealthRemindersFromPetTab: Bool = false
    /// When `true`, `HealthTabView` presents `CertificatesView` once after switching to the Health tab.
    @Published var shouldPresentCertificatesFromPetTab: Bool = false

    func openHealthTabReminders() {
        shouldPresentHealthRemindersFromPetTab = true
        selectedTab = 1
    }

    func openHealthTabCertificates() {
        navigateToCertificates()
    }

    /// Pet tab → Health tab, then present `CertificatesView` (e.g. vaccine rows).
    /// Sets the flag before changing tabs so `HealthTabView.onChange(selectedTab:)` sees it.
    func navigateToCertificates() {
        shouldPresentCertificatesFromPetTab = true
        selectedTab = 1
    }
}

struct MainTabView: View {
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @ObservedObject private var pdfImportCoordinator = PDFImportCoordinator.shared
    @StateObject private var tabRouter = MainTabRouter()

    init() {
        #if canImport(UIKit)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = UIColor(Color("BrandOrange"))
        UITabBar.appearance().unselectedItemTintColor = UIColor.secondaryLabel
        #endif
    }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $tabRouter.selectedTab) {
                PetTabView()
                    .tabItem {
                        Label("Pet", systemImage: "pawprint.fill")
                    }
                    .tag(0)

                HealthTabView()
                    .tabItem {
                        Label("Health", systemImage: "cross.fill")
                    }
                    .tag(1)

                VetAIView()
                    .tabItem {
                        Label("Vet AI", systemImage: "stethoscope")
                    }
                    .tag(2)

                HighlightsTabView()
                    .tabItem {
                        Label("Highlights", systemImage: "sparkles")
                    }
                    .tag(3)

                LucysFavoritesView()
                    .tabItem {
                        Label("Deals", systemImage: "tag.fill")
                    }
                    .tag(4)
            }
            .tint(Color("BrandOrange"))
            .environmentObject(tabRouter)

            if let toast = pdfImportCoordinator.successToast {
                Text(toast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color("BrandDark"))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.top, 12)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: pdfImportCoordinator.successToast)
        .sheet(isPresented: $pdfImportCoordinator.showLoadingSheet) {
            PDFImportLoadingView(primaryMessage: pdfImportCoordinator.loadingPrimaryMessage)
                .presentationDetents([.fraction(0.38)])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(true)
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $pdfImportCoordinator.showFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            pdfImportCoordinator.handleFileImporterFinished(result)
        }
        .sheet(isPresented: $pdfImportCoordinator.showImportSourcePicker) {
            ImportSourcePickerSheet(
                title: pdfImportCoordinator.importSourcePickerTitle,
                subtitle: pdfImportCoordinator.importSourcePickerSubtitle,
                onTakePhoto: { pdfImportCoordinator.userChoseTakePhotoForImport() },
                onChooseFromLibrary: { pdfImportCoordinator.userChosePhotoLibraryForImport() },
                onImportPDF: { pdfImportCoordinator.userChoseImportPDFFromSheet() },
                onCancel: { pdfImportCoordinator.userCancelledImportSourcePicker() }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $pdfImportCoordinator.showImagePicker) {
            ImagePickerView(
                source: pdfImportCoordinator.imagePickerSource,
                onImageSelected: { pdfImportCoordinator.handleImageSelected($0) },
                onCancel: { pdfImportCoordinator.userCancelledImagePicker() }
            )
            .ignoresSafeArea()
        }
        .alert("Could not read text from photo", isPresented: $pdfImportCoordinator.showOCRNoTextAlert) {
            Button("OK", role: .cancel) {
                pdfImportCoordinator.showOCRNoTextAlert = false
            }
        } message: {
            Text("Could not read text from this photo. Make sure the document is well-lit and in focus, then try again.")
        }
        #endif
        .sheet(isPresented: $pdfImportCoordinator.showShelterReviewSheet) {
            Group {
                if let form = pdfImportCoordinator.shelterReviewForm {
                    switch pdfImportCoordinator.shelterSheetTarget {
                    case .newPet:
                        ShelterImportReviewView(
                            mode: .createNewPet,
                            initial: form,
                            onCancel: { pdfImportCoordinator.dismissShelterReviewCanceled() },
                            onSuccessNewPet: { pdfImportCoordinator.dismissShelterReviewSavedNewPet() },
                            onSuccessExistingPet: { pdfImportCoordinator.dismissShelterReviewSavedExistingPet() }
                        )
                    case .existingPet(let pid):
                        if let pet = pets.first(where: { $0.id == pid }) {
                            ShelterImportReviewView(
                                mode: .updateExistingPet(pet),
                                initial: form,
                                onCancel: { pdfImportCoordinator.dismissShelterReviewCanceled() },
                                onSuccessNewPet: { pdfImportCoordinator.dismissShelterReviewSavedNewPet() },
                                onSuccessExistingPet: { pdfImportCoordinator.dismissShelterReviewSavedExistingPet() }
                            )
                        } else {
                            ProgressView()
                                .onAppear { pdfImportCoordinator.dismissShelterReviewCanceled() }
                        }
                    }
                } else {
                    ProgressView()
                        .onAppear { pdfImportCoordinator.dismissShelterReviewCanceled() }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $pdfImportCoordinator.showReviewSheet) {
            Group {
                if let form = pdfImportCoordinator.reviewForm,
                   let pid = ActivePetResolver.resolvedPetId(pets: pets) {
                    PDFImportReviewView(
                        petId: pid,
                        initial: form,
                        onCancel: { pdfImportCoordinator.dismissReviewCanceled() },
                        onSaveSuccess: { v, m, messageOverride in
                            pdfImportCoordinator.dismissReviewSaved(
                                vaccineCount: v,
                                medicationReminderCount: m,
                                messageOverride: messageOverride
                            )
                        }
                    )
                } else {
                    ProgressView()
                        .onAppear { pdfImportCoordinator.dismissReviewCanceled() }
                }
            }
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $pdfImportCoordinator.showManualVisitSheet) {
            VetVisitEditorView()
        }
        .alert("This PDF appears to be a scanned image", isPresented: $pdfImportCoordinator.showScannedImageAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This PDF appears to be a scanned image. Text could not be extracted. Try a PDF with selectable text.")
        }
        .alert("Could not read the record.", isPresented: $pdfImportCoordinator.showAPIFailureAlert) {
            Button("Retry") {
                pdfImportCoordinator.showAPIFailureAlert = false
                pdfImportCoordinator.retryLastExtraction()
            }
            Button("OK", role: .cancel) {
                pdfImportCoordinator.showAPIFailureAlert = false
            }
        } message: {
            Text("Check your connection and try again.")
        }
        .alert("Could not parse this record automatically.", isPresented: $pdfImportCoordinator.showJsonManualAlert) {
            Button("Enter manually") {
                pdfImportCoordinator.openManualVisitEntry()
            }
            Button("OK", role: .cancel) {
                pdfImportCoordinator.showJsonManualAlert = false
            }
        } message: {
            Text("You can enter the visit details manually.")
        }
        .alert("Could not parse this record automatically.", isPresented: $pdfImportCoordinator.showShelterJsonManualAlert) {
            Button("OK", role: .cancel) {
                pdfImportCoordinator.showShelterJsonManualAlert = false
            }
        } message: {
            Text("You can fill in the profile manually.")
        }
        .alert("Could not import PDF", isPresented: $pdfImportCoordinator.showPDFReadAlert) {
            Button("OK", role: .cancel) {
                pdfImportCoordinator.showPDFReadAlert = false
            }
        } message: {
            Text(pdfImportCoordinator.pdfReadAlertMessage)
        }
    }
}

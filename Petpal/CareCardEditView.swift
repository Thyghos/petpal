// CareCardEditView.swift
// Customize Card: visibility toggles + optional care-card photo (profile values edited in Edit Pet).

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct CareCardEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    @Bindable var pet: Pet
    let petId: UUID
    @Binding var settings: CareCardFieldSettings

    @State private var draft = CareCardFieldSettings.defaults
    @State private var photoPickRoute: PhotoPickRoute?
    @State private var showPhotoSourceDialog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    fieldSection(title: "Show on card", icon: "eye") {
                        toggleRow(icon: "textformat", title: "Pet name", isOn: $draft.showPetName)
                        rowDivider
                        toggleRow(icon: "leaf", title: "Breed & species", isOn: $draft.showBreed)
                        rowDivider
                        toggleRow(icon: "calendar", title: "Age / date of birth", isOn: $draft.showAge)
                        rowDivider
                        toggleRow(icon: "photo", title: "Profile photo", isOn: $draft.showPhoto)
                        rowDivider
                        toggleRow(icon: "stethoscope", title: "Vet name", isOn: $draft.showVetName)
                        rowDivider
                        toggleRow(icon: "phone", title: "Vet phone", isOn: $draft.showVetPhone)
                        rowDivider
                        toggleRow(icon: "envelope", title: "Vet email", isOn: $draft.showVetEmail)
                        rowDivider
                        toggleRow(icon: "person.fill", title: "Emergency contact name", isOn: $draft.showEmergencyName)
                        rowDivider
                        toggleRow(icon: "phone.fill", title: "Emergency contact phone", isOn: $draft.showEmergencyPhone)
                        rowDivider
                        toggleRow(icon: "scalemass", title: "Weight", isOn: $draft.showWeight)
                        rowDivider
                        toggleRow(icon: "number", title: "Microchip number", isOn: $draft.showMicrochip)
                        rowDivider
                        toggleRow(icon: "scissors", title: "Spayed / neutered", isOn: $draft.showSpayedNeutered)
                        rowDivider
                        toggleRow(icon: "exclamationmark.triangle.fill", title: "Allergies", isOn: $draft.showAllergies)
                        rowDivider
                        toggleRow(icon: "syringe.fill", title: "Vaccines", isOn: $draft.showVaccines)
                        rowDivider
                        toggleRow(icon: "pills.fill", title: "Medications", isOn: $draft.showMedications)
                        rowDivider
                        toggleRow(icon: "calendar", title: "Next vet appointment", isOn: $draft.showNextVetAppointment)
                        rowDivider
                        toggleRow(icon: "paperclip", title: "Attachments", isOn: $draft.showAttachments)
                        rowDivider
                        toggleRow(icon: "note.text", title: "Other / special notes", isOn: $draft.showSpecialNotes)
                        rowDivider
                        toggleRow(icon: "photo.on.rectangle.angled", title: "Care card photo", isOn: $draft.showCareCardPhoto)
                    }

                    careCardPhotoSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Customize Card")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticManager.shared.light()
                        saveAndDismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = settings
            }
            #if os(iOS)
            .confirmationDialog("Add photo", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button("Take Photo") { photoPickRoute = .camera }
                Button("Choose from Library") { photoPickRoute = .library }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(item: $photoPickRoute) { route in
                ImagePickerView(
                    source: route == .camera ? .camera : .photoLibrary,
                    onImageSelected: { image in
                        photoPickRoute = nil
                        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
                        pet.careCardAttachmentImageData = data
                        try? modelContext.save()
                    },
                    onCancel: { photoPickRoute = nil }
                )
                .ignoresSafeArea()
            }
            #endif
        }
    }

    private func saveAndDismiss() {
        settings = draft
        CareCardFieldSettings.save(draft, for: petId)
        dismiss()
    }

    // MARK: - Care card attachment (not profile photo)

    @ViewBuilder
    private var careCardPhotoSection: some View {
        fieldSection(title: "Care card image", icon: "photo.on.rectangle.angled") {
            VStack(alignment: .leading, spacing: 12) {
                #if canImport(UIKit)
                if let data = pet.careCardAttachmentImageData, !data.isEmpty, let ui = UIImage(data: data) {
                    HStack(spacing: 12) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 6) {
                            Button(role: .destructive) {
                                HapticManager.shared.light()
                                pet.careCardAttachmentImageData = nil
                                try? modelContext.save()
                            } label: {
                                Text("Remove Photo")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                }
                #endif

                VStack(spacing: 8) {
                    Button {
                        HapticManager.shared.light()
                        showPhotoSourceDialog = true
                    } label: {
                        Label(
                            pet.careCardAttachmentImageData == nil ? "Add photo" : "Replace photo",
                            systemImage: "plus.circle.fill"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color("BrandDark"))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    @ViewBuilder
    private func fieldSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ModernSectionHeader(title, icon: icon)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.06), radius: 10, x: 0, y: 4)
        }
    }

    private var rowDivider: some View {
        Divider()
            .padding(.leading, 62)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color("BrandOrange").opacity(colorScheme == .dark ? 0.35 : 0.22),
                                Color("BrandBlue").opacity(colorScheme == .dark ? 0.3 : 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color("BrandDark"))
            }
            Text(title)
                .font(.body)
                .foregroundStyle(Color.primary)
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color("BrandOrange"))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MilestoneCardDetailView.swift
// Preview, share, save milestone PNG (iOS).

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import Photos
#endif

#if os(iOS)
struct MilestoneCardDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    let record: MilestoneRecord
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var selectedPhoto: UIImage?
    @State private var renderedImage: UIImage?
    @State private var shareFileURL: URL?
    @State private var isRendering = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var isSavingPhoto = false
    @State private var showDeleteConfirm = false
    @State private var showRegeneratePhotoPrompt = false
    @State private var afterImagePickRegenerateStatLine = false
    @State private var isRegeneratingAI = false

    // Single fullScreenCover for both pickers (avoids nested-sheet bug).
    @State private var activePicker: PhotoPickerMode?

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var pet: Pet? {
        sortedPets.first { $0.id == record.petId }
    }

    private var milestone: MilestoneType? {
        MilestoneType(rawValue: record.milestoneType)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pet, let mt = milestone {
                    content(pet: pet, milestone: mt)
                } else {
                    ContentUnavailableView(
                        "Milestone unavailable",
                        systemImage: "pawprint",
                        description: Text("Could not load this milestone's pet.")
                    )
                }
            }
            .navigationTitle(milestone?.displayName ?? "Milestone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Regenerate Card") {
                            startRegenerateCardFlow()
                        }
                        .disabled(isRendering || isRegeneratingAI)
                        Button {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(Color(.systemRed))
                        }
                        .accessibilityLabel("Delete card")
                    }
                }
            }
        }
        .confirmationDialog(
            "Keep current photo or pick a new one?",
            isPresented: $showRegeneratePhotoPrompt,
            titleVisibility: .visible
        ) {
            Button("Keep photo") {
                Task { await regenerateCardAI() }
            }
            Button("Choose new photo") {
                afterImagePickRegenerateStatLine = true
                activePicker = .library
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(saveAlertTitle, isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
        .fullScreenCover(item: $activePicker) { mode in
            switch mode {
            case .library:
                ImagePickerView(
                    source: .photoLibrary,
                    onImageSelected: { image in
                        activePicker = nil
                        applyPickedCardPhoto(image)
                        if afterImagePickRegenerateStatLine {
                            afterImagePickRegenerateStatLine = false
                            Task { await regenerateCardAI() }
                        }
                    },
                    onCancel: {
                        activePicker = nil
                        afterImagePickRegenerateStatLine = false
                    }
                )
                .ignoresSafeArea()
            case .camera:
                ImagePickerView(
                    source: .camera,
                    onImageSelected: { image in
                        activePicker = nil
                        applyPickedCardPhoto(image)
                        if afterImagePickRegenerateStatLine {
                            afterImagePickRegenerateStatLine = false
                            Task { await regenerateCardAI() }
                        }
                    },
                    onCancel: {
                        activePicker = nil
                        afterImagePickRegenerateStatLine = false
                    }
                )
                .ignoresSafeArea()
            }
        }
        .alert("Delete this card?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .onAppear {
            if let data = record.cardPhotoData, let img = UIImage(data: data) {
                selectedPhoto = img
            }
        }
    }

    private func applyPickedCardPhoto(_ image: UIImage) {
        selectedPhoto = image
        record.cardPhotoData = image.jpegData(compressionQuality: 0.9) ?? image.pngData()
        try? modelContext.save()
        if let pet, let mt = milestone {
            scheduleRender(pet: pet, milestone: mt)
        }
    }

    private func startRegenerateCardFlow() {
        guard milestone != nil else { return }
        if record.cardPhotoData != nil {
            showRegeneratePhotoPrompt = true
        } else {
            Task { await regenerateCardAI() }
        }
    }

    @MainActor
    private func regenerateCardAI() async {
        guard let pet, let mt = milestone else { return }
        isRegeneratingAI = true
        defer { isRegeneratingAI = false }
        await MilestoneCheckService.shared.regenerateFunStatLine(
            for: record,
            pet: pet,
            modelContext: modelContext
        )
        scheduleRender(pet: pet, milestone: mt)
    }

    @ViewBuilder
    private func content(pet: Pet, milestone: MilestoneType) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                ZStack {
                    ZoomableCardPreview(
                        naturalWidth: 1080,
                        naturalHeight: 1920,
                        pinchHintAppStorageKey: "hasSeenMilestoneZoomHint",
                        hintResetToken: record.id
                    ) { fitWidth, fitHeight in
                        MilestoneCardView(
                            pet: pet,
                            milestone: milestone,
                            record: record,
                            selectedPhoto: selectedPhoto,
                            displayWidth: fitWidth,
                            displayHeight: fitHeight
                        )
                    }

                    if (isRendering && renderedImage == nil) || isRegeneratingAI {
                        VStack(spacing: 10) {
                            ProgressView()
                            Text(isRegeneratingAI ? "Writing something new…" : "Generating your card…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
                .frame(maxWidth: .infinity)

                // Choose Photo (LEFT) | Take Photo (RIGHT)
                HStack(spacing: 12) {
                    Button {
                        activePicker = .library
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                            Text("Choose Photo")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color("BrandOrange"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Button {
                        activePicker = .camera
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "camera.fill")
                                .font(.title3)
                            Text("Take Photo")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .foregroundStyle(Color("BrandDark"))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                Divider()

                HStack(spacing: 10) {
                    if let url = shareFileURL, let img = renderedImage {
                        ShareLink(
                            item: url,
                            preview: SharePreview("Milestone", image: Image(uiImage: img))
                        ) {
                            Label("Share Card", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color("BrandOrange"))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            scheduleRender(pet: pet, milestone: milestone)
                        } label: {
                            Label("Prepare share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color("BrandOrange").opacity(0.35))
                                .foregroundStyle(Color("BrandDark"))
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isRendering)
                    }

                    Button {
                        Task { await saveToPhotos(pet: pet, milestone: milestone) }
                    } label: {
                        Label("Save to Camera Roll", systemImage: "photo.on.rectangle.angled")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(Color("BrandDark"))
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(renderedImage == nil && !isRendering)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGroupedBackground))
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .onAppear {
            scheduleRender(pet: pet, milestone: milestone)
        }
    }

    private func scheduleRender(pet: Pet, milestone: MilestoneType) {
        renderedImage = nil
        shareFileURL = nil
        isRendering = true
        Task { @MainActor in
            let img = MilestoneCardRenderer.snapshot(
                pet: pet,
                milestone: milestone,
                record: record,
                selectedPhoto: selectedPhoto,
                displayScale: displayScale
            )
            renderedImage = img
            if let img {
                shareFileURL = Self.writeTempPNG(image: img)
            }
            isRendering = false
        }
    }

    private static func writeTempPNG(image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let name = "Milestone-\(UUID().uuidString).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    private func saveToPhotos(pet: Pet, milestone: MilestoneType) async {
        let image = renderedImage ?? MilestoneCardRenderer.snapshot(
            pet: pet,
            milestone: milestone,
            record: record,
            selectedPhoto: selectedPhoto,
            displayScale: displayScale
        )
        guard let image else { return }
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        let status = await requestPhotoAddAccess()
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
        } catch {
            saveAlertTitle = "Could Not Save"
            saveAlertMessage = error.localizedDescription
            showSaveAlert = true
        }
    }

    private func requestPhotoAddAccess() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }
}
#else
struct MilestoneCardDetailView: View {
    let record: MilestoneRecord
    var body: some View {
        Text("Milestones on iOS")
    }
}
#endif

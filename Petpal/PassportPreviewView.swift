// PassportPreviewView.swift
// Care Card preview (legacy filename `PassportPreviewView`), export at 1080×1350, share and save to Photos.

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import Photos
#endif

#if os(iOS)
struct PassportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    /// Called after dismiss so the parent can present `PetDetailView`.
    var onEditProfileRequested: (() -> Void)?

    @State private var renderedImage: UIImage?
    @State private var shareFileURL: URL?
    @State private var isRendering = false
    @State private var showSlowRenderSpinner = false
    @State private var slowRenderTask: Task<Void, Never>?
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var isSavingPhoto = false
    @State private var passportFieldSettings = CareCardFieldSettings.defaults

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var resolvedPetId: UUID? {
        ActivePetResolver.resolvedPetId(pets: sortedPets)
    }

    private var resolvedPet: Pet? {
        guard let id = resolvedPetId else { return nil }
        return sortedPets.first { $0.id == id }
    }

    private var passportData: PassportData? {
        guard let pet = resolvedPet else { return nil }
        return PassportData(pet: pet)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let data = passportData {
                    passportContent(data: data)
                } else {
                    ContentUnavailableView(
                        "No Pet Selected",
                        systemImage: "pawprint",
                        description: Text("Add or select a pet, then open Care Card again.")
                    )
                }
            }
            .navigationTitle("Care Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .alert(saveAlertTitle, isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
    }

    private var sharePreviewImage: Image {
        if let img = renderedImage {
            return Image(uiImage: img)
        }
        return Image(systemName: "doc.richtext")
    }

    @ViewBuilder
    private func passportContent(data: PassportData) -> some View {
        VStack(spacing: 0) {
            ZStack {
                ZoomableCardPreview(
                    naturalWidth: 1080,
                    naturalHeight: 1350,
                    pinchHintAppStorageKey: "hasSeenPassportZoomHint",
                    hintResetToken: data.pet.id
                ) {
                    PetPassportCard(
                        data: data,
                        fieldSettings: passportFieldSettings,
                        displayWidth: 1080,
                        displayHeight: 1350
                    )
                }

                if showSlowRenderSpinner && (renderedImage == nil || isRendering) {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Preparing Care Card…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            bottomActionBar
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear {
            passportFieldSettings = CareCardFieldSettings.load(for: data.pet.id)
            scheduleRenderPassport()
        }
        .onChange(of: resolvedPetId) { _, newId in
            if let id = newId {
                passportFieldSettings = CareCardFieldSettings.load(for: id)
            }
            scheduleRenderPassport()
        }
        .onDisappear {
            slowRenderTask?.cancel()
            slowRenderTask = nil
        }
    }

    private var bottomActionBar: some View {
        VStack(spacing: 12) {
            Divider()
            HStack(spacing: 12) {
                if let url = shareFileURL {
                    ShareLink(
                        item: url,
                        preview: SharePreview("Care Card", image: sharePreviewImage)
                    ) {
                        Label("Share Card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BrandOrange"))
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                } else if isRendering {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Preparing…")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("BrandOrange").opacity(0.85))
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    Button {
                        scheduleRenderPassport()
                    } label: {
                        Label("Share Card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BrandOrange"))
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                Button {
                    Task { await saveToPhotos() }
                } label: {
                    Group {
                        if isSavingPhoto {
                            ProgressView()
                                .tint(Color("BrandDark"))
                        } else {
                            Label("Save to Camera Roll", systemImage: "photo.on.rectangle.angled")
                                .font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemGroupedBackground))
                    .foregroundStyle(Color("BrandDark"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRendering || renderedImage == nil || isSavingPhoto)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private func scheduleRenderPassport() {
        guard let data = passportData else {
            renderedImage = nil
            shareFileURL = nil
            return
        }
        renderedImage = nil
        shareFileURL = nil
        slowRenderTask?.cancel()
        showSlowRenderSpinner = false
        slowRenderTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if !Task.isCancelled {
                await MainActor.run { showSlowRenderSpinner = true }
            }
        }

        Task { @MainActor in
            renderPassportAssets(data: data)
        }
    }

    @MainActor
    private func renderPassportAssets(data: PassportData) {
        isRendering = true
        defer {
            isRendering = false
            slowRenderTask?.cancel()
            slowRenderTask = nil
            showSlowRenderSpinner = false
        }

        let image = Self.snapshotPassport(data: data, fieldSettings: CareCardFieldSettings.load(for: data.pet.id), displayScale: displayScale)
        guard let image else { return }
        renderedImage = image
        shareFileURL = Self.writeTempPNG(image: image)
    }

    @MainActor
    private static func snapshotPassport(data: PassportData, fieldSettings: CareCardFieldSettings, displayScale: CGFloat) -> UIImage? {
        let content = PetPassportCard(
            data: data,
            fieldSettings: fieldSettings,
            displayWidth: 1080,
            displayHeight: 1350
        )
            .environment(\.displayScale, displayScale)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 1080, alignment: .top)
            .frame(minHeight: 1350, alignment: .top)
        let renderer = ImageRenderer(content: content)
        let scale = max(displayScale, 3.0)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        return renderer.uiImage
    }

    private static func writeTempPNG(image: UIImage) -> URL? {
        guard let data = image.pngData() else { return nil }
        let name = "PetPassport-\(UUID().uuidString).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    @MainActor
    private func saveToPhotos() async {
        guard let image = renderedImage else { return }
        isSavingPhoto = true
        defer { isSavingPhoto = false }

        let status = await requestPhotoAddAccess()
        guard status == .authorized || status == .limited else {
            saveAlertTitle = "Photos Access Needed"
            saveAlertMessage = "Allow Petpal to add photos in Settings to save your Care Card."
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
struct PassportPreviewView: View {
    var onEditProfileRequested: (() -> Void)?
    var body: some View {
        Text("Care Card is available on iOS.")
    }
}
#endif

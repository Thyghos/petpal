// Sheet: monthly recap card preview, share, save, regenerate.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
import Photos
#endif

#if os(iOS)
struct MonthlyRecapPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    let pet: Pet
    let month: Int
    let year: Int

    @ObservedObject private var appleHealth = AppleHealthService.shared

    @State private var stats: MonthlyRecapService.MonthlyStats?
    @State private var oneLiner: String = ""
    @State private var photos: [PetMonthlyPhoto] = []
    @State private var isLoading = true
    @State private var sharePayload: ShareSheetPayload?
    @State private var showPhotoDenied = false
    @State private var hintToken = UUID()
    @State private var personalNote: String = ""
    /// When false, the note editor is collapsed to a compact row; recap preview stays visible above the inset.
    @State private var isPersonalNoteExpanded = true
    @State private var showMonthlyRegeneratePhotoPrompt = false
    @State private var showMonthlyHighlightPicker = false
    @State private var loadingCaption = "Creating your monthly recap…"

    private var noteStorageKey: String {
        "monthlyRecapNote_\(pet.id.uuidString)_\(year)_\(month)"
    }

    private var personalNoteForCard: String? {
        let t = personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : personalNote
    }

    private var monthTitle: String {
        let idx = max(0, min(11, month - 1))
        return DateFormatter().monthSymbols[idx]
    }

    private var displayPetName: String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your pet" : n
    }

    /// Newest-first rows from the album; the card shows at most 9.
    private var photoImagesForCard: [UIImage] {
        photos.prefix(9).compactMap { UIImage(data: $0.photoData) }
    }

    private var photoCountCaption: String {
        let total = photos.count
        let shown = min(9, total)
        return "Showing \(shown) of \(total) photos from \(monthTitle)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    ZoomableCardPreview(
                        naturalWidth: 1080,
                        naturalHeight: 1350,
                        pinchHintAppStorageKey: "hasSeenMonthlyRecapZoomHint",
                        hintResetToken: hintToken
                    ) { fitW, fitH in
                        MonthlyRecapCardView(
                            petName: displayPetName,
                            monthTitle: monthTitle,
                            month: month,
                            year: year,
                            photoImages: photoImagesForCard,
                            oneLiner: oneLiner,
                            vetVisits: stats?.vetVisits ?? 0,
                            milestoneRecords: stats?.milestoneRecords ?? [],
                            manualWalksCount: stats?.manualWalksCount ?? 0,
                            manualWalksMiles: stats?.manualWalksMiles ?? 0,
                            personalNote: personalNoteForCard,
                            displayWidth: fitW,
                            displayHeight: fitH
                        )
                        .environment(\.displayScale, displayScale)
                    }
                    if !isLoading {
                        Text(photoCountCaption)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }
                if isLoading {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(loadingCaption)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                }
            }
            .navigationTitle("\(monthTitle) recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Regenerate Card") {
                        handleRegenerateCardTap()
                    }
                    .disabled(isLoading)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 12) {
                    personalNoteSection
                    HStack(spacing: 12) {
                        Button {
                            sharePNG()
                        } label: {
                            Label("Share Card", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            saveToPhotos()
                        } label: {
                            Label("Save to Camera Roll", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(.bar)
            }
            .onAppear {
                personalNote = UserDefaults.standard.string(forKey: noteStorageKey) ?? ""
            }
            .onChange(of: personalNote) { _, new in
                if new.count > 120 {
                    personalNote = String(new.prefix(120))
                    return
                }
                persistPersonalNoteToUserDefaults()
            }
            .task {
                await load(forceAI: false, aiRefreshPass: false)
            }
            .confirmationDialog(
                "Keep current month photos or add a new highlight photo?",
                isPresented: $showMonthlyRegeneratePhotoPrompt,
                titleVisibility: .visible
            ) {
                Button("Keep photos") {
                    Task { await load(forceAI: true, aiRefreshPass: true) }
                }
                Button("Add photo") {
                    showMonthlyHighlightPicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showMonthlyHighlightPicker) {
                ImagePickerView(
                    source: .photoLibrary,
                    onImageSelected: { image in
                        addMonthlyHighlightPhoto(image)
                        showMonthlyHighlightPicker = false
                        Task { await load(forceAI: true, aiRefreshPass: true) }
                    },
                    onCancel: {
                        showMonthlyHighlightPicker = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $sharePayload) { p in
                ShareSheet(items: p.items)
            }
            .alert("Photos access denied", isPresented: $showPhotoDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow Photos access in Settings to save your recap.")
            }
        }
    }

    private var personalNoteSection: some View {
        Group {
            if isPersonalNoteExpanded {
                personalNoteCardExpanded
            } else {
                personalNoteRowCompact
            }
        }
    }

    private var personalNoteRowCompact: some View {
        Button {
            isPersonalNoteExpanded = true
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "square.and.pencil")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color("BrandDark").opacity(0.85))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal note")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("BrandDark"))
                    Text(compactNoteSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(ModernCard(cornerRadius: 18))
    }

    private var compactNoteSubtitle: String {
        let t = personalNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            return "Optional · Tap to add"
        }
        return t
    }

    private var personalNoteCardExpanded: some View {
        let placeholder = "Write something about this month with \(displayPetName)..."
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Add a personal note")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color("BrandDark"))
                    Text("Optional · Shows on your recap card")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button {
                    collapsePersonalNoteEditor()
                } label: {
                    Text("Done")
                        .font(.body.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
            ZStack(alignment: .topLeading) {
                if personalNote.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $personalNote)
                    .font(.body)
                    .frame(minHeight: 72, maxHeight: 96)
                    .scrollContentBackground(.hidden)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            Text("\(personalNote.count)/120")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(16)
        .modifier(ModernCard(cornerRadius: 18))
    }

    private func collapsePersonalNoteEditor() {
        persistPersonalNoteToUserDefaults()
        isPersonalNoteExpanded = false
    }

    private func persistPersonalNoteToUserDefaults() {
        UserDefaults.standard.set(personalNote, forKey: noteStorageKey)
    }

    private func handleRegenerateCardTap() {
        if photos.isEmpty {
            Task { await load(forceAI: true, aiRefreshPass: true) }
        } else {
            showMonthlyRegeneratePhotoPrompt = true
        }
    }

    private func addMonthlyHighlightPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData() else { return }
        let entry = PetMonthlyPhoto(petId: pet.id, month: month, year: year, photoData: data)
        modelContext.insert(entry)
        try? modelContext.save()
    }

    @MainActor
    private func load(forceAI: Bool, aiRefreshPass: Bool) async {
        loadingCaption = aiRefreshPass ? "Writing something new…" : "Creating your monthly recap…"
        isLoading = true
        await appleHealth.refreshSummaryIfStale()
        let s = (try? MonthlyRecapService.computeStats(
            petId: pet.id,
            month: month,
            year: year,
            modelContext: modelContext,
            appleHealthSummary: appleHealth.summary
        )) ?? MonthlyRecapService.MonthlyStats(vetVisits: 0, milestones: 0, miles: 0, steps: 0, activeMinutes: 0, manualWalksCount: 0, manualWalksMiles: 0, milestoneRecords: [])
        stats = s
        photos = MonthlyRecapService.monthlyPhotos(
            petId: pet.id,
            month: month,
            year: year,
            modelContext: modelContext
        )
        let line = await MonthlyRecapService.oneLiner(
            petName: displayPetName,
            petId: pet.id,
            month: month,
            year: year,
            monthName: monthTitle,
            stats: s,
            forceRefresh: forceAI
        )
        oneLiner = line
        hintToken = UUID()
        isLoading = false
        loadingCaption = "Creating your monthly recap…"
    }

    private func renderedCardImage() -> UIImage? {
        let content = MonthlyRecapCardView(
            petName: displayPetName,
            monthTitle: monthTitle,
            month: month,
            year: year,
            photoImages: photoImagesForCard,
            oneLiner: oneLiner,
            vetVisits: stats?.vetVisits ?? 0,
            milestoneRecords: stats?.milestoneRecords ?? [],
            manualWalksCount: stats?.manualWalksCount ?? 0,
            manualWalksMiles: stats?.manualWalksMiles ?? 0,
            personalNote: personalNoteForCard,
            displayWidth: 1080,
            displayHeight: 1350
        )
        .environment(\.displayScale, max(displayScale, 2.0))
        .frame(width: 1080, height: 1350)

        let renderer = ImageRenderer(content: content)
        renderer.scale = max(displayScale, 2.0)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1350)
        return renderer.uiImage
    }

    private func sharePNG() {
        guard let img = renderedCardImage() else { return }
        sharePayload = ShareSheetPayload(items: [img])
    }

    private func saveToPhotos() {
        guard let img = renderedCardImage() else { return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { showPhotoDenied = true }
                return
            }
            UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        }
    }
}
#endif

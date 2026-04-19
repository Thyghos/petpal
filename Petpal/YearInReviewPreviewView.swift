// Paged Year in Review: 5 slides, zoom, share, save all, export MP4.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
import Photos
#endif

#if os(iOS)
struct YearInReviewPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.displayScale) private var displayScale

    let pet: Pet
    let record: YearInReviewRecord

    @Query private var monthlyPhotos: [PetMonthlyPhoto]

    @ObservedObject private var appleHealth = AppleHealthService.shared

    @State private var page = 0
    @State private var isBusy = false
    @State private var sharePayload: ShareSheetPayload?
    @State private var showPhotoDenied = false
    @State private var hintToken = UUID()
    @State private var videoExportURL: URL?
    @State private var showVideoShare = false
    @State private var showVideoExportError = false
    @State private var videoExportErrorMessage = ""

    @State private var yirSettings = YearInReviewCustomSettings()
    @State private var showCustomizeSheet = false
    @State private var editedHeadline: String?
    @State private var editedPersonalityLine: String?
    @State private var showHeadlineEditSheet = false
    @State private var showPersonalityEditSheet = false
    @State private var showYIRCoverRegeneratePrompt = false
    @State private var showYIRProfilePicker = false
    @State private var busyOverlayMessage = ""

    /// Month (1–12) → selected `PetMonthlyPhoto.id` for Slide 4 grid; persisted.
    @State private var yirMonthPhotoSelections: [Int: UUID] = [:]
    @State private var showYIRMomentsPhotoPicker = false
    @State private var editedMomentsCaption: String?
    @State private var showMomentsCaptionEditSheet = false

    /// Set to `2` to validate the export pipeline with fewer slides; `nil` uses all rendered slides (5).
    private static let exportVideoLimitedSlideCount: Int? = nil

    private var displayName: String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your pet" : n
    }

    private var year: Int { record.year }

    private var aiHeadline: String { record.yearHeadline ?? "A wonderful year together" }
    private var aiPersonalityLine: String { record.personalityLine ?? "Your companion brings joy every single day." }

    private var effectiveHeadline: String { editedHeadline ?? aiHeadline }
    private var effectivePersonalityLine: String { editedPersonalityLine ?? aiPersonalityLine }

    private var monthPhotoSelectionStorageKey: String {
        "yir_monthPhotos_\(pet.id.uuidString)_\(year)"
    }

    private var momentsCaptionStorageKey: String {
        "yir_momentsCaptionEdit_\(pet.id.uuidString)_\(year)"
    }

    /// Slide 4 grid: one image per month (user selection or first in album), up to 12.
    private func monthThumbnailMapForSlide() -> [Int: UIImage] {
        var map: [Int: UIImage] = [:]
        for m in 1...12 {
            let pool = monthlyPhotos
                .filter { $0.petId == pet.id && $0.year == year && $0.month == m }
                .sorted { $0.addedDate < $1.addedDate }
            guard !pool.isEmpty else { continue }
            let chosen: PetMonthlyPhoto? = {
                if let id = yirMonthPhotoSelections[m], let p = pool.first(where: { $0.id == id }) {
                    return p
                }
                return pool.first
            }()
            if let chosen, let ui = UIImage(data: chosen.photoData) {
                map[m] = ui
            }
        }
        return map
    }

    private var aiMomentsCaption: String? {
        guard yirSettings.showMilestones, record.milestonesCount > 0 else { return nil }
        return "\(record.milestonesCount) milestone\(record.milestonesCount == 1 ? "" : "s") worth celebrating in \(year)."
    }

    private var effectiveMomentsLine: String? {
        let edited = editedMomentsCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !edited.isEmpty { return edited }
        return aiMomentsCaption
    }

    private func loadYIRMomentsPersistence() {
        if let data = UserDefaults.standard.data(forKey: monthPhotoSelectionStorageKey),
           let raw = try? JSONDecoder().decode([String: String].self, from: data) {
            var dict: [Int: UUID] = [:]
            for (k, v) in raw {
                if let m = Int(k), let u = UUID(uuidString: v) { dict[m] = u }
            }
            yirMonthPhotoSelections = dict
        }
        if let s = UserDefaults.standard.string(forKey: momentsCaptionStorageKey)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            editedMomentsCaption = s
        }
    }

    private func saveMonthPhotoSelections() {
        var raw: [String: String] = [:]
        for (m, u) in yirMonthPhotoSelections { raw["\(m)"] = u.uuidString }
        if let data = try? JSONEncoder().encode(raw) {
            UserDefaults.standard.set(data, forKey: monthPhotoSelectionStorageKey)
        }
    }

    private func saveMomentsCaptionPersistence() {
        let t = editedMomentsCaption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if t.isEmpty {
            UserDefaults.standard.removeObject(forKey: momentsCaptionStorageKey)
        } else {
            UserDefaults.standard.set(t, forKey: momentsCaptionStorageKey)
        }
    }

    /// Ensures each month with photos has a valid selection UUID (defaults to earliest in album).
    private func syncYIRMonthSelectionsWithAlbum() {
        for m in 1...12 {
            let pool = monthlyPhotos
                .filter { $0.petId == pet.id && $0.year == year && $0.month == m }
                .sorted { $0.addedDate < $1.addedDate }
            if pool.isEmpty {
                yirMonthPhotoSelections.removeValue(forKey: m)
                continue
            }
            if let sel = yirMonthPhotoSelections[m], pool.contains(where: { $0.id == sel }) {
                continue
            }
            yirMonthPhotoSelections[m] = pool.first?.id
        }
    }

    private var coverPhoto: UIImage? {
        if let d = pet.profileImage, let ui = UIImage(data: d) { return ui }
        return nil
    }

    private var personalityPhoto: UIImage? { coverPhoto }

    private var visibleLogicalSlideIndices: [Int] {
        var s = [0, 1, 2, 3]
        if yirSettings.includePersonalitySlide { s.append(4) }
        return s
    }

    private var currentLogicalSlide: Int {
        guard page >= 0, page < visibleLogicalSlideIndices.count else { return 0 }
        return visibleLogicalSlideIndices[page]
    }

    private var activeMinutesForYear: Int {
        appleHealth.summary.map { s in
            s.walksByMonth.filter { $0.year == year }.map(\.activeMinutes).reduce(0, +)
        } ?? 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TabView(selection: $page) {
                    ForEach(visibleLogicalSlideIndices, id: \.self) { logical in
                        slideContent(logical: logical)
                            .tag(visibleLogicalSlideIndices.firstIndex(of: logical) ?? 0)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .onAppear { hintToken = UUID() }

                if isBusy {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(busyOverlayMessage.isEmpty ? "Creating \(displayName)'s Year in Review…" : busyOverlayMessage)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                }
            }
            .navigationTitle("Year in Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        Button("Customize") {
                            showCustomizeSheet = true
                        }
                        .disabled(isBusy)
                        Button("Regenerate Card") {
                            beginYearReviewRegenerate()
                        }
                        .disabled(isBusy)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if currentLogicalSlide == 0 {
                        Button {
                            showHeadlineEditSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("Edit quote")
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else if currentLogicalSlide == 3 {
                        HStack(spacing: 20) {
                            Button {
                                syncYIRMonthSelectionsWithAlbum()
                                showYIRMomentsPhotoPicker = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "photo")
                                    Text("Edit Photos")
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            Button {
                                showMomentsCaptionEditSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil")
                                    Text("Edit caption")
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else if currentLogicalSlide == 4 {
                        Button {
                            showPersonalityEditSheet = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                Text("Edit quote")
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack(spacing: 8) {
                        Button { shareCurrentSlide() } label: {
                            Text("Share Card")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button { shareAllPNGs() } label: {
                            Text("Share All Cards")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    HStack(spacing: 8) {
                        Button { saveAllToPhotos() } label: {
                            Label("Save All to Camera Roll", systemImage: "photo.on.rectangle.angled")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button { exportVideo() } label: {
                            Label("Export Video", systemImage: "film")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(.bar)
            }
            .task {
                await appleHealth.refreshSummaryIfStale()
            }
            .onAppear {
                yirSettings = YearInReviewCustomizeStorage.load(petId: pet.id, year: year)
                loadYIRMomentsPersistence()
                syncYIRMonthSelectionsWithAlbum()
            }
            .onChange(of: monthlyPhotos.count) { _, _ in
                syncYIRMonthSelectionsWithAlbum()
            }
            .onChange(of: yirSettings) { _, new in
                YearInReviewCustomizeStorage.save(new, petId: pet.id, year: year)
            }
            .onChange(of: yirSettings.includePersonalitySlide) { _, included in
                if !included, page > visibleLogicalSlideIndices.count - 1 {
                    page = max(0, visibleLogicalSlideIndices.count - 1)
                }
            }
            .confirmationDialog(
                "Keep current cover photo or pick a new one?",
                isPresented: $showYIRCoverRegeneratePrompt,
                titleVisibility: .visible
            ) {
                Button("Keep photo") {
                    Task { await runYearReviewRegenerate() }
                }
                Button("Change photo") {
                    showYIRProfilePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showYIRProfilePicker) {
                ImagePickerView(
                    source: .photoLibrary,
                    onImageSelected: { image in
                        if let d = image.jpegData(compressionQuality: 0.9) ?? image.pngData() {
                            pet.profileImage = d
                            try? modelContext.save()
                        }
                        showYIRProfilePicker = false
                        Task { await runYearReviewRegenerate() }
                    },
                    onCancel: {
                        showYIRProfilePicker = false
                    }
                )
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showCustomizeSheet) {
                YearInReviewCustomizeSheet(
                    petName: displayName,
                    settings: $yirSettings
                )
            }
            .sheet(isPresented: $showHeadlineEditSheet) {
                YearInReviewLineEditSheet(
                    title: "Edit Year Headline",
                    maxLength: 60,
                    initialText: editedHeadline ?? aiHeadline,
                    onSave: { editedHeadline = $0.isEmpty ? nil : $0 },
                    onResetToAI: { editedHeadline = nil }
                )
            }
            .sheet(isPresented: $showPersonalityEditSheet) {
                YearInReviewLineEditSheet(
                    title: "Edit Personality Line",
                    maxLength: 100,
                    initialText: editedPersonalityLine ?? aiPersonalityLine,
                    onSave: { editedPersonalityLine = $0.isEmpty ? nil : $0 },
                    onResetToAI: { editedPersonalityLine = nil }
                )
            }
            .sheet(isPresented: $showYIRMomentsPhotoPicker) {
                YearInReviewPhotoPickerSheet(
                    pet: pet,
                    year: year,
                    allMonthlyPhotos: monthlyPhotos,
                    selectedPhotoIdByMonth: $yirMonthPhotoSelections
                )
                .onDisappear {
                    saveMonthPhotoSelections()
                    hintToken = UUID()
                }
            }
            .sheet(isPresented: $showMomentsCaptionEditSheet) {
                YearInReviewLineEditSheet(
                    title: "Edit caption",
                    maxLength: 80,
                    initialText: editedMomentsCaption ?? aiMomentsCaption ?? "",
                    onSave: {
                        editedMomentsCaption = $0.isEmpty ? nil : $0
                        saveMomentsCaptionPersistence()
                        hintToken = UUID()
                    },
                    onResetToAI: {
                        editedMomentsCaption = nil
                        saveMomentsCaptionPersistence()
                        hintToken = UUID()
                    }
                )
            }
            .sheet(item: $sharePayload) { p in
                ShareSheet(items: p.items)
            }
            .sheet(isPresented: $showVideoShare) {
                if let url = videoExportURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Photos access denied", isPresented: $showPhotoDenied) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Allow Photos access in Settings to save images.")
            }
            .alert("Could not export video", isPresented: $showVideoExportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(videoExportErrorMessage)
            }
        }
    }

    @ViewBuilder
    private func slideContent(logical: Int) -> some View {
        switch logical {
        case 0:
            ZoomableCardPreview(
                naturalWidth: 1080,
                naturalHeight: 1920,
                pinchHintAppStorageKey: "hasSeenYIRZoomHint",
                hintResetToken: hintToken
            ) { fitW, fitH in
                YearInReviewSlide1Cover(
                    petName: displayName,
                    year: year,
                    yearHeadline: effectiveHeadline,
                    backgroundPhoto: coverPhoto,
                    displayWidth: fitW,
                    displayHeight: fitH
                )
                .environment(\.displayScale, displayScale)
            }
        case 1:
            ZoomableCardPreview(
                naturalWidth: 1080,
                naturalHeight: 1920,
                pinchHintAppStorageKey: "hasSeenYIRZoomHint",
                hintResetToken: hintToken
            ) { fitW, fitH in
                YearInReviewSlide2Activity(
                    petName: displayName,
                    year: year,
                    isAppleHealthConnected: appleHealth.isConnected,
                    totalActivityMiles: record.totalMiles,
                    totalMilesWithPet: record.totalMilesWithPet,
                    totalSteps: record.totalSteps,
                    totalActiveMinutes: activeMinutesForYear,
                    settings: yirSettings,
                    displayWidth: fitW,
                    displayHeight: fitH
                )
                .environment(\.displayScale, displayScale)
            }
        case 2:
            ZoomableCardPreview(
                naturalWidth: 1080,
                naturalHeight: 1920,
                pinchHintAppStorageKey: "hasSeenYIRZoomHint",
                hintResetToken: hintToken
            ) { fitW, fitH in
                YearInReviewSlide3Health(
                    vetVisits: record.vetVisitsCount,
                    vaccinesCompleted: record.vaccinesCompletedCount,
                    weightChangeText: record.weightChangeText,
                    medicationsLogged: record.medicationsLoggedCount,
                    healthReportGrade: nil,
                    settings: yirSettings,
                    displayWidth: fitW,
                    displayHeight: fitH
                )
                .environment(\.displayScale, displayScale)
            }
        case 3:
            ZoomableCardPreview(
                naturalWidth: 1080,
                naturalHeight: 1920,
                pinchHintAppStorageKey: "hasSeenYIRZoomHint",
                hintResetToken: hintToken
            ) { fitW, fitH in
                YearInReviewSlide4Moments(
                    monthThumbnails: monthThumbnailMapForSlide(),
                    milestonesCount: record.milestonesCount,
                    momentsLine: effectiveMomentsLine,
                    settings: yirSettings,
                    displayWidth: fitW,
                    displayHeight: fitH
                )
                .environment(\.displayScale, displayScale)
            }
        case 4:
            ZoomableCardPreview(
                naturalWidth: 1080,
                naturalHeight: 1920,
                pinchHintAppStorageKey: "hasSeenYIRZoomHint",
                hintResetToken: hintToken
            ) { fitW, fitH in
                YearInReviewSlide5Personality(
                    petName: displayName,
                    year: year,
                    personalityLine: effectivePersonalityLine,
                    petPhoto: personalityPhoto,
                    displayWidth: fitW,
                    displayHeight: fitH
                )
                .environment(\.displayScale, displayScale)
            }
        default:
            EmptyView()
        }
    }

    private func slideImage(logicalIndex: Int) -> UIImage? {
        let scale = max(1.0, displayScale)
        switch logicalIndex {
        case 0:
            return render(
                YearInReviewSlide1Cover(
                    petName: displayName,
                    year: year,
                    yearHeadline: effectiveHeadline,
                    backgroundPhoto: coverPhoto,
                    displayWidth: 1080,
                    displayHeight: 1920
                ),
                scale: scale
            )
        case 1:
            return render(
                YearInReviewSlide2Activity(
                    petName: displayName,
                    year: year,
                    isAppleHealthConnected: appleHealth.isConnected,
                    totalActivityMiles: record.totalMiles,
                    totalMilesWithPet: record.totalMilesWithPet,
                    totalSteps: record.totalSteps,
                    totalActiveMinutes: activeMinutesForYear,
                    settings: yirSettings,
                    displayWidth: 1080,
                    displayHeight: 1920
                ),
                scale: scale
            )
        case 2:
            return render(
                YearInReviewSlide3Health(
                    vetVisits: record.vetVisitsCount,
                    vaccinesCompleted: record.vaccinesCompletedCount,
                    weightChangeText: record.weightChangeText,
                    medicationsLogged: record.medicationsLoggedCount,
                    healthReportGrade: nil,
                    settings: yirSettings,
                    displayWidth: 1080,
                    displayHeight: 1920
                ),
                scale: scale
            )
        case 3:
            return render(
                YearInReviewSlide4Moments(
                    monthThumbnails: monthThumbnailMapForSlide(),
                    milestonesCount: record.milestonesCount,
                    momentsLine: effectiveMomentsLine,
                    settings: yirSettings,
                    displayWidth: 1080,
                    displayHeight: 1920
                ),
                scale: scale
            )
        case 4:
            return render(
                YearInReviewSlide5Personality(
                    petName: displayName,
                    year: year,
                    personalityLine: effectivePersonalityLine,
                    petPhoto: personalityPhoto,
                    displayWidth: 1080,
                    displayHeight: 1920
                ),
                scale: scale
            )
        default:
            return nil
        }
    }

    private func render<V: View>(_ view: V, scale: CGFloat) -> UIImage? {
        let content = view.environment(\.displayScale, scale).frame(width: 1080, height: 1920)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1.0
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }

    private func shareCurrentSlide() {
        guard page < visibleLogicalSlideIndices.count else { return }
        let logical = visibleLogicalSlideIndices[page]
        guard let img = slideImage(logicalIndex: logical) else { return }
        sharePayload = ShareSheetPayload(items: [img])
    }

    private func shareAllPNGs() {
        let imgs = visibleLogicalSlideIndices.compactMap { slideImage(logicalIndex: $0) }
        guard !imgs.isEmpty else { return }
        sharePayload = ShareSheetPayload(items: imgs)
    }

    private func saveAllToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { showPhotoDenied = true }
                return
            }
            for idx in visibleLogicalSlideIndices {
                if let img = slideImage(logicalIndex: idx) {
                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                }
            }
        }
    }

    private func exportVideo() {
        Task { @MainActor in
            isBusy = true
            defer { isBusy = false }
            do {
                let imgs = visibleLogicalSlideIndices.compactMap { slideImage(logicalIndex: $0) }
                guard !imgs.isEmpty else {
                    videoExportErrorMessage = "Could not render any slides for video."
                    showVideoExportError = true
                    return
                }
                let url = try await YearInReviewVideoExporter.exportVideo(
                    slideImages: imgs,
                    limitedSlideCount: Self.exportVideoLimitedSlideCount
                )
                videoExportURL = url
                showVideoShare = true
            } catch {
                videoExportErrorMessage = error.localizedDescription
                showVideoExportError = true
            }
        }
    }

    private func beginYearReviewRegenerate() {
        let hasCover = (pet.profileImage.map { !$0.isEmpty } ?? false)
        if hasCover {
            showYIRCoverRegeneratePrompt = true
        } else {
            Task { await runYearReviewRegenerate() }
        }
    }

    @MainActor
    private func runYearReviewRegenerate() async {
        busyOverlayMessage = "Writing something new…"
        isBusy = true
        editedHeadline = nil
        editedPersonalityLine = nil
        defer {
            isBusy = false
            busyOverlayMessage = ""
        }
        _ = try? await YearInReviewDataService.generateOrUpdate(
            pet: pet,
            year: year,
            modelContext: modelContext,
            appleHealthSummary: appleHealth.summary,
            forceRefreshAI: true
        )
        hintToken = UUID()
    }
}

// MARK: - Edit quote sheet

private struct YearInReviewLineEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let maxLength: Int
    let initialText: String
    let onSave: (String) -> Void
    let onResetToAI: () -> Void

    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                TextEditor(text: $text)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(uiColor: .secondarySystemGroupedBackground)))
                    .frame(minHeight: 120)
                    .onChange(of: text) { _, new in
                        if new.count > maxLength {
                            text = String(new.prefix(maxLength))
                        }
                    }
                Text("\(text.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                Button("Reset to AI version") {
                    onResetToAI()
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .onAppear {
                text = initialText
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(t)
                        dismiss()
                    }
                }
            }
        }
    }
}
#endif

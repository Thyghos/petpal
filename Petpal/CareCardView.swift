// CareCardView.swift
// Full-screen Care Card: quick square export + pet care info sections, share/save.

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
import Photos
import QuickLook
#endif

#if os(iOS)
struct CareCardView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    /// Used only for Pet Care Info export / detail (not for the Quick Care Card passport).
    @Query private var sitterInstructions: [PetSitterInstructions]

    @State private var quickRenderedImage: UIImage?
    @State private var quickShareURL: URL?
    @State private var quickSharePDFURL: URL?
    @State private var careInfoRenderedImage: UIImage?
    @State private var careInfoShareURL: URL?
    @State private var isRenderingQuick = false
    @State private var isRenderingCareInfo = false
    @State private var saveAlertTitle = ""
    @State private var saveAlertMessage = ""
    @State private var showSaveAlert = false
    @State private var isSavingCareInfo = false
    @State private var shareAllPayload: ShareSheetPayload?
    @State private var quickShareSheetPayload: ShareSheetPayload?
    @State private var showShareCareCardChoice = false
    @State private var isPreparingCareCardShare = false
    @State private var showingSitterEdit = false
    @State private var showingPetCareInfoDetail = false
    @State private var showingCareCardEdit = false
    @State private var cardSettings = CareCardFieldSettings.defaults
    @State private var careCardFullscreenImage: CareCardFullscreenImageItem?
    @State private var careCardPdfPreview: CareCardPdfPreviewItem?

    // Quick Care Card pinch zoom (replaces ZoomableCardPreview for this screen only)
    @State private var cardScale: CGFloat = 1.0
    @State private var lastCardScale: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0
    var onEditProfileRequested: (() -> Void)?

    /// When non-`nil`, Care Card content is pinned to this pet (e.g. opened from the Pet tab hero).
    private let explicitPetId: UUID?
    /// Same `Pet` instance passed into the initializer (hero/sheet) so we match Edit Pet even if `@Query` is briefly empty.
    private let seededPet: Pet?

    init(pet: Pet? = nil, onEditProfileRequested: (() -> Void)? = nil) {
        self.explicitPetId = pet?.id
        self.seededPet = pet
        self.onEditProfileRequested = onEditProfileRequested
    }

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var resolvedPetId: UUID? {
        if let id = explicitPetId { return id }
        return ActivePetResolver.resolvedPetId(pets: sortedPets)
    }

    /// Same active pet as Edit Pet / Pet tab: explicit sheet pet id, else `ActivePetResolver` + `@Query` match.
    private var resolvedPet: Pet? {
        guard let id = resolvedPetId else { return nil }
        if let match = pets.first(where: { $0.id == id }) {
            return match
        }
        if let s = seededPet, s.id == id {
            return s
        }
        return nil
    }

    private var sitterForPet: PetSitterInstructions? {
        guard let pid = resolvedPetId else { return nil }
        return sitterInstructions.first { $0.petId == pid }
    }

    /// Quick Care Card uses **Edit Pet profile fields only** (see `PassportData`).
    private var passportData: PassportData? {
        guard let pet = resolvedPet else { return nil }
        return PassportData(pet: pet)
    }

    /// Field toggles from `cardSettings` but never legacy card-only vet overrides — passport always shows live `pet.vet*`.
    private var passportDisplaySettings: CareCardFieldSettings {
        var s = cardSettings
        s.customVetName = nil
        s.customVetPhone = nil
        s.customVetEmail = nil
        return s
    }

    /// Medication lines from manual `MedicationEntry` rows only (for Pet Care Info export).
    private var medicationLines: [String] {
        guard let pet = resolvedPet else { return [] }
        return pet.medicationsArray.map { m -> String in
            let n = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = m.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            let f = m.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = n.isEmpty ? "Medication" : n
            if a.isEmpty && f.isEmpty { return title }
            if f.isEmpty { return "\(title) — \(a)" }
            if a.isEmpty { return "\(title) — \(f)" }
            return "\(title) — \(a) · \(f)"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let pet = resolvedPet, let data = passportData {
                    careScrollContent(pet: pet, data: data)
                } else {
                    ContentUnavailableView(
                        "No Pet Selected",
                        systemImage: "pawprint",
                        description: Text("Add or select a pet first.")
                    )
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(resolvedPet.map { "\($0.name.isEmpty ? "Pet" : $0.name)'s Care Card" } ?? "Care Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Edit") {
                        HapticManager.shared.light()
                        showingCareCardEdit = true
                    }
                    Button("Share All") {
                        shareBothPNGs()
                    }
                    .disabled(passportData == nil || sitterForPet == nil || isRenderingQuick || isRenderingCareInfo)
                }
            }
        }
        .alert(saveAlertTitle, isPresented: $showSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveAlertMessage)
        }
        #if os(iOS)
        .sheet(item: $shareAllPayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(item: $quickShareSheetPayload) { payload in
            ShareSheet(items: payload.items)
        }
        .sheet(isPresented: $showingSitterEdit) {
            FoodRecommendationsView()
        }
        .sheet(isPresented: $showingCareCardEdit) {
            if let pet = resolvedPet,
               let pid = resolvedPetId {
                CareCardEditView(
                    pet: pet,
                    petId: pid,
                    settings: $cardSettings
                )
            } else {
                Text("No pet selected")
                    .padding()
            }
        }
        .fullScreenCover(item: $careCardFullscreenImage) { item in
            CareCardAttachmentFullscreenImageShell(image: item.image) {
                careCardFullscreenImage = nil
            }
        }
        .sheet(item: $careCardPdfPreview) { item in
            NavigationStack {
                CareCardQuickLookPreview(url: item.previewURL)
                    .ignoresSafeArea()
                    .navigationTitle(item.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                try? FileManager.default.removeItem(at: item.previewURL)
                                careCardPdfPreview = nil
                            }
                        }
                    }
            }
            .onDisappear {
                try? FileManager.default.removeItem(at: item.previewURL)
            }
        }
        .sheet(isPresented: $showingPetCareInfoDetail) {
            NavigationStack {
                Group {
                    if let pet = resolvedPet, let sitter = sitterForPet {
                        ScrollView {
                            petCareInfoDeepContent(pet: pet, sitter: sitter)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                        }
                        .background(Color(.systemGroupedBackground).ignoresSafeArea())
                        .navigationTitle("Pet Care Info")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showingPetCareInfoDetail = false }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button("Edit") {
                                    showingPetCareInfoDetail = false
                                    showingSitterEdit = true
                                }
                            }
                        }
                    } else {
                        ContentUnavailableView("Pet Care Info", systemImage: "list.bullet.clipboard", description: Text("Loading…"))
                            .onAppear { ensureSitterInstructionsRow() }
                    }
                }
            }
        }
        #endif
    }

    private func ensureSitterInstructionsRow() {
        guard let pid = resolvedPetId else { return }
        if !sitterInstructions.contains(where: { $0.petId == pid }) {
            modelContext.insert(PetSitterInstructions(petId: pid))
            try? modelContext.save()
        }
    }

    /// Loads toggles from `CareCardFieldSettings` but drops legacy card-only vet overrides so the passport uses live `pet.vetName` / `vetPhone` / `vetEmail` (same as Edit Pet).
    private func reloadCardSettingsUsingLivePetVetFields(petId: UUID) {
        var s = CareCardFieldSettings.load(for: petId)
        s.customVetName = nil
        s.customVetPhone = nil
        s.customVetEmail = nil
        cardSettings = s
        CareCardFieldSettings.save(s, for: petId)
    }

    private var quickCareCardEffectiveScale: CGFloat {
        min(max(lastCardScale * pinchScale, 1.0), 4.0)
    }

    private func careCardDebugVetLog(for pet: Pet) {
        let vetForLog: String? = pet.vetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : pet.vetName
        let _ = print("[CareCard] pet.id=\(pet.persistentModelID) vetName=\(vetForLog ?? "nil")")
    }

    private func livePassportPreviewCard(data: PassportData, contentW: CGFloat, contentH: CGFloat) -> some View {
        careCardDebugVetLog(for: data.pet)
        return PetPassportCard(
            data: data,
            fieldSettings: passportDisplaySettings,
            displayWidth: contentW,
            displayHeight: contentH,
            onAttachmentTap: { att in
                presentCareCardAttachmentPreview(att)
            }
        )
        .environment(\.displayScale, displayScale)
        .frame(width: contentW, alignment: .top)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func presentCareCardAttachmentPreview(_ att: PetAttachment) {
        print("[CareCard] attachment tapped: \(att.name)")
        let displayName = att.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Attachment" : att.name
        if att.careCardIsLikelyPDF() {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("carecard-\(att.id.uuidString).pdf")
            do {
                try att.data.write(to: url, options: .atomic)
                careCardPdfPreview = CareCardPdfPreviewItem(id: att.id, previewURL: url, name: displayName)
                careCardFullscreenImage = nil
            } catch {
                return
            }
            return
        }
        if let img = UIImage(data: att.data) {
            careCardFullscreenImage = CareCardFullscreenImageItem(id: att.id, image: img, name: displayName)
            careCardPdfPreview = nil
        }
    }

    @ViewBuilder
    private func quickCareCardPinchZoomPreview(data: PassportData) -> some View {
        let s = quickCareCardEffectiveScale
        GeometryReader { geo in
            let fitWidth = max(geo.size.width, 1)
            let fitHeight = fitWidth * (1350.0 / 1080.0)
            let contentW = fitWidth * s
            let contentH = fitHeight * s
            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                livePassportPreviewCard(data: data, contentW: contentW, contentH: contentH)
                    .frame(width: contentW, alignment: .top)
                    .frame(minWidth: fitWidth, minHeight: max(fitHeight, contentH), alignment: .topLeading)
            }
            .frame(width: fitWidth, height: fitHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .scrollDisabled(s <= 1.001)
            .simultaneousGesture(
                MagnificationGesture()
                    .updating($pinchScale) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let next = min(max(lastCardScale * value, 1.0), 4.0)
                        lastCardScale = next
                        cardScale = next
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    cardScale = 1.0
                    lastCardScale = 1.0
                }
            }
            .animation(.interactiveSpring(), value: pinchScale)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1080.0 / 1350.0, contentMode: .fit)
        .clipped()
    }

    @ViewBuilder
    private func careScrollContent(pet: Pet, data: PassportData) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    quickCareCardPinchZoomPreview(data: data)
                        .frame(maxWidth: .infinity)
                    if isRenderingQuick && quickRenderedImage == nil {
                        ProgressView("Rendering…")
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                quickActionButtons
                    .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            ensureSitterInstructionsRow()
            if let pid = resolvedPetId {
                reloadCardSettingsUsingLivePetVetFields(petId: pid)
            }
            scheduleQuickRender(data: data)
            if let s = sitterForPet {
                scheduleCareInfoRender(pet: pet, sitter: s)
            }
        }
        .onChange(of: resolvedPetId) { _, newId in
            cardScale = 1.0
            lastCardScale = 1.0
            if let id = newId {
                reloadCardSettingsUsingLivePetVetFields(petId: id)
            }
            if let data = passportData, let p = resolvedPet, let s = sitterForPet {
                scheduleQuickRender(data: data)
                scheduleCareInfoRender(pet: p, sitter: s)
            }
        }
        .onChange(of: cardSettings) { _, _ in
            if let data = passportData {
                scheduleQuickRender(data: data)
            }
        }
        .confirmationDialog(
            "Share Care Card",
            isPresented: $showShareCareCardChoice,
            titleVisibility: .visible
        ) {
            Button("Share as PDF") {
                HapticManager.shared.light()
                shareCareCardAsPDF()
            }
            Button("Share as Photo") {
                HapticManager.shared.light()
                shareCareCardAsPhoto()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("PDF is recommended for best quality")
        }
        .overlay {
            if isPreparingCareCardShare {
                ZStack {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView("Preparing…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .allowsHitTesting(true)
            }
        }
    }

    private var quickActionButtons: some View {
        VStack(spacing: 12) {
            Button {
                HapticManager.shared.light()
                showShareCareCardChoice = true
            } label: {
                Label("Share Card", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("BrandOrange"))
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(passportData == nil || isRenderingQuick || isPreparingCareCardShare)
        }
    }

    /// Single-page Care Card PDF for share: `PetName-CareCard.pdf` (hyphen before `CareCard`).
    private static func careCardShareSinglePDFFileName(petName: String) -> String {
        let raw = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = raw.isEmpty ? "Pet" : raw.replacingOccurrences(of: "/", with: "-")
        return "\(stem)-CareCard.pdf"
    }

    private func shareCareCardAsPDF() {
        guard let data = passportData else { return }
        isPreparingCareCardShare = true
        Task { @MainActor in
            defer { isPreparingCareCardShare = false }
            let img = quickRenderedImage
                ?? snapshotPassport(data: data, fieldSettings: passportDisplaySettings, displayScale: displayScale)
            guard let img else { return }
            let fileName = Self.careCardShareSinglePDFFileName(petName: resolvedPet?.name ?? "")
            guard let pdfURL = PrintShareHelper.writeSinglePagePDF(from: img, fileName: fileName) else { return }
            quickShareSheetPayload = ShareSheetPayload(items: [pdfURL])
        }
    }

    private func shareCareCardAsPhoto() {
        guard let data = passportData else { return }
        isPreparingCareCardShare = true
        Task { @MainActor in
            defer { isPreparingCareCardShare = false }
            let img = quickRenderedImage
                ?? snapshotPassport(data: data, fieldSettings: passportDisplaySettings, displayScale: displayScale)
            guard let img else { return }
            quickShareSheetPayload = ShareSheetPayload(items: [img])
        }
    }

    @ViewBuilder
    private func petCareInfoDeepContent(pet: Pet, sitter: PetSitterInstructions) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Feeding → Routine → Medical → Behavior → Emergency (see `careInfoGroups`).
            // No live 1080×1920 card preview here — export uses `ImageRenderer` in `scheduleCareInfoRender`
            // so Share / Save stay fast without an oversized on-screen preview.
            careInfoGroups(pet: pet, sitter: sitter)

            if isRenderingCareInfo && careInfoRenderedImage == nil {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparing shareable Pet Care Info card…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }

            VStack(spacing: 12) {
                if let url = careInfoShareURL {
                    ShareLink(
                        item: url,
                        preview: SharePreview("Pet Care Info", image: careInfoSharePreviewImage)
                    ) {
                        Label("Share Card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BrandOrange"))
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                } else {
                    Button {
                        scheduleCareInfoRender(pet: pet, sitter: sitter)
                    } label: {
                        Label("Share Card", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color("BrandOrange").opacity(0.85))
                            .foregroundStyle(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .disabled(isRenderingCareInfo)
                }

                Button {
                    Task { await saveCareInfoToPhotos() }
                } label: {
                    Group {
                        if isSavingCareInfo {
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
                .disabled(isRenderingCareInfo || careInfoRenderedImage == nil || isSavingCareInfo)
            }
        }
        .padding(.bottom, 24)
        .onAppear {
            scheduleCareInfoRender(pet: pet, sitter: sitter)
        }
    }

    @ViewBuilder
    private func careInfoGroups(pet: Pet, sitter: PetSitterInstructions) -> some View {
        VStack(spacing: 14) {
            careGroupCard(title: "Feeding") {
                careRow("Food brand & flavor", sitter.favoriteFood)
                careRow("Amount per meal", sitter.foodAmount)
                careRow("Feeding times", sitter.foodSchedule)
                careRow("Add-ons or supplements", sitter.foodAddons)
                careRow("Treats", joinOptional(sitter.favoriteTreats, sitter.treatAmount))
                careRow("Treat schedule", sitter.treatSchedule)
            }
            careGroupCard(title: "Routine") {
                careRow("Walk schedule", sitter.walkSchedule)
                careRow("Exercise", sitter.walkDuration)
            }
            careGroupCard(title: "Medical") {
                if medicationLines.isEmpty {
                    Text("No medications in Edit Pet profile.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(medicationLines, id: \.self) { line in
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                    }
                }
                careRow("Medications (notes)", sitter.medications)
                careRow("Allergies", sitter.allergies)
                if let vn = sitter.vetName, !vn.isEmpty {
                    HStack {
                        Text(vn)
                            .font(.subheadline.weight(.medium))
                        if let p = sitter.vetPhone, !p.isEmpty {
                            let digits = p.filter { $0.isNumber }
                            if let url = URL(string: "tel://\(digits)") {
                                Link(p, destination: url)
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            }
            careGroupCard(title: "Behavior") {
                if !pet.specialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Special notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(pet.specialNotes)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text(sitter.specialInstructions.isEmpty ? "—" : sitter.specialInstructions)
                    .font(.subheadline)
                    .foregroundStyle(Color.primary)
            }
            emergencyProfileGroup(pet: pet)
        }
    }

    @ViewBuilder
    private func emergencyProfileGroup(pet: Pet) -> some View {
        let en = pet.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)
        let ep = pet.emergencyContactNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if en.isEmpty && ep.isEmpty {
            EmptyView()
        } else {
            careGroupCard(title: "Emergency") {
                careRow("Contact", joinOptional(en, ep))
            }
        }
    }

    private func careGroupCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(Color("BrandOrange"))
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.35 : 0.06), radius: 8, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }

    private func careRow(_ title: String, _ value: String?) -> some View {
        Group {
            if let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(v)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)
                }
            }
        }
    }

    private func joinOptional(_ a: String?, _ b: String?) -> String? {
        let x = a?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let y = b?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if x.isEmpty && y.isEmpty { return nil }
        if x.isEmpty { return y }
        if y.isEmpty { return x }
        return "\(x) · \(y)"
    }

    private func scheduleQuickRender(data: PassportData) {
        isRenderingQuick = true
        quickRenderedImage = nil
        quickShareURL = nil
        quickSharePDFURL = nil
        Task { @MainActor in
            let img = snapshotPassport(data: data, fieldSettings: passportDisplaySettings, displayScale: displayScale)
            quickRenderedImage = img
            if let img {
                quickShareURL = writeTempPNG(image: img, prefix: "PetCareCard-Quick")
                let petName = resolvedPet?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let pdfName = Self.careCardPDFFileName(petName: petName)
                quickSharePDFURL = PrintShareHelper.writeSinglePagePDF(from: img, fileName: pdfName)
            }
            isRenderingQuick = false
        }
    }

    private func scheduleCareInfoRender(pet: Pet, sitter: PetSitterInstructions) {
        isRenderingCareInfo = true
        careInfoRenderedImage = nil
        careInfoShareURL = nil
        Task { @MainActor in
            let img = snapshotCareInfo(
                pet: pet,
                sitter: sitter,
                emergency: nil,
                meds: medicationLines,
                displayScale: displayScale
            )
            careInfoRenderedImage = img
            if let img {
                careInfoShareURL = writeTempPNG(image: img, prefix: "PetCareInfo")
            }
            isRenderingCareInfo = false
        }
    }

    private var careInfoSharePreviewImage: Image {
        if let img = careInfoRenderedImage {
            return Image(uiImage: img)
        }
        return Image(systemName: "square.and.arrow.up")
    }

    private func shareBothPNGs() {
        guard let data = passportData,
              let pet = resolvedPet,
              let sitter = sitterForPet else { return }
        guard let q = quickRenderedImage ?? snapshotPassport(data: data, fieldSettings: passportDisplaySettings, displayScale: displayScale) else { return }
        guard let care = careInfoRenderedImage ?? snapshotCareInfo(
            pet: pet,
            sitter: sitter,
            emergency: nil,
            meds: medicationLines,
            displayScale: displayScale
        ) else { return }
        guard let u1 = writeTempPNG(image: q, prefix: "CareCard-Quick"),
              let u2 = writeTempPNG(image: care, prefix: "CareCard-Info") else { return }
        let pdfName = Self.careCardPDFFileName(petName: pet.name)
        let pdfURL = quickSharePDFURL ?? PrintShareHelper.writeSinglePagePDF(from: q, fileName: pdfName)
        var items: [Any] = [u1, u2]
        if let pdfURL {
            items.append(pdfURL)
        }
        shareAllPayload = ShareSheetPayload(items: items)
    }

    private static func careCardPDFFileName(petName: String) -> String {
        let raw = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let stem = raw.isEmpty ? "Pet" : raw.replacingOccurrences(of: "/", with: "-")
        return "\(stem)_CareCard.pdf"
    }

    private func snapshotPassport(data: PassportData, fieldSettings: CareCardFieldSettings, displayScale: CGFloat) -> UIImage? {
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
        renderer.scale = max(displayScale, 3.0)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: nil)
        return renderer.uiImage
    }

    private func snapshotCareInfo(
        pet: Pet,
        sitter: PetSitterInstructions,
        emergency: EmergencyProfile?,
        meds: [String],
        displayScale: CGFloat
    ) -> UIImage? {
        let content = PetCareInfoCardView(
            pet: pet,
            instructions: sitter,
            emergencyProfile: emergency,
            medicationLines: meds
        )
        .environment(\.displayScale, displayScale)
        .frame(width: 1080, height: 1920)
        let renderer = ImageRenderer(content: content)
        renderer.scale = max(displayScale, 3.0)
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }

    private func writeTempPNG(image: UIImage, prefix: String) -> URL? {
        guard let data = image.pngData() else { return nil }
        let name = "\(prefix)-\(UUID().uuidString).png"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private func saveCareInfoToPhotos() async {
        guard let image = careInfoRenderedImage else { return }
        isSavingCareInfo = true
        defer { isSavingCareInfo = false }
        let status = await requestPhotoAddAccess()
        guard status == .authorized || status == .limited else {
            saveAlertTitle = "Photos Access Needed"
            saveAlertMessage = "Allow Petpal to add photos in Settings to save Pet Care Info."
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

// MARK: - Care Card attachment preview (fullscreen image / PDF sheet)

private struct CareCardFullscreenImageItem: Identifiable {
    let id: UUID
    let image: UIImage
    let name: String
}

private struct CareCardPdfPreviewItem: Identifiable {
    let id: UUID
    let previewURL: URL
    let name: String
}

private struct CareCardQuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let q = QLPreviewController()
        q.dataSource = context.coordinator
        return q
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}

private struct CareCardAttachmentFullscreenImageShell: View {
    let image: UIImage
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            CareCardPinchZoomScrollImageView(image: image)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.white, Color.black.opacity(0.45))
            }
            .accessibilityLabel("Dismiss")
            .padding(16)
        }
    }
}

/// Pinch-to-zoom image using `UIScrollView` (same pattern as profile attachment zoom).
private struct CareCardPinchZoomScrollImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        imageView.image = image
        let size = scrollView.bounds.size
        guard size.width > 1, size.height > 1 else { return }

        let prevSize = context.coordinator.lastLayoutSize
        let needsLayout = prevSize != size

        if needsLayout {
            context.coordinator.lastLayoutSize = size
            let imgSize = image.size
            let widthRatio = size.width / imgSize.width
            let heightRatio = size.height / imgSize.height
            let scale = min(widthRatio, heightRatio, 1)
            let fitSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)

            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            scrollView.zoomScale = 1.0
            let insetH = max(0, (size.width - fitSize.width) / 2)
            let insetV = max(0, (size.height - fitSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetV, left: insetH, bottom: insetV, right: insetH)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        var lastLayoutSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard imageView != nil else { return }
            let size = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            let insetH = max(0, (size.width - contentSize.width) / 2)
            let insetV = max(0, (size.height - contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetV, left: insetH, bottom: insetV, right: insetH)
        }
    }
}
#else
struct CareCardView: View {
    var pet: Pet?
    var onEditProfileRequested: (() -> Void)?

    init(pet: Pet? = nil, onEditProfileRequested: (() -> Void)? = nil) {
        self.pet = pet
        self.onEditProfileRequested = onEditProfileRequested
    }

    var body: some View {
        Text("Care Card is available on iOS.")
    }
}
#endif

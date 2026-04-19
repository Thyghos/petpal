// Petpal — Feature screens (local data + curated content; no “coming soon”)

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

// MARK: - Health History

struct HealthHistoryView: View {
    @ObservedObject private var pdfImportCoordinator = PDFImportCoordinator.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var visits: [VetVisitLog]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @Query(sort: \PetRecordAttachment.createdAt, order: .reverse) private var attachmentRows: [PetRecordAttachment]

    @State private var showingAdd = false
    @State private var searchText = ""
    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: pets)
    }
    
    /// Visits for the selected / active pet only.
    private var petScopedVisits: [VetVisitLog] {
        guard let pid = scopedPetId else { return [] }
        return visits.filter { $0.petId == pid }
    }

    /// Rows to show: when not searching, every visit with no match metadata; when searching, only visits that match any searchable field, with which fields matched.
    private var visitsToShow: [(visit: VetVisitLog, matchFields: Set<HealthHistoryMatchField>)] {
        if trimmedQuery.isEmpty {
            return petScopedVisits.map { (visit: $0, matchFields: []) }
        }
        return petScopedVisits.compactMap { visit in
            let fields = Self.computeMatchFields(for: visit, query: trimmedQuery, attachments: attachmentsForVisit(visit.id))
            return fields.isEmpty ? nil : (visit: visit, matchFields: fields)
        }
    }

    private func attachmentsForVisit(_ visitId: UUID) -> [PetRecordAttachment] {
        attachmentRows.filter {
            $0.parentRecordId == visitId && $0.parentKind == PetRecordAttachmentParentKind.vetVisit.rawValue
        }
    }

    private var visitIdsWithAttachments: Set<UUID> {
        Set(
            attachmentRows
                .filter { $0.parentKind == PetRecordAttachmentParentKind.vetVisit.rawValue }
                .map(\.parentRecordId)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    FeaturePetScopeHeader(pets: pets)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                #if os(iOS)
                Section {
                    vetRecordImportCard
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color("BrandOrange").opacity(0.18), lineWidth: 1)
                        )
                        .padding(.vertical, 4)
                )
                #endif

                Section {
                    InlineAddListRow(title: "Add Visit") { showingAdd = true }
                }

                if petScopedVisits.isEmpty {
                    Section {
                        Text("Log vaccines, checkups, and sick visits. Search across clinic, diagnoses, notes, dates, and attachment names (e.g. “rabies”).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ContentUnavailableView {
                            Label("No Visits Logged", systemImage: "heart.text.square.fill")
                        } description: {
                            Text("Tap + to add a visit. Attach vaccine records or receipts as photos or PDFs.")
                        } actions: {
                            Button("Add Visit") { showingAdd = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    Section {
                        if visitsToShow.isEmpty && !trimmedQuery.isEmpty {
                            ContentUnavailableView {
                                Label("No matches", systemImage: "magnifyingglass")
                            } description: {
                                Text("Nothing matches “\(trimmedQuery)”. Try another word.")
                            }
                        } else {
                            ForEach(visitsToShow, id: \.visit.id) { item in
                                NavigationLink {
                                    VetVisitDetailView(visit: item.visit)
                                } label: {
                                    healthHistoryVisitRow(
                                        visit: item.visit,
                                        hasAttachment: visitIdsWithAttachments.contains(item.visit.id),
                                        matchFields: item.matchFields
                                    )
                                }
                                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 10))
                            }
                            .onDelete(perform: deleteVisits)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search visits, notes…")
            .navigationTitle("Health History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        pdfImportCoordinator.showImportSourceOptionsVetRecord(pets: pets)
                    } label: {
                        Label("Import Record", systemImage: "doc.badge.arrow.up")
                    }
                    .accessibilityLabel("Import record")

                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add visit")

                    Menu {
                        Button {
                            let printable = HealthHistoryPrintableView(visits: petScopedVisits)
                                .frame(width: 400, height: 600)
                            if let img = PrintShareHelper.renderToImage(printable) {
                                let text = "Health history — \(petScopedVisits.count) visit(s)"
                                DispatchQueue.main.async {
                                    sharePayload = ShareSheetPayload(items: [img, text])
                                }
                            }
                        } label: {
                            Label("Share all visits", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            let printable = HealthHistoryPrintableView(visits: petScopedVisits)
                                .frame(width: 400, height: 600)
                            DispatchQueue.main.async {
                                PrintShareHelper.printView(printable, title: "Health History")
                            }
                        } label: {
                            Label("Print all visits", systemImage: "printer")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingAdd) {
                VetVisitEditorView()
            }
            #if os(iOS)
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            #endif
            .onAppear {
                migrateLegacyVetVisitsIfNeeded()
            }
        }
    }
    
    /// Older visits had `petId == nil` and appeared under every pet. Assign them once to a single pet (active, or only pet, or oldest added).
    private func migrateLegacyVetVisitsIfNeeded() {
        let orphans = visits.filter { $0.petId == nil }
        guard !orphans.isEmpty, !pets.isEmpty else { return }
        let targetId: UUID
        if pets.count == 1 {
            targetId = pets[0].id
        } else if let aid = ActivePetStorage.activePetUUID, pets.contains(where: { $0.id == aid }) {
            targetId = aid
        } else if let first = pets.sorted(by: { $0.dateAdded < $1.dateAdded }).first {
            targetId = first.id
        } else {
            return
        }
        for v in orphans {
            v.petId = targetId
        }
        try? modelContext.save()
    }

    private func deleteVisits(at offsets: IndexSet) {
        let targets = offsets.map { visitsToShow[$0].visit }
        for v in targets {
            PetRecordAttachment.deleteAll(parentRecordId: v.id, parentKind: .vetVisit, context: modelContext)
            modelContext.delete(v)
        }
    }

    #if os(iOS)
    private var vetRecordImportCard: some View {
        Button {
            HapticManager.shared.light()
            pdfImportCoordinator.showImportSourceOptionsVetRecord(pets: pets)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 8) {
                    healthHistoryImportGradientIcon(
                        systemImage: "camera.fill",
                        gradient: [Color("BrandOrange"), Color("BrandOrange").opacity(0.65)]
                    )
                    healthHistoryImportGradientIcon(
                        systemImage: "doc.badge.arrow.up",
                        gradient: [Color("BrandBlue"), Color("BrandBlue").opacity(0.65)]
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Import a vet record")
                        .font(.headline)
                        .foregroundStyle(Color("BrandDark"))
                    Text("Take a photo or import a PDF — we'll fill it in for you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Import a vet record")
    }

    private func healthHistoryImportGradientIcon(systemImage: String, gradient: [Color]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 44, height: 44)
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
        }
    }
    #endif

    @ViewBuilder
    private func healthHistoryVisitRow(visit: VetVisitLog, hasAttachment: Bool, matchFields: Set<HealthHistoryMatchField>) -> some View {
        let clinic = visit.clinicName.isEmpty ? "Visit" : visit.clinicName
        let showMatchHint = !trimmedQuery.isEmpty && !matchFields.isEmpty
        let notesPreview = Self.notesSearchPreview(visit.notes, maxLen: 160)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                healthHistoryHighlightedLine(
                    visit.visitDate.formatted(.dateTime.month(.abbreviated).day().year()),
                    font: .system(size: 17, weight: .semibold),
                    baseColor: Color.primary
                )
                if hasAttachment {
                    Image(systemName: "paperclip")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
            healthHistoryHighlightedLine(clinic, font: .system(size: 14, weight: .regular), baseColor: Color.secondary)
            if !visit.reason.isEmpty {
                healthHistoryHighlightedLine(visit.reason, font: .system(size: 13, weight: .regular), baseColor: Color.secondary)
                    .lineLimit(1)
            }
            if showMatchHint, matchFields.contains(.notes), !notesPreview.isEmpty {
                healthHistoryHighlightedLine(notesPreview, font: .system(size: 12, weight: .regular), baseColor: Color.secondary)
                    .lineLimit(2)
            }
            if showMatchHint {
                Text("Matched in: \(Self.matchFieldLabels(matchFields))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Search matched in \(Self.matchFieldLabels(matchFields))")
            }
        }
    }

    @ViewBuilder
    private func healthHistoryHighlightedLine(_ string: String, font: Font, baseColor: Color) -> some View {
        let q = trimmedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = Self.searchHighlightParts(in: string, query: q)
        if parts.isEmpty {
            Text(string).font(font).foregroundStyle(baseColor)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    Text(part.text)
                        .font(font)
                        .foregroundStyle(part.isMatch ? Color("BrandOrange") : baseColor)
                        .fontWeight(part.isMatch ? .semibold : .regular)
                }
            }
        }
    }

    /// Split `full` around case-insensitive `query` matches for search highlighting (replaces deprecated `Text` + `Text`).
    private static func searchHighlightParts(in full: String, query: String) -> [(text: String, isMatch: Bool)] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty, !full.isEmpty else { return [] }
        var out: [(text: String, isMatch: Bool)] = []
        var remainder = Substring(full)
        while let range = remainder.range(of: q, options: .caseInsensitive) {
            if range.lowerBound > remainder.startIndex {
                out.append((String(remainder[..<range.lowerBound]), false))
            }
            out.append((String(remainder[range]), true))
            remainder = remainder[range.upperBound...]
        }
        if !remainder.isEmpty {
            out.append((String(remainder), false))
        }
        return out
    }

    private static func dateSearchStrings(for date: Date) -> [String] {
        let medium = DateFormatter()
        medium.dateStyle = .medium
        medium.timeStyle = .none
        let short = DateFormatter()
        short.dateStyle = .short
        short.timeStyle = .none
        let y = DateFormatter()
        y.locale = Locale(identifier: "en_US_POSIX")
        y.dateFormat = "yyyy"
        let isoDay = DateFormatter()
        isoDay.locale = Locale(identifier: "en_US_POSIX")
        isoDay.dateFormat = "yyyy-MM-dd"
        return [
            medium.string(from: date),
            short.string(from: date),
            y.string(from: date),
            isoDay.string(from: date)
        ]
    }

    private static func notesSearchPreview(_ notes: String, maxLen: Int) -> String {
        let t = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }
        if t.count <= maxLen { return t }
        let idx = t.index(t.startIndex, offsetBy: maxLen)
        return String(t[..<idx]) + "…"
    }

    private static func matchFieldLabels(_ fields: Set<HealthHistoryMatchField>) -> String {
        fields.sorted(by: { $0.sortIndex < $1.sortIndex }).map(\.label).joined(separator: ", ")
    }

    /// Which parts of this visit matched `query` (case-insensitive substring).
    private static func computeMatchFields(
        for visit: VetVisitLog,
        query: String,
        attachments: [PetRecordAttachment]
    ) -> Set<HealthHistoryMatchField> {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var out = Set<HealthHistoryMatchField>()
        if visit.clinicName.localizedCaseInsensitiveContains(q) { out.insert(.clinic) }
        if visit.reason.localizedCaseInsensitiveContains(q) { out.insert(.reason) }
        if visit.notes.localizedCaseInsensitiveContains(q) { out.insert(.notes) }
        for s in dateSearchStrings(for: visit.visitDate) where s.localizedCaseInsensitiveContains(q) {
            out.insert(.visitDate)
            break
        }
        for a in attachments {
            if a.displayFileName.localizedCaseInsensitiveContains(q) || a.sourceNote.localizedCaseInsensitiveContains(q) {
                out.insert(.attachment)
                break
            }
        }
        return out
    }
}

// MARK: - Health history search match fields

private enum HealthHistoryMatchField: Hashable, Sendable {
    case clinic
    case reason
    case notes
    case visitDate
    case attachment

    var sortIndex: Int {
        switch self {
        case .clinic: return 0
        case .reason: return 1
        case .notes: return 2
        case .visitDate: return 3
        case .attachment: return 4
        }
    }

    var label: String {
        switch self {
        case .clinic: return "Clinic / title"
        case .reason: return "Reason / diagnosis"
        case .notes: return "Notes"
        case .visitDate: return "Visit date"
        case .attachment: return "Attachment"
        }
    }
}

private struct HealthHistoryPrintableView: View {
    let visits: [VetVisitLog]

    private var heading: String {
        visits.count == 1 ? "Vet visit" : "Health History"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(heading)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.black)
            Divider()
            ForEach(visits) { visit in
                VStack(alignment: .leading, spacing: 4) {
                    Text(visit.clinicName.isEmpty ? "Visit" : visit.clinicName)
                        .font(.headline)
                        .foregroundStyle(Color.black)
                    Text(visit.visitDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(Color.black.opacity(0.7))
                    if !visit.reason.isEmpty {
                        Text(visit.reason)
                            .font(.subheadline)
                            .foregroundStyle(Color.black)
                    }
                    if !visit.notes.isEmpty {
                        Text(visit.notes)
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .preferredColorScheme(.light)
    }
}

struct VetVisitDetailView: View {
    @Bindable var visit: VetVisitLog
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif

    private var detailTitle: String {
        let n = visit.clinicName.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Visit" : n
    }

    var body: some View {
        Form {
            if !pets.isEmpty {
                Section {
                    Picker("This visit is for", selection: $visit.petId) {
                        Text("Not assigned").tag(nil as UUID?)
                        ForEach(pets) { pet in
                            Text(pet.name).tag(Optional(pet.id))
                        }
                    }
                    .accessibilityHint("Move this visit to another pet’s health history.")
                } header: {
                    Text("Pet")
                } footer: {
                    Text("Only visits assigned to a pet appear in that pet’s Health History list.")
                        .font(.footnote)
                }
            }
            Section("Visit") {
                TextField("Clinic / vet", text: $visit.clinicName)
                DatePicker("Date", selection: $visit.visitDate, displayedComponents: .date)
                TextField("Reason", text: $visit.reason, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Notes") {
                TextField("Notes", text: $visit.notes, axis: .vertical)
                    .lineLimit(3...10)
            }
            Section {
                Text("Tap ⋯ for Share this visit or Print (summary image). To send only a PDF or photo, long-press an attachment below or open it and tap Share.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            RecordAttachmentsSection(parentRecordId: visit.id, parentKind: .vetVisit)
        }
        .navigationTitle(detailTitle)
        .navigationBarTitleDisplayMode(.inline)
        #if os(iOS)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        let printable = HealthHistoryPrintableView(visits: [visit])
                            .frame(width: 400, height: 600)
                        if let img = PrintShareHelper.renderToImage(printable) {
                            let text = "Vet visit: \(detailTitle)"
                            DispatchQueue.main.async {
                                sharePayload = ShareSheetPayload(items: [img, text])
                            }
                        }
                    } label: {
                        Label("Share this visit", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        let printable = HealthHistoryPrintableView(visits: [visit])
                            .frame(width: 400, height: 600)
                        DispatchQueue.main.async {
                            PrintShareHelper.printView(printable, title: detailTitle)
                        }
                    } label: {
                        Label("Print this visit", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Share or print this visit")
            }
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        #endif
    }
}

struct VetVisitEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    #if os(iOS)
    @ObservedObject private var pdfImportCoordinator = PDFImportCoordinator.shared
    #endif

    @State private var draftRecordId: UUID?
    @State private var clinicName = ""
    @State private var visitDate = Date()
    @State private var reason = ""
    @State private var notes = ""

    @FocusState private var focusedField: VetVisitField?

    @State private var importCardDismissed = false
    @State private var showImportSuccessBanner = false
    @State private var showPartialParseHint = false
    @State private var documentHintMessage: String?
    @State private var importWeightKg: Double?
    @State private var pendingVaccineNames: [String] = []
    @State private var pendingImportedMedications: [ParsedMedication] = []
    /// Set when AI import succeeded; used to gate optional Pet Profile merge (never for purely manual visits).
    @State private var lastImportedParse: VetRecordParseResult?
    @State private var profileMergeProposal: VetVisitProfileUpdateProposal?
    @State private var pendingProfilePetId: UUID?
    @State private var pendingProfileVisitDate: Date?
    @State private var lastSavedVisitVaxCount = 0
    @State private var lastSavedVisitMedCount = 0
    @State private var showingVaccineReminderSetup = false
    @State private var vaccinesForReminderSetup: [String] = []
    @State private var reminderSetupVisitDate = Date()
    @State private var reminderSetupClinicName = ""
    @State private var reminderSetupCertificates: [PetCertificate] = []
    @State private var reminderSetupParsedHints: [ParsedVaccineDue] = []
    @State private var reminderSetupActivePet: Pet?
    @State private var lastEditorVaccineRemindersCreatedCount = 0

    #if os(iOS)
    @State private var showApiFailureAlert = false
    @State private var showApiConfigAlert = false
    #endif

    private enum VetVisitField: Hashable {
        case clinic
    }

    private var displayPetName: String {
        if let id = FeaturePetScope.resolvedPetId(pets: pets), let p = pets.first(where: { $0.id == id }) {
            return p.name.isEmpty ? "your pet" : p.name
        }
        return "your pet"
    }

    var body: some View {
        NavigationStack {
            Group {
                #if os(iOS)
                vetVisitEditorWithIOSAlerts
                #else
                vetVisitEditorConfiguredBase
                #endif
            }
            .toolbar { visitEditorToolbarContent }
        }
    }

    private var vetVisitEditorConfiguredBase: some View {
        visitEditorForm
            .navigationTitle("New Visit")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if draftRecordId == nil {
                    draftRecordId = UUID()
                }
            }
    }

    #if os(iOS)
    private var vetVisitEditorWithIOSAlerts: some View {
        vetVisitEditorConfiguredBase
            .onDisappear {
                pdfImportCoordinator.clearAddVisitImportHandler()
            }
            .alert("Could not read the record.", isPresented: $showApiFailureAlert) {
                Button("Retry") {
                    showApiFailureAlert = false
                    pdfImportCoordinator.retryLastExtraction()
                }
                Button("OK", role: .cancel) {
                    pdfImportCoordinator.clearAddVisitImportHandler()
                }
            } message: {
                Text("Check your connection and try again.")
            }
            .alert("Import unavailable", isPresented: $showApiConfigAlert) {
                Button("OK", role: .cancel) {
                    pdfImportCoordinator.clearAddVisitImportHandler()
                }
            } message: {
                Text("Add your Claude API key in Settings (or configure the Vet AI proxy) to import documents.")
            }
            .alert("Update Pet Profile?", isPresented: Binding(
                get: { profileMergeProposal != nil },
                set: { if !$0 { profileMergeProposal = nil } }
            )) {
                Button("Update Profile") {
                    finishProfileMerge(apply: true)
                }
                Button("Skip", role: .cancel) {
                    finishProfileMerge(apply: false)
                }
            } message: {
                if let prop = profileMergeProposal {
                    Text(profileMergeAlertMessage(petDisplayName: displayPetName, proposal: prop))
                }
            }
            .sheet(isPresented: $showingVaccineReminderSetup, onDismiss: {
                completeVisitAfterVaccineReminderSheet(reminderCount: lastEditorVaccineRemindersCreatedCount)
            }) {
                if let pet = reminderSetupActivePet, !vaccinesForReminderSetup.isEmpty {
                    VaccineReminderSetupSheet(
                        vaccines: vaccinesForReminderSetup,
                        visitDate: reminderSetupVisitDate,
                        clinicName: reminderSetupClinicName,
                        certificates: reminderSetupCertificates,
                        parsedDueHints: reminderSetupParsedHints,
                        activePet: pet,
                        onComplete: { count in
                            lastEditorVaccineRemindersCreatedCount = count
                        }
                    )
                    .presentationDragIndicator(.visible)
                }
            }
    }

    private func completeVisitAfterVaccineReminderSheet(reminderCount: Int) {
        let visitLine = PDFImportCoordinator.visitSavedToastLine(
            vaccineCount: lastSavedVisitVaxCount,
            medicationReminderCount: lastSavedVisitMedCount
        )
        if reminderCount > 0 {
            let base = visitLine.hasSuffix(" ✓") ? String(visitLine.dropLast(2)) : visitLine
            pdfImportCoordinator.showTransientSuccessToast("\(base) · \(reminderCount) vaccine reminder(s) set ✓")
        } else {
            pdfImportCoordinator.presentVisitOutcomeToast(
                vaccineCount: lastSavedVisitVaxCount,
                medicationReminderCount: lastSavedVisitMedCount
            )
        }
        pdfImportCoordinator.clearAddVisitImportHandler()
        dismiss()
    }
    #endif

    @ViewBuilder
    private var visitEditorForm: some View {
        Form {
            #if os(iOS)
            importChromeSections
            #endif
            Section {
                TextField("Clinic or veterinarian", text: $clinicName)
                    .focused($focusedField, equals: .clinic)
                DatePicker("Date", selection: $visitDate, displayedComponents: .date)
                TextField("Reason for visit", text: $reason, axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Notes") {
                TextField("Diagnosis, meds, follow-up…", text: $notes, axis: .vertical)
                    .lineLimit(3...10)
            }
            if let rid = draftRecordId {
                RecordAttachmentsSection(parentRecordId: rid, parentKind: .vetVisit)
            }
        }
    }

    @ToolbarContentBuilder
    private var visitEditorToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: visitEditorCancelTapped)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") {
                saveVisit()
            }
            .disabled(draftRecordId == nil)
        }
    }

    private func visitEditorCancelTapped() {
        if let rid = draftRecordId {
            PetRecordAttachment.deleteAll(parentRecordId: rid, parentKind: .vetVisit, context: modelContext)
        }
        #if os(iOS)
        pdfImportCoordinator.clearAddVisitImportHandler()
        #endif
        dismiss()
    }

    #if os(iOS)
    private func profileMergeAlertMessage(petDisplayName: String, proposal: VetVisitProfileUpdateProposal) -> String {
        """
        We found the following info in your vet visit record:

        \(proposal.detailMessage)

        Would you like to update \(petDisplayName)'s profile and Care Card with this information?
        """
    }

    private func finishProfileMerge(apply: Bool) {
        guard let proposal = profileMergeProposal,
              let pid = pendingProfilePetId,
              let pet = pets.first(where: { $0.id == pid }),
              let visitD = pendingProfileVisitDate else {
            profileMergeProposal = nil
            pendingProfilePetId = nil
            pendingProfileVisitDate = nil
            dismiss()
            return
        }
        profileMergeProposal = nil
        pendingProfilePetId = nil
        pendingProfileVisitDate = nil
        if apply {
            VetVisitProfileUpdateSupport.apply(proposal: proposal, to: pet, visitDate: visitD, modelContext: modelContext)
            pdfImportCoordinator.showTransientSuccessToast("Profile updated successfully")
        } else {
            pdfImportCoordinator.showTransientSuccessToast("Saved to Health History only")
        }
        if !vaccinesForReminderSetup.isEmpty, reminderSetupActivePet != nil {
            lastEditorVaccineRemindersCreatedCount = 0
            showingVaccineReminderSetup = true
        } else {
            pdfImportCoordinator.presentVisitOutcomeToast(
                vaccineCount: lastSavedVisitVaxCount,
                medicationReminderCount: lastSavedVisitMedCount
            )
            pdfImportCoordinator.clearAddVisitImportHandler()
            dismiss()
        }
    }

    private func stashEditorVaccineReminderContext(
        vaccines: [String],
        certificates: [PetCertificate],
        visitDate: Date,
        clinic: String,
        parsedHints: [ParsedVaccineDue],
        activePet: Pet?
    ) {
        if vaccines.isEmpty {
            vaccinesForReminderSetup = []
            reminderSetupCertificates = []
            reminderSetupParsedHints = []
            reminderSetupActivePet = nil
            return
        }
        vaccinesForReminderSetup = vaccines
        reminderSetupCertificates = certificates
        reminderSetupVisitDate = visitDate
        reminderSetupClinicName = clinic
        reminderSetupParsedHints = parsedHints
        reminderSetupActivePet = activePet
    }

    @ViewBuilder
    private var importChromeSections: some View {
        if showImportSuccessBanner {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color(.systemGreen))
                    Text("Auto-filled from your document. Review and save.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color("BrandDark"))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button {
                        clearImportedFieldsAndResetChrome()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss auto-fill banner")
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
            .listRowBackground(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemGreen).opacity(colorScheme == .dark ? 0.22 : 0.14))
                    .padding(.vertical, 4)
            )
        } else if !importCardDismissed {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        HStack(spacing: 8) {
                            vetImportMiniIcon(systemImage: "camera.fill", gradient: [Color("BrandOrange"), Color("BrandOrange").opacity(0.65)])
                            vetImportMiniIcon(systemImage: "doc.badge.arrow.up", gradient: [Color("BrandBlue"), Color("BrandBlue").opacity(0.65)])
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Add your vet receipt first")
                                .font(.headline)
                                .foregroundStyle(Color("BrandDark"))
                            Text("Take a photo or import a PDF — we'll auto-fill the date, vet, diagnosis, and more. You can edit or add notes after.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Button {
                        HapticManager.shared.light()
                        startAddVisitImport()
                    } label: {
                        Text("Add from camera, photos, or PDF")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color("BrandOrange"))

                    Button {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            importCardDismissed = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                            focusedField = .clinic
                        }
                    } label: {
                        Text("Skip — I'll enter manually")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
            .listRowBackground(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(Color("BrandOrange").opacity(0.18), lineWidth: 1)
                    )
                    .padding(.vertical, 4)
            )
        }

        if showPartialParseHint {
            Section {
                Text("Some fields could not be read — please review before saving.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        if let hint = documentHintMessage {
            Section {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func vetImportMiniIcon(systemImage: String, gradient: [Color]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 44, height: 44)
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white)
        }
    }

    private func startAddVisitImport() {
        documentHintMessage = nil
        showPartialParseHint = false
        pdfImportCoordinator.beginAddVisitImport(pets: pets, handler: handleAddVisitImportOutcome(_:))
    }

    private func handleAddVisitImportOutcome(_ outcome: AddVisitImportOutcome) {
        switch outcome {
        case .parsed(let envelope):
            applyParsedEnvelope(envelope)
        case .documentUnreadable:
            documentHintMessage = "Could not read this document. You can fill in the visit details manually."
        case .pdfReadFailed(let message):
            documentHintMessage = message
        case .apiNotConfigured:
            showApiConfigAlert = true
        case .apiFailedNeedsRetry:
            showApiFailureAlert = true
        case .imageProcessingFailed(_):
            documentHintMessage = "Could not read this document. You can fill in the visit details manually."
        }
    }

    private func applyParsedEnvelope(_ envelope: VetRecordParserResponse) {
        let r = envelope.result
        let meaningful = envelope.structuredDecodeSucceeded || r.hasMeaningfulExtractedContent
        guard meaningful else {
            documentHintMessage = "Could not read this document. You can fill in the visit details manually."
            return
        }

        let form = PDFImportReviewFormState(from: r)
        let clinicDisplay: String = {
            let c = form.clinicName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !c.isEmpty { return c }
            let v = form.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
            return ""
        }()

        clinicName = clinicDisplay
        visitDate = form.visitDate
        reason = form.diagnosesText.trimmingCharacters(in: .whitespacesAndNewlines)
        notes = form.structuredNotesForHealthHistoryImport()
        importWeightKg = form.resolvedWeightKg()
        pendingVaccineNames = form.vaccineNames()
        pendingImportedMedications = form.medicationsForSave()
        lastImportedParse = r

        withAnimation(.easeInOut(duration: 0.25)) {
            showImportSuccessBanner = true
            importCardDismissed = true
        }
        showApiFailureAlert = false
        showPartialParseHint = !envelope.structuredDecodeSucceeded
        documentHintMessage = nil
    }

    private func clearImportedFieldsAndResetChrome() {
        clinicName = ""
        visitDate = Date()
        reason = ""
        notes = ""
        importWeightKg = nil
        pendingVaccineNames = []
        pendingImportedMedications = []
        lastImportedParse = nil
        showImportSuccessBanner = false
        showPartialParseHint = false
        importCardDismissed = false
        documentHintMessage = nil
    }

    #endif

    private func saveVisit() {
        guard let rid = draftRecordId else { return }
        var skipDismissForVaccinePrompt = false
        let petId = FeaturePetScope.resolvedPetId(pets: pets)
        let clinicDisplay = clinicName.isEmpty ? "Visit" : clinicName
        let visitDateLabel = visitDate.formatted(date: .abbreviated, time: .omitted)

        #if os(iOS)
        let vaxCountSnapshot = pendingVaccineNames.count
        var medicationReminderCount = 0
        var vaccinePairs: [(vaccineName: String, id: UUID)] = []
        var medicationReminderIds: [UUID] = []
        #endif

        let v = VetVisitLog(
            id: rid,
            petId: petId,
            visitDate: visitDate,
            clinicName: clinicDisplay,
            reason: reason,
            notes: notes
        )
        modelContext.insert(v)
        #if os(iOS)
        if let kg = importWeightKg, let pid = petId {
            let entry = PetWeightEntry(
                petId: pid,
                entryDate: visitDate,
                weightKg: kg
            )
            modelContext.insert(entry)
        }

        var vaccineCertificatesCreated: [PetCertificate] = []
        if let pid = petId {
            for name in pendingVaccineNames {
                let cert = PetCertificate(
                    petId: pid,
                    title: name,
                    notes: "Added from vet visit on \(visitDateLabel)",
                    category: "Vaccine",
                    expirationDate: nil
                )
                modelContext.insert(cert)
                vaccineCertificatesCreated.append(cert)
                vaccinePairs.append((vaccineName: name, id: cert.id))
            }

            let medNextDue = Calendar.current.date(byAdding: .day, value: 1, to: visitDate) ?? visitDate
            for med in pendingImportedMedications {
                let n = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !n.isEmpty else { continue }
                let dosage = med.dosage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let title: String
                if dosage.isEmpty {
                    title = n
                } else {
                    title = "\(n) - \(dosage)"
                }
                var noteLines: [String] = ["From vet visit at \(clinicDisplay) on \(visitDateLabel)."]
                if let freq = med.frequency?.trimmingCharacters(in: .whitespacesAndNewlines), !freq.isEmpty {
                    noteLines.append("Frequency: \(freq)")
                }
                let reminder = PetReminder(
                    petId: pid,
                    title: title,
                    notes: noteLines.joined(separator: " "),
                    category: "Medication",
                    nextDueDate: medNextDue,
                    recurring: false,
                    recurrenceInterval: 1,
                    recurrenceUnit: "month"
                )
                modelContext.insert(reminder)
                medicationReminderIds.append(reminder.id)
                medicationReminderCount += 1
            }
        }
        #endif

        do {
            try modelContext.save()
        } catch {
            return
        }

        #if os(iOS)
        VetImportSourceAttachment.attachAfterVetVisitSave(
            modelContext: modelContext,
            visitId: rid,
            visitDate: visitDate,
            clinicDisplay: clinicDisplay,
            visitDateLabel: visitDateLabel,
            vaccineCertificates: vaccinePairs,
            medicationReminderIds: medicationReminderIds,
            nextAppointmentReminderId: nil
        )
        try? modelContext.save()
        guard v.id == rid else { return }
        PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)

        let vaxCopy = pendingVaccineNames
        let medCopy = pendingImportedMedications
        let wCopy = importWeightKg
        let parseSnapshot = lastImportedParse

        pendingVaccineNames = []
        pendingImportedMedications = []
        importWeightKg = nil

        if let parseSnapshot,
           let pid = petId,
           let resolved = pets.first(where: { $0.id == pid }),
           let proposal = VetVisitProfileUpdateSupport.buildProposal(
               pet: resolved,
               parsed: parseSnapshot,
               form: nil,
               pendingVaccineNames: vaxCopy,
               pendingMedications: medCopy,
               importWeightKg: wCopy
           ),
           proposal.hasWork {
            lastSavedVisitVaxCount = vaxCountSnapshot
            lastSavedVisitMedCount = medicationReminderCount
            stashEditorVaccineReminderContext(
                vaccines: vaxCopy,
                certificates: vaccineCertificatesCreated,
                visitDate: visitDate,
                clinic: clinicDisplay,
                parsedHints: parseSnapshot.vaccinesWithDueDates,
                activePet: resolved
            )
            profileMergeProposal = proposal
            pendingProfilePetId = pid
            pendingProfileVisitDate = visitDate
            lastImportedParse = nil
            pdfImportCoordinator.clearAddVisitImportHandler()
            return
        }

        lastImportedParse = nil
        lastSavedVisitVaxCount = vaxCountSnapshot
        lastSavedVisitMedCount = medicationReminderCount
        stashEditorVaccineReminderContext(
            vaccines: vaxCopy,
            certificates: vaccineCertificatesCreated,
            visitDate: visitDate,
            clinic: clinicDisplay,
            parsedHints: parseSnapshot?.vaccinesWithDueDates ?? [],
            activePet: petId.flatMap { id in pets.first(where: { $0.id == id }) }
        )

        if !vaccinesForReminderSetup.isEmpty, reminderSetupActivePet != nil {
            skipDismissForVaccinePrompt = true
            lastEditorVaccineRemindersCreatedCount = 0
            showingVaccineReminderSetup = true
        } else {
            pdfImportCoordinator.presentVisitOutcomeToast(
                vaccineCount: vaxCountSnapshot,
                medicationReminderCount: medicationReminderCount
            )
            pdfImportCoordinator.clearAddVisitImportHandler()
        }
        #endif
        if !skipDismissForVaccinePrompt {
            dismiss()
        }
    }
}

// MARK: - Vet visit import notes (mirrors `PDFImportReviewView` structured notes)

extension PDFImportReviewFormState {
    /// Structured visit summary for `VetVisitLog.notes`; same sections as `PDFImportReviewView.buildStructuredImportNotes()`.
    func structuredNotesForHealthHistoryImport() -> String {
        var blocks: [String] = []

        let vet = vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vet.isEmpty {
            blocks.append("Veterinarian: \(vet)")
        }

        let vaxList = vaccineNames()
        if !vaxList.isEmpty {
            blocks.append("Vaccines given: \(vaxList.joined(separator: ", "))")
        }

        let meds = medicationsForSave()
        if !meds.isEmpty {
            let medLines = meds.map { med -> String in
                let name = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let dosage = med.dosage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let frequency = med.frequency?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                var parts: [String] = [name]
                if !dosage.isEmpty { parts.append(dosage) }
                if !frequency.isEmpty { parts.append(frequency) }
                return parts.joined(separator: " - ")
            }
            blocks.append("Medications:\n" + medLines.joined(separator: "\n"))
        }

        if includeWeight, let kg = resolvedWeightKg() {
            let lbs = kg * 2.2046226218
            blocks.append("Weight recorded: \(String(format: "%.1f", lbs)) lbs")
        }

        if includeNextAppointment {
            let when = nextAppointmentDate.formatted(date: .long, time: .shortened)
            blocks.append("Next appointment: \(when)")
        }

        let userNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userNotes.isEmpty {
            blocks.append(userNotes)
        }

        let importDate = Date().formatted(date: .long, time: .omitted)
        blocks.append("Imported via PDF on \(importDate).")

        return blocks.joined(separator: "\n\n")
    }
}

// MARK: - Pet Care Notes (pet sitter instructions)

struct FoodRecommendationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allInstructions: [PetSitterInstructions]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif
    @State private var showAutofillFromProfileBanner = false
    @State private var userDismissedAutofillBanner = false

    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: pets)
    }

    private var displayPetName: String {
        FeaturePetScope.currentPetName(pets: pets)
    }
    
    /// Per-pet row only. Legacy `petId == nil` rows are not shared across pets (see migration).
    private var instructionsForPet: PetSitterInstructions? {
        guard let pid = scopedPetId else { return nil }
        return allInstructions.first { $0.petId == pid }
    }

    private var scopedPet: Pet? {
        guard let pid = scopedPetId else { return nil }
        return pets.first { $0.id == pid }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                if showAutofillFromProfileBanner && !userDismissedAutofillBanner {
                    HStack(alignment: .top, spacing: 10) {
                        Text("Some info was filled in from \(displayPetName)'s profile. Review and edit anything before sharing.")
                            .font(.subheadline)
                            .foregroundStyle(Color("BrandDark"))
                            .fixedSize(horizontal: false, vertical: true)
                        Button {
                            userDismissedAutofillBanner = true
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("BrandBlue").opacity(0.12))
                }
                FeaturePetScopeHeader(pets: pets)
                Text("Printable sheet for pet sitter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                if let instructions = instructionsForPet {
                    PetSitterInstructionsForm(
                        instructions: instructions,
                        petName: displayPetName,
                        nextVetAppointmentDate: scopedPet?.nextVetAppointmentDate
                    )
                } else {
                    ContentUnavailableView {
                        Label("Setting up…", systemImage: "note.text")
                    }
                }
            }
            .navigationTitle("Pet Care Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    if let instructions = instructionsForPet {
                        Menu {
                            Button {
                                instructions.updatedAt = Date()
                                let printable = PetSitterPrintableDocument(
                                    instructions: instructions,
                                    petName: displayPetName,
                                    nextVetAppointmentDate: scopedPet?.nextVetAppointmentDate
                                )
                                    .frame(width: 400, height: 680)
                                    .preferredColorScheme(.light)
                                if let img = PrintShareHelper.renderToImage(printable) {
                                    let text = "Pet Care Notes for \(displayPetName)"
                                    DispatchQueue.main.async {
                                        sharePayload = ShareSheetPayload(items: [img, text])
                                    }
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                instructions.updatedAt = Date()
                                let printable = PetSitterPrintableDocument(
                                    instructions: instructions,
                                    petName: displayPetName,
                                    nextVetAppointmentDate: scopedPet?.nextVetAppointmentDate
                                )
                                    .frame(width: 400, height: 680)
                                    .preferredColorScheme(.light)
                                DispatchQueue.main.async {
                                    PrintShareHelper.printView(printable, title: "Pet Care Notes - \(displayPetName)")
                                }
                            } label: {
                                Label("Print", systemImage: "printer")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                #endif
            }
            #if os(iOS)
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            #endif
            .onAppear {
                migrateLegacySitterNotesIfNeeded()
                applyPetSitterAutofillFromProfile()
            }
        }
    }

    private func applyPetSitterAutofillFromProfile() {
        guard let pid = scopedPetId,
              let pet = pets.first(where: { $0.id == pid }),
              let inst = allInstructions.first(where: { $0.petId == pid }) else { return }
        let care = CareCardFieldSettings.load(for: pid)
        if PetSitterProfileAutofill.fillEmptyFields(instructions: inst, pet: pet, careCard: care, modelContext: modelContext) {
            showAutofillFromProfileBanner = true
        }
    }

    /// Legacy notes used `petId == nil` and matched every pet via `PetRecordFilter`, so edits were global. Split into one row per pet.
    private func migrateLegacySitterNotesIfNeeded() {
        let orphans = allInstructions.filter { $0.petId == nil }
        var assignedPetIds = Set(allInstructions.compactMap(\.petId))
        
        if let template = orphans.first, !pets.isEmpty {
            for pet in pets where !assignedPetIds.contains(pet.id) {
                let copy = PetSitterInstructions(
                    petId: pet.id,
                    favoriteFood: template.favoriteFood,
                    foodAmount: template.foodAmount,
                    foodAddons: template.foodAddons,
                    foodSchedule: template.foodSchedule,
                    favoriteTreats: template.favoriteTreats,
                    treatAmount: template.treatAmount,
                    treatSchedule: template.treatSchedule,
                    walkSchedule: template.walkSchedule,
                    walkDuration: template.walkDuration,
                    allergies: template.allergies,
                    medications: template.medications,
                    vetName: template.vetName,
                    vetPhone: template.vetPhone,
                    vetAddress: template.vetAddress,
                    specialInstructions: template.specialInstructions,
                    updatedAt: template.updatedAt
                )
                modelContext.insert(copy)
                assignedPetIds.insert(pet.id)
            }
            for o in orphans {
                modelContext.delete(o)
            }
            try? modelContext.save()
            return
        }
        
        if let pid = scopedPetId, !allInstructions.contains(where: { $0.petId == pid }) {
            modelContext.insert(PetSitterInstructions(petId: pid))
            try? modelContext.save()
        }
    }
}

private struct PetSitterInstructionsForm: View {
    @Bindable var instructions: PetSitterInstructions
    let petName: String
    var nextVetAppointmentDate: Date?

    var body: some View {
        Form {
            Section {
                Text("Print this off for your pet sitter when you're away. Fill in everything your sitter needs to care for \(petName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Section("Food") {
                TextField("Favorite food (brand, flavor)", text: $instructions.favoriteFood)
                TextField("Amount per meal (e.g. 1 cup)", text: $instructions.foodAmount)
                TextField("Add-ons (e.g. scoop of wet food, half cup rice)", text: Binding(
                    get: { instructions.foodAddons ?? "" },
                    set: { instructions.foodAddons = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(2...4)
                TextField("When to feed (e.g. 8am and 6pm)", text: $instructions.foodSchedule)
            }
            Section("Treats") {
                TextField("Favorite treats", text: $instructions.favoriteTreats)
                TextField("How much (e.g. 2 small treats)", text: $instructions.treatAmount)
                TextField("When to give (e.g. after walks)", text: $instructions.treatSchedule)
            }
            Section("Walks") {
                TextField("When to walk (e.g. 7am, 12pm, 6pm)", text: Binding(
                    get: { instructions.walkSchedule ?? "" },
                    set: { instructions.walkSchedule = $0.isEmpty ? nil : $0 }
                ))
                TextField("Duration (e.g. 15–20 min)", text: Binding(
                    get: { instructions.walkDuration ?? "" },
                    set: { instructions.walkDuration = $0.isEmpty ? nil : $0 }
                ))
            }
            Section("Allergies") {
                TextField("Food, meds, environment, reactions…", text: Binding(
                    get: { instructions.allergies ?? "" },
                    set: { instructions.allergies = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(2...6)
            }
            Section("Medications") {
                TextField("Dose, timing, instructions…", text: Binding(
                    get: { instructions.medications ?? "" },
                    set: { instructions.medications = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(2...6)
            }
            Section("Vet contact") {
                TextField("Vet name", text: Binding(
                    get: { instructions.vetName ?? "" },
                    set: { instructions.vetName = $0.isEmpty ? nil : $0 }
                ))
                TextField("Vet phone number", text: Binding(
                    get: { instructions.vetPhone ?? "" },
                    set: { instructions.vetPhone = $0.isEmpty ? nil : $0 }
                ))
                    .keyboardType(.phonePad)
                TextField("Vet address", text: Binding(
                    get: { instructions.vetAddress ?? "" },
                    set: { instructions.vetAddress = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(2...4)
            }
            Section("Special instructions") {
                TextField("Allergies, behavior notes, potty habits, no table scraps…", text: $instructions.specialInstructions, axis: .vertical)
                    .lineLimit(3...8)
            }
            Section {
                PetSitterDocumentPreview(
                    instructions: instructions,
                    petName: petName,
                    nextVetAppointmentDate: nextVetAppointmentDate
                )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }
}

private struct PetSitterDocumentPreview: View {
    let instructions: PetSitterInstructions
    let petName: String
    var nextVetAppointmentDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview for sitter")
                .font(.caption)
                .foregroundStyle(.secondary)
            PetSitterPrintableDocument(
                instructions: instructions,
                petName: petName,
                nextVetAppointmentDate: nextVetAppointmentDate
            )
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.vertical, 8)
    }
}

private struct PetSitterPrintableDocument: View {
    let instructions: PetSitterInstructions
    let petName: String
    var nextVetAppointmentDate: Date?

    private let labelColor = Color.black.opacity(0.6)
    private let textColor = Color.black

    private func row(_ label: String, _ value: String) -> some View {
        Group {
            if !value.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(labelColor)
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(textColor)
                }
            }
        }
    }

    private var hasAnyContent: Bool {
        nextVetAppointmentDate != nil ||
        !instructions.favoriteFood.isEmpty || !instructions.foodSchedule.isEmpty ||
        !(instructions.foodAddons ?? "").isEmpty ||
        !instructions.favoriteTreats.isEmpty || !instructions.treatSchedule.isEmpty ||
        !(instructions.walkSchedule ?? "").isEmpty || !(instructions.allergies ?? "").isEmpty ||
        !(instructions.medications ?? "").isEmpty || !(instructions.vetName ?? "").isEmpty ||
        !(instructions.vetPhone ?? "").isEmpty || !(instructions.vetAddress ?? "").isEmpty ||
        !instructions.specialInstructions.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Print this off for your pet sitter")
                .font(.headline)
                .foregroundStyle(labelColor)
            Text("Pet Care Notes — \(petName)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(textColor)
            Rectangle()
                .fill(labelColor)
                .frame(height: 1)
            if let next = nextVetAppointmentDate {
                Text("Appointments")
                    .font(.headline)
                    .foregroundStyle(textColor)
                row("Next vet appointment", next.formatted(date: .long, time: .omitted))
            }
            if !instructions.favoriteFood.isEmpty || !instructions.foodAmount.isEmpty || !instructions.foodSchedule.isEmpty || !(instructions.foodAddons ?? "").isEmpty {
                Text("Food")
                    .font(.headline)
                    .foregroundStyle(textColor)
                row("Favorite food", instructions.favoriteFood)
                row("Amount per meal", instructions.foodAmount)
                row("Add-ons", instructions.foodAddons ?? "")
                row("When to feed", instructions.foodSchedule)
            }
            if !instructions.favoriteTreats.isEmpty || !instructions.treatAmount.isEmpty || !instructions.treatSchedule.isEmpty {
                Text("Treats")
                    .font(.headline)
                    .foregroundStyle(textColor)
                row("Favorite treats", instructions.favoriteTreats)
                row("How much", instructions.treatAmount)
                row("When to give", instructions.treatSchedule)
            }
            if !(instructions.walkSchedule ?? "").isEmpty || !(instructions.walkDuration ?? "").isEmpty {
                Text("Walks")
                    .font(.headline)
                    .foregroundStyle(textColor)
                row("When to walk", instructions.walkSchedule ?? "")
                row("Duration", instructions.walkDuration ?? "")
            }
            if let allergies = instructions.allergies, !allergies.isEmpty {
                Text("Allergies")
                    .font(.headline)
                    .foregroundStyle(textColor)
                Text(allergies)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
            }
            if let med = instructions.medications, !med.isEmpty {
                Text("Medications")
                    .font(.headline)
                    .foregroundStyle(textColor)
                Text(med)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
            }
            if !(instructions.vetName ?? "").isEmpty || !(instructions.vetPhone ?? "").isEmpty || !(instructions.vetAddress ?? "").isEmpty {
                Text("Vet contact")
                    .font(.headline)
                    .foregroundStyle(textColor)
                row("Name", instructions.vetName ?? "")
                row("Phone", instructions.vetPhone ?? "")
                row("Address", instructions.vetAddress ?? "")
            }
            if !instructions.specialInstructions.isEmpty {
                Text("Special instructions")
                    .font(.headline)
                    .foregroundStyle(textColor)
                Text(instructions.specialInstructions)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
            }
            if !hasAnyContent {
                Text("Add care details above to generate your pet sitter notes.")
                    .font(.subheadline)
                    .foregroundStyle(labelColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .foregroundStyle(textColor)
        .preferredColorScheme(.light)
    }
}

// MARK: - Reminders (SwiftData PetReminder)

struct RemindersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetReminder.nextDueDate) private var reminders: [PetReminder]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var showingAdd = false
    
    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: pets)
    }
    
    private var petScopedReminders: [PetReminder] {
        guard let pid = scopedPetId else { return [] }
        return reminders.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
    }

    /// Due or “now” for this pet’s list — stays after the app icon badge clears until completed, rescheduled, or deleted.
    private var dueAttentionCountForScopedPet: Int {
        petScopedReminders.filter { $0.needsAttention }.count
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                FeaturePetScopeHeader(pets: pets)
                Text("Push notifications for meds & more")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                if petScopedReminders.isEmpty {
                    ContentUnavailableView {
                        Label("No Reminders", systemImage: "bell.badge.fill")
                    } description: {
                        Text("Vaccines, grooming, meds — add what you need to remember.")
                    } actions: {
                        Button("Add Reminder") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        InlineAddListRow(title: "Add Reminder") { showingAdd = true }
                        ForEach(petScopedReminders) { r in
                            NavigationLink {
                                PetReminderDetailView(reminder: r)
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    if r.needsAttention {
                                        Circle()
                                            .fill(Color.red)
                                            .frame(width: 10, height: 10)
                                            .accessibilityLabel("Due — needs attention")
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r.title.isEmpty ? "Reminder" : r.title)
                                            .font(.headline)
                                        Text(r.category)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(r.nextDueDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(r.needsAttention ? Color.red : Color.secondary.opacity(0.85))
                                    }
                                    Spacer()
                                    if r.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteReminders)
                    }
                }
            }
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    #if os(iOS)
                    if dueAttentionCountForScopedPet > 0 {
                        Text(dueAttentionCountForScopedPet > 99 ? "99+" : "\(dueAttentionCountForScopedPet)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.red))
                            .accessibilityLabel("\(dueAttentionCountForScopedPet) due reminders for this pet")
                    }
                    #endif
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                PetReminderEditorView()
            }
            #if os(iOS)
            .task {
                await PetReminderNotificationService.requestPermissionIfNeeded()
            }
            #endif
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            let r = petScopedReminders[index]
            PetRecordAttachment.deleteAll(parentRecordId: r.id, parentKind: .reminder, context: modelContext)
            #if os(iOS)
            PetReminderNotificationService.cancel(reminderId: r.id)
            #endif
            modelContext.delete(r)
        }
        try? modelContext.save()
        #if os(iOS)
        PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        #endif
    }
}

private let reminderCategories = ["Medication", "Vet visit", "Reorder", "General"]

private func everyDisplay(interval: Int, unit: String) -> String {
    let u = interval == 1 ? unit : unit + "s"
    return "Every \(interval) \(u)"
}

private enum RecurrencePreset: String, CaseIterable {
    case weekly = "Once a week"
    case monthly = "Once a month"
    case yearly = "Once a year"
    case custom = "Custom"

    func toIntervalAndUnit() -> (Int, String)? {
        switch self {
        case .weekly: return (1, "week")
        case .monthly: return (1, "month")
        case .yearly: return (1, "year")
        case .custom: return nil
        }
    }

    static func from(interval: Int, unit: String) -> RecurrencePreset {
        if interval == 1 && unit == "week" { return .weekly }
        if interval == 1 && unit == "month" { return .monthly }
        if interval == 1 && unit == "year" { return .yearly }
        return .custom
    }
}

struct PetReminderDetailView: View {
    @Bindable var reminder: PetReminder
    @Environment(\.modelContext) private var modelContext

    private func recurrencePresetBinding() -> Binding<RecurrencePreset> {
        Binding(
            get: { RecurrencePreset.from(interval: reminder.recurrenceInterval, unit: reminder.recurrenceUnit) },
            set: { newValue in
                if let (i, u) = newValue.toIntervalAndUnit() {
                    reminder.recurrenceInterval = i
                    reminder.recurrenceUnit = u
                }
            }
        )
    }

    var body: some View {
        Form {
            Section("Reminder") {
                TextField("Title", text: $reminder.title)
                Picker("Category", selection: $reminder.category) {
                    ForEach(reminderCategories, id: \.self) { Text($0).tag($0) }
                }
                DatePicker("Due", selection: $reminder.nextDueDate)
                Toggle("Completed", isOn: $reminder.isCompleted)
            }
            Section("Notes") {
                TextField("Notes", text: $reminder.notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            RecordAttachmentsSection(parentRecordId: reminder.id, parentKind: .reminder)
            Section("Repeat") {
                Toggle("Recurring", isOn: $reminder.recurring)
                if reminder.recurring {
                    Picker("Frequency", selection: recurrencePresetBinding()) {
                        ForEach(RecurrencePreset.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    if RecurrencePreset.from(interval: reminder.recurrenceInterval, unit: reminder.recurrenceUnit) == .custom {
                        Stepper(everyDisplay(interval: reminder.recurrenceInterval, unit: reminder.recurrenceUnit), value: $reminder.recurrenceInterval, in: 1...52)
                        Picker("Unit", selection: $reminder.recurrenceUnit) {
                            Text("day").tag("day")
                            Text("week").tag("week")
                            Text("month").tag("month")
                            Text("year").tag("year")
                        }
                    }
                }
            }
        }
        .navigationTitle("Reminder")
        #if os(iOS)
        .onChange(of: reminder.nextDueDate) { _, _ in
            PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        }
        .onChange(of: reminder.isCompleted) { _, _ in
            PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        }
        .onChange(of: reminder.recurring) { _, _ in
            PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        }
        .onDisappear {
            PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        }
        #endif
    }
}

struct PetReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var title = ""
    @State private var category = "General"
    @State private var notes = ""
    @State private var nextDue = Date()
    @State private var recurring = false
    @State private var recurrencePreset: RecurrencePreset = .monthly
    @State private var recurrenceInterval = 1
    @State private var recurrenceUnit = "month"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(reminderCategories, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Due date", selection: $nextDue)
                    Toggle("Repeats", isOn: $recurring)
                }
                if recurring {
                    Section("Repeat") {
                        Picker("Frequency", selection: $recurrencePreset) {
                            ForEach(RecurrencePreset.allCases, id: \.self) {
                                Text($0.rawValue).tag($0)
                            }
                        }
                        if recurrencePreset == .custom {
                            Stepper(everyDisplay(interval: recurrenceInterval, unit: recurrenceUnit), value: $recurrenceInterval, in: 1...52)
                            Picker("Unit", selection: $recurrenceUnit) {
                                Text("day").tag("day")
                                Text("week").tag("week")
                                Text("month").tag("month")
                                Text("year").tag("year")
                            }
                        }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                }
            }
            .navigationTitle("New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let (interval, unit) = recurrencePreset.toIntervalAndUnit()
                            ?? (recurrenceInterval, recurrenceUnit)
                        let r = PetReminder(
                            petId: FeaturePetScope.resolvedPetId(pets: pets),
                            title: title.isEmpty ? "Reminder" : title,
                            notes: notes,
                            category: category,
                            nextDueDate: nextDue,
                            recurring: recurring,
                            recurrenceInterval: interval,
                            recurrenceUnit: unit
                        )
                        modelContext.insert(r)
                        try? modelContext.save()
                        #if os(iOS)
                        PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
                        #endif
                        dismiss()
                    }
                    .disabled(FeaturePetScope.resolvedPetId(pets: pets) == nil)
                }
            }
        }
    }
}

// MARK: - Insurance

struct InsuranceTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetInsuranceInfo.providerName) private var policies: [PetInsuranceInfo]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var showingAdd = false
    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif
    
    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: pets)
    }
    
    private var petScopedPolicies: [PetInsuranceInfo] {
        guard let pid = scopedPetId else { return [] }
        return policies.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                FeaturePetScopeHeader(pets: pets)
                Text("Upload all policy docs")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                if petScopedPolicies.isEmpty {
                    ContentUnavailableView {
                        Label("No Policies", systemImage: "checkmark.shield.fill")
                    } description: {
                        Text("Store provider, policy number, and renewal dates in one place.")
                    } actions: {
                        Button("Add Policy") { showingAdd = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        InlineAddListRow(title: "Add Policy") { showingAdd = true }
                        ForEach(petScopedPolicies) { p in
                            NavigationLink {
                                InsuranceDetailView(policy: p)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(p.providerName.isEmpty ? "Policy" : p.providerName)
                                        .font(.headline)
                                    if !p.policyNumber.isEmpty {
                                        Text(p.policyNumber)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let renew = p.renewalDate {
                                        Text("Renews \(renew.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption2)
                                            .foregroundStyle(Color.secondary.opacity(0.85))
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deletePolicies)
                    }
                }
            }
            .navigationTitle("Insurance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                #if os(iOS)
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            let printable = InsurancePrintableView(policies: petScopedPolicies)
                                .frame(width: 400, height: 600)
                            if let img = PrintShareHelper.renderToImage(printable) {
                                let text = "Pet insurance — \(petScopedPolicies.count) policy(ies)"
                                DispatchQueue.main.async {
                                    sharePayload = ShareSheetPayload(items: [img, text])
                                }
                            }
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            let printable = InsurancePrintableView(policies: petScopedPolicies)
                                .frame(width: 400, height: 600)
                            DispatchQueue.main.async {
                                PrintShareHelper.printView(printable, title: "Pet Insurance")
                            }
                        } label: {
                            Label("Print", systemImage: "printer")
                        }
                        Button {
                            showingAdd = true
                        } label: {
                            Label("Add Policy", systemImage: "plus.circle.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingAdd) {
                InsuranceEditorView()
            }
            #if os(iOS)
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
            #endif
        }
    }

    private func deletePolicies(at offsets: IndexSet) {
        for index in offsets {
            let p = petScopedPolicies[index]
            PetRecordAttachment.deleteAll(parentRecordId: p.id, parentKind: .insurance, context: modelContext)
            modelContext.delete(p)
        }
    }
}

private struct InsurancePrintableView: View {
    let policies: [PetInsuranceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pet Insurance")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.black)
            Divider()
            ForEach(policies) { p in
                VStack(alignment: .leading, spacing: 4) {
                    Text(p.providerName.isEmpty ? "Policy" : p.providerName)
                        .font(.headline)
                        .foregroundStyle(Color.black)
                    if !p.policyNumber.isEmpty {
                        Text("Policy #\(p.policyNumber)")
                            .font(.subheadline)
                            .foregroundStyle(Color.black)
                    }
                    if !p.phone.isEmpty {
                        Text("Phone: \(p.phone)")
                            .font(.caption)
                            .foregroundStyle(Color.black)
                    }
                    if let renew = p.renewalDate {
                        Text("Renewal: \(renew.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                    if !p.notes.isEmpty {
                        Text(p.notes)
                            .font(.caption)
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .preferredColorScheme(.light)
    }
}

struct InsuranceDetailView: View {
    @Bindable var policy: PetInsuranceInfo

    var body: some View {
        Form {
            Section("Policy") {
                TextField("Provider", text: $policy.providerName)
                TextField("Policy number", text: $policy.policyNumber)
                TextField("Phone", text: $policy.phone)
            }
            Section("Renewal") {
                DatePicker("Renewal date", selection: Binding(
                    get: { policy.renewalDate ?? Date() },
                    set: { policy.renewalDate = $0 }
                ), displayedComponents: .date)
            }
            Section("Notes") {
                TextField("Claims, coverage notes…", text: $policy.notes, axis: .vertical)
                    .lineLimit(3...10)
            }
            RecordAttachmentsSection(parentRecordId: policy.id, parentKind: .insurance)
        }
        .navigationTitle("Insurance")
    }
}

struct InsuranceEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var draftRecordId: UUID?
    @State private var provider = ""
    @State private var number = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var renewal = Date()
    #if os(iOS)
    @State private var insuranceImagePick: InsuranceImagePickRoute?
    @State private var isScanningInsurance = false
    @State private var insuranceScanAlert: String?
    @State private var pendingScanImageForSourceAttachment: UIImage?
    #endif

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section {
                        TextField("Provider", text: $provider)
                        TextField("Policy number", text: $number)
                        TextField("Phone", text: $phone)
                        DatePicker("Renewal", selection: $renewal, displayedComponents: .date)
                    }
                    #if os(iOS)
                    Section("Scan") {
                        Button {
                            insuranceImagePick = InsuranceImagePickRoute(source: .camera)
                        } label: {
                            Label("Scan insurance card (camera)", systemImage: "camera.fill")
                        }
                        Button {
                            insuranceImagePick = InsuranceImagePickRoute(source: .photoLibrary)
                        } label: {
                            Label("Choose card photo", systemImage: "photo.fill")
                        }
                    }
                    #endif
                    Section("Notes") {
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(2...8)
                    }
                    if let rid = draftRecordId {
                        RecordAttachmentsSection(parentRecordId: rid, parentKind: .insurance)
                    }
                }
                #if os(iOS)
                if isScanningInsurance {
                    Color.black.opacity(0.25)
                        .ignoresSafeArea()
                    ProgressView("Reading your document…")
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                #endif
            }
            .navigationTitle("New Policy")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if draftRecordId == nil {
                    draftRecordId = UUID()
                }
            }
            #if os(iOS)
            .sheet(item: $insuranceImagePick) { route in
                ImagePickerView(
                    source: route.source,
                    onImageSelected: { img in
                        insuranceImagePick = nil
                        Task { await processInsuranceScan(image: img) }
                    },
                    onCancel: {
                        insuranceImagePick = nil
                    }
                )
                .ignoresSafeArea()
            }
            .alert("Insurance scan", isPresented: Binding(
                get: { insuranceScanAlert != nil },
                set: { if !$0 { insuranceScanAlert = nil } }
            )) {
                Button("OK", role: .cancel) { insuranceScanAlert = nil }
            } message: {
                Text(insuranceScanAlert ?? "")
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let rid = draftRecordId {
                            PetRecordAttachment.deleteAll(parentRecordId: rid, parentKind: .insurance, context: modelContext)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let rid = draftRecordId else { return }
                        let providerTrimmed = provider.isEmpty ? "Policy" : provider
                        let p = PetInsuranceInfo(
                            id: rid,
                            petId: FeaturePetScope.resolvedPetId(pets: pets),
                            providerName: providerTrimmed,
                            policyNumber: number,
                            phone: phone,
                            notes: notes,
                            renewalDate: renewal
                        )
                        modelContext.insert(p)
                        try? modelContext.save()
                        #if os(iOS)
                        if let img = pendingScanImageForSourceAttachment {
                            let dateTok = SourceAttachmentService.fileDateToken(Date())
                            let note = "Scanned on \(dateTok). AI extracted: \(providerTrimmed), \(number)."
                            _ = SourceAttachmentService.attachPhoto(
                                img,
                                to: modelContext,
                                parentRecordId: rid,
                                parentKind: .insurance,
                                filename: "insurance-scan-\(dateTok).jpg",
                                note: note
                            )
                            try? modelContext.save()
                            pendingScanImageForSourceAttachment = nil
                        }
                        #endif
                        dismiss()
                    }
                    .disabled(draftRecordId == nil || FeaturePetScope.resolvedPetId(pets: pets) == nil)
                }
            }
        }
    }

    #if os(iOS)
    @MainActor
    private func processInsuranceScan(image: UIImage) async {
        isScanningInsurance = true
        defer { isScanningInsurance = false }
        pendingScanImageForSourceAttachment = image
        do {
            let text = try await VisionOCRService.extractText(from: image)
            let result = await InsuranceOCRService.extract(from: text)
            switch result {
            case .success(let fields):
                if let n = fields.providerName, !n.isEmpty { provider = n }
                if let num = fields.policyNumber, !num.isEmpty { number = num }
                if let ph = fields.phoneNumber, !ph.isEmpty { phone = ph }
                if let cov = fields.coverageType, !cov.isEmpty {
                    let line = "Coverage: \(cov)"
                    notes = notes.isEmpty ? line : "\(line)\n\(notes)"
                }
            case .failure(let err):
                if case .noAPIConfigured = err {
                    insuranceScanAlert = err.localizedDescription
                } else {
                    insuranceScanAlert = "Could not extract fields automatically. You can still fill the form manually."
                }
            }
        } catch VisionOCRService.OCRError.noTextFound {
            insuranceScanAlert = "Could not read text from this photo. Try better lighting and focus."
        } catch {
            insuranceScanAlert = error.localizedDescription
        }
    }
    #endif
}

#if os(iOS)
private struct InsuranceImagePickRoute: Identifiable {
    let id = UUID()
    let source: ImagePickerSource
}
#endif

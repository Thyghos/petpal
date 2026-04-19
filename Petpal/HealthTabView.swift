// HealthTabView.swift
// Health hub: stats, PDF import placeholder, and navigation into existing health screens.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct HealthTabView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabRouter: MainTabRouter
    @ObservedObject private var pdfImportCoordinator = PDFImportCoordinator.shared
    #if os(iOS)
    @ObservedObject private var appleHealthService = AppleHealthService.shared
    @State private var showAppleHealthPrePrompt = false
    @State private var showRemindersFromPetTab = false
    @State private var showCertificatesFromPetTab = false
    #endif
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var visits: [VetVisitLog]
    @Query(sort: \PetCertificate.updatedAt, order: .reverse) private var certificates: [PetCertificate]

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var scopedPetId: UUID? {
        FeaturePetScope.resolvedPetId(pets: sortedPets)
    }

    private var petScopedVisits: [VetVisitLog] {
        guard let pid = scopedPetId else { return [] }
        return visits.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
    }

    private var petScopedCertificates: [PetCertificate] {
        guard let pid = scopedPetId else { return [] }
        return certificates.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
    }

    private var weightLine: String {
        guard let pid = scopedPetId, let pet = sortedPets.first(where: { $0.id == pid }) else { return "—" }
        guard pet.weight > 0 else { return "—" }
        return "\(Int(pet.weight)) \(pet.weightUnit)"
    }

    private var lastVisitLine: String {
        guard let v = petScopedVisits.first else { return "—" }
        return v.visitDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var vaccineLine: String {
        let certs = petScopedCertificates
        guard !certs.isEmpty else { return "—" }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let expired = certs.contains { cert in
            guard let exp = cert.expirationDate else { return false }
            return cal.startOfDay(for: exp) < today
        }
        if expired { return "Review needed" }
        let futureExps = certs.compactMap(\.expirationDate).filter { cal.startOfDay(for: $0) >= today }
        if let next = futureExps.min() {
            return "Next: \(next.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Logged"
    }

    #if os(iOS)
    /// Presents `CertificatesView` when the Pet tab requests it and this tab is selected.
    private func tryPresentCertificatesFromPetTab() {
        guard tabRouter.shouldPresentCertificatesFromPetTab, tabRouter.selectedTab == 1 else { return }
        showCertificatesFromPetTab = true
        tabRouter.shouldPresentCertificatesFromPetTab = false
    }
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    quickStatsBar
                        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    Button {
                        pdfImportCoordinator.showImportSourceOptionsVetRecord(pets: sortedPets)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.arrow.up")
                                .font(.title2)
                                .foregroundStyle(Color("BrandBlue"))
                                .frame(width: 40, height: 40)
                                .background(Color("BrandBlue").opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Import a vet record")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color("BrandDark"))
                                Text("Take a photo or import a PDF — we fill it in for you. Or add a visit manually in Health History.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }

                Section("Records") {
                    NavigationLink {
                        HealthHistoryView()
                    } label: {
                        Label("Health History", systemImage: "heart.text.square.fill")
                    }

                    NavigationLink {
                        CertificatesView()
                    } label: {
                        Label("Certificates & Vaccines", systemImage: "doc.text.fill")
                    }

                    NavigationLink {
                        InsuranceTrackerView()
                    } label: {
                        Label("Insurance", systemImage: "checkmark.shield.fill")
                    }

                    NavigationLink {
                        VetStoredDocumentsListView()
                    } label: {
                        Label("Documents", systemImage: "folder.fill")
                    }

                    NavigationLink {
                        EmergencyQRView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "qrcode")
                                .foregroundStyle(Color("BrandOrange"))
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Emergency QR")
                                    .foregroundStyle(Color("BrandDark"))
                                Text("Printable QR for lost pet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Tracking") {
                    NavigationLink {
                        RemindersView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(Color("BrandBlue"))
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Reminders")
                                    .foregroundStyle(Color("BrandDark"))
                                Text("Medications, appointments & alerts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        WeightTrackerView()
                    } label: {
                        Label("Weight Tracker", systemImage: "chart.line.uptrend.xyaxis")
                    }

                    NavigationLink {
                        WalksActivityView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.walk")
                                .foregroundStyle(Color("BrandBlue"))
                                .frame(width: 24, alignment: .center)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Walks & Activity")
                                    .foregroundStyle(Color("BrandDark"))
                                Text("Apple Health + manual entries")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [
                        Color("BrandCream"),
                        Color("BrandSoftBlue").opacity(0.22),
                        Color("BrandCream")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                        tabRouter.selectedTab = 0
                    }
                }
                if !sortedPets.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        FeaturePetScopePetSwitcherMenu(pets: sortedPets, pillStyle: .navigationBar)
                    }
                }
            }
            #if os(iOS)
            .onAppear {
                // Do not auto-present `AppleHealthPrePromptSheet` on first Health tab visit — users land on
                // the hub; they can tap "Connect Apple Health" in the activity column or in Walks & Activity.
                Task { await appleHealthService.refreshSummaryIfStale() }
                if tabRouter.shouldPresentHealthRemindersFromPetTab {
                    showRemindersFromPetTab = true
                    tabRouter.shouldPresentHealthRemindersFromPetTab = false
                }
                tryPresentCertificatesFromPetTab()
            }
            .sheet(isPresented: $showAppleHealthPrePrompt) {
                AppleHealthPrePromptSheet(
                    petName: FeaturePetScope.currentPetName(pets: sortedPets),
                    onConnect: {
                        Task {
                            await appleHealthService.requestReadAuthorization()
                            await MainActor.run {
                                showAppleHealthPrePrompt = false
                            }
                        }
                    },
                    onNotNow: {
                        UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
                        showAppleHealthPrePrompt = false
                    }
                )
            }
            .onChange(of: tabRouter.selectedTab) { _, newTab in
                if newTab == 1, tabRouter.shouldPresentHealthRemindersFromPetTab {
                    showRemindersFromPetTab = true
                    tabRouter.shouldPresentHealthRemindersFromPetTab = false
                }
                if newTab == 1 {
                    tryPresentCertificatesFromPetTab()
                }
            }
            .onChange(of: tabRouter.shouldPresentCertificatesFromPetTab) { _, _ in
                tryPresentCertificatesFromPetTab()
            }
            .fullScreenCover(isPresented: $showRemindersFromPetTab) {
                RemindersView()
            }
            .fullScreenCover(isPresented: $showCertificatesFromPetTab) {
                CertificatesView()
            }
            #endif
        }
    }

    private var quickStatsBar: some View {
        HStack(spacing: 0) {
            statCell(title: "Weight", value: weightLine)
            Divider().frame(height: 36)
            statCell(title: "Last visit", value: lastVisitLine)
            Divider().frame(height: 36)
            statCell(title: "Vaccines", value: vaccineLine)
            #if os(iOS)
            Divider().frame(height: 36)
            appleHealthWalksColumn
            #endif
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HealthTabView.secondaryGroupedFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color("BrandBlue").opacity(0.12), lineWidth: 1)
        )
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("BrandDark"))
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    #if os(iOS)
    private var appleHealthWalksColumn: some View {
        VStack(spacing: 4) {
            Text("ACTIVITY")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            if appleHealthService.isConnected {
                if let miles = appleHealthService.summary?.totalMilesThisYear {
                    Text(String(format: "%.1f mi — your activity this year (Apple Health)", miles))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("BrandDark"))
                        .lineLimit(3)
                        .minimumScaleFactor(0.65)
                        .multilineTextAlignment(.center)
                } else {
                    Text("—")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color("BrandDark"))
                }
            } else {
                Button {
                    HapticManager.shared.selection()
                    showAppleHealthPrePrompt = true
                } label: {
                    Text("Connect Apple Health")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.75)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }
    #endif

    private static var secondaryGroupedFill: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemGroupedBackground)
        #else
        Color.gray.opacity(0.12)
        #endif
    }
}

// MARK: - Walks & Activity (same module as Health tab; co-located to avoid target membership issues)

struct WalksActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]
    @Query(sort: \ManualWalkEntry.walkDate, order: .reverse) private var walkEntries: [ManualWalkEntry]

    #if os(iOS)
    @ObservedObject private var appleHealthService = AppleHealthService.shared
    @State private var showAppleHealthPrePrompt = false
    #endif

    @State private var showAddWalk = false

    private var logWalkCardPetName: String {
        FeaturePetScope.currentPetName(pets: sortedPets)
    }

    private var sortedPets: [Pet] {
        pets.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var scopedPetId: UUID? {
        ActivePetResolver.resolvedPetId(pets: sortedPets)
    }

    private var scopedWalks: [ManualWalkEntry] {
        guard let pid = scopedPetId else { return [] }
        return walkEntries.filter { $0.petId == pid }
    }

    var body: some View {
        List {
            #if os(iOS)
            Section {
                logWalkProminentCard
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            Section {
                appleHealthSummaryCard
            }
            .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            #endif

            Section {
                if scopedPetId == nil {
                    Text("Select a pet to log walks.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    InlineAddListRow(title: "Add Walk") {
                        HapticManager.shared.light()
                        showAddWalk = true
                    }
                    .disabled(scopedPetId == nil)
                    if scopedWalks.isEmpty {
                        Text("No manual walks yet. Tap + to add one.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scopedWalks) { entry in
                            manualWalkRow(entry)
                        }
                        .onDelete(perform: deleteWalks)
                    }
                }
            } header: {
                Text("Manual walk log")
            } footer: {
                Text("Entries are saved for the pet selected above and sync with your other devices when iCloud is enabled.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(
            LinearGradient(
                colors: [
                    Color("BrandCream"),
                    Color("BrandSoftBlue").opacity(0.22),
                    Color("BrandCream")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Walks & Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !sortedPets.isEmpty {
                    FeaturePetScopePetSwitcherMenu(pets: sortedPets, pillStyle: .navigationBar)
                }
                Button {
                    HapticManager.shared.light()
                    showAddWalk = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color("BrandOrange"))
                }
                .disabled(scopedPetId == nil)
                .accessibilityLabel("Add manual walk")
            }
        }
        .sheet(isPresented: $showAddWalk) {
            ManualWalkAddSheet(
                petId: scopedPetId,
                onSave: { entry in
                    modelContext.insert(entry)
                    showAddWalk = false
                },
                onCancel: { showAddWalk = false }
            )
        }
        #if os(iOS)
        .sheet(isPresented: $showAppleHealthPrePrompt) {
            AppleHealthPrePromptSheet(
                petName: FeaturePetScope.currentPetName(pets: sortedPets),
                onConnect: {
                    Task {
                        await appleHealthService.requestReadAuthorization()
                        await MainActor.run {
                            showAppleHealthPrePrompt = false
                        }
                    }
                },
                onNotNow: {
                    UserDefaults.standard.set(true, forKey: AppleHealthUserDefaultsKeys.hasPromptedHealthKit)
                    showAppleHealthPrePrompt = false
                }
            )
        }
        .task {
            await appleHealthService.refreshSummaryIfStale()
        }
        #endif
    }

    #if os(iOS)
    private var logWalkProminentCard: some View {
        Button {
            HapticManager.shared.light()
            showAddWalk = true
        } label: {
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color("BrandOrange"), Color("BrandOrange").opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    Image(systemName: "figure.walk.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log a walk with \(logWalkCardPetName)")
                        .font(.headline)
                        .foregroundStyle(Color("BrandDark"))
                    Text("Track walks you take together")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(scopedPetId == nil)
        .opacity(scopedPetId == nil ? 0.55 : 1)
    }

    @ViewBuilder
    private var appleHealthSummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color("BrandBlue"), Color("BrandPurple")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("Apple Health")
                    .font(.headline)
                    .foregroundStyle(Color("BrandDark"))
                Spacer(minLength: 0)
            }

            if appleHealthService.isConnected {
                if let s = appleHealthService.summary {
                    VStack(alignment: .leading, spacing: 8) {
                        walksStatLine(title: "Your activity this year (Apple Health)", value: String(format: "%.1f mi", s.totalMilesThisYear))
                        walksStatLine(title: "Steps", value: "\(s.totalStepsThisYear)")
                        walksStatLine(title: "Active minutes", value: "\(s.totalActiveMinutesThisYear)")
                    }
                    Text("via Apple Health")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let last = appleHealthService.lastSyncDate {
                        Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("—")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color("BrandDark"))
                    Text("via Apple Health")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let last = appleHealthService.lastSyncDate {
                        Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Connect to show steps and distance from the Health app on this iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                connectAppleHealthButton
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernCard(cornerRadius: 18, shadowRadius: 12, shadowY: 5)
    }

    private func walksStatLine(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("BrandDark"))
                .multilineTextAlignment(.trailing)
        }
    }

    private var connectAppleHealthButton: some View {
        Button {
            HapticManager.shared.selection()
            showAppleHealthPrePrompt = true
        } label: {
            Text("Connect Apple Health")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color("BrandOrange").opacity(0.15))
                .foregroundStyle(Color("BrandOrange"))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
    #endif

    private func manualWalkRow(_ entry: ManualWalkEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.walkDate.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color("BrandDark"))
            HStack(spacing: 12) {
                Label("\(entry.durationMinutes) min", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(walkDistanceLabel(entry), systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .labelStyle(.titleAndIcon)
            if !entry.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(entry.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }

    private func walkDistanceLabel(_ entry: ManualWalkEntry) -> String {
        let u = entry.distanceUnit.lowercased()
        if u == "km" {
            return String(format: "%.2f km", entry.distance)
        }
        return String(format: "%.2f mi", entry.distance)
    }

    private func deleteWalks(at offsets: IndexSet) {
        for i in offsets {
            let entry = scopedWalks[i]
            modelContext.delete(entry)
        }
    }
}

private struct ManualWalkAddSheet: View {
    let petId: UUID?
    var onSave: (ManualWalkEntry) -> Void
    var onCancel: () -> Void

    @State private var walkDate = Date()
    @State private var durationText = "30"
    @State private var distanceText = "1"
    @State private var distanceUnit: String = "mi"
    @State private var notes = ""

    private let unitChoices = ["mi", "km"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $walkDate, displayedComponents: .date)
                }
                Section {
                    TextField("Duration (minutes)", text: $durationText)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    TextField(distanceUnit == "km" ? "Distance (km)" : "Distance (miles)", text: $distanceText)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Picker("Unit", selection: $distanceUnit) {
                        ForEach(unitChoices, id: \.self) { u in
                            Text(u).tag(u)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Walk")
                }
                Section("Notes (optional)") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New walk")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color("BrandOrange"))
                        .disabled(!canSave)
                }
            }
        }
    }

    private var parsedDurationMinutes: Int? {
        let t = durationText.trimmingCharacters(in: .whitespaces)
        guard let v = Int(t), v > 0 else { return nil }
        return v
    }

    private var parsedDistance: Double? {
        let t = distanceText.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let v = Double(t), v >= 0 else { return nil }
        return v
    }

    private var canSave: Bool {
        guard petId != nil else { return false }
        guard parsedDurationMinutes != nil else { return false }
        guard parsedDistance != nil else { return false }
        return true
    }

    private func save() {
        guard let pid = petId else { return }
        guard let mins = parsedDurationMinutes, let dist = parsedDistance else { return }
        let entry = ManualWalkEntry(
            petId: pid,
            walkDate: walkDate,
            durationMinutes: mins,
            distance: dist,
            distanceUnit: distanceUnit,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(entry)
    }
}

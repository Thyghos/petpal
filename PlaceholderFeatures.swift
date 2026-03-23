// Petpal — Feature screens (local data + curated content; no “coming soon”)

import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

// MARK: - Health History

struct HealthHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VetVisitLog.visitDate, order: .reverse) private var visits: [VetVisitLog]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    @State private var showingAdd = false
    @State private var searchText = ""
    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var activePetId: UUID? {
        ActivePetStorage.activePetUUID
    }
    
    /// Only visits for the active pet. Legacy `petId == nil` is migrated on appear (not shared across pets).
    private var petScopedVisits: [VetVisitLog] {
        guard let pid = activePetId else {
            return visits.filter { $0.petId == nil }
        }
        return visits.filter { $0.petId == pid }
    }

    private var filteredVisits: [VetVisitLog] {
        guard !trimmedQuery.isEmpty else { return petScopedVisits }
        return petScopedVisits.filter { visit in
            visit.clinicName.localizedCaseInsensitiveContains(trimmedQuery)
                || visit.reason.localizedCaseInsensitiveContains(trimmedQuery)
                || visit.notes.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if petScopedVisits.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Log vaccines, checkups, and sick visits. Search by clinic, reason, or notes (e.g. “rabies”).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .padding(.bottom, 8)
                        ContentUnavailableView {
                            Label("No Visits Logged", systemImage: "heart.text.square.fill")
                        } description: {
                            Text("Tap + to add a visit. Attach vaccine records or receipts as photos or PDFs.")
                        } actions: {
                            Button("Add Visit") { showingAdd = true }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            Text("Search by clinic, reason, or notes (e.g. rabies, vaccine).")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if filteredVisits.isEmpty {
                            ContentUnavailableView {
                                Label("No matches", systemImage: "magnifyingglass")
                            } description: {
                                Text("Nothing matches “\(trimmedQuery)”. Try another word.")
                            }
                        } else {
                            ForEach(filteredVisits) { visit in
                                NavigationLink {
                                    VetVisitDetailView(visit: visit)
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(visit.clinicName.isEmpty ? "Visit" : visit.clinicName)
                                            .font(.headline)
                                        Text(visit.visitDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if !visit.reason.isEmpty {
                                            Text(visit.reason)
                                                .font(.caption)
                                                .foregroundStyle(Color.secondary.opacity(0.85))
                                                .lineLimit(2)
                                        }
                                    }
                                }
                            }
                            .onDelete(perform: deleteVisits)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search visits, notes…")
                }
            }
            .navigationTitle("Health History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .topBarTrailing) {
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
        let targets = offsets.map { filteredVisits[$0] }
        for v in targets {
            PetRecordAttachment.deleteAll(parentRecordId: v.id, parentKind: .vetVisit, context: modelContext)
            modelContext.delete(v)
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

    @State private var draftRecordId: UUID?
    @State private var clinicName = ""
    @State private var visitDate = Date()
    @State private var reason = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Clinic or veterinarian", text: $clinicName)
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
            .navigationTitle("New Visit")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if draftRecordId == nil {
                    draftRecordId = UUID()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if let rid = draftRecordId {
                            PetRecordAttachment.deleteAll(parentRecordId: rid, parentKind: .vetVisit, context: modelContext)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let rid = draftRecordId else { return }
                        let v = VetVisitLog(
                            id: rid,
                            petId: ActivePetStorage.activePetUUID,
                            visitDate: visitDate,
                            clinicName: clinicName.isEmpty ? "Visit" : clinicName,
                            reason: reason,
                            notes: notes
                        )
                        modelContext.insert(v)
                        dismiss()
                    }
                    .disabled(draftRecordId == nil)
                }
            }
        }
    }
}

// MARK: - Pet Care Notes (pet sitter instructions)

struct FoodRecommendationsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("petName") private var petName: String = "Your Pet"
    @Query private var allInstructions: [PetSitterInstructions]
    @Query(sort: \Pet.dateAdded) private var pets: [Pet]

    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif
    
    private var activePetId: UUID? {
        ActivePetStorage.activePetUUID
    }
    
    /// Per-pet row only. Legacy `petId == nil` rows are not shared across pets (see migration).
    private var instructionsForPet: PetSitterInstructions? {
        guard let pid = activePetId else {
            return allInstructions.first { $0.petId == nil }
        }
        return allInstructions.first { $0.petId == pid }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Printable sheet for pet sitter")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                if let instructions = instructionsForPet {
                    PetSitterInstructionsForm(instructions: instructions, petName: petName)
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
                                let printable = PetSitterPrintableDocument(instructions: instructions, petName: petName)
                                    .frame(width: 400, height: 680)
                                    .preferredColorScheme(.light)
                                if let img = PrintShareHelper.renderToImage(printable) {
                                    let text = "Pet Care Notes for \(petName)"
                                    DispatchQueue.main.async {
                                        sharePayload = ShareSheetPayload(items: [img, text])
                                    }
                                }
                            } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button {
                                instructions.updatedAt = Date()
                                let printable = PetSitterPrintableDocument(instructions: instructions, petName: petName)
                                    .frame(width: 400, height: 680)
                                    .preferredColorScheme(.light)
                                DispatchQueue.main.async {
                                    PrintShareHelper.printView(printable, title: "Pet Care Notes - \(petName)")
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
            }
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
                    medications: template.medications,
                    vetPhone: template.vetPhone,
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
        
        if let pid = activePetId, !allInstructions.contains(where: { $0.petId == pid }) {
            modelContext.insert(PetSitterInstructions(petId: pid))
            try? modelContext.save()
        } else if activePetId == nil && allInstructions.isEmpty {
            modelContext.insert(PetSitterInstructions(petId: nil))
            try? modelContext.save()
        }
    }
}

private struct PetSitterInstructionsForm: View {
    @Bindable var instructions: PetSitterInstructions
    let petName: String

    var body: some View {
        Form {
            Section {
                Text("Print this off for your pet sitter when you travel. Fill in everything your sitter needs to care for \(petName).")
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
            Section("Medications") {
                TextField("Dose, timing, instructions…", text: Binding(
                    get: { instructions.medications ?? "" },
                    set: { instructions.medications = $0.isEmpty ? nil : $0 }
                ), axis: .vertical)
                    .lineLimit(2...6)
            }
            Section("Vet contact") {
                TextField("Vet phone number", text: Binding(
                    get: { instructions.vetPhone ?? "" },
                    set: { instructions.vetPhone = $0.isEmpty ? nil : $0 }
                ))
                    .keyboardType(.phonePad)
            }
            Section("Special instructions") {
                TextField("Allergies, behavior notes, potty habits, no table scraps…", text: $instructions.specialInstructions, axis: .vertical)
                    .lineLimit(3...8)
            }
            Section {
                PetSitterDocumentPreview(instructions: instructions, petName: petName)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
    }
}

private struct PetSitterDocumentPreview: View {
    let instructions: PetSitterInstructions
    let petName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview for sitter")
                .font(.caption)
                .foregroundStyle(.secondary)
            PetSitterPrintableDocument(instructions: instructions, petName: petName)
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
        !instructions.favoriteFood.isEmpty || !instructions.foodSchedule.isEmpty ||
        !(instructions.foodAddons ?? "").isEmpty ||
        !instructions.favoriteTreats.isEmpty || !instructions.treatSchedule.isEmpty ||
        !(instructions.walkSchedule ?? "").isEmpty || !(instructions.medications ?? "").isEmpty ||
        !(instructions.vetPhone ?? "").isEmpty || !instructions.specialInstructions.isEmpty
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
            if let med = instructions.medications, !med.isEmpty {
                Text("Medications")
                    .font(.headline)
                    .foregroundStyle(textColor)
                Text(med)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
            }
            if let vp = instructions.vetPhone, !vp.isEmpty {
                Text("Vet contact")
                    .font(.headline)
                    .foregroundStyle(textColor)
                Text(vp)
                    .font(.subheadline)
                    .foregroundStyle(textColor)
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

    @State private var showingAdd = false
    
    private var petScopedReminders: [PetReminder] {
        let pid = ActivePetStorage.activePetUUID
        return reminders.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
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
                        ForEach(petScopedReminders) { r in
                            NavigationLink {
                                PetReminderDetailView(reminder: r)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(r.title.isEmpty ? "Reminder" : r.title)
                                            .font(.headline)
                                        Text(r.category)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(r.nextDueDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2)
                                            .foregroundStyle(r.isOverdue ? Color.red : Color.secondary.opacity(0.85))
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
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                PetReminderEditorView()
            }
        }
    }

    private func deleteReminders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(petScopedReminders[index])
        }
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
    }
}

struct PetReminderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

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
                            petId: ActivePetStorage.activePetUUID,
                            title: title.isEmpty ? "Reminder" : title,
                            notes: notes,
                            category: category,
                            nextDueDate: nextDue,
                            recurring: recurring,
                            recurrenceInterval: interval,
                            recurrenceUnit: unit
                        )
                        modelContext.insert(r)
                        dismiss()
                    }
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

    @State private var showingAdd = false
    #if os(iOS)
    @State private var sharePayload: ShareSheetPayload?
    #endif
    
    private var petScopedPolicies: [PetInsuranceInfo] {
        let pid = ActivePetStorage.activePetUUID
        return policies.filter { PetRecordFilter.matches($0.petId, selectedPetId: pid) }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
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

    @State private var draftRecordId: UUID?
    @State private var provider = ""
    @State private var number = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var renewal = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Provider", text: $provider)
                    TextField("Policy number", text: $number)
                    TextField("Phone", text: $phone)
                    DatePicker("Renewal", selection: $renewal, displayedComponents: .date)
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...8)
                }
                if let rid = draftRecordId {
                    RecordAttachmentsSection(parentRecordId: rid, parentKind: .insurance)
                }
            }
            .navigationTitle("New Policy")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if draftRecordId == nil {
                    draftRecordId = UUID()
                }
            }
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
                        let p = PetInsuranceInfo(
                            id: rid,
                            petId: ActivePetStorage.activePetUUID,
                            providerName: provider.isEmpty ? "Policy" : provider,
                            policyNumber: number,
                            phone: phone,
                            notes: notes,
                            renewalDate: renewal
                        )
                        modelContext.insert(p)
                        dismiss()
                    }
                    .disabled(draftRecordId == nil)
                }
            }
        }
    }
}

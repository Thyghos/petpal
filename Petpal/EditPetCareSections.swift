// EditPetCareSections.swift
// Emergency, allergies, vaccines, medications, attachments for Edit Pet Profile.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Vaccine / medication sheet editing (presented over full-screen edit pet)

struct VaccineEditTarget: Identifiable, Hashable {
    let id: PersistentIdentifier
    let isNew: Bool
}

struct MedicationEditTarget: Identifiable, Hashable {
    let id: PersistentIdentifier
    let isNew: Bool
}

// MARK: - Attachment flows (sheet host is `EditPetView` in PetDetailView)

enum PhotoPickRoute: String, Identifiable {
    case camera
    case library
    var id: String { rawValue }
}

struct EntrySheetToken: Identifiable {
    let id: UUID
}

struct PendingPetAttachment: Identifiable {
    let id = UUID()
    let data: Data
    let fileType: String
    let suggestedName: String
}

struct AttachmentNameSheet: View {
    let suggestedName: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                TextField("Attachment name", text: $name)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Name attachment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear { name = suggestedName }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Sections embedded in Edit Pet form

struct EditPetCareSections: View {
    @Bindable var pet: Pet
    @Environment(\.modelContext) private var modelContext

    @Binding var activeVaccineEdit: VaccineEditTarget?
    @Binding var activeMedicationEdit: MedicationEditTarget?

    @Binding var photoPickRoute: PhotoPickRoute?
    @Binding var pendingAttachment: PendingPetAttachment?
    @Binding var attachmentPreviewToken: EntrySheetToken?

    @State private var showAttachmentSourceDialog = false
    @State private var showFileImporter = false

    var body: some View {
        Group {
            Section("Emergency Contact") {
                TextField("Contact name", text: $pet.emergencyContactName)
                    .autocorrectionDisabled()
                TextField("Phone number", text: $pet.emergencyContactNumber)
                    #if os(iOS)
                    .keyboardType(.phonePad)
                    #endif
                    .autocorrectionDisabled()
            }

            Section("Allergies") {
                TextEditor(text: $pet.allergies)
                    .frame(minHeight: 88)
            }

            Section {
                NextVetAppointmentProfileFields(pet: pet)
            } header: {
                Text("Next vet visit")
            } footer: {
                Text("Set this yourself when you book a visit. It is never filled in from imported records.")
                    .font(.caption)
            }

            Section {
                ForEach(vaccinesSorted, id: \.id) { entry in
                    Button {
                        activeVaccineEdit = VaccineEditTarget(id: entry.persistentModelID, isNew: false)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Vaccine" : entry.name)
                                .foregroundStyle(Color.primary)
                            Text(vaccineSubtitle(entry))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Vaccines")
                    Spacer()
                    Button {
                        beginAddVaccine()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Add vaccine")
                }
            }

            Section {
                ForEach(medicationsSorted, id: \.id) { entry in
                    Button {
                        activeMedicationEdit = MedicationEditTarget(id: entry.persistentModelID, isNew: false)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Medication" : entry.name)
                                .foregroundStyle(Color.primary)
                            Text(medicationSubtitle(entry))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            modelContext.delete(entry)
                            try? modelContext.save()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Medications")
                    Spacer()
                    Button {
                        beginAddMedication()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Add medication")
                }
            }

            Section {
                ForEach(attachmentsSorted, id: \.id) { att in
                    Button {
                        attachmentPreviewToken = EntrySheetToken(id: att.id)
                    } label: {
                        HStack {
                            Text(att.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Attachment" : att.name)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete(perform: deleteAttachmentsAt)
            } header: {
                HStack {
                    Text("Attachments")
                    Spacer()
                    Button {
                        showAttachmentSourceDialog = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
                    .accessibilityLabel("Add attachment")
                }
            }

            Section("Other") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Special notes")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $pet.specialNotes)
                            .frame(minHeight: 120)
                        if pet.specialNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Anything else you'd like on the care card (dietary preferences, behavioral notes, special instructions...)")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Special notes")
            }
        }
        .confirmationDialog("Add attachment", isPresented: $showAttachmentSourceDialog, titleVisibility: .visible) {
            Button("Take Photo") { photoPickRoute = .camera }
            Button("Choose Photo") { photoPickRoute = .library }
            Button("Upload File") { showFileImporter = true }
            Button("Cancel", role: .cancel) {}
        }
        #if os(iOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .image, .jpeg, .png, .heic],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let got = url.startAccessingSecurityScopedResource()
                defer { if got { url.stopAccessingSecurityScopedResource() } }
                guard let data = try? Data(contentsOf: url) else { return }
                let ext = url.pathExtension.lowercased()
                let type: String
                if ext == "pdf" { type = "pdf" }
                else if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext) { type = "image" }
                else { type = ext.isEmpty ? "file" : ext }
                let base = url.deletingPathExtension().lastPathComponent
                pendingAttachment = PendingPetAttachment(data: data, fileType: type, suggestedName: base.isEmpty ? "File" : base)
            case .failure:
                break
            }
        }
        #endif
    }

    private var vaccinesSorted: [VaccineEntry] {
        pet.vaccinesArray.sorted { $0.dateAdministered > $1.dateAdministered }
    }

    private var medicationsSorted: [MedicationEntry] {
        pet.medicationsArray.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var attachmentsSorted: [PetAttachment] {
        pet.attachmentsArray.sorted { $0.dateAdded > $1.dateAdded }
    }

    private func vaccineSubtitle(_ entry: VaccineEntry) -> String {
        let admin = entry.dateAdministered.formatted(date: .abbreviated, time: .omitted)
        if let exp = entry.dateExpires {
            return "Given \(admin) · exp \(exp.formatted(date: .abbreviated, time: .omitted))"
        }
        return "Given \(admin)"
    }

    private func medicationSubtitle(_ entry: MedicationEntry) -> String {
        let a = entry.amount.trimmingCharacters(in: .whitespacesAndNewlines)
        let f = entry.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        if a.isEmpty && f.isEmpty { return "—" }
        if f.isEmpty { return a }
        if a.isEmpty { return f }
        return "\(a) · \(f)"
    }

    private func beginAddVaccine() {
        let e = VaccineEntry(name: "", dateAdministered: Date(), dateExpires: nil, pet: pet)
        pet.appendVaccine(e)
        try? modelContext.save()
        DispatchQueue.main.async {
            activeVaccineEdit = VaccineEditTarget(id: e.persistentModelID, isNew: true)
        }
    }

    private func beginAddMedication() {
        let e = MedicationEntry(name: "", amount: "", frequency: "", pet: pet)
        pet.appendMedication(e)
        try? modelContext.save()
        DispatchQueue.main.async {
            activeMedicationEdit = MedicationEditTarget(id: e.persistentModelID, isNew: true)
        }
    }

    private func deleteAttachmentsAt(offsets: IndexSet) {
        let rows = attachmentsSorted
        for i in offsets {
            guard rows.indices.contains(i) else { continue }
            modelContext.delete(rows[i])
        }
    }
}

// MARK: - Next vet appointment (manual profile field)

/// Shared with ``EditPetCareSections`` and ``ModernEditPetSheet`` (HomeView).
struct NextVetAppointmentProfileFields: View {
    @Bindable var pet: Pet

    var body: some View {
        Toggle("Set next vet appointment", isOn: Binding(
            get: { pet.nextVetAppointmentDate != nil },
            set: { on in
                if on {
                    if pet.nextVetAppointmentDate == nil {
                        pet.nextVetAppointmentDate = Calendar.current.startOfDay(for: Date())
                    }
                } else {
                    pet.nextVetAppointmentDate = nil
                }
            }
        ))
        if pet.nextVetAppointmentDate != nil {
            DatePicker(
                "Next Vet Appointment",
                selection: Binding(
                    get: { pet.nextVetAppointmentDate ?? Date() },
                    set: { pet.nextVetAppointmentDate = $0 }
                ),
                displayedComponents: .date
            )
        }
    }
}

// MARK: - Vaccine edit sheet

struct VaccineEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var vaccine: VaccineEntry
    let isNewEntry: Bool

    @State private var name: String = ""
    @State private var dateAdministered: Date = Date()
    @State private var hasExpiry = false
    @State private var dateExpires: Date = Date()
    @State private var cancelSnapshot: (name: String, dateAdministered: Date, dateExpires: Date?)?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Vaccine name", text: $name)
                    .autocorrectionDisabled()
                DatePicker("Date administered", selection: $dateAdministered, displayedComponents: .date)
                Toggle("Expiration date", isOn: $hasExpiry)
                if hasExpiry {
                    DatePicker("Expires", selection: $dateExpires, displayedComponents: .date)
                }
            }
            .navigationTitle("Vaccine")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                if !isNewEntry, cancelSnapshot == nil {
                    cancelSnapshot = (vaccine.name, vaccine.dateAdministered, vaccine.dateExpires)
                }
                name = vaccine.name
                dateAdministered = vaccine.dateAdministered
                if let exp = vaccine.dateExpires {
                    hasExpiry = true
                    dateExpires = exp
                } else {
                    hasExpiry = false
                    dateExpires = Calendar.current.date(byAdding: .year, value: 1, to: vaccine.dateAdministered) ?? vaccine.dateAdministered
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelEdits() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdits() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveEdits() {
        vaccine.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        vaccine.dateAdministered = dateAdministered
        vaccine.dateExpires = hasExpiry ? dateExpires : nil
        try? modelContext.save()
        dismiss()
    }

    private func cancelEdits() {
        if isNewEntry {
            modelContext.delete(vaccine)
            try? modelContext.save()
        } else if let s = cancelSnapshot {
            vaccine.name = s.name
            vaccine.dateAdministered = s.dateAdministered
            vaccine.dateExpires = s.dateExpires
        }
        dismiss()
    }
}

// MARK: - Medication edit sheet

struct MedicationEditSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var medication: MedicationEntry
    let isNewEntry: Bool

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var frequency: String = ""
    @State private var cancelSnapshot: (name: String, amount: String, frequency: String)?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Medication name", text: $name)
                    .autocorrectionDisabled()
                TextField("Amount (e.g. 10mg)", text: $amount)
                    .autocorrectionDisabled()
                TextField("Frequency (e.g. twice daily)", text: $frequency)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Medication")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                if !isNewEntry, cancelSnapshot == nil {
                    cancelSnapshot = (medication.name, medication.amount, medication.frequency)
                }
                name = medication.name
                amount = medication.amount
                frequency = medication.frequency
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelEdits() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdits() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveEdits() {
        medication.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.amount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        medication.frequency = frequency.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }

    private func cancelEdits() {
        if isNewEntry {
            modelContext.delete(medication)
            try? modelContext.save()
        } else if let s = cancelSnapshot {
            medication.name = s.name
            medication.amount = s.amount
            medication.frequency = s.frequency
        }
        dismiss()
    }
}

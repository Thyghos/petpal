// ShelterImportReviewView.swift
// Review and save shelter PDF import into a new or existing `Pet`.

import SwiftUI
import SwiftData

enum ShelterImportProfileMode: Equatable {
    case createNewPet
    case updateExistingPet(Pet)
}

enum ShelterSexPicker: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case unknown = "Unknown"
    var id: String { rawValue }
}

struct ShelterVaccinationRow: Identifiable, Equatable {
    var id: UUID
    var name: String
    var date: Date?

    init(id: UUID = UUID(), name: String, date: Date?) {
        self.id = id
        self.name = name
        self.date = date
    }
}

struct ShelterImportReviewFormState {
    var petName: String
    var species: String
    var breed: String
    var showBirthDate: Bool
    var birthDate: Date
    var sex: ShelterSexPicker
    var includeSpayStatus: Bool
    var isSpayedNeutered: Bool
    var colorMarkings: String
    var microchipNumber: String
    var includeWeight: Bool
    var weightLbsText: String
    var showAdoptionDate: Bool
    var adoptionDate: Date
    var shelterName: String
    var vaccinations: [ShelterVaccinationRow]
    var medications: [ParsedMedication]
    var notes: String

    init(from result: ShelterRecordParseResult) {
        petName = result.petName ?? ""
        species = result.species ?? "Dog"
        breed = result.breed ?? ""
        if let bd = result.birthDate {
            showBirthDate = true
            birthDate = bd
        } else {
            showBirthDate = false
            birthDate = Calendar.current.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        }
        sex = Self.mapSex(result.sex)
        if let sn = result.isSpayedNeutered {
            includeSpayStatus = true
            isSpayedNeutered = sn
        } else {
            includeSpayStatus = false
            isSpayedNeutered = false
        }
        colorMarkings = result.colorMarkings ?? ""
        microchipNumber = result.microchipNumber ?? ""
        if let kg = result.weightKg {
            includeWeight = true
            weightLbsText = String(format: "%.1f", kg * 2.2046226218)
        } else {
            includeWeight = false
            weightLbsText = ""
        }
        if let ad = result.adoptionDate {
            showAdoptionDate = true
            adoptionDate = ad
        } else {
            showAdoptionDate = false
            adoptionDate = Date()
        }
        shelterName = result.shelterName ?? ""
        let vrows = result.vaccinations.map { ShelterVaccinationRow(name: $0.name, date: $0.date) }
        vaccinations = vrows.isEmpty ? [ShelterVaccinationRow(name: "", date: nil)] : vrows
        let meds = result.medications.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        medications = meds.isEmpty ? [ParsedMedication(name: "")] : meds
        notes = result.notes ?? ""
    }

    private static func mapSex(_ raw: String?) -> ShelterSexPicker {
        guard let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !t.isEmpty else {
            return .unknown
        }
        if t.hasPrefix("m") || t == "male" || t == "m" { return .male }
        if t.hasPrefix("f") || t == "female" || t == "f" { return .female }
        return .unknown
    }

    func resolvedWeightKg() -> Double? {
        guard includeWeight else { return nil }
        let trimmed = weightLbsText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let lbs = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { return nil }
        guard lbs > 0 else { return nil }
        return lbs / 2.2046226218
    }

    func shelterMetadataLines() -> String {
        var lines: [String] = []
        switch sex {
        case .male:
            lines.append("Sex: Male")
        case .female:
            lines.append("Sex: Female")
        case .unknown:
            break
        }
        if includeSpayStatus {
            lines.append("Spayed/neutered: \(isSpayedNeutered ? "Yes" : "No")")
        }
        let color = colorMarkings.trimmingCharacters(in: .whitespacesAndNewlines)
        if !color.isEmpty {
            lines.append("Color / markings: \(color)")
        }
        if showAdoptionDate {
            lines.append("Adoption date: \(adoptionDate.formatted(date: .long, time: .omitted))")
        }
        let n = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !n.isEmpty {
            lines.append("Record notes: \(n)")
        }
        lines.append("Imported from breeder or rescue document on \(Date().formatted(date: .long, time: .omitted)).")
        return lines.joined(separator: "\n")
    }
}

struct ShelterImportReviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.dateAdded) private var allPets: [Pet]

    let mode: ShelterImportProfileMode
    @State private var form: ShelterImportReviewFormState
    let onCancel: () -> Void
    let onSuccessNewPet: () -> Void
    let onSuccessExistingPet: () -> Void

    init(
        mode: ShelterImportProfileMode,
        initial: ShelterImportReviewFormState,
        onCancel: @escaping () -> Void,
        onSuccessNewPet: @escaping () -> Void,
        onSuccessExistingPet: @escaping () -> Void
    ) {
        self.mode = mode
        _form = State(initialValue: initial)
        self.onCancel = onCancel
        self.onSuccessNewPet = onSuccessNewPet
        self.onSuccessExistingPet = onSuccessExistingPet
    }

    private var primaryTitle: String {
        switch mode {
        case .createNewPet: return "Create Pet Profile"
        case .updateExistingPet: return "Update Profile"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    card {
                        TextField("Pet name", text: $form.petName)
                        TextField("Species", text: $form.species)
                            .textInputAutocapitalization(.words)
                        TextField("Breed", text: $form.breed)
                    }

                    card {
                        Toggle("Birthday", isOn: $form.showBirthDate)
                        if form.showBirthDate {
                            DatePicker("Birthday", selection: $form.birthDate, in: ...Date(), displayedComponents: .date)
                        }
                        Picker("Sex", selection: $form.sex) {
                            ForEach(ShelterSexPicker.allCases) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        Toggle("Include spay/neuter status", isOn: $form.includeSpayStatus)
                        if form.includeSpayStatus {
                            Toggle("Spayed or neutered", isOn: $form.isSpayedNeutered)
                        }
                        TextField("Color / markings", text: $form.colorMarkings, axis: .vertical)
                            .lineLimit(2...4)
                    }

                    card {
                        TextField("Microchip number", text: $form.microchipNumber)
                            .textInputAutocapitalization(.never)
                        Toggle("Include weight", isOn: $form.includeWeight)
                        if form.includeWeight {
                            TextField("Weight (lbs)", text: $form.weightLbsText)
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif
                        }
                    }

                    card {
                        Toggle("Adoption date", isOn: $form.showAdoptionDate)
                        if form.showAdoptionDate {
                            DatePicker("Adoption date", selection: $form.adoptionDate, displayedComponents: .date)
                        }
                        TextField("Breeder or rescue name", text: $form.shelterName)
                    }

                    card {
                        HStack {
                            Text("Vaccinations")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                form.vaccinations.append(ShelterVaccinationRow(name: "", date: nil))
                            } label: {
                                Label("Add", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                        ForEach(Array(form.vaccinations.enumerated()), id: \.element.id) { index, _ in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Vaccine name", text: Binding(
                                    get: { form.vaccinations[index].name },
                                    set: { form.vaccinations[index].name = $0 }
                                ))
                                DatePicker(
                                    "Date given (optional)",
                                    selection: Binding(
                                        get: { form.vaccinations[index].date ?? Date() },
                                        set: { form.vaccinations[index].date = $0 }
                                    ),
                                    displayedComponents: .date
                                )
                            }
                            if form.vaccinations.count > 1 {
                                Button(role: .destructive) {
                                    form.vaccinations.remove(at: index)
                                } label: {
                                    Label("Remove", systemImage: "minus.circle")
                                        .font(.caption)
                                }
                            }
                            Divider()
                        }
                    }

                    card {
                        HStack {
                            Text("Medications")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                form.medications.append(ParsedMedication(name: ""))
                            } label: {
                                Label("Add", systemImage: "plus.circle.fill")
                                    .font(.subheadline)
                            }
                        }
                        ForEach(Array(form.medications.enumerated()), id: \.element.id) { index, _ in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 8) {
                                    TextField("Name", text: Binding(
                                        get: { form.medications[index].name },
                                        set: { form.medications[index].name = $0 }
                                    ))
                                    TextField("Dosage (optional)", text: Binding(
                                        get: { form.medications[index].dosage ?? "" },
                                        set: { form.medications[index].dosage = $0.isEmpty ? nil : $0 }
                                    ))
                                    TextField("Frequency (optional)", text: Binding(
                                        get: { form.medications[index].frequency ?? "" },
                                        set: { form.medications[index].frequency = $0.isEmpty ? nil : $0 }
                                    ))
                                }
                                if form.medications.count > 1 {
                                    Button {
                                        form.medications.remove(at: index)
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            Divider()
                        }
                    }

                    card {
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))
                        TextField("Additional notes", text: $form.notes, axis: .vertical)
                            .lineLimit(4...12)
                    }

                    VStack(spacing: 12) {
                        Button(action: save) {
                            Text(primaryTitle)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color("BrandOrange"))

                        Button("Cancel", role: .cancel) {
                            onCancel()
                        }
                        .frame(maxWidth: .infinity)

                        Text("Review AI-extracted data before saving.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Review Imported Records")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color("BrandBlue").opacity(0.12), lineWidth: 1)
        )
    }

    private func save() {
        let meta = form.shelterMetadataLines()
        let name = form.petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let species = form.species.trimmingCharacters(in: .whitespacesAndNewlines)
        let breed = form.breed.trimmingCharacters(in: .whitespacesAndNewlines)
        let shelter = form.shelterName.trimmingCharacters(in: .whitespacesAndNewlines)
        let micro = form.microchipNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .createNewPet:
            let weightVal: Double = {
                guard let kg = form.resolvedWeightKg() else { return 0 }
                return kg * 2.2046226218
            }()
            let newPet = Pet(
                name: name.isEmpty ? "My Pet" : name,
                species: species.isEmpty ? "Dog" : species,
                breed: breed,
                weight: weightVal,
                weightUnit: "lbs",
                dateOfBirth: form.showBirthDate ? form.birthDate : nil,
                vetName: "",
                vetPhone: "",
                vetEmail: "",
                groomerName: shelter,
                groomerPhone: "",
                microchipNumber: micro,
                microchipRegistry: meta
            )
            newPet.dateAdded = form.showAdoptionDate ? form.adoptionDate : Date()
            for p in allPets {
                p.isActive = false
            }
            modelContext.insert(newPet)
            newPet.isActive = true
            newPet.syncToLegacyAppStorage()
            let importInfo = addCertificatesAndReminders(for: newPet)
            addWeightEntryIfNeeded(for: newPet.id)
            try? modelContext.save()
            #if os(iOS)
            ShelterImportSourceAttachment.attachAfterShelterSave(
                modelContext: modelContext,
                petName: newPet.name,
                anchorDate: importInfo.anchor,
                anchorLabel: importInfo.anchorLabel,
                vaccineCertificates: importInfo.vaccinePairs,
                medicationReminderIds: importInfo.medicationReminderIds,
                storedDocumentId: importInfo.storedDocumentId
            )
            try? modelContext.save()
            PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
            #endif
            onSuccessNewPet()

        case .updateExistingPet(let pet):
            if !name.isEmpty { pet.name = name }
            if !species.isEmpty { pet.species = species }
            if !breed.isEmpty { pet.breed = breed }
            if form.showBirthDate {
                pet.dateOfBirth = form.birthDate
            }
            if !shelter.isEmpty { pet.groomerName = shelter }
            if !micro.isEmpty { pet.microchipNumber = micro }
            if let kg = form.resolvedWeightKg() {
                pet.weight = kg * 2.2046226218
                pet.weightUnit = "lbs"
            }
            if !meta.isEmpty {
                let existing = pet.microchipRegistry.trimmingCharacters(in: .whitespacesAndNewlines)
                if existing.isEmpty {
                    pet.microchipRegistry = meta
                } else if !existing.contains(meta) {
                    pet.microchipRegistry = existing + "\n\n---\n" + meta
                }
            }
            if pet.isActive {
                pet.syncToLegacyAppStorage()
            }
            let importInfo = addCertificatesAndReminders(for: pet)
            addWeightEntryIfNeeded(for: pet.id)
            try? modelContext.save()
            #if os(iOS)
            ShelterImportSourceAttachment.attachAfterShelterSave(
                modelContext: modelContext,
                petName: pet.name,
                anchorDate: importInfo.anchor,
                anchorLabel: importInfo.anchorLabel,
                vaccineCertificates: importInfo.vaccinePairs,
                medicationReminderIds: importInfo.medicationReminderIds,
                storedDocumentId: importInfo.storedDocumentId
            )
            try? modelContext.save()
            PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
            #endif
            onSuccessExistingPet()
        }
    }

    private struct ShelterImportRowsInfo {
        var vaccinePairs: [(vaccineName: String, id: UUID)]
        var medicationReminderIds: [UUID]
        var storedDocumentId: UUID?
        var anchor: Date
        var anchorLabel: String
    }

    private func addCertificatesAndReminders(for pet: Pet) -> ShelterImportRowsInfo {
        let pid = pet.id
        let anchor = form.showAdoptionDate ? form.adoptionDate : Date()
        let anchorLabel = anchor.formatted(date: .abbreviated, time: .omitted)
        let dueSeed = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: anchor) ?? anchor

        var vaccinePairs: [(vaccineName: String, id: UUID)] = []
        var medicationReminderIds: [UUID] = []

        #if os(iOS)
        let coord = PDFImportCoordinator.shared
        let hasShelterFile = (coord.lastShelterImportPDFData.map { !$0.isEmpty } ?? false) || coord.sourceImage != nil
        #else
        let hasShelterFile = false
        #endif

        var storedDocumentId: UUID?
        if hasShelterFile {
            let displayName = pet.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Pet" : pet.name
            let doc = StoredVetDocument(
                title: "Breeder or rescue record — \(displayName)",
                notes: "",
                documentKind: "Breeder or rescue",
                recordDate: anchor,
                createdAt: Date()
            )
            modelContext.insert(doc)
            storedDocumentId = doc.id
        }

        for row in form.vaccinations {
            let t = row.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { continue }
            var noteParts: [String] = []
            if let d = row.date {
                noteParts.append("Given: \(d.formatted(date: .abbreviated, time: .omitted))")
            }
            noteParts.append("From breeder or rescue import.")
            let c = PetCertificate(
                petId: pid,
                title: t,
                notes: noteParts.joined(separator: " "),
                category: "Vaccine",
                expirationDate: nil
            )
            modelContext.insert(c)
            vaccinePairs.append((vaccineName: t, id: c.id))
        }

        for med in form.medications {
            let n = med.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { continue }
            var noteLines: [String] = []
            if let d = med.dosage, !d.isEmpty { noteLines.append("Dosage: \(d)") }
            if let f = med.frequency, !f.isEmpty { noteLines.append("Frequency: \(f)") }
            noteLines.append("From breeder or rescue import.")
            let r = PetReminder(
                petId: pid,
                title: n,
                notes: noteLines.joined(separator: "\n"),
                category: "General",
                nextDueDate: dueSeed,
                recurring: false,
                recurrenceInterval: 1,
                recurrenceUnit: "month"
            )
            modelContext.insert(r)
            medicationReminderIds.append(r.id)
        }

        return ShelterImportRowsInfo(
            vaccinePairs: vaccinePairs,
            medicationReminderIds: medicationReminderIds,
            storedDocumentId: storedDocumentId,
            anchor: anchor,
            anchorLabel: anchorLabel
        )
    }

    private func addWeightEntryIfNeeded(for petId: UUID) {
        guard let kg = form.resolvedWeightKg() else { return }
        let entry = PetWeightEntry(
            petId: petId,
            entryDate: form.showAdoptionDate ? form.adoptionDate : Date(),
            weightKg: kg
        )
        modelContext.insert(entry)
    }
}

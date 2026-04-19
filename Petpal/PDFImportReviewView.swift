// PDFImportReviewView.swift
// Editable review of AI-extracted vet visit data before saving to SwiftData.

import SwiftUI
import SwiftData

struct PDFImportReviewFormState: Equatable {
    var visitDate: Date
    var vetName: String
    var clinicName: String
    var diagnosesText: String
    var medications: [ParsedMedication]
    var vaccinesText: String
    /// Structured vaccine names with due/expiration dates when the parser extracted them.
    var vaccinesWithDueDates: [ParsedVaccineDue]
    var weightUsesKg: Bool
    var weightText: String
    var includeWeight: Bool
    var includeNextAppointment: Bool
    var nextAppointmentDate: Date
    var notes: String

    init(from result: VetRecordParseResult) {
        visitDate = result.visitDate ?? Date()
        vetName = result.vetName ?? ""
        clinicName = result.clinicName ?? ""
        diagnosesText = result.diagnoses.joined(separator: ", ")
        medications = result.medications.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if medications.isEmpty {
            medications = [ParsedMedication(name: "")]
        }
        vaccinesText = result.vaccinesGiven.joined(separator: ", ")
        vaccinesWithDueDates = result.vaccinesWithDueDates
        weightUsesKg = false
        includeWeight = result.weightKg != nil
        if let kg = result.weightKg {
            weightText = PDFImportReviewFormState.formatWeight(kg, usesKg: false)
        } else {
            weightText = ""
        }
        // Never auto-enable next appointment from parsing — user opts in and picks a date manually for reminders/notes.
        includeNextAppointment = false
        nextAppointmentDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        notes = result.notes ?? ""
    }

    private static func formatWeight(_ kg: Double, usesKg: Bool) -> String {
        if usesKg {
            return String(format: "%.2f", kg)
        }
        let lbs = kg * 2.2046226218
        return String(format: "%.1f", lbs)
    }

    func resolvedWeightKg() -> Double? {
        guard includeWeight else { return nil }
        let trimmed = weightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed.replacingOccurrences(of: ",", with: ".")) else { return nil }
        guard value > 0 else { return nil }
        if weightUsesKg {
            return value
        }
        return value / 2.2046226218
    }

    func vaccineNames() -> [String] {
        vaccinesText
            .split { $0 == "," || $0 == ";" || $0 == "\n" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func medicationsForSave() -> [ParsedMedication] {
        medications.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct PDFImportReviewView: View {
    @Environment(\.modelContext) private var modelContext
    #if os(iOS)
    @ObservedObject private var pdfImportCoordinator = PDFImportCoordinator.shared
    #endif

    let petId: UUID?
    let onCancel: () -> Void
    /// Third parameter is an optional toast override; pass `nil` for the default “visit saved” line.
    let onSaveSuccess: (_ vaccineCertificatesCreated: Int, _ medicationRemindersCreated: Int, _ messageOverride: String?) -> Void

    @State private var form: PDFImportReviewFormState

    @State private var showingReminderPrompt = false
    @State private var pendingReminder: Bool?
    @State private var profileMergeProposal: VetVisitProfileUpdateProposal?
    @State private var profileMergeVisitDate: Date?
    @State private var profileMergePetName: String = ""
    @State private var pendingSaveVaxCount: Int = 0
    @State private var pendingSaveMedCount: Int = 0
    @State private var pendingSaveMessageOverride: String? = nil
    #if os(iOS)
    @State private var showingVaccineReminderSetup = false
    @State private var vaccinesForReminderSetup: [String] = []
    @State private var reminderSetupVisitDate = Date()
    @State private var reminderSetupClinicName = ""
    @State private var reminderSetupCertificates: [PetCertificate] = []
    @State private var reminderSetupParsedHints: [ParsedVaccineDue] = []
    @State private var reminderSetupActivePet: Pet?
    @State private var lastVaccineRemindersCreatedCount = 0
    #endif

    init(
        petId: UUID?,
        initial: PDFImportReviewFormState,
        onCancel: @escaping () -> Void,
        onSaveSuccess: @escaping (_ vaccineCertificatesCreated: Int, _ medicationRemindersCreated: Int, _ messageOverride: String?) -> Void
    ) {
        self.petId = petId
        _form = State(initialValue: initial)
        self.onCancel = onCancel
        self.onSaveSuccess = onSaveSuccess
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    formSection {
                        DatePicker("Visit date", selection: $form.visitDate, displayedComponents: .date)
                        TextField("Vet name", text: $form.vetName)
                        TextField("Clinic name", text: $form.clinicName)
                    }

                    formSection {
                        Text("Diagnoses")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("BrandDark"))
                        TextField("Comma-separated diagnoses", text: $form.diagnosesText, axis: .vertical)
                            .lineLimit(3...8)
                    }

                    formSection {
                        HStack {
                            Text("Medications")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color("BrandDark"))
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
                                    .buttonStyle(.plain)
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }

                    formSection {
                        Text("Vaccines given")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("BrandDark"))
                        TextField("Comma-separated vaccines", text: $form.vaccinesText, axis: .vertical)
                            .lineLimit(2...6)
                    }

                    formSection {
                        Toggle("Include weight", isOn: $form.includeWeight)
                        if form.includeWeight {
                            HStack {
                                TextField(form.weightUsesKg ? "Weight (kg)" : "Weight (lbs)", text: $form.weightText)
                                    .keyboardType(.decimalPad)
                                Picker("Unit", selection: $form.weightUsesKg) {
                                    Text("lbs").tag(false)
                                    Text("kg").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 120)
                            }
                        }
                    }

                    formSection {
                        Toggle("Include next appointment", isOn: $form.includeNextAppointment)
                        if form.includeNextAppointment {
                            DatePicker("Next appointment", selection: $form.nextAppointmentDate, displayedComponents: [.date, .hourAndMinute])
                        }
                    }

                    formSection {
                        Text("Notes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("BrandDark"))
                        TextField("Additional notes", text: $form.notes, axis: .vertical)
                            .lineLimit(4...14)
                    }

                    VStack(spacing: 12) {
                        Button {
                            startSavePipeline()
                        } label: {
                            Text("Save to Health History")
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
            .navigationTitle("Review import")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Update Pet Profile?", isPresented: Binding(
                get: { profileMergeProposal != nil },
                set: { if !$0 { profileMergeProposal = nil } }
            )) {
                Button("Update Profile") {
                    finishProfileMergeFromReview(apply: true)
                }
                Button("Skip", role: .cancel) {
                    finishProfileMergeFromReview(apply: false)
                }
            } message: {
                if let prop = profileMergeProposal {
                    Text(reviewProfileAlertBody(petName: profileMergePetName, proposal: prop))
                }
            }
            .alert("Create a reminder for your next appointment?", isPresented: $showingReminderPrompt) {
                Button("Yes") {
                    pendingReminder = true
                    commitSave()
                }
                Button("No", role: .cancel) {
                    pendingReminder = false
                    commitSave()
                }
            } message: {
                Text("Petpal will schedule a local notification for this date.")
            }
            #if os(iOS)
            .sheet(isPresented: $showingVaccineReminderSetup, onDismiss: {
                flushReviewSaveSuccess()
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
                            lastVaccineRemindersCreatedCount = count
                        }
                    )
                    .presentationDragIndicator(.visible)
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func formSection<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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

    private func startSavePipeline() {
        guard petId != nil else { return }
        considerReminderPrompt()
    }

    private func considerReminderPrompt() {
        guard form.includeNextAppointment else {
            pendingReminder = false
            commitSave()
            return
        }
        showingReminderPrompt = true
    }

    /// Structured visit summary for Health History notes; omits empty sections.
    private func buildStructuredImportNotes() -> String {
        var blocks: [String] = []

        let vet = form.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !vet.isEmpty {
            blocks.append("Veterinarian: \(vet)")
        }

        let vaxList = form.vaccineNames()
        if !vaxList.isEmpty {
            blocks.append("Vaccines given: \(vaxList.joined(separator: ", "))")
        }

        let meds = form.medicationsForSave()
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

        if form.includeWeight, let kg = form.resolvedWeightKg() {
            let lbs = kg * 2.2046226218
            blocks.append("Weight recorded: \(String(format: "%.1f", lbs)) lbs")
        }

        if form.includeNextAppointment {
            let when = form.nextAppointmentDate.formatted(date: .long, time: .shortened)
            blocks.append("Next appointment: \(when)")
        }

        let userNotes = form.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userNotes.isEmpty {
            blocks.append(userNotes)
        }

        let importDate = Date().formatted(date: .long, time: .omitted)
        blocks.append("Imported via PDF on \(importDate).")

        return blocks.joined(separator: "\n\n")
    }

    private func commitSave() {
        guard let petId else { return }

        let visitId = UUID()
        let clinicDisplay: String = {
            let c = form.clinicName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !c.isEmpty { return c }
            let v = form.vetName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
            return "Visit"
        }()

        let visitDateLabel = form.visitDate.formatted(date: .abbreviated, time: .omitted)
        let reason = form.diagnosesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let combinedNotes = buildStructuredImportNotes()

        let visit = VetVisitLog(
            id: visitId,
            petId: petId,
            visitDate: form.visitDate,
            clinicName: clinicDisplay,
            reason: reason,
            notes: combinedNotes
        )
        modelContext.insert(visit)

        if let kg = form.resolvedWeightKg() {
            let entry = PetWeightEntry(
                petId: petId,
                entryDate: form.visitDate,
                weightKg: kg
            )
            modelContext.insert(entry)
        }

        let vaxNames = form.vaccineNames()
        var vaccinePairs: [(vaccineName: String, id: UUID)] = []
        var createdVaccineCertificates: [PetCertificate] = []
        for name in vaxNames {
            let cert = PetCertificate(
                petId: petId,
                title: name,
                notes: "Added from vet visit on \(visitDateLabel)",
                category: "Vaccine",
                expirationDate: nil
            )
            modelContext.insert(cert)
            createdVaccineCertificates.append(cert)
            vaccinePairs.append((vaccineName: name, id: cert.id))
        }

        let meds = form.medicationsForSave()
        var medicationReminderCount = 0
        var medicationReminderIds: [UUID] = []
        let medNextDue = Calendar.current.date(byAdding: .day, value: 1, to: form.visitDate) ?? form.visitDate
        for med in meds {
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
                petId: petId,
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

        var nextAppointmentReminderId: UUID?
        if pendingReminder == true, form.includeNextAppointment {
            let reminder = PetReminder(
                petId: petId,
                title: "Vet appointment — \(clinicDisplay)",
                notes: "Created from imported vet record.",
                category: "General",
                nextDueDate: form.nextAppointmentDate,
                recurring: false,
                recurrenceInterval: 1,
                recurrenceUnit: "month"
            )
            modelContext.insert(reminder)
            nextAppointmentReminderId = reminder.id
        }

        do {
            try modelContext.save()
        } catch {
            return
        }

        #if os(iOS)
        VetImportSourceAttachment.attachAfterVetVisitSave(
            modelContext: modelContext,
            visitId: visitId,
            visitDate: form.visitDate,
            clinicDisplay: clinicDisplay,
            visitDateLabel: visitDateLabel,
            vaccineCertificates: vaccinePairs,
            medicationReminderIds: medicationReminderIds,
            nextAppointmentReminderId: nextAppointmentReminderId
        )
        try? modelContext.save()
        #endif

        #if os(iOS)
        PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)

        let pidConst = petId
        var fd = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == pidConst })
        fd.fetchLimit = 1
        let fetchedPet = try? modelContext.fetch(fd).first
        if let pet = fetchedPet {
            let synthetic = form.asSyntheticParseResult()
            if let proposal = VetVisitProfileUpdateSupport.buildProposal(
                pet: pet,
                parsed: synthetic,
                form: form,
                pendingVaccineNames: vaxNames,
                pendingMedications: meds,
                importWeightKg: form.resolvedWeightKg()
            ), proposal.hasWork {
                profileMergeProposal = proposal
                profileMergeVisitDate = form.visitDate
                let pn = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
                profileMergePetName = pn.isEmpty ? "your pet" : pn
                pendingSaveVaxCount = vaxNames.count
                pendingSaveMedCount = medicationReminderCount
                stashVaccineReminderContext(
                    vaccines: vaxNames,
                    certificates: createdVaccineCertificates,
                    visitDate: form.visitDate,
                    clinic: clinicDisplay,
                    parsedHints: form.vaccinesWithDueDates,
                    activePet: pet
                )
                return
            }
        }
        stashVaccineReminderContext(
            vaccines: vaxNames,
            certificates: createdVaccineCertificates,
            visitDate: form.visitDate,
            clinic: clinicDisplay,
            parsedHints: form.vaccinesWithDueDates,
            activePet: fetchedPet
        )
        pendingSaveMessageOverride = nil
        finalizeReviewSaveAfterProfileAndVaccines()
        #else
        onSaveSuccess(vaxNames.count, medicationReminderCount, nil)
        #endif
    }

    #if os(iOS)
    private func finishProfileMergeFromReview(apply: Bool) {
        let vax = pendingSaveVaxCount
        let medc = pendingSaveMedCount
        defer {
            profileMergeProposal = nil
            profileMergeVisitDate = nil
        }
        guard let proposal = profileMergeProposal,
              let pid = petId,
              let vd = profileMergeVisitDate else {
            onSaveSuccess(vax, medc, nil)
            return
        }
        let pidConst = pid
        var fd = FetchDescriptor<Pet>(predicate: #Predicate<Pet> { $0.id == pidConst })
        fd.fetchLimit = 1
        guard let pet = try? modelContext.fetch(fd).first else {
            onSaveSuccess(vax, medc, nil)
            return
        }
        if apply {
            VetVisitProfileUpdateSupport.apply(proposal: proposal, to: pet, visitDate: vd, modelContext: modelContext)
        }
        pendingSaveMessageOverride = apply ? "Profile updated successfully" : "Saved to Health History only"
        finalizeReviewSaveAfterProfileAndVaccines()
    }

    private func finalizeReviewSaveAfterProfileAndVaccines() {
        if !vaccinesForReminderSetup.isEmpty, reminderSetupActivePet != nil {
            lastVaccineRemindersCreatedCount = 0
            showingVaccineReminderSetup = true
            return
        }
        flushReviewSaveSuccess()
    }

    private func stashVaccineReminderContext(
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

    private func flushReviewSaveSuccess() {
        var messageOverride = pendingSaveMessageOverride
        pendingSaveMessageOverride = nil
        if lastVaccineRemindersCreatedCount > 0 {
            let line = "\(lastVaccineRemindersCreatedCount) vaccine reminder(s) set ✓"
            if let existing = messageOverride {
                messageOverride = "\(existing) · \(line)"
            } else {
                messageOverride = line
            }
            lastVaccineRemindersCreatedCount = 0
        }
        onSaveSuccess(pendingSaveVaxCount, pendingSaveMedCount, messageOverride)
    }

    private func reviewProfileAlertBody(petName: String, proposal: VetVisitProfileUpdateProposal) -> String {
        let n = petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "your pet" : petName
        return """
        We found the following info in your vet visit record:

        \(proposal.detailMessage)

        Would you like to update \(n)'s profile and Care Card with this information?
        """
    }
    #endif
}

extension PDFImportReviewFormState {
    func asSyntheticParseResult() -> VetRecordParseResult {
        let dx = diagnosesText
            .split { $0 == "," || $0 == ";" || $0 == "\n" }
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return VetRecordParseResult(
            visitDate: visitDate,
            vetName: vetName.isEmpty ? nil : vetName,
            clinicName: clinicName.isEmpty ? nil : clinicName,
            diagnoses: dx,
            medications: medicationsForSave(),
            vaccinesGiven: vaccineNames(),
            vaccinesWithDueDates: vaccinesWithDueDates,
            weightKg: resolvedWeightKg(),
            nextAppointmentDate: includeNextAppointment ? nextAppointmentDate : nil,
            notes: notes.isEmpty ? nil : notes
        )
    }
}

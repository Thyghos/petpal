// VetVisitProfileUpdateSupport.swift
// After vet visit import is saved to Health History, optionally merge parsed data into Pet profile (user-approved only).

import Foundation
import SwiftData

struct VetVisitProfileUpdateProposal: Equatable {
    /// Lines for the alert body (specific items found).
    var detailLines: [String]
    /// Vaccine names to append as VaccineEntry (not already on profile).
    var vaccinesToAppend: [String]
    /// Medications to append as MedicationEntry.
    var medicationsToAppend: [ParsedMedication]
    /// Set pet.allergies only when empty.
    var allergiesText: String?
    /// Update weight from visit (kg).
    var weightKg: Double?
    /// Fill pet.vetName when empty.
    var vetName: String?
    /// Fill pet.vetPhone when empty (often unknown from PDF).
    var vetPhone: String?

    var hasWork: Bool {
        !vaccinesToAppend.isEmpty
            || !medicationsToAppend.isEmpty
            || allergiesText != nil
            || weightKg != nil
            || vetName != nil
            || vetPhone != nil
    }

    var detailMessage: String {
        detailLines.map { "• \($0)" }.joined(separator: "\n")
    }
}

enum VetVisitProfileUpdateSupport {
    /// Build merge proposal from parsed vet record + current pet. Never writes to the store.
    static func buildProposal(
        pet: Pet,
        parsed: VetRecordParseResult,
        form: PDFImportReviewFormState?,
        pendingVaccineNames: [String],
        pendingMedications: [ParsedMedication],
        importWeightKg: Double?
    ) -> VetVisitProfileUpdateProposal? {
        var lines: [String] = []
        var vaccinesToAppend: [String] = []
        var medsToAppend: [ParsedMedication] = []
        var allergiesText: String?
        var weightKg: Double?
        var vetName: String?
        var vetPhone: String?

        let existingVaxNames = Set(
            pet.vaccinesArray.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
        )

        let vaccineCandidates: [String] = {
            if !pendingVaccineNames.isEmpty { return pendingVaccineNames }
            return form?.vaccineNames() ?? parsed.vaccinesGiven
        }()

        for raw in vaccineCandidates {
            let n = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { continue }
            if existingVaxNames.contains(n.lowercased()) { continue }
            vaccinesToAppend.append(n)
            lines.append("Vaccine: \(n)")
        }

        let medCandidates: [ParsedMedication] = {
            if !pendingMedications.isEmpty { return pendingMedications }
            return form?.medicationsForSave() ?? parsed.medications.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }()

        let existingMedKeys = Set(pet.medicationsArray.map { medKey($0) })
        for m in medCandidates {
            let key = medKeyFromParsed(m)
            guard !existingMedKeys.contains(key) else { continue }
            medsToAppend.append(m)
            let dose = m.dosage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let freq = m.frequency?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            var parts = ["Medication: \(m.name.trimmingCharacters(in: .whitespacesAndNewlines))"]
            if !dose.isEmpty { parts.append(dose) }
            if !freq.isEmpty { parts.append(freq) }
            lines.append(parts.joined(separator: " · "))
        }

        let allergiesProfileEmpty = pet.allergies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if allergiesProfileEmpty {
            let diagText = form?.diagnosesText ?? parsed.diagnoses.joined(separator: ", ")
            if let extracted = extractAllergiesSummary(from: diagText) {
                allergiesText = extracted
                lines.append("Allergies noted: \(extracted)")
            }
        }

        let wKg: Double? = importWeightKg ?? form?.resolvedWeightKg() ?? parsed.weightKg
        if let kg = wKg, kg > 0 {
            let existingKg: Double? = {
                guard pet.weight > 0 else { return nil }
                let unit = WeightUnit(rawValue: pet.weightUnit.lowercased()) ?? .lbs
                return unit == .kg ? pet.weight : pet.weight / 2.2046226218
            }()
            let differs: Bool = {
                guard let ek = existingKg else { return true }
                return abs(ek - kg) > 0.05
            }()
            if differs {
                weightKg = kg
                let lbs = kg * 2.2046226218
                lines.append(String(format: "Weight: %.1f lbs", lbs))
            }
        }

        let vn = (form?.vetName ?? parsed.vetName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let clinic = (form?.clinicName ?? parsed.clinicName)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let vetDisplay = clinic.isEmpty ? vn : clinic

        if pet.vetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !vetDisplay.isEmpty {
            vetName = vetDisplay
            lines.append("Veterinarian / clinic: \(vetDisplay)")
        }

        if pet.vetPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Parser rarely has phone; placeholder for future extraction.
            vetPhone = nil
        }

        guard !lines.isEmpty else { return nil }

        return VetVisitProfileUpdateProposal(
            detailLines: lines,
            vaccinesToAppend: vaccinesToAppend,
            medicationsToAppend: medsToAppend,
            allergiesText: allergiesText,
            weightKg: weightKg,
            vetName: vetName,
            vetPhone: vetPhone
        )
    }

    static func apply(proposal: VetVisitProfileUpdateProposal, to pet: Pet, visitDate: Date, modelContext: ModelContext) {
        for name in proposal.vaccinesToAppend {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let entry = VaccineEntry(
                name: trimmed,
                dateAdministered: visitDate,
                dateExpires: nil,
                pet: pet
            )
            modelContext.insert(entry)
        }

        for m in proposal.medicationsToAppend {
            let n = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !n.isEmpty else { continue }
            let amount = m.dosage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let freq = m.frequency?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let entry = MedicationEntry(
                name: n,
                amount: amount,
                frequency: freq,
                pet: pet
            )
            modelContext.insert(entry)
        }

        if let a = proposal.allergiesText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !a.isEmpty,
           pet.allergies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pet.allergies = a
        }

        if let kg = proposal.weightKg, kg > 0 {
            let unit = WeightUnit(rawValue: pet.weightUnit.lowercased()) ?? .lbs
            pet.weight = unit == .kg ? kg : WeightUnit.lbs.value(fromKg: kg)
        }

        if let vn = proposal.vetName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !vn.isEmpty,
           pet.vetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pet.vetName = vn
        }

        if let vp = proposal.vetPhone?.trimmingCharacters(in: .whitespacesAndNewlines),
           !vp.isEmpty,
           pet.vetPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pet.vetPhone = vp
        }

        try? modelContext.save()
    }

    private static func medKey(_ m: MedicationEntry) -> String {
        let n = m.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let a = m.amount.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let f = m.frequency.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(n)|\(a)|\(f)"
    }

    private static func medKeyFromParsed(_ m: ParsedMedication) -> String {
        let n = m.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let a = m.dosage?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        let f = m.frequency?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return "\(n)|\(a)|\(f)"
    }

    private static func extractAllergiesSummary(from diagnosesText: String) -> String? {
        let parts = diagnosesText
            .split { $0 == "," || $0 == ";" || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let hits = parts.filter { $0.localizedCaseInsensitiveContains("allerg") }
        guard !hits.isEmpty else { return nil }
        return hits.joined(separator: "; ")
    }
}

// MARK: - Vaccine due reminders (PDF import / profile merge)

enum VetVisitVaccineDueReminderSupport {
    private static let suppressionKey = "vetVisitVaccineDueReminderPromptSuppressed"

    static var isPromptSuppressed: Bool {
        get { UserDefaults.standard.bool(forKey: suppressionKey) }
        set { UserDefaults.standard.set(newValue, forKey: suppressionKey) }
    }

    static func shouldOfferPrompt() -> Bool {
        !isPromptSuppressed
    }

    static func eligibleItems(from vaccines: [ParsedVaccineDue]) -> [ParsedVaccineDue] {
        vaccines.filter { v in
            let n = v.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return !n.isEmpty && v.dueDate != nil
        }
    }

    static func alertBody(for items: [ParsedVaccineDue]) -> String {
        let bullets = items.compactMap { v -> String? in
            guard let d = v.dueDate else { return nil }
            let name = v.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            return "• \(name) — due \(formatDueHeading(d))"
        }
        let list = bullets.joined(separator: "\n")
        return "We found the following vaccines with due dates:\n\n\(list)\n\nWould you like to create reminders for these?"
    }

    private static func formatDueHeading(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "MMM d yyyy"
        return df.string(from: date)
    }

    @MainActor
    static func createReminders(
        for items: [ParsedVaccineDue],
        petId: UUID,
        petDisplayName: String,
        modelContext: ModelContext
    ) {
        let trimmed = petDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPet = trimmed.isEmpty ? "your pet" : trimmed
        let cal = Calendar.current
        let note = "Time to schedule a vet appointment."

        for v in items {
            guard let dueRaw = v.dueDate else { continue }
            let vaccineName = v.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !vaccineName.isEmpty else { continue }

            let dueDayStart = cal.startOfDay(for: dueRaw)
            guard let dueAtNine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: dueDayStart) else { continue }

            if let soonDay = cal.date(byAdding: .day, value: -14, to: dueDayStart),
               let soonAtNine = cal.date(bySettingHour: 9, minute: 0, second: 0, of: soonDay),
               soonAtNine > Date() {
                let soon = PetReminder(
                    petId: petId,
                    title: "\(vaccineName) due soon for \(displayPet)",
                    notes: note,
                    category: "Vaccine",
                    nextDueDate: soonAtNine,
                    recurring: false,
                    recurrenceInterval: 1,
                    recurrenceUnit: "month"
                )
                modelContext.insert(soon)
            }

            if dueAtNine > Date() {
                let today = PetReminder(
                    petId: petId,
                    title: "\(vaccineName) due today for \(displayPet)",
                    notes: note,
                    category: "Vaccine",
                    nextDueDate: dueAtNine,
                    recurring: false,
                    recurrenceInterval: 1,
                    recurrenceUnit: "month"
                )
                modelContext.insert(today)
            }
        }

        try? modelContext.save()
        #if os(iOS)
        PetReminderNotificationService.scheduleAfterReminderChange(modelContext: modelContext)
        #endif
    }
}

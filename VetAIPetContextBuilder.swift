// VetAIPetContextBuilder.swift
// Builds a text summary of Petpal SwiftData + profile fields for AI Vet system prompts.

import Foundation

enum VetAIPetContextBuilder {

    private static let maxTotalCharacters = 10_000
    private static let maxFieldCharacters = 900

    static func buildContext(
        profileName: String,
        profileSpecies: String,
        profileBreed: String,
        profileWeight: Double,
        weightUnit: String,
        pets: [Pet],
        visits: [VetVisitLog],
        policies: [PetInsuranceInfo],
        reminders: [PetReminder],
        emergencyProfiles: [EmergencyProfile],
        petSitterInstructions: [PetSitterInstructions],
        attachments: [PetRecordAttachment]
    ) -> String {
        var sections: [String] = []

        sections.append("=== Profile (home screen) ===")
        sections.append("Name: \(profileName)")
        sections.append("Species: \(profileSpecies)")
        if !profileBreed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("Breed: \(profileBreed)")
        }
        if profileWeight > 0 {
            sections.append("Weight: \(profileWeight) \(weightUnit)")
        }

        if !pets.isEmpty {
            sections.append("")
            sections.append("=== Pets in app (SwiftData) ===")
            for p in pets.prefix(8) {
                var line = "• \(p.name) — \(p.species)"
                if !p.breed.isEmpty { line += ", \(p.breed)" }
                if p.weight > 0 { line += ", \(p.weight) \(p.weightUnit)" }
                if p.isActive { line += " [active]" }
                if let dob = p.dateOfBirth {
                    line += ", DOB \(dob.formatted(date: .abbreviated, time: .omitted))"
                }
                sections.append(line)
            }
            if pets.count > 8 {
                sections.append("… and \(pets.count - 8) more pet(s)")
            }
        }

        if !visits.isEmpty {
            sections.append("")
            sections.append("=== Health history / vet visits ===")
            for v in visits.prefix(25) {
                let att = attachmentLine(parentId: v.id, kind: .vetVisit, attachments: attachments)
                let clinic = v.clinicName.isEmpty ? "Visit" : v.clinicName
                var block = "• \(clinic) — \(v.visitDate.formatted(date: .abbreviated, time: .omitted))\(att)"
                if !v.reason.isEmpty { block += "\n  Reason: \(clip(v.reason))" }
                if !v.notes.isEmpty { block += "\n  Notes: \(clip(v.notes))" }
                sections.append(block)
            }
            if visits.count > 25 {
                sections.append("… \(visits.count - 25) more visit(s) not listed")
            }
        }

        if !policies.isEmpty {
            sections.append("")
            sections.append("=== Pet insurance ===")
            for p in policies.prefix(10) {
                let att = attachmentLine(parentId: p.id, kind: .insurance, attachments: attachments)
                var block = "• Provider: \(p.providerName.isEmpty ? "(unnamed)" : p.providerName)\(att)"
                if !p.policyNumber.isEmpty { block += "\n  Policy #: \(p.policyNumber)" }
                if !p.phone.isEmpty { block += "\n  Phone: \(p.phone)" }
                if let r = p.renewalDate {
                    block += "\n  Renewal: \(r.formatted(date: .abbreviated, time: .omitted))"
                }
                if !p.notes.isEmpty { block += "\n  Notes: \(clip(p.notes))" }
                sections.append(block)
            }
        }

        if !reminders.isEmpty {
            sections.append("")
            sections.append("=== Reminders (upcoming / care tasks) ===")
            let sorted = reminders.sorted { $0.nextDueDate < $1.nextDueDate }
            for r in sorted.prefix(20) {
                let status = r.isCompleted ? "done" : (r.isOverdue ? "overdue" : "pending")
                var line = "• \(r.title.isEmpty ? "Reminder" : r.title) [\(r.category)] — next \(r.nextDueDate.formatted(date: .abbreviated, time: .shortened)) (\(status))"
                if !r.notes.isEmpty { line += "\n  Notes: \(clip(r.notes))" }
                sections.append(line)
            }
        }

        if let ep = emergencyProfiles.first(where: { $0.isActive }) ?? emergencyProfiles.first {
            sections.append("")
            sections.append("=== Emergency profile ===")
            if !ep.petName.isEmpty { sections.append("Pet: \(ep.petName)") }
            appendNonEmpty(&sections, "Medications", ep.medications)
            appendNonEmpty(&sections, "Allergies", ep.allergies)
            appendNonEmpty(&sections, "Medical conditions", ep.medicalConditions)
            appendNonEmpty(&sections, "Microchip", ep.microchipNumber)
            appendNonEmpty(&sections, "Vet", ep.vetName)
            appendNonEmpty(&sections, "Vet phone", ep.vetPhone)
            appendNonEmpty(&sections, "Feeding", ep.feedingInstructions)
            appendNonEmpty(&sections, "Special needs", ep.specialNeeds)
        }

        if let sitter = petSitterInstructions.first {
            let hasSitterContent =
                !sitter.favoriteFood.isEmpty || !sitter.foodSchedule.isEmpty
                || !(sitter.foodAddons ?? "").isEmpty || !sitter.specialInstructions.isEmpty
                || !(sitter.medications ?? "").isEmpty || !(sitter.vetPhone ?? "").isEmpty
            if hasSitterContent {
                sections.append("")
                sections.append("=== Pet care notes (sitter / routine) ===")
                appendNonEmpty(&sections, "Favorite food", sitter.favoriteFood)
                appendNonEmpty(&sections, "Food amount", sitter.foodAmount)
                appendNonEmpty(&sections, "Food schedule", sitter.foodSchedule)
                appendNonEmpty(&sections, "Food add-ons", sitter.foodAddons ?? "")
                appendNonEmpty(&sections, "Treats", sitter.favoriteTreats)
                appendNonEmpty(&sections, "Walk schedule", sitter.walkSchedule ?? "")
                appendNonEmpty(&sections, "Medications (notes)", sitter.medications ?? "")
                appendNonEmpty(&sections, "Vet phone (notes)", sitter.vetPhone ?? "")
                appendNonEmpty(&sections, "Special instructions", sitter.specialInstructions)
            }
        }

        var text = sections.joined(separator: "\n")
        if text.count > maxTotalCharacters {
            let end = text.index(text.startIndex, offsetBy: maxTotalCharacters - 80)
            text = String(text[..<end]) + "\n\n…[Petpal records truncated for length]"
        }
        return text
    }

    private static func clip(_ s: String) -> String {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= maxFieldCharacters { return t }
        let end = t.index(t.startIndex, offsetBy: maxFieldCharacters - 1)
        return String(t[..<end]) + "…"
    }

    private static func appendNonEmpty(_ sections: inout [String], _ label: String, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !v.isEmpty else { return }
        sections.append("\(label): \(clip(v))")
    }

    private static func attachmentLine(
        parentId: UUID,
        kind: PetRecordAttachmentParentKind,
        attachments: [PetRecordAttachment]
    ) -> String {
        let subset = attachments.filter { $0.parentRecordId == parentId && $0.parentKind == kind.rawValue }
        guard !subset.isEmpty else { return "" }
        let images = subset.filter { $0.contentKind == "image" }.count
        let pdfs = subset.filter { $0.contentKind == "pdf" }.count
        var parts: [String] = []
        if images > 0 { parts.append("\(images) photo(s)") }
        if pdfs > 0 { parts.append("\(pdfs) PDF(s)") }
        return " [files on record: \(parts.joined(separator: ", ")) — contents not readable by AI]"
    }
}

// PetSitterProfileAutofill.swift
// One-time pre-fill of empty Pet Sitter / Pet Care Info fields from Pet profile + Care Card vaccine visibility.

import Foundation
import SwiftData

enum PetSitterProfileAutofill {
    /// Returns `true` if any field was changed.
    @discardableResult
    static func fillEmptyFields(
        instructions: PetSitterInstructions,
        pet: Pet,
        careCard: CareCardFieldSettings,
        modelContext: ModelContext
    ) -> Bool {
        var changed = false
        let pid = pet.id
        let today = Calendar.current.startOfDay(for: Date())

        func isEmpty(_ s: String?) -> Bool {
            (s ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if instructions.favoriteFood.isEmpty {
            // No dedicated "pet name" field — name appears in document title; skip.
        }

        if isEmpty(instructions.vetName), !pet.vetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            instructions.vetName = pet.vetName
            changed = true
        }
        if isEmpty(instructions.vetPhone), !pet.vetPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            instructions.vetPhone = pet.vetPhone
            changed = true
        }
        if isEmpty(instructions.vetAddress) {
            let email = pet.vetEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            if !email.isEmpty {
                instructions.vetAddress = "Email: \(email)"
                changed = true
            }
        }

        if isEmpty(instructions.allergies), !pet.allergies.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            instructions.allergies = pet.allergies
            changed = true
        }

        let medLines = pet.medicationsArray.map { m -> String in
            let n = m.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let a = m.amount.trimmingCharacters(in: .whitespacesAndNewlines)
            let f = m.frequency.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = n.isEmpty ? "Medication" : n
            if a.isEmpty && f.isEmpty { return name }
            if f.isEmpty { return "\(name) — \(a)" }
            if a.isEmpty { return "\(name) — \(f)" }
            return "\(name) — \(a) · \(f)"
        }

        var vaccineLines: [String] = []
        if careCard.showVaccines {
            for v in pet.vaccinesArray.sorted(by: { $0.dateAdministered > $1.dateAdministered }) {
                if let exp = v.dateExpires, exp < today { continue }
                let n = v.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !n.isEmpty else { continue }
                let admin = v.dateAdministered.formatted(date: .abbreviated, time: .omitted)
                if let exp = v.dateExpires {
                    vaccineLines.append("\(n) (given \(admin), exp \(exp.formatted(date: .abbreviated, time: .omitted)))")
                } else {
                    vaccineLines.append("\(n) (given \(admin))")
                }
            }

            let certDesc = FetchDescriptor<PetCertificate>(
                predicate: #Predicate<PetCertificate> { c in
                    c.petId == pid && c.category == "Vaccine"
                }
            )
            if let certs = try? modelContext.fetch(certDesc) {
                for c in certs.sorted(by: { $0.updatedAt > $1.updatedAt }) {
                    if let exp = c.expirationDate, exp < today { continue }
                    let t = c.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { continue }
                    if let exp = c.expirationDate {
                        vaccineLines.append("\(t) (certificate, exp \(exp.formatted(date: .abbreviated, time: .omitted)))")
                    } else {
                        vaccineLines.append("\(t) (certificate)")
                    }
                }
            }
        }

        let vaccineBlock: String? = vaccineLines.isEmpty ? nil : ("Vaccines (from Care Card): " + vaccineLines.joined(separator: "; "))

        if isEmpty(instructions.medications) {
            var combined: [String] = []
            if !medLines.isEmpty {
                combined.append(medLines.joined(separator: "\n"))
            }
            if let vb = vaccineBlock {
                combined.append(vb)
            }
            if !combined.isEmpty {
                instructions.medications = combined.joined(separator: "\n\n")
                changed = true
            }
        } else if let vb = vaccineBlock, let existing = instructions.medications, !existing.localizedCaseInsensitiveContains("Vaccines (from Care Card)") {
            instructions.medications = existing + "\n\n" + vb
            changed = true
        }

        if instructions.specialInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var profileBits: [String] = []
            let petDisplay = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !petDisplay.isEmpty { profileBits.append("Pet: \(petDisplay)") }
            let breed = pet.breed.trimmingCharacters(in: .whitespacesAndNewlines)
            if !breed.isEmpty { profileBits.append("Breed: \(breed)") }
            if let dob = pet.dateOfBirth {
                profileBits.append("Birthday: \(dob.formatted(date: .long, time: .omitted)) (\(Self.ageDescription(from: dob)))")
            }
            if pet.weight > 0 {
                profileBits.append(String(format: "Weight: %.1f %@", pet.weight, pet.weightUnit))
            }
            let en = pet.emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)
            let ep = pet.emergencyContactNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            if !en.isEmpty || !ep.isEmpty {
                profileBits.append("Emergency contact: \(Self.joinNamePhone(en, ep))")
            }
            let reg = pet.microchipRegistry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reg.isEmpty {
                profileBits.append("Microchip registry: \(reg)")
            }
            if !profileBits.isEmpty {
                instructions.specialInstructions = "From Pet Profile — " + profileBits.joined(separator: " · ")
                changed = true
            }
        }

        if changed {
            instructions.updatedAt = Date()
            try? modelContext.save()
        }

        return changed
    }

    private static func ageDescription(from birth: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: birth, to: Date())
        let y = c.year ?? 0
        let m = c.month ?? 0
        if y > 0 { return "\(y) yr\(y == 1 ? "" : "s") old" }
        if m > 0 { return "\(m) mo old" }
        return "less than 1 mo old"
    }

    private static func joinNamePhone(_ name: String, _ phone: String) -> String {
        switch (name.isEmpty, phone.isEmpty) {
        case (true, true): return ""
        case (false, true): return name
        case (true, false): return phone
        default: return "\(name) · \(phone)"
        }
    }
}

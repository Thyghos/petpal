// LegacyPetBootstrap.swift
// Recovers a SwiftData Pet from UserDefaults when the store has care data but no pet rows
// (e.g. after schema/UI changes), so testers don’t see an “empty” app while data still exists.

import Foundation
import SwiftData

enum LegacyPetBootstrap {
    private static let completionKey = "PetpalLegacyPetBootstrapCompleted"

    @MainActor
    static func runIfNeeded(modelContext: ModelContext) {
        do {
            let petCount = try modelContext.fetchCount(FetchDescriptor<Pet>())
            if petCount > 0 {
                UserDefaults.standard.set(true, forKey: completionKey)
                return
            }

            // Store shows no pets. Still recover if anything hints data survived in UserDefaults or in other
            // SwiftData tables (e.g. after an upgrade opened the wrong store file once). Do not skip solely
            // because a previous run set `completionKey` — that can strand users after a bad migration.
            let wasMarkedDone = UserDefaults.standard.bool(forKey: completionKey)
            let recoveryWarranted = shouldCreateRecoveryPet(modelContext: modelContext)
            if wasMarkedDone && !recoveryWarranted {
                return
            }

            guard recoveryWarranted else {
                UserDefaults.standard.set(true, forKey: completionKey)
                return
            }

            let defaults = UserDefaults.standard
            let storedName = defaults.string(forKey: "petName")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let name: String
            if !storedName.isEmpty, storedName != "Your Pet" {
                name = storedName
            } else {
                name = "My Pet"
            }
            let speciesRaw = defaults.string(forKey: "petSpecies") ?? ""
            let species = speciesRaw.isEmpty ? "Dog" : speciesRaw
            let breed = defaults.string(forKey: "petBreed") ?? ""
            let weight = defaults.double(forKey: "petWeight")
            let weightUnit = defaults.string(forKey: "weightUnit") ?? "lbs"
            let avatar = defaults.data(forKey: "petAvatarData")

            let pet = Pet(
                name: name,
                species: species,
                breed: breed,
                weight: weight,
                weightUnit: weightUnit,
                profileImage: avatar,
                isActive: true
            )
            modelContext.insert(pet)
            try modelContext.save()
            try attachLegacyRecordsWithoutPetId(to: pet.id, modelContext: modelContext)
            try modelContext.save()
            pet.syncToLegacyAppStorage()
            UserDefaults.standard.set(true, forKey: completionKey)
        } catch {
            // Leave completionKey unset so the next launch retries (transient DB errors).
        }
    }

    /// Binds rows that pre-date per-pet ids to the recovered profile so nothing appears “unowned.”
    private static func attachLegacyRecordsWithoutPetId(to petId: UUID, modelContext: ModelContext) throws {
        for r in try modelContext.fetch(FetchDescriptor<PetReminder>()) where r.petId == nil {
            r.petId = petId
        }
        for v in try modelContext.fetch(FetchDescriptor<VetVisitLog>()) where v.petId == nil {
            v.petId = petId
        }
        for p in try modelContext.fetch(FetchDescriptor<PetInsuranceInfo>()) where p.petId == nil {
            p.petId = petId
        }
        for s in try modelContext.fetch(FetchDescriptor<PetSitterInstructions>()) where s.petId == nil {
            s.petId = petId
        }
        for e in try modelContext.fetch(FetchDescriptor<EmergencyProfile>()) where e.linkedPetId == nil {
            e.linkedPetId = petId
        }
    }

    private static func shouldCreateRecoveryPet(modelContext: ModelContext) -> Bool {
        if hasPersistedCareData(modelContext: modelContext) { return true }
        return hasStrongUserDefaultsProfile()
    }

    private static func hasPersistedCareData(modelContext: ModelContext) -> Bool {
        do {
            if try modelContext.fetchCount(FetchDescriptor<PetReminder>()) > 0 { return true }
            if try modelContext.fetchCount(FetchDescriptor<VetVisitLog>()) > 0 { return true }
            if try modelContext.fetchCount(FetchDescriptor<PetInsuranceInfo>()) > 0 { return true }
            if try modelContext.fetchCount(FetchDescriptor<PetSitterInstructions>()) > 0 { return true }
            if try modelContext.fetchCount(FetchDescriptor<EmergencyProfile>()) > 0 { return true }
            if try modelContext.fetchCount(FetchDescriptor<StoredVetDocument>()) > 0 { return true }
            if try modelContext.fetchCount(FetchDescriptor<PetRecordAttachment>()) > 0 { return true }
        } catch {
            return false
        }
        return false
    }

    private static func hasStrongUserDefaultsProfile() -> Bool {
        let d = UserDefaults.standard
        if d.data(forKey: "petAvatarData") != nil { return true }
        if d.double(forKey: "petWeight") > 0 { return true }
        let breed = d.string(forKey: "petBreed") ?? ""
        if !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        let name = d.string(forKey: "petName") ?? ""
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != "Your Pet" { return true }
        return false
    }
}

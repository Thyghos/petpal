// Models.swift
// Petpal - SwiftData Models

import Foundation
import SwiftData

@Model
final class Pet {
    var id: UUID = UUID()
    var name: String = "My Pet"
    var species: String = "Dog"
    var breed: String = ""
    var weight: Double = 0.0
    var weightUnit: String = "lbs"
    @Attribute(.externalStorage) var profileImage: Data?
    var dateAdded: Date = Date()
    var dateOfBirth: Date?
    var isActive: Bool = false
    /// Primary care vet for this pet (profile; Emergency QR has its own fields).
    var vetName: String = ""
    var vetPhone: String = ""
    var vetEmail: String = ""
    var groomerName: String = ""
    var groomerPhone: String = ""
    /// Microchip ID / number (profile; Emergency QR can still hold a separate copy).
    var microchipNumber: String = ""
    /// Registry or provider name (e.g. HomeAgain, AKC Reunite).
    var microchipRegistry: String = ""
    
    init(
        id: UUID = UUID(),
        name: String = "My Pet",
        species: String = "Dog",
        breed: String = "",
        weight: Double = 0.0,
        weightUnit: String = "lbs",
        profileImage: Data? = nil,
        dateAdded: Date = Date(),
        dateOfBirth: Date? = nil,
        isActive: Bool = false,
        vetName: String = "",
        vetPhone: String = "",
        vetEmail: String = "",
        groomerName: String = "",
        groomerPhone: String = "",
        microchipNumber: String = "",
        microchipRegistry: String = ""
    ) {
        self.id = id
        self.name = name
        self.species = species
        self.breed = breed
        self.weight = weight
        self.weightUnit = weightUnit
        self.profileImage = profileImage
        self.dateAdded = dateAdded
        self.dateOfBirth = dateOfBirth
        self.isActive = isActive
        self.vetName = vetName
        self.vetPhone = vetPhone
        self.vetEmail = vetEmail
        self.groomerName = groomerName
        self.groomerPhone = groomerPhone
        self.microchipNumber = microchipNumber
        self.microchipRegistry = microchipRegistry
    }
}

/// Legacy rows with `nil` `petId` match every pet until reassigned.
enum PetRecordFilter {
    /// True only when the record is explicitly tagged for `selectedPetId`. Legacy `nil` petId does **not** match (avoids showing one pet’s reminders under another).
    static func matches(_ recordPetId: UUID?, selectedPetId: UUID?) -> Bool {
        guard let selected = selectedPetId else { return false }
        guard let rid = recordPetId else { return false }
        return rid == selected
    }
}

enum ActivePetStorage {
    static var activePetUUID: UUID? {
        guard let s = UserDefaults.standard.string(forKey: "activePetId"), !s.isEmpty else { return nil }
        return UUID(uuidString: s)
    }
}

/// Resolves which pet is “active” for badges and notifications (same rules as `FeaturePetScope`, without SwiftUI).
enum ActivePetResolver {
    static func resolvedPetId(pets: [Pet]) -> UUID? {
        if let id = ActivePetStorage.activePetUUID, pets.contains(where: { $0.id == id }) {
            return id
        }
        if let active = pets.first(where: { $0.isActive }) {
            return active.id
        }
        if pets.count == 1 {
            return pets.first?.id
        }
        return nil
    }
}

extension Pet {
    /// Keeps @AppStorage-backed UI (home hero, Vet AI, etc.) aligned with this pet when it is active.
    func syncToLegacyAppStorage() {
        UserDefaults.standard.set(name, forKey: "petName")
        UserDefaults.standard.set(species, forKey: "petSpecies")
        UserDefaults.standard.set(breed, forKey: "petBreed")
        UserDefaults.standard.set(weight, forKey: "petWeight")
        UserDefaults.standard.set(weightUnit, forKey: "weightUnit")
        if let img = profileImage {
            UserDefaults.standard.set(img, forKey: "petAvatarData")
        } else {
            UserDefaults.standard.removeObject(forKey: "petAvatarData")
        }
        UserDefaults.standard.set(id.uuidString, forKey: "activePetId")
    }
}

@Model
final class PetReminder {
    var id: UUID = UUID()
    /// When `nil`, the reminder is treated as global (legacy data).
    var petId: UUID?
    var title: String = ""
    var notes: String = ""
    var category: String = "General"
    var nextDueDate: Date = Date()
    var recurring: Bool = false
    var recurrenceInterval: Int = 1
    var recurrenceUnit: String = "month"
    var isCompleted: Bool = false
    var completedDate: Date?
    var createdDate: Date = Date()
    
    var isOverdue: Bool {
        !isCompleted && nextDueDate < Date()
    }

    /// Due time has arrived or passed (including “right now”) and not completed — aligns with when a local notification fires; clears when rescheduled or marked done.
    var needsAttention: Bool {
        !isCompleted && nextDueDate <= Date()
    }
    
    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        title: String = "",
        notes: String = "",
        category: String = "General",
        nextDueDate: Date = Date(),
        recurring: Bool = false,
        recurrenceInterval: Int = 1,
        recurrenceUnit: String = "month",
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.title = title
        self.notes = notes
        self.category = category
        self.nextDueDate = nextDueDate
        self.recurring = recurring
        self.recurrenceInterval = recurrenceInterval
        self.recurrenceUnit = recurrenceUnit
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.createdDate = createdDate
    }
}

@Model
final class EmergencyProfile {
    var id: UUID = UUID()
    /// When `nil`, profile is treated as global (legacy); otherwise scoped to one pet.
    var linkedPetId: UUID?
    var petName: String = ""
    var ownerName: String = ""
    var ownerPhone: String = ""
    var ownerEmail: String = ""
    var alternateContact: String = ""
    var medications: String = ""
    var allergies: String = ""
    var medicalConditions: String = ""
    var microchipNumber: String = ""
    var vetName: String = ""
    var vetPhone: String = ""
    var vetAddress: String = ""
    var feedingInstructions: String = ""
    var specialNeeds: String = ""
    var lostPetMessage: String = "I'm lost! Please call my owner ASAP!"
    var rewardOffered: String = ""
    var isActive: Bool = true
    var lastUpdated: Date = Date()
    
    /// Base URL for emergency page. Use your GitHub Pages URL, e.g. https://USERNAME.github.io/petpal-emergency/
    private static let emergencyPageBaseURL = "https://thyghos.github.io/petpal-emergency/"

    /// URL with profile data encoded for static hosting (GitHub Pages). No backend required.
    var emergencyURL: String {
        let payload: [String: String] = [
            "petName": petName,
            "ownerName": ownerName,
            "ownerPhone": ownerPhone,
            "ownerEmail": ownerEmail,
            "alternateContact": alternateContact,
            "medications": medications,
            "allergies": allergies,
            "medicalConditions": medicalConditions,
            "microchipNumber": microchipNumber,
            "vetName": vetName,
            "vetPhone": vetPhone,
            "vetAddress": vetAddress,
            "feedingInstructions": feedingInstructions,
            "specialNeeds": specialNeeds,
            "lostPetMessage": lostPetMessage,
            "rewardOffered": rewardOffered
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: payload) else {
            return Self.emergencyPageBaseURL
        }
        let base64 = json.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return Self.emergencyPageBaseURL + "#" + base64
    }
    
    init(
        id: UUID = UUID(),
        linkedPetId: UUID? = nil,
        petName: String = "",
        ownerName: String = "",
        ownerPhone: String = "",
        ownerEmail: String = "",
        alternateContact: String = "",
        medications: String = "",
        allergies: String = "",
        medicalConditions: String = "",
        microchipNumber: String = "",
        vetName: String = "",
        vetPhone: String = "",
        vetAddress: String = "",
        feedingInstructions: String = "",
        specialNeeds: String = "",
        lostPetMessage: String = "I'm lost! Please call my owner ASAP!",
        rewardOffered: String = "",
        isActive: Bool = true,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.linkedPetId = linkedPetId
        self.petName = petName
        self.ownerName = ownerName
        self.ownerPhone = ownerPhone
        self.ownerEmail = ownerEmail
        self.alternateContact = alternateContact
        self.medications = medications
        self.allergies = allergies
        self.medicalConditions = medicalConditions
        self.microchipNumber = microchipNumber
        self.vetName = vetName
        self.vetPhone = vetPhone
        self.vetAddress = vetAddress
        self.feedingInstructions = feedingInstructions
        self.specialNeeds = specialNeeds
        self.lostPetMessage = lostPetMessage
        self.rewardOffered = rewardOffered
        self.isActive = isActive
        self.lastUpdated = lastUpdated
    }
}

@Model
final class StoredVetDocument {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var documentKind: String = "General"
    var recordDate: Date = Date()
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        title: String = "",
        notes: String = "",
        documentKind: String = "General",
        recordDate: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.documentKind = documentKind
        self.recordDate = recordDate
        self.createdAt = createdAt
    }
}

@Model
final class VetVisitLog {
    var id: UUID = UUID()
    var petId: UUID?
    var visitDate: Date = Date()
    var clinicName: String = ""
    var reason: String = ""
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        visitDate: Date = Date(),
        clinicName: String = "",
        reason: String = "",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.visitDate = visitDate
        self.clinicName = clinicName
        self.reason = reason
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class PetInsuranceInfo {
    var id: UUID = UUID()
    var petId: UUID?
    var providerName: String = ""
    var policyNumber: String = ""
    var phone: String = ""
    var notes: String = ""
    var renewalDate: Date?
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        providerName: String = "",
        policyNumber: String = "",
        phone: String = "",
        notes: String = "",
        renewalDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.providerName = providerName
        self.policyNumber = policyNumber
        self.phone = phone
        self.notes = notes
        self.renewalDate = renewalDate
        self.createdAt = createdAt
    }
}

@Model
final class PetSitterInstructions {
    var id: UUID = UUID()
    var petId: UUID?
    var favoriteFood: String = ""
    var foodAmount: String = ""
    var foodAddons: String?
    var foodSchedule: String = ""
    var favoriteTreats: String = ""
    var treatAmount: String = ""
    var treatSchedule: String = ""
    var walkSchedule: String?
    var walkDuration: String?
    var allergies: String?
    var medications: String?
    var vetName: String?
    var vetPhone: String?
    var vetAddress: String?
    var specialInstructions: String = ""
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        favoriteFood: String = "",
        foodAmount: String = "",
        foodAddons: String? = nil,
        foodSchedule: String = "",
        favoriteTreats: String = "",
        treatAmount: String = "",
        treatSchedule: String = "",
        walkSchedule: String? = nil,
        walkDuration: String? = nil,
        allergies: String? = nil,
        medications: String? = nil,
        vetName: String? = nil,
        vetPhone: String? = nil,
        vetAddress: String? = nil,
        specialInstructions: String = "",
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.favoriteFood = favoriteFood
        self.foodAmount = foodAmount
        self.foodAddons = foodAddons
        self.foodSchedule = foodSchedule
        self.favoriteTreats = favoriteTreats
        self.treatAmount = treatAmount
        self.treatSchedule = treatSchedule
        self.walkSchedule = walkSchedule
        self.walkDuration = walkDuration
        self.allergies = allergies
        self.medications = medications
        self.vetName = vetName
        self.vetPhone = vetPhone
        self.vetAddress = vetAddress
        self.specialInstructions = specialInstructions
        self.updatedAt = updatedAt
    }
}

/// Parent type for `PetRecordAttachment` (stored as `parentKind` string for SwiftData).
enum PetRecordAttachmentParentKind: String, CaseIterable {
    case vetDocument
    case vetVisit
    case insurance
    case reminder
    case certificate
}

@Model
final class PetCertificate {
    var id: UUID = UUID()
    var petId: UUID?
    var title: String = ""
    var notes: String = ""
    var category: String = "Other"
    var expirationDate: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        title: String = "",
        notes: String = "",
        category: String = "Other",
        expirationDate: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.title = title
        self.notes = notes
        self.category = category
        self.expirationDate = expirationDate
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PetRecordAttachment: Identifiable {
    var id: UUID = UUID()
    var parentRecordId: UUID = UUID()
    var parentKind: String = ""
    @Attribute(.externalStorage) var fileData: Data = Data()
    /// `"image"` (JPEG/PNG bitmap) or `"pdf"`
    var contentKind: String = "image"
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        parentRecordId: UUID,
        parentKind: PetRecordAttachmentParentKind,
        fileData: Data,
        contentKind: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.parentRecordId = parentRecordId
        self.parentKind = parentKind.rawValue
        self.fileData = fileData
        self.contentKind = contentKind
        self.createdAt = createdAt
    }
}

@Model
final class PetWeightEntry: Identifiable {
    var id: UUID = UUID()
    var petId: UUID?
    var entryDate: Date = Date()
    /// Stored as kilograms (canonical). UI can display kg or lbs.
    var weightKg: Double = 0.0
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        entryDate: Date = Date(),
        weightKg: Double = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.entryDate = entryDate
        self.weightKg = weightKg
        self.createdAt = createdAt
    }
}

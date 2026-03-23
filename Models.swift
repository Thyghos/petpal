// Models.swift
// Petpal - SwiftData Models

import Foundation
import SwiftData

@Model
final class Pet {
    var id: UUID
    var name: String
    var species: String
    var breed: String
    var weight: Double
    var weightUnit: String
    var profileImage: Data?
    var dateAdded: Date
    var dateOfBirth: Date?
    var isActive: Bool
    
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
        isActive: Bool = false
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
    }
}

/// Legacy rows with `nil` `petId` match every pet until reassigned.
enum PetRecordFilter {
    static func matches(_ recordPetId: UUID?, selectedPetId: UUID?) -> Bool {
        guard let selected = selectedPetId else { return true }
        guard let rid = recordPetId else { return true }
        return rid == selected
    }
}

enum ActivePetStorage {
    static var activePetUUID: UUID? {
        guard let s = UserDefaults.standard.string(forKey: "activePetId"), !s.isEmpty else { return nil }
        return UUID(uuidString: s)
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
    var id: UUID
    /// When `nil`, the reminder is treated as global (legacy data).
    var petId: UUID?
    var title: String
    var notes: String
    var category: String
    var nextDueDate: Date
    var recurring: Bool
    var recurrenceInterval: Int
    var recurrenceUnit: String
    var isCompleted: Bool
    var completedDate: Date?
    var createdDate: Date
    
    var isOverdue: Bool {
        !isCompleted && nextDueDate < Date()
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
    var id: UUID
    /// When `nil`, profile is treated as global (legacy); otherwise scoped to one pet.
    var linkedPetId: UUID?
    var petName: String
    var ownerName: String
    var ownerPhone: String
    var ownerEmail: String
    var alternateContact: String
    var medications: String
    var allergies: String
    var medicalConditions: String
    var microchipNumber: String
    var vetName: String
    var vetPhone: String
    var vetAddress: String
    var feedingInstructions: String
    var specialNeeds: String
    var lostPetMessage: String
    var rewardOffered: String
    var isActive: Bool
    var lastUpdated: Date
    
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
    var id: UUID
    var title: String
    var notes: String
    var documentKind: String
    var recordDate: Date
    var createdAt: Date

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
    var id: UUID
    var petId: UUID?
    var visitDate: Date
    var clinicName: String
    var reason: String
    var notes: String
    var createdAt: Date

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
    var id: UUID
    var petId: UUID?
    var providerName: String
    var policyNumber: String
    var phone: String
    var notes: String
    var renewalDate: Date?
    var createdAt: Date

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
    var id: UUID
    var petId: UUID?
    var favoriteFood: String
    var foodAmount: String
    var foodAddons: String?
    var foodSchedule: String
    var favoriteTreats: String
    var treatAmount: String
    var treatSchedule: String
    var walkSchedule: String?
    var walkDuration: String?
    var medications: String?
    var vetPhone: String?
    var specialInstructions: String
    var updatedAt: Date

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
        medications: String? = nil,
        vetPhone: String? = nil,
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
        self.medications = medications
        self.vetPhone = vetPhone
        self.specialInstructions = specialInstructions
        self.updatedAt = updatedAt
    }
}

/// Parent type for `PetRecordAttachment` (stored as `parentKind` string for SwiftData).
enum PetRecordAttachmentParentKind: String, CaseIterable {
    case vetDocument
    case vetVisit
    case insurance
}

@Model
final class PetRecordAttachment: Identifiable {
    var id: UUID
    var parentRecordId: UUID
    var parentKind: String
    var fileData: Data
    /// `"image"` (JPEG/PNG bitmap) or `"pdf"`
    var contentKind: String
    var createdAt: Date

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

// Models.swift
// Petpal - SwiftData Models

import Foundation
import SwiftData

// MARK: - Profile care entries (Edit Pet → Care Card)
// SwiftData `@Model` classes conform to `Identifiable` via `PersistentModel` (stable `persistentModelID`).

@Model
final class VaccineEntry {
    var id: UUID = UUID()
    var name: String = ""
    var dateAdministered: Date = Date()
    var dateExpires: Date?
    var pet: Pet?

    init(
        id: UUID = UUID(),
        name: String = "",
        dateAdministered: Date = Date(),
        dateExpires: Date? = nil,
        pet: Pet? = nil
    ) {
        self.id = id
        self.name = name
        self.dateAdministered = dateAdministered
        self.dateExpires = dateExpires
        self.pet = pet
    }
}

@Model
final class MedicationEntry {
    var id: UUID = UUID()
    var name: String = ""
    var amount: String = ""
    var frequency: String = ""
    var pet: Pet?

    init(
        id: UUID = UUID(),
        name: String = "",
        amount: String = "",
        frequency: String = "",
        pet: Pet? = nil
    ) {
        self.id = id
        self.name = name
        self.amount = amount
        self.frequency = frequency
        self.pet = pet
    }
}

@Model
final class PetAttachment {
    var id: UUID = UUID()
    var name: String = ""
    @Attribute(.externalStorage) var data: Data = Data()
    var fileType: String = ""
    var dateAdded: Date = Date()
    var pet: Pet?

    init(
        id: UUID = UUID(),
        name: String = "",
        data: Data = Data(),
        fileType: String = "",
        dateAdded: Date = Date(),
        pet: Pet? = nil
    ) {
        self.id = id
        self.name = name
        self.data = data
        self.fileType = fileType
        self.dateAdded = dateAdded
        self.pet = pet
    }
}

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
    /// `nil` = unknown / not set (CloudKit-friendly default).
    var isSpayedNeutered: Bool? = nil

    /// Profile emergency contact (Care Card / Edit Pet).
    var emergencyContactName: String = ""
    var emergencyContactNumber: String = ""
    /// Free-text allergies for this pet (Care Card).
    var allergies: String = ""
    /// Extra notes for care card / pet sitter (Edit Pet → Other).
    var specialNotes: String = ""
    /// Optional image embedded on the exported Quick Care Card (Customize Card).
    @Attribute(.externalStorage) var careCardAttachmentImageData: Data? = nil
    /// Manual only — never set from PDF/AI import. Optional next vet visit (date).
    var nextVetAppointmentDate: Date?

    @Relationship(deleteRule: .cascade, inverse: \VaccineEntry.pet)
    var vaccines: [VaccineEntry]? = nil

    @Relationship(deleteRule: .cascade, inverse: \MedicationEntry.pet)
    var medications: [MedicationEntry]? = nil

    @Relationship(deleteRule: .cascade, inverse: \PetAttachment.pet)
    var attachments: [PetAttachment]? = nil

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
        microchipRegistry: String = "",
        isSpayedNeutered: Bool? = nil,
        emergencyContactName: String = "",
        emergencyContactNumber: String = "",
        allergies: String = "",
        specialNotes: String = "",
        careCardAttachmentImageData: Data? = nil,
        nextVetAppointmentDate: Date? = nil
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
        self.isSpayedNeutered = isSpayedNeutered
        self.emergencyContactName = emergencyContactName
        self.emergencyContactNumber = emergencyContactNumber
        self.allergies = allergies
        self.specialNotes = specialNotes
        self.careCardAttachmentImageData = careCardAttachmentImageData
        self.nextVetAppointmentDate = nextVetAppointmentDate
    }
}

// MARK: - Codable interchange
// SwiftData `@Model` types do not synthesize `Codable`; use these for export and backup mapping.

struct VaccineEntryCodable: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var dateAdministered: Date
    var dateExpires: Date?
}

struct MedicationEntryCodable: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var amount: String
    var frequency: String
}

struct PetProfileAttachmentCodable: Codable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var data: Data
    var fileType: String
    var dateAdded: Date
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
    /// Non-optional read helpers for profile care entries (relationship arrays are optional for CloudKit).
    var vaccinesArray: [VaccineEntry] { vaccines ?? [] }
    var medicationsArray: [MedicationEntry] { medications ?? [] }
    var attachmentsArray: [PetAttachment] { attachments ?? [] }

    func appendVaccine(_ entry: VaccineEntry) {
        if vaccines == nil { vaccines = [] }
        vaccines!.append(entry)
    }

    func appendMedication(_ entry: MedicationEntry) {
        if medications == nil { medications = [] }
        medications!.append(entry)
    }

    func appendAttachment(_ attachment: PetAttachment) {
        if attachments == nil { attachments = [] }
        attachments!.append(attachment)
    }

    /// Persists only the active pet id for legacy screens that key off `activePetId`. Profile fields and avatar live in SwiftData only.
    func syncToLegacyAppStorage() {
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
    /// User-facing filename for exports/sharing (e.g. `vet-visit-2026-04-15.jpg`).
    var displayFileName: String = ""
    /// Human-readable provenance (import source, AI context).
    var sourceNote: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        parentRecordId: UUID,
        parentKind: PetRecordAttachmentParentKind,
        fileData: Data,
        contentKind: String,
        displayFileName: String = "",
        sourceNote: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.parentRecordId = parentRecordId
        self.parentKind = parentKind.rawValue
        self.fileData = fileData
        self.contentKind = contentKind
        self.displayFileName = displayFileName
        self.sourceNote = sourceNote
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

/// A manually logged walk for the active pet (Apple Health aggregates stay separate).
@Model
final class ManualWalkEntry: Identifiable {
    var id: UUID = UUID()
    /// Scoped to `ActivePetResolver` / `PetRecordFilter` like other per-pet records.
    var petId: UUID?
    var walkDate: Date = Date()
    var durationMinutes: Int = 0
    var distance: Double = 0
    /// `"mi"` or `"km"` for display of `distance`.
    var distanceUnit: String = "mi"
    var notes: String = ""
    var createdAt: Date = Date()

    init(
        id: UUID = UUID(),
        petId: UUID? = nil,
        walkDate: Date = Date(),
        durationMinutes: Int = 0,
        distance: Double = 0,
        distanceUnit: String = "mi",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.petId = petId
        self.walkDate = walkDate
        self.durationMinutes = durationMinutes
        self.distance = distance
        self.distanceUnit = distanceUnit
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class MilestoneRecord {
    var id: UUID = UUID()
    var petId: UUID = UUID()
    var milestoneType: String = ""
    var triggeredDate: Date = Date()
    var year: Int = 0
    var funStatLine: String?
    var wasAutoTriggered: Bool = false
    /// Full-bleed card background image (PNG/JPEG data). CloudKit-friendly optional.
    var cardPhotoData: Data?
    /// Headline for `milestoneType == "custom"`; ignored for other types.
    var customCardTitle: String?

    init(
        petId: UUID,
        milestoneType: String,
        triggeredDate: Date,
        year: Int,
        funStatLine: String? = nil,
        wasAutoTriggered: Bool = false,
        cardPhotoData: Data? = nil,
        customCardTitle: String? = nil
    ) {
        self.id = UUID()
        self.petId = petId
        self.milestoneType = milestoneType
        self.triggeredDate = triggeredDate
        self.year = year
        self.funStatLine = funStatLine
        self.wasAutoTriggered = wasAutoTriggered
        self.cardPhotoData = cardPhotoData
        self.customCardTitle = customCardTitle
    }
}

@Model
final class HealthReportRecord {
    var id: UUID = UUID()
    /// The `VetVisitLog.id` this report was generated for.
    var visitId: UUID = UUID()
    var petId: UUID = UUID()
    var visitDate: Date = Date()
    var generatedDate: Date = Date()
    var gradeString: String = ""
    var gradeReason: String = ""
    var visitSummaryText: String = ""
    var currentWeightLbs: Double?
    var previousWeightLbs: Double?
    var vaccineStatusSummary: String = ""
    var nextCheckupDate: Date?
    var activeMedicationsCount: Int = 0

    init(
        visitId: UUID,
        petId: UUID,
        visitDate: Date,
        gradeString: String,
        gradeReason: String,
        visitSummaryText: String,
        currentWeightLbs: Double? = nil,
        previousWeightLbs: Double? = nil,
        vaccineStatusSummary: String = "",
        nextCheckupDate: Date? = nil,
        activeMedicationsCount: Int = 0
    ) {
        self.id = UUID()
        self.visitId = visitId
        self.petId = petId
        self.visitDate = visitDate
        self.generatedDate = Date()
        self.gradeString = gradeString
        self.gradeReason = gradeReason
        self.visitSummaryText = visitSummaryText
        self.currentWeightLbs = currentWeightLbs
        self.previousWeightLbs = previousWeightLbs
        self.vaccineStatusSummary = vaccineStatusSummary
        self.nextCheckupDate = nextCheckupDate
        self.activeMedicationsCount = activeMedicationsCount
    }
}

// MARK: - Highlights / Year in Review

@Model
final class PetMonthlyPhoto {
    var id: UUID = UUID()
    var petId: UUID = UUID()
    var month: Int = 1
    var year: Int = 2026
    @Attribute(.externalStorage) var photoData: Data = Data()
    var caption: String?
    var addedDate: Date = Date()

    init(petId: UUID, month: Int, year: Int, photoData: Data, caption: String? = nil) {
        self.id = UUID()
        self.petId = petId
        self.month = month
        self.year = year
        self.photoData = photoData
        self.caption = caption
        self.addedDate = Date()
    }
}

@Model
final class YearInReviewRecord {
    var id: UUID = UUID()
    var petId: UUID = UUID()
    var year: Int = 2026
    var generatedDate: Date = Date()
    var personalityLine: String?
    var yearHeadline: String?
    /// Apple Health walking + running distance for the calendar `year` (general activity, not pet-specific).
    var totalMiles: Double = 0
    var totalSteps: Int = 0
    /// Manual `ManualWalkEntry` count for this pet in the calendar `year`.
    var totalWalksWithPet: Int = 0
    /// Sum of manual walk distances for this pet in the calendar `year`, stored in miles.
    var totalMilesWithPet: Double = 0.0
    var vetVisitsCount: Int = 0
    var milestonesCount: Int = 0
    var weightChangeText: String?
    var vaccinesCompletedCount: Int = 0
    var medicationsLoggedCount: Int = 0
    var aiConversationsCount: Int = 0

    init(petId: UUID, year: Int) {
        self.id = UUID()
        self.petId = petId
        self.year = year
        self.generatedDate = Date()
        self.totalMiles = 0
        self.totalSteps = 0
        self.totalWalksWithPet = 0
        self.totalMilesWithPet = 0
        self.vetVisitsCount = 0
        self.milestonesCount = 0
        self.vaccinesCompletedCount = 0
        self.medicationsLoggedCount = 0
        self.aiConversationsCount = 0
    }
}

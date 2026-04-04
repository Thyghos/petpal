// PetpalBackup.swift
// Export / import app data as JSON (share, email, AirDrop). Optional category selection.

import Foundation
import SwiftData

// MARK: - Selection (export UI)

struct BackupSelection: Equatable {
    var includePets: Bool
    var includeReminders: Bool
    var includeHealthHistory: Bool
    var includeEmergencyProfiles: Bool
    var includeInsurance: Bool
    var includeSitterInstructions: Bool
    var includeStoredVetDocuments: Bool
    var includeAppPreferences: Bool
    var includeCertificates: Bool

    static let allOn = BackupSelection(
        includePets: true,
        includeReminders: true,
        includeHealthHistory: true,
        includeEmergencyProfiles: true,
        includeInsurance: true,
        includeSitterInstructions: true,
        includeStoredVetDocuments: true,
        includeAppPreferences: true,
        includeCertificates: true
    )

    static let allOff = BackupSelection(
        includePets: false,
        includeReminders: false,
        includeHealthHistory: false,
        includeEmergencyProfiles: false,
        includeInsurance: false,
        includeSitterInstructions: false,
        includeStoredVetDocuments: false,
        includeAppPreferences: false,
        includeCertificates: false
    )

    var hasAnySelection: Bool {
        includePets || includeReminders || includeHealthHistory || includeEmergencyProfiles
            || includeInsurance || includeSitterInstructions || includeStoredVetDocuments || includeAppPreferences
            || includeCertificates
    }

    mutating func setAll(_ on: Bool) {
        self = on ? .allOn : .allOff
    }
}

enum PetpalBackupImportMode: String, CaseIterable, Identifiable, Hashable {
    /// Insert only rows whose IDs are not already present.
    case mergeSkipExisting
    /// Insert missing rows; for matching IDs, replace fields with backup values.
    case mergeUpdateExisting
    /// Remove existing SwiftData content, then load backup.
    case replaceAll

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .mergeSkipExisting: return "Merge — keep existing, add new only"
        case .mergeUpdateExisting: return "Merge — update existing from backup"
        case .replaceAll: return "Replace all data on this device"
        }
    }
}

/// Export container for the share sheet (plain JSON or a one-file ZIP of the same JSON).
enum PetpalBackupExportFormat: String, CaseIterable, Identifiable, Hashable {
    case json
    case zip

    var id: String { rawValue }

    var pickerTitle: String {
        switch self {
        case .json: return "JSON (.json)"
        case .zip: return "ZIP (.zip)"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .zip: return "zip"
        }
    }
}

enum PetpalBackupError: LocalizedError {
    case nothingSelected
    case decodeFailed
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .nothingSelected:
            return "Choose at least one category to export."
        case .decodeFailed:
            return "This file doesn’t look like a valid Petpal backup."
        case .unsupportedVersion(let v):
            return "This backup format (version \(v)) isn’t supported. Update Petpal and try again."
        }
    }
}

// MARK: - DTOs

private struct PetpalBackupEnvelope: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var pets: [PetDTO]?
    var petReminders: [PetReminderDTO]?
    var vetVisitLogs: [VetVisitLogDTO]?
    var emergencyProfiles: [EmergencyProfileDTO]?
    var petInsurance: [PetInsuranceDTO]?
    var sitterInstructions: [PetSitterInstructionsDTO]?
    var storedVetDocuments: [StoredVetDocumentDTO]?
    var tilePreferences: [TilePreferencesDTO]?
    var healthTipPreferences: [HealthTipPreferencesDTO]?
    var attachments: [PetRecordAttachmentDTO]?
    var petCertificates: [PetCertificateDTO]?
}

private struct PetDTO: Codable {
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
    var vetName: String
    var vetPhone: String
    var vetEmail: String
    var groomerName: String
    var groomerPhone: String
    var microchipNumber: String
    var microchipRegistry: String

    enum CodingKeys: String, CodingKey {
        case id, name, species, breed, weight, weightUnit, profileImage, dateAdded, dateOfBirth, isActive
        case vetName, vetPhone, vetEmail, groomerName, groomerPhone
        case microchipNumber, microchipRegistry
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        species = try c.decode(String.self, forKey: .species)
        breed = try c.decode(String.self, forKey: .breed)
        weight = try c.decode(Double.self, forKey: .weight)
        weightUnit = try c.decode(String.self, forKey: .weightUnit)
        profileImage = try c.decodeIfPresent(Data.self, forKey: .profileImage)
        dateAdded = try c.decode(Date.self, forKey: .dateAdded)
        dateOfBirth = try c.decodeIfPresent(Date.self, forKey: .dateOfBirth)
        isActive = try c.decode(Bool.self, forKey: .isActive)
        vetName = try c.decode(String.self, forKey: .vetName)
        vetPhone = try c.decode(String.self, forKey: .vetPhone)
        vetEmail = try c.decodeIfPresent(String.self, forKey: .vetEmail) ?? ""
        groomerName = try c.decode(String.self, forKey: .groomerName)
        groomerPhone = try c.decode(String.self, forKey: .groomerPhone)
        microchipNumber = try c.decodeIfPresent(String.self, forKey: .microchipNumber) ?? ""
        microchipRegistry = try c.decodeIfPresent(String.self, forKey: .microchipRegistry) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(species, forKey: .species)
        try c.encode(breed, forKey: .breed)
        try c.encode(weight, forKey: .weight)
        try c.encode(weightUnit, forKey: .weightUnit)
        try c.encodeIfPresent(profileImage, forKey: .profileImage)
        try c.encode(dateAdded, forKey: .dateAdded)
        try c.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
        try c.encode(isActive, forKey: .isActive)
        try c.encode(vetName, forKey: .vetName)
        try c.encode(vetPhone, forKey: .vetPhone)
        try c.encode(vetEmail, forKey: .vetEmail)
        try c.encode(groomerName, forKey: .groomerName)
        try c.encode(groomerPhone, forKey: .groomerPhone)
        try c.encode(microchipNumber, forKey: .microchipNumber)
        try c.encode(microchipRegistry, forKey: .microchipRegistry)
    }
}

private struct PetCertificateDTO: Codable {
    var id: UUID
    var petId: UUID?
    var title: String
    var notes: String
    var category: String
    var expirationDate: Date?
    var createdAt: Date
    var updatedAt: Date
}

private struct PetReminderDTO: Codable {
    var id: UUID
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
}

private struct VetVisitLogDTO: Codable {
    var id: UUID
    var petId: UUID?
    var visitDate: Date
    var clinicName: String
    var reason: String
    var notes: String
    var createdAt: Date
}

private struct EmergencyProfileDTO: Codable {
    var id: UUID
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
}

private struct PetInsuranceDTO: Codable {
    var id: UUID
    var petId: UUID?
    var providerName: String
    var policyNumber: String
    var phone: String
    var notes: String
    var renewalDate: Date?
    var createdAt: Date
}

private struct PetSitterInstructionsDTO: Codable {
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
    var allergies: String?
    var medications: String?
    var vetName: String?
    var vetPhone: String?
    var vetAddress: String?
    var specialInstructions: String
    var updatedAt: Date
}

private struct StoredVetDocumentDTO: Codable {
    var id: UUID
    var title: String
    var notes: String
    var documentKind: String
    var recordDate: Date
    var createdAt: Date
}

private struct TilePreferencesDTO: Codable {
    var id: UUID
    var tileOrder: [String]
    var hiddenTiles: [String]
    var lastUpdated: Date
}

private struct HealthTipPreferencesDTO: Codable {
    var id: UUID
    var isEnabled: Bool
    var frequencyRaw: String
    var lastShownDate: Date?
    var currentTipIndex: Int
    var petSpecies: String
}

private struct PetRecordAttachmentDTO: Codable {
    var id: UUID
    var parentRecordId: UUID
    var parentKind: String
    var fileData: Data
    var contentKind: String
    var createdAt: Date
}

// MARK: - Export

/// All entry points use `ModelContext` / `@Model` types; keep on the main actor for Swift 6 isolation.
@MainActor
enum PetpalBackup {
    static let supportedFormatVersion = 2
    static let fileNamePrefix = "Petpal-Backup"

    static func exportJSON(selection: BackupSelection, modelContext: ModelContext) throws -> Data {
        guard selection.hasAnySelection else { throw PetpalBackupError.nothingSelected }

        let petsFull = try modelContext.fetch(FetchDescriptor<Pet>())
        let petIdsNeeded = try referencedPetIds(selection: selection, modelContext: modelContext)
        let petsOut: [Pet]
        if selection.includePets {
            petsOut = petsFull
        } else {
            petsOut = petsFull.filter { petIdsNeeded.contains($0.id) }
        }

        var envelope = PetpalBackupEnvelope(
            formatVersion: supportedFormatVersion,
            exportedAt: Date(),
            pets: nil,
            petReminders: nil,
            vetVisitLogs: nil,
            emergencyProfiles: nil,
            petInsurance: nil,
            sitterInstructions: nil,
            storedVetDocuments: nil,
            tilePreferences: nil,
            healthTipPreferences: nil,
            attachments: nil,
            petCertificates: nil
        )

        if !petsOut.isEmpty {
            envelope.pets = petsOut.map(PetDTO.init(model:))
        }

        if selection.includeReminders {
            let rows = try modelContext.fetch(FetchDescriptor<PetReminder>())
            envelope.petReminders = rows.map(PetReminderDTO.init(model:))
        }
        
        var reminderIds = Set<UUID>()
        if selection.includeReminders {
            reminderIds = Set((envelope.petReminders ?? []).map(\.id))
        }

        var visitIds = Set<UUID>()
        if selection.includeHealthHistory {
            let rows = try modelContext.fetch(FetchDescriptor<VetVisitLog>())
            envelope.vetVisitLogs = rows.map(VetVisitLogDTO.init(model:))
            visitIds = Set(rows.map(\.id))
        }

        if selection.includeEmergencyProfiles {
            let rows = try modelContext.fetch(FetchDescriptor<EmergencyProfile>())
            envelope.emergencyProfiles = rows.map(EmergencyProfileDTO.init(model:))
        }

        var insuranceIds = Set<UUID>()
        if selection.includeInsurance {
            let rows = try modelContext.fetch(FetchDescriptor<PetInsuranceInfo>())
            envelope.petInsurance = rows.map(PetInsuranceDTO.init(model:))
            insuranceIds = Set(rows.map(\.id))
        }

        var certificateIds = Set<UUID>()
        if selection.includeCertificates {
            let rows = try modelContext.fetch(FetchDescriptor<PetCertificate>())
            envelope.petCertificates = rows.map(PetCertificateDTO.init(model:))
            certificateIds = Set(rows.map(\.id))
        }

        if selection.includeSitterInstructions {
            let rows = try modelContext.fetch(FetchDescriptor<PetSitterInstructions>())
            envelope.sitterInstructions = rows.map(PetSitterInstructionsDTO.init(model:))
        }

        var docIds = Set<UUID>()
        if selection.includeStoredVetDocuments {
            let rows = try modelContext.fetch(FetchDescriptor<StoredVetDocument>())
            envelope.storedVetDocuments = rows.map(StoredVetDocumentDTO.init(model:))
            docIds = Set(rows.map(\.id))
        }

        if selection.includeAppPreferences {
            envelope.tilePreferences = try modelContext.fetch(FetchDescriptor<TilePreferences>()).map(TilePreferencesDTO.init(model:))
            envelope.healthTipPreferences = try modelContext.fetch(FetchDescriptor<HealthTipPreferences>()).map(HealthTipPreferencesDTO.init(model:))
        }

        let allAtt = try modelContext.fetch(FetchDescriptor<PetRecordAttachment>())
        var attOut: [PetRecordAttachment] = []
        for a in allAtt {
            guard let kind = PetRecordAttachmentParentKind(rawValue: a.parentKind) else { continue }
            switch kind {
            case .vetVisit:
                if selection.includeHealthHistory && visitIds.contains(a.parentRecordId) {
                    attOut.append(a)
                }
            case .insurance:
                if selection.includeInsurance && insuranceIds.contains(a.parentRecordId) {
                    attOut.append(a)
                }
            case .vetDocument:
                if selection.includeStoredVetDocuments && docIds.contains(a.parentRecordId) {
                    attOut.append(a)
                }
            case .reminder:
                if selection.includeReminders && reminderIds.contains(a.parentRecordId) {
                    attOut.append(a)
                }
            case .certificate:
                if selection.includeCertificates && certificateIds.contains(a.parentRecordId) {
                    attOut.append(a)
                }
            }
        }
        if !attOut.isEmpty {
            envelope.attachments = attOut.map(PetRecordAttachmentDTO.init(model:))
        }

        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        return try enc.encode(envelope)
    }

    private static func referencedPetIds(selection: BackupSelection, modelContext: ModelContext) throws -> Set<UUID> {
        var ids = Set<UUID>()
        if selection.includeReminders {
            for r in try modelContext.fetch(FetchDescriptor<PetReminder>()) {
                if let p = r.petId { ids.insert(p) }
            }
        }
        if selection.includeHealthHistory {
            for v in try modelContext.fetch(FetchDescriptor<VetVisitLog>()) {
                if let p = v.petId { ids.insert(p) }
            }
        }
        if selection.includeInsurance {
            for x in try modelContext.fetch(FetchDescriptor<PetInsuranceInfo>()) {
                if let p = x.petId { ids.insert(p) }
            }
        }
        if selection.includeSitterInstructions {
            for x in try modelContext.fetch(FetchDescriptor<PetSitterInstructions>()) {
                if let p = x.petId { ids.insert(p) }
            }
        }
        if selection.includeEmergencyProfiles {
            for e in try modelContext.fetch(FetchDescriptor<EmergencyProfile>()) {
                if let p = e.linkedPetId { ids.insert(p) }
            }
        }
        if selection.includeCertificates {
            for c in try modelContext.fetch(FetchDescriptor<PetCertificate>()) {
                if let p = c.petId { ids.insert(p) }
            }
        }
        return ids
    }

    // MARK: - Import

    static func importJSON(_ data: Data, mode: PetpalBackupImportMode, modelContext: ModelContext) throws {
        let payload = try PetpalBackupZip.jsonDataIfZipOrPlain(data)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        let env = try dec.decode(PetpalBackupEnvelope.self, from: payload)
        guard env.formatVersion == supportedFormatVersion else {
            throw PetpalBackupError.unsupportedVersion(env.formatVersion)
        }

        switch mode {
        case .replaceAll:
            try deleteAllSwiftData(modelContext: modelContext)
            try insertAll(from: env, modelContext: modelContext)
        case .mergeSkipExisting:
            try merge(from: env, modelContext: modelContext)
        case .mergeUpdateExisting:
            try mergeUpdate(from: env, modelContext: modelContext)
        }

        try modelContext.save()
        syncActivePetUserDefaults(modelContext: modelContext)
    }

    private static func deleteAllSwiftData(modelContext: ModelContext) throws {
        for a in try modelContext.fetch(FetchDescriptor<PetRecordAttachment>()) {
            modelContext.delete(a)
        }
        for x in try modelContext.fetch(FetchDescriptor<VetVisitLog>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<PetReminder>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<PetInsuranceInfo>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<PetSitterInstructions>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<EmergencyProfile>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<StoredVetDocument>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<PetCertificate>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<Pet>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<TilePreferences>()) {
            modelContext.delete(x)
        }
        for x in try modelContext.fetch(FetchDescriptor<HealthTipPreferences>()) {
            modelContext.delete(x)
        }
    }

    private static func insertAll(from env: PetpalBackupEnvelope, modelContext: ModelContext) throws {
        if let rows = env.pets {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.petReminders {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.vetVisitLogs {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.emergencyProfiles {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.petInsurance {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.sitterInstructions {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.storedVetDocuments {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.tilePreferences {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.healthTipPreferences {
            for dto in rows {
                modelContext.insert(try dto.toModel())
            }
        }
        if let rows = env.petCertificates {
            for dto in rows {
                modelContext.insert(dto.toModel())
            }
        }
        if let rows = env.attachments {
            for dto in rows {
                modelContext.insert(try dto.toModel())
            }
        }
    }

    private static func merge(from env: PetpalBackupEnvelope, modelContext: ModelContext) throws {
        if let rows = env.pets {
            for dto in rows {
                if try fetchPet(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.petReminders {
            for dto in rows {
                if try fetchReminder(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.vetVisitLogs {
            for dto in rows {
                if try fetchVisit(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.emergencyProfiles {
            for dto in rows {
                if try fetchEmergency(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.petInsurance {
            for dto in rows {
                if try fetchInsurance(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.sitterInstructions {
            for dto in rows {
                if try fetchSitter(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.storedVetDocuments {
            for dto in rows {
                if try fetchStoredDoc(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.tilePreferences {
            for dto in rows {
                if try fetchTilePrefs(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.healthTipPreferences {
            for dto in rows {
                if try fetchHealthTipPrefs(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(try dto.toModel())
                }
            }
        }
        if let rows = env.petCertificates {
            for dto in rows {
                if try fetchCertificate(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.attachments {
            for dto in rows {
                if try fetchAttachment(id: dto.id, modelContext: modelContext) == nil {
                    modelContext.insert(try dto.toModel())
                }
            }
        }
    }

    private static func mergeUpdate(from env: PetpalBackupEnvelope, modelContext: ModelContext) throws {
        if let rows = env.pets {
            for dto in rows {
                if let existing = try fetchPet(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.petReminders {
            for dto in rows {
                if let existing = try fetchReminder(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.vetVisitLogs {
            for dto in rows {
                if let existing = try fetchVisit(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.emergencyProfiles {
            for dto in rows {
                if let existing = try fetchEmergency(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.petInsurance {
            for dto in rows {
                if let existing = try fetchInsurance(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.sitterInstructions {
            for dto in rows {
                if let existing = try fetchSitter(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.storedVetDocuments {
            for dto in rows {
                if let existing = try fetchStoredDoc(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.tilePreferences {
            for dto in rows {
                if let existing = try fetchTilePrefs(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.healthTipPreferences {
            for dto in rows {
                if let existing = try fetchHealthTipPrefs(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(try dto.toModel())
                }
            }
        }
        if let rows = env.petCertificates {
            for dto in rows {
                if let existing = try fetchCertificate(id: dto.id, modelContext: modelContext) {
                    existing.apply(from: dto)
                } else {
                    modelContext.insert(dto.toModel())
                }
            }
        }
        if let rows = env.attachments {
            for dto in rows {
                if let existing = try fetchAttachment(id: dto.id, modelContext: modelContext) {
                    try existing.apply(from: dto)
                } else {
                    modelContext.insert(try dto.toModel())
                }
            }
        }
    }

    private static func fetchPet(id: UUID, modelContext: ModelContext) throws -> Pet? {
        let idv = id
        var d = FetchDescriptor<Pet>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchReminder(id: UUID, modelContext: ModelContext) throws -> PetReminder? {
        let idv = id
        var d = FetchDescriptor<PetReminder>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchVisit(id: UUID, modelContext: ModelContext) throws -> VetVisitLog? {
        let idv = id
        var d = FetchDescriptor<VetVisitLog>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchEmergency(id: UUID, modelContext: ModelContext) throws -> EmergencyProfile? {
        let idv = id
        var d = FetchDescriptor<EmergencyProfile>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchInsurance(id: UUID, modelContext: ModelContext) throws -> PetInsuranceInfo? {
        let idv = id
        var d = FetchDescriptor<PetInsuranceInfo>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchSitter(id: UUID, modelContext: ModelContext) throws -> PetSitterInstructions? {
        let idv = id
        var d = FetchDescriptor<PetSitterInstructions>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchStoredDoc(id: UUID, modelContext: ModelContext) throws -> StoredVetDocument? {
        let idv = id
        var d = FetchDescriptor<StoredVetDocument>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchTilePrefs(id: UUID, modelContext: ModelContext) throws -> TilePreferences? {
        let idv = id
        var d = FetchDescriptor<TilePreferences>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchHealthTipPrefs(id: UUID, modelContext: ModelContext) throws -> HealthTipPreferences? {
        let idv = id
        var d = FetchDescriptor<HealthTipPreferences>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchAttachment(id: UUID, modelContext: ModelContext) throws -> PetRecordAttachment? {
        let idv = id
        var d = FetchDescriptor<PetRecordAttachment>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func fetchCertificate(id: UUID, modelContext: ModelContext) throws -> PetCertificate? {
        let idv = id
        var d = FetchDescriptor<PetCertificate>(predicate: #Predicate { $0.id == idv })
        d.fetchLimit = 1
        return try modelContext.fetch(d).first
    }

    private static func syncActivePetUserDefaults(modelContext: ModelContext) {
        let allPets = (try? modelContext.fetch(FetchDescriptor<Pet>())) ?? []
        let activeString = UserDefaults.standard.string(forKey: "activePetId")
        let activeId = activeString.flatMap(UUID.init(uuidString:))
        if let aid = activeId, let pet = allPets.first(where: { $0.id == aid }) {
            for p in allPets { p.isActive = (p.id == aid) }
            pet.syncToLegacyAppStorage()
        } else if let first = allPets.first {
            for p in allPets { p.isActive = (p.id == first.id) }
            first.syncToLegacyAppStorage()
        } else {
            UserDefaults.standard.removeObject(forKey: "activePetId")
        }
    }
}

// MARK: - DTO mappers

private extension PetDTO {
    init(model: Pet) {
        id = model.id
        name = model.name
        species = model.species
        breed = model.breed
        weight = model.weight
        weightUnit = model.weightUnit
        profileImage = model.profileImage
        dateAdded = model.dateAdded
        dateOfBirth = model.dateOfBirth
        isActive = model.isActive
        vetName = model.vetName
        vetPhone = model.vetPhone
        vetEmail = model.vetEmail
        groomerName = model.groomerName
        groomerPhone = model.groomerPhone
        microchipNumber = model.microchipNumber
        microchipRegistry = model.microchipRegistry
    }

    func toModel() -> Pet {
        Pet(
            id: id,
            name: name,
            species: species,
            breed: breed,
            weight: weight,
            weightUnit: weightUnit,
            profileImage: profileImage,
            dateAdded: dateAdded,
            dateOfBirth: dateOfBirth,
            isActive: isActive,
            vetName: vetName,
            vetPhone: vetPhone,
            vetEmail: vetEmail,
            groomerName: groomerName,
            groomerPhone: groomerPhone,
            microchipNumber: microchipNumber,
            microchipRegistry: microchipRegistry
        )
    }
}

private extension PetCertificateDTO {
    init(model: PetCertificate) {
        id = model.id
        petId = model.petId
        title = model.title
        notes = model.notes
        category = model.category
        expirationDate = model.expirationDate
        createdAt = model.createdAt
        updatedAt = model.updatedAt
    }

    func toModel() -> PetCertificate {
        PetCertificate(
            id: id,
            petId: petId,
            title: title,
            notes: notes,
            category: category,
            expirationDate: expirationDate,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private extension PetReminderDTO {
    init(model: PetReminder) {
        id = model.id
        petId = model.petId
        title = model.title
        notes = model.notes
        category = model.category
        nextDueDate = model.nextDueDate
        recurring = model.recurring
        recurrenceInterval = model.recurrenceInterval
        recurrenceUnit = model.recurrenceUnit
        isCompleted = model.isCompleted
        completedDate = model.completedDate
        createdDate = model.createdDate
    }

    func toModel() -> PetReminder {
        PetReminder(
            id: id,
            petId: petId,
            title: title,
            notes: notes,
            category: category,
            nextDueDate: nextDueDate,
            recurring: recurring,
            recurrenceInterval: recurrenceInterval,
            recurrenceUnit: recurrenceUnit,
            isCompleted: isCompleted,
            completedDate: completedDate,
            createdDate: createdDate
        )
    }
}

private extension VetVisitLogDTO {
    init(model: VetVisitLog) {
        id = model.id
        petId = model.petId
        visitDate = model.visitDate
        clinicName = model.clinicName
        reason = model.reason
        notes = model.notes
        createdAt = model.createdAt
    }

    func toModel() -> VetVisitLog {
        VetVisitLog(id: id, petId: petId, visitDate: visitDate, clinicName: clinicName, reason: reason, notes: notes, createdAt: createdAt)
    }
}

private extension EmergencyProfileDTO {
    init(model: EmergencyProfile) {
        id = model.id
        linkedPetId = model.linkedPetId
        petName = model.petName
        ownerName = model.ownerName
        ownerPhone = model.ownerPhone
        ownerEmail = model.ownerEmail
        alternateContact = model.alternateContact
        medications = model.medications
        allergies = model.allergies
        medicalConditions = model.medicalConditions
        microchipNumber = model.microchipNumber
        vetName = model.vetName
        vetPhone = model.vetPhone
        vetAddress = model.vetAddress
        feedingInstructions = model.feedingInstructions
        specialNeeds = model.specialNeeds
        lostPetMessage = model.lostPetMessage
        rewardOffered = model.rewardOffered
        isActive = model.isActive
        lastUpdated = model.lastUpdated
    }

    func toModel() -> EmergencyProfile {
        EmergencyProfile(
            id: id,
            linkedPetId: linkedPetId,
            petName: petName,
            ownerName: ownerName,
            ownerPhone: ownerPhone,
            ownerEmail: ownerEmail,
            alternateContact: alternateContact,
            medications: medications,
            allergies: allergies,
            medicalConditions: medicalConditions,
            microchipNumber: microchipNumber,
            vetName: vetName,
            vetPhone: vetPhone,
            vetAddress: vetAddress,
            feedingInstructions: feedingInstructions,
            specialNeeds: specialNeeds,
            lostPetMessage: lostPetMessage,
            rewardOffered: rewardOffered,
            isActive: isActive,
            lastUpdated: lastUpdated
        )
    }
}

private extension PetInsuranceDTO {
    init(model: PetInsuranceInfo) {
        id = model.id
        petId = model.petId
        providerName = model.providerName
        policyNumber = model.policyNumber
        phone = model.phone
        notes = model.notes
        renewalDate = model.renewalDate
        createdAt = model.createdAt
    }

    func toModel() -> PetInsuranceInfo {
        PetInsuranceInfo(
            id: id,
            petId: petId,
            providerName: providerName,
            policyNumber: policyNumber,
            phone: phone,
            notes: notes,
            renewalDate: renewalDate,
            createdAt: createdAt
        )
    }
}

private extension PetSitterInstructionsDTO {
    init(model: PetSitterInstructions) {
        id = model.id
        petId = model.petId
        favoriteFood = model.favoriteFood
        foodAmount = model.foodAmount
        foodAddons = model.foodAddons
        foodSchedule = model.foodSchedule
        favoriteTreats = model.favoriteTreats
        treatAmount = model.treatAmount
        treatSchedule = model.treatSchedule
        walkSchedule = model.walkSchedule
        walkDuration = model.walkDuration
        allergies = model.allergies
        medications = model.medications
        vetName = model.vetName
        vetPhone = model.vetPhone
        vetAddress = model.vetAddress
        specialInstructions = model.specialInstructions
        updatedAt = model.updatedAt
    }

    func toModel() -> PetSitterInstructions {
        PetSitterInstructions(
            id: id,
            petId: petId,
            favoriteFood: favoriteFood,
            foodAmount: foodAmount,
            foodAddons: foodAddons,
            foodSchedule: foodSchedule,
            favoriteTreats: favoriteTreats,
            treatAmount: treatAmount,
            treatSchedule: treatSchedule,
            walkSchedule: walkSchedule,
            walkDuration: walkDuration,
            allergies: allergies,
            medications: medications,
            vetName: vetName,
            vetPhone: vetPhone,
            vetAddress: vetAddress,
            specialInstructions: specialInstructions,
            updatedAt: updatedAt
        )
    }
}

private extension StoredVetDocumentDTO {
    init(model: StoredVetDocument) {
        id = model.id
        title = model.title
        notes = model.notes
        documentKind = model.documentKind
        recordDate = model.recordDate
        createdAt = model.createdAt
    }

    func toModel() -> StoredVetDocument {
        StoredVetDocument(id: id, title: title, notes: notes, documentKind: documentKind, recordDate: recordDate, createdAt: createdAt)
    }
}

private extension TilePreferencesDTO {
    init(model: TilePreferences) {
        id = model.id
        tileOrder = model.tileOrder
        hiddenTiles = model.hiddenTiles
        lastUpdated = model.lastUpdated
    }

    func toModel() -> TilePreferences {
        TilePreferences(id: id, tileOrder: tileOrder, hiddenTiles: hiddenTiles, lastUpdated: lastUpdated)
    }
}

private extension HealthTipPreferencesDTO {
    init(model: HealthTipPreferences) {
        id = model.id
        isEnabled = model.isEnabled
        frequencyRaw = model.frequency.rawValue
        lastShownDate = model.lastShownDate
        currentTipIndex = model.currentTipIndex
        petSpecies = model.petSpecies
    }

    func toModel() throws -> HealthTipPreferences {
        let freq = TipFrequency(rawValue: frequencyRaw) ?? .daily
        return HealthTipPreferences(
            id: id,
            isEnabled: isEnabled,
            frequency: freq,
            lastShownDate: lastShownDate,
            currentTipIndex: currentTipIndex,
            petSpecies: petSpecies
        )
    }
}

private extension PetRecordAttachmentDTO {
    init(model: PetRecordAttachment) {
        id = model.id
        parentRecordId = model.parentRecordId
        parentKind = model.parentKind
        fileData = model.fileData
        contentKind = model.contentKind
        createdAt = model.createdAt
    }

    func toModel() throws -> PetRecordAttachment {
        guard let kind = PetRecordAttachmentParentKind(rawValue: parentKind) else {
            throw PetpalBackupError.decodeFailed
        }
        return PetRecordAttachment(
            id: id,
            parentRecordId: parentRecordId,
            parentKind: kind,
            fileData: fileData,
            contentKind: contentKind,
            createdAt: createdAt
        )
    }
}

// MARK: - Merge update: apply DTO onto existing SwiftData models

private extension Pet {
    func apply(from dto: PetDTO) {
        name = dto.name
        species = dto.species
        breed = dto.breed
        weight = dto.weight
        weightUnit = dto.weightUnit
        profileImage = dto.profileImage
        dateAdded = dto.dateAdded
        dateOfBirth = dto.dateOfBirth
        isActive = dto.isActive
        vetName = dto.vetName
        vetPhone = dto.vetPhone
        vetEmail = dto.vetEmail
        groomerName = dto.groomerName
        groomerPhone = dto.groomerPhone
        microchipNumber = dto.microchipNumber
        microchipRegistry = dto.microchipRegistry
    }
}

private extension PetCertificate {
    func apply(from dto: PetCertificateDTO) {
        petId = dto.petId
        title = dto.title
        notes = dto.notes
        category = dto.category
        expirationDate = dto.expirationDate
        createdAt = dto.createdAt
        updatedAt = dto.updatedAt
    }
}

private extension PetReminder {
    func apply(from dto: PetReminderDTO) {
        petId = dto.petId
        title = dto.title
        notes = dto.notes
        category = dto.category
        nextDueDate = dto.nextDueDate
        recurring = dto.recurring
        recurrenceInterval = dto.recurrenceInterval
        recurrenceUnit = dto.recurrenceUnit
        isCompleted = dto.isCompleted
        completedDate = dto.completedDate
        createdDate = dto.createdDate
    }
}

private extension VetVisitLog {
    func apply(from dto: VetVisitLogDTO) {
        petId = dto.petId
        visitDate = dto.visitDate
        clinicName = dto.clinicName
        reason = dto.reason
        notes = dto.notes
        createdAt = dto.createdAt
    }
}

private extension EmergencyProfile {
    func apply(from dto: EmergencyProfileDTO) {
        linkedPetId = dto.linkedPetId
        petName = dto.petName
        ownerName = dto.ownerName
        ownerPhone = dto.ownerPhone
        ownerEmail = dto.ownerEmail
        alternateContact = dto.alternateContact
        medications = dto.medications
        allergies = dto.allergies
        medicalConditions = dto.medicalConditions
        microchipNumber = dto.microchipNumber
        vetName = dto.vetName
        vetPhone = dto.vetPhone
        vetAddress = dto.vetAddress
        feedingInstructions = dto.feedingInstructions
        specialNeeds = dto.specialNeeds
        lostPetMessage = dto.lostPetMessage
        rewardOffered = dto.rewardOffered
        isActive = dto.isActive
        lastUpdated = dto.lastUpdated
    }
}

private extension PetInsuranceInfo {
    func apply(from dto: PetInsuranceDTO) {
        petId = dto.petId
        providerName = dto.providerName
        policyNumber = dto.policyNumber
        phone = dto.phone
        notes = dto.notes
        renewalDate = dto.renewalDate
        createdAt = dto.createdAt
    }
}

private extension PetSitterInstructions {
    func apply(from dto: PetSitterInstructionsDTO) {
        petId = dto.petId
        favoriteFood = dto.favoriteFood
        foodAmount = dto.foodAmount
        foodAddons = dto.foodAddons
        foodSchedule = dto.foodSchedule
        favoriteTreats = dto.favoriteTreats
        treatAmount = dto.treatAmount
        treatSchedule = dto.treatSchedule
        walkSchedule = dto.walkSchedule
        walkDuration = dto.walkDuration
        allergies = dto.allergies
        medications = dto.medications
        vetName = dto.vetName
        vetPhone = dto.vetPhone
        vetAddress = dto.vetAddress
        specialInstructions = dto.specialInstructions
        updatedAt = dto.updatedAt
    }
}

private extension StoredVetDocument {
    func apply(from dto: StoredVetDocumentDTO) {
        title = dto.title
        notes = dto.notes
        documentKind = dto.documentKind
        recordDate = dto.recordDate
        createdAt = dto.createdAt
    }
}

private extension TilePreferences {
    func apply(from dto: TilePreferencesDTO) {
        tileOrder = dto.tileOrder
        hiddenTiles = dto.hiddenTiles
        lastUpdated = dto.lastUpdated
    }
}

private extension HealthTipPreferences {
    func apply(from dto: HealthTipPreferencesDTO) {
        isEnabled = dto.isEnabled
        frequency = TipFrequency(rawValue: dto.frequencyRaw) ?? .daily
        lastShownDate = dto.lastShownDate
        currentTipIndex = dto.currentTipIndex
        petSpecies = dto.petSpecies
    }
}

private extension PetRecordAttachment {
    func apply(from dto: PetRecordAttachmentDTO) throws {
        guard PetRecordAttachmentParentKind(rawValue: dto.parentKind) != nil else {
            throw PetpalBackupError.decodeFailed
        }
        parentRecordId = dto.parentRecordId
        parentKind = dto.parentKind
        fileData = dto.fileData
        contentKind = dto.contentKind
        createdAt = dto.createdAt
    }
}

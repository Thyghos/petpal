// CareCardFieldSettings.swift
// Per-pet toggles + optional card-only overrides for Quick Care Card; persisted in UserDefaults as JSON.

import Foundation

struct CareCardFieldSettings: Codable, Equatable {
    var showPetName: Bool = true
    var showPhoto: Bool = true
    var showBreed: Bool = true
    var showAge: Bool = true
    var showWeight: Bool = true
    var showMicrochip: Bool = true
    var showSpayedNeutered: Bool = true
    var showVetName: Bool = true
    var showVetPhone: Bool = true
    var showVetEmail: Bool = true
    var showEmergencyName: Bool = true
    var showEmergencyPhone: Bool = true
    var showAllergies: Bool = true
    var showVaccines: Bool = true
    var showMedications: Bool = true
    /// Shows ``Pet/nextVetAppointmentDate`` on the card when set (manual profile field).
    var showNextVetAppointment: Bool = true
    /// Profile attachments list on the exported card.
    var showAttachments: Bool = true
    /// ``Pet/specialNotes`` when non-empty.
    var showSpecialNotes: Bool = true
    /// ``Pet/careCardAttachmentImageData`` on the exported card.
    var showCareCardPhoto: Bool = true

    /// When non-nil and non-empty after trim, overrides SwiftData-derived display on the exported card.
    var customWeight: String?
    var customMicrochip: String?
    var customVetName: String?
    var customVetPhone: String?
    var customVetEmail: String?
    var customEmergencyName: String?
    var customEmergencyPhone: String?
    var customAllergies: String?
    var customMedications: String?
    var customBreed: String?
    /// Mirrors card display: "Yes" / "No" / "Unknown"; optional override when set.
    var customSpayedNeutered: String?

    static var defaults: CareCardFieldSettings { CareCardFieldSettings() }

    /// Memberwise default initializer (also used for encoding round-trips).
    init() {}

    private static func storageKey(for petId: UUID) -> String {
        "careCardFields_\(petId.uuidString)"
    }

    static func load(for petId: UUID) -> CareCardFieldSettings {
        let key = storageKey(for: petId)
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(CareCardFieldSettings.self, from: data)
        } catch {
            return .defaults
        }
    }

    static func save(_ settings: CareCardFieldSettings, for petId: UUID) {
        let key = storageKey(for: petId)
        do {
            let encoded = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(encoded, forKey: key)
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    enum CodingKeys: String, CodingKey {
        case showPetName, showPhoto, showBreed, showAge, showWeight, showMicrochip, showSpayedNeutered
        case showVetName, showVetPhone, showVetEmail
        case showEmergencyName, showEmergencyPhone
        case showAllergies, showVaccines, showMedications, showNextVetAppointment
        case showAttachments, showSpecialNotes, showCareCardPhoto
        case customWeight, customMicrochip, customVetName, customVetPhone, customVetEmail
        case customEmergencyName, customEmergencyPhone, customAllergies, customMedications, customBreed, customSpayedNeutered
        /// Legacy single toggles (decoded only).
        case showVetContact, showEmergencyContact
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func b(_ key: CodingKeys) throws -> Bool? {
            try c.decodeIfPresent(Bool.self, forKey: key)
        }
        showPetName = try b(.showPetName) ?? true
        showPhoto = try b(.showPhoto) ?? true
        showBreed = try b(.showBreed) ?? true
        showAge = try b(.showAge) ?? true
        showWeight = try b(.showWeight) ?? true
        showMicrochip = try b(.showMicrochip) ?? true
        showSpayedNeutered = try b(.showSpayedNeutered) ?? true

        var vn = try b(.showVetName)
        var vp = try b(.showVetPhone)
        var ve = try b(.showVetEmail)
        if vn == nil, vp == nil, ve == nil {
            let legacy = try c.decodeIfPresent(Bool.self, forKey: .showVetContact)
            let v = legacy ?? true
            vn = v; vp = v; ve = v
        }
        showVetName = vn ?? true
        showVetPhone = vp ?? true
        showVetEmail = ve ?? true

        var en = try b(.showEmergencyName)
        var ep = try b(.showEmergencyPhone)
        if en == nil, ep == nil {
            let legacy = try c.decodeIfPresent(Bool.self, forKey: .showEmergencyContact)
            let v = legacy ?? true
            en = v; ep = v
        }
        showEmergencyName = en ?? true
        showEmergencyPhone = ep ?? true

        showAllergies = try b(.showAllergies) ?? true
        showVaccines = try b(.showVaccines) ?? true
        showMedications = try b(.showMedications) ?? true
        showNextVetAppointment = try b(.showNextVetAppointment) ?? true
        showAttachments = try b(.showAttachments) ?? true
        showSpecialNotes = try b(.showSpecialNotes) ?? true
        showCareCardPhoto = try b(.showCareCardPhoto) ?? true

        customWeight = try c.decodeIfPresent(String.self, forKey: .customWeight)
        customMicrochip = try c.decodeIfPresent(String.self, forKey: .customMicrochip)
        customVetName = try c.decodeIfPresent(String.self, forKey: .customVetName)
        customVetPhone = try c.decodeIfPresent(String.self, forKey: .customVetPhone)
        customVetEmail = try c.decodeIfPresent(String.self, forKey: .customVetEmail)
        customEmergencyName = try c.decodeIfPresent(String.self, forKey: .customEmergencyName)
        customEmergencyPhone = try c.decodeIfPresent(String.self, forKey: .customEmergencyPhone)
        customAllergies = try c.decodeIfPresent(String.self, forKey: .customAllergies)
        customMedications = try c.decodeIfPresent(String.self, forKey: .customMedications)
        customBreed = try c.decodeIfPresent(String.self, forKey: .customBreed)
        customSpayedNeutered = try c.decodeIfPresent(String.self, forKey: .customSpayedNeutered)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(showPetName, forKey: .showPetName)
        try c.encode(showPhoto, forKey: .showPhoto)
        try c.encode(showBreed, forKey: .showBreed)
        try c.encode(showAge, forKey: .showAge)
        try c.encode(showWeight, forKey: .showWeight)
        try c.encode(showMicrochip, forKey: .showMicrochip)
        try c.encode(showSpayedNeutered, forKey: .showSpayedNeutered)
        try c.encode(showVetName, forKey: .showVetName)
        try c.encode(showVetPhone, forKey: .showVetPhone)
        try c.encode(showVetEmail, forKey: .showVetEmail)
        try c.encode(showEmergencyName, forKey: .showEmergencyName)
        try c.encode(showEmergencyPhone, forKey: .showEmergencyPhone)
        try c.encode(showAllergies, forKey: .showAllergies)
        try c.encode(showVaccines, forKey: .showVaccines)
        try c.encode(showMedications, forKey: .showMedications)
        try c.encode(showNextVetAppointment, forKey: .showNextVetAppointment)
        try c.encode(showAttachments, forKey: .showAttachments)
        try c.encode(showSpecialNotes, forKey: .showSpecialNotes)
        try c.encode(showCareCardPhoto, forKey: .showCareCardPhoto)
        try c.encodeIfPresent(customWeight, forKey: .customWeight)
        try c.encodeIfPresent(customMicrochip, forKey: .customMicrochip)
        try c.encodeIfPresent(customVetName, forKey: .customVetName)
        try c.encodeIfPresent(customVetPhone, forKey: .customVetPhone)
        try c.encodeIfPresent(customVetEmail, forKey: .customVetEmail)
        try c.encodeIfPresent(customEmergencyName, forKey: .customEmergencyName)
        try c.encodeIfPresent(customEmergencyPhone, forKey: .customEmergencyPhone)
        try c.encodeIfPresent(customAllergies, forKey: .customAllergies)
        try c.encodeIfPresent(customMedications, forKey: .customMedications)
        try c.encodeIfPresent(customBreed, forKey: .customBreed)
        try c.encodeIfPresent(customSpayedNeutered, forKey: .customSpayedNeutered)
    }
}

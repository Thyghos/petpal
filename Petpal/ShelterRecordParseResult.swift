// ShelterRecordParseResult.swift
// Structured output from shelter/rescue adoption PDF parsing (Claude JSON).

import Foundation

struct ShelterRecordParseResult: Codable, Equatable, Sendable {
    var petName: String?
    var species: String?
    var breed: String?
    var birthDate: Date?
    var sex: String?
    var isSpayedNeutered: Bool?
    var colorMarkings: String?
    var microchipNumber: String?
    var weightKg: Double?
    var vaccinations: [ShelterVaccination]
    var medications: [ParsedMedication]
    var shelterName: String?
    var adoptionDate: Date?
    var notes: String?

    init(
        petName: String? = nil,
        species: String? = nil,
        breed: String? = nil,
        birthDate: Date? = nil,
        sex: String? = nil,
        isSpayedNeutered: Bool? = nil,
        colorMarkings: String? = nil,
        microchipNumber: String? = nil,
        weightKg: Double? = nil,
        vaccinations: [ShelterVaccination] = [],
        medications: [ParsedMedication] = [],
        shelterName: String? = nil,
        adoptionDate: Date? = nil,
        notes: String? = nil
    ) {
        self.petName = petName
        self.species = species
        self.breed = breed
        self.birthDate = birthDate
        self.sex = sex
        self.isSpayedNeutered = isSpayedNeutered
        self.colorMarkings = colorMarkings
        self.microchipNumber = microchipNumber
        self.weightKg = weightKg
        self.vaccinations = vaccinations
        self.medications = medications
        self.shelterName = shelterName
        self.adoptionDate = adoptionDate
        self.notes = notes
    }

    static var empty: ShelterRecordParseResult {
        ShelterRecordParseResult()
    }

    var hasMeaningfulExtractedContent: Bool {
        if let n = petName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { return true }
        if let s = species?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return true }
        if let b = breed?.trimmingCharacters(in: .whitespacesAndNewlines), !b.isEmpty { return true }
        if birthDate != nil { return true }
        if let sx = sex?.trimmingCharacters(in: .whitespacesAndNewlines), !sx.isEmpty { return true }
        if isSpayedNeutered != nil { return true }
        if let c = colorMarkings?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return true }
        if let m = microchipNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty { return true }
        if weightKg != nil { return true }
        if !vaccinations.isEmpty { return true }
        if !medications.isEmpty { return true }
        if let sh = shelterName?.trimmingCharacters(in: .whitespacesAndNewlines), !sh.isEmpty { return true }
        if adoptionDate != nil { return true }
        if let n = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty { return true }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case petName, species, breed, birthDate, sex, isSpayedNeutered, colorMarkings
        case microchipNumber, weightKg, vaccinations, medications, shelterName, adoptionDate, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        petName = Self.decodeTrimmedString(from: c, forKey: .petName)
        species = Self.decodeTrimmedString(from: c, forKey: .species)
        breed = Self.decodeTrimmedString(from: c, forKey: .breed)
        birthDate = Self.decodeFlexibleDateField(from: c, forKey: .birthDate)
        sex = Self.decodeTrimmedString(from: c, forKey: .sex)
        isSpayedNeutered = try c.decodeIfPresent(Bool.self, forKey: .isSpayedNeutered)
        colorMarkings = Self.decodeTrimmedString(from: c, forKey: .colorMarkings)
        microchipNumber = Self.decodeTrimmedString(from: c, forKey: .microchipNumber)
        weightKg = Self.decodeFlexibleDouble(from: c, forKey: .weightKg)
        vaccinations = (try? c.decodeIfPresent([ShelterVaccination].self, forKey: .vaccinations)) ?? []
        medications = (try? c.decodeIfPresent([ParsedMedication].self, forKey: .medications)) ?? []
        shelterName = Self.decodeTrimmedString(from: c, forKey: .shelterName)
        adoptionDate = Self.decodeFlexibleDateField(from: c, forKey: .adoptionDate)
        notes = Self.decodeTrimmedString(from: c, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(petName, forKey: .petName)
        try c.encodeIfPresent(species, forKey: .species)
        try c.encodeIfPresent(breed, forKey: .breed)
        try c.encodeIfPresent(birthDate, forKey: .birthDate)
        try c.encodeIfPresent(sex, forKey: .sex)
        try c.encodeIfPresent(isSpayedNeutered, forKey: .isSpayedNeutered)
        try c.encodeIfPresent(colorMarkings, forKey: .colorMarkings)
        try c.encodeIfPresent(microchipNumber, forKey: .microchipNumber)
        try c.encodeIfPresent(weightKg, forKey: .weightKg)
        try c.encode(vaccinations, forKey: .vaccinations)
        try c.encode(medications, forKey: .medications)
        try c.encodeIfPresent(shelterName, forKey: .shelterName)
        try c.encodeIfPresent(adoptionDate, forKey: .adoptionDate)
        try c.encodeIfPresent(notes, forKey: .notes)
    }

    private static func decodeTrimmedString(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> String? {
        guard let s = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func decodeFlexibleDouble(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Double? {
        if let d = try? c.decodeIfPresent(Double.self, forKey: key) { return d }
        if let i = try? c.decodeIfPresent(Int.self, forKey: key) { return Double(i) }
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return nil }
            return Double(t.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    private static func decodeFlexibleDateField(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            return parseFlexibleDateString(s)
        }
        if let d = try? c.decodeIfPresent(Date.self, forKey: key) { return d }
        return nil
    }

    /// Shared by top-level fields and `ShelterVaccination.date`.
    static func parseFlexibleDateString(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }

        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFrac.date(from: s) { return d }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: s) { return d }

        let isoDay = ISO8601DateFormatter()
        isoDay.formatOptions = [.withFullDate]
        if let d = isoDay.date(from: s) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: String(s.prefix(10)))
    }
}

struct ShelterVaccination: Codable, Equatable, Sendable {
    var name: String
    var date: Date?

    init(name: String = "", date: Date? = nil) {
        self.name = name
        self.date = date
    }

    enum CodingKeys: String, CodingKey {
        case name
        case date
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let rawName = (try c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        let n = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = n.isEmpty ? "Vaccine" : n
        if let s = try? c.decodeIfPresent(String.self, forKey: .date) {
            date = ShelterRecordParseResult.parseFlexibleDateString(s)
        } else if let d = try? c.decodeIfPresent(Date.self, forKey: .date) {
            date = d
        } else {
            date = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(date, forKey: .date)
    }
}

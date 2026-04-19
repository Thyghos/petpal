// VetRecordParseResult.swift
// Structured output from vet-record PDF parsing (Claude JSON).

import Foundation

/// Vaccine name with a due or expiration date from a vet record (when the document lists it).
struct ParsedVaccineDue: Codable, Equatable, Hashable, Sendable {
    var name: String
    /// Next due date or expiration date from the record, whichever is present.
    var dueDate: Date?

    init(name: String, dueDate: Date?) {
        self.name = name
        self.dueDate = dueDate
    }

    enum CodingKeys: String, CodingKey {
        case name
        case dueDate
        case expirationDate
        case expiryDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let raw = (try c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = try c.decodeIfPresent(Date.self, forKey: .dueDate) {
            dueDate = d
        } else if let s = try c.decodeIfPresent(String.self, forKey: .dueDate) {
            dueDate = VetRecordParseResult.parseDateString(s)
        } else if let s = try c.decodeIfPresent(String.self, forKey: .expirationDate) {
            dueDate = VetRecordParseResult.parseDateString(s)
        } else if let s = try c.decodeIfPresent(String.self, forKey: .expiryDate) {
            dueDate = VetRecordParseResult.parseDateString(s)
        } else {
            dueDate = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
    }
}

struct VetRecordParseResult: Codable, Equatable, Sendable {
    var visitDate: Date?
    var vetName: String?
    var clinicName: String?
    var diagnoses: [String]
    var medications: [ParsedMedication]
    var vaccinesGiven: [String]
    /// Structured vaccines with due or expiration dates when extractable from the document.
    var vaccinesWithDueDates: [ParsedVaccineDue]
    var weightKg: Double?
    var nextAppointmentDate: Date?
    var notes: String?

    init(
        visitDate: Date? = nil,
        vetName: String? = nil,
        clinicName: String? = nil,
        diagnoses: [String] = [],
        medications: [ParsedMedication] = [],
        vaccinesGiven: [String] = [],
        vaccinesWithDueDates: [ParsedVaccineDue] = [],
        weightKg: Double? = nil,
        nextAppointmentDate: Date? = nil,
        notes: String? = nil
    ) {
        self.visitDate = visitDate
        self.vetName = vetName
        self.clinicName = clinicName
        self.diagnoses = diagnoses
        self.medications = medications
        self.vaccinesGiven = vaccinesGiven
        self.vaccinesWithDueDates = vaccinesWithDueDates
        self.weightKg = weightKg
        self.nextAppointmentDate = nextAppointmentDate
        self.notes = notes
    }

    /// Empty shell used when JSON decoding partially fails.
    static var empty: VetRecordParseResult {
        VetRecordParseResult(
            visitDate: nil,
            vetName: nil,
            clinicName: nil,
            diagnoses: [],
            medications: [],
            vaccinesGiven: [],
            vaccinesWithDueDates: [],
            weightKg: nil,
            nextAppointmentDate: nil,
            notes: nil
        )
    }

    /// True when the model extracted at least one clinical field (ignores freeform notes alone).
    var hasMeaningfulExtractedContent: Bool {
        if visitDate != nil { return true }
        if nextAppointmentDate != nil { return true }
        if weightKg != nil { return true }
        if let v = vetName?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty { return true }
        if let c = clinicName?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty { return true }
        if !diagnoses.isEmpty { return true }
        if !medications.isEmpty { return true }
        if !vaccinesGiven.isEmpty { return true }
        if !vaccinesWithDueDates.isEmpty { return true }
        return false
    }

    enum CodingKeys: String, CodingKey {
        case visitDate
        case vetName
        case clinicName
        case diagnoses
        case medications
        case vaccinesGiven
        case vaccinesWithDueDates
        case weightKg
        case nextAppointmentDate
        case notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        visitDate = Self.decodeFlexibleDate(from: c, forKey: .visitDate)
        vetName = Self.decodeTrimmedString(from: c, forKey: .vetName)
        clinicName = Self.decodeTrimmedString(from: c, forKey: .clinicName)
        diagnoses = (try? c.decodeIfPresent([String].self, forKey: .diagnoses))?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        medications = (try? c.decodeIfPresent([ParsedMedication].self, forKey: .medications)) ?? []
        vaccinesGiven = (try? c.decodeIfPresent([String].self, forKey: .vaccinesGiven))?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        vaccinesWithDueDates = (try? c.decodeIfPresent([ParsedVaccineDue].self, forKey: .vaccinesWithDueDates)) ?? []
        weightKg = Self.decodeFlexibleDouble(from: c, forKey: .weightKg)
        nextAppointmentDate = Self.decodeFlexibleDate(from: c, forKey: .nextAppointmentDate)
        notes = Self.decodeTrimmedString(from: c, forKey: .notes)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(visitDate, forKey: .visitDate)
        try c.encodeIfPresent(vetName, forKey: .vetName)
        try c.encodeIfPresent(clinicName, forKey: .clinicName)
        try c.encode(diagnoses, forKey: .diagnoses)
        try c.encode(medications, forKey: .medications)
        try c.encode(vaccinesGiven, forKey: .vaccinesGiven)
        try c.encode(vaccinesWithDueDates, forKey: .vaccinesWithDueDates)
        try c.encodeIfPresent(weightKg, forKey: .weightKg)
        try c.encodeIfPresent(nextAppointmentDate, forKey: .nextAppointmentDate)
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

    private static func decodeFlexibleDate(from c: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let s = try? c.decodeIfPresent(String.self, forKey: key) {
            return parseDateString(s)
        }
        if let d = try? c.decodeIfPresent(Date.self, forKey: key) { return d }
        return nil
    }

    fileprivate static func parseDateString(_ raw: String) -> Date? {
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

struct ParsedMedication: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var dosage: String?
    var frequency: String?

    init(id: UUID = UUID(), name: String, dosage: String? = nil, frequency: String? = nil) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
    }

    enum CodingKeys: String, CodingKey {
        case name
        case dosage
        case frequency
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = UUID()
        let rawName = (try c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        let n = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = n.isEmpty ? "Medication" : n
        dosage = try c.decodeIfPresent(String.self, forKey: .dosage).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
        frequency = try c.decodeIfPresent(String.self, forKey: .frequency).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(dosage, forKey: .dosage)
        try c.encodeIfPresent(frequency, forKey: .frequency)
    }
}

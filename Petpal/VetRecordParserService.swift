// VetRecordParserService.swift
// Sends extracted PDF text to Claude via the Vet AI Cloudflare proxy (same as VetAIView).

import Foundation

enum VetRecordParserError: Equatable, LocalizedError {
    case noAPIConfigured
    case networkFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .noAPIConfigured:
            return "Vet AI proxy is not configured."
        case .networkFailed(let s):
            return s
        case .invalidResponse(let s):
            return s
        }
    }
}

struct VetRecordParserResponse: Sendable {
    var result: VetRecordParseResult
    /// True only when the top-level JSON decoded cleanly as `VetRecordParseResult` (not best-effort or raw fallback).
    var structuredDecodeSucceeded: Bool
}

enum VetRecordParserService {
    private static let systemPrompt = """
You are a veterinary record parser. Extract structured data from the following vet visit record text. Return ONLY a JSON object with these fields: visitDate (ISO 8601 string or null), vetName (string or null), clinicName (string or null), diagnoses (array of strings), medications (array of objects with name, dosage, frequency fields), vaccinesGiven (array of strings), vaccinesWithDueDates (array of objects with name and dueDate or expirationDate as ISO 8601 date strings when the record lists a next due or expiry for that vaccine), weightKg (number or null), nextAppointmentDate (ISO 8601 string or null), notes (string or null). If a field cannot be found use null. Return only valid JSON with no explanation, no markdown, no code fences.
"""

    private static var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    /// Parses PDF text into structured fields. On malformed JSON, returns partial data when possible.
    static func parse(
        pdfText: String,
        petDisplayName: String,
        petSpecies: String
    ) async -> Result<VetRecordParserResponse, VetRecordParserError> {
        let trimmed = pdfText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(VetRecordParserResponse(result: .empty, structuredDecodeSucceeded: true))
        }

        let rawReply: String
        do {
            if APIConfiguration.vetAIProxyURL != nil {
                rawReply = try await fetchViaProxy(
                    pdfText: trimmed,
                    petName: petDisplayName,
                    petSpecies: petSpecies
                )
            } else {
                return .failure(.noAPIConfigured)
            }
        } catch {
            return .failure(.networkFailed(error.localizedDescription))
        }

        let cleaned = stripMarkdownFences(from: rawReply)
        guard let data = extractJSONObjectData(from: cleaned) else {
            var partial = VetRecordParseResult.empty
            partial.notes = mergeNotes(partial.notes, "Unparsed model output:\n\n\(cleaned.prefix(4000))")
            return .success(VetRecordParserResponse(result: partial, structuredDecodeSucceeded: false))
        }

        do {
            let decoded = try jsonDecoder.decode(VetRecordParseResult.self, from: data)
            return .success(VetRecordParserResponse(result: decoded, structuredDecodeSucceeded: true))
        } catch {
            if let fallback = bestEffortParse(from: data) {
                var merged = fallback
                merged.notes = mergeNotes(merged.notes, "Some fields could not be read automatically (\(error.localizedDescription)).")
                return .success(VetRecordParserResponse(result: merged, structuredDecodeSucceeded: false))
            }
            var partial = VetRecordParseResult.empty
            partial.notes = mergeNotes(partial.notes, "Could not parse JSON. Raw output:\n\n\(cleaned.prefix(4000))")
            return .success(VetRecordParserResponse(result: partial, structuredDecodeSucceeded: false))
        }
    }

    // MARK: - Networking (Vet AI proxy only)

    private static func fetchViaProxy(
        pdfText: String,
        petName: String,
        petSpecies: String
    ) async throws -> String {
        let userContent = """
\(systemPrompt)

---
Vet visit record text to parse (return only the JSON object described above):

\(pdfText)
"""

        do {
            return try await ClaudeProxyClient.send(
                messages: [["role": "user", "content": userContent]],
                petName: petName,
                petSpecies: petSpecies,
                petContext: ""
            )
        } catch let e as ClaudeProxyError {
            switch e {
            case .httpError(let s):
                throw VetRecordParserError.networkFailed(s)
            case .invalidResponse:
                throw VetRecordParserError.invalidResponse("Invalid proxy response.")
            case .noProxyConfigured, .invalidURL:
                throw VetRecordParserError.noAPIConfigured
            }
        }
    }

    // MARK: - JSON cleanup

    private static func stripMarkdownFences(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```json") {
            s = String(s.dropFirst("```json".count))
        } else if s.hasPrefix("```") {
            s = String(s.dropFirst(3))
        }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasSuffix("```") {
            s = String(s.dropLast(3))
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractJSONObjectData(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        guard let end = text.lastIndex(of: "}") else { return nil }
        guard end >= start else { return nil }
        let slice = text[start...end]
        return String(slice).data(using: .utf8)
    }

    private static func mergeNotes(_ a: String?, _ b: String) -> String {
        let t = b.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return a ?? "" }
        if let a, !a.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return a + "\n\n" + t
        }
        return t
    }

    /// Best-effort dictionary decode when Codable fails (e.g. odd medication shapes).
    private static func bestEffortParse(from data: Data) -> VetRecordParseResult? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        func str(_ key: String) -> String? {
            (obj[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }

        func strArray(_ key: String) -> [String] {
            guard let arr = obj[key] as? [Any] else { return [] }
            return arr.compactMap { $0 as? String }.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }

        var meds: [ParsedMedication] = []
        if let rawMeds = obj["medications"] as? [[String: Any]] {
            for m in rawMeds {
                let name = (m["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Medication"
                let dosage = m["dosage"] as? String
                let frequency = m["frequency"] as? String
                meds.append(ParsedMedication(name: name.isEmpty ? "Medication" : name, dosage: dosage, frequency: frequency))
            }
        }

        var weight: Double?
        if let d = obj["weightKg"] as? Double {
            weight = d
        } else if let i = obj["weightKg"] as? Int {
            weight = Double(i)
        } else if let s = obj["weightKg"] as? String {
            weight = Double(s.replacingOccurrences(of: ",", with: "."))
        }

        let visit = (str("visitDate")).flatMap { VetRecordParseResult.decodeStandaloneDate($0) }
        let nextAppt = (str("nextAppointmentDate")).flatMap { VetRecordParseResult.decodeStandaloneDate($0) }

        var vaccineDues: [ParsedVaccineDue] = []
        if let raw = obj["vaccinesWithDueDates"] as? [Any] {
            for item in raw {
                guard let row = item as? [String: Any] else { continue }
                let n = ((row["name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !n.isEmpty else { continue }
                let dueStr = (row["dueDate"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? (row["expirationDate"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                    ?? (row["expiryDate"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                let due = dueStr.flatMap { VetRecordParseResult.decodeStandaloneDate($0) }
                vaccineDues.append(ParsedVaccineDue(name: n, dueDate: due))
            }
        }

        return VetRecordParseResult(
            visitDate: visit,
            vetName: str("vetName"),
            clinicName: str("clinicName"),
            diagnoses: strArray("diagnoses"),
            medications: meds,
            vaccinesGiven: strArray("vaccinesGiven"),
            vaccinesWithDueDates: vaccineDues,
            weightKg: weight,
            nextAppointmentDate: nextAppt,
            notes: str("notes")
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

extension VetRecordParseResult {
    fileprivate static func decodeStandaloneDate(_ raw: String) -> Date? {
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

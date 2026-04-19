// ShelterRecordParserService.swift
// Shelter/rescue adoption PDF → Claude JSON (same routing as VetRecordParserService).

import Foundation

enum ShelterRecordParserError: Equatable, LocalizedError {
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

struct ShelterRecordParserResponse: Sendable {
    var result: ShelterRecordParseResult
    var structuredDecodeSucceeded: Bool
}

enum ShelterRecordParserService {
    private static let systemPrompt = """
You are a shelter adoption record parser. Extract structured data from the following shelter or rescue adoption record. Return ONLY a JSON object with these fields: petName (string or null), species (string or null), breed (string or null), birthDate (ISO 8601 string or null), sex (string or null), isSpayedNeutered (boolean or null), colorMarkings (string or null), microchipNumber (string or null), weightKg (number or null), vaccinations (array of objects with name and date fields, date is ISO 8601 or null), medications (array of objects with name, dosage, frequency fields), shelterName (string or null), adoptionDate (ISO 8601 string or null), notes (string or null). Return only valid JSON with no explanation, no markdown, no code fences.
"""

    private static var jsonDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func parse(
        pdfText: String,
        petDisplayName: String,
        petSpecies: String
    ) async -> Result<ShelterRecordParserResponse, ShelterRecordParserError> {
        let trimmed = pdfText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(ShelterRecordParserResponse(result: .empty, structuredDecodeSucceeded: true))
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
            var partial = ShelterRecordParseResult.empty
            partial.notes = mergeNotes(partial.notes, "Unparsed model output:\n\n\(cleaned.prefix(4000))")
            return .success(ShelterRecordParserResponse(result: partial, structuredDecodeSucceeded: false))
        }

        do {
            let decoded = try jsonDecoder.decode(ShelterRecordParseResult.self, from: data)
            return .success(ShelterRecordParserResponse(result: decoded, structuredDecodeSucceeded: true))
        } catch {
            if let fallback = bestEffortParse(from: data) {
                var merged = fallback
                merged.notes = mergeNotes(merged.notes, "Some fields could not be read automatically (\(error.localizedDescription)).")
                return .success(ShelterRecordParserResponse(result: merged, structuredDecodeSucceeded: false))
            }
            var partial = ShelterRecordParseResult.empty
            partial.notes = mergeNotes(partial.notes, "Could not parse JSON. Raw output:\n\n\(cleaned.prefix(4000))")
            return .success(ShelterRecordParserResponse(result: partial, structuredDecodeSucceeded: false))
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
Shelter or rescue adoption record text to parse (return only the JSON object described above):

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
                throw ShelterRecordParserError.networkFailed(s)
            case .invalidResponse:
                throw ShelterRecordParserError.invalidResponse("Invalid proxy response.")
            case .noProxyConfigured, .invalidURL:
                throw ShelterRecordParserError.noAPIConfigured
            }
        }
    }

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

    private static func bestEffortParse(from data: Data) -> ShelterRecordParseResult? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        func str(_ key: String) -> String? {
            (obj[key] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmptyShelter
        }

        var vax: [ShelterVaccination] = []
        if let raw = obj["vaccinations"] as? [[String: Any]] {
            for row in raw {
                let n = (row["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Vaccine"
                let dateStr = row["date"] as? String
                let d = dateStr.flatMap { ShelterRecordParseResult.parseFlexibleDateString($0) }
                vax.append(ShelterVaccination(name: n.isEmpty ? "Vaccine" : n, date: d))
            }
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

        var spayed: Bool?
        if let b = obj["isSpayedNeutered"] as? Bool {
            spayed = b
        } else if let s = obj["isSpayedNeutered"] as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if ["true", "yes", "y", "1"].contains(t) { spayed = true }
            else if ["false", "no", "n", "0"].contains(t) { spayed = false }
        }

        let birth = str("birthDate").flatMap { ShelterRecordParseResult.parseFlexibleDateString($0) }
        let adopt = str("adoptionDate").flatMap { ShelterRecordParseResult.parseFlexibleDateString($0) }

        return ShelterRecordParseResult(
            petName: str("petName"),
            species: str("species"),
            breed: str("breed"),
            birthDate: birth,
            sex: str("sex"),
            isSpayedNeutered: spayed,
            colorMarkings: str("colorMarkings"),
            microchipNumber: str("microchipNumber"),
            weightKg: weight,
            vaccinations: vax,
            medications: meds,
            shelterName: str("shelterName"),
            adoptionDate: adopt,
            notes: str("notes")
        )
    }
}

private extension String {
    var nilIfEmptyShelter: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

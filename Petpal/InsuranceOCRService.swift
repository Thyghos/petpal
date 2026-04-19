// Claude (Vet AI proxy) JSON extraction for insurance card OCR text.

import Foundation

enum InsuranceOCRError: Error, LocalizedError {
    case noAPIConfigured
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .noAPIConfigured:
            return "Vet AI proxy is not available. Try again later."
        case .invalidResponse:
            return "Could not read structured data from the scan."
        }
    }
}

struct InsuranceExtractedFields: Sendable {
    var providerName: String?
    var policyNumber: String?
    var phoneNumber: String?
    var coverageType: String?
}

enum InsuranceOCRService {
    private static let systemPrompt = """
    Extract pet insurance info from this text. Return ONLY JSON: {"providerName": string or null, "policyNumber": string or null, "phoneNumber": string or null, "coverageType": string or null}. Return only valid JSON, no markdown or code fences.
    """

    static func extract(from ocrText: String) async -> Result<InsuranceExtractedFields, InsuranceOCRError> {
        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(InsuranceExtractedFields(providerName: nil, policyNumber: nil, phoneNumber: nil, coverageType: nil))
        }
        guard APIConfiguration.vetAIProxyURL != nil else {
            return .failure(.noAPIConfigured)
        }
        do {
            let raw = try await ClaudeShortTextAPI.ocrJSONExtraction(
                systemPrompt: systemPrompt,
                userContent: trimmed,
                maxTokens: 512
            )
            let cleaned = stripMarkdownFences(from: raw)
            guard let data = extractJSONObjectData(from: cleaned) else {
                return .failure(.invalidResponse)
            }
            let decoded = try JSONDecoder().decode(InsuranceJSON.self, from: data)
            return .success(
                InsuranceExtractedFields(
                    providerName: nilIfEmpty(decoded.providerName),
                    policyNumber: nilIfEmpty(decoded.policyNumber),
                    phoneNumber: nilIfEmpty(decoded.phoneNumber),
                    coverageType: nilIfEmpty(decoded.coverageType)
                )
            )
        } catch {
            return .failure(.invalidResponse)
        }
    }

    private struct InsuranceJSON: Decodable {
        let providerName: String?
        let policyNumber: String?
        let phoneNumber: String?
        let coverageType: String?
    }

    private static func nilIfEmpty(_ s: String?) -> String? {
        let t = s?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    private static func stripMarkdownFences(from text: String) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.hasPrefix("```json") { t.removeFirst(7) }
        else if t.hasPrefix("```") { t.removeFirst(3) }
        if t.hasSuffix("```") { t.removeLast(3) }
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func extractJSONObjectData(from text: String) -> Data? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let sub = text[start ... end]
        return String(sub).data(using: .utf8)
    }
}

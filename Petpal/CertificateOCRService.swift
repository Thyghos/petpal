// Claude (Vet AI proxy) JSON extraction for certificate / vaccine card OCR text.

import Foundation

enum CertificateOCRError: Error, LocalizedError {
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

struct CertificateExtractedFields: Sendable {
    var title: String?
    var issueDate: Date?
    var expiryDate: Date?
}

enum CertificateOCRService {
    private static let systemPrompt = """
    Extract certificate/vaccine info from this text. Return ONLY JSON: {"name": string or null, "issueDate": string ISO8601 or null, "expiryDate": string ISO8601 or null}. Return only valid JSON, no markdown or code fences.
    """

    static func extract(from ocrText: String) async -> Result<CertificateExtractedFields, CertificateOCRError> {
        let trimmed = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .success(CertificateExtractedFields(title: nil, issueDate: nil, expiryDate: nil))
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
            let decoded = try JSONDecoder().decode(CertificateJSON.self, from: data)
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let iso2 = ISO8601DateFormatter()
            iso2.formatOptions = [.withFullDate]
            func parseDate(_ s: String?) -> Date? {
                guard let s = s?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
                return iso.date(from: s) ?? iso2.date(from: s) ?? ISO8601DateFormatter().date(from: s)
            }
            let title = decoded.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fields = CertificateExtractedFields(
                title: (title?.isEmpty == false) ? title : nil,
                issueDate: parseDate(decoded.issueDate),
                expiryDate: parseDate(decoded.expiryDate)
            )
            return .success(fields)
        } catch {
            return .failure(.invalidResponse)
        }
    }

    private struct CertificateJSON: Decodable {
        let name: String?
        let issueDate: String?
        let expiryDate: String?
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

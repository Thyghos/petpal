// Shared Claude one-shot text calls via the Vet AI Cloudflare proxy (same path as Vet AI chat / PDF parsers).

import Foundation

private enum ClaudeShortTextError: Error {
    case missingProxy
    case invalidResponse
}

enum ClaudeShortTextAPI {
    private static func post(system: String, user: String, maxTokens: Int = 128) async throws -> String {
        guard APIConfiguration.vetAIProxyURL != nil else {
            throw ClaudeShortTextError.missingProxy
        }
        let combined = """
        \(system)

        ---
        User request (follow instructions above; max_tokens intent: ~\(maxTokens)):

        \(user)
        """
        let messages: [[String: String]] = [
            ["role": "user", "content": combined]
        ]
        let raw = try await ClaudeProxyClient.send(
            messages: messages,
            petName: "Petpal",
            petSpecies: "Pet",
            petContext: ""
        )
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// JSON-only extraction for OCR follow-up flows (certificates, insurance cards).
    static func ocrJSONExtraction(systemPrompt: String, userContent: String, maxTokens: Int = 512) async throws -> String {
        try await post(system: systemPrompt, user: userContent, maxTokens: maxTokens)
    }

    /// Monthly recap one-liner (max ~14 words).
    static func monthlyRecapLine(
        petName: String,
        monthName: String,
        vetVisits: Int,
        milestones: Int,
        manualWalks: Int,
        manualMiles: Double
    ) async throws -> String {
        let system = """
        Write one short, fun, warm sentence (max 14 words) summarizing \(petName)'s \(monthName). Based on: \(vetVisits) vet visits, \(milestones) milestones, \(manualWalks) walks with \(petName) (\(String(format: "%.1f", manualMiles)) miles). Make it playful and specific to the month. Return the sentence only, no quotes.
        """
        return try await post(system: system, user: "Write it now.", maxTokens: 96)
    }

    /// Year personality one-liner (max ~15 words).
    static func yearPersonalityLine(
        petName: String,
        breed: String,
        vetVisits: Int,
        walksWithPet: Int,
        milesWithPet: Double,
        milestones: Int
    ) async throws -> String {
        let system = """
        You are a witty pet personality writer. In one sentence (max 15 words), describe the personality of a \(breed) named \(petName) based on this year: \(vetVisits) vet visits, \(walksWithPet) walks with \(petName) (\(String(format: "%.1f", milesWithPet)) miles with them), \(milestones) milestones celebrated. Be charming, warm, and specific. Return the sentence only, no quotes.
        """
        return try await post(system: system, user: "Write it now.", maxTokens: 96)
    }

    /// Six-word headline for the year.
    static func yearHeadline(petName: String, year: Int) async throws -> String {
        let system = """
        Write a 6-word headline summarizing \(petName)'s \(year). Fun, punchy, and celebratory. No hashtags. Return only the headline, nothing else.
        """
        let raw = try await post(system: system, user: "Headline only.", maxTokens: 48)
        return raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

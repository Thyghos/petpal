// APIConfiguration.swift
// Petpal - API Configuration

import Foundation

/// Configuration for external API services
struct APIConfiguration {
    static let defaultVetAIProxyURL = "https://petpal-vet-ai-proxy.sollunaghost.workers.dev/v1/vet-chat"

    // MARK: - AI (Vet assistant)

    /// Anthropic API key.
    /// Resolution order:
    /// 1) User-entered key in Settings (`USER_CLAUDE_API_KEY`)
    /// 2) Info.plist `Claude_API_Key` / `Claude_API-Key`
    static var anthropicAPIKey: String? {
        userDefaultsString("USER_CLAUDE_API_KEY")
            ?? plistString("Claude_API_Key")
            ?? plistString("Claude_API-Key")
    }

    /// Google Gemini API key.
    /// Resolution order:
    /// 1) User-entered key in Settings (`USER_GEMINI_API_KEY`)
    /// 2) Info.plist `GEMINI_API_KEY`
    static var geminiAPIKey: String? {
        userDefaultsString("USER_GEMINI_API_KEY")
            ?? plistString("GEMINI_API_KEY")
    }

    /// Optional backend proxy endpoint for Vet AI.
    /// Resolution order:
    /// 1) User-entered URL in Settings (`USER_VET_AI_PROXY_URL`)
    /// 2) Info.plist `VET_AI_PROXY_URL`
    static var vetAIProxyURL: String? {
        normalizeProxyURL(vetAIProxyURLRaw)
    }

    /// Raw proxy URL before normalization/validation.
    static var vetAIProxyURLRaw: String? {
        userDefaultsString("USER_VET_AI_PROXY_URL")
            ?? plistString("VET_AI_PROXY_URL")
            ?? defaultVetAIProxyURL
    }

    /// True when a proxy value exists but cannot be normalized into a URL.
    static var hasInvalidVetAIProxyURL: Bool {
        guard let raw = vetAIProxyURLRaw else { return false }
        return normalizeProxyURL(raw) == nil
    }

    /// Optional shared token sent as `Authorization: Bearer <token>` to proxy.
    /// Resolution order:
    /// 1) User-entered token in Settings (`USER_VET_AI_PROXY_TOKEN`)
    /// 2) Info.plist `VET_AI_PROXY_TOKEN`
    static var vetAIProxyToken: String? {
        userDefaultsString("USER_VET_AI_PROXY_TOKEN")
            ?? plistString("VET_AI_PROXY_TOKEN")
    }

    /// Ensures a usable default proxy URL exists in user defaults for first-run and migrated users.
    static func ensureDefaultVetAIProxyURLSeeded() {
        let key = "USER_VET_AI_PROXY_URL"
        let existing = UserDefaults.standard.string(forKey: key) ?? ""
        let trimmed = existing.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("https://your-worker.workers.dev") {
            UserDefaults.standard.set(defaultVetAIProxyURL, forKey: key)
        }
    }

    private static func normalizedNonPlaceholderString(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("YOUR_") else { return nil }
        return trimmed
    }

    private static func plistString(_ key: String) -> String? {
        normalizedNonPlaceholderString(Bundle.main.object(forInfoDictionaryKey: key) as? String)
    }

    private static func userDefaultsString(_ key: String) -> String? {
        normalizedNonPlaceholderString(UserDefaults.standard.string(forKey: key))
    }

    private static func normalizeProxyURL(_ raw: String?) -> String? {
        guard var raw = normalizedNonPlaceholderString(raw) else { return nil }
        // Common paste mistakes from rich text/messages.
        raw = raw
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: " ", with: "")

        if !raw.contains("://") {
            raw = "https://\(raw)"
        }

        guard var components = URLComponents(string: raw),
              let host = components.host,
              !host.isEmpty else { return nil }

        let path = components.path
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()

        if path.isEmpty {
            components.path = "/v1/vet-chat"
        } else if path != "v1/vet-chat" {
            // If a user pasted a base URL or wrong path, standardize to the expected endpoint.
            components.path = "/v1/vet-chat"
        }

        return components.url?.absoluteString
    }

    // MARK: - Feedback (home screen)

    /// Optional: set `FEEDBACK_URL` in Info.plist to a Google Form / web page. If set, it is used instead of email.
    static var feedbackWebURL: URL? {
        guard let s = plistString("FEEDBACK_URL") else { return nil }
        return URL(string: s)
    }

    /// Inbox for feature requests via Mail. Override with Info.plist `FEEDBACK_EMAIL`, or set `feedbackEmailFallback` below.
    static var feedbackEmailAddress: String {
        if let s = plistString("FEEDBACK_EMAIL") { return s }
        let trimmed = feedbackEmailFallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    /// Replace with your real support address if you do not use Info.plist `FEEDBACK_EMAIL`.
    private static let feedbackEmailFallback = ""

    /// Opens a web form, or `mailto:` with a prefilled subject and body for feature ideas.
    static func feedbackFeatureURL() -> URL? {
        if let web = feedbackWebURL { return web }
        let email = feedbackEmailAddress
        guard !email.isEmpty else { return nil }
        let subject = "Petpal — feature idea"
        let body = """
        Hi Petpal team,

        Here’s what I’d love to see in Petpal:


        """
        guard var components = URLComponents(string: "mailto:\(email)") else { return nil }
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        return components.url
    }
}

/*
 GEMINI (AI Vet):
    a. Open https://aistudio.google.com/apikey and sign in with Google.
    b. Create an API key. In Xcode target Info, add GEMINI_API_KEY (String).
    c. If both Claude_API_Key and GEMINI_API_KEY are set, the app prefers Claude.
    d. Model IDs: https://ai.google.dev/gemini-api/docs/models
 */

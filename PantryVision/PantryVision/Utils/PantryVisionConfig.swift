import Foundation

enum PantryVisionConfig {
    /// Example: `https://us-central1-YOUR_PROJECT.cloudfunctions.net`
    static var cloudFunctionsBaseURL: URL? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "CLOUD_FUNCTIONS_BASE_URL") as? String else {
            return nil
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed)
    }

    static var languageCode: String {
        // Keep it simple for MVP.
        "en"
    }
}


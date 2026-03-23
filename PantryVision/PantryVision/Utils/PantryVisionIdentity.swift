import Foundation

enum PantryVisionIdentity {
    private static let displayNameKey = "pantryvision_display_name"

    static var displayName: String {
        let name = UserDefaults.standard.string(forKey: displayNameKey)
        return (name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? name!.trimmingCharacters(in: .whitespacesAndNewlines)
            : "You"
    }

    static func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmed.isEmpty ? "You" : trimmed, forKey: displayNameKey)
    }
}


import SwiftUI

enum PantryVisionTheme {
    // "Fresh Pantry" palette (MVP branding).
    static let background = Color(hex: "#FFF7F1")
    static let card = Color(hex: "#FFFFFF")
    static let textPrimary = Color(hex: "#0F172A") // slate-900
    static let textSecondary = Color(hex: "#64748B") // slate-500
    static let accent = Color(hex: "#16C5B4") // teal-mint
    static let accent2 = Color(hex: "#4F46E5") // indigo-600
}

extension Color {
    init(hex: String, opacity: Double = 1.0) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }

        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)

        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}


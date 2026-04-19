// Reusable Petpal logo + wordmark for shareable cards (ImageRenderer-safe).

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - App icon (heart + paw from asset catalog)

/// Rounded square matching the on-device Petpal app icon (`PetpalAppIcon` imageset).
/// Use this anywhere card exports or UI should show the real logo, not a generic paw SF Symbol.
struct PetpalAppIconThumbnail: View {
    var size: CGFloat

    var body: some View {
        Group {
            #if canImport(UIKit)
            if UIImage(named: "PetpalAppIcon") != nil {
                Image("PetpalAppIcon")
                    .resizable()
                    .scaledToFill()
            } else if UIImage(named: "AppIcon") != nil {
                Image("AppIcon")
                    .resizable()
                    .scaledToFill()
            } else {
                petpalIconSFallback
            }
            #else
            petpalIconSFallback
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }

    /// Approximates the icon (heart motif + paw) when the asset isn’t in the bundle.
    private var petpalIconSFallback: some View {
        ZStack {
            Image(systemName: "heart.circle.fill")
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.palette)
                .foregroundStyle(
                    Color(hex: "E8622A"),
                    Color(hex: "4A90D9")
                )
            Image(systemName: "pawprint.fill")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(Color.white)
                .shadow(color: .black.opacity(0.15), radius: 1, x: 0, y: 0.5)
        }
        .padding(size * 0.02)
    }
}

// MARK: - Wordmark

struct PetpalBrandMark: View {
    var size: CGFloat = 24
    var style: BrandMarkStyle = .darkBackground

    enum BrandMarkStyle {
        case darkBackground
        case lightBackground
    }

    var body: some View {
        HStack(spacing: size * 0.2) {
            PetpalAppIconThumbnail(size: size)

            Text("Petpal")
                .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
        }
    }

    private var textColor: Color {
        switch style {
        case .darkBackground:
            return .white
        case .lightBackground:
            return Color(hex: "E8622A")
        }
    }
}

// MARK: - “Made with Petpal App” line (export cards on light background)

struct MadeWithPetpalAppAttribution: View {
    var iconSize: CGFloat
    var textSize: CGFloat
    var textColor: Color

    var body: some View {
        HStack(spacing: iconSize * 0.22) {
            PetpalAppIconThumbnail(size: iconSize)
            Text("Made with Petpal App")
                .font(.system(size: textSize, weight: .semibold, design: .rounded))
                .foregroundStyle(textColor)
        }
    }
}

// MilestoneCardView.swift
// Instagram Story–sized (1080×1920) share card — full-bleed photo or layered gradient; fixed colors for export.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)

/// Non-interactive artboard for sharing / `ImageRenderer`.
struct MilestoneCardView: View {
    let pet: Pet
    let milestone: MilestoneType
    let record: MilestoneRecord
    /// Full-bleed background; when `nil`, uses pet profile image then type gradient.
    let selectedPhoto: UIImage?

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var layoutScale: CGFloat { max(w / 1080, 0.001) }

    private var displayPetName: String {
        let n = pet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return n.isEmpty ? "Your Pet" : n
    }

    private var backgroundUIImage: UIImage? {
        if let selectedPhoto { return selectedPhoto }
        if let d = pet.profileImage, !d.isEmpty, let ui = UIImage(data: d) { return ui }
        return nil
    }

    private var hasFullBleedPhoto: Bool {
        backgroundUIImage != nil
    }

    private var headline: String {
        if milestone == .custom {
            let t = record.customCardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return t.isEmpty ? "Custom moment" : t
        }
        return milestone.replacingPetName(displayPetName, in: milestone.cardTitle)
    }

    private var statLine: String {
        if milestone == .custom {
            return record.funStatLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        if let s = record.funStatLine, !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return s
        }
        return MilestoneCardView.fallbackStatLine(for: milestone, petName: displayPetName)
    }

    static func fallbackStatLine(for milestone: MilestoneType, petName: String) -> String {
        switch milestone {
        case .birthday:
            return "Celebrating another wonderful year with \(petName)."
        case .adoptionAnniversary:
            return "So glad \(petName) found their forever home."
        case .firstVetVisit:
            return "Great job staying on top of \(petName)'s care."
        case .healthyVetVisit:
            return "Wonderful news — \(petName) is thriving."
        case .vaccinesUpToDate:
            return "\(petName) is protected and ready for adventure."
        case .oneYearInPetpal:
            return "Thanks for letting Petpal be part of the journey."
        case .custom:
            return ""
        }
    }

    private var triggeredDateFormatted: String {
        record.triggeredDate.formatted(.dateTime.month(.wide).day().year())
    }

    var body: some View {
        let _ = displayScale
        ZStack {
            backgroundLayer

            if hasFullBleedPhoto {
                photoOverlays
            } else {
                noPhotoOverlays
            }

            if !hasFullBleedPhoto {
                milestonePhotoCircle
            }

            bottomScrimContent
        }
        .frame(width: w, height: h)
        .clipped()
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if hasFullBleedPhoto, let ui = backgroundUIImage {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
        } else {
            ZStack {
                Color(hex: "0a0a1a")
                LinearGradient(
                    colors: [
                        Color(hex: "E8622A").opacity(0.55),
                        Color(hex: "C0392B").opacity(0.5),
                        Color(hex: "8E44AD").opacity(0.45)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: w, height: h)
        }
    }

    private var photoOverlays: some View {
        ZStack {
            RadialGradient(
                colors: [Color.clear, Color.black.opacity(0.3)],
                center: .center,
                startRadius: w * 0.15,
                endRadius: w * 1.1
            )
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.82)],
                    startPoint: UnitPoint(x: 0.5, y: 0.3),
                    endPoint: .bottom
                )
                .frame(height: h * 0.7)
            }
        }
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }

    private var noPhotoOverlays: some View {
        Color.clear
            .frame(width: w, height: h)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var milestonePhotoCircle: some View {
        let diameter = w * 0.38
        ZStack {
            Circle()
                .strokeBorder(Color(hex: "E8622A").opacity(0.3), lineWidth: 2 * layoutScale)
                .frame(width: diameter + 8 * layoutScale, height: diameter + 8 * layoutScale)
            Group {
                if let ui = backgroundUIImage {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        LinearGradient(
                            colors: [Color("BrandOrange"), Color("BrandBlue")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: diameter * 0.28, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.95))
                    }
                }
            }
            .frame(width: diameter, height: diameter)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(Color.white, lineWidth: 3 * layoutScale)
            )
        }
        .position(x: w / 2, y: h * 0.27)
        .allowsHitTesting(false)
    }

    private var bottomScrimContent: some View {
        ZStack {
            Text(headline)
                .font(.system(size: w * 0.085, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .lineSpacing(-2 * layoutScale)
                .minimumScaleFactor(0.82)
                .shadow(color: Color.black.opacity(0.6), radius: 8 * layoutScale, x: 0, y: 2)
                .frame(maxWidth: w * 0.9)
                .position(x: w / 2, y: h * 0.655)

            Group {
                if !statLine.isEmpty {
                    Text(statLine)
                        .font(.system(size: w * 0.034, weight: .regular, design: .rounded))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.88))
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.4), radius: 4 * layoutScale, x: 0, y: 1)
                        .frame(maxWidth: w * 0.86)
                }
            }
            .position(x: w / 2, y: h * 0.755)

            Text(triggeredDateFormatted)
                .font(.system(size: w * 0.022, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14 * layoutScale)
                .padding(.vertical, 8 * layoutScale)
                .background(
                    RoundedRectangle(cornerRadius: 12 * layoutScale, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
                .position(x: w / 2, y: h * 0.825)

            HStack(spacing: 20 * layoutScale) {
                ForEach(0..<3, id: \.self) { _ in
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: w * 0.05))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }
            .position(x: w / 2, y: h * 0.870)

            milestoneCreatedWithPetpalFooter(centerY: h * 0.935)
        }
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }

    /// Bottom attribution: app icon + “Created with Petpal” (no top wordmark on this card).
    private func milestoneCreatedWithPetpalFooter(centerY: CGFloat) -> some View {
        HStack(spacing: w * 0.018) {
            PetpalAppIconThumbnail(size: w * 0.048)
            Text("Created with Petpal")
                .font(.system(size: w * 0.022, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .padding(.horizontal, 16 * layoutScale)
        .padding(.vertical, 6 * layoutScale)
        .background(
            Capsule(style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
        .position(x: w / 2, y: centerY)
    }
}

enum MilestoneCardRenderer {
    @MainActor
    static func snapshot(
        pet: Pet,
        milestone: MilestoneType,
        record: MilestoneRecord,
        selectedPhoto: UIImage?,
        displayScale: CGFloat
    ) -> UIImage? {
        let content = MilestoneCardView(
            pet: pet,
            milestone: milestone,
            record: record,
            selectedPhoto: selectedPhoto,
            displayWidth: 1080,
            displayHeight: 1920
        )
        .environment(\.displayScale, displayScale)
        .frame(width: 1080, height: 1920)
        let renderer = ImageRenderer(content: content)
        let scale = max(displayScale, 3.0)
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
        return renderer.uiImage
    }
}
#endif

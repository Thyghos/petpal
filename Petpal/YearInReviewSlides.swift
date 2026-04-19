// Year in Review slide artboards (1080×1920) — fixed colors for ImageRenderer.

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)

// MARK: - Slide 1 — Cover

struct YearInReviewSlide1Cover: View {
    let petName: String
    let year: Int
    let yearHeadline: String
    let backgroundPhoto: UIImage?

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var ls: CGFloat { max(w / 1080, 0.001) }

    var body: some View {
        let _ = displayScale
        ZStack {
            slide1CoverLayers
        }
        .frame(width: w, height: h)
        .clipped()
    }

    /// Split from `body` for faster type-checking (large ZStacks compile slowly).
    @ViewBuilder
    private var slide1CoverLayers: some View {
        Color(hex: "0a0a0a")

        Text(String(year))
            .font(.system(size: w * 0.28, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.06))
            .position(x: w / 2, y: h * 0.50)

        slide1HeroColumn

        LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.97)],
            startPoint: UnitPoint(x: 0.5, y: 0.35),
            endPoint: .bottom
        )
        .frame(width: w, height: h)
        .allowsHitTesting(false)

        PetpalBrandMark(size: w * 0.055, style: .darkBackground)
            .opacity(0.75)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, w * 0.05)
            .padding(.top, h * 0.04)

        if backgroundPhoto == nil {
            yirPetCircle(photo: nil, diameter: w * 0.32, layoutScale: ls)
                .position(x: w / 2, y: h * 0.32)
        }

        Text("\(petName)'s")
            .font(.system(size: w * 0.055, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.75))
            .position(x: w / 2, y: h * 0.625)

        Text("Year in Review")
            .font(.system(size: w * 0.095, weight: .black, design: .rounded))
            .foregroundStyle(Color.white)
            .shadow(color: Color.black.opacity(0.8), radius: 10 * ls, x: 0, y: 3)
            .position(x: w / 2, y: h * 0.695)

        Text(yearHeadline)
            .font(.system(size: w * 0.034, weight: .regular, design: .rounded))
            .italic()
            .foregroundStyle(Color.white.opacity(0.70))
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.8)
            .frame(width: w * 0.88)
            .position(x: w / 2, y: h * 0.760)

        exportBrandingFooterDark(centerY: h * 0.935, layoutScale: ls, displayWidth: w)
    }

    private var slide1HeroColumn: some View {
        VStack(spacing: 0) {
            Group {
                if let bg = backgroundPhoto {
                    Image(uiImage: bg)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Color(hex: "E8622A"),
                            Color(hex: "C0392B"),
                            Color(hex: "8E44AD"),
                            Color(hex: "2C3E50")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
            .frame(width: w, height: h * 0.65)
            .clipped()

            Spacer(minLength: 0)
        }
        .frame(width: w, height: h, alignment: .top)
    }
}

// MARK: - Slide 2 — Activity

struct YearInReviewSlide2Activity: View {
    let petName: String
    let year: Int
    let isAppleHealthConnected: Bool
    let totalActivityMiles: Double
    let totalMilesWithPet: Double
    let totalSteps: Int
    let totalActiveMinutes: Int
    var settings: YearInReviewCustomSettings = YearInReviewCustomSettings()

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var ls: CGFloat { max(w / 1080, 0.001) }

    private var activityComparisonLine: String {
        if totalActivityMiles >= 100 {
            return "That’s a big year of movement — keep exploring."
        }
        if totalActivityMiles >= 20 {
            return "Plenty of distance from everyday walks and runs in Health."
        }
        return "Every bit of motion adds up — nice work staying active."
    }

    private var wantsAppleHealthUI: Bool {
        settings.showAppleHealthActivity || settings.showActiveMinutes
    }

    private var hasActivityContent: Bool {
        settings.showManualWalks
            || (isAppleHealthConnected && wantsAppleHealthUI)
            || (!isAppleHealthConnected && wantsAppleHealthUI)
    }

    var body: some View {
        let _ = displayScale
        ZStack {
            slide2ActivityLayers
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private var slide2ActivityLayers: some View {
        LinearGradient(
            colors: [Color(hex: "0a0a2e"), Color(hex: "1a0a40")],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: w, height: h)

        Text(String(year))
            .font(.system(size: w * 0.28, weight: .black, design: .rounded))
            .foregroundStyle(Color(hex: "4A90D9").opacity(0.05))
            .position(x: w / 2, y: h * 0.50)

        Text("You & \(petName)")
            .font(.system(size: w * 0.06, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white)
            .position(x: w / 2, y: h * 0.12)

        Text("in \(String(year))")
            .font(.system(size: w * 0.038, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.7))
            .position(x: w / 2, y: h * 0.175)

        activityCenterBlock
            .frame(width: w * 0.92)
            .position(x: w / 2, y: h * 0.46)

        if hasActivityContent && (settings.showManualWalks || (isAppleHealthConnected && wantsAppleHealthUI)) {
            Text(activityComparisonLine)
                .font(.system(size: w * 0.028, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
                .frame(width: w * 0.85)
                .position(x: w / 2, y: h * 0.72)
        }

        exportBrandingFooterDark(centerY: h * 0.935, layoutScale: ls, displayWidth: w)
    }

    @ViewBuilder
    private var activityCenterBlock: some View {
        if !hasActivityContent {
            Text("Choose activity stats in Customize to fill this slide.")
                .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.72))
                .frame(width: w * 0.82)
        } else {
            VStack(spacing: h * 0.028) {
                if settings.showManualWalks {
                    VStack(spacing: h * 0.012) {
                        Text(String(format: "%.1f", totalMilesWithPet))
                            .font(.system(size: w * 0.22, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("miles with \(petName)")
                            .font(.system(size: w * 0.038, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }

                if isAppleHealthConnected && wantsAppleHealthUI {
                    VStack(spacing: h * 0.018) {
                        if settings.showAppleHealthActivity || settings.showActiveMinutes {
                            HStack(spacing: 12 * ls) {
                                if settings.showAppleHealthActivity {
                                    yirFrostTextPill("\(totalSteps) steps", ls: ls, w: w)
                                }
                                if settings.showActiveMinutes {
                                    yirFrostTextPill("\(totalActiveMinutes) active min", ls: ls, w: w)
                                }
                            }
                        }
                        if settings.showAppleHealthActivity {
                            Text("General activity via Apple Health")
                                .font(.system(size: w * 0.024, weight: .medium, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }
                    }
                } else if !isAppleHealthConnected && wantsAppleHealthUI {
                    VStack(spacing: 16 * ls) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: w * 0.1))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Text("Connect Apple Health to see steps, distance, and active minutes from this iPhone.")
                            .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.88))
                            .frame(width: w * 0.82)
                    }
                }
            }
        }
    }
}

private func yirFrostTextPill(_ text: String, ls: CGFloat, w: CGFloat) -> some View {
    Text(text)
        .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
        .foregroundStyle(Color.white)
        .padding(.vertical, 10 * ls)
        .padding(.horizontal, 14 * ls)
        .background(
            RoundedRectangle(cornerRadius: 12 * ls, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
}

// MARK: - Slide 3 — Health

struct YearInReviewSlide3Health: View {
    let vetVisits: Int
    let vaccinesCompleted: Int
    let weightChangeText: String?
    let medicationsLogged: Int
    var healthReportGrade: String?
    var settings: YearInReviewCustomSettings = YearInReviewCustomSettings()

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var ls: CGFloat { max(w / 1080, 0.001) }

    private var hasWeightToShow: Bool {
        guard settings.showWeightChange, let t = weightChangeText?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else {
            return false
        }
        return true
    }

    private var hasHealthContent: Bool {
        settings.showVetVisits
            || settings.showVaccines
            || hasWeightToShow
            || settings.showMedications
    }

    var body: some View {
        let _ = displayScale
        ZStack {
            slide3HealthLayers
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private var slide3HealthLayers: some View {
        LinearGradient(
            colors: [Color(hex: "0a1f0a"), Color(hex: "1a4a1a")],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: w, height: h)

        Text("Health Highlights")
            .font(.system(size: w * 0.068, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .position(x: w / 2, y: h * 0.10)

        healthStack
            .frame(width: w * 0.9)
            .position(x: w / 2, y: h * 0.48)

        exportBrandingFooterDark(centerY: h * 0.935, layoutScale: ls, displayWidth: w)
    }

    @ViewBuilder
    private var healthStack: some View {
        if !hasHealthContent {
            Text("Choose health stats in Customize to fill this slide.")
                .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.72))
        } else {
            VStack(spacing: h * 0.04) {
                if settings.showVetVisits {
                    VStack(spacing: h * 0.012) {
                        Text("\(vetVisits)")
                            .font(.system(size: w * 0.18, weight: .black, design: .rounded))
                            .foregroundStyle(Color.white)
                        Text("vet visits this year")
                            .font(.system(size: w * 0.034, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }

                if settings.showVaccines || hasWeightToShow {
                    HStack(spacing: 12 * ls) {
                        if settings.showVaccines {
                            yirFrostTextPill("\(vaccinesCompleted) vaccines", ls: ls, w: w)
                        }
                        if hasWeightToShow {
                            weightPill
                        }
                    }
                }

                if settings.showMedications {
                    VStack(spacing: 8 * ls) {
                        Text("\(medicationsLogged) medication reminders")
                            .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.85))
                        if let g = healthReportGrade, !g.isEmpty {
                            Text("Latest grade: \(g.prefix(1))")
                                .font(.system(size: w * 0.038, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.white.opacity(0.9))
                        }
                    }
                }
            }
        }
    }

    private var weightPill: some View {
        let txt = weightChangeText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let arrow: String = {
            guard let t = weightChangeText else { return "→" }
            if t.hasPrefix("+") { return "↑" }
            if t.hasPrefix("-") { return "↓" }
            return "→"
        }()
        return HStack(spacing: 8) {
            Text(arrow)
                .font(.system(size: w * 0.06, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.9))
            Text(txt)
                .font(.system(size: w * 0.028, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white)
        }
        .padding(.vertical, 10 * ls)
        .padding(.horizontal, 14 * ls)
        .background(
            RoundedRectangle(cornerRadius: 12 * ls, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
    }
}

// MARK: - Slide 4 — Moments

struct YearInReviewSlide4Moments: View {
    let monthThumbnails: [Int: UIImage]
    let milestonesCount: Int
    /// Optional line between the grid and milestone row (user caption and/or stats summary).
    var momentsLine: String? = nil
    var settings: YearInReviewCustomSettings = YearInReviewCustomSettings()

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var ls: CGFloat { max(w / 1080, 0.001) }

    private static let monthAbbrevs = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    private var trimmedMomentsLine: String? {
        let t = momentsLine?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? nil : t
    }

    private var hasCaptionLine: Bool { trimmedMomentsLine != nil }

    private var milestoneRowY: CGFloat { hasCaptionLine ? h * 0.87 : h * 0.84 }

    var body: some View {
        let _ = displayScale
        ZStack {
            slide4MomentsLayers
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private var slide4MomentsLayers: some View {
        LinearGradient(
            colors: [Color(hex: "1f0a00"), Color(hex: "4a1a00")],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(width: w, height: h)

        Text("Moments & Milestones")
            .font(.system(size: w * 0.062, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white)
            .position(x: w / 2, y: h * 0.08)

        if settings.showMonthlyPhotoGrid {
            yearMomentsGrid
                .position(x: w / 2, y: h * 0.44)
        }

        if let line = trimmedMomentsLine {
            Text(line)
                .font(.system(size: w * 0.030, weight: .regular, design: .rounded))
                .italic()
                .foregroundStyle(Color.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .frame(width: w * 0.88)
                .position(x: w / 2, y: h * 0.76)
        }

        if settings.showMilestones {
            HStack(spacing: 10 * ls) {
                Image(systemName: "star.fill")
                    .font(.system(size: w * 0.038))
                    .foregroundStyle(Color(hex: "E8622A"))
                Text("\(milestonesCount) milestone\(milestonesCount == 1 ? "" : "s")")
                    .font(.system(size: w * 0.040, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .position(x: w / 2, y: milestoneRowY)
        }

        exportBrandingFooterDark(centerY: h * 0.935, layoutScale: ls, displayWidth: w)
    }

    private var yearMomentsGrid: some View {
        let m = momentsGridMetrics()
        return VStack(spacing: m.gap) {
            ForEach(0..<4, id: \.self) { row in
                HStack(spacing: m.gap) {
                    ForEach(0..<3, id: \.self) { col in
                        let month = row * 3 + col + 1
                        monthCell(month: month, cellS: m.cellS, labelH: m.labelH, innerLabelGap: m.innerLabelGap, corner: 6 * ls)
                            .frame(width: (m.gridW - 2 * m.gap) / 3, alignment: .center)
                    }
                }
            }
        }
        .frame(width: m.gridW, height: min(m.totalGridH, m.gridH))
        .clipShape(RoundedRectangle(cornerRadius: 12 * ls, style: .continuous))
    }

    private func momentsGridMetrics() -> (gridW: CGFloat, gridH: CGFloat, gap: CGFloat, labelH: CGFloat, innerLabelGap: CGFloat, cellS: CGFloat, totalGridH: CGFloat) {
        let gridW = w * 0.86
        let gridH = h * 0.38
        let gap: CGFloat = 4 * ls
        let labelH = w * 0.022
        let innerLabelGap: CGFloat = 3 * ls
        var cellS = (gridW - 2 * gap) / 3
        var rowContentH = cellS + innerLabelGap + labelH
        var totalGridH = 4 * rowContentH + 3 * gap
        if totalGridH > gridH {
            let scale = gridH / totalGridH
            cellS *= scale
            rowContentH = cellS + innerLabelGap + labelH
            totalGridH = 4 * rowContentH + 3 * gap
        }
        return (gridW, gridH, gap, labelH, innerLabelGap, cellS, totalGridH)
    }

    private func monthCell(month: Int, cellS: CGFloat, labelH: CGFloat, innerLabelGap: CGFloat, corner: CGFloat) -> some View {
        let abbrev = Self.monthAbbrevs[month - 1]
        return VStack(spacing: innerLabelGap) {
            if let img = monthThumbnails[month] {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cellS, height: cellS)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
                Text(abbrev)
                    .font(.system(size: w * 0.018, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .frame(height: labelH)
            } else {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: cellS, height: cellS)
                Color.clear.frame(height: labelH)
            }
        }
    }
}

// MARK: - Slide 5 — Personality

struct YearInReviewSlide5Personality: View {
    let petName: String
    let year: Int
    let personalityLine: String
    let petPhoto: UIImage?

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1920

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var ls: CGFloat { max(w / 1080, 0.001) }

    var body: some View {
        let _ = displayScale
        ZStack {
            slide5PersonalityLayers
        }
        .frame(width: w, height: h)
    }

    @ViewBuilder
    private var slide5PersonalityLayers: some View {
        Group {
            if let p = petPhoto {
                Image(uiImage: p)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(hex: "1a0a00"), Color(hex: "E8622A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(width: w, height: h)
        .clipped()

        Color.black.opacity(0.75)
            .frame(width: w, height: h)

        yirPetCircle(photo: petPhoto, diameter: 200 * ls, layoutScale: ls)
            .position(x: w / 2, y: h * 0.22)

        Text(personalityLine)
            .font(.system(size: w * 0.052, weight: .semibold, design: .rounded))
            .italic()
            .foregroundStyle(Color.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.82)
            .shadow(color: Color.black.opacity(0.6), radius: 6 * ls, x: 0, y: 2)
            .frame(width: w * 0.88)
            .position(x: w / 2, y: h * 0.52)

        Text("Another year together.")
            .font(.system(size: w * 0.038, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.78))
            .position(x: w / 2, y: h * 0.70)

        Text(String(year))
            .font(.system(size: w * 0.068, weight: .black, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.9))
            .position(x: w / 2, y: h * 0.78)

        exportBrandingFooterDark(centerY: h * 0.935, layoutScale: ls, displayWidth: w)
    }
}

@ViewBuilder
private func yirPetCircle(photo: UIImage?, diameter: CGFloat, layoutScale ls: CGFloat) -> some View {
    ZStack {
        Circle()
            .strokeBorder(Color(hex: "E8622A").opacity(0.35), lineWidth: 2 * ls)
            .frame(width: diameter + 10 * ls, height: diameter + 10 * ls)
        Group {
            if let p = photo {
                Image(uiImage: p)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.white.opacity(0.25))
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: diameter * 0.28, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.85), lineWidth: 3 * ls))
    }
}

#endif

// 4:5 monthly recap artboard (1080×1350) — fixed colors for ImageRenderer.

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
struct MonthlyRecapCardView: View {
    let petName: String
    let monthTitle: String
    let month: Int
    let year: Int
    let photoImages: [UIImage]
    let oneLiner: String
    let vetVisits: Int
    let milestoneRecords: [MilestoneRecord]
    let manualWalksCount: Int
    let manualWalksMiles: Double
    var personalNote: String? = nil

    var displayWidth: CGFloat = 1080
    var displayHeight: CGFloat = 1350

    @Environment(\.displayScale) private var displayScale

    private var w: CGFloat { displayWidth }
    private var h: CGFloat { displayHeight }
    private var layoutScale: CGFloat { max(w / 1080, 0.001) }

    private var manualMilesFormatted: String {
        String(format: "%.1f", manualWalksMiles)
    }

    private var yearString: String {
        String(year)
    }

    private var hasPhotos: Bool {
        !photoImages.isEmpty
    }

    private var trimmedPersonalNote: String? {
        guard let n = personalNote?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty else { return nil }
        return n
    }

    private var statsRowY: CGFloat {
        trimmedPersonalNote != nil ? h * 0.820 : h * 0.795
    }

    /// Collage frame: wide landscape tile; height tied to artboard width for consistent proportions.
    private var collageFrameWidth: CGFloat { w * 0.90 }
    private var collageFrameHeight: CGFloat { w * 0.72 }

    var body: some View {
        let _ = displayScale
        ZStack {
            monthlyRecapLayers
        }
        .frame(width: w, height: h)
        .clipped()
    }

    /// Split from `body` — large ZStacks are the main driver of slow SwiftUI type-checking.
    @ViewBuilder
    private var monthlyRecapLayers: some View {
        backgroundLayer

        if hasPhotos, let first = photoImages.first {
            monthlyPhotoBackdrop(first)
        }

        if !hasPhotos {
            noPhotoTexture
        }

        collageBlock
            .frame(width: collageFrameWidth, height: collageFrameHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16 * layoutScale, style: .continuous))
            .position(x: w * 0.50, y: h * 0.28)

        recapWordmark

        monthlyTitleBlock

        monthlySubtitleAndOneLiner

        if let note = trimmedPersonalNote {
            personalNoteText(note)
        }

        statsRow
            .position(x: w / 2, y: statsRowY)

        exportBrandingFooterDark(centerY: h * 0.945, layoutScale: layoutScale, displayWidth: w)
    }

    private func monthlyPhotoBackdrop(_ first: UIImage) -> some View {
        ZStack {
            Image(uiImage: first)
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
            Color(hex: "8B2500").opacity(0.45)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(
                    colors: [Color.clear, Color(hex: "2C1810").opacity(0.93)],
                    startPoint: UnitPoint(x: 0.5, y: 0.35),
                    endPoint: .bottom
                )
                .frame(height: h * 0.65)
            }
        }
    }

    private var monthlyTitleBlock: some View {
        Text("\(monthTitle) \(yearString)")
            .font(.system(size: w * 0.11, weight: .black, design: .rounded))
            .foregroundStyle(Color.white)
            .shadow(color: Color.black.opacity(0.5), radius: 6 * layoutScale, x: 0, y: 2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: w * 0.92)
            .position(x: w / 2, y: h * 0.57)
    }

    private var monthlySubtitleAndOneLiner: some View {
        Group {
            Text("\(petName)'s highlights")
                .font(.system(size: w * 0.042, weight: .regular, design: .rounded))
                .italic()
                .foregroundStyle(Color.white.opacity(0.82))
                .position(x: w / 2, y: h * 0.638)

            Text(oneLiner)
                .font(.system(size: w * 0.030, weight: .regular, design: .rounded))
                .italic()
                .foregroundStyle(Color.white.opacity(0.78))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: w * 0.88)
                .position(x: w / 2, y: h * 0.700)
        }
    }

    private func personalNoteText(_ note: String) -> some View {
        Text(note)
            .font(.system(size: w * 0.028, weight: .regular, design: .rounded))
            .italic()
            .foregroundStyle(Color.white.opacity(0.85))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.82)
            .frame(width: w * 0.88)
            .position(x: w / 2, y: h * 0.752)
    }

    private var backgroundLayer: some View {
        Group {
            if hasPhotos {
                Color.clear
            } else {
                ZStack {
                    Color(hex: "2C1810")
                    LinearGradient(
                        colors: [
                            Color(hex: "E8622A").opacity(0.8),
                            Color(hex: "8B2500").opacity(0.9)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(0.85)
                }
            }
        }
        .frame(width: w, height: h)
    }

    private var noPhotoTexture: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 300 * layoutScale, height: 300 * layoutScale)
                .position(x: w * 0.2, y: h * 0.25)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 200 * layoutScale, height: 200 * layoutScale)
                .position(x: w * 0.78, y: h * 0.45)
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: 150 * layoutScale, height: 150 * layoutScale)
                .position(x: w * 0.5, y: h * 0.7)
        }
        .frame(width: w, height: h)
        .allowsHitTesting(false)
    }

    private var recapWordmark: some View {
        PetpalBrandMark(size: w * 0.055, style: .darkBackground)
            .opacity(0.75)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, w * 0.05)
            .padding(.top, h * 0.04)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var collageBlock: some View {
        /// Callers should pass at most 9 images, newest first.
        let imgs = Array(photoImages.prefix(9))
        let gap: CGFloat = 3 * layoutScale
        let innerR: CGFloat = 6 * layoutScale
        let FW = collageFrameWidth
        let FH = collageFrameHeight

        if imgs.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 16 * layoutScale, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "E8622A").opacity(0.4),
                                Color(hex: "8B2500").opacity(0.55)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                VStack(spacing: 8 * layoutScale) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: w * 0.1))
                        .foregroundStyle(Color.white.opacity(0.9))
                    Text("Add photos for \(monthTitle)")
                        .font(.system(size: w * 0.032, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
            }
        } else if imgs.count == 1 {
            Image(uiImage: imgs[0])
                .resizable()
                .scaledToFill()
                .frame(width: FW, height: FH)
                .clipped()
        } else if imgs.count == 2 {
            HStack(spacing: gap) {
                ForEach(0..<2, id: \.self) { i in
                    collageCellImage(imgs[i], width: (FW - gap) / 2, height: FH, cornerRadius: innerR)
                }
            }
        } else if imgs.count == 3 {
            let innerH = FH - gap
            let topH = innerH * 0.60
            let botH = innerH * 0.40
            VStack(spacing: gap) {
                collageCellImage(imgs[0], width: FW, height: topH, cornerRadius: innerR)
                HStack(spacing: gap) {
                    collageCellImage(imgs[1], width: (FW - gap) / 2, height: botH, cornerRadius: innerR)
                    collageCellImage(imgs[2], width: (FW - gap) / 2, height: botH, cornerRadius: innerR)
                }
            }
        } else if imgs.count <= 6 {
            collageGrid2Columns(imgs: imgs, gap: gap, innerR: innerR, FW: FW, FH: FH)
        } else {
            collageGrid3x3(imgs: imgs, gap: gap, innerR: innerR, FW: FW, FH: FH)
        }
    }

    private func collageCellImage(_ ui: UIImage, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Image(uiImage: ui)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// 4–6 photos: 2 columns; 4 = 2×2, 5 = 2+2+1, 6 = 3×2.
    @ViewBuilder
    private func collageGrid2Columns(imgs: [UIImage], gap: CGFloat, innerR: CGFloat, FW: CGFloat, FH: CGFloat) -> some View {
        let n = imgs.count
        if n == 4 {
            let cellW = (FW - gap) / 2
            let cellH = (FH - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    collageCellImage(imgs[0], width: cellW, height: cellH, cornerRadius: innerR)
                    collageCellImage(imgs[1], width: cellW, height: cellH, cornerRadius: innerR)
                }
                HStack(spacing: gap) {
                    collageCellImage(imgs[2], width: cellW, height: cellH, cornerRadius: innerR)
                    collageCellImage(imgs[3], width: cellW, height: cellH, cornerRadius: innerR)
                }
            }
        } else if n == 5 {
            let rowH = (FH - 2 * gap) / 3
            let cellW = (FW - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    collageCellImage(imgs[0], width: cellW, height: rowH, cornerRadius: innerR)
                    collageCellImage(imgs[1], width: cellW, height: rowH, cornerRadius: innerR)
                }
                HStack(spacing: gap) {
                    collageCellImage(imgs[2], width: cellW, height: rowH, cornerRadius: innerR)
                    collageCellImage(imgs[3], width: cellW, height: rowH, cornerRadius: innerR)
                }
                collageCellImage(imgs[4], width: FW, height: rowH, cornerRadius: innerR)
            }
        } else {
            // 6 photos: 3 rows × 2 columns
            let rowH = (FH - 2 * gap) / 3
            let cellW = (FW - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    collageCellImage(imgs[0], width: cellW, height: rowH, cornerRadius: innerR)
                    collageCellImage(imgs[1], width: cellW, height: rowH, cornerRadius: innerR)
                }
                HStack(spacing: gap) {
                    collageCellImage(imgs[2], width: cellW, height: rowH, cornerRadius: innerR)
                    collageCellImage(imgs[3], width: cellW, height: rowH, cornerRadius: innerR)
                }
                HStack(spacing: gap) {
                    collageCellImage(imgs[4], width: cellW, height: rowH, cornerRadius: innerR)
                    collageCellImage(imgs[5], width: cellW, height: rowH, cornerRadius: innerR)
                }
            }
        }
    }

    /// 7–9 photos: 3×3 grid, equal cells.
    @ViewBuilder
    private func collageGrid3x3(imgs: [UIImage], gap: CGFloat, innerR: CGFloat, FW: CGFloat, FH: CGFloat) -> some View {
        let cellW = (FW - 2 * gap) / 3
        let cellH = (FH - 2 * gap) / 3
        let n = min(imgs.count, 9)
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { col in
                        let idx = row * 3 + col
                        if idx < n {
                            collageCellImage(imgs[idx], width: cellW, height: cellH, cornerRadius: innerR)
                        } else {
                            Color.clear.frame(width: cellW, height: cellH)
                        }
                    }
                }
            }
        }
    }

    private var statsRow: some View {
        ZStack {
            recapStatColumn(
                value: "\(vetVisits)",
                label: "vet visits",
                centerX: w * 0.22
            )
            recapStatColumn(
                value: manualMilesFormatted,
                label: "miles w/ \(petName)",
                centerX: w * 0.50
            )
            recapMilestoneColumn(centerX: w * 0.78)
        }
        .frame(width: w, height: h * 0.14)
    }

    private func recapMilestoneColumn(centerX: CGFloat) -> some View {
        let count = milestoneRecords.count
        let value: String
        let label: String
        if count == 0 {
            value = "0"
            label = "milestones"
        } else if count == 1, let m = milestoneRecords.first {
            value = Self.milestoneDisplayTitle(m)
            label = "this month"
        } else {
            value = "\(count)"
            label = "milestones"
        }
        return recapStatColumn(value: value, label: label, centerX: centerX)
    }

    private static func milestoneDisplayTitle(_ m: MilestoneRecord) -> String {
        let t = m.milestoneType.trimmingCharacters(in: .whitespacesAndNewlines)
        if t == MilestoneType.custom.rawValue {
            let c = m.customCardTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !c.isEmpty { return c }
        }
        if let mt = MilestoneType(rawValue: t) {
            return mt.displayName
        }
        return t.isEmpty ? "Milestone" : t
    }

    private func recapStatColumn(value: String, label: String, centerX: CGFloat) -> some View {
        VStack(spacing: 4 * layoutScale) {
            Text(value)
                .font(.system(size: w * 0.055, weight: .black, design: .rounded))
                .foregroundStyle(Color.white)
                .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 1)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .frame(width: w * 0.28)
            Text(label)
                .font(.system(size: w * 0.024, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 8 * layoutScale)
        .padding(.horizontal, 10 * layoutScale)
        .background(
            RoundedRectangle(cornerRadius: 12 * layoutScale, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
        .position(x: centerX, y: h * 0.07)
    }
}
#endif

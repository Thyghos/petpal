// ZoomableCardPreview.swift
// Reusable full-width card preview with pinch zoom, double-tap reset, and optional one-time hint.
//
// Examples: milestone 1080×1920; passport 1080×1350 (4∶5); a future health report might use e.g. 800×1000 (4∶5).

import SwiftUI

#if os(iOS)
/// Full-width preview: container height follows `naturalWidth`:`naturalHeight` (e.g. 1080×1920 → 9∶16).
struct ZoomableCardPreview<Content: View> {
    /// Design-time width of the card content (e.g. 1080).
    let naturalWidth: CGFloat
    /// Design-time height of the card content (e.g. 1920 for milestones, 1080 for passport).
    let naturalHeight: CGFloat
    /// `UserDefaults` key for “has seen pinch hint” (per card type).
    let pinchHintAppStorageKey: String
    /// Bumps the hint animation when the presented item changes (e.g. `record.id`).
    let hintResetToken: AnyHashable
    /// When `false`, the built-in “Pinch to zoom” caption is hidden (host supplies its own).
    let showsPinchCaption: Bool

    private let content: (CGFloat, CGFloat) -> Content
    /// When `true`, content is laid out at `naturalWidth`×`naturalHeight` then fitted (passport). When `false`, `content` receives fitted size (milestone).
    private let laysOutAtNaturalSizeThenFits: Bool

    /// Passes fitted width and height so the card can render at screen size (no downscale from design pixels).
    init(
        naturalWidth: CGFloat,
        naturalHeight: CGFloat,
        pinchHintAppStorageKey: String,
        hintResetToken: AnyHashable,
        showsPinchCaption: Bool = true,
        @ViewBuilder content: @escaping (CGFloat, CGFloat) -> Content
    ) {
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
        self.pinchHintAppStorageKey = pinchHintAppStorageKey
        self.hintResetToken = hintResetToken
        self.showsPinchCaption = showsPinchCaption
        self.content = content
        self.laysOutAtNaturalSizeThenFits = false
    }

    /// Fixed-size card content (e.g. passport); fit dimensions are ignored.
    init(
        naturalWidth: CGFloat,
        naturalHeight: CGFloat,
        pinchHintAppStorageKey: String,
        hintResetToken: AnyHashable,
        showsPinchCaption: Bool = true,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.naturalWidth = naturalWidth
        self.naturalHeight = naturalHeight
        self.pinchHintAppStorageKey = pinchHintAppStorageKey
        self.hintResetToken = hintResetToken
        self.showsPinchCaption = showsPinchCaption
        self.content = { _, _ in content() }
        self.laysOutAtNaturalSizeThenFits = true
    }
}

extension ZoomableCardPreview: View {
    /// `naturalHeight / naturalWidth` (e.g. 1920/1080 = 16/9 for story cards).
    private var heightOverWidth: CGFloat {
        guard naturalWidth > 0 else { return 1 }
        return naturalHeight / naturalWidth
    }

    var body: some View {
        _ZoomableCardPreviewBody(
            naturalWidth: naturalWidth,
            naturalHeight: naturalHeight,
            heightOverWidth: heightOverWidth,
            pinchHintAppStorageKey: pinchHintAppStorageKey,
            hintResetToken: hintResetToken,
            showsPinchCaption: showsPinchCaption,
            laysOutAtNaturalSizeThenFits: laysOutAtNaturalSizeThenFits,
            content: content
        )
    }
}

/// Split so `ZoomableCardPreview` can expose two `init`s without duplicate `body` storage.
private struct _ZoomableCardPreviewBody<Content: View>: View {
    let naturalWidth: CGFloat
    let naturalHeight: CGFloat
    let heightOverWidth: CGFloat
    let pinchHintAppStorageKey: String
    let hintResetToken: AnyHashable
    let showsPinchCaption: Bool
    let laysOutAtNaturalSizeThenFits: Bool
    let content: (CGFloat, CGFloat) -> Content

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var hintOpacity: Double = 1.0
    @State private var showPinchHintRow: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                GeometryReader { geo in
                    // Avoid zero-size layout during first pass (would clip the card to invisible).
                    let fitWidth = max(geo.size.width, 1)
                    let fitHeight = max(fitWidth * naturalHeight / naturalWidth, 1)

                    Group {
                        if scale > 1.0 {
                            ScrollView([.horizontal, .vertical], showsIndicators: false) {
                                magnifiedCard(fitWidth: fitWidth, fitHeight: fitHeight)
                            }
                        } else {
                            magnifiedCard(fitWidth: fitWidth, fitHeight: fitHeight)
                        }
                    }
                    .frame(width: fitWidth, height: fitHeight)
                    .clipped()
                }
            }
            .aspectRatio(1.0 / heightOverWidth, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipped()

            if showsPinchCaption, showPinchHintRow {
                Text("Pinch to zoom")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                    .opacity(hintOpacity)
            }
        }
        .frame(maxWidth: .infinity)
        .ignoresSafeArea(edges: .horizontal)
        .onChange(of: hintResetToken) { _, _ in
            scale = 1.0
            lastScale = 1.0
        }
        .onAppear {
            guard showsPinchCaption else {
                showPinchHintRow = false
                hintOpacity = 0
                return
            }
            showPinchHintRow = !UserDefaults.standard.bool(forKey: pinchHintAppStorageKey)
            if !showPinchHintRow {
                hintOpacity = 0
            }
        }
        .task(id: hintResetToken) {
            guard showsPinchCaption else {
                showPinchHintRow = false
                return
            }
            guard !UserDefaults.standard.bool(forKey: pinchHintAppStorageKey) else {
                showPinchHintRow = false
                return
            }
            showPinchHintRow = true
            hintOpacity = 1.0
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation(.easeOut(duration: 0.45)) {
                hintOpacity = 0
            }
            try? await Task.sleep(nanoseconds: 450_000_000)
            UserDefaults.standard.set(true, forKey: pinchHintAppStorageKey)
            showPinchHintRow = false
        }
    }

    @ViewBuilder
    private func magnifiedCard(fitWidth: CGFloat, fitHeight: CGFloat) -> some View {
        Group {
            if laysOutAtNaturalSizeThenFits {
                ScrollView([.vertical], showsIndicators: false) {
                    content(fitWidth, fitHeight)
                        .frame(width: naturalWidth, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: fitWidth, height: fitHeight)
            } else {
                content(fitWidth, fitHeight)
                    .frame(width: fitWidth, height: fitHeight)
            }
        }
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: fitWidth * scale, height: fitHeight * scale, alignment: .topLeading)
        .contentShape(Rectangle())
        .clipped()
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = min(max(lastScale * value, 1.0), 3.0)
                }
                .onEnded { _ in
                    lastScale = scale
                }
        )
        .onTapGesture(count: 2) {
            withAnimation(.spring()) {
                scale = 1.0
                lastScale = 1.0
            }
        }
    }
}
#endif

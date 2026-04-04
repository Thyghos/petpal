// PrintShareSupport.swift
// Print and share for vet documents, insurance, health history, and pet sitter instructions.

import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
/// Use with `.sheet(item: $payload)` so the share sheet only presents when items exist (avoids flash-dismiss when `sheet(isPresented:)` + optional content races with Menu dismissal).
final class ShareSheetPayload: Identifiable {
    let id = UUID()
    let items: [Any]
    init(items: [Any]) {
        self.items = items
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct PrintShareHelper {
    /// Width (points) for printable layouts — full height is always measured so nothing is cropped.
    /// `nonisolated` so default parameter values on `@MainActor` methods can use it (Swift 6).
    nonisolated static let printableWidth: CGFloat = 612

    /// Renders a SwiftUI view to UIImage and presents print UI.
    /// Deferred to the next run loop so presentation succeeds after a toolbar `Menu` finishes dismissing (otherwise the print UI can open and dismiss immediately).
    @MainActor
    static func printView<V: View>(_ view: V, title: String) {
        let image = renderToImage(view)
        guard let img = image else { return }
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = title
        DispatchQueue.main.async {
            let printController = UIPrintInteractionController.shared
            printController.printInfo = printInfo
            printController.printingItem = img
            printController.present(animated: true) { _, _, _ in }
        }
    }

    /// Renders a SwiftUI view to a **full-height** UIImage (no clipping). Uses a fixed content width; do not wrap the view in a fixed height.
    @MainActor
    static func renderToImage<V: View>(_ view: V, contentWidth: CGFloat = printableWidth) -> UIImage? {
        let content = view
            .frame(width: contentWidth, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
        let renderer = ImageRenderer(content: content)
        let displayScale = UITraitCollection.current.displayScale
        renderer.scale = displayScale > 0 ? displayScale : 2
        renderer.proposedSize = ProposedViewSize(width: contentWidth, height: nil)
        return renderer.uiImage
    }

    /// Share items (image, text, etc.) via system share sheet.
    static func share(items: [Any]) -> ShareSheet {
        ShareSheet(items: items)
    }
}
#endif

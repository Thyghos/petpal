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
    /// Renders a SwiftUI view to UIImage and presents print UI.
    /// Deferred to the next run loop so presentation succeeds after a toolbar `Menu` finishes dismissing (otherwise the print UI can open and dismiss immediately).
    static func printView<V: View>(_ view: V, title: String) {
        let image = renderToImage(view)
        guard let img = image else { return }
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .photo
        printInfo.jobName = title
        DispatchQueue.main.async {
            let printController = UIPrintInteractionController.shared
            printController.printInfo = printInfo
            printController.printingItem = img
            printController.present(animated: true) { _, _, _ in }
        }
    }

    /// Renders a SwiftUI view to UIImage for sharing or printing.
    /// The view should have a defined frame (e.g. .frame(width: 400, height: 600)) for consistent output.
    static func renderToImage<V: View>(_ view: V) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0
        return renderer.uiImage
    }

    /// Share items (image, text, etc.) via system share sheet.
    static func share(items: [Any]) -> ShareSheet {
        ShareSheet(items: items)
    }
}
#endif

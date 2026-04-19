// PetAttachmentPreviewSupport.swift
// Shared PDF / image preview for profile PetAttachment rows.

import SwiftUI
#if canImport(UIKit)
import UIKit
import PDFKit
#endif

#if canImport(UIKit)
struct PetProfileAttachmentPreview: View {
    let attachment: PetAttachment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                let ft = attachment.fileType.lowercased()
                if ft == "pdf", let doc = PDFDocument(data: attachment.data) {
                    PetPDFKitRepresentable(document: doc)
                        .ignoresSafeArea(edges: .bottom)
                } else if let img = UIImage(data: attachment.data) {
                    ScrollView {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    }
                } else {
                    ContentUnavailableView(
                        "Preview unavailable",
                        systemImage: "doc",
                        description: Text("This file type can’t be previewed in the app.")
                    )
                }
            }
            .navigationTitle(attachment.name.isEmpty ? "Attachment" : attachment.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct PetPDFKitRepresentable: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.document = document
        v.autoScales = true
        v.displayDirection = .vertical
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#endif

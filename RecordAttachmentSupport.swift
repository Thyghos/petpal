// RecordAttachmentSupport.swift
// Camera, photo library, document scan, and file import for vet records.

import SwiftUI
import SwiftData
import PhotosUI
import Photos
import UIKit
import UniformTypeIdentifiers
import VisionKit
import PDFKit

// MARK: - Model helpers

extension PetRecordAttachment {
    static func deleteAll(parentRecordId: UUID, parentKind: PetRecordAttachmentParentKind, context: ModelContext) {
        let pk = parentKind.rawValue
        let pid = parentRecordId
        let descriptor = FetchDescriptor<PetRecordAttachment>(
            predicate: #Predicate { a in
                a.parentRecordId == pid && a.parentKind == pk
            }
        )
        guard let items = try? context.fetch(descriptor) else { return }
        for item in items {
            context.delete(item)
        }
    }

    static func detectedContentKind(for data: Data) -> String {
        guard data.count >= 4 else { return "image" }
        let prefix = String(data: data.prefix(4), encoding: .ascii) ?? ""
        return prefix == "%PDF" ? "pdf" : "image"
    }

    static func insertImagePages(_ images: [UIImage], parentRecordId: UUID, parentKind: PetRecordAttachmentParentKind, context: ModelContext) {
        for img in images {
            let resized = img.resizedForStorage(maxSide: 2200)
            guard let data = resized.jpegData(compressionQuality: 0.82) else { continue }
            let att = PetRecordAttachment(
                parentRecordId: parentRecordId,
                parentKind: parentKind,
                fileData: data,
                contentKind: "image"
            )
            context.insert(att)
        }
    }

    static func insertFileData(_ data: Data, parentRecordId: UUID, parentKind: PetRecordAttachmentParentKind, context: ModelContext) {
        let ck = detectedContentKind(for: data)
        let att = PetRecordAttachment(
            parentRecordId: parentRecordId,
            parentKind: parentKind,
            fileData: data,
            contentKind: ck
        )
        context.insert(att)
    }
}

private extension UIImage {
    func resizedForStorage(maxSide: CGFloat) -> UIImage {
        let w = size.width
        let h = size.height
        let m = max(w, h)
        guard m > maxSide else { return self }
        let scale = maxSide / m
        let newSize = CGSize(width: floor(w * scale), height: floor(h * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Share attachment (PDF / image as file URL for system share sheet)

private enum AttachmentShareHelper {
    /// Items for `UIActivityViewController`: a temp file URL so Mail, Files, etc. keep the correct type and name.
    static func activityItems(for attachment: PetRecordAttachment) -> [Any] {
        let tempDir = FileManager.default.temporaryDirectory
        if attachment.contentKind == "pdf" {
            let url = tempDir.appendingPathComponent("Petpal-attachment-\(attachment.id.uuidString).pdf")
            do {
                try attachment.fileData.write(to: url, options: .atomic)
                return [url]
            } catch {
                return [attachment.fileData]
            }
        }
        let url = tempDir.appendingPathComponent("Petpal-attachment-\(attachment.id.uuidString).jpg")
        guard let ui = UIImage(data: attachment.fileData) else { return [] }
        if let jpeg = ui.jpegData(compressionQuality: 0.92) {
            do {
                try jpeg.write(to: url, options: .atomic)
                return [url]
            } catch {
                return [ui]
            }
        }
        return [ui]
    }
}

// MARK: - Attachment strip + paperclip menu

struct RecordAttachmentsSection: View {
    let parentRecordId: UUID
    let parentKind: PetRecordAttachmentParentKind

    @Environment(\.modelContext) private var modelContext
    @Query private var attachments: [PetRecordAttachment]

    @State private var showingCamera = false
    @State private var showingScanner = false
    @State private var showingPhotoLibrary = false
    @State private var showingFilePicker = false
    @State private var previewAttachment: PetRecordAttachment?
    @State private var alertMessage: String?
    @State private var sharePayload: ShareSheetPayload?

    init(parentRecordId: UUID, parentKind: PetRecordAttachmentParentKind) {
        self.parentRecordId = parentRecordId
        self.parentKind = parentKind
        let pid = parentRecordId
        let pk = parentKind.rawValue
        _attachments = Query(
            filter: #Predicate<PetRecordAttachment> { a in
                a.parentRecordId == pid && a.parentKind == pk
            },
            sort: \.createdAt
        )
    }

    var body: some View {
        Section {
            if attachments.isEmpty {
                Text("No attachments yet. Use the paperclip to scan, photograph, or import a file.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(attachments) { att in
                            attachmentThumb(att)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        } header: {
            HStack {
                Text("Attachments")
                Spacer()
                Menu {
                    if VNDocumentCameraViewController.isSupported {
                        Button {
                            DispatchQueue.main.async { showingScanner = true }
                        } label: {
                            Label("Scan document", systemImage: "doc.viewfinder")
                        }
                    }
                    Button {
                        DispatchQueue.main.async {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showingCamera = true
                            } else {
                                alertMessage = "Camera isn’t available on this device (try a physical iPhone)."
                            }
                        }
                    } label: {
                        Label("Take photo", systemImage: "camera.fill")
                    }
                    // Defer sheet presentation until after the Menu dismisses (otherwise picker/sheet can flash closed).
                    Button {
                        DispatchQueue.main.async { showingPhotoLibrary = true }
                    } label: {
                        Label("Photo library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        DispatchQueue.main.async { showingFilePicker = true }
                    } label: {
                        Label("Choose file…", systemImage: "folder")
                    }
                } label: {
                    Image(systemName: "paperclip.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color("BrandBlue"))
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                if let image {
                    PetRecordAttachment.insertImagePages([image], parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView { images in
                PetRecordAttachment.insertImagePages(images, parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            LibraryPhotoPicker { image in
                if let image {
                    PetRecordAttachment.insertImagePages([image], parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
                }
            }
        }
        .sheet(isPresented: $showingFilePicker) {
            FileImportPicker { url in
                guard let url else { return }
                defer { try? FileManager.default.removeItem(at: url) }
                if let data = try? Data(contentsOf: url) {
                    PetRecordAttachment.insertFileData(data, parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
                }
            }
        }
        .sheet(item: $previewAttachment) { att in
            AttachmentPreviewSheet(attachment: att)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(items: payload.items)
        }
        .alert("Attachments", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @ViewBuilder
    private func attachmentThumb(_ att: PetRecordAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if att.contentKind == "pdf" {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("BrandSoftBlue").opacity(0.4))
                        Image(systemName: "doc.fill")
                            .font(.title)
                            .foregroundStyle(Color("BrandBlue"))
                    }
                } else if let ui = UIImage(data: att.fileData) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "questionmark.square")
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                previewAttachment = att
            }
            .contextMenu {
                Button {
                    let items = AttachmentShareHelper.activityItems(for: att)
                    guard !items.isEmpty else { return }
                    DispatchQueue.main.async {
                        sharePayload = ShareSheetPayload(items: items)
                    }
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                modelContext.delete(att)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .font(.caption)
            }
            .offset(x: 4, y: -4)
        }
    }
}

// MARK: - Preview sheet

struct AttachmentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: PetRecordAttachment

    @State private var sharePayload: ShareSheetPayload?

    var body: some View {
        NavigationStack {
            Group {
                if attachment.contentKind == "pdf" {
                    PDFKitView(data: attachment.fileData)
                } else if let ui = UIImage(data: attachment.fileData) {
                    ZoomableImageView(image: ui)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView("Preview unavailable", systemImage: "doc")
                }
            }
            .navigationTitle(attachment.contentKind == "pdf" ? "PDF" : "Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        let items = AttachmentShareHelper.activityItems(for: attachment)
                        guard !items.isEmpty else { return }
                        DispatchQueue.main.async {
                            sharePayload = ShareSheetPayload(items: items)
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share attachment")

                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(items: payload.items)
            }
        }
    }
}

// MARK: - Zoomable image (pinch to zoom, starts fit-to-screen)

private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .systemBackground

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.tag = 999
        scrollView.addSubview(imageView)

        context.coordinator.imageView = imageView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }
        let size = scrollView.bounds.size
        guard size.width > 1, size.height > 1 else { return }

        let prevSize = context.coordinator.lastLayoutSize
        let needsLayout = prevSize != size

        if needsLayout {
            context.coordinator.lastLayoutSize = size
            let imgSize = image.size
            let widthRatio = size.width / imgSize.width
            let heightRatio = size.height / imgSize.height
            let scale = min(widthRatio, heightRatio, 1)
            let fitSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)

            imageView.frame = CGRect(origin: .zero, size: fitSize)
            scrollView.contentSize = fitSize
            scrollView.zoomScale = 1.0
            scrollView.contentInsetAdjustmentBehavior = .automatic
            let insetH = max(0, (size.width - fitSize.width) / 2)
            let insetV = max(0, (size.height - fitSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetV, left: insetH, bottom: insetV, right: insetH)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var imageView: UIImageView?
        var lastLayoutSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard imageView != nil else { return }
            let size = scrollView.bounds.size
            let contentSize = scrollView.contentSize
            let insetH = max(0, (size.width - contentSize.width) / 2)
            let insetV = max(0, (size.height - contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(top: insetV, left: insetH, bottom: insetV, right: insetH)
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let v = PDFView()
        v.autoScales = true
        v.displayMode = .singlePageContinuous
        v.displayDirection = .vertical
        if let doc = PDFDocument(data: data) {
            v.document = doc
        }
        return v
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Photo library (PHPicker; reliable vs PhotosPicker-in-Menu)

private struct LibraryPhotoPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onImage: (UIImage?) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                finish(nil)
                return
            }
            let provider = result.itemProvider

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                    guard let self else { return }
                    if let img = object as? UIImage {
                        self.finish(img)
                        return
                    }
                    self.loadImageData(from: provider)
                }
            } else {
                loadImageData(from: provider)
            }
        }

        private func loadImageData(from provider: NSItemProvider) {
            let preferred = provider.registeredTypeIdentifiers.first { id in
                UTType(importedAs: id).conforms(to: .image)
            } ?? UTType.image.identifier

            provider.loadDataRepresentation(forTypeIdentifier: preferred) { [weak self] data, _ in
                guard let self else { return }
                let image = data.flatMap { UIImage(data: $0) }
                self.finish(image)
            }
        }

        private func finish(_ image: UIImage?) {
            DispatchQueue.main.async {
                self.onImage(image)
                self.dismiss()
            }
        }
    }
}

// MARK: - Camera

private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        p.allowsEditing = false
        return p
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void
        let dismiss: DismissAction

        init(onImage: @escaping (UIImage?) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImage(nil)
            dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let img = info[.originalImage] as? UIImage
            onImage(img)
            dismiss()
        }
    }
}

// MARK: - Document scanner

private struct DocumentScannerView: UIViewControllerRepresentable {
    var onComplete: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> ScanCoordinator {
        ScanCoordinator(onComplete: onComplete, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let c = VNDocumentCameraViewController()
        c.delegate = context.coordinator
        return c
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class ScanCoordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let dismiss: DismissAction

        init(onComplete: @escaping ([UIImage]) -> Void, dismiss: DismissAction) {
            self.onComplete = onComplete
            self.dismiss = dismiss
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var pages: [UIImage] = []
            for i in 0..<scan.pageCount {
                pages.append(scan.imageOfPage(at: i))
            }
            onComplete(pages)
            dismiss()
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            dismiss()
        }
    }
}

// MARK: - File import (Photos / PDF)

private struct FileImportPicker: UIViewControllerRepresentable {
    var onPick: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> FileCoordinator {
        FileCoordinator(onPick: onPick, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.image, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class FileCoordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void
        let dismiss: DismissAction

        init(onPick: @escaping (URL?) -> Void, dismiss: DismissAction) {
            self.onPick = onPick
            self.dismiss = dismiss
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
            dismiss()
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onPick(nil)
                dismiss()
                return
            }
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing { url.stopAccessingSecurityScopedResource() }
            }
            onPick(url)
            dismiss()
        }
    }
}

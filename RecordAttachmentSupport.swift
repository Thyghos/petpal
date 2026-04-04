// RecordAttachmentSupport.swift
// Camera, photo library, document scan, and file import for vet records.

import SwiftUI
import SwiftData
@preconcurrency import PhotosUI
import Photos
import UIKit
import UniformTypeIdentifiers
import VisionKit
import PDFKit
import AVFoundation

// MARK: - Camera permission (avoid first-launch sheet + system prompt fighting SwiftUI)

private enum CameraAccessHelper {
    static func requestVideoAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async { completion(true) }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { completion(false) }
        @unknown default:
            DispatchQueue.main.async { completion(false) }
        }
    }
}

// MARK: - Present camera / scanner from top UIKit VC (SwiftUI nested sheets break UIImagePickerController)

@MainActor
private enum TopViewControllerFinder {
    static func topMost() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap { $0.windows }
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap { $0.windows }.first { $0.windowLevel == .normal }
        guard let root = window?.rootViewController else { return nil }
        return findTop(from: root)
    }

    private static func findTop(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return findTop(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return findTop(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return findTop(from: selected)
        }
        return vc
    }
}

/// Holds strong ref to self while system camera is up (picker keeps delegate weak).
@MainActor
private final class DirectCameraSession: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private var onComplete: ((UIImage?) -> Void)?
    private static var active: DirectCameraSession?

    static func present(completion: @escaping (UIImage?) -> Void) {
        guard let top = TopViewControllerFinder.topMost() else {
            completion(nil)
            return
        }
        let session = DirectCameraSession()
        session.onComplete = completion
        Self.active = session
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = session
        picker.allowsEditing = false
        picker.modalPresentationStyle = .fullScreen
        top.present(picker, animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        finish(picker, image: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let img = info[.originalImage] as? UIImage
        finish(picker, image: img)
    }

    private func finish(_ picker: UIImagePickerController, image: UIImage?) {
        picker.dismiss(animated: true) {
            Self.active = nil
            self.onComplete?(image)
            self.onComplete = nil
        }
    }
}

/// Presents the photo library from the topmost UIKit VC (SwiftUI `fullScreenCover` + PHPicker can dismiss immediately).
/// Not `@MainActor`: `PHPicker` / `NSItemProvider` completions are not main-actor-isolated.
final class DirectPhotoLibrarySession: NSObject, PHPickerViewControllerDelegate {
    private var onComplete: ((UIImage?) -> Void)?
    private static var active: DirectPhotoLibrarySession?

    @MainActor
    static func present(completion: @escaping (UIImage?) -> Void) {
        guard let top = TopViewControllerFinder.topMost() else {
            completion(nil)
            return
        }
        let session = DirectPhotoLibrarySession()
        session.onComplete = completion
        Self.active = session
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = session
        picker.modalPresentationStyle = .fullScreen
        top.present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        guard let result = results.first else {
            dismissPicker(picker, image: nil)
            return
        }
        let provider = result.itemProvider
        let loadBitmap: () -> Void = { [weak self] in
            let preferred = provider.registeredTypeIdentifiers.first { id in
                UTType(importedAs: id).conforms(to: .image)
            } ?? UTType.image.identifier
            provider.loadDataRepresentation(forTypeIdentifier: preferred) { [weak self] data, _ in
                guard let self else { return }
                let image = data.flatMap { UIImage(data: $0) }
                self.dismissPicker(picker, image: image)
            }
        }

        if provider.canLoadObject(ofClass: UIImage.self) {
            provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                guard let self else { return }
                if let img = object as? UIImage {
                    self.dismissPicker(picker, image: img)
                } else {
                    loadBitmap()
                }
            }
        } else {
            loadBitmap()
        }
    }

    private func dismissPicker(_ picker: PHPickerViewController, image: UIImage?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            picker.dismiss(animated: true) {
                Self.active = nil
                self.onComplete?(image)
                self.onComplete = nil
            }
        }
    }
}

@MainActor
private final class DirectDocumentScannerSession: NSObject, VNDocumentCameraViewControllerDelegate {
    private var onComplete: (([UIImage]) -> Void)?
    private static var active: DirectDocumentScannerSession?

    static func present(completion: @escaping ([UIImage]) -> Void) {
        guard let top = TopViewControllerFinder.topMost() else {
            completion([])
            return
        }
        let session = DirectDocumentScannerSession()
        session.onComplete = completion
        Self.active = session
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = session
        scanner.modalPresentationStyle = .fullScreen
        top.present(scanner, animated: true)
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var pages: [UIImage] = []
        for i in 0..<scan.pageCount {
            pages.append(scan.imageOfPage(at: i))
        }
        dismiss(controller, result: pages)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        dismiss(controller, result: [])
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        dismiss(controller, result: [])
    }

    private func dismiss(_ controller: VNDocumentCameraViewController, result: [UIImage]) {
        controller.dismiss(animated: true) {
            Self.active = nil
            self.onComplete?(result)
            self.onComplete = nil
        }
    }
}

/// Presents the document picker from the topmost UIKit VC (SwiftUI `fullScreenCover` + document picker can dismiss immediately).
@MainActor
private final class DirectDocumentPickerSession: NSObject, UIDocumentPickerDelegate {
    private var onComplete: ((URL?) -> Void)?
    private static var active: DirectDocumentPickerSession?

    static func present(completion: @escaping (URL?) -> Void) {
        guard let top = TopViewControllerFinder.topMost() else {
            completion(nil)
            return
        }
        let session = DirectDocumentPickerSession()
        session.onComplete = completion
        Self.active = session
        let types: [UTType] = [.image, .pdf]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = session
        picker.allowsMultipleSelection = false
        picker.modalPresentationStyle = .fullScreen
        top.present(picker, animated: true)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completeAndDismiss(controller, url: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            completeAndDismiss(controller, url: nil)
            return
        }
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }
        completeAndDismiss(controller, url: url)
    }

    private func completeAndDismiss(_ controller: UIDocumentPickerViewController, url: URL?) {
        let cb = onComplete
        onComplete = nil
        cb?(url)
        controller.dismiss(animated: true) {
            Self.active = nil
        }
    }
}

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
        activityItems(fileData: attachment.fileData, contentKind: attachment.contentKind, id: attachment.id)
    }

    static func activityItems(fileData: Data, contentKind: String, id: UUID) -> [Any] {
        let tempDir = FileManager.default.temporaryDirectory
        if contentKind == "pdf" {
            let url = tempDir.appendingPathComponent("Petpal-attachment-\(id.uuidString).pdf")
            do {
                try fileData.write(to: url, options: .atomic)
                return [url]
            } catch {
                return [fileData]
            }
        }
        let url = tempDir.appendingPathComponent("Petpal-attachment-\(id.uuidString).jpg")
        guard let ui = UIImage(data: fileData) else { return [] }
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

// MARK: - Attachment preview (UIKit host; SwiftUI `.sheet` flashes closed when nested in forms / fullScreenCover)

private struct AttachmentPreviewPayload {
    let id: UUID
    let contentKind: String
    let fileData: Data

    init(attachment: PetRecordAttachment) {
        id = attachment.id
        contentKind = attachment.contentKind
        fileData = attachment.fileData
    }
}

@MainActor
private enum DirectAttachmentPreviewSession {
    private static var activeToken: NSObject?

    static func present(payload: AttachmentPreviewPayload) {
        guard let top = TopViewControllerFinder.topMost() else { return }
        let token = NSObject()
        activeToken = token
        let root = AttachmentPreviewViewController(payload: payload) {
            if activeToken === token {
                activeToken = nil
            }
        }
        let nav = UINavigationController(rootViewController: root)
        nav.modalPresentationStyle = .fullScreen
        top.present(nav, animated: true)
    }
}

/// Image preview with pinch-to-zoom. At zoom 1× the **entire** image is visible (aspect-fit).
/// Delegates all fit logic to UIImageView.scaleAspectFit; the scroll view only adds zoom + pan.
private final class ZoomingImageScrollUIView: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private var lastBounds: CGSize = .zero

    init(image: UIImage) {
        super.init(frame: .zero)
        backgroundColor = .systemBackground

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .systemBackground
        scrollView.contentInsetAdjustmentBehavior = .never

        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        addSubview(scrollView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds.size
        guard b.width > 1, b.height > 1 else { return }
        let changed = abs(b.width - lastBounds.width) > 0.5
                   || abs(b.height - lastBounds.height) > 0.5
        guard changed else { return }
        lastBounds = b
        scrollView.frame = bounds
        scrollView.zoomScale = 1.0
        imageView.frame = CGRect(origin: .zero, size: b)
        scrollView.contentSize = b
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let bw = scrollView.bounds.width
        let bh = scrollView.bounds.height
        let cw = imageView.frame.width
        let ch = imageView.frame.height
        let ox = max((bw - cw) * 0.5, 0)
        let oy = max((bh - ch) * 0.5, 0)
        scrollView.contentInset = UIEdgeInsets(top: oy, left: ox, bottom: oy, right: ox)
    }
}

/// PDF attachment preview: continuous vertical scroll; refits page scale when bounds change (UIKit avoids Hosting zero-bounds so `autoScales` applies).
private final class FittingPDFPreviewUIView: UIView {
    private let pdfView = PDFView()
    private var lastFitBounds: CGSize = .zero

    init(data: Data) {
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        // Manual `scaleFactor` + `scaleFactorForSizeToFit`; `autoScales` can fight layout and stay too zoomed in.
        pdfView.autoScales = false
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        if let doc = PDFDocument(data: data) {
            pdfView.document = doc
        }
        addSubview(pdfView)
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds.size
        guard b.width > 2, b.height > 2, pdfView.document != nil else { return }
        let changed =
            lastFitBounds.width < 1
            || abs(b.width - lastFitBounds.width) > 0.5
            || abs(b.height - lastFitBounds.height) > 0.5
        guard changed else { return }
        lastFitBounds = b
        pdfView.layoutDocumentView()
        let fit = pdfView.scaleFactorForSizeToFit
        guard fit > 0.001, fit.isFinite else { return }
        pdfView.minScaleFactor = fit
        pdfView.maxScaleFactor = max(4, fit * 4)
        pdfView.scaleFactor = fit
    }
}

private final class AttachmentPreviewViewController: UIViewController {
    private let payload: AttachmentPreviewPayload
    private let onClosed: () -> Void

    init(payload: AttachmentPreviewPayload, onClosed: @escaping () -> Void) {
        self.payload = payload
        self.onClosed = onClosed
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func hostingPDFPreview(data: Data) -> UIViewController {
        let pdfVC = UIViewController()
        pdfVC.view.backgroundColor = .systemBackground
        let pdf = FittingPDFPreviewUIView(data: data)
        pdf.translatesAutoresizingMaskIntoConstraints = false
        pdfVC.view.addSubview(pdf)
        NSLayoutConstraint.activate([
            pdf.topAnchor.constraint(equalTo: pdfVC.view.topAnchor),
            pdf.leadingAnchor.constraint(equalTo: pdfVC.view.leadingAnchor),
            pdf.trailingAnchor.constraint(equalTo: pdfVC.view.trailingAnchor),
            pdf.bottomAnchor.constraint(equalTo: pdfVC.view.bottomAnchor)
        ])
        return pdfVC
    }

    private static func hostingImagePreview(image: UIImage) -> UIViewController {
        let imageVC = UIViewController()
        imageVC.view.backgroundColor = .systemBackground
        let zoom = ZoomingImageScrollUIView(image: image)
        zoom.translatesAutoresizingMaskIntoConstraints = false
        imageVC.view.addSubview(zoom)
        NSLayoutConstraint.activate([
            zoom.topAnchor.constraint(equalTo: imageVC.view.topAnchor),
            zoom.leadingAnchor.constraint(equalTo: imageVC.view.leadingAnchor),
            zoom.trailingAnchor.constraint(equalTo: imageVC.view.trailingAnchor),
            zoom.bottomAnchor.constraint(equalTo: imageVC.view.bottomAnchor)
        ])
        return imageVC
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .action,
            target: self,
            action: #selector(shareTapped)
        )

        let pageCount = PDFDocument(data: payload.fileData)?.pageCount ?? 0
        let treatAsPDF = pageCount > 0

        let host: UIViewController
        if payload.contentKind == "pdf", treatAsPDF {
            title = "PDF"
            host = Self.hostingPDFPreview(data: payload.fileData)
        } else if let ui = UIImage(data: payload.fileData) {
            title = "Photo"
            host = Self.hostingImagePreview(image: ui)
        } else if treatAsPDF {
            title = "PDF"
            host = Self.hostingPDFPreview(data: payload.fileData)
        } else {
            title = "Attachment"
            let label = UILabel()
            label.text = "Preview unavailable"
            label.textAlignment = .center
            label.textColor = .secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
            ])
            return
        }

        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(host.view, at: 0)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    @objc private func doneTapped() {
        dismiss(animated: true) { [onClosed] in
            onClosed()
        }
    }

    @objc private func shareTapped() {
        let items = AttachmentShareHelper.activityItems(
            fileData: payload.fileData,
            contentKind: payload.contentKind,
            id: payload.id
        )
        guard !items.isEmpty else { return }
        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
        av.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        av.popoverPresentationController?.sourceView = view
        present(av, animated: true)
    }
}

// MARK: - Attachment strip + paperclip menu

struct RecordAttachmentsSection: View {
    let parentRecordId: UUID
    let parentKind: PetRecordAttachmentParentKind

    @Environment(\.modelContext) private var modelContext
    @Query private var attachments: [PetRecordAttachment]

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
                            presentScannerAfterMenuDismiss()
                        } label: {
                            Label("Scan document", systemImage: "doc.viewfinder")
                        }
                    }
                    Button {
                        presentCameraAfterMenuDismiss()
                    } label: {
                        Label("Take photo", systemImage: "camera.fill")
                    }
                    // Defer sheet presentation until after the Menu dismisses (otherwise picker/sheet can flash closed).
                    Button {
                        presentPhotoLibraryAfterMenuDismiss()
                    } label: {
                        Label("Photo library", systemImage: "photo.on.rectangle")
                    }
                    Button {
                        presentChooseFileAfterMenuDismiss()
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

    /// Menu dismiss delay + permission, then present camera via UIKit (SwiftUI sheets/covers break nested camera).
    private func presentCameraAfterMenuDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                alertMessage = "Camera isn’t available on this device (try a physical iPhone)."
                return
            }
            CameraAccessHelper.requestVideoAccessIfNeeded { ok in
                guard ok else {
                    alertMessage = "Camera access is needed to photograph documents. You can enable it in Settings → Petpal."
                    return
                }
                DirectCameraSession.present { image in
                    guard let image else { return }
                    PetRecordAttachment.insertImagePages([image], parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
                }
            }
        }
    }

    private func presentPhotoLibraryAfterMenuDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            DirectPhotoLibrarySession.present { image in
                guard let image else { return }
                PetRecordAttachment.insertImagePages([image], parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
            }
        }
    }

    private func presentScannerAfterMenuDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard VNDocumentCameraViewController.isSupported else { return }
            CameraAccessHelper.requestVideoAccessIfNeeded { ok in
                guard ok else {
                    alertMessage = "Camera access is needed to scan documents. You can enable it in Settings → Petpal."
                    return
                }
                DirectDocumentScannerSession.present { images in
                    guard !images.isEmpty else { return }
                    PetRecordAttachment.insertImagePages(images, parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
                }
            }
        }
    }

    private func presentChooseFileAfterMenuDismiss() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            DirectDocumentPickerSession.present { url in
                guard let url else { return }
                defer { try? FileManager.default.removeItem(at: url) }
                if let data = try? Data(contentsOf: url) {
                    PetRecordAttachment.insertFileData(data, parentRecordId: parentRecordId, parentKind: parentKind, context: modelContext)
                }
            }
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
                DirectAttachmentPreviewSession.present(payload: AttachmentPreviewPayload(attachment: att))
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

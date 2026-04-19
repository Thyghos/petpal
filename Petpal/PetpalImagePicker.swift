// Reusable camera / photo library pickers for document capture.

import SwiftUI
#if os(iOS)
import UIKit
import PhotosUI
import UniformTypeIdentifiers
#endif

enum ImagePickerSource: Sendable {
    case camera
    case photoLibrary
}

#if os(iOS)

struct ImagePickerView: UIViewControllerRepresentable {
    var source: ImagePickerSource
    var onImageSelected: (UIImage) -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // `source` / callbacks can change while the representable updates; keep coordinator in sync.
        context.coordinator.parent = self
    }

    func makeUIViewController(context: Context) -> UIViewController {
        switch source {
        case .camera:
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                let label = UILabel()
                label.text = "Camera isn’t available on this device."
                label.textAlignment = .center
                label.textColor = .secondaryLabel
                let vc = UIViewController()
                vc.view = label
                return vc
            }
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.image.identifier]
            picker.delegate = context.coordinator
            picker.allowsEditing = false
            picker.modalPresentationStyle = .fullScreen
            return picker
        case .photoLibrary:
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = PHPickerFilter.images
            configuration.selectionLimit = 1
            configuration.preferredAssetRepresentationMode = .compatible
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            picker.modalPresentationStyle = .fullScreen
            return picker
        }
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {
        var parent: ImagePickerView

        init(parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            let img = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                if let img {
                    self.parent.onImageSelected(img)
                } else {
                    self.parent.onCancel()
                }
            }
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                picker.dismiss(animated: true) { [weak self] in
                    self?.parent.onCancel()
                }
                return
            }
            let provider = result.itemProvider
            let finish: (UIImage?) -> Void = { [weak self] img in
                guard let self else { return }
                picker.dismiss(animated: true) {
                    if let img {
                        self.parent.onImageSelected(img)
                    } else {
                        self.parent.onCancel()
                    }
                }
            }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { object, _ in
                    DispatchQueue.main.async {
                        finish(object as? UIImage)
                    }
                }
            } else {
                let type = provider.registeredTypeIdentifiers.first { id in
                    UTType(importedAs: id).conforms(to: .image)
                } ?? UTType.image.identifier
                provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                    DispatchQueue.main.async {
                        finish(data.flatMap { UIImage(data: $0) })
                    }
                }
            }
        }
    }
}

#endif

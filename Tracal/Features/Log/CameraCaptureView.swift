import SwiftUI
import UIKit

struct CapturedCameraPhoto {
    let originalData: Data?
    let fallbackImage: UIImage?
}

/// Apple's one-shot system camera, presented full-screen by SwiftUI.
///
/// `UIImagePickerController` owns the capture session. It must not be embedded
/// in custom view-controller containment: normal full-screen presentation gives
/// UIKit the matching presentation and dismissal lifecycle it uses to release
/// the camera hardware.
struct InlineMealCameraView: UIViewControllerRepresentable {
    let onCapture: (CapturedCameraPhoto) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        // Source type is the only camera setting UIKit requires. Avoid touching
        // the picker's view or querying devices here; both force extra camera
        // setup before the full-screen presentation is ready.
        picker.sourceType = .camera
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    static func dismantleUIViewController(
        _ uiViewController: UIImagePickerController,
        coordinator: Coordinator
    ) {
        coordinator.invalidate()
        uiViewController.delegate = nil
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let onCapture: (CapturedCameraPhoto) -> Void
        private let onCancel: () -> Void
        private var isFinished = false

        init(onCapture: @escaping (CapturedCameraPhoto) -> Void, onCancel: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func invalidate() {
            isFinished = true
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            guard !isFinished else { return }
            isFinished = true
            picker.delegate = nil
            onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard !isFinished else { return }
            let image = info[.originalImage] as? UIImage
            let originalData = (info[.imageURL] as? URL).flatMap { url in
                try? Data(contentsOf: url)
            }
            guard originalData != nil || image != nil else {
                isFinished = true
                picker.delegate = nil
                onCancel()
                return
            }

            isFinished = true
            picker.delegate = nil
            // Prefer the picker's original temporary bytes. This avoids a
            // full-resolution UIImage → JPEG encode on the main thread.
            onCapture(
                CapturedCameraPhoto(
                    originalData: originalData,
                    fallbackImage: originalData == nil ? image : nil
                )
            )
        }
    }
}

// MARK: - Availability and authorization

@MainActor
enum CameraCaptureView {
    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
}

import UIKit

/// Opens the system camera straight from UIKit, above whatever is on screen.
///
/// The camera used to sit in a SwiftUI full-screen cover. Covers attached to
/// list rows or menus were torn down as soon as the camera appeared, which
/// closed it again at once. Presenting from the top view controller keeps it
/// out of SwiftUI's view updates.
@MainActor
enum Camera {
    static var isAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    private static var delegate: Delegate?

    static func capture(_ onCapture: @escaping @MainActor (UIImage) -> Void) {
        guard isAvailable else { return }
        // Let a menu or sheet finish closing before presenting.
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard let presenter = topViewController() else { return }
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.modalPresentationStyle = .fullScreen
            let delegate = Delegate(onCapture: onCapture)
            Self.delegate = delegate
            picker.delegate = delegate
            presenter.present(picker, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.first as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }

    private final class Delegate: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: @MainActor (UIImage) -> Void

        init(onCapture: @escaping @MainActor (UIImage) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                if let image { MainActor.assumeIsolated { self.onCapture(image) } }
                Camera.delegate = nil
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) { Camera.delegate = nil }
        }
    }
}

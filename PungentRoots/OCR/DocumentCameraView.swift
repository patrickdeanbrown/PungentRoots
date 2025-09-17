#if os(iOS)
import SwiftUI
import VisionKit

struct DocumentCameraView: UIViewControllerRepresentable {
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentCameraView

        init(parent: DocumentCameraView) {
            self.parent = parent
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.presentationMode.wrappedValue.dismiss()
            parent.onCompletion(.failure(error))
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            parent.presentationMode.wrappedValue.dismiss()
            var images = [CGImage]()
            for index in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: index)
                if let cgImage = image.cgImage {
                    images.append(cgImage)
                }
            }
            guard let first = images.first else {
                parent.onCompletion(.failure(DocumentCameraError.noImageCaptures))
                return
            }
            parent.onCompletion(.success(first))
        }
    }

    enum DocumentCameraError: Swift.Error {
        case noImageCaptures
    }

    @Environment(\.presentationMode) private var presentationMode
    let onCompletion: (Result<CGImage, Swift.Error>) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
}
#endif

import SwiftUI

/// Displays a captured image with detection bounding boxes overlaid
struct CapturedImageOverlayView: View {
    let image: UIImage
    let boxes: [DetectionOverlay]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                // Overlay bounding boxes
                ForEach(boxes, id: \.id) { overlay in
                    let imageSize = calculateFittedImageSize(in: geometry.size)
                    let offset = calculateImageOffset(imageSize: imageSize, containerSize: geometry.size)

                    Rectangle()
                        .fill(overlay.severity.color)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                        )
                        .frame(
                            width: overlay.rect.width * imageSize.width,
                            height: overlay.rect.height * imageSize.height
                        )
                        .position(
                            x: offset.x + (overlay.rect.midX * imageSize.width),
                            y: offset.y + (overlay.rect.midY * imageSize.height)
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(image.size.width / image.size.height, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// Calculate the actual size of the image when fit into the container
    private func calculateFittedImageSize(in containerSize: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            // Image is wider - fit to width
            let width = containerSize.width
            let height = width / imageAspect
            return CGSize(width: width, height: height)
        } else {
            // Image is taller - fit to height
            let height = containerSize.height
            let width = height * imageAspect
            return CGSize(width: width, height: height)
        }
    }

    /// Calculate the offset for centering the fitted image
    private func calculateImageOffset(imageSize: CGSize, containerSize: CGSize) -> CGPoint {
        let x = (containerSize.width - imageSize.width) / 2
        let y = (containerSize.height - imageSize.height) / 2
        return CGPoint(x: x + imageSize.width / 2, y: y + imageSize.height / 2)
    }
}
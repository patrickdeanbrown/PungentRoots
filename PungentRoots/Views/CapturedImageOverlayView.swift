import SwiftUI

/// Displays a captured image with detection bounding boxes overlaid
struct CapturedImageOverlayView: View {
    let image: UIImage
    let boxes: [DetectionOverlay]

    var body: some View {
        GeometryReader { geometry in
            let imageSize = calculateFittedImageSize(in: geometry.size)
            let imageOffset = calculateImageOffset(imageSize: imageSize, containerSize: geometry.size)

            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize.width, height: imageSize.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)

                // Overlay bounding boxes
                ForEach(boxes, id: \.id) { overlay in
                    let transformedRect = transformVisionRect(overlay.rect, imageSize: imageSize)

                    Rectangle()
                        .fill(overlay.severity.color)
                        .frame(
                            width: max(transformedRect.width, 1),
                            height: max(transformedRect.height, 1)
                        )
                        .offset(
                            x: imageOffset.x - imageSize.width / 2 + transformedRect.minX,
                            y: imageOffset.y - imageSize.height / 2 + transformedRect.minY
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
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

    private func transformVisionRect(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        CGRect(
            x: visionRect.minX * imageSize.width,
            y: (1 - visionRect.maxY) * imageSize.height,
            width: visionRect.width * imageSize.width,
            height: visionRect.height * imageSize.height
        )
    }
}

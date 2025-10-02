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
                        .onAppear {
                            print("📦 Box: transformed=\(transformedRect) imageSize=\(imageSize) imageOffset=\(imageOffset)")
                        }
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

    /// Transform Vision framework bounding box to SwiftUI coordinates
    /// Vision uses bottom-left origin (0,0) with normalized coordinates (0-1)
    /// SwiftUI uses top-left origin with pixel coordinates
    private func transformVisionRect(_ visionRect: CGRect, imageSize: CGSize) -> CGRect {
        // The UIImage already has the correct orientation applied
        // Vision coordinates are in the ORIGINAL sensor orientation (landscape)
        // UIImage.size reflects the ROTATED dimensions (portrait after .right rotation)
        // So we need to map from landscape Vision coords to portrait image coords

        print("🔧 Transform: orientation=\(image.imageOrientation.rawValue) visionRect=\(visionRect) imageSize=\(imageSize)")

        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat

        // Check if the image is portrait but Vision detected in landscape orientation
        // This happens when camera sensor is landscape but UIImage is rotated to portrait
        let isPortraitImage = imageSize.height > imageSize.width
        let isLandscapeVisionBox = visionRect.height > visionRect.width

        if isPortraitImage && isLandscapeVisionBox {
            // Image is portrait, but Vision box is landscape (height > width)
            // This means Vision coordinates are in sensor space (landscape)
            // and we need to rotate them to match the portrait image
            print("🔄 Detected landscape Vision box on portrait image - rotating coordinates")

            // Rotate 90° clockwise: swap X/Y and swap width/height
            x = visionRect.minY * imageSize.width
            y = (1 - visionRect.maxX) * imageSize.height
            width = visionRect.height * imageSize.width   // Swap width/height
            height = visionRect.width * imageSize.height
        } else {
            // Standard transformation: flip Y axis from bottom-left to top-left
            x = visionRect.minX * imageSize.width
            y = (1 - visionRect.maxY) * imageSize.height
            width = visionRect.width * imageSize.width
            height = visionRect.height * imageSize.height
        }

        let result = CGRect(x: x, y: y, width: width, height: height)
        print("🔧 Result: \(result)")
        return result
    }
}
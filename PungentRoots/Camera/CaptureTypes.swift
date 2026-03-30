import Foundation
#if os(iOS)
import UIKit
#endif

enum CaptureState: Equatable, Sendable {
    case idle
    case preparing
    case scanning
    case processing
    case paused
    case error(String)
}

enum CaptureReadiness: Equatable, Sendable {
    case none
    case tooFar
    case almostReady
    case ready
}

struct CapturePayload {
    struct Item: Hashable, Sendable {
        let text: String
        let boundingBox: CGRect
    }

    let items: [Item]
#if os(iOS)
    let capturedImage: UIImage?
#else
    let capturedImage: Never?
#endif

    var strings: [String] {
        items.map(\.text)
    }
}

import CoreGraphics
import Foundation

struct RecognizedTextBlock: Identifiable, Equatable, Sendable {
    let text: String
    let boundingBox: CGRect
    let confidence: Float

    var id: String {
        "\(text.lowercased())-\(boundingBox.origin.x)-\(boundingBox.origin.y)-\(boundingBox.width)-\(boundingBox.height)"
    }
}

enum OCRCoverageStatus: String, Equatable, Sendable {
    case complete
    case partial
    case insufficient

    var title: String {
        switch self {
        case .complete:
            return "Full label likely captured"
        case .partial:
            return "Ingredient list may be incomplete"
        case .insufficient:
            return "Only partial packaging text was read"
        }
    }

    var subtitle: String {
        switch self {
        case .complete:
            return "This scan appears to include the ingredient panel."
        case .partial:
            return "Review the package and retake if the ingredient list is cut off."
        case .insufficient:
            return "The app may have read footer or allergen text instead of the full ingredients."
        }
    }
}

struct CapturedLabel: Equatable, Sendable {
    let imageData: Data?
    let recognizedBlocks: [RecognizedTextBlock]
    let rawText: String
    let coverageStatus: OCRCoverageStatus
    let warnings: [String]
}

import Foundation

struct ScanAnalysis: Equatable, Sendable {
    let rawText: String
    let normalizedText: String
    let result: DetectionResult
    let recognizedBlocks: [RecognizedTextBlock]
    let coverageStatus: OCRCoverageStatus
    let warnings: [String]
    let capturedImageData: Data?

    var matches: [Match] {
        result.matches
    }

    var verdict: Verdict {
        result.verdict
    }

    var hasWarnings: Bool {
        warnings.isEmpty == false
    }
}

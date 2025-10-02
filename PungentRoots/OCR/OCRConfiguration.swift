import Foundation
import Vision

/// Centralized configuration for OCR text recognition settings
struct OCRConfiguration {
    /// Recognition quality level (accurate provides better results but slower processing)
    let recognitionLevel: VNRequestTextRecognitionLevel

    /// Enable language-based correction during recognition
    let usesLanguageCorrection: Bool

    /// Minimum text height as a fraction of image height (0.0-1.0)
    /// Lower values detect smaller text but may increase false positives
    let minimumTextHeight: Float

    /// Minimum confidence threshold for accepting recognized text (0.0-1.0)
    let confidenceThreshold: Float

    /// Preferred recognition languages in priority order
    let recognitionLanguages: [String]

    /// Vision framework revision to use (iOS 16+ supports revision 3)
    let revision: Int

    /// Minimum character count for valid text capture
    let minimumCaptureLength: Int

    /// Minimum number of text observations (lines) for capture
    let minimumObservationCount: Int

    /// Minimum average confidence across all observations (0.0-1.0)
    let minimumAverageConfidence: Float

    /// Throttle interval between frame captures (in seconds)
    let frameThrottleInterval: TimeInterval

    /// Default configuration optimized for ingredient label scanning
    static let `default` = OCRConfiguration(
        recognitionLevel: .accurate,
        usesLanguageCorrection: true,
        minimumTextHeight: 0.012,
        confidenceThreshold: 0.45,
        recognitionLanguages: ["en-US", "en-GB"],
        revision: 3, // VNRecognizeTextRequestRevision3
        minimumCaptureLength: 20,  // Increased from 12 to require more text
        minimumObservationCount: 5, // Require at least 5 lines of text
        minimumAverageConfidence: 0.65, // Require 65% average confidence
        frameThrottleInterval: 0.7
    )

    /// Fast configuration with lower quality but faster processing
    static let fast = OCRConfiguration(
        recognitionLevel: .fast,
        usesLanguageCorrection: false,
        minimumTextHeight: 0.015,
        confidenceThreshold: 0.5,
        recognitionLanguages: ["en-US"],
        revision: 3,
        minimumCaptureLength: 15,
        minimumObservationCount: 4,
        minimumAverageConfidence: 0.6,
        frameThrottleInterval: 0.5
    )
}
import Foundation
import Testing
@testable import PungentRoots

@MainActor
struct ScanFlowModelTests {
    @Test("Scan analysis keeps raw and normalized text")
    func scanAnalysisTracksSourceAndNormalization() {
        let environment = AppEnvironment.preview
        let analysis = environment.analyze("Ingredients: Onio-\nn Powder")

        #expect(analysis.rawText.contains("Onio-"))
        #expect(analysis.normalizedText.contains("onion powder"))
        #expect(analysis.verdict == .contains)
    }

    @Test("UI test preview loads a deterministic result")
    func previewLaunchLoadsResultWithoutCapture() {
        let flowModel = ScanFlowModel(
            launchArguments: ["--ui-test-disable-capture", "--ui-test-preview-result"]
        )

        flowModel.bind(environment: .preview)

        #expect(flowModel.detectionResult != nil)
        #expect(flowModel.captureState == .paused)
        #expect(flowModel.captureReadiness == .ready)
        #expect(flowModel.isProcessing == false)
        #expect(flowModel.phase == .result)
    }

    @Test("Rescan clears preview analysis and returns to scanning")
    func rescanClearsPreviewAnalysis() {
        let flowModel = ScanFlowModel(
            launchArguments: ["--ui-test-disable-capture", "--ui-test-preview-result"]
        )

        flowModel.bind(environment: .preview)
        flowModel.rescan()

        #expect(flowModel.detectionResult == nil)
        #expect(flowModel.captureState == .scanning)
        #expect(flowModel.showsEmptyState)
        #expect(flowModel.phase == .framing)
    }

    @Test("Partial preview requires review when ingredient coverage is missing")
    func partialPreviewRequiresReview() {
        let flowModel = ScanFlowModel(
            launchArguments: ["--ui-test-disable-capture", "--ui-test-preview-partial-result"]
        )

        flowModel.bind(environment: .preview)

        #expect(flowModel.phase == .result)
        #expect(flowModel.analysis?.coverageStatus == .insufficient)
        #expect(flowModel.analysis?.verdict == .needsReview)
        #expect(flowModel.analysis?.warnings.isEmpty == false)
    }

    @Test("Overlay mapping keeps the highest severity per detected term")
    func overlayMappingUsesHighestSeverity() {
        let items = [
            RecognizedTextBlock(text: "Onion Powder", boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.1), confidence: 0.91),
            RecognizedTextBlock(text: "Sea Salt", boundingBox: CGRect(x: 0.2, y: 0.4, width: 0.2, height: 0.1), confidence: 0.89)
        ]
        let matches = [
            Match(term: "onion", kind: .ambiguous, range: 0..<5, note: "ambiguous"),
            Match(term: "onion", kind: .definite, range: 0..<5, note: "definite")
        ]

        let overlays = DetectionOverlay.overlays(for: items, matches: matches)

        #expect(overlays.count == 1)
        #expect(overlays.first?.severity == .high)
    }
}

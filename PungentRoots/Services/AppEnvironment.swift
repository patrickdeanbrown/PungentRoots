import Foundation
import Observation
import os

@MainActor
@Observable
final class AppEnvironment {
    let detectionEngine: DetectionEngine
    let dictionary: DetectDictionary
    let normalizer: TextNormalizer
    let textAcquisition: TextAcquisitionService
    let scoring: DetectionScoring

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "Detection")
    private let signposter = OSSignposter(subsystem: "co.ouchieco.PungentRoots", category: "Detection")

    init(
        dictionary: DetectDictionary,
        normalizer: TextNormalizer = TextNormalizer(),
        scoring: DetectionScoring = .default
    ) {
        self.dictionary = dictionary
        self.normalizer = normalizer
        self.scoring = scoring
        self.detectionEngine = DetectionEngine(dictionary: dictionary, normalizer: normalizer, scoring: scoring)
        self.textAcquisition = TextAcquisitionService(normalizer: normalizer)

#if canImport(MetricKit)
        _ = MetricReporter.shared
#endif
    }

    func analyze(_ rawText: String) -> ScanAnalysis {
        let signpostID = signposter.makeSignpostID()
        let interval = signposter.beginInterval("SynchronousAnalyze", id: signpostID)
        let start = DispatchTime.now()
        let analysis = detectionEngine.analyze(rawText: rawText)
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        signposter.endInterval("SynchronousAnalyze", interval)
        logger.debug("Detection completed in \(duration, format: .fixed(precision: 2))ms (\(analysis.result.matches.count) matches)")
        return ScanAnalysis(
            rawText: rawText,
            normalizedText: analysis.normalized,
            result: analysis.result,
            recognizedBlocks: [],
            coverageStatus: .complete,
            warnings: [],
            capturedImageData: nil
        )
    }

    func analyzeAsync(_ rawText: String) async -> ScanAnalysis {
        let engine = detectionEngine
        let signposter = self.signposter
        let result = await Task(priority: .userInitiated) { () -> (String, DetectionResult, Double) in
            let signpostID = signposter.makeSignpostID()
            let interval = signposter.beginInterval("AsyncAnalyze", id: signpostID)
            let start = DispatchTime.now()
            let analysis = engine.analyze(rawText: rawText)
            let duration = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
            signposter.endInterval("AsyncAnalyze", interval)
            return (analysis.normalized, analysis.result, duration)
        }.value

        logger.debug("Async detection completed in \(result.2, format: .fixed(precision: 2))ms (\(result.1.matches.count) matches)")
        return ScanAnalysis(
            rawText: rawText,
            normalizedText: result.0,
            result: result.1,
            recognizedBlocks: [],
            coverageStatus: .complete,
            warnings: [],
            capturedImageData: nil
        )
    }

    func analyzeCapturedLabel(_ label: CapturedLabel) -> ScanAnalysis {
        let signpostID = signposter.makeSignpostID()
        let interval = signposter.beginInterval("CapturedLabelAnalyze", id: signpostID)
        let analysis = detectionEngine.analyze(rawText: label.rawText)
        signposter.endInterval("CapturedLabelAnalyze", interval)
        let result = adjustedDetectionResult(analysis.result, coverageStatus: label.coverageStatus)

        return ScanAnalysis(
            rawText: label.rawText,
            normalizedText: analysis.normalized,
            result: result,
            recognizedBlocks: label.recognizedBlocks,
            coverageStatus: label.coverageStatus,
            warnings: label.warnings,
            capturedImageData: label.imageData
        )
    }

    func analyzeCapturedImageData(_ imageData: Data) async throws -> ScanAnalysis {
        let label = try await textAcquisition.recognizePackaging(from: .imageData(imageData))
        return analyzeCapturedLabel(label)
    }

    private func adjustedDetectionResult(_ result: DetectionResult, coverageStatus: OCRCoverageStatus) -> DetectionResult {
        guard result.verdict == .safe, coverageStatus != .complete else {
            return result
        }

        return DetectionResult(
            matches: result.matches,
            riskScore: max(result.riskScore, scoring.needsReviewThreshold),
            verdict: .needsReview
        )
    }
}

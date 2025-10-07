import Foundation
import Observation
import os

@MainActor
@Observable
final class AppEnvironment {
    struct CaptureOptions: Sendable {
        var prefersDataScanner: Bool = true
    }

    let detectionEngine: DetectionEngine
    let dictionary: DetectDictionary
    let normalizer: TextNormalizer
    let textAcquisition: TextAcquisitionService
    var captureOptions: CaptureOptions

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "Detection")
    private let signposter = OSSignposter(subsystem: "co.ouchieco.PungentRoots", category: "Detection")

    init(
        dictionary: DetectDictionary,
        normalizer: TextNormalizer = TextNormalizer(),
        scoring: DetectionScoring = .default,
        captureOptions: CaptureOptions = .init()
    ) {
        self.dictionary = dictionary
        self.normalizer = normalizer
        self.detectionEngine = DetectionEngine(dictionary: dictionary, normalizer: normalizer, scoring: scoring)
        self.textAcquisition = TextAcquisitionService(normalizer: normalizer)
        self.captureOptions = captureOptions

#if canImport(MetricKit)
        _ = MetricReporter.shared
#endif
    }

    func analyze(_ rawText: String) -> (normalized: String, result: DetectionResult) {
        let signpostID = signposter.makeSignpostID()
        let interval = signposter.beginInterval("SynchronousAnalyze", id: signpostID)
        let start = DispatchTime.now()
        let analysis = detectionEngine.analyze(rawText: rawText)
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        signposter.endInterval("SynchronousAnalyze", interval)
        logger.debug("Detection completed in \(duration, format: .fixed(precision: 2))ms (\(analysis.result.matches.count) matches)")
        return analysis
    }

    func analyzeAsync(_ rawText: String) async -> (normalized: String, result: DetectionResult) {
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
        return (result.0, result.1)
    }
}

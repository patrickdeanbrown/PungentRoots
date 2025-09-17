import Foundation
import os

@MainActor
final class AppEnvironment: ObservableObject {
    let detectionEngine: DetectionEngine
    let dictionary: DetectDictionary
    let normalizer: TextNormalizer
    let textAcquisition: TextAcquisitionService
    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "Detection")

    init(dictionary: DetectDictionary, normalizer: TextNormalizer = TextNormalizer()) {
        self.dictionary = dictionary
        self.normalizer = normalizer
        self.detectionEngine = DetectionEngine(dictionary: dictionary, normalizer: normalizer)
        self.textAcquisition = TextAcquisitionService(normalizer: normalizer)
    }

    func analyze(_ rawText: String) -> (normalized: String, result: DetectionResult) {
        let start = DispatchTime.now()
        let analysis = detectionEngine.analyze(rawText: rawText)
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        logger.debug("Detection completed in \(duration, format: .fixed(precision: 2))ms (\(analysis.result.matches.count) matches)")
        return analysis
    }
}

import Foundation
import os
import Vision

struct TextAcquisitionService {
    struct RecognizedText {
        let raw: String
        let normalized: String
    }

    enum Source {
        case cgImage(CGImage)
        case imageData(Data)
    }

    enum Error: Swift.Error {
        case unsupportedImage
        case recognitionFailed(Swift.Error)
        case noTextFound
    }

    private let normalizer: TextNormalizer
    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "TextAcquisition")

    init(normalizer: TextNormalizer = TextNormalizer()) {
        self.normalizer = normalizer
    }

    func recognize(from source: Source) async throws -> RecognizedText {
        let start = DispatchTime.now()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        request.revision = VNRecognizeTextRequestRevision3

        let observations: [VNRecognizedTextObservation]
        do {
            switch source {
            case .cgImage(let cgImage):
                let handler = VNImageRequestHandler(cgImage: cgImage)
                try handler.perform([request])
            case .imageData(let data):
                let handler = VNImageRequestHandler(data: data)
                try handler.perform([request])
            }
            observations = request.results ?? []
        } catch {
            throw Error.recognitionFailed(error)
        }

        let topCandidates = observations.compactMap { $0.topCandidates(1).first?.string }
        guard topCandidates.isEmpty == false else {
            throw Error.noTextFound
        }

        let recognized = makeRecognizedText(from: topCandidates)
        let duration = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        logger.debug("OCR completed in \(duration, format: .fixed(precision: 2))ms with \(topCandidates.count) lines")
        return recognized
    }

    func makeRecognizedText(from strings: [String]) -> RecognizedText {
        let joined = strings.joined(separator: "\n")
        return RecognizedText(raw: joined, normalized: normalizer.normalize(joined))
    }
}

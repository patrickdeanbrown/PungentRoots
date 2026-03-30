import Foundation
import os
import CoreGraphics
import Vision
#if os(iOS)
import UIKit
#endif

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
    private let ocrConfig: OCRConfiguration
    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "TextAcquisition")

    init(normalizer: TextNormalizer = TextNormalizer(), ocrConfig: OCRConfiguration = .default) {
        self.normalizer = normalizer
        self.ocrConfig = ocrConfig
    }

    func recognize(from source: Source) async throws -> RecognizedText {
        let start = DispatchTime.now()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = ocrConfig.recognitionLevel
        request.usesLanguageCorrection = ocrConfig.usesLanguageCorrection
        request.recognitionLanguages = ocrConfig.recognitionLanguages
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

    func recognizePackaging(from source: Source) async throws -> CapturedLabel {
        let prepared = try prepareImage(from: source)
        let blocks = try recognizeBlocks(in: RecognitionJob(cgImage: prepared.cgImage))
        let mergedBlocks = PackagingTextAnalyzer.mergeBlocks(blocks)

        guard mergedBlocks.isEmpty == false else {
            throw Error.noTextFound
        }

        let rawText = mergedBlocks.map(\.text).joined(separator: "\n")
        let coverageStatus = PackagingTextAnalyzer.coverageStatus(for: mergedBlocks, rawText: rawText)
        let warnings = PackagingTextAnalyzer.warnings(for: coverageStatus, rawText: rawText)

        logger.debug(
            "Packaging OCR completed with \(mergedBlocks.count, privacy: .public) blocks coverage=\(coverageStatus.rawValue, privacy: .public)"
        )

        return CapturedLabel(
            imageData: prepared.imageData,
            recognizedBlocks: mergedBlocks,
            rawText: rawText,
            coverageStatus: coverageStatus,
            warnings: warnings
        )
    }

    func makeRecognizedText(from strings: [String]) -> RecognizedText {
        let joined = strings.joined(separator: "\n")
        return RecognizedText(raw: joined, normalized: normalizer.normalize(joined))
    }

    private func prepareImage(from source: Source) throws -> PreparedImage {
        switch source {
        case .cgImage(let cgImage):
            return PreparedImage(cgImage: cgImage, imageData: nil)
        case .imageData(let data):
#if os(iOS)
            guard let image = UIImage(data: data), let normalized = image.normalizedOrientationImage() else {
                throw Error.unsupportedImage
            }
        return PreparedImage(cgImage: normalized, imageData: data)
#else
            throw Error.unsupportedImage
#endif
        }
    }

    private func recognizeBlocks(in job: RecognitionJob) throws -> [RecognizedTextBlock] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = ocrConfig.recognitionLevel
        request.usesLanguageCorrection = ocrConfig.usesLanguageCorrection
        request.recognitionLanguages = ocrConfig.recognitionLanguages
        request.minimumTextHeight = ocrConfig.minimumTextHeight
        request.revision = ocrConfig.revision

        let handler = VNImageRequestHandler(cgImage: job.cgImage)
        do {
            try handler.perform([request])
        } catch {
            throw Error.recognitionFailed(error)
        }

        let observations = request.results ?? []
        return observations.compactMap { observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return nil }
            guard candidate.confidence >= ocrConfig.confidenceThreshold else { return nil }
            return RecognizedTextBlock(
                text: trimmed,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence
            )
        }
    }

    private struct PreparedImage {
        let cgImage: CGImage
        let imageData: Data?
    }

    private struct RecognitionJob {
        let cgImage: CGImage
    }
}

#if os(iOS)
private extension UIImage {
    func normalizedOrientationImage() -> CGImage? {
        if imageOrientation == .up, let cgImage {
            return cgImage
        }

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        return image.cgImage
    }
}
#endif

import CoreGraphics
import Foundation

enum PackagingTextAnalyzer {
    static func mergeBlocks(_ blocks: [RecognizedTextBlock]) -> [RecognizedTextBlock] {
        let sorted = blocks.sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.text.count > rhs.text.count
            }
            return lhs.confidence > rhs.confidence
        }

        var merged: [RecognizedTextBlock] = []
        for block in sorted {
            let normalizedText = normalizedKey(for: block.text)
            if let existingIndex = merged.firstIndex(where: { existing in
                let existingText = normalizedKey(for: existing.text)
                let overlap = intersectionOverUnion(block.boundingBox, existing.boundingBox)
                let sameLine = abs(block.boundingBox.midY - existing.boundingBox.midY) < 0.03
                let textMatches = existingText == normalizedText
                return overlap > 0.72 || (sameLine && textMatches)
            }) {
                let existing = merged[existingIndex]
                if block.confidence > existing.confidence || block.text.count > existing.text.count {
                    merged[existingIndex] = block
                }
                continue
            }
            merged.append(block)
        }

        return merged.sorted(by: readingOrder)
    }

    static func coverageStatus(for blocks: [RecognizedTextBlock], rawText: String) -> OCRCoverageStatus {
        let text = rawText.lowercased()
        let ingredientIndicators = ["ingredients", "ingredient:"]
        let footerIndicators = [
            "distributed by",
            "dist. & sold",
            "dist & sold",
            "contains sesame",
            "contains soy",
            "trader joe",
            "product of",
            "keep refrigerated",
            "net wt"
        ]

        var score = 0
        if ingredientIndicators.contains(where: text.contains) { score += 3 }

        let commaCount = rawText.filter { $0 == "," }.count
        switch commaCount {
        case 4...:
            score += 2
        case 2...:
            score += 1
        default:
            break
        }

        switch blocks.count {
        case 8...:
            score += 2
        case 4...:
            score += 1
        default:
            break
        }

        let textCoverage = blocks.reduce(CGFloat.zero) { partialResult, block in
            partialResult + (block.boundingBox.width * block.boundingBox.height)
        }
        switch textCoverage {
        case 0.18...:
            score += 2
        case 0.08...:
            score += 1
        default:
            break
        }

        let footerHitCount = footerIndicators.reduce(into: 0) { total, indicator in
            if text.contains(indicator) {
                total += 1
            }
        }

        if footerHitCount >= 2 && ingredientIndicators.contains(where: text.contains) == false {
            score -= 2
        }
        if commaCount == 0 && blocks.count < 4 {
            score -= 2
        }

        if score >= 5 {
            return .complete
        } else if score >= 2 {
            return .partial
        } else {
            return .insufficient
        }
    }

    static func warnings(for coverageStatus: OCRCoverageStatus, rawText: String) -> [String] {
        switch coverageStatus {
        case .complete:
            return []
        case .partial:
            return ["This scan may not include the full ingredient list. Review the package and retake if needed."]
        case .insufficient:
            if rawText.lowercased().contains("contains ") {
                return ["Only footer or allergen text was read. Retake the photo with the ingredient list centered and fully visible."]
            }
            return ["Only partial packaging text was read. The ingredient list may be missing from this scan."]
        }
    }

    private static func normalizedKey(for text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    private static func readingOrder(lhs: RecognizedTextBlock, rhs: RecognizedTextBlock) -> Bool {
        if abs(lhs.boundingBox.midY - rhs.boundingBox.midY) > 0.03 {
            return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
    }

    private static func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard intersection.isNull == false else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = (lhs.width * lhs.height) + (rhs.width * rhs.height) - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}

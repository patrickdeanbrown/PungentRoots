import Foundation
import Testing
@testable import PungentRoots

struct DetectionEngineTests {
    private let dictionary: DetectDictionary = {
        do {
            return try DictionaryLoader().load()
        } catch {
            fatalError("Failed to load detection dictionary: \(error)")
        }
    }()

    @Test("Onion powder triggers contains verdict")
    func onionPowderContains() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Ingredients: wheat flour, onion powder, salt"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.verdict == .contains)
        #expect(analysis.result.matches.contains { $0.kind == .definite })
    }

    @Test("Ambiguous terms lead to needs review")
    func ambiguousNeedsReview() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Ingredients: vegetable stock, spices, paprika"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.verdict == .needsReview)
        #expect(analysis.result.riskScore >= 0.3)
        #expect(analysis.result.matches.contains { $0.kind == .ambiguous })
    }

    @Test("Safe list stays safe")
    func safeIngredientsRemainSafe() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Ingredients: wheat flour, sugar, cocoa, salt"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.verdict == .safe)
        #expect(analysis.result.matches.isEmpty)
        #expect(analysis.result.riskScore == 0)
    }

    @Test("Fuzzy matching ignores suffix terms")
    func fuzzyIgnoresSuffixOnlyTokens() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Ingredients: sea salt, seasoning blend"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.matches.allSatisfy { $0.kind != .fuzzy })
        #expect(analysis.result.verdict == .needsReview)
    }

    @Test("Calcium does not trigger allium match")
    func calciumIsIgnored() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Additives: calcium carbonate, vitamins"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.matches.isEmpty)
        #expect(analysis.result.verdict == .safe)
    }

    @Test("Plain oil is not flagged")
    func oilIsIgnored() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Ingredients: expeller pressed canola oil, sea salt"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.matches.isEmpty)
        #expect(analysis.result.verdict == .safe)
    }

    @Test("Natural flavors remain unflagged")
    func naturalFlavorsIgnored() {
        let engine = DetectionEngine(dictionary: dictionary)
        let sample = "Ingredients: carbonated water, natural flavors"
        let analysis = engine.analyze(rawText: sample)

        #expect(analysis.result.matches.isEmpty)
        #expect(analysis.result.verdict == .safe)
    }

    @Test("Async analyzer matches synchronous detection results")
    @MainActor
    func asyncAnalyzerMatchesSync() async {
        let environment = AppEnvironment(dictionary: dictionary)
        let sample = "Ingredients: wheat flour, onion powder, salt"

        let syncResult = environment.analyze(sample)
        let asyncResult = await environment.analyzeAsync(sample)

        #expect(asyncResult.normalizedText == syncResult.normalizedText)
        #expect(asyncResult.result.matches == syncResult.result.matches)
        #expect(asyncResult.result.verdict == syncResult.result.verdict)
        #expect(asyncResult.coverageStatus == .complete)
    }

    @Test("Footer-only packaging text requires review")
    @MainActor
    func footerOnlyTextRequiresReview() {
        let environment = AppEnvironment(dictionary: dictionary)
        let label = CapturedLabel(
            imageData: nil,
            recognizedBlocks: [
                RecognizedTextBlock(
                    text: "Contains Sesame. Dist & sold exclusively by Trader Joe's",
                    boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.12),
                    confidence: 0.94
                )
            ],
            rawText: "Contains Sesame. Dist & sold exclusively by Trader Joe's",
            coverageStatus: .insufficient,
            warnings: PackagingTextAnalyzer.warnings(
                for: .insufficient,
                rawText: "Contains Sesame. Dist & sold exclusively by Trader Joe's"
            )
        )

        let analysis = environment.analyzeCapturedLabel(label)

        #expect(analysis.result.verdict == .needsReview)
        #expect(analysis.coverageStatus == .insufficient)
        #expect(analysis.warnings.isEmpty == false)
    }

    @Test("Packaging text merge removes duplicated OCR blocks")
    func packagingMergeDeduplicatesRepeatedBlocks() {
        let blocks = [
            RecognizedTextBlock(text: "Ingredients", boundingBox: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.06), confidence: 0.82),
            RecognizedTextBlock(text: "Ingredients", boundingBox: CGRect(x: 0.11, y: 0.79, width: 0.3, height: 0.06), confidence: 0.93),
            RecognizedTextBlock(text: "Onion Powder", boundingBox: CGRect(x: 0.1, y: 0.7, width: 0.4, height: 0.08), confidence: 0.9)
        ]

        let merged = PackagingTextAnalyzer.mergeBlocks(blocks)

        #expect(merged.count == 2)
        #expect(merged.first?.confidence == 0.93)
    }

    @Test("Coverage classification prefers complete ingredient panels")
    func coverageClassifierPrefersIngredientPanels() {
        let blocks = [
            RecognizedTextBlock(text: "Ingredients", boundingBox: CGRect(x: 0.1, y: 0.82, width: 0.28, height: 0.06), confidence: 0.94),
            RecognizedTextBlock(text: "Potatoes, sunflower oil, onion powder, garlic powder, sea salt", boundingBox: CGRect(x: 0.08, y: 0.62, width: 0.84, height: 0.18), confidence: 0.92),
            RecognizedTextBlock(text: "Paprika, yeast extract, spices", boundingBox: CGRect(x: 0.08, y: 0.46, width: 0.78, height: 0.12), confidence: 0.88),
            RecognizedTextBlock(text: "Distributed by Trader Joe's", boundingBox: CGRect(x: 0.1, y: 0.14, width: 0.52, height: 0.06), confidence: 0.9)
        ]

        let status = PackagingTextAnalyzer.coverageStatus(
            for: blocks,
            rawText: blocks.map(\.text).joined(separator: "\n")
        )

        #expect(status == .complete)
    }
}

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

        #expect(asyncResult.normalized == syncResult.normalized)
        #expect(asyncResult.result.matches == syncResult.result.matches)
        #expect(asyncResult.result.verdict == syncResult.result.verdict)
    }
}

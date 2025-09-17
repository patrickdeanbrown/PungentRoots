import Foundation
import Testing
@testable import PungentRoots

struct DetectionFixtureTests {
    private let engine: DetectionEngine = {
        do {
            let dictionary = try DictionaryLoader().load()
            return DetectionEngine(dictionary: dictionary)
        } catch {
            fatalError("Failed to load detection dictionary: \(error)")
        }
    }()

    @Test("Contains fixtures evaluate to contains verdict")
    func containsFixtures() {
        for sample in DetectionFixtures.containsSamples {
            let analysis = engine.analyze(rawText: sample)
            #expect(analysis.result.verdict == .contains, "Expected contains for \(sample)")
        }
    }

    @Test("Ambiguous fixtures evaluate to needs review")
    func ambiguousFixtures() {
        for sample in DetectionFixtures.ambiguousSamples {
            let analysis = engine.analyze(rawText: sample)
            #expect(analysis.result.verdict != .safe, "Expected non-safe verdict for \(sample)")
        }
    }

    @Test("Safe fixtures stay safe")
    func safeFixtures() {
        for sample in DetectionFixtures.safeSamples {
            let analysis = engine.analyze(rawText: sample)
            #expect(analysis.result.verdict != .contains, "Expected non-contains verdict for \(sample)")
        }
    }
}

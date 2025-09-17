import Foundation
import Testing
@testable import PungentRoots

struct TextNormalizerTests {
    private let normalizer = TextNormalizer()

    @Test("Hyphenated line breaks are removed")
    func removesHyphenation() {
        let input = "dehy-\n drated garlic"
        let normalized = normalizer.normalize(input)
        #expect(normalized.contains("dehydrated garlic"))
    }

    @Test("Bullets and excess whitespace collapse")
    func removesBullets() {
        let input = "• Onion Powder\n  - Garlic Salt\n\tChives"
        let normalized = normalizer.normalize(input)
        #expect(normalized == "onion powder garlic salt chives")
    }

    @Test("Tokenizes with ranges")
    func tokenizesWithRanges() {
        let input = "Onion powder and garlic".lowercased()
        let tokens = normalizer.tokens(in: input)
        #expect(tokens.count == 4)
        #expect(tokens.first?.text == "onion")
        #expect(tokens[1].text == "powder")
    }
}

import Foundation
import NaturalLanguage

struct TextNormalizer {
    struct Token: Sendable {
        let text: Substring
        let range: Range<Int>
    }

    func normalize(_ input: String) -> String {
        let nfkc = input.precomposedStringWithCompatibilityMapping
        let lowered = nfkc.lowercased()
        let noHyphenBreaks = lowered.replacingOccurrences(
            of: "-\\s*\\n\\s*",
            with: "",
            options: [.regularExpression]
        )
        let cleanedBullets = noHyphenBreaks.replacingOccurrences(
            of: "(?m)^\\s*[\\u2022\\-*]+\\s*",
            with: "",
            options: [.regularExpression]
        )
        let singleSpaced = cleanedBullets.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: [.regularExpression]
        )
        return singleSpaced.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    func tokens(in normalized: String) -> [Token] {
        var tokens = [Token]()
        let tagger = NLTagger(tagSchemes: [.tokenType])
        tagger.string = normalized
        tagger.enumerateTags(
            in: normalized.startIndex..<normalized.endIndex,
            unit: .word,
            scheme: .tokenType,
            options: [.omitWhitespace, .omitPunctuation]
        ) { _, range -> Bool in
            let substring = normalized[range]
            let lower = range.lowerBound.utf16Offset(in: normalized)
            let upper = range.upperBound.utf16Offset(in: normalized)
            tokens.append(Token(text: substring, range: lower..<upper))
            return true
        }
        return tokens
    }
}

import Foundation

struct DetectionEngine {
    private let dictionary: DetectDictionary
    private let normalizer: TextNormalizer
    private let scoring: DetectionScoring

    init(dictionary: DetectDictionary, normalizer: TextNormalizer = TextNormalizer(), scoring: DetectionScoring = .default) {
        self.dictionary = dictionary
        self.normalizer = normalizer
        self.scoring = scoring
    }

    func analyze(rawText: String) -> (normalized: String, result: DetectionResult) {
        let normalized = normalizer.normalize(rawText)
        let result = detect(in: normalized)
        return (normalized, result)
    }

    func detect(in normalized: String) -> DetectionResult {
        guard !normalized.isEmpty else {
            return DetectionResult(matches: [], riskScore: 0, verdict: .safe)
        }

        var matches = [Match]()
        var strongScore = 0.0
        var ambiguousScore = 0.0
        var hasDefinite = false

        func addMatch(_ match: Match, scoreContribution: Double, isDefinite: Bool = false, isAmbiguous: Bool = false) {
            matches.append(match)
            if isDefinite {
                hasDefinite = true
            }
            if isDefinite {
                strongScore = scoring.maxScore
                return
            }
            if isAmbiguous {
                ambiguousScore = min(scoring.maxAmbiguousScore, ambiguousScore + scoreContribution)
            } else {
                strongScore = min(scoring.maxScore, strongScore + scoreContribution)
            }
        }

        // Exact matches (definite + synonyms)
        for term in dictionary.definite {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "\\b"
            for range in normalized.ranges(of: pattern) {
                let match = Match(term: term, kind: .definite, range: range, note: "Exact match")
                addMatch(match, scoreContribution: scoring.definiteMatchScore, isDefinite: true)
            }
        }

        for term in dictionary.synonyms {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "\\b"
            for range in normalized.ranges(of: pattern) {
                let match = Match(term: term, kind: .synonym, range: range, note: "Synonym match")
                addMatch(match, scoreContribution: scoring.synonymMatchScore)
            }
        }

        // Pattern matches
        for pattern in dictionary.patterns {
            for range in normalized.ranges(of: pattern, options: [.caseInsensitive]) {
                let snippet = snippet(in: normalized, range: range)
                let match = Match(term: snippet, kind: .pattern, range: range, note: "Pattern match")
                addMatch(match, scoreContribution: scoring.patternMatchScore)
            }
        }

        // Ambiguous terms
        for term in dictionary.ambiguous {
            let pattern = "\\b" + NSRegularExpression.escapedPattern(for: term) + "\\b"
            for range in normalized.ranges(of: pattern) {
                let snippet = snippet(in: normalized, range: range)
                let match = Match(term: snippet, kind: .ambiguous, range: range, note: "Ambiguous ingredient")
                addMatch(match, scoreContribution: scoring.ambiguousMatchScore, isAmbiguous: true)
            }
        }

        // Fuzzy matches
        let tokens = normalizer.tokens(in: normalized)
        let canonicalTargets = canonicalTokenTargets()
        var recordedFuzzyTokens = Set<String>()

        let fuzzyExclusions: Set<String> = [
            "calcium", "calciums", "natural", "flavor", "flavors", "flavour", "flavours", "oil", "oils"
        ]

        for token in tokens {
            let tokenString = String(token.text)
            let lowercasedToken = tokenString.lowercased()
            guard recordedFuzzyTokens.contains(lowercasedToken) == false else { continue }
            guard lowercasedToken.count > 3 else { continue }
            guard fuzzyExclusions.contains(lowercasedToken) == false else { continue }
            let threshold = lowercasedToken.count <= 6 ? 1 : 2
            var bestTarget: String?
            for target in canonicalTargets {
                let distance = levenshtein(lowercasedToken, target)
                if distance <= threshold {
                    bestTarget = target
                    break
                }
            }
            guard let target = bestTarget else { continue }
            recordedFuzzyTokens.insert(lowercasedToken)
            let note = "Possible OCR error: \(target)"
            let match = Match(term: tokenString, kind: .fuzzy, range: token.range, note: note)
            addMatch(match, scoreContribution: scoring.fuzzyMatchScore)
        }

        let coreScore = hasDefinite ? scoring.maxScore : max(strongScore, ambiguousScore)
        let verdict: Verdict
        switch coreScore {
        case scoring.containsThreshold...:
            verdict = .contains
        case scoring.needsReviewThreshold...:
            verdict = .needsReview
        default:
            verdict = .safe
        }

        return DetectionResult(matches: matches, riskScore: coreScore, verdict: verdict)
    }

    private func canonicalTokenTargets() -> [String] {
        let ignoredSuffixes: Set<String> = [
            "powder", "salt", "extract", "granules", "flakes", "oil", "base", "paste", "mix", "granule"
        ]
        let singleWordTerms = (dictionary.definite + dictionary.synonyms)
            .map { $0.lowercased() }
            .filter { term in
                guard term.contains(" ") == false else { return false }
                return ignoredSuffixes.contains(term) == false
            }
        let hints = dictionary.fuzzyHints.map { $0.lowercased() }
        return Array(Set(singleWordTerms + hints))
    }

    private func snippet(in text: String, range: Range<Int>) -> String {
        guard range.lowerBound >= 0, range.upperBound <= text.utf16.count else { return text }
        let start = String.Index(utf16Offset: range.lowerBound, in: text)
        let end = String.Index(utf16Offset: range.upperBound, in: text)
        return String(text[start..<end])
    }

    private func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        if lhs == rhs { return 0 }
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        let lhsCount = lhsChars.count
        let rhsCount = rhsChars.count

        if lhsCount == 0 || rhsCount == 0 { return max(lhsCount, rhsCount) }

        var distances = Array(repeating: Array(repeating: 0, count: rhsCount + 1), count: lhsCount + 1)

        for i in 0...lhsCount { distances[i][0] = i }
        for j in 0...rhsCount { distances[0][j] = j }

        for i in 1...lhsCount {
            for j in 1...rhsCount {
                let cost = lhsChars[i - 1] == rhsChars[j - 1] ? 0 : 1
                distances[i][j] = min(
                    distances[i - 1][j] + 1,
                    distances[i][j - 1] + 1,
                    distances[i - 1][j - 1] + cost
                )
            }
        }

        return distances[lhsCount][rhsCount]
    }
}

import Foundation

/// Centralized configuration for detection scoring and thresholds
struct DetectionScoring: Sendable {
    // MARK: - Match Score Contributions

    /// Score contribution for definite matches (exact term matches)
    /// These are high-confidence matches that immediately flag the product
    let definiteMatchScore: Double

    /// Score contribution for synonym matches
    /// Alternative names for the same ingredient (e.g., "allium" for onion family)
    let synonymMatchScore: Double

    /// Score contribution for pattern matches
    /// Regex-based matches like "dehydrated onion"
    let patternMatchScore: Double

    /// Score contribution for ambiguous matches
    /// Terms that could indicate presence but need review (e.g., "stock")
    let ambiguousMatchScore: Double

    /// Score contribution for fuzzy matches
    /// OCR error corrections (e.g., "garilc" -> "garlic")
    let fuzzyMatchScore: Double

    // MARK: - Score Caps

    /// Maximum accumulated ambiguous score
    /// Prevents many low-confidence matches from triggering false positives
    let maxAmbiguousScore: Double

    /// Maximum total score (typically 1.0)
    let maxScore: Double

    // MARK: - Verdict Thresholds

    /// Minimum score for "contains" verdict (high confidence)
    let containsThreshold: Double

    /// Minimum score for "needs review" verdict (medium confidence)
    let needsReviewThreshold: Double

    // Below needsReviewThreshold = "safe" verdict

    // MARK: - Default Configuration

    /// Default scoring optimized for ingredient detection
    static let `default` = DetectionScoring(
        definiteMatchScore: 1.0,      // Immediately conclusive
        synonymMatchScore: 0.8,        // High confidence alternate name
        patternMatchScore: 0.8,        // High confidence regex match
        ambiguousMatchScore: 0.3,      // Low confidence, multiple needed
        fuzzyMatchScore: 0.7,          // Moderate confidence OCR correction
        maxAmbiguousScore: 0.6,        // Cap prevents false positives
        maxScore: 1.0,                 // Normalized maximum
        containsThreshold: 0.8,        // High confidence threshold
        needsReviewThreshold: 0.3      // Low confidence threshold
    )

    /// Conservative scoring with higher thresholds
    static let conservative = DetectionScoring(
        definiteMatchScore: 1.0,
        synonymMatchScore: 0.7,
        patternMatchScore: 0.7,
        ambiguousMatchScore: 0.2,
        fuzzyMatchScore: 0.5,
        maxAmbiguousScore: 0.5,
        maxScore: 1.0,
        containsThreshold: 0.9,
        needsReviewThreshold: 0.5
    )

    /// Aggressive scoring with lower thresholds (fewer false negatives)
    static let aggressive = DetectionScoring(
        definiteMatchScore: 1.0,
        synonymMatchScore: 0.9,
        patternMatchScore: 0.9,
        ambiguousMatchScore: 0.4,
        fuzzyMatchScore: 0.8,
        maxAmbiguousScore: 0.7,
        maxScore: 1.0,
        containsThreshold: 0.7,
        needsReviewThreshold: 0.2
    )
}

import Foundation
import SwiftData

@Model
final class Scan {
    @Attribute(.unique) var id: String
    @Attribute(.preserveValueOnDeletion) var createdAt: Date
    var source: ScanSource
    var rawText: String
    var normalizedText: String
    var verdict: Verdict
    var riskScore: Double
    var matches: [Match]
    var thumbnailPNG: Data?
    var userOverride: Verdict?
    var dictionaryVersion: String

    init(
        id: String = UUID().uuidString,
        createdAt: Date = .now,
        source: ScanSource,
        rawText: String,
        normalizedText: String,
        verdict: Verdict,
        riskScore: Double,
        matches: [Match],
        thumbnailPNG: Data? = nil,
        userOverride: Verdict? = nil,
        dictionaryVersion: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.source = source
        self.rawText = rawText
        self.normalizedText = normalizedText
        self.verdict = verdict
        self.riskScore = riskScore
        self.matches = matches
        self.thumbnailPNG = thumbnailPNG
        self.userOverride = userOverride
        self.dictionaryVersion = dictionaryVersion
    }
}

enum ScanSource: String, Codable, CaseIterable, Hashable {
    case photo
    case paste
}

enum Verdict: String, Codable, CaseIterable, Hashable {
    case safe
    case needsReview
    case contains
}

struct Match: Codable, Hashable, Sendable {
    var term: String
    var kind: MatchKind
    var range: Range<Int>
    var note: String

    init(term: String, kind: MatchKind, range: Range<Int>, note: String) {
        self.term = term
        self.kind = kind
        self.range = range
        self.note = note
    }
}

enum MatchKind: String, Codable, CaseIterable, Hashable {
    case definite
    case synonym
    case pattern
    case ambiguous
    case fuzzy
}

struct DetectionResult {
    let matches: [Match]
    let riskScore: Double
    let verdict: Verdict
}

import SwiftUI

struct DetectionResultView: View {
    let normalizedText: String
    let result: DetectionResult
    @Binding var isShowingFullText: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            matchesSection
            disclosureSection
        }
    }

    private var matchesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if uniqueMatches.isEmpty {
                Text("No matches were detected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Matches")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                AdaptiveBadgeGrid(items: uniqueMatches) { summary in
                    MatchBadge(summary: summary)
                }
            }
        }
    }

    private var disclosureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingFullText.toggle()
                }
            } label: {
                Label(isShowingFullText ? "Hide scanned text" : "Show full scanned text", systemImage: "text.magnifyingglass")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("toggle-scanned-text")

            if isShowingFullText {
                HighlightedTextView(text: normalizedText, matches: result.matches)
                    .frame(maxHeight: 260)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var uniqueMatches: [MatchSummary] {
        var accumulator: [String: MatchAccumulator] = [:]

        for match in result.matches {
            let key = match.term.lowercased()
            let display = displayName(for: match.term)
            let current = accumulator[key]
            let bestKind = mergeKind(current?.kind, with: match.kind)
            accumulator[key] = MatchAccumulator(term: display, kind: bestKind, count: (current?.count ?? 0) + 1)
        }

        return accumulator.values
            .map { MatchSummary(term: $0.term, kind: $0.kind, count: $0.count) }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.term < rhs.term
                }
                return lhs.priority > rhs.priority
            }
    }

    private func displayName(for term: String) -> String {
        return term.localizedCapitalized
    }

    struct MatchSummary: Identifiable, Hashable {
        let term: String
        let kind: MatchKind
        let count: Int

        var id: String { term.lowercased() }

        var priority: Int {
            kind.priority
        }
    }

    private struct MatchAccumulator {
        let term: String
        let kind: MatchKind
        let count: Int
    }

    private func mergeKind(_ existing: MatchKind?, with newKind: MatchKind) -> MatchKind {
        guard let existing else { return newKind }
        if newKind.priority > existing.priority {
            return newKind
        }
        return existing
    }

    private struct MatchBadge: View {
        let summary: MatchSummary

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .imageScale(.small)
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(tint.opacity(0.15), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.term)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if summary.count > 1 {
                        Text("x\(summary.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(tint.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(0.4), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint("Severity: \(severityDescription)")
            .accessibilitySortPriority(Double(summary.priority))
        }

        private var icon: String {
            switch summary.kind {
            case .definite:
                return "exclamationmark.triangle.fill"
            case .synonym, .pattern:
                return "exclamationmark.circle.fill"
            case .ambiguous, .fuzzy:
                return "questionmark.circle.fill"
            }
        }

        private var tint: Color {
            switch summary.kind {
            case .definite:
                return Color(red: 0.86, green: 0.18, blue: 0.24)
            case .synonym, .pattern:
                return Color(red: 0.96, green: 0.55, blue: 0.19)
            case .ambiguous, .fuzzy:
                return Color(red: 0.98, green: 0.82, blue: 0.24)
            }
        }

        private var label: String {
            switch summary.kind {
            case .definite:
                return "Pungent root detected: \(summary.term)"
            case .synonym, .pattern:
                return "Likely match: \(summary.term)"
            case .ambiguous, .fuzzy:
                return "Needs review: \(summary.term)"
            }
        }

        private var severityDescription: String {
            switch summary.kind {
            case .definite:
                return "High"
            case .synonym, .pattern:
                return "Medium"
            case .ambiguous, .fuzzy:
                return "Needs review"
            }
        }
    }
}

private struct AdaptiveBadgeGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                content(item)
            }
        }
    }
}

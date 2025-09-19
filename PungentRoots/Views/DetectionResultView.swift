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
            if result.matches.isEmpty {
                Text("No matches were detected.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Matches")
                    .font(.headline)
                ForEach(result.matches, id: \.self) { match in
                    Text(match.term)
                        .font(.body)
                        .foregroundStyle(color(for: match))
                        .accessibilityLabel(accessibilityLabel(for: match))
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

    private func color(for match: Match) -> Color {
        switch match.kind {
        case .definite, .synonym, .pattern:
            return .red
        case .ambiguous, .fuzzy:
            return .yellow
        }
    }

    private func accessibilityLabel(for match: Match) -> String {
        switch match.kind {
        case .definite, .synonym, .pattern:
            return "Likely pungent root: \(match.term)"
        case .ambiguous, .fuzzy:
            return "Possible match: \(match.term)"
        }
    }
}

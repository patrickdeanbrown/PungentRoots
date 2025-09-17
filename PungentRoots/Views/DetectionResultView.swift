import SwiftUI

struct DetectionResultView: View {
    let normalizedText: String
    let result: DetectionResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            verdictHeader
            HighlightedTextView(text: normalizedText, matches: result.matches)
                .frame(maxHeight: 260)
            matchList
        }
        .padding()
    }

    private var verdictHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
            VStack(alignment: .leading) {
                Text(verdictText)
                    .font(.headline)
                Text(String(format: "Risk score: %.2f", result.riskScore))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(iconColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Verdict: \(verdictText). Risk score \(String(format: "%.2f", result.riskScore))")
    }

    private var matchList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matches")
                .font(.headline)
            if result.matches.isEmpty {
                Text("No matches found.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(result.matches, id: \.self) { match in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.term)
                            .font(.subheadline)
                            .bold()
                        Text(match.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var iconName: String {
        switch result.verdict {
        case .contains:
            return "exclamationmark.triangle.fill"
        case .needsReview:
            return "questionmark.circle.fill"
        case .safe:
            return "checkmark.seal.fill"
        }
    }

    private var verdictText: String {
        switch result.verdict {
        case .contains:
            return "Contains pungent roots"
        case .needsReview:
            return "Needs review"
        case .safe:
            return "Safe"
        }
    }

    private var iconColor: Color {
        switch result.verdict {
        case .contains:
            return .red
        case .needsReview:
            return .orange
        case .safe:
            return .green
        }
    }
}

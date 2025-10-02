import SwiftUI

struct HighlightedTextView: View {
    let text: String
    let matches: [Match]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Legend
                HStack(spacing: 16) {
                    legendItem(color: highColor, label: "High")
                    legendItem(color: mediumColor, label: "Medium")
                    legendItem(color: reviewColor, label: "Review")
                }
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                // Highlighted text
                Text(makeAttributedString())
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.tertiarySystemBackground))
                    )
            }
            .padding(.vertical, 4)
        }
        .background(Color(.systemBackground))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // Match the severity colors from DetectionOverlay
    private var highColor: Color {
        Color(red: 0.86, green: 0.18, blue: 0.24) // Red for definite
    }

    private var mediumColor: Color {
        Color(red: 0.96, green: 0.55, blue: 0.19) // Orange for synonym/pattern
    }

    private var reviewColor: Color {
        Color(red: 0.98, green: 0.82, blue: 0.24) // Yellow for ambiguous/fuzzy
    }

    private func makeAttributedString() -> AttributedString {
        var attributed = AttributedString(text)

        // Sort matches by priority (highest first) to ensure definite matches override lower priority ones
        let sortedMatches = matches.sorted { $0.kind.priority > $1.kind.priority }

        for match in sortedMatches {
            let range = NSRange(location: match.range.lowerBound, length: match.range.count)
            guard
                let stringRange = Range(range, in: text),
                let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                let upper = AttributedString.Index(stringRange.upperBound, within: attributed)
            else {
                continue
            }

            var segment = AttributedString(text[stringRange])

            // Apply color and styling based on match kind priority
            switch match.kind {
            case .definite:
                segment.foregroundColor = .white
                segment.backgroundColor = highColor
                segment.font = .body.bold()

            case .synonym, .pattern:
                segment.foregroundColor = .white
                segment.backgroundColor = mediumColor
                segment.font = .body.weight(.semibold)

            case .ambiguous, .fuzzy:
                segment.foregroundColor = .primary
                segment.backgroundColor = reviewColor.opacity(0.4)
                segment.font = .body.weight(.medium)
            }

            attributed.replaceSubrange(lower..<upper, with: segment)
        }
        return attributed
    }
}

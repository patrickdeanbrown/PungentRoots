import SwiftUI

struct HighlightedTextView: View {
    let text: String
    let matches: [Match]

    var body: some View {
        ScrollView {
            Text(makeAttributedString())
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
        }
        .background(Color(.systemBackground))
    }

    private func makeAttributedString() -> AttributedString {
        var attributed = AttributedString(text)
        for match in matches {
            guard let range = Range(NSRange(location: match.range.lowerBound, length: match.range.count), in: text) else { continue }
            guard
                let lower = AttributedString.Index(range.lowerBound, within: attributed),
                let upper = AttributedString.Index(range.upperBound, within: attributed)
            else { continue }
            let attributedRange = lower..<upper
            var segment = AttributedString(text[range])
            switch match.kind {
            case .definite:
                segment.foregroundColor = .red
                segment.font = .body.bold()
            case .synonym, .pattern:
                segment.foregroundColor = .orange
                segment.underlineStyle = .single
            case .ambiguous:
                segment.foregroundColor = .yellow
                segment.backgroundColor = Color.yellow.opacity(0.2)
            case .fuzzy:
                segment.foregroundColor = .pink
            }
            attributed.replaceSubrange(attributedRange, with: segment)
        }
        return attributed
    }
}

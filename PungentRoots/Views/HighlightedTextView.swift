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
            let range = NSRange(location: match.range.lowerBound, length: match.range.count)
            guard
                let stringRange = Range(range, in: text),
                let lower = AttributedString.Index(stringRange.lowerBound, within: attributed),
                let upper = AttributedString.Index(stringRange.upperBound, within: attributed)
            else {
                continue
            }

            var segment = AttributedString(text[stringRange])
            let isCertain = match.kind == .definite || match.kind == .synonym || match.kind == .pattern
            if isCertain {
                segment.foregroundColor = .red
                segment.font = .body.bold()
            } else {
                segment.foregroundColor = .yellow
                segment.backgroundColor = Color.yellow.opacity(0.25)
            }
            attributed.replaceSubrange(lower..<upper, with: segment)
        }
        return attributed
    }
}

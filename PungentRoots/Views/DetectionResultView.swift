import SwiftUI

struct DetectionResultView: View {
    let normalizedText: String
    let result: DetectionResult
    let capturedImage: UIImage?
    let detectionBoxes: [DetectionOverlay]
    @Binding var isShowingFullText: Bool
    let onRescan: () -> Void

    @State private var showingHighInfo = false
    @State private var showingMediumInfo = false
    @State private var showingReviewInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Verdict badge at top with animation
            VerdictBadge(verdict: result.verdict)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: result.verdict)

            if let image = capturedImage, !detectionBoxes.isEmpty {
                capturedImageSection(image: image)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            matchesSection
                .transition(.move(edge: .bottom).combined(with: .opacity))

            disclosureSection
                .transition(.opacity)

            actionButtonsSection
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.easeOut(duration: 0.3), value: result.matches.count)
    }

    @ViewBuilder
    private func capturedImageSection(image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Detected Ingredients")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                Text("Highlighted text shows detected matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            CapturedImageOverlayView(image: image, boxes: detectionBoxes)
                .frame(maxHeight: 300)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
                )
                .accessibilityHint("Tap to view full size")

            // Interactive color legend
            HStack(spacing: 12) {
                interactiveLegendItem(
                    color: Color(red: 0.86, green: 0.18, blue: 0.24),
                    label: "High",
                    description: "Definite pungent roots detected",
                    examples: "Onion, garlic, shallot",
                    isShowing: $showingHighInfo
                )

                interactiveLegendItem(
                    color: Color(red: 0.96, green: 0.55, blue: 0.19),
                    label: "Medium",
                    description: "Likely matches or synonyms",
                    examples: "Onion powder, garlic extract",
                    isShowing: $showingMediumInfo
                )

                interactiveLegendItem(
                    color: Color(red: 0.98, green: 0.82, blue: 0.24),
                    label: "Review",
                    description: "Ambiguous or possible OCR errors",
                    examples: "Stock, garilc (typo)",
                    isShowing: $showingReviewInfo
                )
            }
            .font(.caption2)
        }
    }

    private func interactiveLegendItem(color: Color, label: String, description: String, examples: String, isShowing: Binding<Bool>) -> some View {
        Button {
            isShowing.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(label)
                    .foregroundStyle(.secondary)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(color.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: isShowing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 16, height: 16)
                    Text(label + " Severity")
                        .font(.headline)
                }

                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Examples:")
                        .font(.caption.weight(.semibold))
                    Text(examples)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: 280)
            .presentationCompactAdaptation(.popover)
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
                        .transition(.scale.combined(with: .opacity))
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

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.vertical, 8)

            // Primary action: Scan another
            Button(action: onRescan) {
                Label("Scan Another Label", systemImage: "camera.rotate")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Scan another label")
            .accessibilityHint("Returns to camera to scan a new ingredient label")

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
                    .font(.system(size: iconSize, weight: iconWeight))
                    .foregroundStyle(tint.opacity(iconOpacity))
                    .frame(width: iconFrameSize, height: iconFrameSize)
                    .background(tint.opacity(backgroundOpacity), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.term)
                        .font(.subheadline.weight(textWeight))
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
                    .fill(tint.opacity(cardBackgroundOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(tint.opacity(borderOpacity), lineWidth: borderWidth)
            )
            .scaleEffect(scaleEffect)
            .animation(.easeInOut(duration: 0.3), value: summary.kind)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint("Severity: \(severityDescription)")
            .accessibilitySortPriority(Double(summary.priority))
        }

        // Visual hierarchy properties based on priority
        private var iconSize: CGFloat {
            summary.kind == .definite ? 20 : 18
        }

        private var iconWeight: Font.Weight {
            summary.kind == .definite ? .semibold : .medium
        }

        private var iconOpacity: Double {
            switch summary.kind {
            case .definite: return 1.0
            case .synonym, .pattern: return 1.0
            case .ambiguous, .fuzzy: return 0.8
            }
        }

        private var iconFrameSize: CGFloat {
            summary.kind == .definite ? 26 : 22
        }

        private var backgroundOpacity: Double {
            summary.kind == .definite ? 0.20 : 0.15
        }

        private var textWeight: Font.Weight {
            switch summary.kind {
            case .definite: return .bold
            case .synonym, .pattern: return .semibold
            case .ambiguous, .fuzzy: return .regular
            }
        }

        private var cardBackgroundOpacity: Double {
            summary.kind == .definite ? 0.18 : 0.10
        }

        private var borderOpacity: Double {
            switch summary.kind {
            case .definite: return 0.5
            case .synonym, .pattern: return 0.4
            case .ambiguous, .fuzzy: return 0.3
            }
        }

        private var borderWidth: CGFloat {
            summary.kind == .definite ? 2.0 : 1.0
        }

        private var scaleEffect: CGFloat {
            summary.kind == .definite ? 1.0 : 1.0
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

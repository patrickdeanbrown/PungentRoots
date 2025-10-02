import SwiftUI
import SwiftData

struct ScanDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var scan: Scan
    @State private var showDeleteConfirmation = false

    private var effectiveVerdict: Verdict {
        scan.userOverride ?? scan.verdict
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Verdict badge
                VerdictBadge(verdict: effectiveVerdict)

                // Override picker
                VStack(alignment: .leading, spacing: 12) {
                    Label("Override Verdict", systemImage: "slider.horizontal.3")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("", selection: Binding(
                            get: { scan.userOverride ?? scan.verdict },
                            set: { newValue in
                                scan.userOverride = newValue == scan.verdict ? nil : newValue
                                try? modelContext.save()
                            }
                        )) {
                            Text("Safe").tag(Verdict.safe)
                            Text("Needs Review").tag(Verdict.needsReview)
                            Text("Contains").tag(Verdict.contains)
                        }
                        .pickerStyle(.segmented)

                        if scan.userOverride != nil {
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle.fill")
                                    .font(.caption)
                                Text("You've overridden the automatic verdict")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                // Matches section
                if !scan.matches.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Detected Matches", systemImage: "list.bullet.circle.fill")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], alignment: .leading, spacing: 12) {
                            ForEach(uniqueMatches, id: \.term) { summary in
                                matchBadge(summary: summary)
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                }

                // Captured text section
                VStack(alignment: .leading, spacing: 12) {
                    Label("Captured Text", systemImage: "doc.text.fill")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)

                    Text(scan.normalizedText)
                        .font(.body)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.tertiarySystemBackground))
                        )

                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Saved on \(scan.createdAt.formatted(date: .long, time: .shortened))")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )

                // Delete button
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete Scan", systemImage: "trash")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
            }
            .padding()
        }
        .navigationTitle(effectiveVerdictTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this scan?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(scan)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var uniqueMatches: [(term: String, kind: MatchKind, count: Int)] {
        var accumulator: [String: (kind: MatchKind, count: Int)] = [:]

        for match in scan.matches {
            let key = match.term.lowercased()
            if let existing = accumulator[key] {
                let bestKind = match.kind.priority > existing.kind.priority ? match.kind : existing.kind
                accumulator[key] = (kind: bestKind, count: existing.count + 1)
            } else {
                accumulator[key] = (kind: match.kind, count: 1)
            }
        }

        return accumulator.map { (term: $0.key.localizedCapitalized, kind: $0.value.kind, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.kind.priority == rhs.kind.priority {
                    return lhs.term < rhs.term
                }
                return lhs.kind.priority > rhs.kind.priority
            }
    }

    private func matchBadge(summary: (term: String, kind: MatchKind, count: Int)) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon(for: summary.kind))
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(tint(for: summary.kind))
                .frame(width: 22, height: 22)

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
                .fill(tint(for: summary.kind).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tint(for: summary.kind).opacity(0.3), lineWidth: 1.5)
        )
    }

    private func icon(for kind: MatchKind) -> String {
        switch kind {
        case .definite:
            return "exclamationmark.triangle.fill"
        case .synonym, .pattern:
            return "exclamationmark.circle.fill"
        case .ambiguous, .fuzzy:
            return "questionmark.circle.fill"
        }
    }

    private func tint(for kind: MatchKind) -> Color {
        switch kind {
        case .definite:
            return Color(red: 0.86, green: 0.18, blue: 0.24)
        case .synonym, .pattern:
            return Color(red: 0.96, green: 0.55, blue: 0.19)
        case .ambiguous, .fuzzy:
            return Color(red: 0.98, green: 0.82, blue: 0.24)
        }
    }

    private var effectiveVerdictTitle: String {
        switch effectiveVerdict {
        case .contains:
            return "Contains"
        case .needsReview:
            return "Needs Review"
        case .safe:
            return "Safe"
        }
    }
}

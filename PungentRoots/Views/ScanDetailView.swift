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

    private var verdictDescription: String {
        switch effectiveVerdict {
        case .contains:
            return "Marked as Contains"
        case .needsReview:
            return "Marked as Needs Review"
        case .safe:
            return "Marked as Safe"
        }
    }

    var body: some View {
        List {
            Section("Verdict") {
                Picker("Override", selection: Binding(
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

                Text(verdictDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Captured Text") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(scan.normalizedText)
                        .textSelection(.enabled)
                    Text("Saved on \(scan.createdAt.formatted(date: .long, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if scan.matches.isEmpty == false {
                Section("Matches") {
                    ForEach(scan.matches, id: \.self) { match in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(match.term)
                                .font(.headline)
                            Text(match.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section("Actions") {
                Button("Delete Scan", role: .destructive) {
                    showDeleteConfirmation = true
                }
            }
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

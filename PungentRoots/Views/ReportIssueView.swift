import SwiftUI

/// Allows users to report detection issues with screenshot capture
struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    let capturedImage: UIImage?
    let detectionResult: DetectionResult
    let normalizedText: String

    @State private var selectedIssueType: IssueType = .falsePositive
    @State private var additionalNotes: String = ""
    @State private var showShareSheet = false

    enum IssueType: String, CaseIterable, Identifiable {
        case falsePositive = "False Positive"
        case missedIngredient = "Missed Ingredient"
        case wrongSeverity = "Wrong Severity"
        case ocrError = "OCR Error"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .falsePositive:
                return "Flagged an ingredient that's not a pungent root"
            case .missedIngredient:
                return "Didn't detect a pungent root that's present"
            case .wrongSeverity:
                return "Severity level doesn't match ingredient type"
            case .ocrError:
                return "Text recognition was incorrect"
            }
        }

        var icon: String {
            switch self {
            case .falsePositive: return "xmark.circle"
            case .missedIngredient: return "exclamationmark.triangle"
            case .wrongSeverity: return "gauge.with.dots.needle.bottom.50percent"
            case .ocrError: return "doc.text.magnifyingglass"
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Report an Issue")
                                    .font(.headline)
                                Text("Help improve detection accuracy")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Issue Type") {
                    ForEach(IssueType.allCases) { type in
                        Button {
                            selectedIssueType = type
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(selectedIssueType == type ? Color.accentColor : .secondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type.rawValue)
                                        .foregroundStyle(.primary)
                                        .font(.subheadline.weight(selectedIssueType == type ? .semibold : .regular))
                                    Text(type.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedIssueType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Additional Details") {
                    TextField("Add any helpful context...", text: $additionalNotes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("What happens next?", systemImage: "info.circle")
                            .font(.subheadline.weight(.semibold))

                        Text("Your report will be shared via your preferred method. Include the screenshot to help us see exactly what you saw.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Report Issue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Share Report") {
                        showShareSheet = true
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: buildReportItems())
            }
        }
    }

    private func buildReportItems() -> [Any] {
        var items: [Any] = []

        // Build report text
        let reportText = """
        PungentRoots Detection Report

        Issue Type: \(selectedIssueType.rawValue)
        \(selectedIssueType.description)

        Verdict: \(detectionResult.verdict.rawValue)
        Matches Found: \(detectionResult.matches.count)

        Detected Text:
        \(normalizedText)

        \(additionalNotes.isEmpty ? "" : "Additional Notes:\n\(additionalNotes)\n")
        ---
        Generated by PungentRoots
        """

        items.append(reportText)

        // Add screenshot if available
        if let image = capturedImage {
            items.append(image)
        }

        return items
    }
}

/// UIKit share sheet wrapper
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

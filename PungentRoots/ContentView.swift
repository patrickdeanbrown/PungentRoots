import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @Query(sort: \Scan.createdAt, order: .reverse) private var scans: [Scan]

    @State private var manualInput: String = ""
    @State private var normalizedPreview: String = ""
    @State private var detectionResult: DetectionResult?
    @State private var lastRawText: String = ""
    @State private var lastSource: ScanSource?
    @State private var isProcessing = false
    @State private var isShowingManualSheet = false
#if os(iOS)
    @State private var isShowingDocumentScanner = false
#endif
    @State private var isShowingSettings = false
    @State private var showClearConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                captureSection
                manualSection
                resultSection
                historySection
            }
            .navigationTitle("PungentRoots")
            .toolbar { toolbarContent }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .confirmationDialog("Clear all history?", isPresented: $showClearConfirmation) {
                Button("Clear History", role: .destructive) {
                    clearHistory()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
#if os(iOS)
        .sheet(isPresented: $isShowingDocumentScanner) {
            DocumentCameraView { result in
                handleDocumentCamera(result: result)
            }
        }
#endif
        .sheet(isPresented: $isShowingManualSheet) {
            NavigationStack {
                VStack(spacing: 16) {
                    TextEditor(text: $manualInput)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3))
                        )
                        .frame(minHeight: 220)
                    Button(action: analyzeManualInput) {
                        Label("Analyze Text", systemImage: "wand.and.stars")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
                .padding()
                .navigationTitle("Paste Text")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isShowingManualSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { isShowingSettings = false }
                        }
                    }
            }
        }
    }

    private var captureSection: some View {
        Section("Scan Label") {
#if os(iOS)
            Button {
                isShowingDocumentScanner = true
            } label: {
                Label("Use Document Camera", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
#else
            Text("Document camera is available on iOS devices.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#endif
        }
    }

    private var manualSection: some View {
        Section("Manual Entry") {
            Button {
                isShowingManualSheet = true
            } label: {
                Label("Paste or type ingredients", systemImage: "text.viewfinder")
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
    }

    private var resultSection: some View {
        Section("Result") {
            if isProcessing {
                HStack {
                    ProgressView()
                    Text("Analyzing…")
                        .font(.body)
                }
            } else if let result = detectionResult, !normalizedPreview.isEmpty {
                DetectionResultView(normalizedText: normalizedPreview, result: result)
                    .listRowInsets(EdgeInsets())
                    .accessibilityElement(children: .contain)
            } else {
                Text("Run a scan or paste text to see highlights.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historySection: some View {
        Section("History") {
            if scans.isEmpty {
                ContentUnavailableView(
                    "No scans yet",
                    systemImage: "doc.plaintext",
                    description: Text("Capture a label or paste text to start.")
                )
            } else {
                ForEach(scans) { scan in
                    NavigationLink(destination: ScanDetailView(scan: scan)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scan.verdictLabel)
                                .font(.subheadline)
                                .bold()
                            Text(scan.normalizedText)
                                .font(.footnote)
                                .lineLimit(2)
                            Text(scan.createdAt, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete(perform: deleteScans)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Button(action: { isShowingSettings = true }) {
                Label("Settings", systemImage: "gear")
            }
            if !normalizedPreview.isEmpty {
                Button("Save") { persistCurrentScan() }
                    .disabled(detectionResult == nil || lastSource == nil)
            }
        }

        ToolbarItem(placement: .navigationBarLeading) {
            if scans.isEmpty == false {
                Button("Clear") { showClearConfirmation = true }
            }
        }
    }

    private func analyzeManualInput() {
        let trimmed = manualInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        isProcessing = true
        lastRawText = trimmed
        lastSource = .paste
        Task {
            await analyzeText(trimmed, source: .paste)
            isProcessing = false
            isShowingManualSheet = false
            manualInput = ""
        }
    }

#if os(iOS)
    private func handleDocumentCamera(result: Result<CGImage, Swift.Error>) {
        Task { @MainActor in
            isProcessing = true
        }
        Task {
            do {
                let cgImage = try result.get()
                let recognized = try await appEnvironment.textAcquisition.recognize(from: .cgImage(cgImage))
                await MainActor.run {
                    lastRawText = recognized.raw
                    lastSource = .photo
                    normalizedPreview = recognized.normalized
                    completeAnalysis(normalized: recognized.normalized)
                }
            } catch {
                await MainActor.run {
                    if let acquisitionError = error as? TextAcquisitionService.Error {
                        switch acquisitionError {
                        case .noTextFound:
                            errorMessage = "No text detected. Try scanning a clearer area or switch to paste mode."
                        case .recognitionFailed(let underlying):
                            errorMessage = "OCR failed: \(underlying.localizedDescription)."
                        case .unsupportedImage:
                            errorMessage = "Unsupported image format for OCR."
                        }
                    } else {
                        errorMessage = "Unable to read text from scan."
                    }
                    isProcessing = false
                }
            }
        }
    }
#endif

    private func analyzeText(_ text: String, source: ScanSource) async {
        await MainActor.run {
            lastSource = source
            normalizedPreview = text
        }
        do {
            let normalized = appEnvironment.normalizer.normalize(text)
            await MainActor.run {
                normalizedPreview = normalized
                completeAnalysis(normalized: normalized)
            }
        }
    }

    @MainActor
    private func completeAnalysis(normalized: String) {
        let analysis = appEnvironment.analyze(normalized)
        detectionResult = analysis.result
        normalizedPreview = analysis.normalized
        isProcessing = false
        provideFeedback(for: analysis.result.verdict)
        announceVerdict(analysis.result)
    }

    @MainActor
    private func persistCurrentScan() {
        guard
            let currentResult = detectionResult,
            let source = lastSource
        else { return }
        let scan = Scan(
            source: source,
            rawText: lastRawText,
            normalizedText: normalizedPreview,
            verdict: currentResult.verdict,
            riskScore: currentResult.riskScore,
            matches: currentResult.matches,
            dictionaryVersion: appEnvironment.dictionary.version
        )
        do {
            modelContext.insert(scan)
            try modelContext.save()
            detectionResult = nil
            normalizedPreview = ""
            lastSource = nil
            lastRawText = ""
        } catch {
            errorMessage = "Failed to save scan."
        }
    }

    @MainActor
    private func deleteScans(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(scans[index])
        }
        try? modelContext.save()
    }

    @MainActor
    private func clearHistory() {
        for scan in scans {
            modelContext.delete(scan)
        }
        try? modelContext.save()
    }

    @MainActor
    private func provideFeedback(for verdict: Verdict) {
#if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(verdict == .contains ? .error : (verdict == .needsReview ? .warning : .success))
#endif
    }

    @MainActor
    private func announceVerdict(_ result: DetectionResult) {
#if os(iOS)
        let message: String
        switch result.verdict {
        case .contains:
            message = "Contains pungent roots with score \(String(format: "%.2f", result.riskScore))."
        case .needsReview:
            message = "Needs review with score \(String(format: "%.2f", result.riskScore))."
        case .safe:
            message = "Safe with score \(String(format: "%.2f", result.riskScore))."
        }
        UIAccessibility.post(notification: .announcement, argument: message)
#endif
    }
}

private extension Scan {
    var verdictLabel: String {
        switch verdict {
        case .contains:
            return "Contains"
        case .needsReview:
            return "Needs Review"
        case .safe:
            return "Safe"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppEnvironment(dictionary: DetectDictionary(
            definite: ["onion"],
            patterns: ["onion"],
            ambiguous: ["stock"],
            synonyms: ["allium"],
            fuzzyHints: ["oniorn"],
            version: "preview"
        )))
        .modelContainer(for: Scan.self, inMemory: true)
}

import SwiftUI
import os
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @State private var normalizedPreview: String = ""
    @State private var detectionResult: DetectionResult?
    @State private var isProcessing = false
    @State private var isShowingFullText = false
#if os(iOS)
    @State private var isShowingDocumentScanner = false
    @State private var hasAutoPresentedCamera = false
#endif
    @State private var isShowingSettings = false
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "ScanFlow")

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    resultCard
                    primaryActions
                    guidanceCard
                }
                .padding(.vertical, 32)
                .padding(.horizontal)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
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
        }
#if os(iOS)
        .sheet(isPresented: $isShowingDocumentScanner) {
            DocumentCameraView { result in
                handleDocumentCamera(result: result)
            }
        }
        .onAppear(perform: presentCameraIfNeeded)
#endif
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

    private var resultCard: some View {
        Group {
            if isProcessing {
                card {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Analyzing…")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let result = detectionResult, !normalizedPreview.isEmpty {
                card {
                    DetectionResultView(normalizedText: normalizedPreview, result: result, isShowingFullText: $isShowingFullText)
                }
            } else {
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ready to scan")
                            .font(.headline)
                        Text("We’ll highlight any pungent roots the moment the label is captured.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var primaryActions: some View {
        VStack(spacing: 12) {
#if os(iOS)
            Button {
                logger.info("scan_button_tapped")
                isShowingDocumentScanner = true
            } label: {
                Label("Scan Ingredients", systemImage: "camera.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isProcessing)
#else
            Text("Scanning is available on iOS devices.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#endif
            Text("Hold the packaging steady until the text is sharp, then rescan whenever ingredients change.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var guidanceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tips for fast rescans")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Move close to the ingredient panel so text fills the frame.", systemImage: "viewfinder")
                    Label("Nothing is stored — every check is a fresh scan for the latest label.", systemImage: "arrow.clockwise")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { isShowingSettings = true }) {
                Label("Info", systemImage: "info.circle")
            }
        }
    }

#if os(iOS)
    private func presentCameraIfNeeded() {
        guard hasAutoPresentedCamera == false else { return }
        hasAutoPresentedCamera = true
        logger.info("auto_present_camera")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            guard isProcessing == false else { return }
            isShowingDocumentScanner = true
        }
    }

    private func handleDocumentCamera(result: Result<CGImage, Swift.Error>) {
        Task { @MainActor in
            isProcessing = true
            detectionResult = nil
            normalizedPreview = ""
            isShowingFullText = false
        }
        Task {
            do {
                let cgImage = try result.get()
                let recognized = try await appEnvironment.textAcquisition.recognize(from: .cgImage(cgImage))
                await MainActor.run {
                    normalizedPreview = recognized.normalized
                    completeAnalysis(normalized: recognized.normalized)
                }
            } catch {
                await MainActor.run {
                    if let acquisitionError = error as? TextAcquisitionService.Error {
                        switch acquisitionError {
                        case .noTextFound:
                            errorMessage = "No text detected. Hold closer to the label and try again."
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

    @MainActor
    private func completeAnalysis(normalized: String) {
        let analysis = appEnvironment.analyze(normalized)
        detectionResult = analysis.result
        normalizedPreview = analysis.normalized
        isProcessing = false
        isShowingFullText = false
        announceSummary(for: analysis.result)
        logger.info("analysis_completed matches=\(analysis.result.matches.count, privacy: .public)")
    }

    private func announceSummary(for result: DetectionResult) {
#if os(iOS)
        let count = result.matches.count
        let message: String
        if count == 0 {
            message = "No pungent root matches detected."
        } else if count == 1 {
            message = "1 match detected. Review details."
        } else {
            message = "\(count) matches detected. Review details."
        }
        UIAccessibility.post(notification: .announcement, argument: message)
#endif
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
    }
}

private struct ContentViewPreviewHarness: View {
    @StateObject private var environment = AppEnvironment(dictionary: DetectDictionary(
        definite: ["onion"],
        patterns: ["dehydrated onion"],
        ambiguous: ["stock"],
        synonyms: ["allium"],
        fuzzyHints: ["garilc"],
        version: "preview"
    ))

    var body: some View {
        ContentView()
            .environmentObject(environment)
    }
}

#Preview {
    ContentViewPreviewHarness()
}

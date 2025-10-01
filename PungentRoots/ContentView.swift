import SwiftUI
import os

struct ContentView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @StateObject private var captureController = LiveCaptureController()
    @State private var normalizedPreview: String = ""
    @State private var detectionResult: DetectionResult?
    @State private var recognizedItems: [LiveCaptureController.RecognizedPayload.Item] = []
    @State private var capturedImage: UIImage?
    @State private var highlightedBoxes: [DetectionOverlay] = []
    @State private var isProcessing = false
    @State private var isShowingFullText = false
    @State private var isShowingSettings = false
    @State private var isShowingReportIssue = false
    @State private var interfaceError: String?

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "ScanFlow")

    @AppStorage("retakeButtonAlignment") private var retakeAlignmentRaw: String = RetakeButtonAlignment.trailing.rawValue

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    cameraModule
                    resultCard
                    guidanceLink
                }
                .padding(.vertical, 20)
                .padding(.horizontal)
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color(.systemGray6), Color(.systemBackground)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .toolbar { toolbarContent }
            .alert("Error", isPresented: Binding(
                get: { interfaceError != nil },
                set: { if !$0 { interfaceError = nil } }
            )) {
                Button("OK", role: .cancel) { interfaceError = nil }
            } message: {
                Text(interfaceError ?? "")
            }
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
        .onAppear { configureCaptureController() }
        .onDisappear { captureController.stop() }
        .onReceive(captureController.$state) { state in
            if case let .error(message) = state {
                interfaceError = message
            }
        }
    }

    private var cameraModule: some View {
        VStack(spacing: 12) {
            cameraPreviewContent
        }
    }

    @ViewBuilder
    private var cameraPreviewContent: some View {
#if os(iOS)
        ZStack {
            GeometryReader { proxy in
                LiveCameraPreview(controller: captureController)
                    .frame(height: proxy.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(alignmentGuides)
                    .overlay(statusOverlay, alignment: .topLeading)
                    .overlay(
                        DetectionOverlayView(boxes: highlightedBoxes, size: proxy.size)
                    )
            }
            .frame(height: 340)
            if case .error = captureController.state {
                errorOverlay
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, -16)
#else
        Text("Camera preview is available on iOS devices.")
            .font(.footnote)
            .foregroundStyle(.secondary)
#endif
    }

#if os(iOS)
    private var alignmentGuides: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(height: 1)
                Spacer()
            }
            HStack {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 1)
                Spacer()
            }
        }
    }

    private var statusOverlay: some View {
        HStack(spacing: 12) {
            let descriptor = captureController.state.descriptor
            Label(descriptor.text, systemImage: descriptor.icon)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(.white)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.55), Color.black.opacity(0.35)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Capsule()
                )
            Spacer()
            if shouldShowRetakeButton {
                let alignment = retakeAlignment
                if alignment == .leading {
                    retakeButton
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    retakeButton
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var retakeButton: some View {
        Button(action: rescan) {
            Image(systemName: "camera.rotate")
                .imageScale(.medium)
                .padding(12)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.accentColor)
        .clipShape(Circle())
        .accessibilityLabel("Retake scan")
    }

    private var errorOverlay: some View {
        VStack(spacing: 12) {
            Label("Camera unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Button {
                captureController.resumeScanning()
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var shouldShowRetakeButton: Bool {
        switch captureController.state {
        case .processing:
            return false
        case .error:
            return true
        case .paused:
            return true
        default:
            return detectionResult != nil
        }
    }

#endif

    private var resultCard: some View {
        Group {
            if isProcessing {
                card {
                    ProcessingStateView()
                }
            } else if let result = detectionResult, !normalizedPreview.isEmpty {
                card {
                    DetectionResultView(
                        normalizedText: normalizedPreview,
                        result: result,
                        capturedImage: capturedImage,
                        detectionBoxes: highlightedBoxes,
                        isShowingFullText: $isShowingFullText,
                        onRescan: rescan,
                        onReportIssue: { isShowingReportIssue = true }
                    )
                }
            } else {
                EmptyView()
            }
        }
    }

    private var guidanceLink: some View {
        Group {
            if detectionResult == nil && !isProcessing {
                EmptyStateView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
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

    private func configureCaptureController() {
#if os(iOS)
        captureController.setHandlers(
            onCapture: { payload in
                handleRecognizedText(payload)
            },
            onError: { message in
                interfaceError = message
            }
        )
        captureController.start()
#endif
    }

    private func handleRecognizedText(_ payload: LiveCaptureController.RecognizedPayload) {
        logger.info("auto_capture_recognized lines=\(payload.items.count, privacy: .public)")

        // Haptic feedback on capture
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif

        Task { @MainActor in
            isProcessing = true
            detectionResult = nil
            normalizedPreview = ""
            isShowingFullText = false
            highlightedBoxes = []
            recognizedItems = payload.items
            capturedImage = payload.capturedImage
            let recognized = appEnvironment.textAcquisition.makeRecognizedText(from: payload.items.map { $0.text })
            normalizedPreview = recognized.normalized
            completeAnalysis(normalized: recognized.normalized)
            isProcessing = false
            captureController.finishProcessing()
        }
    }

    @MainActor
    private func completeAnalysis(normalized: String) {
        let analysis = appEnvironment.analyze(normalized)
        detectionResult = analysis.result
        normalizedPreview = analysis.normalized
        updateHighlights(for: analysis.result)
        announceSummary(for: analysis.result)

        // Haptic feedback based on verdict
        #if os(iOS)
        let feedback = UINotificationFeedbackGenerator()
        switch analysis.result.verdict {
        case .safe:
            feedback.notificationOccurred(.success)
        case .needsReview:
            feedback.notificationOccurred(.warning)
        case .contains:
            feedback.notificationOccurred(.error)
        }
        #endif
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

    private func rescan() {
        logger.info("auto_capture_rescan")

        // Haptic feedback on button tap
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif

        normalizedPreview = ""
        detectionResult = nil
        isShowingFullText = false
        isProcessing = false
        highlightedBoxes = []
        recognizedItems = []
        capturedImage = nil
#if os(iOS)
        captureController.resumeScanning()
#endif
    }

    private func updateHighlights(for result: DetectionResult) {
        var severityMap: [String: DetectionOverlay.DetectionSeverity] = [:]
        for match in result.matches {
            let key = match.term.lowercased()
            let severity = DetectionOverlay.DetectionSeverity(kind: match.kind)
            if let existing = severityMap[key], existing.priority >= severity.priority {
                continue
            }
            severityMap[key] = severity
        }

        guard !severityMap.isEmpty else {
            highlightedBoxes = []
            return
        }

        let orderedMap = severityMap.sorted { lhs, rhs in
            lhs.value.priority > rhs.value.priority
        }

        var overlays: [DetectionOverlay] = []
        for item in recognizedItems {
            let lowered = item.text.lowercased()
            if let match = orderedMap.first(where: { lowered.contains($0.key) }) {
                let severity = match.value
                overlays.append(DetectionOverlay(rect: item.boundingBox, severity: severity))
            }
        }
        highlightedBoxes = overlays
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
            )
    }
}


extension ContentView {
    var retakeAlignment: RetakeButtonAlignment {
        RetakeButtonAlignment(rawValue: retakeAlignmentRaw) ?? .trailing
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


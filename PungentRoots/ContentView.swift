import SwiftUI
import os

struct ContentView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

#if os(iOS)
    @State private var captureController = AutoCaptureController(prefersDataScanner: true)
    @State private var capturePreference = true
#endif
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
#if os(iOS)
    @ScaledMetric(relativeTo: .title2) private var baseCameraHeight: CGFloat = 340
#endif

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
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
        .navigationTitle(Text("scan.navigation.title"))
        .toolbarTitleDisplayMode(.large)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("common.done", action: { isShowingSettings = false })
                        }
                    }
            }
        }
        .sheet(isPresented: $isShowingReportIssue) {
            if let result = detectionResult {
                ReportIssueView(
                    capturedImage: capturedImage,
                    detectionResult: result,
                    normalizedText: normalizedPreview
                )
            }
        }
        .onAppear { configureCaptureController() }
#if os(iOS)
        .onDisappear { captureController.stop() }
        .onChange(of: captureController.state) { _, state in
            if case let .error(message) = state {
                interfaceError = message
            }
        }
        .onChange(of: appEnvironment.captureOptions.prefersDataScanner) { _, _ in
            configureCaptureController()
        }
#endif
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
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.thickMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
            GeometryReader { proxy in
                Group {
                    if captureController.isUsingDataScanner, let scanner = captureController.dataScannerController {
                        DataScannerContainerView(controller: scanner)
                    } else if let legacy = captureController.legacyController {
                        LiveCameraPreview(controller: legacy)
                            .overlay(alignmentGuides)
                    } else {
                        Color.black.opacity(0.6)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityElement(children: .contain)
            }
            .padding(6)
        }
        .frame(height: cameraHeight)
        .frame(maxWidth: .infinity)
        .overlay(statusBadgeOverlay, alignment: .topLeading)
        .overlay(retakeButtonOverlay, alignment: retakeAlignment == .leading ? .bottomLeading : .bottomTrailing)
        .overlay(alignment: .center) {
            if case .error = captureController.state {
                errorOverlay
            }
        }
        .padding(.horizontal, -16)
#else
        Text("Camera preview is available on iOS devices.")
            .font(.footnote)
            .foregroundStyle(.secondary)
#endif
    }

#if os(iOS)
    private var cameraHeight: CGFloat {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 380 : 320
        return max(minimum, baseCameraHeight)
    }

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
        .accessibilityHidden(true)
    }

    private var statusBadgeOverlay: some View {
        HStack {
            statusBadge
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var retakeButtonOverlay: some View {
        if shouldShowRetakeButton {
            retakeButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let descriptor = statusDescriptor
        let stateColor = descriptor.color

        HStack(spacing: 8) {
            // Animated status indicator
            if captureController.state == .scanning || captureController.state == .processing {
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill(stateColor.opacity(0.3))
                            .scaleEffect(1.8)
                    )
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: captureController.state)
            }

            Label(descriptor.text, systemImage: descriptor.icon)
                .font(.footnote.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating, value: captureController.state == .processing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .background(
            Capsule()
                .strokeBorder(stateColor.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: stateColor.opacity(0.3), radius: 8, x: 0, y: 2)
        .accessibilityHint(Text("scan.status.accessibility.hint"))
    }

    private var statusDescriptor: (text: LocalizedStringKey, icon: String, color: Color) {
        // When scanning, show readiness-based feedback
        if captureController.state == .scanning {
            switch captureController.readiness {
            case .none:
                let descriptor = captureController.state.descriptor
                return (descriptor.text, descriptor.icon, .blue)
            case .tooFar:
                return (LocalizedStringKey("scan.status.move_closer"), "arrow.down.forward.and.arrow.up.backward", .orange)
            case .almostReady:
                return (LocalizedStringKey("scan.status.almost_ready"), "camera.metering.center.weighted", .yellow)
            case .ready:
                return (LocalizedStringKey("scan.status.ready"), "checkmark.circle", .green)
            }
        }

        // Otherwise, use default state-based descriptor
        let descriptor = captureController.state.descriptor
        let color = statusColor(for: captureController.state)
        return (descriptor.text, descriptor.icon, color)
    }

    private func statusColor(for state: AutoCaptureController.State) -> Color {
        switch state {
        case .idle, .preparing:
            return .gray
        case .scanning:
            return .blue
        case .processing:
            return .orange
        case .paused:
            return .green
        case .error:
            return .red
        }
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
        .accessibilityLabel(Text("scan.retake.accessibility"))
        .accessibilityHint(Text("scan.retake.hint"))
    }

    private var errorOverlay: some View {
        VStack(spacing: 12) {
            Label("scan.error.title", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Button {
                captureController.resumeScanning()
            } label: {
                Label("scan.error.retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
        }
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var shouldShowRetakeButton: Bool {
        // Only show retake button when we have results to retake
        guard detectionResult != nil else { return false }

        switch captureController.state {
        case .processing:
            return false
        case .error, .paused:
            return true
        default:
            return true
        }
    }

#endif

    private var resultCard: some View {
        Group {
            if isProcessing {
                card {
                    ProcessingStateView()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            } else {
                EmptyView()
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isProcessing)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: detectionResult?.verdict)
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
                Label("common.info", systemImage: "info.circle")
            }
        }
    }

    private func configureCaptureController() {
#if os(iOS)
        let prefersDataScanner = appEnvironment.captureOptions.prefersDataScanner
        if capturePreference != prefersDataScanner {
            captureController.stop()
            captureController = AutoCaptureController(prefersDataScanner: prefersDataScanner)
            capturePreference = prefersDataScanner
        }

        captureController.setHandlers(
            onCapture: { payload in
                handleRecognizedText(payload)
            },
            onError: { message in
                interfaceError = message
            }
        )

        DispatchQueue.main.async {
            captureController.start()
        }
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
            let analysis = await appEnvironment.analyzeAsync(recognized.normalized)

            detectionResult = analysis.result
            normalizedPreview = analysis.normalized
            updateHighlights(for: analysis.result)
            announceSummary(for: analysis.result)

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

            isProcessing = false
            captureController.finishProcessing()
        }
    }

    private func announceSummary(for result: DetectionResult) {
#if os(iOS)
        let count = result.matches.count
        let message: String
        if count == 0 {
            message = String(localized: "scan.summary.none")
        } else if count == 1 {
            message = String(localized: "scan.summary.single")
        } else {
            let format = NSLocalizedString("scan.summary.multiple", comment: "Announcement for multiple detection matches")
            message = String(format: format, count)
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
        logger.debug("updateHighlights: recognizedItems=\(self.recognizedItems.count) matches=\(result.matches.count)")

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
            logger.debug("updateHighlights: severityMap is empty, clearing boxes")
            highlightedBoxes = []
            return
        }

        let orderedMap = severityMap.sorted { lhs, rhs in
            lhs.value.priority > rhs.value.priority
        }

        var overlays: [DetectionOverlay] = []
        for item in recognizedItems {
            let lowered = item.text.lowercased()
            logger.debug("updateHighlights: checking item text='\(lowered)'")
            if let match = orderedMap.first(where: { lowered.contains($0.key) }) {
                let severity = match.value
                let matchedKey = match.key
                logger.debug("updateHighlights: MATCHED '\(lowered)' with key '\(matchedKey)'")
                overlays.append(DetectionOverlay(rect: item.boundingBox, severity: severity))
            }
        }
        logger.debug("updateHighlights: created \(overlays.count) overlay boxes")
        highlightedBoxes = overlays
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
            )
    }
}


extension ContentView {
    var retakeAlignment: RetakeButtonAlignment {
        RetakeButtonAlignment(rawValue: retakeAlignmentRaw) ?? .trailing
    }
}

private struct ContentViewPreviewHarness: View {
    @State private var environment = AppEnvironment.preview

    var body: some View {
        ContentView()
            .environment(environment)
    }
}

#Preview {
    ContentViewPreviewHarness()
}

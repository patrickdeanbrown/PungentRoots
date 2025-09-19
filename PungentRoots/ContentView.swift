import SwiftUI
import os
#if os(iOS)
import AVFoundation
import Vision
#endif

struct ContentView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment

    @StateObject private var captureController = LiveCaptureController()
    @State private var normalizedPreview: String = ""
    @State private var detectionResult: DetectionResult?
    @State private var isProcessing = false
    @State private var isShowingFullText = false
    @State private var isShowingSettings = false
    @State private var interfaceError: String?

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "ScanFlow")

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    cameraModule
                    resultCard
                    guidanceCard
                }
                .padding(.vertical, 24)
                .padding(.horizontal)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("PungentRoots")
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
#if os(iOS)
            ZStack {
                LiveCameraPreview(controller: captureController)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(alignmentGuides)
                    .overlay(stateOverlay, alignment: .topLeading)
                if case .error = captureController.state {
                    errorOverlay
                }
            }
            if captureController.supportsZoom {
                zoomSlider
            }
#else
            Text("Camera preview is available on iOS devices.")
                .font(.footnote)
                .foregroundStyle(.secondary)
#endif
        }
    }

#if os(iOS)
    private var alignmentGuides: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
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

    private var stateOverlay: some View {
        HStack {
            let descriptor = captureController.state.descriptor
            Label(descriptor.text, systemImage: descriptor.icon)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
            Spacer()
        }
        .padding(16)
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

    private var zoomSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Zoom", systemImage: "magnifyingglass.circle")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1fx", captureController.zoomFactor))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { captureController.zoomFactor },
                    set: { captureController.setZoom($0) }
                ),
                in: captureController.zoomRange
            )
            .tint(.accentColor)
        }
        .padding(.horizontal, 4)
    }
#endif

    private var resultCard: some View {
        Group {
            if isProcessing {
                card {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text("Processing capture…")
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else if let result = detectionResult, !normalizedPreview.isEmpty {
                card {
                    DetectionResultView(normalizedText: normalizedPreview, result: result, isShowingFullText: $isShowingFullText)
                    Divider()
                    Button(action: rescan) {
                        Label("Scan Again", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hold steady")
                            .font(.headline)
                        Text("We’ll capture the label automatically once the text is sharp and in focus.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var guidanceCard: some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Capture tips")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Move close so the ingredient panel fills the frame.", systemImage: "viewfinder")
                    Label("Let the app focus — the scan triggers when text is clear.", systemImage: "bolt.badge.clock")
                    Label("Highlights appear instantly; rescan whenever labels change.", systemImage: "arrow.clockwise")
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
        logger.info("auto_capture_recognized lines=\(payload.strings.count, privacy: .public)")
        Task { @MainActor in
            isProcessing = true
            detectionResult = nil
            normalizedPreview = ""
            isShowingFullText = false
            let recognized = appEnvironment.textAcquisition.makeRecognizedText(from: payload.strings)
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
        announceSummary(for: analysis.result)
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
        normalizedPreview = ""
        detectionResult = nil
        isShowingFullText = false
        isProcessing = false
#if os(iOS)
        captureController.resumeScanning()
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

#if os(iOS)
struct LiveCameraPreview: UIViewRepresentable {
    @ObservedObject var controller: LiveCaptureController

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = controller.session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        if uiView.videoPreviewLayer.session !== controller.session {
            uiView.videoPreviewLayer.session = controller.session
        }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

final class LiveCaptureController: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case scanning
        case processing
        case paused
        case error(String)
    }

    struct RecognizedPayload {
        let strings: [String]
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var zoomFactor: CGFloat = 1.0

    var supportsZoom: Bool { maxZoomFactor > 1.01 }
    var zoomRange: ClosedRange<CGFloat> { 1.0...maxZoomFactor }

    fileprivate let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "co.ouchieco.PungentRoots.camera.session", qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "co.ouchieco.PungentRoots.camera.analysis", qos: .userInitiated)
    private let output = AVCaptureVideoDataOutput()
    private var activeDevice: AVCaptureDevice?
    private var maxZoomFactor: CGFloat = 1.0
    private var isConfigured = false
    private var authorizationInFlight = false
    private var frameThrottle: CFTimeInterval = CACurrentMediaTime()
    private var scanningEnabled = false

    private var onCapture: ((RecognizedPayload) -> Void)?
    private var onError: ((String) -> Void)?

    func setHandlers(onCapture: @escaping (RecognizedPayload) -> Void, onError: @escaping (String) -> Void) {
        self.onCapture = onCapture
        self.onError = onError
    }

    func start() {
        configureIfNeeded()
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.scanningEnabled = false
            self.updateState(.idle)
        }
    }

    func resumeScanning() {
        sessionQueue.async {
            guard self.isConfigured else {
                DispatchQueue.main.async { self.configureIfNeeded() }
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.scanningEnabled = true
            self.updateState(.scanning)
        }
    }

    func finishProcessing() {
        updateState(.paused)
    }

    func setZoom(_ factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.activeDevice else { return }
            let clamped = max(1.0, min(factor, self.maxZoomFactor))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clamped
                device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.zoomFactor = clamped
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?("Unable to adjust zoom.")
                }
            }
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else {
            resumeScanning()
            return
        }
        guard authorizationInFlight == false else { return }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            authorizationInFlight = true
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.authorizationInFlight = false
                    if granted {
                        self.configureSession()
                    } else {
                        self.reportError("Camera access is required to scan labels.")
                    }
                }
            }
        default:
            reportError("Enable camera access in Settings to scan labels.")
        }
    }

    private func configureSession() {
        updateState(.preparing)
        sessionQueue.async {
            let session = self.session
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) ?? AVCaptureDevice.default(for: .video) else {
                session.commitConfiguration()
                self.reportError("Camera is unavailable on this device.")
                return
            }

            self.activeDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    session.commitConfiguration()
                    self.reportError("Camera input could not be configured.")
                    return
                }
                session.addInput(input)
            } catch {
                session.commitConfiguration()
                self.reportError("Failed to access the camera: \(error.localizedDescription)")
                return
            }

            self.configureDevice(device)

            self.output.alwaysDiscardsLateVideoFrames = true
            self.output.setSampleBufferDelegate(self, queue: self.analysisQueue)
            guard session.canAddOutput(self.output) else {
                session.commitConfiguration()
                self.reportError("Camera output could not be configured.")
                return
            }
            session.addOutput(self.output)
            session.commitConfiguration()

            self.isConfigured = true
            self.scanningEnabled = true
            self.frameThrottle = CACurrentMediaTime()
            session.startRunning()
            self.updateState(.scanning)
        }
    }

    private func configureDevice(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isAutoFocusRangeRestrictionSupported {
                device.autoFocusRangeRestriction = .near
            }
            if device.isSmoothAutoFocusSupported {
                device.isSmoothAutoFocusEnabled = true
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isLowLightBoostSupported {
                device.automaticallyEnablesLowLightBoostWhenAvailable = true
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)

            maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            let baseline = max(1.0, min(1.3, maxZoomFactor))
            device.videoZoomFactor = baseline
            DispatchQueue.main.async {
                self.zoomFactor = baseline
            }
            device.unlockForConfiguration()
        } catch {
            DispatchQueue.main.async {
                self.onError?("Unable to fine-tune camera focus.")
            }
        }
    }

    private func updateState(_ newState: State) {
        DispatchQueue.main.async {
            self.state = newState
        }
    }

    private func reportError(_ message: String) {
        scanningEnabled = false
        updateState(.error(message))
        DispatchQueue.main.async {
            self.onError?(message)
        }
    }
}

extension LiveCaptureController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard scanningEnabled else { return }
        let now = CACurrentMediaTime()
        guard now - frameThrottle >= 0.7 else { return }
        frameThrottle = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results, observations.isEmpty == false else { return }
            let candidates = observations.compactMap { $0.topCandidates(1).first }
            let filtered = candidates.filter { $0.confidence >= 0.45 }
            let strings = filtered
                .map { $0.string.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let combined = strings.joined(separator: " ")
            guard strings.isEmpty == false, combined.count >= 12 else { return }

            scanningEnabled = false
            updateState(.processing)
            DispatchQueue.main.async {
                self.onCapture?(RecognizedPayload(strings: strings))
            }
        } catch {
            scanningEnabled = false
            reportError("Failed to analyze the camera feed.")
        }
    }
}
#else
final class LiveCaptureController: ObservableObject {
    enum State: Equatable {
        case idle
        case preparing
        case scanning
        case processing
        case paused
        case error(String)
    }

    struct RecognizedPayload {
        let strings: [String]
    }

    @Published private(set) var state: State = .idle
    var supportsZoom: Bool { false }
    var zoomRange: ClosedRange<CGFloat> { 1.0...1.0 }
    var zoomFactor: CGFloat { 1.0 }

    func setHandlers(onCapture: @escaping (RecognizedPayload) -> Void, onError: @escaping (String) -> Void) {}
    func start() {}
    func stop() {}
    func resumeScanning() {}
    func finishProcessing() {}
    func setZoom(_ factor: CGFloat) {}
}
#endif

extension LiveCaptureController.State {
    var descriptor: (text: String, icon: String) {
        switch self {
        case .idle:
            return ("Starting camera…", "camera")
        case .preparing:
            return ("Preparing camera…", "camera")
        case .scanning:
            return ("Hold steady for auto capture", "camera.viewfinder")
        case .processing:
            return ("Analyzing frame…", "wand.and.stars")
        case .paused:
            return ("Capture complete", "checkmark.circle")
        case .error:
            return ("Camera paused", "exclamationmark.triangle")
        }
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

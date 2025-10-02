import Foundation
import SwiftUI
#if os(iOS)
import AVFoundation
import Vision
#endif
import os

#if os(iOS)
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
        struct Item {
            let text: String
            let boundingBox: CGRect
        }

        let items: [Item]
        let capturedImage: UIImage?

        var strings: [String] {
            items.map { $0.text }
        }
    }

    enum ReadinessLevel: Equatable {
        case none          // Not scanning or no feedback available
        case tooFar        // Not enough text detected
        case almostReady   // Text detected but quality not high enough
        case ready         // All criteria met, will capture soon
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var zoomFactor: CGFloat = 1.0
    @Published private(set) var readiness: ReadinessLevel = .none

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
    private let ocrConfig: OCRConfiguration

    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = ocrConfig.recognitionLevel
        request.usesLanguageCorrection = ocrConfig.usesLanguageCorrection
        request.minimumTextHeight = ocrConfig.minimumTextHeight
        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }
        request.recognitionLanguages = ocrConfig.recognitionLanguages
        return request
    }()

    init(ocrConfig: OCRConfiguration = .default) {
        self.ocrConfig = ocrConfig
        super.init()
    }

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
            self.updateReadiness(.none)
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

            guard let device = self.selectCaptureDevice() else {
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

            // Start camera session with timeout protection
            let startTime = Date()
            session.startRunning()
            let duration = Date().timeIntervalSince(startTime)

            if duration > 5.0 {
                print("⚠️ Camera startup took \(duration)s - consider reporting this issue")
            }

            // Verify session actually started
            if !session.isRunning {
                print("❌ Camera session failed to start")
                self.reportError("Camera failed to start. Please try restarting the app.")
                return
            }

            self.updateState(.scanning)
        }
    }

    private func selectCaptureDevice() -> AVCaptureDevice? {
        #if os(iOS)
        let preferredTypes: [AVCaptureDevice.DeviceType] = [
            .builtInTripleCamera,
            .builtInDualWideCamera,
            .builtInDualCamera,
            .builtInWideAngleCamera
        ]
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: preferredTypes,
            mediaType: .video,
            position: .back
        )
        if let matched = discovery.devices.first {
            return matched
        }
        return AVCaptureDevice.default(for: .video)
        #else
        return nil
        #endif
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
#if os(iOS)
            if device.responds(to: Selector(("setAutomaticallyAdjustsVideoZoomFactorForDepthOfField:"))) {
                device.setValue(true, forKey: "automaticallyAdjustsVideoZoomFactorForDepthOfField")
            }
            if #available(iOS 17.0, *), device.isGeometricDistortionCorrectionSupported {
                device.isGeometricDistortionCorrectionEnabled = true
            }
#endif
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)

            maxZoomFactor = min(device.activeFormat.videoMaxZoomFactor, 5.0)
            let baseline = min(max(1.0, 1.5), maxZoomFactor)
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

    private func updateReadiness(_ level: ReadinessLevel) {
        DispatchQueue.main.async {
            self.readiness = level
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
        guard now - frameThrottle >= ocrConfig.frameThrottleInterval else { return }
        frameThrottle = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = textRequest
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
            guard let observations = request.results, observations.isEmpty == false else {
                updateReadiness(.tooFar)
                return
            }

            // Track confidence for quality check
            var totalConfidence: Float = 0
            var confidenceCount: Float = 0

            let items: [RecognizedPayload.Item] = observations.compactMap { observation in
                guard let candidate = observation.topCandidates(1).first, candidate.confidence >= ocrConfig.confidenceThreshold else { return nil }
                let trimmed = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmed.isEmpty == false else { return nil }
                let normalizedBox = normalizedBoundingBox(for: observation.boundingBox)

                // Accumulate confidence for average calculation
                totalConfidence += candidate.confidence
                confidenceCount += 1

                return RecognizedPayload.Item(text: trimmed, boundingBox: normalizedBox)
            }

            // Check capture quality criteria progressively
            guard items.count >= ocrConfig.minimumObservationCount else {
                updateReadiness(.tooFar)
                return
            }

            let combined = items.map { $0.text }.joined(separator: " ")
            guard combined.count >= ocrConfig.minimumCaptureLength else {
                updateReadiness(.almostReady)
                return
            }

            let averageConfidence = confidenceCount > 0 ? totalConfidence / confidenceCount : 0
            guard averageConfidence >= ocrConfig.minimumAverageConfidence else {
                updateReadiness(.almostReady)
                return
            }

            // All criteria met - ready to capture
            updateReadiness(.ready)

            // Capture the frame as an image for display in results
            let capturedImage = captureImage(from: pixelBuffer)

            scanningEnabled = false
            updateState(.processing)
            DispatchQueue.main.async {
                self.onCapture?(RecognizedPayload(items: items, capturedImage: capturedImage))
            }
        } catch {
            scanningEnabled = false
            reportError("Failed to analyze the camera feed.")
        }
    }
    private func normalizedBoundingBox(for box: CGRect) -> CGRect {
        let converted = CGRect(
            x: box.origin.y,
            y: box.origin.x,
            width: box.size.height,
            height: box.size.width
        )

        let clampedX = max(0, min(1, converted.origin.x))
        let clampedY = max(0, min(1, converted.origin.y))
        let clampedWidth = max(0, min(1 - clampedX, converted.width))
        let clampedHeight = max(0, min(1 - clampedY, converted.height))

        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }

    private func captureImage(from pixelBuffer: CVPixelBuffer, maxWidth: CGFloat = 800) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }

        // Create UIImage with proper orientation (rotated right)
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)

        // Resize if needed for memory efficiency
        if image.size.width > maxWidth {
            return resizeImage(image, targetWidth: maxWidth)
        }

        return image
    }

    private func resizeImage(_ image: UIImage, targetWidth: CGFloat) -> UIImage? {
        let scale = targetWidth / image.size.width
        let targetHeight = image.size.height * scale
        let targetSize = CGSize(width: targetWidth, height: targetHeight)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}

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
        struct Item {
            let text: String
            let boundingBox: CGRect
        }

        let items: [Item]
        let capturedImage: UIImage?

        var strings: [String] { items.map { $0.text } }
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
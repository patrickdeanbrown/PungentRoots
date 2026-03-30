import Foundation
import Observation
import SwiftUI
#if os(iOS)
@preconcurrency import AVFoundation
import Vision

@MainActor
@Observable
final class LabelCaptureController: NSObject {
    private(set) var state: CaptureState = .idle
    private(set) var readiness: CaptureReadiness = .none

    @ObservationIgnored
    nonisolated(unsafe) fileprivate let session = AVCaptureSession()

    @ObservationIgnored
    private let sessionQueue = DispatchQueue(label: "co.ouchieco.PungentRoots.labelCapture.session", qos: .userInitiated)
    @ObservationIgnored
    private let analysisQueue = DispatchQueue(label: "co.ouchieco.PungentRoots.labelCapture.analysis", qos: .userInitiated)
    @ObservationIgnored
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    @ObservationIgnored
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored
    private let ocrConfiguration: OCRConfiguration

    @ObservationIgnored
    nonisolated(unsafe) private var activeDevice: AVCaptureDevice?
    @ObservationIgnored
    nonisolated(unsafe) private var isConfigured = false
    @ObservationIgnored
    nonisolated(unsafe) private var isConfiguringSession = false
    @ObservationIgnored
    nonisolated(unsafe) private var authorizationInFlight = false
    @ObservationIgnored
    nonisolated(unsafe) private var readinessPaused = false
    @ObservationIgnored
    nonisolated(unsafe) private var frameThrottle: CFTimeInterval = CACurrentMediaTime()
    @ObservationIgnored
    nonisolated(unsafe) private var photoContinuation: CheckedContinuation<Data, Error>?
    @ObservationIgnored
    nonisolated(unsafe) private var isObservingSessionNotifications = false

    @ObservationIgnored
    private lazy var readinessRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.minimumTextHeight = max(0.01, ocrConfiguration.minimumTextHeight * 0.8)
        request.recognitionLanguages = ocrConfiguration.recognitionLanguages
        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }
        return request
    }()

    init(ocrConfiguration: OCRConfiguration = .default) {
        self.ocrConfiguration = ocrConfiguration
        super.init()
    }

    func start() {
        configureIfNeeded()
    }

    func stop() {
        readinessPaused = true
        unregisterForNotifications()
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
        state = .idle
        readiness = .none
    }

    func resumeScanning() {
        readinessPaused = false
        if isConfigured == false {
            configureIfNeeded()
            return
        }

        sessionQueue.async {
            self.startSessionIfNeeded()
        }
    }

    func capturePhotoData() async throws -> Data {
        guard isConfigured else {
            throw CaptureError.cameraUnavailable
        }
        guard photoContinuation == nil else {
            throw CaptureError.captureInProgress
        }

        readinessPaused = true
        state = .processing

        return try await withCheckedThrowingContinuation { continuation in
            photoContinuation = continuation
            sessionQueue.async {
                let settings: AVCapturePhotoSettings
                if self.photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
                    settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
                } else {
                    settings = AVCapturePhotoSettings()
                }
                settings.photoQualityPrioritization = .quality
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func configureIfNeeded() {
        guard isConfigured == false else {
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
                        self.present(error: .permissionDenied)
                    }
                }
            }
        default:
            present(error: .permissionDenied)
        }
    }

    private func configureSession() {
        state = .preparing
        registerForNotifications()

        sessionQueue.async {
            guard self.isConfiguringSession == false else { return }

            self.isConfiguringSession = true
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            var shouldStartSession = false

            defer {
                self.session.commitConfiguration()
                self.isConfiguringSession = false

                if shouldStartSession {
                    self.startSessionIfNeeded()
                }
            }

            guard let device = self.selectCaptureDevice() else {
                DispatchQueue.main.async {
                    self.present(error: .cameraUnavailable)
                }
                return
            }

            self.activeDevice = device

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.inputs.isEmpty, self.session.canAddInput(input) else {
                    DispatchQueue.main.async {
                        self.present(error: .configurationFailed)
                    }
                    return
                }
                self.session.addInput(input)
            } catch {
                DispatchQueue.main.async {
                    self.present(error: .system(error.localizedDescription))
                }
                return
            }

            do {
                try self.configure(device: device)
            } catch {
                DispatchQueue.main.async {
                    self.present(error: .system(error.localizedDescription))
                }
                return
            }

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.setSampleBufferDelegate(self, queue: self.analysisQueue)
            guard self.session.outputs.isEmpty, self.session.canAddOutput(self.videoOutput), self.session.canAddOutput(self.photoOutput) else {
                DispatchQueue.main.async {
                    self.present(error: .configurationFailed)
                }
                return
            }

            self.session.addOutput(self.videoOutput)
            self.session.addOutput(self.photoOutput)
            self.photoOutput.maxPhotoQualityPrioritization = .quality
            self.frameThrottle = CACurrentMediaTime()
            self.isConfigured = true
            self.readinessPaused = false
            shouldStartSession = true
        }
    }

    nonisolated private func startSessionIfNeeded() {
        guard isConfiguringSession == false else { return }

        if session.isRunning == false {
            session.startRunning()
        }

        DispatchQueue.main.async {
            if self.session.isRunning {
                self.state = .scanning
                self.readiness = .none
            } else {
                self.present(error: .cameraUnavailable)
            }
        }
    }

    nonisolated private func selectCaptureDevice() -> AVCaptureDevice? {
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
        return discovery.devices.first ?? AVCaptureDevice.default(for: .video)
    }

    nonisolated private func configure(device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

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
        if #available(iOS 17.0, *), device.isGeometricDistortionCorrectionSupported {
            device.isGeometricDistortionCorrectionEnabled = true
        }
        device.isSubjectAreaChangeMonitoringEnabled = true
        device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
    }

    private func registerForNotifications() {
        guard isObservingSessionNotifications == false else { return }
        isObservingSessionNotifications = true
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(handleRuntimeError(_:)), name: AVCaptureSession.runtimeErrorNotification, object: session)
        center.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVCaptureSession.wasInterruptedNotification, object: session)
        center.addObserver(self, selector: #selector(handleInterruptionEnded(_:)), name: AVCaptureSession.interruptionEndedNotification, object: session)
    }

    private func unregisterForNotifications() {
        guard isObservingSessionNotifications else { return }
        isObservingSessionNotifications = false
        NotificationCenter.default.removeObserver(self, name: AVCaptureSession.runtimeErrorNotification, object: session)
        NotificationCenter.default.removeObserver(self, name: AVCaptureSession.wasInterruptedNotification, object: session)
        NotificationCenter.default.removeObserver(self, name: AVCaptureSession.interruptionEndedNotification, object: session)
    }

    @objc
    private func handleRuntimeError(_ notification: Notification) {
        if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError, error.code == .mediaServicesWereReset {
            sessionQueue.async {
                self.startSessionIfNeeded()
            }
            return
        }

        present(error: .runtimeFailure)
    }

    @objc
    private func handleInterruption(_ notification: Notification) {
        readiness = .none
        state = .error(CaptureError.interrupted.message)
    }

    @objc
    private func handleInterruptionEnded(_ notification: Notification) {
        resumeScanning()
    }

    private func present(error: CaptureError) {
        state = .error(error.message)
        readiness = .none
        photoContinuation?.resume(throwing: error)
        photoContinuation = nil
    }

    private func updateReadiness(using observations: [VNRecognizedTextObservation]) {
        let candidates = observations.compactMap { observation -> VNRecognizedText? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            guard candidate.confidence >= max(0.3, ocrConfiguration.confidenceThreshold - 0.15) else { return nil }
            return candidate
        }

        if candidates.isEmpty {
            readiness = .tooFar
            return
        }

        let combinedLength = candidates.reduce(0) { $0 + $1.string.count }
        let averageConfidence = candidates.reduce(Float.zero) { $0 + $1.confidence } / Float(candidates.count)

        if combinedLength >= 36 && averageConfidence >= 0.58 && candidates.count >= 4 {
            readiness = .ready
        } else {
            readiness = .almostReady
        }
    }

    enum CaptureError: LocalizedError {
        case permissionDenied
        case cameraUnavailable
        case configurationFailed
        case captureInProgress
        case photoProcessingFailed
        case runtimeFailure
        case interrupted
        case system(String)

        var message: String {
            switch self {
            case .permissionDenied:
                return "Enable camera access in Settings to scan ingredient labels."
            case .cameraUnavailable:
                return "Camera preview is unavailable on this device."
            case .configurationFailed:
                return "The camera could not be configured for label capture."
            case .captureInProgress:
                return "A label capture is already in progress."
            case .photoProcessingFailed:
                return "The captured photo could not be processed."
            case .runtimeFailure:
                return "The camera session was interrupted. Try retaking the label."
            case .interrupted:
                return "Camera access was interrupted. Return to the app to continue scanning."
            case .system(let message):
                return message
            }
        }

        var errorDescription: String? { message }
    }
}

extension LabelCaptureController: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard readinessPaused == false else { return }
        let now = CACurrentMediaTime()
        guard now - frameThrottle >= ocrConfiguration.frameThrottleInterval else { return }
        frameThrottle = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = readinessRequest
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results ?? []
            DispatchQueue.main.async {
                if self.state == .scanning {
                    self.updateReadiness(using: observations)
                }
            }
        } catch {
            DispatchQueue.main.async {
                if self.state != .error(error.localizedDescription) {
                    self.present(error: .runtimeFailure)
                }
            }
        }
    }
}

extension LabelCaptureController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let dataResult: Result<Data, CaptureError>
        if let error {
            dataResult = .failure(.system(error.localizedDescription))
        } else if let data = photo.fileDataRepresentation() {
            dataResult = .success(data)
        } else {
            dataResult = .failure(.photoProcessingFailed)
        }

        DispatchQueue.main.async {
            switch dataResult {
            case .success(let data):
                self.state = .paused
                self.readiness = .none
                self.photoContinuation?.resume(returning: data)
                self.photoContinuation = nil
            case .failure(let captureError):
                self.present(error: captureError)
            }
        }
    }
}

struct LabelCameraPreview: UIViewRepresentable {
    let controller: LabelCaptureController

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

@MainActor
@Observable
final class LabelCaptureController {
    private(set) var state: CaptureState = .idle
    private(set) var readiness: CaptureReadiness = .none

    func start() {}
    func stop() {}
    func resumeScanning() {}
    func capturePhotoData() async throws -> Data { Data() }
}

#endif

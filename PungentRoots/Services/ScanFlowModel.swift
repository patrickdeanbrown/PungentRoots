import Foundation
import Observation
import os
#if os(iOS)
import UIKit
#endif

@MainActor
@Observable
final class ScanFlowModel {
    enum Phase: Equatable {
        case framing
        case capturing
        case analyzing
        case result
    }

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "ScanFlow")
    private let launchArguments: [String]

    private(set) var phase: Phase = .framing
    private(set) var analysis: ScanAnalysis?
    private(set) var highlightedBoxes: [DetectionOverlay] = []
    private(set) var interfaceError: String?
    private(set) var captureController: LabelCaptureController?
    var isShowingFullText = false

    @ObservationIgnored
    private var appEnvironment: AppEnvironment?

    @ObservationIgnored
    private var scanTask: Task<Void, Never>?

    @ObservationIgnored
    private var didLoadUITestPreview = false

    init(launchArguments: [String] = ProcessInfo.processInfo.arguments) {
        self.launchArguments = launchArguments
    }

    var normalizedText: String {
        analysis?.normalizedText ?? ""
    }

    var detectionResult: DetectionResult? {
        analysis?.result
    }

    var captureState: CaptureState {
        if isLiveCaptureDisabled {
            switch phase {
            case .framing:
                return .scanning
            case .capturing, .analyzing:
                return .processing
            case .result:
                return .paused
            }
        }
        return captureController?.state ?? .idle
    }

    var captureReadiness: CaptureReadiness {
        if isLiveCaptureDisabled {
            return phase == .result ? .ready : .none
        }
        return captureController?.readiness ?? .none
    }

    var isProcessing: Bool {
        phase == .capturing || phase == .analyzing
    }

    var showsEmptyState: Bool {
        phase == .framing && analysis == nil && isProcessing == false
    }

    var canAnalyzeLabel: Bool {
        phase == .framing && interfaceError == nil
    }

    func bind(environment: AppEnvironment) {
        appEnvironment = environment

        if showsUITestPreviewResult {
            loadUITestPreviewResultIfNeeded(using: environment)
            return
        }

        if showsUITestPartialResult {
            loadUITestPartialResultIfNeeded(using: environment)
            return
        }

        if captureController == nil, isLiveCaptureDisabled == false {
            let controller = LabelCaptureController()
            captureController = controller
            controller.start()
        }
    }

    func captureLabel() {
        guard canAnalyzeLabel else { return }
        guard let environment = appEnvironment else {
            interfaceError = "App environment is unavailable."
            return
        }

        logger.info("capture_label_requested")
        cancelWork()
        interfaceError = nil
        isShowingFullText = false
        phase = .capturing

        if isLiveCaptureDisabled {
            phase = .analyzing
            scanTask = Task { [weak self] in
                guard let self else { return }
                let analysis = self.makeUITestPartialResult(using: environment)
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    self.apply(analysis: analysis)
                }
            }
            return
        }

        scanTask = Task { [weak self] in
            guard let self, let controller = self.captureController else { return }

            do {
                let imageData = try await controller.capturePhotoData()
                guard Task.isCancelled == false else { return }

                await MainActor.run {
                    self.phase = .analyzing
                }

                let analysis = try await environment.analyzeCapturedImageData(imageData)
                guard Task.isCancelled == false else { return }

                await MainActor.run {
                    self.apply(analysis: analysis)
                }
            } catch {
                guard Task.isCancelled == false else { return }
                await MainActor.run {
                    self.phase = .framing
                    self.interfaceError = error.localizedDescription
                    self.captureController?.resumeScanning()
                }
            }
        }
    }

    func rescan() {
        logger.info("label_rescan_requested")
        cancelWork()

#if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
#endif

        analysis = nil
        highlightedBoxes = []
        isShowingFullText = false
        interfaceError = nil
        phase = .framing
        captureController?.resumeScanning()
    }

    func dismissError() {
        interfaceError = nil
    }

    func stop() {
        cancelWork()
        captureController?.stop()
    }

    private func apply(analysis: ScanAnalysis) {
        self.analysis = analysis
        highlightedBoxes = DetectionOverlay.overlays(for: analysis.recognizedBlocks, matches: analysis.result.matches)
        phase = .result
        announceSummary(for: analysis)
        provideVerdictFeedback(for: analysis.result.verdict)
    }

    private func cancelWork() {
        scanTask?.cancel()
        scanTask = nil
    }

    private func loadUITestPreviewResultIfNeeded(using environment: AppEnvironment) {
        guard didLoadUITestPreview == false else { return }
        didLoadUITestPreview = true
        apply(analysis: environment.analyzeCapturedLabel(makePreviewLabel()))
    }

    private func loadUITestPartialResultIfNeeded(using environment: AppEnvironment) {
        guard didLoadUITestPreview == false else { return }
        didLoadUITestPreview = true
        apply(analysis: makeUITestPartialResult(using: environment))
    }

    private func makeUITestPartialResult(using environment: AppEnvironment) -> ScanAnalysis {
        environment.analyzeCapturedLabel(
            CapturedLabel(
                imageData: nil,
                recognizedBlocks: [
                    RecognizedTextBlock(
                        text: "Contains Sesame. Dist & sold exclusively by Trader Joe's",
                        boundingBox: CGRect(x: 0.08, y: 0.54, width: 0.82, height: 0.14),
                        confidence: 0.92
                    )
                ],
                rawText: "Contains Sesame. Dist & sold exclusively by Trader Joe's",
                coverageStatus: .insufficient,
                warnings: PackagingTextAnalyzer.warnings(
                    for: .insufficient,
                    rawText: "Contains Sesame. Dist & sold exclusively by Trader Joe's"
                )
            )
        )
    }

    private func makePreviewLabel() -> CapturedLabel {
        CapturedLabel(
            imageData: nil,
            recognizedBlocks: [
                RecognizedTextBlock(
                    text: "Ingredients: wheat flour, onion powder, garlic extract, salt",
                    boundingBox: CGRect(x: 0.08, y: 0.56, width: 0.84, height: 0.18),
                    confidence: 0.96
                )
            ],
            rawText: "Ingredients: wheat flour, onion powder, garlic extract, salt",
            coverageStatus: .complete,
            warnings: []
        )
    }

    private func announceSummary(for analysis: ScanAnalysis) {
#if os(iOS)
        let result = analysis.result
        let message: String
        if analysis.coverageStatus == .complete {
            let count = result.matches.count
            if count == 0 {
                message = String(localized: "scan.summary.none")
            } else if count == 1 {
                message = String(localized: "scan.summary.single")
            } else {
                let format = NSLocalizedString("scan.summary.multiple", comment: "Announcement for multiple detection matches")
                message = String(format: format, count)
            }
        } else {
            message = analysis.coverageStatus.subtitle
        }
        UIAccessibility.post(notification: .announcement, argument: message)
#endif
    }

    private func provideVerdictFeedback(for verdict: Verdict) {
#if os(iOS)
        let feedback = UINotificationFeedbackGenerator()
        switch verdict {
        case .safe:
            feedback.notificationOccurred(.success)
        case .needsReview:
            feedback.notificationOccurred(.warning)
        case .contains:
            feedback.notificationOccurred(.error)
        }
#endif
    }

    private var isLiveCaptureDisabled: Bool {
        launchArguments.contains("--ui-test-disable-capture")
    }

    private var showsUITestPreviewResult: Bool {
        launchArguments.contains("--ui-test-preview-result")
    }

    private var showsUITestPartialResult: Bool {
        launchArguments.contains("--ui-test-preview-partial-result")
    }
}

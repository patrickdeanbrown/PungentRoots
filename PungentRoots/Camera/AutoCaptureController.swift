import Foundation

#if os(iOS)
import Combine
import Observation
import SwiftUI
import UIKit
import VisionKit

@available(iOS 16.0, *)
@MainActor
@Observable
final class AutoCaptureController {
    enum Mode {
        case dataScanner(DataScannerCaptureController)
        case legacy(LiveCaptureController)
    }

    enum State: Equatable {
        case idle
        case preparing
        case scanning
        case processing
        case paused
        case error(String)

        init(_ legacy: LiveCaptureController.State) {
            switch legacy {
            case .idle: self = .idle
            case .preparing: self = .preparing
            case .scanning: self = .scanning
            case .processing: self = .processing
            case .paused: self = .paused
            case .error(let message): self = .error(message)
            }
        }
    }

    private(set) var state: State = .idle
    private(set) var readiness: LiveCaptureController.ReadinessLevel = .none
    private(set) var mode: Mode

    var isUsingDataScanner: Bool {
        if case .dataScanner = mode {
            return true
        }
        return false
    }

    init(
        prefersDataScanner: Bool,
        ocrConfiguration: OCRConfiguration = .default
    ) {
        if prefersDataScanner, DataScannerCaptureController.isSupported {
            let controller = DataScannerCaptureController()
            mode = .dataScanner(controller)
            bindDataScanner(controller)
        } else {
            let controller = LiveCaptureController(ocrConfig: ocrConfiguration)
            mode = .legacy(controller)
            bindLegacy(controller)
        }
    }

    func setHandlers(
        onCapture: @escaping (LiveCaptureController.RecognizedPayload) -> Void,
        onError: @escaping (String) -> Void
    ) {
        switch mode {
        case .dataScanner(let controller):
            controller.setHandlers(onCapture: onCapture, onError: onError)
        case .legacy(let controller):
            controller.setHandlers(onCapture: onCapture, onError: onError)
        }
    }

    func start() {
        switch mode {
        case .dataScanner(let controller):
            controller.start()
        case .legacy(let controller):
            controller.start()
        }
    }

    func stop() {
        switch mode {
        case .dataScanner(let controller):
            controller.stop()
        case .legacy(let controller):
            controller.stop()
        }
    }

    func resumeScanning() {
        switch mode {
        case .dataScanner(let controller):
            controller.resumeScanning()
        case .legacy(let controller):
            controller.resumeScanning()
        }
    }

    func finishProcessing() {
        switch mode {
        case .dataScanner(let controller):
            controller.finishProcessing()
        case .legacy(let controller):
            controller.finishProcessing()
        }
    }

    var legacyController: LiveCaptureController? {
        if case .legacy(let controller) = mode {
            return controller
        }
        return nil
    }

    var dataScannerController: DataScannerCaptureController? {
        if case .dataScanner(let controller) = mode {
            return controller
        }
        return nil
    }

    private func bindLegacy(_ controller: LiveCaptureController) {
        controller.$state.receive(on: DispatchQueue.main).sink { [weak self] newState in
            guard let self else { return }
            self.state = State(newState)
        }
        .store(in: &legacyCancellables)

        controller.$readiness.receive(on: DispatchQueue.main).sink { [weak self] readiness in
            self?.readiness = readiness
        }
        .store(in: &legacyCancellables)
    }

    private func bindDataScanner(_ controller: DataScannerCaptureController) {
        controller.stateDidChange = { [weak self] newState in
            self?.state = newState
        }

        controller.readinessDidChange = { [weak self] readiness in
            self?.readiness = readiness
        }
    }

    // MARK: - Private

    @ObservationIgnored
    private var legacyCancellables: Set<AnyCancellable> = []
}

@available(iOS 16.0, *)
@MainActor
@Observable
final class DataScannerCaptureController: NSObject, DataScannerViewControllerDelegate {
    typealias RecognizedPayload = LiveCaptureController.RecognizedPayload

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var stateDidChange: ((AutoCaptureController.State) -> Void)?
    var readinessDidChange: ((LiveCaptureController.ReadinessLevel) -> Void)?

    private(set) var state: AutoCaptureController.State = .idle {
        didSet {
            guard state != oldValue else { return }
            stateDidChange?(state)
        }
    }

    private(set) var readiness: LiveCaptureController.ReadinessLevel = .none {
        didSet {
            guard readiness != oldValue else { return }
            readinessDidChange?(readiness)
        }
    }

    private var onCapture: ((RecognizedPayload) -> Void)?
    private var onError: ((String) -> Void)?

    private var scanner: DataScannerViewController?
    private var pendingCaptureWorkItem: DispatchWorkItem?
    private var hasDeliveredCapture = false

    func setHandlers(
        onCapture: @escaping (RecognizedPayload) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.onCapture = onCapture
        self.onError = onError
    }

    func makeScannerIfNeeded() -> DataScannerViewController? {
        if let scanner {
            return scanner
        }

        do {
            let recognizedDataTypes: Set<DataScannerViewController.RecognizedDataType> = [.text()]
            let controller = try DataScannerViewController(
                recognizedDataTypes: recognizedDataTypes,
                qualityLevel: .balanced,
                recognizesMultipleItems: false,
                isHighFrameRateTrackingEnabled: true,
                isPinchToZoomEnabled: true,
                isGuidanceEnabled: true,
                isHighlightingEnabled: true
            )
            controller.delegate = self
            controller.view.backgroundColor = .clear
            scanner = controller
            return controller
        } catch {
            onError?("Unable to configure data scanner.")
            return nil
        }
    }

    func start() {
        guard let scanner = makeScannerIfNeeded() else { return }
        guard state != .scanning else { return }
        state = .preparing
        pendingCaptureWorkItem?.cancel()
        hasDeliveredCapture = false

        Task { @MainActor in
            do {
                try scanner.startScanning()
                state = .scanning
                readiness = .none
            } catch {
                reportError("Data scanner could not start.")
            }
        }
    }

    func stop() {
        pendingCaptureWorkItem?.cancel()
        scanner?.stopScanning()
        state = .idle
        readiness = .none
        hasDeliveredCapture = false
    }

    func resumeScanning() {
        guard let scanner else {
            start()
            return
        }
        pendingCaptureWorkItem?.cancel()
        hasDeliveredCapture = false
        Task { @MainActor in
            do {
                try scanner.startScanning()
                state = .scanning
                readiness = .none
            } catch {
                reportError("Failed to resume data scanner.")
            }
        }
    }

    func finishProcessing() {
        state = .paused
        readiness = .none
    }

    // MARK: - DataScannerViewControllerDelegate

    func dataScanner(
        _ dataScanner: DataScannerViewController,
        didAdd addedItems: [RecognizedItem],
        allItems: [RecognizedItem]
    ) {
        evaluateReadiness(for: allItems)
        scheduleCaptureIfNeeded(from: allItems)
    }

    func dataScanner(
        _ dataScanner: DataScannerViewController,
        didRemove removedItems: [RecognizedItem],
        allItems: [RecognizedItem]
    ) {
        evaluateReadiness(for: allItems)
    }

    func dataScanner(
        _ dataScanner: DataScannerViewController,
        observedError: (any Error),
        isCritical: Bool
    ) {
        reportError("Scanner error: \(observedError.localizedDescription)")
    }

    // MARK: - Helpers

    private func scheduleCaptureIfNeeded(from items: [RecognizedItem]) {
        guard state == .scanning else { return }
        guard hasDeliveredCapture == false else { return }

        let textItems = Self.textItems(from: items)
        guard !textItems.isEmpty else { return }

        pendingCaptureWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.sendCapture(for: textItems)
        }

        pendingCaptureWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: workItem)
    }

    private func sendCapture(for items: [RecognizedItem.Text]) {
        guard hasDeliveredCapture == false else { return }
        guard let scanner else { return }

        hasDeliveredCapture = true
        state = .processing
        scanner.stopScanning()

        let viewBounds = scanner.view.bounds
        let payloadItems = items.map { textItem -> RecognizedPayload.Item in
            LiveCaptureController.RecognizedPayload.Item(
                text: textItem.transcript,
                boundingBox: Self.normalizedRect(from: textItem.bounds, in: viewBounds)
            )
        }

        let payload = RecognizedPayload(items: payloadItems, capturedImage: nil)
        onCapture?(payload)
    }

    private func evaluateReadiness(for items: [RecognizedItem]) {
        guard state == .scanning else {
            readiness = .none
            return
        }

        let textItems = Self.textItems(from: items)
        if textItems.isEmpty {
            readiness = .tooFar
        } else if textItems.contains(where: { $0.transcript.count > 6 }) {
            readiness = .ready
        } else {
            readiness = .almostReady
        }
    }

    private func reportError(_ message: String) {
        onError?(message)
        state = .error(message)
    }

    private static func textItems(from items: [RecognizedItem]) -> [RecognizedItem.Text] {
        items.compactMap { item in
            if case let .text(text) = item {
                return text
            }
            return nil
        }
    }

    private static func normalizedRect(from bounds: RecognizedItem.Bounds, in viewBounds: CGRect) -> CGRect {
        guard viewBounds.width > 0, viewBounds.height > 0 else { return .zero }

        let points = [bounds.topLeft, bounds.topRight, bounds.bottomRight, bounds.bottomLeft]
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let minY = points.map { $0.y }.min() ?? 0
        let maxY = points.map { $0.y }.max() ?? 0

        let width = max(0, maxX - minX)
        let height = max(0, maxY - minY)

        if width <= 0 || height <= 0 {
            return .zero
        }

        let normalizedX = minX / viewBounds.width
        // Convert from UIKit top-left coordinate space to normalized bottom-left
        let normalizedY = (viewBounds.height - maxY) / viewBounds.height
        let normalizedWidth = width / viewBounds.width
        let normalizedHeight = height / viewBounds.height

        return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
    }
}

@available(iOS 16.0, *)
struct DataScannerContainerView: UIViewControllerRepresentable {
    let controller: DataScannerCaptureController

    func makeUIViewController(context: Context) -> UIViewController {
        ScannerHostingViewController(controller: controller)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // No-op: controller manages scanner state changes.
    }
}

@available(iOS 16.0, *)
private final class ScannerHostingViewController: UIViewController {
    private let controller: DataScannerCaptureController
    private var embeddedScanner: DataScannerViewController?

    init(controller: DataScannerCaptureController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        attachScannerIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        controller.stop()
    }

    private func attachScannerIfNeeded() {
        guard embeddedScanner == nil else { return }
        guard let scanner = controller.makeScannerIfNeeded() else { return }
        embeddedScanner = scanner

        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanner.view)
        NSLayoutConstraint.activate([
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        scanner.didMove(toParent: self)
    }
}

@available(iOS 16.0, *)
extension AutoCaptureController.State {
    var descriptor: (text: LocalizedStringKey, icon: String) {
        switch self {
        case .idle:
            return (LocalizedStringKey("scan.status.default_idle"), "camera")
        case .preparing:
            return (LocalizedStringKey("scan.status.default_preparing"), "camera")
        case .scanning:
            return (LocalizedStringKey("scan.status.default_scanning"), "camera.viewfinder")
        case .processing:
            return (LocalizedStringKey("scan.status.default_processing"), "wand.and.stars")
        case .paused:
            return (LocalizedStringKey("scan.status.default_paused"), "checkmark.circle")
        case .error:
            return (LocalizedStringKey("scan.status.default_error"), "exclamationmark.triangle")
        }
    }
}

#else

@MainActor
typealias AutoCaptureController = LiveCaptureController

#endif

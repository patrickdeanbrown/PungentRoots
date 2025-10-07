#if canImport(MetricKit)

import Foundation
import MetricKit
import os

@MainActor
final class MetricReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricReporter()

    private let logger = Logger(subsystem: "co.ouchieco.PungentRoots", category: "Metrics")

    private override init() {
        super.init()
        MXMetricManager.shared.add(self)
        logger.debug("MetricReporter subscribed to MXMetricManager")
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        logger.debug("Received metric payload count=\(payloads.count, privacy: .public)")
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        logger.warning("Diagnostic payload count=\(payloads.count, privacy: .public)")
    }
}

#endif

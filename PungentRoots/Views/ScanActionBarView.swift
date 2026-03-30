import SwiftUI

struct ScanActionBarView: View {
    let flowModel: ScanFlowModel
    let onSettings: () -> Void

    var body: some View {
        adaptiveGlassGroup(spacing: 14) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    if let badge = statusBadge {
                        Text(badge)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .adaptiveBadgeSurface(tint: badgeTint)
                    }
                }

                HStack(spacing: 12) {
                    if flowModel.phase == .result {
                        Button(action: flowModel.rescan) {
                            Label("Retake Label", systemImage: "camera.rotate")
                                .frame(maxWidth: .infinity)
                        }
                        .adaptivePrimaryButtonStyle()
                        .controlSize(.large)
                        .accessibilityIdentifier("retake-label-button")
                    } else if flowModel.isProcessing {
                        Button(action: {}) {
                            Label(
                                flowModel.phase == .capturing ? "Capturing…" : "Analyzing…",
                                systemImage: flowModel.phase == .capturing ? "camera.shutter.button" : "wand.and.stars"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .disabled(true)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    } else {
                        Button(action: flowModel.captureLabel) {
                            Label("Analyze Label", systemImage: "camera.metering.matrix")
                                .frame(maxWidth: .infinity)
                        }
                        .adaptivePrimaryButtonStyle()
                        .controlSize(.large)
                        .disabled(flowModel.canAnalyzeLabel == false)
                        .accessibilityIdentifier("analyze-label-button")
                    }

                    Button(action: onSettings) {
                        Image(systemName: "slider.horizontal.3")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("scan-settings-button")
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .adaptiveCardSurface(cornerRadius: 24)
        }
    }

    private var title: String {
        switch flowModel.phase {
        case .framing:
            return "Frame the full ingredient list"
        case .capturing:
            return "Capturing the full label"
        case .analyzing:
            return "Reading the captured label"
        case .result:
            return "Review the full-label scan"
        }
    }

    private var subtitle: String {
        switch flowModel.phase {
        case .framing:
            return "Center the ingredient panel, reduce glare, and keep the package as flat as possible."
        case .capturing:
            return "Hold steady while the app saves a high-quality still image for OCR."
        case .analyzing:
            return "The app is reading the full photo, including small or off-center packaging text."
        case .result:
            return flowModel.analysis?.coverageStatus.subtitle ?? "Review the detected terms and transcript before deciding."
        }
    }

    private var statusBadge: String? {
        guard flowModel.phase == .result else { return nil }
        return flowModel.analysis?.coverageStatus.title
    }

    private var badgeTint: Color {
        switch flowModel.analysis?.coverageStatus {
        case .complete:
            return .green
        case .partial:
            return .orange
        case .insufficient:
            return .red
        case nil:
            return .secondary
        }
    }
}

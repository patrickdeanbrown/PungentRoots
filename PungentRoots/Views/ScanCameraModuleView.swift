import SwiftUI

struct ScanCameraModuleView: View {
    let flowModel: ScanFlowModel

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var baseCameraHeight: CGFloat = 340

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thickMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)

                GeometryReader { proxy in
                    previewContent(size: proxy.size)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityElement(children: .contain)
                }
                .padding(6)
            }
            .frame(height: cameraHeight)
            .frame(maxWidth: .infinity)
            .overlay(statusBadgeOverlay, alignment: .topLeading)
            .overlay(alignment: .center) {
                if case .error = flowModel.captureState {
                    errorOverlay
                }
            }
            .padding(.horizontal, -16)
            .accessibilityIdentifier("scan-camera-module")
        }
    }

    private var cameraHeight: CGFloat {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 380 : 320
        return max(minimum, baseCameraHeight)
    }

    @ViewBuilder
    private func previewContent(size: CGSize) -> some View {
#if os(iOS)
        if let controller = flowModel.captureController {
            LabelCameraPreview(controller: controller)
                .overlay(alignmentGuides)
                .overlay(alignment: .bottomLeading) {
                    framingHints
                }
        } else {
            previewFallback
        }
#else
        previewFallback
#endif
    }

    private var previewFallback: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.secondary)
            Text("Camera preview is unavailable in this mode.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.45))
    }

    private var alignmentGuides: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 1, dash: [8, 10]))
                .padding(28)
        }
        .accessibilityHidden(true)
    }

    private var framingHints: some View {
        VStack(alignment: .leading, spacing: 8) {
            tipPill(icon: "viewfinder", text: "Fill the frame with the ingredient panel")
            tipPill(icon: "sun.max", text: "Reduce glare from shiny packaging")
            tipPill(icon: "arrow.up.left.and.down.right.magnifyingglass", text: "Keep curved labels as flat as possible")
        }
        .padding(16)
    }

    private func tipPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(2)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .adaptiveBadgeSurface(tint: .white)
    }

    private var statusBadgeOverlay: some View {
        HStack {
            adaptiveGlassGroup(spacing: 12) {
                statusBadge
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private var statusBadge: some View {
        let descriptor = statusDescriptor
        let stateColor = descriptor.color

        return HStack(spacing: 8) {
            if flowModel.captureState == .scanning || flowModel.isProcessing {
                Circle()
                    .fill(stateColor)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill(stateColor.opacity(0.3))
                            .scaleEffect(1.8)
                    )
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: flowModel.captureState)
            }

            Label(descriptor.text, systemImage: descriptor.icon)
                .font(.footnote.weight(.semibold))
                .symbolEffect(.pulse, options: .repeating, value: flowModel.isProcessing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .adaptiveBadgeSurface(tint: stateColor)
        .shadow(color: stateColor.opacity(0.3), radius: 8, x: 0, y: 2)
        .accessibilityHint(Text("scan.status.accessibility.hint"))
        .accessibilityIdentifier("scan-status-badge")
    }

    private var statusDescriptor: (text: LocalizedStringKey, icon: String, color: Color) {
        switch flowModel.phase {
        case .capturing:
            return (LocalizedStringKey("scan.status.default_capturing"), "camera.shutter.button", .orange)
        case .analyzing:
            return (LocalizedStringKey("scan.status.default_processing"), "wand.and.stars", .orange)
        case .framing:
            switch flowModel.captureReadiness {
            case .none:
                return (LocalizedStringKey("scan.status.default_scanning"), "camera.viewfinder", .blue)
            case .tooFar:
                return (LocalizedStringKey("scan.status.move_closer"), "arrow.down.forward.and.arrow.up.backward", .orange)
            case .almostReady:
                return (LocalizedStringKey("scan.status.almost_ready"), "camera.metering.center.weighted", .yellow)
            case .ready:
                return (LocalizedStringKey("scan.status.ready"), "checkmark.circle", .green)
            }
        case .result:
            let descriptor = flowModel.captureState.descriptor
            return (descriptor.text, descriptor.icon, statusColor(for: flowModel.captureState))
        }
    }

    private func statusColor(for state: CaptureState) -> Color {
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

    private var errorOverlay: some View {
        VStack(spacing: 12) {
            Label("scan.error.title", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Button(action: flowModel.rescan) {
                Label("scan.error.retry", systemImage: "arrow.clockwise")
            }
            .adaptivePrimaryButtonStyle()
        }
        .padding(24)
        .adaptiveCardSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }
}

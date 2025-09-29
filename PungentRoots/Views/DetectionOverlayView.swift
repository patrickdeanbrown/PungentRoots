import SwiftUI

struct DetectionOverlay {
    let id = UUID()
    let rect: CGRect
    let severity: DetectionSeverity

    enum DetectionSeverity {
        case high
        case medium
        case review

        var color: Color {
            switch self {
            case .high: return Color.red.opacity(0.4)
            case .medium: return Color.orange.opacity(0.32)
            case .review: return Color.yellow.opacity(0.25)
            }
        }

        var priority: Int {
            switch self {
            case .high: return 3
            case .medium: return 2
            case .review: return 1
            }
        }

        init(kind: MatchKind) {
            // Map MatchKind priority to severity level
            switch kind.priority {
            case 3:
                self = .high
            case 2:
                self = .medium
            default:
                self = .review
            }
        }
    }
}

struct DetectionOverlayView: View {
    let boxes: [DetectionOverlay]
    let size: CGSize

    var body: some View {
        ZStack {
            ForEach(boxes, id: \.id) { overlay in
                Rectangle()
                    .fill(overlay.severity.color)
                    .overlay(
                        Rectangle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    )
                    .frame(
                        width: overlay.rect.width * size.width,
                        height: overlay.rect.height * size.height
                    )
                    .position(
                        x: overlay.rect.midX * size.width,
                        y: (1 - overlay.rect.midY) * size.height
                    )
                    .animation(.easeInOut(duration: 0.2), value: overlay.id)
            }
        }
        .allowsHitTesting(false)
    }
}
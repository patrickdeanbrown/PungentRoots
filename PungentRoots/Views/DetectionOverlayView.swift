import SwiftUI

struct DetectionOverlay: Identifiable, Equatable {
    let rect: CGRect
    let severity: DetectionSeverity

    var id: String {
        "\(rect.origin.x)-\(rect.origin.y)-\(rect.size.width)-\(rect.size.height)-\(severity.priority)"
    }

    enum DetectionSeverity: Equatable {
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

    static func overlays(for items: [RecognizedTextBlock], matches: [Match]) -> [DetectionOverlay] {
        var severityMap: [String: DetectionSeverity] = [:]
        for match in matches {
            let key = normalizedSearchText(match.term)
            let severity = DetectionSeverity(kind: match.kind)
            if let existing = severityMap[key], existing.priority >= severity.priority {
                continue
            }
            severityMap[key] = severity
        }

        guard !severityMap.isEmpty else {
            return []
        }

        let orderedMap = severityMap.sorted { lhs, rhs in
            lhs.value.priority > rhs.value.priority
        }

        let overlays = items.compactMap { item -> DetectionOverlay? in
            let normalizedItemText = normalizedSearchText(item.text)
            guard let severity = orderedMap.first(where: { containsNormalizedTerm($0.key, in: normalizedItemText) })?.value else {
                return nil
            }

            return DetectionOverlay(rect: item.boundingBox, severity: severity)
        }

        var deduplicated: [DetectionOverlay] = []
        for overlay in overlays {
            if let existingIndex = deduplicated.firstIndex(where: {
                intersectionOverUnion($0.rect, overlay.rect) > 0.72
            }) {
                if overlay.severity.priority > deduplicated[existingIndex].severity.priority {
                    deduplicated[existingIndex] = overlay
                }
            } else {
                deduplicated.append(overlay)
            }
        }

        return deduplicated
    }

    private static func normalizedSearchText(_ text: String) -> String {
        let collapsed = text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
        return " \(collapsed) "
    }

    private static func containsNormalizedTerm(_ term: String, in text: String) -> Bool {
        text.contains(" \(term) ")
    }

    private static func intersectionOverUnion(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let intersection = lhs.intersection(rhs)
        guard intersection.isNull == false else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let unionArea = (lhs.width * lhs.height) + (rhs.width * rhs.height) - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
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

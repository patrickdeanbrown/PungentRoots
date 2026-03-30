import SwiftUI

/// Displays processing state with stage-by-stage feedback
struct ProcessingStateView: View {
    let phase: ScanFlowModel.Phase

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: stage.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                    )
                    .symbolEffect(.pulse, options: .repeating)

                Text(stage.text)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .accessibilityIdentifier("scan-processing-state")
    }

    private var progress: CGFloat {
        switch phase {
        case .framing:
            return 0.05
        case .capturing:
            return 0.35
        case .analyzing:
            return 0.82
        case .result:
            return 1
        }
    }

    private var stage: (icon: String, text: String) {
        switch phase {
        case .framing:
            return ("viewfinder.circle", "Frame the entire ingredient panel before analyzing.")
        case .capturing:
            return ("camera.shutter.button", "Capturing a full-resolution label photo…")
        case .analyzing:
            return ("doc.text.magnifyingglass", "Reading the full label and checking ingredients…")
        case .result:
            return ("checkmark.circle", "Scan complete.")
        }
    }
}

#Preview {
    ProcessingStateView(phase: .analyzing)
        .padding()
}

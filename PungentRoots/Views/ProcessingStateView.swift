import SwiftUI

/// Displays processing state with stage-by-stage feedback
struct ProcessingStateView: View {
    @State private var currentStage: Int = 0

    private let stages = [
        (icon: "camera.fill", text: "Capturing frame..."),
        (icon: "doc.text.magnifyingglass", text: "Analyzing text..."),
        (icon: "list.bullet.clipboard", text: "Checking ingredients...")
    ]

    var body: some View {
        VStack(spacing: 20) {
            // Current stage icon and text
            HStack(spacing: 12) {
                ForEach(0..<stages.count, id: \.self) { index in
                    if index == currentStage {
                        Image(systemName: stages[index].icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.accentColor.opacity(0.15))
                                    .scaleEffect(currentStage == index ? 1.1 : 1.0)
                            )
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: currentStage)
                            .transition(.scale.combined(with: .opacity))
                    }
                }

                Text(stages[min(currentStage, stages.count - 1)].text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .animation(.easeInOut, value: currentStage)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.accentColor)
                        .frame(width: geometry.size.width * progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: currentStage)
                }
            }
            .frame(height: 6)
        }
        .padding(20)
        .onAppear {
            startProgressAnimation()
        }
    }

    private var progress: CGFloat {
        CGFloat(currentStage + 1) / CGFloat(stages.count)
    }

    private func startProgressAnimation() {
        // Stage 1: 0.3s
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                currentStage = 1
            }
        }

        // Stage 2: 0.5s after stage 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                currentStage = 2
            }
        }
    }
}

#Preview {
    ProcessingStateView()
        .padding()
}

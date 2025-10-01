import SwiftUI

/// Displays onboarding instructions when no scan results are available
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Large icon
            Image(systemName: "viewfinder.circle")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, 8)

            // Main instruction
            VStack(spacing: 8) {
                Text("Scan an Ingredient Label")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Point your camera at the ingredient list on food packaging")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Tips
            VStack(alignment: .leading, spacing: 16) {
                tipRow(icon: "viewfinder", text: "Fill the frame with text")
                tipRow(icon: "lightbulb", text: "Use good lighting")
                tipRow(icon: "hand.tap", text: "Hold steady for auto-capture")
            }
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ready to scan. Point your camera at an ingredient label to begin.")
    }

    private func tipRow(icon: String, text: String) -> some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
        }
    }
}

#Preview {
    EmptyStateView()
        .padding()
}

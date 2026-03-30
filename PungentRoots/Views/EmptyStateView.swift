import SwiftUI

/// Displays onboarding instructions when no scan results are available
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "viewfinder.circle")
                .font(.system(size: 72, weight: .thin))
                .foregroundStyle(.secondary.opacity(0.5))
                .padding(.bottom, 8)

            VStack(spacing: 8) {
                Text("Capture the Whole Ingredient Panel")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Use the live preview to frame the full ingredient list before analyzing the label.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            // Tips
            VStack(alignment: .leading, spacing: 16) {
                tipRow(icon: "viewfinder", text: "Fill the frame with the ingredient panel")
                tipRow(icon: "sun.max", text: "Reduce glare from glossy packaging")
                tipRow(icon: "arrow.up.left.and.down.right.magnifyingglass", text: "Keep curved labels as flat as possible")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Ready to scan. Frame the full ingredient panel and use Analyze Label to capture it.")
        .accessibilityIdentifier("scan-empty-state")
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

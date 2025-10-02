import SwiftUI

/// Displays a prominent verdict badge indicating the safety status of scanned ingredients
struct VerdictBadge: View {
    let verdict: Verdict
    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isHeader)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }

    private var icon: String {
        switch verdict {
        case .safe:
            return "checkmark.circle.fill"
        case .needsReview:
            return "exclamationmark.triangle.fill"
        case .contains:
            return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch verdict {
        case .safe:
            return .green
        case .needsReview:
            return .orange
        case .contains:
            return .red
        }
    }

    private var title: String {
        switch verdict {
        case .safe:
            return "Safe to consume"
        case .needsReview:
            return "Review ingredients"
        case .contains:
            return "Contains pungent roots"
        }
    }

    private var subtitle: String? {
        switch verdict {
        case .safe:
            return "No pungent roots detected"
        case .needsReview:
            return "Potential matches found"
        case .contains:
            return "Avoid if sensitive"
        }
    }

    private var accessibilityLabel: String {
        switch verdict {
        case .safe:
            return "Safe to consume. No pungent roots detected."
        case .needsReview:
            return "Review ingredients. Potential matches found that need your attention."
        case .contains:
            return "Contains pungent roots. Avoid if sensitive to onions, garlic, or related ingredients."
        }
    }
}

#Preview("Safe") {
    VerdictBadge(verdict: .safe)
        .padding()
}

#Preview("Needs Review") {
    VerdictBadge(verdict: .needsReview)
        .padding()
}

#Preview("Contains") {
    VerdictBadge(verdict: .contains)
        .padding()
}

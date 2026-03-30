import SwiftUI

@ViewBuilder
func adaptiveGlassGroup<Content: View>(
    spacing: CGFloat = 16,
    @ViewBuilder content: () -> Content
) -> some View {
    if #available(iOS 26.0, *) {
        GlassEffectContainer(spacing: spacing) {
            content()
        }
    } else {
        content()
    }
}

private struct AdaptiveCardSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
        } else {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
                )
        }
    }
}

private struct AdaptiveBadgeSurfaceModifier: ViewModifier {
    let tint: Color

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(
                    .regular
                        .tint(tint.opacity(0.14))
                        .interactive(),
                    in: Capsule()
                )
        } else {
            content
                .background(Capsule().fill(.ultraThinMaterial))
                .overlay(
                    Capsule()
                        .strokeBorder(tint.opacity(0.35), lineWidth: 1)
                )
        }
    }
}

extension View {
    func adaptiveCardSurface(cornerRadius: CGFloat = 24) -> some View {
        modifier(AdaptiveCardSurfaceModifier(cornerRadius: cornerRadius))
    }

    func adaptiveBadgeSurface(tint: Color) -> some View {
        modifier(AdaptiveBadgeSurfaceModifier(tint: tint))
    }

    @ViewBuilder
    func adaptivePrimaryButtonStyle() -> some View {
        if #available(iOS 26.0, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
        }
    }
}

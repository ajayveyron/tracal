import SwiftUI

struct TracalGlassButtonStyle: ButtonStyle {
    enum Role {
        case standard
        case prominent
        case destructive
    }

    @Environment(\.isEnabled) private var isEnabled
    let role: Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .glassEffect(
                glass.interactive(isEnabled),
                in: Capsule(style: .continuous)
            )
            .contentShape(.capsule)
            .opacity(isEnabled ? 1 : 0.42)
    }

    private var glass: Glass {
        switch role {
        case .standard:
            .clear
        case .prominent:
            .regular.tint(TracalColor.glassAccentVibrant.opacity(0.70))
        case .destructive:
            .regular.tint(TracalColor.destructive.opacity(0.22))
        }
    }

    private var foreground: Color {
        switch role {
        case .standard: TracalColor.accent
        case .prominent: TracalColor.accentForeground
        case .destructive: TracalColor.destructive
        }
    }

}

extension ButtonStyle where Self == TracalGlassButtonStyle {
    static var tracalGlass: TracalGlassButtonStyle {
        TracalGlassButtonStyle(role: .standard)
    }

    static var tracalGlassProminent: TracalGlassButtonStyle {
        TracalGlassButtonStyle(role: .prominent)
    }

    static var tracalGlassDestructive: TracalGlassButtonStyle {
        TracalGlassButtonStyle(role: .destructive)
    }
}

struct TonalSurfaceModifier: ViewModifier {
    let level: SurfaceLevel
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(level.color)
            .clipShape(.rect(cornerRadius: radius, style: .continuous))
    }
}

enum SurfaceLevel {
    case secondary
    case tertiary

    var color: Color {
        switch self {
        case .secondary: TracalColor.backgroundSecondary
        case .tertiary: TracalColor.backgroundTertiary
        }
    }
}

extension View {
    func tonalSurface(
        _ level: SurfaceLevel = .secondary,
        radius: CGFloat = TracalRadius.medium
    ) -> some View {
        modifier(TonalSurfaceModifier(level: level, radius: radius))
    }

    func tracalScreenBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(TracalColor.backgroundPrimary.ignoresSafeArea())
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: TracalSpace.small) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(TracalColor.accent)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .foregroundStyle(TracalColor.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(TracalColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(TracalSpace.xLarge)
        .tonalSurface()
    }
}

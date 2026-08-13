import SwiftUI

enum AppTheme {
    // Nastart's visual language: graphite surfaces, warm amber actions, and
    // restrained translucency. Keep the palette semantic so every feature
    // can share the same hierarchy in light and dark appearance.
    static let accent = Color(red: 0.96, green: 0.56, blue: 0.19)
    static let accentDeep = Color(red: 0.72, green: 0.31, blue: 0.08)
    static let softAccent = Color(red: 1.0, green: 0.94, blue: 0.86)
    static let primaryAction = Color(red: 0.10, green: 0.11, blue: 0.13)
    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondarySurface = Color(.secondarySystemGroupedBackground)
    static let elevatedSurface = Color(.secondarySystemBackground)
    static let hairline = Color(.separator).opacity(0.38)
    static let screenGradient = LinearGradient(
        colors: [
            Color(.systemGroupedBackground),
            accent.opacity(0.035),
            Color(.systemGroupedBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let accentGradient = LinearGradient(
        colors: [accent, accentDeep],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct NastartPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, 18)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.99 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.12),
                value: configuration.isPressed
            )
    }

    private var foregroundColor: Color {
        guard isEnabled else { return Color(.secondaryLabel) }
        return colorScheme == .dark ? .black : .white
    }

    private var backgroundColor: Color {
        guard isEnabled else { return Color(.systemGray4) }
        return colorScheme == .dark ? .white : AppTheme.primaryAction
    }
}

struct NastartSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isEnabled ? AppTheme.accent : .secondary)
            .frame(minHeight: 42)
            .padding(.horizontal, 14)
            .background(AppTheme.accent.opacity(isEnabled ? 0.10 : 0.05))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(AppTheme.accent.opacity(isEnabled ? 0.28 : 0.12), lineWidth: 1)
            }
            .opacity(configuration.isPressed && !reduceMotion ? 0.72 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
    }
}

struct NastartStatusChip: View {
    let titleKey: LocalizedStringKey
    let symbol: String
    let color: Color

    var body: some View {
        Label(titleKey, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.11))
            .clipShape(Capsule())
            .overlay {
                Capsule().stroke(color.opacity(0.20), lineWidth: 1)
            }
    }
}

extension View {
    func nastartCard(cornerRadius: CGFloat = 20, elevated: Bool = false) -> some View {
        self
            .background(elevated ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(AppTheme.elevatedSurface))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
            .shadow(
                color: .black.opacity(elevated ? 0.10 : 0.045),
                radius: elevated ? 18 : 8,
                y: elevated ? 9 : 4
            )
    }

    func nastartScreenBackground() -> some View {
        background(AppTheme.screenGradient.ignoresSafeArea())
    }

    func nastartSectionTitle() -> some View {
        font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.7)
    }
}

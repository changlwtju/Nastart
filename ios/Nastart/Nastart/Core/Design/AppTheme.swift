import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.96, green: 0.56, blue: 0.19)
    static let softAccent = Color(red: 1.0, green: 0.94, blue: 0.86)
    static let primaryAction = Color(red: 0.13, green: 0.14, blue: 0.16)
    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondarySurface = Color(.secondarySystemGroupedBackground)
    static let hairline = Color(.separator).opacity(0.38)
}

struct NastartPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme

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
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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

extension View {
    func nastartCard(cornerRadius: CGFloat = 22) -> some View {
        self
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }
}

import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.96, green: 0.56, blue: 0.19)
    static let softAccent = Color(red: 1.0, green: 0.94, blue: 0.86)
    static let background = Color(.systemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let secondarySurface = Color(.secondarySystemGroupedBackground)
    static let hairline = Color(.separator).opacity(0.38)
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

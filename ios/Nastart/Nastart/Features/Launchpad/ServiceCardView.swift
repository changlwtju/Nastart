import SwiftUI

struct ServiceCardView: View {
    let service: LaunchpadService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(service.iconText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(AppTheme.hairline, lineWidth: 1)
                    }

                Spacer()
                StatusDot(status: service.status)
            }

            Spacer(minLength: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(LocalizedStringKey(service.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(minHeight: service.isMedia ? 126 : 108)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(service.isMedia ? AppTheme.accent.opacity(0.26) : AppTheme.hairline, lineWidth: 1)
        }
        .contextMenu {
            Button("action.open") {}
            Button("action.open_external") {}
            Button("action.details") {}
            Button("action.edit") {}
        }
    }

    private var cardBackground: some ShapeStyle {
        service.isMedia ? AnyShapeStyle(AppTheme.softAccent.opacity(0.35)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }
}

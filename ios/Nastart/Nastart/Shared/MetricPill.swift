import SwiftUI

struct MetricPill: View {
    let titleKey: LocalizedStringKey
    let value: String
    let progress: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            if let progress {
                ProgressView(value: progress)
                    .tint(AppTheme.accent)
                    .scaleEffect(x: 1, y: 0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

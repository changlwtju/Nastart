import SwiftUI

struct MetricPill: View {
    let titleKey: LocalizedStringKey
    let value: String
    let progress: Double?
    let symbolName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                if let symbolName {
                    Image(systemName: symbolName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(titleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

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

struct MetricPillSpec: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let value: String
    let progress: Double?
    let symbolName: String?

    init(_ titleKey: String, value: String, progress: Double? = nil, symbolName: String? = nil) {
        self.id = titleKey
        self.titleKey = LocalizedStringKey(titleKey)
        self.value = value
        self.progress = progress
        self.symbolName = symbolName ?? Self.defaultSymbolName(for: titleKey)
    }

    private static func defaultSymbolName(for titleKey: String) -> String? {
        switch titleKey {
        case "metric.cpu": return "cpu"
        case "metric.memory": return "memorychip"
        case "metric.storage": return "internaldrive"
        case "metric.tls": return "lock.shield"
        case "metric.uptime": return "clock"
        default: return nil
        }
    }
}

struct MetricPillRow: View {
    let metrics: [MetricPillSpec]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                ForEach(metrics) { metric in
                    MetricPill(titleKey: metric.titleKey, value: metric.value, progress: metric.progress, symbolName: metric.symbolName)
                }
            }

            VStack(spacing: 10) {
                ForEach(metrics) { metric in
                    MetricPill(titleKey: metric.titleKey, value: metric.value, progress: metric.progress, symbolName: metric.symbolName)
                }
            }
        }
    }
}

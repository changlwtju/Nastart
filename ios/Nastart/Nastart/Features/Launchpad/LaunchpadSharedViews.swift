import SwiftUI

extension ServiceStatus {
    var titleKey: String {
        switch self {
        case .online: return "status.online"
        case .installed: return "status.installed"
        case .warning: return "status.warning"
        case .offline: return "status.offline"
        case .unknown: return "status.unknown"
        }
    }
}

struct CertificateReminderStrip: View {
    let days: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield")
                .font(.subheadline.weight(.medium))
            Text("launchpad.reminder.cert \(days)")
                .font(.subheadline)
            Spacer()
            Text("action.view")
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

struct LiveUptimeText: View {
    let baseMinutes: Int
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 60)) { context in
            Text(displayText(at: context.date))
        }
    }

    private func displayText(at date: Date) -> String {
        let elapsedMinutes = max(0, Int(date.timeIntervalSince(startedAt)) / 60)
        return NASUptimeFormatter.string(totalMinutes: baseMinutes + elapsedMinutes)
    }
}

struct DeviceSummaryPanel: View {
    let device: NASDevice
    let compact: Bool
    let isConnected: Bool
    var theme: LaunchpadTheme = .cleanGrid

    @ViewBuilder
    var body: some View {
        switch theme {
        case .cleanGrid:
            summaryContent
                .padding(compact ? 14 : 16)
                .nastartCard(cornerRadius: 18)
        case .commandCenter:
            HStack(alignment: .center, spacing: 14) {
                VStack(spacing: compact ? 14 : 18) {
                    ForEach(metrics) { metric in
                        VStack(spacing: 5) {
                            Label(metric.titleKey, systemImage: metric.symbolName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.8))
                            Text(metric.value)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 6)
                .frame(width: compact ? 82 : 96)
                .background(AppTheme.primaryAction)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    titleCluster
                    statusCluster(alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(compact ? 14 : 16)
            .nastartCard(cornerRadius: 18)
        case .glassDeck:
            summaryContent
                .padding(compact ? 14 : 16)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.4), lineWidth: 1)
                }
        }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 15) {
            header
            LaunchpadNASMetricRow(metrics: metrics, compact: compact)
        }
    }

    @ViewBuilder
    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titleCluster
                Spacer(minLength: 10)
                statusCluster(alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 10) {
                titleCluster
                statusCluster(alignment: .leading)
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(systemName: "server.rack")
                .font(.system(size: compact ? 17 : 19, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: compact ? 38 : 42, height: compact ? 38 : 42)
                .background(AppTheme.accent.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font((compact ? Font.headline : Font.title3).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Label {
                    Text(LocalizedStringKey(summaryKey))
                } icon: {
                    Image(systemName: summarySymbol)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(summaryColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }
        }
        .layoutPriority(1)
    }

    private func statusCluster(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            LaunchpadNASConnectionBadge(isConnected: isConnected)
            if isConnected, let uptimeMinutes = device.uptimeMinutes {
                LaunchpadNASUptimeBadge(deviceID: device.id, baseMinutes: uptimeMinutes)
            }
        }
    }

    private var summaryKey: String {
        guard isConnected else { return "state.not_connected" }
        return activeWarning?.titleKey ?? "launchpad.summary.normal"
    }

    private var summarySymbol: String {
        guard isConnected else { return "wifi.slash" }
        return activeWarning?.symbolName ?? "checkmark.circle.fill"
    }

    private var summaryColor: Color {
        guard isConnected else { return .secondary }
        return activeWarning == nil ? .green : AppTheme.accent
    }

    private var activeWarning: LaunchpadResourceWarning? {
        LaunchpadResourceWarning.primary(for: device)
    }

    private var metrics: [LaunchpadNASMetricSpec] {
        [
            LaunchpadNASMetricSpec(
                titleKey: "metric.cpu",
                value: launchpadPercentText(device.cpu),
                progress: device.cpu,
                symbolName: "cpu"
            ),
            LaunchpadNASMetricSpec(
                titleKey: "metric.memory_ram",
                value: launchpadPercentText(device.memory),
                progress: device.memory,
                symbolName: "memorychip"
            ),
            LaunchpadNASMetricSpec(
                titleKey: "metric.storage_disk",
                value: launchpadPercentText(device.storageUsed),
                progress: device.storageUsed,
                symbolName: "internaldrive"
            )
        ]
    }
}

private struct LaunchpadNASConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(LocalizedStringKey(isConnected ? "status.online" : "state.not_connected"))
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(statusColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(statusColor.opacity(0.10))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        isConnected ? .green : .secondary
    }
}

private struct LaunchpadNASUptimeBadge: View {
    let deviceID: UUID
    let baseMinutes: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "clock")
                .font(.caption2.weight(.medium))
            LiveUptimeText(baseMinutes: baseMinutes)
                .id(deviceID)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct LaunchpadNASMetricSpec: Identifiable {
    let id: String
    let titleKey: LocalizedStringKey
    let value: String
    let progress: Double?
    let symbolName: String

    init(titleKey: String, value: String, progress: Double?, symbolName: String) {
        self.id = titleKey
        self.titleKey = LocalizedStringKey(titleKey)
        self.value = value
        self.progress = progress
        self.symbolName = symbolName
    }
}

private struct LaunchpadNASMetricRow: View {
    let metrics: [LaunchpadNASMetricSpec]
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: compact ? 8 : 10) {
                metricViews
            }

            VStack(spacing: 10) {
                metricViews
            }
        }
    }

    private var metricViews: some View {
        ForEach(metrics) { metric in
            LaunchpadNASMetricTile(metric: metric, compact: compact)
        }
    }
}

private struct LaunchpadNASMetricTile: View {
    let metric: LaunchpadNASMetricSpec
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 7) {
            HStack(spacing: 5) {
                Image(systemName: metric.symbolName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(metric.titleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(metric.value)
                .font((compact ? Font.subheadline : Font.headline).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            ProgressView(value: normalizedProgress)
                .tint(AppTheme.accent)
                .scaleEffect(x: 1, y: 0.72)
                .opacity(metric.progress == nil ? 0.35 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compact ? 10 : 12)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var normalizedProgress: Double {
        min(max(metric.progress ?? 0, 0), 1)
    }
}

func launchpadPercentText(_ value: Double?) -> String {
    guard let value else { return "-" }
    return "\(Int((value * 100).rounded()))%"
}

func launchpadServicePercentText(_ value: Double?) -> String {
    guard let value else { return "-" }
    let percentage = value * 100
    if percentage > 0, percentage < 10 {
        return String(format: "%.1f%%", percentage)
    }
    return "\(Int(percentage.rounded()))%"
}

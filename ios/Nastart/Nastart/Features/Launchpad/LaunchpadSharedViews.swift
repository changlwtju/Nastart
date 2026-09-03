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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(LocalizedStringKey(summaryKey))
                } icon: {
                    Image(systemName: summarySymbol)
                }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if let uptimeMinutes = device.uptimeMinutes {
                    LiveUptimeText(baseMinutes: uptimeMinutes)
                        .id(device.id)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if compact {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu"),
                    MetricPillSpec("metric.memory_ram", value: launchpadPercentText(device.memory), symbolName: "memorychip"),
                    MetricPillSpec("metric.storage_disk", value: launchpadPercentText(device.storageUsed), symbolName: "internaldrive")
                ])
            } else {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), progress: device.cpu, symbolName: "cpu"),
                    MetricPillSpec("metric.memory_ram", value: launchpadPercentText(device.memory), progress: device.memory, symbolName: "memorychip"),
                    MetricPillSpec("metric.storage_disk", value: launchpadPercentText(device.storageUsed), progress: device.storageUsed, symbolName: "internaldrive")
                ])
            }
        }
        .padding(14)
        .nastartCard(cornerRadius: 22)
    }

    private var summaryKey: String {
        guard isConnected else { return "state.not_connected" }
        return activeWarning?.titleKey ?? "launchpad.summary.normal"
    }

    private var summarySymbol: String {
        guard isConnected else { return "wifi.slash" }
        return activeWarning?.symbolName ?? "checkmark.circle.fill"
    }

    private var activeWarning: LaunchpadResourceWarning? {
        LaunchpadResourceWarning.primary(for: device)
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

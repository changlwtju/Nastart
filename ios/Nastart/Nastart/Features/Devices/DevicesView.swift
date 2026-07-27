import SwiftUI

struct DevicesView: View {
    private let device = SampleData.device
    private let services = SampleData.services

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.name)
                                    .font(.title2.weight(.bold))
                                Text(device.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label("status.online", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        }

                        HStack(spacing: 10) {
                            MetricPill(titleKey: "metric.cpu", value: "11%", progress: device.cpu)
                            MetricPill(titleKey: "metric.memory", value: "32%", progress: device.memory)
                            MetricPill(titleKey: "metric.storage", value: device.storageFreeText, progress: device.storageUsed)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("devices.section.resources") {
                    NavigationLink {
                        DeviceDetailView(device: device, services: services)
                    } label: {
                        Label("devices.resource.overview", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink {
                        ContainersPlaceholderView()
                    } label: {
                        Label("devices.resource.containers", systemImage: "shippingbox")
                    }
                    NavigationLink {
                        FilesPlaceholderView()
                    } label: {
                        Label("devices.resource.files", systemImage: "folder")
                    }
                }

                Section("devices.section.maintenance") {
                    Label("devices.maintenance.certificate", systemImage: "lock.shield")
                    Label("devices.maintenance.discovery", systemImage: "sparkle.magnifyingglass")
                    Label("devices.maintenance.agent", systemImage: "antenna.radiowaves.left.and.right")
                }
            }
            .navigationTitle("tab.devices")
        }
    }
}

private struct DeviceDetailView: View {
    let device: NASDevice
    let services: [LaunchpadService]

    var body: some View {
        List {
            Section("devices.detail.status") {
                LabeledContent("metric.uptime", value: device.uptimeText)
                LabeledContent("devices.detail.mode", value: device.subtitle)
                LabeledContent("devices.detail.certificate", value: "\(device.certificateDaysRemaining)d")
            }

            Section("devices.resource.containers") {
                ForEach(services) { service in
                    HStack {
                        Text(service.iconText)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        VStack(alignment: .leading) {
                            Text(service.name)
                            Text(LocalizedStringKey(service.detail))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(device.name)
    }
}

private struct ContainersPlaceholderView: View {
    var body: some View {
        PlaceholderView(titleKey: "devices.resource.containers", systemImage: "shippingbox", descriptionKey: "devices.placeholder.agent")
            .navigationTitle("devices.resource.containers")
    }
}

private struct FilesPlaceholderView: View {
    var body: some View {
        PlaceholderView(titleKey: "devices.resource.files", systemImage: "folder", descriptionKey: "devices.placeholder.files")
            .navigationTitle("devices.resource.files")
    }
}

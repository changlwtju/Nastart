import SwiftUI

struct DevicesView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var showRediscoverHint = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(dataStore.device.name)
                                    .font(.title2.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                                Text(dataStore.device.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.82)
                            }
                            .layoutPriority(1)
                            Spacer()
                            Label("status.online", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        MetricPillRow(metrics: [
                            MetricPillSpec("metric.cpu", value: devicePercentText(dataStore.device.cpu), progress: dataStore.device.cpu),
                            MetricPillSpec("metric.memory", value: devicePercentText(dataStore.device.memory), progress: dataStore.device.memory),
                            MetricPillSpec("metric.storage", value: dataStore.device.storageFreeText, progress: dataStore.device.storageUsed)
                        ])
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    NavigationLink {
                        DeviceStatusView(device: dataStore.device)
                    } label: {
                        Label("devices.resource.overview", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink {
                        DockerContainersView(containers: dataStore.containers)
                    } label: {
                        Label("devices.resource.containers", systemImage: "shippingbox")
                    }
                    NavigationLink {
                        FileBrowserView(titleKey: "devices.resource.files", items: dataStore.files)
                    } label: {
                        Label("devices.resource.files", systemImage: "folder")
                    }
                    NavigationLink {
                        NetworkDetailView(services: dataStore.services)
                    } label: {
                        Label("devices.resource.network", systemImage: "network")
                    }
                } header: {
                    Text("devices.section.resources")
                }

                Section {
                    NavigationLink {
                        CertificateSecurityView(device: dataStore.device)
                    } label: {
                        Label("devices.maintenance.certificate", systemImage: "lock.shield")
                    }
                    Button {
                        if let session = connectionStore.dsmSession {
                            Task {
                                await dataStore.refreshDSM(session: session, useAgent: connectionStore.usesAgent)
                            }
                        } else {
                            dataStore.refreshAll()
                        }
                        showRediscoverHint = true
                    } label: {
                        Label("devices.maintenance.discovery", systemImage: "magnifyingglass")
                    }
                    NavigationLink {
                        AgentStatusView()
                    } label: {
                        Label("devices.maintenance.agent", systemImage: "antenna.radiowaves.left.and.right")
                    }
                } header: {
                    Text("devices.section.maintenance")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("tab.devices")
            .alert("devices.discovery.hint", isPresented: $showRediscoverHint) {
                Button("action.ok", role: .cancel) {}
            }
        }
    }
}

struct DeviceStatusView: View {
    let device: NASDevice

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text("devices.status.title")
                        .font(.title2.weight(.bold))
                    MetricPillRow(metrics: [
                        MetricPillSpec("metric.cpu", value: devicePercentText(device.cpu), progress: device.cpu),
                        MetricPillSpec("metric.memory", value: devicePercentText(device.memory), progress: device.memory),
                        MetricPillSpec("metric.storage", value: device.storageFreeText, progress: device.storageUsed)
                    ])
                }
                .padding(.vertical, 8)
            }

            Section {
                LabeledContent("metric.uptime", value: device.uptimeText)
                LabeledContent("devices.detail.mode", value: device.subtitle)
                LabeledContent("devices.detail.certificate", value: "\(device.certificateDaysRemaining)d")
                LabeledContent("devices.status.temperature", value: "41 C")
                LabeledContent("devices.status.network", value: "LAN - 32 ms")
            } header: {
                Text("devices.detail.status")
            }

            Section {
                DiagnosisRow(titleKey: "devices.diagnosis.reachable", valueKey: "devices.diagnosis.good", symbol: "checkmark.circle")
                DiagnosisRow(titleKey: "devices.diagnosis.certificate", valueKey: "devices.diagnosis.watch", symbol: "lock.shield")
                DiagnosisRow(titleKey: "devices.diagnosis.agent", valueKey: "devices.diagnosis.good", symbol: "antenna.radiowaves.left.and.right")
            } header: {
                Text("devices.status.diagnosis")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(device.name)
    }
}

private func devicePercentText(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

private struct DiagnosisRow: View {
    let titleKey: LocalizedStringKey
    let valueKey: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body)
                .frame(width: 28, height: 28)
            Text(titleKey)
            Spacer()
            Text(valueKey)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DockerContainersView: View {
    let containers: [DockerContainer]

    var body: some View {
        List {
            Section {
                ForEach(containers) { container in
                    NavigationLink {
                        DockerContainerDetailView(container: container)
                    } label: {
                        DockerContainerRow(container: container)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.resource.containers")
    }
}

private struct DockerContainerRow: View {
    let container: DockerContainer

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(container.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    StatusDot(status: container.status)
                }
                Text(container.image)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .layoutPriority(1)
            Spacer()
            Text(container.memoryText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

private struct DockerContainerDetailView: View {
    let container: DockerContainer
    @State private var actionMessageKey = "devices.container.action_hint"
    @State private var showActionHint = false

    var body: some View {
        List {
            Section {
                DockerContainerRow(container: container)
            }

            Section {
                LabeledContent("metric.cpu", value: "\(Int(container.cpu * 100))%")
                LabeledContent("metric.memory", value: container.memoryText)
            } header: {
                Text("devices.container.metrics")
            }

            Section {
                ForEach(container.ports, id: \.self) { port in
                    Text(port)
                }
            } header: {
                Text("devices.container.ports")
            }

            Section {
                Button("devices.container.open_logs") {
                    showAction("devices.container.logs_hint")
                }
                Button("devices.container.restart") {
                    showAction("devices.container.restart_hint")
                }
                Button("devices.container.stop", role: .destructive) {
                    showAction("devices.container.stop_hint")
                }
            } header: {
                Text("devices.container.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(container.name)
        .alert(LocalizedStringKey(actionMessageKey), isPresented: $showActionHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func showAction(_ key: String) {
        actionMessageKey = key
        showActionHint = true
    }
}

private struct FileBrowserView: View {
    let titleKey: LocalizedStringKey
    let items: [FileItem]

    var body: some View {
        List {
            Section {
                ForEach(items) { item in
                    FileItemRowLink(item: item)
                }
            } header: {
                Text("devices.files.favorites")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(titleKey)
    }
}

private struct FileItemRowLink: View {
    let item: FileItem

    var body: some View {
        if item.isFolder {
            NavigationLink {
                FileBrowserView(titleKey: LocalizedStringKey(item.name), items: item.children)
            } label: {
                FileItemRow(item: item)
            }
        } else {
            NavigationLink {
                FilePreviewView(item: item)
            } label: {
                FileItemRow(item: item)
            }
        }
    }
}

private struct FileItemRow: View {
    let item: FileItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.kind.symbolName)
                .font(.title3)
                .foregroundStyle(item.isFolder ? .yellow : .primary)
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.body.weight(.medium))
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let sizeText = item.sizeText {
                Text(sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct FilePreviewView: View {
    let item: FileItem
    @State private var showExternalPicker = false
    @State private var showPreviewHint = false
    @State private var showFavoriteHint = false
    @State private var externalMessageKey = "external.files_hint"
    @State private var showExternalHint = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: item.kind.symbolName)
                        .font(.system(size: 44, weight: .regular))
                    Text(item.name)
                        .font(.title2.weight(.bold))
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Button("devices.files.preview") {
                    showPreviewHint = true
                }
                Button("devices.files.open_external") {
                    showExternalPicker = true
                }
                Button("devices.files.favorite") {
                    showFavoriteHint = true
                }
            } header: {
                Text("devices.files.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.files.preview")
        .alert("devices.files.preview_hint", isPresented: $showPreviewHint) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("devices.files.favorite_hint", isPresented: $showFavoriteHint) {
            Button("action.ok", role: .cancel) {}
        }
        .confirmationDialog("service.external.title", isPresented: $showExternalPicker) {
            Button("Infuse") { showExternal("external.infuse_hint") }
            Button("VidHub") { showExternal("external.vidhub_hint") }
            Button("VLC") { showExternal("external.vlc_hint") }
            Button("Files") { showExternal("external.files_hint") }
            Button("action.cancel", role: .cancel) {}
        }
        .alert(LocalizedStringKey(externalMessageKey), isPresented: $showExternalHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func showExternal(_ key: String) {
        externalMessageKey = key
        showExternalHint = true
    }
}

private struct NetworkDetailView: View {
    let services: [LaunchpadService]

    var body: some View {
        List {
            Section {
                ForEach(services) { service in
                    HStack {
                        Text(service.name)
                        Spacer()
                        StatusDot(status: service.status)
                    }
                }
            } header: {
                Text("devices.network.reachability")
            }

            Section {
                LabeledContent("DSM", value: "5001")
                LabeledContent("Jellyfin", value: "8096")
                LabeledContent("Navidrome", value: "4533")
            } header: {
                Text("devices.network.ports")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.resource.network")
    }
}

private struct CertificateSecurityView: View {
    let device: NASDevice
    @State private var showCheckHint = false
    @State private var showReminderHint = false

    var body: some View {
        List {
            Section {
                LabeledContent("devices.detail.certificate", value: "\(device.certificateDaysRemaining)d")
                LabeledContent("devices.cert.domain", value: "nas.example.com")
                LabeledContent("devices.cert.issuer", value: "Let's Encrypt")
            }

            Section {
                Button("devices.cert.create_task") {
                    showReminderHint = true
                }
                Button("devices.cert.check_now") {
                    showCheckHint = true
                }
            } header: {
                Text("devices.cert.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.maintenance.certificate")
        .alert("devices.cert.reminder_hint", isPresented: $showReminderHint) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("devices.cert.check_hint", isPresented: $showCheckHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct AgentStatusView: View {
    var body: some View {
        List {
            Section {
                LabeledContent("devices.agent.mode", value: "DSM + Agent")
                LabeledContent("devices.agent.version", value: "0.1.0")
                LabeledContent("devices.agent.last_seen", value: "2 min")
            }

            Section {
                Label("Docker", systemImage: "shippingbox")
                Label("devices.agent.scope.metrics", systemImage: "chart.line.uptrend.xyaxis")
                Label("devices.agent.scope.discovery", systemImage: "magnifyingglass")
            } header: {
                Text("devices.agent.scope")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.maintenance.agent")
    }
}

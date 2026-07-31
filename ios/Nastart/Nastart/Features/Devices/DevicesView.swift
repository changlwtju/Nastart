import SwiftUI
import UIKit
import QuickLook

struct DevicesView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var showRediscoverHint = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DeviceHealthHeader(
                        device: dataStore.device,
                        isConnected: connectionStore.isConnected
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    NavigationLink {
                        DeviceStatusView(device: dataStore.device)
                    } label: {
                        Label("devices.resource.overview", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    NavigationLink {
                        ServiceResourcesView()
                    } label: {
                        resourceLabel(
                            "devices.resource.services",
                            systemImage: "chart.bar.xaxis",
                            count: runningContainers.count
                        )
                    }
                    NavigationLink {
                        DockerContainersView(containers: dataStore.containers)
                    } label: {
                        resourceLabel(
                            "devices.resource.containers",
                            systemImage: "shippingbox",
                            count: dataStore.containers.count
                        )
                    }
                    NavigationLink {
                        PackageServicesView(services: packageServices)
                    } label: {
                        resourceLabel(
                            "devices.resource.packages",
                            systemImage: "square.stack.3d.up",
                            count: packageServices.count
                        )
                    }
                    NavigationLink {
                        FileBrowserView(titleKey: "devices.resource.files", items: dataStore.files)
                    } label: {
                        Label("devices.resource.files", systemImage: "folder")
                    }
                    NavigationLink {
                        NetworkDetailView(
                            services: dataStore.services,
                            baseURL: connectionStore.dsmSession?.baseURL
                        )
                    } label: {
                        Label("devices.resource.network", systemImage: "network")
                    }
                } header: {
                    Text("devices.section.resources")
                }

                Section {
                    NavigationLink {
                        CertificateSecurityView()
                    } label: {
                        Label("devices.maintenance.certificate", systemImage: "lock.shield")
                    }
                    Button {
                        Task {
                            if let session = connectionStore.dsmSession {
                                await dataStore.refreshDSM(session: session, useAgent: connectionStore.usesAgent)
                            } else {
                                await MainActor.run {
                                    dataStore.refreshAll()
                                }
                            }
                            await MainActor.run {
                                showRediscoverHint = true
                            }
                        }
                    } label: {
                        HStack {
                            Label("devices.maintenance.discovery", systemImage: "magnifyingglass")
                            Spacer()
                            if dataStore.isRefreshing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(dataStore.isRefreshing)
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
            .padding(.top, -12)
            .navigationTitle("tab.devices")
            .navigationBarTitleDisplayMode(.inline)
            .alert("devices.discovery.hint", isPresented: $showRediscoverHint) {
                Button("action.ok", role: .cancel) {}
            }
        }
    }

    private var packageServices: [LaunchpadService] {
        dataStore.services.filter { $0.source == .package }
    }

    private var runningContainers: [DockerContainer] {
        dataStore.containers.filter { $0.status == .online }
    }

    private func resourceLabel(_ key: String, systemImage: String, count: Int) -> some View {
        HStack {
            Label(LocalizedStringKey(key), systemImage: systemImage)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct DeviceHealthHeader: View {
    let device: NASDevice
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(device.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(device.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                DeviceConnectionBadge(isConnected: isConnected)
            }

            HStack(alignment: .top, spacing: 10) {
                DeviceHealthMetric(
                    titleKey: "metric.cpu",
                    value: devicePercentText(device.cpu),
                    progress: device.cpu,
                    symbol: "cpu"
                )
                DeviceHealthMetric(
                    titleKey: "metric.memory_ram",
                    value: devicePercentText(device.memory),
                    progress: device.memory,
                    symbol: "memorychip"
                )
                DeviceHealthMetric(
                    titleKey: "metric.storage_disk",
                    value: devicePercentText(device.storageUsed),
                    progress: device.storageUsed,
                    symbol: "internaldrive"
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct DeviceConnectionBadge: View {
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isConnected ? Color.green : Color.secondary)
                .frame(width: 7, height: 7)
            Text(LocalizedStringKey(isConnected ? "status.online" : "state.not_connected"))
                .lineLimit(1)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(isConnected ? Color.green : Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background((isConnected ? Color.green : Color.secondary).opacity(0.1))
        .clipShape(Capsule())
    }
}

private struct DeviceHealthMetric: View {
    let titleKey: LocalizedStringKey
    let value: String
    let progress: Double?
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2.weight(.medium))
                Text(titleKey)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            ProgressView(value: normalizedProgress)
                .tint(AppTheme.accent)
                .scaleEffect(x: 1, y: 0.72)
                .opacity(progress == nil ? 0.35 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var normalizedProgress: Double {
        min(max(progress ?? 0, 0), 1)
    }
}

struct DeviceStatusView: View {
    let device: NASDevice

    var body: some View {
        List {
            Section {
                LabeledContent("devices.detail.name", value: device.name)
                if let model = device.model {
                    LabeledContent("devices.detail.model", value: model)
                }
                if let dsmVersion = device.dsmVersion {
                    LabeledContent("devices.detail.dsm_version", value: dsmVersion)
                }
                LabeledContent("metric.uptime", value: device.uptimeText)
                LabeledContent("devices.detail.mode", value: deviceConnectionText(device.mode))
                LabeledContent("devices.detail.certificate", value: certificateDaysText(device.certificateDaysRemaining))
                LabeledContent("devices.status.temperature", value: device.temperatureText ?? "-")
                LabeledContent("devices.security.ssh", value: sshStatusText(device.sshStatus))
            } header: {
                Text("devices.detail.status")
            }

            Section {
                LabeledContent("metric.memory_ram", value: device.memoryDisplayText)
                LabeledContent("metric.storage_disk", value: device.storageDisplayText)
                LabeledContent("devices.status.storage_free", value: device.storageFreeText)
            } header: {
                Text("devices.status.capacity")
            }

            Section {
                DiagnosisRow(titleKey: "devices.diagnosis.reachable", valueKey: "devices.diagnosis.good", symbol: "checkmark.circle")
                DiagnosisRow(
                    titleKey: "devices.diagnosis.certificate",
                    valueKey: device.certificate == nil ? "status.unknown" : "devices.diagnosis.watch",
                    symbol: "lock.shield"
                )
                DiagnosisRow(
                    titleKey: "devices.diagnosis.agent",
                    valueKey: device.mode == .dsmWithAgent ? "devices.diagnosis.good" : "status.unknown",
                    symbol: "antenna.radiowaves.left.and.right"
                )
            } header: {
                Text("devices.status.diagnosis")
            }
        }
        .listStyle(.insetGrouped)
        .padding(.top, -12)
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func devicePercentText(_ value: Double?) -> String {
    guard let value else { return "-" }
    return "\(Int((value * 100).rounded()))%"
}

private func containerPercentText(_ value: Double?) -> String {
    guard let value else { return "-" }
    let percentage = value * 100
    if percentage > 0, percentage < 10 {
        return String(format: "%.1f%%", percentage)
    }
    return "\(Int(percentage.rounded()))%"
}

private func certificateDaysText(_ days: Int?) -> String {
    guard let days else { return "-" }
    return String(format: NSLocalizedString("devices.cert.days_remaining %lld", comment: ""), days)
}

private func deviceConnectionText(_ mode: ConnectionMode) -> String {
    switch mode {
    case .dsmOnly: return "DSM"
    case .dsmWithAgent: return "DSM + Agent"
    case .agentOnly: return "Agent"
    case .manualOnly: return "-"
    }
}

private func sshStatusText(_ status: NASSSHStatus) -> String {
    switch status {
    case .enabled: return NSLocalizedString("state.on", comment: "")
    case .disabled: return NSLocalizedString("state.off", comment: "")
    case .unavailable: return NSLocalizedString("status.unknown", comment: "")
    }
}

private func certificateTrustText(_ certificate: NASCertificateInfo?) -> String {
    guard let certificate else { return "-" }
    return NSLocalizedString(
        certificate.usesCustomTrust ? "devices.cert.trust.custom" : "devices.cert.trust.system",
        comment: ""
    )
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

private enum ServiceResourceSort: String, CaseIterable, Identifiable {
    case cpu
    case memory

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .cpu: return "metric.cpu"
        case .memory: return "metric.memory"
        }
    }
}

private struct ServiceResourcesView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var sort: ServiceResourceSort = .memory

    var body: some View {
        List {
            Section {
                MetricPillRow(metrics: [
                    MetricPillSpec(
                        "metric.cpu",
                        value: devicePercentText(dataStore.device.cpu),
                        progress: dataStore.device.cpu
                    ),
                    MetricPillSpec(
                        "metric.memory",
                        value: devicePercentText(dataStore.device.memory),
                        progress: dataStore.device.memory
                    )
                ])

                LabeledContent(
                    "devices.resources.running",
                    value: "\(runningContainers.count)"
                )
            } header: {
                Text("devices.resources.system")
            }

            Section {
                Picker("devices.resources.sort", selection: $sort) {
                    ForEach(ServiceResourceSort.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                if sortedContainers.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("devices.resources.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(sortedContainers) { container in
                        ServiceResourceRow(container: container, sort: sort)
                    }
                }
            } header: {
                Text("devices.resources.services")
            } footer: {
                Text("devices.resources.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.resource.services")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            guard let session = connectionStore.dsmSession else { return }
            await dataStore.refreshDSM(
                session: session,
                useAgent: connectionStore.usesAgent
            )
        }
    }

    private var runningContainers: [DockerContainer] {
        dataStore.containers.filter { $0.status == .online }
    }

    private var sortedContainers: [DockerContainer] {
        runningContainers.sorted { lhs, rhs in
            switch sort {
            case .cpu:
                if lhs.cpu != rhs.cpu {
                    return (lhs.cpu ?? -1) > (rhs.cpu ?? -1)
                }
            case .memory:
                if lhs.memoryPercent != rhs.memoryPercent {
                    return (lhs.memoryPercent ?? -1) > (rhs.memoryPercent ?? -1)
                }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private struct ServiceResourceRow: View {
    let container: DockerContainer
    let sort: ServiceResourceSort

    var body: some View {
        HStack(spacing: 12) {
            ContainerServiceIcon(name: container.name, size: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(container.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    StatusDot(status: container.status)
                }
                Text(secondaryMetricText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(primaryMetricText)
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text(primaryMetricLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.vertical, 3)
    }

    private var primaryMetricText: String {
        switch sort {
        case .cpu:
            return containerPercentText(container.cpu)
        case .memory:
            return containerPercentText(container.memoryPercent)
        }
    }

    private var primaryMetricLabel: String {
        switch sort {
        case .cpu:
            return NSLocalizedString("metric.cpu", comment: "")
        case .memory:
            return NSLocalizedString("devices.container.memory_percent", comment: "")
        }
    }

    private var secondaryMetricText: String {
        guard container.memoryText != "-" else {
            return NSLocalizedString("devices.container.runtime_memory_unavailable", comment: "")
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("devices.container.runtime_memory_value", comment: ""),
            container.memoryText
        )
    }

}

private struct ContainerServiceIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(width: size, height: size)
            .background(AppTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }

    private var symbolName: String {
        let normalizedName = name.lowercased()
        let mappings: [(keywords: [String], symbol: String)] = [
            (["jellyfin", "emby", "plex"], "play.rectangle"),
            (["navidrome", "music"], "music.note.list"),
            (["qbittorrent", "transmission", "aria2", "download"], "arrow.down.circle"),
            (["homeassistant", "home-assistant", "home assistant", "homepage"], "house"),
            (["code-server", "codex-server", "jupyter"], "terminal"),
            (["sonarr", "radarr", "prowlarr", "mediamanager"], "film.stack"),
            (["nginx", "traefik", "caddy", "proxy"], "lock.rectangle"),
            (["adguard", "pihole", "pi-hole"], "shield"),
            (["vaultwarden", "bitwarden"], "key"),
            (["immich", "photo"], "photo"),
            (["ddns", "tailscale", "zerotier", "mihomo", "clash"], "network")
        ]
        return mappings.first { mapping in
            mapping.keywords.contains { normalizedName.contains($0) }
        }?.symbol ?? "shippingbox"
    }
}

private struct PackageServicesView: View {
    let services: [LaunchpadService]

    var body: some View {
        List {
            Section {
                if services.isEmpty {
                    Text("devices.packages.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(services) { service in
                        HStack(spacing: 12) {
                            ServiceIconView(service: service, size: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(service.name)
                                    .font(.body.weight(.medium))
                                Text(service.status.devicesTitleKey)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            StatusDot(status: service.status)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } footer: {
                Text("devices.packages.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.resource.packages")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DockerContainerRow: View {
    let container: DockerContainer

    var body: some View {
        HStack(spacing: 12) {
            ContainerServiceIcon(name: container.name, size: 36)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(container.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    StatusDot(status: container.status)
                }
                Text(container.status.devicesTitleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .layoutPriority(1)
            Spacer()
            Text(containerPercentText(container.memoryPercent))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}

private extension ServiceStatus {
    var devicesTitleKey: LocalizedStringKey {
        switch self {
        case .online: return "status.online"
        case .installed: return "status.installed"
        case .warning: return "status.warning"
        case .offline: return "status.offline"
        case .unknown: return "status.unknown"
        }
    }
}

private struct DockerContainerDetailView: View {
    let container: DockerContainer

    var body: some View {
        List {
            Section {
                DockerContainerRow(container: container)
            }

            Section {
                LabeledContent("metric.cpu", value: containerPercentText(container.cpu))
                LabeledContent(
                    "devices.container.memory_percent",
                    value: containerPercentText(container.memoryPercent)
                )
                LabeledContent("devices.container.runtime_memory", value: container.memoryText)
            } header: {
                Text("devices.container.metrics")
            }

            Section {
                if container.ports.isEmpty {
                    Text("devices.container.ports.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(container.ports, id: \.self) { port in
                        Text(port)
                    }
                }
            } header: {
                Text("devices.container.ports")
            }

            Section {
                Label("devices.container.agent_required", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
            } header: {
                Text("devices.container.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(container.name)
    }
}

private struct FileBrowserView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    let titleKey: LocalizedStringKey
    let items: [FileItem]
    let folderPath: String?
    @State private var loadedItems: [FileItem] = []
    @State private var didLoad = false
    @State private var isLoading = false

    init(titleKey: LocalizedStringKey, items: [FileItem], folderPath: String? = nil) {
        self.titleKey = titleKey
        self.items = items
        self.folderPath = folderPath
    }

    private var visibleItems: [FileItem] {
        if folderPath == nil { return items }
        return didLoad ? loadedItems : items
    }

    var body: some View {
        List {
            Section {
                if isLoading && visibleItems.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                ForEach(visibleItems) { item in
                    FileItemRowLink(item: item)
                }

                if !isLoading && visibleItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("devices.files.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } header: {
                Text(folderPath == nil ? "devices.files.favorites" : "devices.resource.files")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(titleKey)
        .task { await loadIfNeeded() }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard let folderPath, !didLoad else { return }
        isLoading = true
        loadedItems = await dataStore.loadFolder(path: folderPath)
        didLoad = true
        isLoading = false
    }
}

private struct FileItemRowLink: View {
    let item: FileItem

    var body: some View {
        if item.isFolder {
            NavigationLink {
                FileBrowserView(titleKey: LocalizedStringKey(item.name), items: item.children, folderPath: item.subtitle)
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
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var showExternalPicker = false
    @State private var externalMessageKey = "external.open_failed"
    @State private var showExternalHint = false
    @State private var playbackRequest: MediaPlaybackRequest?
    @State private var sharePayload: FileSharePayload?
    @State private var localPreview: LocalFilePreview?
    @State private var isPreparingPreview = false

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
                Button {
                    previewFile()
                } label: {
                    if isPreparingPreview {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("devices.files.preparing_preview")
                        }
                    } else {
                        Label("devices.files.preview", systemImage: previewSymbolName)
                    }
                }
                .disabled(isPreparingPreview)
                Button {
                    openExternalPicker()
                } label: {
                    Label("devices.files.open_external", systemImage: "arrow.up.forward.app")
                }
            } header: {
                Text("devices.files.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.files.preview")
        .confirmationDialog("service.external.title", isPresented: $showExternalPicker) {
            if item.kind == .video || item.kind == .audio {
                Button("Infuse") { openExternal(.infuse) }
                Button("VidHub") { openExternal(.vidhub) }
                Button("VLC") { openExternal(.vlc) }
            }
            Button("external.other_apps") { presentShareSheet() }
            Button("action.cancel", role: .cancel) {}
        }
        .alert(LocalizedStringKey(externalMessageKey), isPresented: $showExternalHint) {
            Button("action.ok", role: .cancel) {}
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .fullScreenCover(item: $playbackRequest) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
        .fullScreenCover(item: $localPreview) { preview in
            LocalFilePreviewScreen(preview: preview)
        }
    }

    private func previewFile() {
        guard let url = authenticatedURL else {
            showFailure("devices.files.session_required")
            return
        }
        switch item.kind {
        case .video, .audio:
            playbackRequest = MediaPlaybackRequest(
                url: url,
                title: item.name,
                allowsSelfSignedCertificates: connectionStore.dsmSession?.allowsSelfSignedCertificates == true,
                source: .dsmFile
            )
        case .image, .text, .archive:
            prepareLocalPreview(from: url)
        case .folder:
            break
        }
    }

    private func prepareLocalPreview(from url: URL) {
        isPreparingPreview = true
        Task {
            do {
                let fileURL = try await AuthenticatedFilePreviewLoader.download(
                    from: url,
                    filename: item.name,
                    allowsSelfSignedCertificates: connectionStore.dsmSession?.allowsSelfSignedCertificates == true
                )
                await MainActor.run {
                    isPreparingPreview = false
                    localPreview = LocalFilePreview(url: fileURL)
                }
            } catch {
                await MainActor.run {
                    isPreparingPreview = false
                    showFailure("devices.files.preview_failed")
                }
            }
        }
    }

    private func openExternalPicker() {
        guard authenticatedURL != nil else {
            showFailure("devices.files.session_required")
            return
        }
        showExternalPicker = true
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        guard let targetURL = target.url(endpoint: authenticatedURL, filename: item.name) else {
            showFailure("external.unsupported_hint")
            return
        }
        showExternalPicker = false
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            DiagnosticLogStore.shared.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.external_handoff_accepted"
                    : "diagnostics.media.external_handoff_failed",
                details: [
                    "targetApp": target.diagnosticName,
                    "extension": (item.name as NSString).pathExtension.lowercased()
                ]
            )
            guard !accepted else { return }
            DispatchQueue.main.async {
                showFailure(target.failureMessageKey)
            }
        }
    }

    private func presentShareSheet() {
        guard let authenticatedURL else {
            showFailure("devices.files.session_required")
            return
        }
        showExternalPicker = false
        sharePayload = FileSharePayload(url: authenticatedURL)
    }

    private func showFailure(_ key: String) {
        externalMessageKey = key
        showExternalHint = true
    }

    private var authenticatedURL: URL? {
        connectionStore.dsmSession?.fileStationOpenURL(path: item.subtitle)
    }

    private var previewSymbolName: String {
        item.kind == .video || item.kind == .audio ? "play.rectangle" : "doc.text.magnifyingglass"
    }
}

private struct FileSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct LocalFilePreview: Identifiable {
    let id = UUID()
    let url: URL
}

private final class FilePreviewTrustDelegate: NSObject, URLSessionDelegate {
    let trustedHost: String?
    let allowsSelfSignedCertificates: Bool

    init(trustedHost: String?, allowsSelfSignedCertificates: Bool) {
        self.trustedHost = trustedHost
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            allowsSelfSignedCertificates,
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost ?? "") == .orderedSame,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

private enum AuthenticatedFilePreviewLoader {
    static func download(
        from url: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool
    ) async throws -> URL {
        let diagnostics = DiagnosticLogStore.shared
        let details = [
            "target": DiagnosticLogStore.redactedURL(url),
            "extension": (filename as NSString).pathExtension.lowercased(),
            "selfSigned": allowsSelfSignedCertificates ? "on" : "off"
        ]
        diagnostics.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.files.preview_download_started",
            details: details
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 180
        let delegate = FilePreviewTrustDelegate(
            trustedHost: url.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        do {
            let (temporaryURL, response) = try await session.download(from: url)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                httpResponse.mimeType?.lowercased().contains("json") != true,
                httpResponse.mimeType?.lowercased().contains("html") != true
            else {
                throw URLError(.badServerResponse)
            }

            let safeName = safeFilename(filename)
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NastartPreviews", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let destination = directory.appendingPathComponent(safeName)
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            diagnostics.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.preview_download_succeeded",
                details: details.merging([
                    "status": "\(httpResponse.statusCode)",
                    "mime": httpResponse.mimeType ?? "-",
                    "bytes": "\(httpResponse.expectedContentLength)"
                ]) { current, _ in current }
            )
            return destination
        } catch {
            let nsError = error as NSError
            diagnostics.record(
                .error,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.preview_download_failed",
                details: details.merging([
                    "errorDomain": nsError.domain,
                    "errorCode": "\(nsError.code)"
                ]) { current, _ in current }
            )
            throw error
        }
    }

    private static func safeFilename(_ value: String) -> String {
        let candidate = (value as NSString).lastPathComponent
            .replacingOccurrences(of: ":", with: "-")
        return candidate.isEmpty ? "preview" : candidate
    }
}

private struct LocalFilePreviewScreen: View {
    let preview: LocalFilePreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QuickLookPreviewController(url: preview.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(preview.url.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("action.done") {
                            dismiss()
                        }
                    }
                }
        }
        .onDisappear {
            try? FileManager.default.removeItem(at: preview.url.deletingLastPathComponent())
        }
    }
}

private struct QuickLookPreviewController: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}

private struct NetworkDetailView: View {
    let services: [LaunchpadService]
    let baseURL: URL?

    var body: some View {
        List {
            Section {
                LabeledContent("devices.network.address", value: baseURL?.absoluteString ?? "-")
                LabeledContent("devices.network.protocol", value: baseURL?.scheme?.uppercased() ?? "-")
                LabeledContent("devices.network.scope") {
                    Text(LocalizedStringKey(networkScopeKey))
                }
            } header: {
                Text("devices.network.connection")
            }

            Section {
                LabeledContent("devices.network.online_count", value: "\(reachableEntries.count)")
                LabeledContent("devices.network.proxy_count", value: "\(reverseProxyCount)")
            } header: {
                Text("devices.network.summary")
            }

            Section {
                if reachableEntries.isEmpty {
                    Text("devices.network.entries.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(reachableEntries) { service in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(service.name)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Text(LocalizedStringKey(service.sourceTitleKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(endpointSummary(service.suggestedEndpoint))
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                Text("devices.network.available_entries")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.resource.network")
    }

    private var reachableEntries: [LaunchpadService] {
        var seen = Set<String>()
        return services.filter { service in
            guard
                service.status == .online,
                let endpoint = service.suggestedEndpoint
            else {
                return false
            }
            return seen.insert(endpoint.absoluteString.lowercased()).inserted
        }
    }

    private var reverseProxyCount: Int {
        reachableEntries.filter { $0.source == .reverseProxy }.count
    }

    private var networkScopeKey: String {
        guard let host = baseURL?.host?.lowercased() else {
            return "status.unknown"
        }
        if host == "localhost" || host.hasSuffix(".local") || isPrivateIPv4(host) {
            return "devices.network.scope.lan"
        }
        return "devices.network.scope.remote"
    }

    private func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4 else { return false }
        return parts[0] == 10
            || (parts[0] == 192 && parts[1] == 168)
            || (parts[0] == 172 && (16...31).contains(parts[1]))
    }

    private func endpointSummary(_ endpoint: URL?) -> String {
        guard let endpoint else { return "-" }
        let scheme = endpoint.scheme.map { "\($0)://" } ?? ""
        let host = endpoint.host ?? endpoint.absoluteString
        if let port = endpoint.port {
            return "\(scheme)\(host):\(port)"
        }
        return "\(scheme)\(host)"
    }
}

private struct CertificateSecurityView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var isChecking = false
    @State private var showCheckResult = false

    private var device: NASDevice {
        dataStore.device
    }

    var body: some View {
        List {
            Section {
                LabeledContent("devices.detail.certificate", value: certificateDaysText(device.certificateDaysRemaining))
                LabeledContent("devices.cert.domain", value: device.certificate?.subject ?? "-")
                LabeledContent("devices.cert.issuer", value: device.certificate?.issuer ?? "-")
                LabeledContent("devices.cert.trust", value: certificateTrustText(device.certificate))
                if let validFrom = device.certificate?.validFrom {
                    LabeledContent("devices.cert.valid_from") {
                        Text(validFrom, style: .date)
                    }
                }
                if let validUntil = device.certificate?.validUntil {
                    LabeledContent("devices.cert.valid_until") {
                        Text(validUntil, style: .date)
                    }
                }
            } header: {
                Text("devices.cert.https")
            }

            Section {
                LabeledContent("devices.security.ssh", value: sshStatusText(device.sshStatus))
            } footer: {
                Text("devices.security.ssh.footer")
            }

            Section {
                NavigationLink {
                    ReminderCreateView(defaultKind: .certificate)
                } label: {
                    Label("devices.cert.create_task", systemImage: "bell.badge")
                }
                Button {
                    checkNow()
                } label: {
                    HStack {
                        Text("devices.cert.check_now")
                        Spacer()
                        if isChecking {
                            ProgressView()
                        }
                    }
                }
                .disabled(isChecking || connectionStore.dsmSession == nil)
            } header: {
                Text("devices.cert.actions")
            }
        }
        .listStyle(.insetGrouped)
        .padding(.top, -12)
        .navigationTitle("devices.maintenance.certificate")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            LocalizedStringKey(
                device.certificate == nil ? "devices.cert.check_unavailable" : "devices.cert.check_complete"
            ),
            isPresented: $showCheckResult
        ) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func checkNow() {
        guard let session = connectionStore.dsmSession else { return }
        isChecking = true
        Task {
            await dataStore.refreshDSM(session: session, useAgent: connectionStore.usesAgent)
            await MainActor.run {
                isChecking = false
                showCheckResult = true
            }
        }
    }
}

private struct AgentStatusView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        List {
            Section {
                LabeledContent(
                    "devices.agent.mode",
                    value: NSLocalizedString(connectionStore.usesAgent ? "state.connected" : "state.not_connected", comment: "")
                )
                LabeledContent(
                    "devices.security.ssh",
                    value: sshStatusText(dataStore.device.sshStatus)
                )
            }

            Section {
                NavigationLink {
                    AgentSetupGuideView()
                } label: {
                    Label("devices.agent.ssh.desktop", systemImage: "desktopcomputer")
                }
            } header: {
                Text("devices.agent.setup_paths")
            } footer: {
                Text("devices.agent.ssh.footer")
            }

            Section {
                Label {
                    Text(LocalizedStringKey(
                        connectionStore.usesAgent
                            ? "devices.agent.connected"
                            : "devices.agent.not_connected"
                    ))
                } icon: {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                }
                    .foregroundStyle(connectionStore.usesAgent ? .green : .secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.maintenance.agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

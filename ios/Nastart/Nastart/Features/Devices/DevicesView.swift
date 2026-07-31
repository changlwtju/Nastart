import SwiftUI
import UIKit

struct DevicesView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var showRediscoverHint = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
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
                            Label {
                                Text(LocalizedStringKey(connectionStore.isConnected ? "status.online" : "state.not_connected"))
                            } icon: {
                                Image(systemName: connectionStore.isConnected ? "checkmark.circle.fill" : "minus.circle")
                            }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(connectionStore.isConnected ? Color.green : Color.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)
                        }

                        MetricPillRow(metrics: [
                            MetricPillSpec("metric.cpu", value: devicePercentText(dataStore.device.cpu), progress: dataStore.device.cpu),
                            MetricPillSpec("metric.memory", value: devicePercentText(dataStore.device.memory), progress: dataStore.device.memory),
                            MetricPillSpec("metric.storage", value: devicePercentText(dataStore.device.storageUsed), progress: dataStore.device.storageUsed)
                        ])
                    }
                    .padding(.vertical, 4)

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
                }

                Section {
                    NavigationLink {
                        CertificateSecurityView()
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
                LabeledContent("metric.memory", value: device.memoryDisplayText)
                LabeledContent("metric.storage", value: device.storageDisplayText)
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
    @State private var sort: ServiceResourceSort = .cpu

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
                        ServiceResourceRow(container: container)
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
                if lhs.memoryBytes != rhs.memoryBytes {
                    return (lhs.memoryBytes ?? -1) > (rhs.memoryBytes ?? -1)
                }
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private struct ServiceResourceRow: View {
    let container: DockerContainer

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shippingbox")
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
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

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(containerPercentText(container.cpu))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Text(memorySummary)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
        .padding(.vertical, 3)
    }

    private var memorySummary: String {
        guard let memoryPercent = container.memoryPercent else {
            return container.memoryText
        }
        return "\(container.memoryText) · \(containerPercentText(memoryPercent))"
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
                                Text(LocalizedStringKey(service.subtitle))
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
                LabeledContent("metric.cpu", value: containerPercentText(container.cpu))
                LabeledContent("metric.memory", value: container.memoryText)
                if let memoryPercent = container.memoryPercent {
                    LabeledContent(
                        "devices.container.memory_percent",
                        value: containerPercentText(memoryPercent)
                    )
                }
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
                        LabeledContent(service.name, value: endpointSummary(service.suggestedEndpoint))
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
                let endpoint = service.suggestedEndpoint,
                service.source == .dsm || service.source == .reverseProxy
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
    @State private var showReminderHint = false

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
                Button("devices.cert.create_task") {
                    showReminderHint = true
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
        .alert("devices.cert.reminder_hint", isPresented: $showReminderHint) {
            Button("action.ok", role: .cancel) {}
        }
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

    var body: some View {
        List {
            Section {
                LabeledContent(
                    "devices.agent.mode",
                    value: NSLocalizedString(connectionStore.usesAgent ? "state.connected" : "state.not_connected", comment: "")
                )
                LabeledContent(
                    "devices.security.ssh",
                    value: NSLocalizedString("devices.agent.ssh.available", comment: "")
                )
            }

            Section {
                NavigationLink {
                    SSHAgentSetupView()
                } label: {
                    Label("devices.agent.ssh.in_app", systemImage: "terminal")
                }
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
                Label("devices.agent.not_connected", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(connectionStore.usesAgent ? .green : .secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.maintenance.agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum SSHAuthMethod: String, CaseIterable, Identifiable {
    case password
    case privateKey

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .password: return "ssh.auth.password"
        case .privateKey: return "ssh.auth.private_key"
        }
    }
}

private struct SSHAgentSetupView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod: SSHAuthMethod = .password
    @State private var secret = ""
    @State private var showCopyHint = false
    @State private var showSavedHint = false

    private let installCommand = "docker run -d --name nastart-agent -p 8787:8787 --restart unless-stopped nastart/agent:latest"

    var body: some View {
        List {
            Section {
                Text("ssh.in_app.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                TextField("ssh.host.placeholder", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("ssh.port.placeholder", text: $port)
                    .keyboardType(.numberPad)
                TextField("ssh.username.placeholder", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.username)
                Picker("ssh.auth.method", selection: $authMethod) {
                    ForEach(SSHAuthMethod.allCases) { method in
                        Text(method.titleKey).tag(method)
                    }
                }
                if authMethod == .password {
                    SecureField("ssh.password.placeholder", text: $secret)
                        .textContentType(.password)
                } else {
                    SecureField("ssh.private_key.placeholder", text: $secret)
                }
            } header: {
                Text("ssh.connection")
            } footer: {
                Text("ssh.security.footer")
            }

            Section {
                AgentStepRow(number: 1, titleKey: "ssh.step.connect", detailKey: "ssh.step.connect_detail")
                AgentStepRow(number: 2, titleKey: "ssh.step.detect", detailKey: "ssh.step.detect_detail")
                AgentStepRow(number: 3, titleKey: "ssh.step.install", detailKey: "ssh.step.install_detail")
                AgentStepRow(number: 4, titleKey: "ssh.step.verify", detailKey: "ssh.step.verify_detail")
            } header: {
                Text("connect.agent.steps")
            }

            Section {
                Text(installCommand)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button("connect.agent.copy") {
                    UIPasteboard.general.string = installCommand
                    showCopyHint = true
                }
            } header: {
                Text("connect.agent.command")
            }

            Section {
                Button {
                    saveProfileHint()
                } label: {
                    Label("ssh.profile.save", systemImage: "lock.shield")
                }
                .disabled(host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } footer: {
                Text("ssh.profile.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.agent.ssh.in_app")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if host.isEmpty {
                host = connectionStore.dsmSession?.baseURL.host ?? ""
            }
        }
        .alert("connect.agent.copy_hint", isPresented: $showCopyHint) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("ssh.profile.saved_hint", isPresented: $showSavedHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func saveProfileHint() {
        UserDefaults.standard.set(host.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "nastart.ssh.host")
        UserDefaults.standard.set(port.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "nastart.ssh.port")
        UserDefaults.standard.set(username.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "nastart.ssh.username")
        UserDefaults.standard.set(authMethod.rawValue, forKey: "nastart.ssh.authMethod")
        secret = ""
        showSavedHint = true
    }
}

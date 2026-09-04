import SwiftUI
import UIKit
import QuickLook
import Network

struct DevicesView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var showRediscoverHint = false
    @State private var rediscoverSummaryKey = "devices.discovery.hint"

    var body: some View {
        NavigationStack {
            List {
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
                        // The persisted snapshot may contain an empty or stale
                        // root on a second device. Treat the root like every
                        // nested folder and load `/` from the active DSM session.
                        FileBrowserView(
                            titleKey: "devices.resource.files",
                            items: dataStore.files,
                            folderPath: "/"
                        )
                    } label: {
                        Label("devices.resource.files", systemImage: "folder")
                    }
                    NavigationLink {
                        NetworkDetailView(
                            services: dataStore.services,
                            baseURL: connectionStore.dsmSession?.baseURL,
                            endpoints: connectionStore.connectionEndpoints,
                            actualRoute: connectionStore.actualRoute
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
                            let summaryKey: String
                            if let session = connectionStore.dsmSession {
                                _ = await dataStore.refreshDSM(
                                    session: session,
                                    useAgent: connectionStore.usesAgent
                                )
                                summaryKey = await MainActor.run {
                                    dataStore.lastRefreshSummaryKey
                                }
                            } else {
                                await MainActor.run {
                                    dataStore.refreshAll()
                                }
                                summaryKey = await MainActor.run {
                                    dataStore.lastRefreshSummaryKey
                                }
                            }
                            await MainActor.run {
                                rediscoverSummaryKey = summaryKey
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
            .alert("devices.discovery.result", isPresented: $showRediscoverHint) {
                Button("action.ok", role: .cancel) {}
            } message: {
                Text(LocalizedStringKey(rediscoverSummaryKey))
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
        ZStack(alignment: .bottomTrailing) {
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

            if let badgeText {
                Text(badgeText)
                    .font(.system(size: max(size * 0.21, 8), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(width: size * 0.42, height: size * 0.32)
                    .background(AppTheme.accentDeep)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                            .stroke(Color(.systemBackground), lineWidth: 1)
                    }
                    .offset(x: size * 0.08, y: size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var symbolName: String {
        iconIdentity.symbolName ?? "shippingbox"
    }

    private var badgeText: String? {
        return iconIdentity.badgeText
    }

    private var iconIdentity: ServiceIconIdentity {
        ServiceIconRegistry.identity(name: name)
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

private enum FileBrowserSort: String, CaseIterable, Identifiable {
    case name
    case kind

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .name: return "devices.files.sort.name"
        case .kind: return "devices.files.sort.kind"
        }
    }
}

private struct FileBrowserView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    let titleKey: LocalizedStringKey
    let items: [FileItem]
    let folderPath: String?
    @State private var query = ""
    @State private var sort: FileBrowserSort = .name
    @State private var loadedItems: [FileItem] = []
    @State private var didLoad = false
    @State private var isLoading = false
    @State private var loadErrorKey: String?

    init(titleKey: LocalizedStringKey, items: [FileItem], folderPath: String? = nil) {
        self.titleKey = titleKey
        self.items = items
        self.folderPath = folderPath
    }

    private var baseItems: [FileItem] {
        if folderPath == nil { return items }
        return didLoad ? loadedItems : items
    }

    private var visibleItems: [FileItem] {
        sortedItems(filteredItems(baseItems))
    }

    var body: some View {
        List {
            if let folderPath {
                Section {
                    LabeledContent("devices.files.path") {
                        Text(folderPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .textSelection(.enabled)
                    }
                }
            }

            Section {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("devices.files.search", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("action.clear"))
                    }
                }

                Picker("devices.files.sort", selection: $sort) {
                    ForEach(FileBrowserSort.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }

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

                if let loadErrorKey, visibleItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.folder")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey(loadErrorKey))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("action.retry") {
                            didLoad = false
                            Task { await loadIfNeeded() }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                if !isLoading && visibleItems.isEmpty && loadErrorKey == nil {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(LocalizedStringKey(
                            query.isEmpty ? "devices.files.empty" : "devices.files.search.empty"
                        ))
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
        .refreshable {
            await reloadFolder()
        }
    }

    private func filteredItems(_ items: [FileItem]) -> [FileItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return items }
        return items.filter {
            $0.name.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.subtitle.localizedCaseInsensitiveContains(normalizedQuery)
                || $0.path.localizedCaseInsensitiveContains(normalizedQuery)
        }
    }

    private func sortedItems(_ items: [FileItem]) -> [FileItem] {
        items.sorted { lhs, rhs in
            if lhs.isFolder != rhs.isFolder {
                return lhs.isFolder
            }
            switch sort {
            case .name:
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .kind:
                if lhs.kind.rawValue != rhs.kind.rawValue {
                    return lhs.kind.rawValue < rhs.kind.rawValue
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }
    }

    @MainActor
    private func loadIfNeeded() async {
        guard let folderPath, !didLoad else { return }
        isLoading = true
        loadErrorKey = nil
        do {
            loadedItems = try await dataStore.loadFolder(path: folderPath)
            if loadedItems.isEmpty,
               let session = connectionStore.dsmSession {
                // A device can render a persisted empty snapshot, or a nested
                // folder can arrive while the DSM source is still restoring.
                // Rebuild the active source once before treating any folder
                // as genuinely empty.
                _ = await dataStore.refreshDSM(
                    session: session,
                    useAgent: connectionStore.usesAgent
                )
                loadedItems = try await dataStore.loadFolder(
                    path: folderPath,
                    forceRefresh: true
                )
            }
            if loadedItems.isEmpty, folderPath == "/", !dataStore.files.isEmpty {
                // File Station can acknowledge list_share with an empty
                // payload while the authenticated snapshot already contains
                // the same live shared-folder inventory. Keep the DSM root
                // navigable instead of presenting a false empty directory.
                loadedItems = dataStore.files
            }
            didLoad = true
        } catch {
            loadErrorKey = "devices.files.folder_load_failed"
        }
        isLoading = false
    }

    @MainActor
    private func reloadFolder() async {
        guard let folderPath else { return }
        loadErrorKey = nil
        do {
            loadedItems = try await dataStore.loadFolder(
                path: folderPath,
                forceRefresh: true
            )
            didLoad = true
        } catch {
            loadErrorKey = "devices.files.folder_load_failed"
        }
    }
}

private struct FileItemRowLink: View {
    let item: FileItem

    var body: some View {
        if item.isFolder {
            NavigationLink {
                FileBrowserView(titleKey: LocalizedStringKey(item.name), items: item.children, folderPath: item.path)
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
            if !item.isFolder, let sizeText = item.sizeText {
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
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var externalMessageKey = "external.open_failed"
    @State private var showExternalHint = false
    @State private var playbackRequest: MediaPlaybackRequest?
#if DEBUG
    @AppStorage(GreenfieldPlaybackDebugSettings.useGreenfieldPlayerKey)
    private var usesGreenfieldPlayer = false
    @State private var greenfieldPlaybackRequest: GreenfieldPlaybackLaunchRequest?
#endif
    @State private var localPreview: LocalFilePreview?
    @State private var isPreparingPreview = false
    @State private var externalPlaybackURL: URL?
    @State private var showExternalPicker = false
    @State private var externalSharePayload: FileExternalSharePayload?
    @State private var pendingExternalTarget: ExternalOpenTarget?
    @State private var pendingExternalShare = false
    @State private var showCredentialHandoffWarning = false

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
#if DEBUG
                if item.kind == .video || item.kind == .audio {
                    Toggle(isOn: $usesGreenfieldPlayer) {
                        Label("Greenfield player", systemImage: "switch.2")
                            .font(.subheadline.weight(.semibold))
                    }
                    .toggleStyle(.switch)
                }
#endif
            } header: {
                Text("devices.files.actions")
            } footer: {
                if item.kind == .discImage {
                    Text("devices.files.iso_playback_hint")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.files.preview")
        .alert(LocalizedStringKey(externalMessageKey), isPresented: $showExternalHint) {
            Button("action.ok", role: .cancel) {}
        }
        .fullScreenCover(item: $playbackRequest, onDismiss: {
            PlayerOrientationController.setPlayerActive(false)
        }) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
#if DEBUG
        .fullScreenCover(item: $greenfieldPlaybackRequest) { request in
            NavigationStack {
                GreenfieldVideoPlayerView(request: request)
            }
        }
#endif
        .fullScreenCover(item: $localPreview) { preview in
            LocalFilePreviewScreen(preview: preview)
        }
        .confirmationDialog("service.external.title", isPresented: $showExternalPicker) {
            ForEach(ExternalOpenTarget.installedPlayers) { target in
                Button(target.displayName) { requestExternalOpen(target) }
            }
            Button("external.other_apps") { requestExternalShare() }
            Button("action.cancel", role: .cancel) {}
        }
        .sheet(item: $externalSharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .confirmationDialog(
            "external.credential_warning.title",
            isPresented: $showCredentialHandoffWarning,
            titleVisibility: .visible
        ) {
            Button("external.credential_warning.continue") {
                if let target = pendingExternalTarget {
                    openExternal(target)
                } else if pendingExternalShare, let externalPlaybackURL {
                    externalSharePayload = FileExternalSharePayload(url: externalPlaybackURL)
                }
                pendingExternalTarget = nil
                pendingExternalShare = false
            }
            Button("action.cancel", role: .cancel) {
                pendingExternalTarget = nil
                pendingExternalShare = false
            }
        } message: {
            Text("external.credential_warning.message")
        }
    }

    private func previewFile() {
        guard let url = authenticatedURL else {
            showFailure("devices.files.session_required")
            return
        }
        switch item.kind {
        case .video, .audio:
            prepareMediaPlayback(from: url)
        case .image, .text, .archive:
            prepareLocalPreview(from: url)
        case .discImage:
            prepareDiscImagePlayback(from: url)
        case .folder:
            break
        }
    }

    private func prepareDiscImagePlayback(from fallbackURL: URL) {
        isPreparingPreview = true
        let session = connectionStore.dsmSession
        let candidates = session?.fileStationOpenURLs(path: item.path) ?? [fallbackURL]
        Task {
            let selectedURL = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                candidates: candidates,
                allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true,
                diagnosticStage: "dsmDiscImageRange"
            ) ?? fallbackURL
            do {
                let prepared = try await ISOPlaybackAdapter.prepare(
                    sourceURL: selectedURL,
                    allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true
                )
                await MainActor.run {
                    isPreparingPreview = false
                    externalPlaybackURL = selectedURL
                    PlayerOrientationController.prepareForPresentation(.landscape)
                    playbackRequest = MediaPlaybackRequest(
                        url: prepared.playbackURL,
                        title: item.name,
                        source: .dsmFile,
                        contentKind: .discImage,
                        fileExtensionOverride: prepared.fileExtension,
                        initialOrientationMode: .landscape,
                        isPrivateNetworkRoute: NetworkHostClassifier.isPrivate(selectedURL.host),
                        externalHandoffResource: MediaPlaybackResource(
                            url: selectedURL,
                            fileExtensionOverride: "iso",
                            allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates
                        )
                    )
                    DiagnosticLogStore.shared.record(
                        .info,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.files.preview_stream_started",
                        details: [
                            "target": DiagnosticLogStore.redactedURL(selectedURL),
                            "extension": "iso",
                            "mode": "builtInDiscImage",
                            "selectedPath": prepared.selectedPath,
                            "titleCount": String(prepared.titleCount)
                        ]
                    )
                }
            } catch {
                await MainActor.run {
                    isPreparingPreview = false
                    externalPlaybackURL = selectedURL
                    showExternalPicker = true
                    DiagnosticLogStore.shared.record(
                        .warning,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.iso_failed",
                        details: [
                            "target": DiagnosticLogStore.redactedURL(selectedURL),
                            "error": String(describing: error),
                            "fallback": "externalDiscImage"
                        ]
                    )
                }
            }
        }
    }

    private func prepareMediaPlayback(from url: URL) {
        isPreparingPreview = true
        let requestedAt = Date()
        let fileExtension = (item.name as NSString).pathExtension.lowercased()
        let session = connectionStore.dsmSession
        let candidates = session?.fileStationOpenURLs(path: item.path) ?? [url]
#if DEBUG
        let greenfieldRequested = usesGreenfieldPlayer
#else
        let greenfieldRequested = false
#endif
        Task {
            let directory = (item.path as NSString).deletingLastPathComponent
            let siblingItems = try? await dataStore.loadFolder(path: directory)
            async let sidecarSubtitle = NASSubtitleAssetResolver.resolve(
                videoPath: item.path,
                videoName: item.name,
                session: session,
                siblingItems: siblingItems
            )
            // Do not spend the startup path on a 0-1 byte probe. VLC already
            // performs the real authenticated read and can begin demuxing as
            // soon as the first media bytes arrive. The candidate resolver is
            // kept for the failure path below, where selecting a working
            // scheme is useful and no first-frame latency is at stake.
            let selectedURL = candidates.first ?? url
            let subtitleAsset = await sidecarSubtitle
            let isPrivateRoute = NetworkHostClassifier.isPrivate(selectedURL.host)
            // Greenfield/KSPlayer needs the authenticated local Range proxy
            // up front so DSM cookies, redirects, and Range behavior stay under
            // Nastart's control instead of being delegated to the renderer.
            let fallbackCandidates = candidates
            let fallbackUpstreamURL = selectedURL
            let fallbackFilename = item.name
            let fallbackAllowsSelfSigned = session?.allowsSelfSignedCertificates == true
            let fallbackSubtitleURL = subtitleAsset?.playbackURL
            let shouldPrepareLocalProxy = item.kind == .video
                && (greenfieldRequested
                    || isPrivateRoute
                    || NetworkHostClassifier.isLiteralAddress(selectedURL.host))
            let preparedProxyURL: URL?
            if shouldPrepareLocalProxy {
                preparedProxyURL = try? await AuthenticatedMediaStreamProxy.shared.register(
                    upstreamURL: selectedURL,
                    filename: item.name,
                    allowsSelfSignedCertificates: fallbackAllowsSelfSigned,
                    prefersFiniteRangeResponse: greenfieldRequested
                )
            } else {
                preparedProxyURL = nil
            }
            let playbackURL = preparedProxyURL ?? selectedURL
            let playbackUsesLocalProxy = preparedProxyURL != nil
            await MainActor.run {
                isPreparingPreview = false
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.files.preview_stream_started",
                    details: [
                        "target": DiagnosticLogStore.redactedURL(playbackURL),
                        "extension": fileExtension.isEmpty ? "-" : fileExtension,
                        "sidecarSubtitle": subtitleAsset == nil ? "none" : "normalizedUTF8",
                        "selfSigned": session?.allowsSelfSignedCertificates == true ? "on" : "off",
                        "transport": playbackUsesLocalProxy ? "localRangeProxy" : (selectedURL.scheme?.lowercased() ?? "-"),
                        "upstream": DiagnosticLogStore.redactedURL(selectedURL),
                        "fallbackTransport": item.kind == .video ? "lazyLocalRangeProxy" : "none",
                        "greenfield": greenfieldRequested ? "on" : "off"
                    ]
                )
                let request = MediaPlaybackRequest(
                    requestedAt: requestedAt,
                    url: playbackURL,
                    title: item.name,
                    allowsSelfSignedCertificates: !playbackUsesLocalProxy
                        && session?.allowsSelfSignedCertificates == true
                        && selectedURL.scheme?.lowercased() == "https",
                    source: .dsmFile,
                    contentKind: item.kind == .audio ? .audio : .video,
                    fileExtensionOverride: fileExtension.isEmpty ? nil : fileExtension,
                    externalSubtitleURL: subtitleAsset?.playbackURL,
                    initialOrientationMode: item.kind == .video ? .landscape : .automatic,
                    isPrivateNetworkRoute: isPrivateRoute,
                    externalHandoffResource: MediaPlaybackResource(
                        url: selectedURL,
                        fileExtensionOverride: fileExtension.isEmpty ? nil : fileExtension,
                        subtitleURL: subtitleAsset?.sourceURL,
                        allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true
                            && selectedURL.scheme?.lowercased() == "https"
                    ),
                    compatibilityFallbackResourceLoader: item.kind == .video
                        ? { _ in
                            let resolvedFallbackURL = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                                candidates: fallbackCandidates,
                                allowsSelfSignedCertificates: fallbackAllowsSelfSigned,
                                diagnosticStage: "dsmRangeFallback",
                                timeout: 3
                            ) ?? fallbackUpstreamURL
                            guard let proxyURL = try? await AuthenticatedMediaStreamProxy.shared.register(
                                upstreamURL: resolvedFallbackURL,
                                filename: fallbackFilename,
                                allowsSelfSignedCertificates: fallbackAllowsSelfSigned,
                                prefersFiniteRangeResponse: greenfieldRequested
                            ) else {
                                return nil
                            }
                            return MediaPlaybackResource(
                                url: proxyURL,
                                fileExtensionOverride: fileExtension.isEmpty ? nil : fileExtension,
                                subtitleURL: fallbackSubtitleURL,
                                forcesSoftwareDecoding: true
                            )
                        }
                        : nil
                )
#if DEBUG
                if greenfieldRequested {
                    greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
                } else {
                    PlayerOrientationController.prepareForPresentation(
                        item.kind == .video ? .landscape : .automatic
                    )
                    playbackRequest = request
                }
#else
                PlayerOrientationController.prepareForPresentation(
                    item.kind == .video ? .landscape : .automatic
                )
                playbackRequest = request
#endif
            }
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

    private func showFailure(_ key: String) {
        externalMessageKey = key
        showExternalHint = true
    }

    private func requestExternalOpen(_ target: ExternalOpenTarget) {
        guard let externalPlaybackURL else {
            showFailure("external.open_failed")
            return
        }
        guard !externalRequest(for: externalPlaybackURL).containsSensitiveCredential else {
            pendingExternalTarget = target
            pendingExternalShare = false
            showCredentialHandoffWarning = true
            return
        }
        openExternal(target)
    }

    private func requestExternalShare() {
        guard let externalPlaybackURL else {
            showFailure("external.open_failed")
            return
        }
        guard !externalRequest(for: externalPlaybackURL).containsSensitiveCredential else {
            pendingExternalTarget = nil
            pendingExternalShare = true
            showCredentialHandoffWarning = true
            return
        }
        externalSharePayload = FileExternalSharePayload(url: externalPlaybackURL)
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        guard let externalPlaybackURL,
              let targetURL = target.url(endpoint: externalPlaybackURL, filename: item.name) else {
            showFailure("external.open_failed")
            return
        }
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            guard !accepted else { return }
            DispatchQueue.main.async {
                externalSharePayload = FileExternalSharePayload(url: externalPlaybackURL)
            }
        }
    }

    private func externalRequest(for url: URL) -> MediaPlaybackRequest {
        MediaPlaybackRequest(
            url: url,
            title: item.name,
            source: .dsmFile,
            fileExtensionOverride: "iso",
            externalHandoffResource: MediaPlaybackResource(
                url: url,
                fileExtensionOverride: "iso"
            )
        )
    }

    private var authenticatedURL: URL? {
        connectionStore.dsmSession?.fileStationOpenURL(path: item.path)
    }

    private var previewSymbolName: String {
        item.kind == .video || item.kind == .audio || item.kind == .discImage
            ? "play.rectangle"
            : "doc.text.magnifyingglass"
    }
}

private struct FileExternalSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct NASSubtitleAsset {
    let sourceURL: URL
    let playbackURL: URL
}

/// File Station does not expose sidecar subtitles as part of the video item.
/// Probe same-directory basename variants and normalize legacy Chinese
/// encodings before handing the subtitle to VLC. The original authenticated
/// URL remains available for external-player handoff.
private enum NASSubtitleAssetResolver {
    private static let sidecarExtensions = ["srt", "ass", "ssa", "vtt", "sub"]
    private static let maximumSubtitleBytes = 16 * 1024 * 1024

    static func resolve(
        videoPath: String,
        videoName: String,
        session: DSMSession?,
        siblingItems: [FileItem]? = nil
    ) async -> NASSubtitleAsset? {
        guard let session else { return nil }
        let basename = (videoName as NSString).deletingPathExtension
        guard !basename.isEmpty else { return nil }
        let directory = (videoPath as NSString).deletingLastPathComponent
        let suffixes = [
            "",
            ".zh", ".zh-cn", ".zh-tw", ".zh-hans", ".zh-hant",
            ".zh_cn", ".zh_tw", ".chs", ".cht", ".chi", ".sc", ".tc",
            ".简", ".繁", "-zh", "-chs", "-cht"
        ]
        var paths: [(path: String, name: String)] = []
        var seen = Set<String>()
        if let siblingItems {
            for item in siblingItems where !item.isFolder && sidecarExtensions.contains(
                (item.name as NSString).pathExtension.lowercased()
            ) && subtitleNameMatches(videoBaseName: basename, subtitleName: item.name) {
                guard seen.insert(item.path.lowercased()).inserted else { continue }
                paths.append((path: item.path, name: item.name))
            }
        }
        // When File Station returned a directory listing, it is authoritative.
        // Do not fan out dozens of 404 probes over a cellular route after the
        // directory has already proved that no matching sidecar exists.
        if siblingItems == nil {
            for suffix in suffixes {
                for fileExtension in sidecarExtensions {
                    let name = "\(basename)\(suffix).\(fileExtension)"
                    let path = directory == "." || directory.isEmpty ? "/\(name)" : "\(directory)/\(name)"
                    guard seen.insert(path.lowercased()).inserted else { continue }
                    paths.append((path, name))
                }
            }
        }

        return await withTaskGroup(of: NASSubtitleAsset?.self, returning: NASSubtitleAsset?.self) { group in
            for candidate in paths {
                group.addTask {
                    let urls = session.fileStationOpenURLs(path: candidate.path)
                    guard let sourceURL = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                        candidates: urls,
                        allowsSelfSignedCertificates: session.allowsSelfSignedCertificates,
                        diagnosticStage: "dsmSidecarSubtitle",
                        timeout: 1.5
                    ) else {
                        return nil
                    }
                    return await normalize(
                        sourceURL: sourceURL,
                        filename: candidate.name,
                        allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
                    )
                }
            }
            while let asset = await group.next() {
                if let asset {
                    group.cancelAll()
                    return asset
                }
            }
            return nil
        }
    }

    private static func subtitleNameMatches(videoBaseName: String, subtitleName: String) -> Bool {
        let video = normalizedName(videoBaseName)
        let subtitle = normalizedName((subtitleName as NSString).deletingPathExtension)
        guard !video.isEmpty, !subtitle.isEmpty else { return false }
        return subtitle == video
            || subtitle.hasPrefix(video + ".")
            || subtitle.hasPrefix(video + "_")
            || subtitle.hasPrefix(video + "-")
            || subtitle.hasPrefix(video + " ")
    }

    private static func normalizedName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func normalize(
        sourceURL: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool
    ) async -> NASSubtitleAsset? {
        let delegate = FilePreviewTrustDelegate(
            trustedHost: sourceURL.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
                && sourceURL.scheme?.lowercased() == "https"
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 8
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: sourceURL)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.count <= maximumSubtitleBytes,
                  let decoded = decode(data),
                  looksLikeSubtitle(decoded) else {
                return nil
            }
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Nastart/Subtitles", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let outputExtension = (filename as NSString).pathExtension.isEmpty
                ? "srt"
                : (filename as NSString).pathExtension
            let outputURL = directory.appendingPathComponent("\(UUID().uuidString).utf8.\(outputExtension)")
            guard let outputData = decoded
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .data(using: .utf8) else {
                return nil
            }
            try outputData.write(to: outputURL, options: .atomic)
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.subtitle_normalized",
                details: [
                    "source": DiagnosticLogStore.redactedURL(sourceURL),
                    "encoding": detectedEncoding(data),
                    "bytes": "\(data.count)"
                ]
            )
            return NASSubtitleAsset(sourceURL: sourceURL, playbackURL: outputURL)
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data, encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16BigEndian)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8
        }
        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        ))
        return String(data: data, encoding: gb18030)
            ?? String(data: data, encoding: .isoLatin1)
    }

    private static func detectedEncoding(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) { return "UTF-16LE" }
        if data.starts(with: [0xFE, 0xFF]) { return "UTF-16BE" }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) { return "UTF-8-BOM" }
        if String(data: data, encoding: .utf8) != nil { return "UTF-8" }
        return "GB18030-or-ISO-8859-1"
    }

    private static func looksLikeSubtitle(_ value: String) -> Bool {
        let text = value.lowercased()
        return text.contains("-->")
            || text.contains("[script info]")
            || text.contains("[v4+ styles]")
            || text.contains("{\\an")
    }
}

actor MediaPlaybackRouteCache {
    static let shared = MediaPlaybackRouteCache()

    private var entries: [String: (url: URL, validatedAt: Date)] = [:]

    func url(for key: String, candidates: [URL]) -> URL? {
        guard let entry = entries[key],
              Date().timeIntervalSince(entry.validatedAt) < 5 * 60,
              candidates.contains(entry.url) else {
            entries[key] = nil
            return nil
        }
        return entry.url
    }

    func store(_ url: URL, for key: String) {
        entries[key] = (url, Date())
    }
}

enum AuthenticatedMediaPlaybackResolver {
    static func firstPlayableURL(
        candidates: [URL],
        allowsSelfSignedCertificates: Bool,
        diagnosticStage: String,
        timeout: TimeInterval = 8,
        expectedContentLength: Int? = nil
    ) async -> URL? {
        let cacheKey = candidates.map(\.absoluteString).joined(separator: "|")
            + "|length=\(expectedContentLength.map(String.init) ?? "unknown")"
        if let cached = await MediaPlaybackRouteCache.shared.url(
            for: cacheKey,
            candidates: candidates
        ) {
            return cached
        }
        let selected: URL? = await withTaskGroup(
            of: URL?.self,
            returning: URL?.self
        ) { group in
            for candidate in candidates {
                group.addTask {
                    return await playableURL(
                        candidate,
                        allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                        diagnosticStage: diagnosticStage,
                        timeout: timeout,
                        expectedContentLength: expectedContentLength
                    )
                }
            }
            while let url = await group.next() {
                if let url {
                    group.cancelAll()
                    return url
                }
            }
            return nil
        }
        if let selected {
            await MediaPlaybackRouteCache.shared.store(selected, for: cacheKey)
        }
        return selected
    }

    private static func playableURL(
        _ candidate: URL,
        allowsSelfSignedCertificates: Bool,
        diagnosticStage: String,
        timeout: TimeInterval,
        expectedContentLength: Int?
    ) async -> URL? {
        let delegate = FilePreviewTrustDelegate(
            trustedHost: candidate.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
                && candidate.scheme?.lowercased() == "https"
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout + 4
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: candidate)
        request.setValue("bytes=0-1", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (_, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { return nil }
            let mimeType = response.mimeType?.lowercased() ?? ""
            let responseContentLength = totalContentLength(from: response)
            let contentLengthMatches = expectedContentLength.map { expectedLength in
                guard expectedLength > 0, let responseContentLength else { return true }
                return Int64(expectedLength) == responseContentLength
            } ?? true
            let isMediaResponse = contentLengthMatches
                && (response.statusCode == 200 || response.statusCode == 206)
                && !mimeType.contains("json")
                && !mimeType.contains("html")
            DiagnosticLogStore.shared.record(
                isMediaResponse ? .info : .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: isMediaResponse
                    ? "diagnostics.media.probe_succeeded"
                    : "diagnostics.media.probe_invalid_response",
                details: [
                    "target": DiagnosticLogStore.redactedURL(candidate),
                    "stage": diagnosticStage,
                    "status": "\(response.statusCode)",
                    "mime": mimeType.isEmpty ? "-" : mimeType,
                    "acceptRanges": response.value(forHTTPHeaderField: "Accept-Ranges") ?? "-",
                    "lengthCheck": contentLengthMatches ? "matchedOrUnavailable" : "mismatch"
                ]
            )
            return isMediaResponse ? (response.url ?? candidate) : nil
        } catch is CancellationError {
            return nil
        } catch {
            let value = error as NSError
            guard !Task.isCancelled,
                  !(value.domain == NSURLErrorDomain && value.code == NSURLErrorCancelled) else {
                return nil
            }
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.probe_failed",
                details: [
                    "target": DiagnosticLogStore.redactedURL(candidate),
                    "stage": diagnosticStage,
                    "errorDomain": value.domain,
                    "errorCode": "\(value.code)"
                ]
            )
            return nil
        }
    }

    private static func totalContentLength(from response: HTTPURLResponse) -> Int64? {
        if let contentRange = response.value(forHTTPHeaderField: "Content-Range"),
           let total = contentRange.split(separator: "/").last,
           total != "*" {
            return Int64(total)
        }
        guard response.statusCode == 200,
              let value = response.value(forHTTPHeaderField: "Content-Length") else {
            return nil
        }
        return Int64(value)
    }
}

enum MediaRangePolicy {
    struct ContentRange: Equatable {
        let start: Int64
        let end: Int64
        let totalLength: Int64

        var bodyLength: Int64 { end - start + 1 }
    }

    // The client-facing response stays open; this is only the maximum amount
    // fetched from the upstream in one URLSession task. It bounds memory and
    // remote connection lifetime without making a playback decision based on
    // a particular title, container, or bitrate.
    static let upstreamWindowBytes: Int64 = 32 * 1024 * 1024

    static func boundedRange(_ value: String, maximumLength: Int64 = upstreamWindowBytes) -> String {
        let fallbackEnd = max(maximumLength - 1, 0)
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let rangeText: Substring?
        if normalized.lowercased().hasPrefix("bytes=") {
            rangeText = normalized.dropFirst("bytes=".count)
        } else {
            let components = normalized.split(
                maxSplits: 1,
                whereSeparator: { $0 == " " || $0 == "\t" }
            )
            rangeText = components.count == 2 && components[0].lowercased() == "bytes"
                ? components[1]
                : nil
        }
        guard let firstRange = rangeText?.split(separator: ",", maxSplits: 1).first,
              let separator = firstRange.firstIndex(of: "-"),
              let start = Int64(firstRange[..<separator]),
              start >= 0 else {
            return "bytes=0-\(fallbackEnd)"
        }
        let endText = firstRange[firstRange.index(after: separator)...]
        let requestedEnd = Int64(endText)
        let maximumEnd = start + fallbackEnd
        let end = min(requestedEnd ?? maximumEnd, maximumEnd)
        return "bytes=\(start)-\(max(start, end))"
    }

    static func isOpenEnded(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalized.hasPrefix("bytes=") else { return false }
        guard let firstRange = normalized.dropFirst("bytes=".count)
            .split(separator: ",", maxSplits: 1)
            .first,
            let separator = firstRange.firstIndex(of: "-") else {
            return false
        }
        guard firstRange[firstRange.index(after: separator)...].isEmpty,
              let start = Int64(firstRange[..<separator]) else {
            return false
        }
        return start >= 0
    }

    static func requestedRangeStart(from value: String?) -> Int64? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let rangeText: Substring?
        if normalized.lowercased().hasPrefix("bytes=") {
            rangeText = normalized.dropFirst("bytes=".count)
        } else {
            let components = normalized.split(
                maxSplits: 1,
                whereSeparator: { $0 == " " || $0 == "\t" }
            )
            rangeText = components.count == 2 && components[0].lowercased() == "bytes"
                ? components[1]
                : nil
        }
        guard let firstRange = rangeText?.split(separator: ",", maxSplits: 1).first,
              let separator = firstRange.firstIndex(of: "-") else {
            return nil
        }
        let startValue = firstRange[..<separator]
        guard !startValue.isEmpty,
              let start = Int64(startValue),
              start >= 0 else {
            return nil
        }
        return start
    }

    static func contentRange(from value: String?) -> ContentRange? {
        guard let value else { return nil }
        let components = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1)
        guard components.count == 2,
              components[0].lowercased() == "bytes" else {
            return nil
        }
        let rangeAndTotal = components[1].split(separator: "/", maxSplits: 1)
        guard rangeAndTotal.count == 2,
              rangeAndTotal[0] != "*",
              let totalLength = Int64(rangeAndTotal[1]),
              totalLength > 0 else {
            return nil
        }
        let bounds = rangeAndTotal[0].split(separator: "-", maxSplits: 1)
        guard bounds.count == 2,
              let start = Int64(bounds[0]),
              let end = Int64(bounds[1]),
              start >= 0,
              end >= start,
              end < totalLength else {
            return nil
        }
        return ContentRange(start: start, end: end, totalLength: totalLength)
    }

    static func validatedPartialResponse(
        statusCode: Int,
        contentRange: String?,
        expectedStart: Int64
    ) -> ContentRange? {
        guard statusCode == 206,
              let range = Self.contentRange(from: contentRange),
              range.start == expectedStart else {
            return nil
        }
        return range
    }
}

final class AuthenticatedMediaStreamProxy: @unchecked Sendable {
    static let shared = AuthenticatedMediaStreamProxy()

    private struct Route {
        let upstreamURL: URL
        let allowsSelfSignedCertificates: Bool
        let filename: String
        let isPlaylist: Bool
        let prefersFiniteRangeResponse: Bool
        let playbackTraceID: String?
        let localPort: NWEndpoint.Port
        let createdAt: Date
    }

    private let queue = DispatchQueue(label: "com.nastart.authenticated-media-stream-proxy")
    private var listener: NWListener?
    private var port: NWEndpoint.Port?
    private var routes: [String: Route] = [:]
    private var transfers: [UUID: AuthenticatedMediaProxyTransfer] = [:]
    private var listenerWaiters: [(Result<NWEndpoint.Port, Error>) -> Void] = []

    private init() {}

    func register(
        upstreamURL: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool,
        prefersFiniteRangeResponse: Bool = false,
        playbackTraceID: String? = nil
    ) async throws -> URL {
        let port = try await listenerPort()
        let token = UUID().uuidString.lowercased()
        let safeFilename = filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        await withCheckedContinuation { continuation in
            queue.async {
                let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
                self.routes = self.routes.filter { $0.value.createdAt > cutoff }
                self.routes[token] = Route(
                    upstreamURL: upstreamURL,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                    filename: safeFilename,
                    isPlaylist: upstreamURL.pathExtension.lowercased() == "m3u8",
                    prefersFiniteRangeResponse: prefersFiniteRangeResponse,
                    playbackTraceID: playbackTraceID?.isEmpty == false ? playbackTraceID : nil,
                    localPort: port,
                    createdAt: Date()
                )
                continuation.resume()
            }
        }
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port.rawValue)
        components.path = "/media/\(token)/\(safeFilename)"
        guard let url = components.url else { throw URLError(.badURL) }
        return url
    }

    private func listenerPort() async throws -> NWEndpoint.Port {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                if let port = self.port {
                    continuation.resume(returning: port)
                    return
                }
                self.listenerWaiters.append { result in
                    continuation.resume(with: result)
                }
                guard self.listener == nil else { return }
                self.startListener()
            }
        }
    }

    private func startListener() {
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
            let listener = try NWListener(using: parameters, on: .any)
            self.listener = listener
            listener.stateUpdateHandler = { [weak self, weak listener] state in
                guard let self else { return }
                switch state {
                case .ready:
                    guard let port = listener?.port else {
                        self.failListener(URLError(.cannotCreateFile))
                        return
                    }
                    self.port = port
                    let waiters = self.listenerWaiters
                    self.listenerWaiters.removeAll()
                    waiters.forEach { $0(.success(port)) }
                case .failed(let error):
                    self.failListener(error)
                default:
                    break
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.start(queue: queue)
        } catch {
            failListener(error)
        }
    }

    private func failListener(_ error: Error) {
        listener?.cancel()
        listener = nil
        port = nil
        let waiters = listenerWaiters
        listenerWaiters.removeAll()
        waiters.forEach { $0(.failure(error)) }
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            var requestData = buffer
            if let data { requestData.append(data) }
            let headerDelimiter = Data([13, 10, 13, 10])
            if requestData.range(of: headerDelimiter) != nil {
                self.handleRequest(requestData, on: connection)
                return
            }
            if error != nil || isComplete || requestData.count > 64 * 1024 {
                self.sendError(400, on: connection)
                return
            }
            self.receiveRequest(on: connection, buffer: requestData)
        }
    }

    private func handleRequest(_ data: Data, on connection: NWConnection) {
        guard
            let header = String(data: data, encoding: .isoLatin1),
            let requestLine = header.components(separatedBy: "\r\n").first
        else {
            sendError(400, on: connection)
            return
        }
        let requestParts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard requestParts.count == 3,
              requestParts[0] == "GET" || requestParts[0] == "HEAD" else {
            sendError(405, on: connection)
            return
        }
        let requestTarget = requestParts[1]
        let requestComponents = URLComponents(
            string: "http://127.0.0.1\(requestTarget.hasPrefix("/") ? requestTarget : "/\(requestTarget)")"
        )
        let path = requestComponents?.path ?? requestTarget.split(separator: "?", maxSplits: 1).first.map(String.init) ?? ""
        let pathParts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard pathParts.count >= 2, pathParts[0] == "media" else {
            sendError(404, on: connection)
            return
        }
        let token = String(pathParts[1])
        guard let route = routes[token] else {
            sendError(404, on: connection)
            return
        }
        let requestedUpstreamURL: URL
        if let redirected = requestComponents?.queryItems?.first(where: {
            $0.name.caseInsensitiveCompare("u") == .orderedSame
        })?.value,
           let redirectedURL = URL(string: redirected),
           ["http", "https"].contains(redirectedURL.scheme?.lowercased() ?? "") {
            requestedUpstreamURL = redirectedURL
        } else {
            requestedUpstreamURL = route.upstreamURL
        }
        var headers: [String: String] = [:]
        for line in header.components(separatedBy: "\r\n").dropFirst() {
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            headers[key] = value
        }

        let transferID = UUID()
        let transfer = AuthenticatedMediaProxyTransfer(
            connection: connection,
            upstreamURL: requestedUpstreamURL,
            method: requestParts[0],
            requestHeaders: headers,
            allowsSelfSignedCertificates: route.allowsSelfSignedCertificates,
            prefersFiniteRangeResponse: route.prefersFiniteRangeResponse,
            isPlaylist: route.isPlaylist
                && requestedUpstreamURL.pathExtension.lowercased() == "m3u8",
            isHLSChildRequest: route.isPlaylist
                && requestedUpstreamURL.pathExtension.lowercased() != "m3u8",
            playbackTraceID: route.playbackTraceID,
            playlistToken: token,
            playlistFilename: route.filename,
            playlistPort: route.localPort
        ) { [weak self] in
            self?.queue.async { self?.transfers[transferID] = nil }
        }
        transfers[transferID] = transfer
        transfer.start()
    }

    private func sendError(_ statusCode: Int, on connection: NWConnection) {
        let reason = HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
        let response = "HTTP/1.1 \(statusCode) \(reason)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

private final class AuthenticatedMediaProxyTransfer: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    private let connection: NWConnection
    private let upstreamURL: URL
    private let method: String
    private let requestHeaders: [String: String]
    private let allowsSelfSignedCertificates: Bool
    private let prefersFiniteRangeResponse: Bool
    private let isPlaylist: Bool
    private let isHLSChildRequest: Bool
    private let playbackTraceID: String?
    private let playlistToken: String?
    private let playlistFilename: String?
    private let playlistPort: NWEndpoint.Port?
    private let completion: () -> Void
    private let finishLock = NSLock()
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var finished = false
    private var didSendResponseHeaders = false
    private var responseStartOffset: Int64?
    private var responseEndOffset: Int64?
    private var expectedBodyBytes: Int64?
    private var deliveredBodyBytes: Int64 = 0
    private var retryAttempts = 0
    private var consecutiveRetryFailures = 0
    private var bodyBytesAtTaskStart: Int64 = 0
    private var activeRequestedRange: String?
    private var activeRequestedRangeStart: Int64?
    private var lastStatusCode: Int?
    private let startedAt = Date()
    private let bufferLock = NSLock()
    // Keep received chunks independent after they leave the URLSession
    // callback. Mutating one large Data buffer while a slice is still owned by
    // NWConnection.send can trip Swift Data's copy-on-write assertion during
    // long Range transfers.
    private var pendingBodyChunks: [Data] = []
    private var pendingBodyBytes = 0
    private var playlistBody = Data()
    private var playlistStatusCode = 200
    private var playlistContentType = "application/vnd.apple.mpegurl"
    private var playlistExpectedBodyBytes: Int64?
    private var responseTotalLength: Int64?
    private var isSendingBody = false
    private var suspendedDataTask: URLSessionDataTask?
    private var upstreamCompleted = false
    private var didScheduleConnectionClose = false
    private var upstreamTaskIndex = 0
    private let sendChunkSize = 512 * 1024
    private let highWaterMark = 4 * 1024 * 1024
    private let lowWaterMark = 1 * 1024 * 1024
    private let maximumConsecutiveRetryFailures = 5
    private let maximumMediaSegmentBytes = MediaRangePolicy.upstreamWindowBytes

    private var clientUsesChunkedMediaResponse: Bool {
        guard !prefersFiniteRangeResponse else { return false }
        guard !isPlaylist, !isHLSChildRequest else { return false }
        return MediaRangePolicy.isOpenEnded(requestHeaders["range"] ?? "bytes=0-")
    }

    private var clientUsesContinuousRangeResponse: Bool {
        guard prefersFiniteRangeResponse, !isPlaylist, !isHLSChildRequest else { return false }
        return MediaRangePolicy.isOpenEnded(requestHeaders["range"] ?? "bytes=0-")
    }

    private var proxyKind: String {
        if isPlaylist { return "hlsPlaylist" }
        if isHLSChildRequest { return "hlsChild" }
        return "mediaRange"
    }

    private var hlsRole: String {
        guard isPlaylist || isHLSChildRequest else { return "-" }
        let path = upstreamURL.path.lowercased()
        let ext = upstreamURL.pathExtension.lowercased()
        if ext == "m3u8" {
            if path.contains("master") { return "masterPlaylist" }
            return "mediaPlaylist"
        }
        if ["m4s", "ts", "mp4", "aac", "mp3", "ac3", "vtt"].contains(ext) {
            return "segment"
        }
        if ["key", "bin"].contains(ext) {
            return "key"
        }
        return ext.isEmpty ? "unknown" : ext
    }

    private var diagnosticContext: [String: String] {
        [
            "proxyKind": proxyKind,
            "hlsRole": hlsRole,
            "pathExtension": upstreamURL.pathExtension.lowercased().isEmpty
                ? "-"
                : upstreamURL.pathExtension.lowercased(),
            "upstreamTaskIndex": "\(upstreamTaskIndex)",
            "playbackTraceID": playbackTraceID ?? "-"
        ]
    }

    private func diagnosticDetails(_ details: [String: String]) -> [String: String] {
        diagnosticContext.merging(details) { _, new in new }
    }

    init(
        connection: NWConnection,
        upstreamURL: URL,
        method: String,
        requestHeaders: [String: String],
        allowsSelfSignedCertificates: Bool,
        prefersFiniteRangeResponse: Bool,
        isPlaylist: Bool,
        isHLSChildRequest: Bool,
        playbackTraceID: String?,
        playlistToken: String?,
        playlistFilename: String?,
        playlistPort: NWEndpoint.Port?,
        completion: @escaping () -> Void
    ) {
        self.connection = connection
        self.upstreamURL = upstreamURL
        self.method = method
        self.requestHeaders = requestHeaders
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.prefersFiniteRangeResponse = prefersFiniteRangeResponse
        self.isPlaylist = isPlaylist
        self.isHLSChildRequest = isHLSChildRequest
        self.playbackTraceID = playbackTraceID?.isEmpty == false ? playbackTraceID : nil
        self.playlistToken = playlistToken
        self.playlistFilename = playlistFilename
        self.playlistPort = playlistPort
        self.completion = completion
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                self?.finish(with: URLError(.networkConnectionLost))
            default:
                break
            }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        self.session = session
        startUpstreamTask()
    }

    private func startUpstreamTask(rangeOverride: String? = nil) {
        upstreamTaskIndex += 1
        bodyBytesAtTaskStart = deliveredBodyBytes
        expectedBodyBytes = nil
        responseEndOffset = nil
        let activeRange: String?
        if isPlaylist || isHLSChildRequest {
            activeRange = rangeOverride ?? requestHeaders["range"]
        } else {
            let requestedRange = rangeOverride ?? requestHeaders["range"] ?? "bytes=0-"
            // Never turn a client's open-ended first request into a
            // progressive 200 response. VLC can retain the resulting
            // Matroska stream while probing/seeking and push the app past
            // iOS's per-process memory limit. Every media request therefore
            // starts with a finite Range window; interrupted transfers are
            // resumed from the received offset below.
            activeRange = MediaRangePolicy.boundedRange(
                requestedRange,
                maximumLength: maximumMediaSegmentBytes
            )
        }
        activeRequestedRange = activeRange
        activeRequestedRangeStart = MediaRangePolicy.requestedRangeStart(from: activeRange)
        var request = URLRequest(url: upstreamURL)
        request.httpMethod = method
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        for name in ["range", "if-range", "if-none-match", "if-modified-since"] {
            if let value = requestHeaders[name] {
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
        // AVPlayer does not propagate custom headers from the master HLS
        // request to child playlists or segments. Query authentication is
        // already inherited when the local playlist is rewritten, but some
        // Jellyfin reverse proxies only honor X-Emby-Token on the media
        // request itself. Re-emit the token for every upstream HLS request;
        // never include it in diagnostics or the local response URL.
        if requestHeaders["x-emby-token"] == nil,
           let token = Self.authenticationToken(from: upstreamURL) {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        if let activeRange {
            request.setValue(activeRange, forHTTPHeaderField: "Range")
        }
        guard let session else {
            finish(with: URLError(.cancelled))
            return
        }
        let task = session.dataTask(with: request)
        self.task = task
        task.resume()
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard !isFinished else {
            completionHandler(.cancel)
            return
        }
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(with: URLError(.badServerResponse))
            return
        }
        lastStatusCode = response.statusCode
        if isPlaylist {
            playlistStatusCode = response.statusCode
            playlistContentType = response.value(forHTTPHeaderField: "Content-Type")
                ?? "application/vnd.apple.mpegurl"
            if let contentLength = response.value(forHTTPHeaderField: "Content-Length"),
               let parsedLength = Int64(contentLength), parsedLength >= 0 {
                playlistExpectedBodyBytes = parsedLength
            }
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_started",
                details: diagnosticDetails([
                    "method": method,
                    "range": activeRequestedRange ?? "full",
                    "status": "\(response.statusCode)",
                    "contentLength": playlistExpectedBodyBytes.map(String.init) ?? "-",
                    "contentRange": response.value(forHTTPHeaderField: "Content-Range") ?? "-",
                    "clientResponse": "finitePlaylist"
                ])
            )
            completionHandler(.allow)
            return
        }
        let contentRange = response.value(forHTTPHeaderField: "Content-Range")
        let parsedRange = MediaRangePolicy.contentRange(from: contentRange)
        responseTotalLength = parsedRange?.totalLength
        if !isHLSChildRequest,
           let requestedStart = activeRequestedRangeStart,
           MediaRangePolicy.validatedPartialResponse(
                statusCode: response.statusCode,
                contentRange: contentRange,
                expectedStart: requestedStart
           ) == nil {
                completionHandler(.cancel)
                rejectUpstreamResponse()
                return
        }
        if didSendResponseHeaders {
            let expectedStart = responseStartOffset.map { $0 + deliveredBodyBytes }
            guard let expectedStart,
                  let parsedRange = MediaRangePolicy.validatedPartialResponse(
                    statusCode: response.statusCode,
                    contentRange: contentRange,
                    expectedStart: expectedStart
                  ) else {
                completionHandler(.cancel)
                finish(with: URLError(.cannotParseResponse))
                return
            }
            // Each finite upstream window has its own body length. Keep that
            // per-task expectation current so an interrupted continuation is
            // resumed from the exact delivered offset instead of being
            // mistaken for a completed first window.
            responseEndOffset = parsedRange.end
            if let contentLength = response.value(forHTTPHeaderField: "Content-Length"),
               let parsedLength = Int64(contentLength), parsedLength >= 0 {
                expectedBodyBytes = parsedLength
            } else {
                expectedBodyBytes = parsedRange.bodyLength
            }
            responseTotalLength = parsedRange.totalLength
            completionHandler(.allow)
            return
        }

        didSendResponseHeaders = true
        responseStartOffset = parsedRange?.start ?? 0
        responseEndOffset = parsedRange?.end
        if let contentLength = response.value(forHTTPHeaderField: "Content-Length"),
           let parsedLength = Int64(contentLength), parsedLength >= 0 {
            expectedBodyBytes = parsedLength
        }
        let shouldExposeContinuousRange = clientUsesContinuousRangeResponse && parsedRange != nil
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_started",
            details: diagnosticDetails([
                "method": method,
                "range": activeRequestedRange ?? "full",
                "status": "\(response.statusCode)",
                "contentLength": expectedBodyBytes.map(String.init) ?? "-",
                "contentRange": contentRange ?? "-",
                "clientResponse": shouldExposeContinuousRange
                    ? "continuousRange"
                    : (clientUsesChunkedMediaResponse ? "chunkedRange" : "finiteRange")
            ])
        )
        let reason = HTTPURLResponse.localizedString(forStatusCode: response.statusCode).capitalized
        var lines = ["HTTP/1.1 \(response.statusCode) \(reason)"]
        for name in [
            "Content-Type", "Content-Length", "Content-Range", "Accept-Ranges",
            "ETag", "Last-Modified", "Content-Disposition"
        ] {
            if (clientUsesChunkedMediaResponse || shouldExposeContinuousRange)
                && (name == "Content-Length" || name == "Content-Range") {
                continue
            }
            if let value = response.value(forHTTPHeaderField: name) {
                lines.append("\(name): \(value)")
            }
        }
        if shouldExposeContinuousRange,
           let start = parsedRange?.start,
           let total = responseTotalLength,
           total > start {
            lines.append("Content-Length: \(total - start)")
            lines.append("Content-Range: bytes \(start)-\(total - 1)/\(total)")
        }
        if clientUsesChunkedMediaResponse {
            if let start = parsedRange?.start, let total = responseTotalLength, total > start {
                lines.append("Content-Range: bytes \(start)-\(total - 1)/\(total)")
            }
            lines.append("Transfer-Encoding: chunked")
        }
        lines.append("Cache-Control: no-store")
        lines.append("Connection: close")
        let header = lines.joined(separator: "\r\n") + "\r\n\r\n"
        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
            if let error { self?.finish(with: error) }
        })
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isFinished else { return }
        if isPlaylist {
            playlistBody.append(data)
            return
        }
        deliveredBodyBytes += Int64(data.count)
        bufferLock.lock()
        pendingBodyChunks.append(Data(data))
        pendingBodyBytes += data.count
        if pendingBodyBytes >= highWaterMark, suspendedDataTask == nil {
            suspendedDataTask = dataTask
            dataTask.suspend()
        }
        bufferLock.unlock()
        drainBufferedBody()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        guard let transaction = metrics.transactionMetrics.last else { return }
        func milliseconds(_ start: Date?, _ end: Date?) -> String {
            guard let start, let end else { return "-" }
            return String(Int(max(end.timeIntervalSince(start), 0) * 1_000))
        }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished",
            details: diagnosticDetails([
                "stage": "urlSessionTaskMetrics",
                "target": DiagnosticLogStore.redactedURL(upstreamURL),
                "dnsMs": milliseconds(
                    transaction.domainLookupStartDate,
                    transaction.domainLookupEndDate
                ),
                "tcpMs": milliseconds(
                    transaction.connectStartDate,
                    transaction.connectEndDate
                ),
                "tlsMs": milliseconds(
                    transaction.secureConnectionStartDate,
                    transaction.secureConnectionEndDate
                ),
                "requestMs": milliseconds(
                    transaction.requestStartDate,
                    transaction.responseStartDate
                ),
                "responseMs": milliseconds(
                    transaction.responseStartDate,
                    transaction.responseEndDate
                ),
                "totalMs": milliseconds(
                    transaction.fetchStartDate,
                    transaction.responseEndDate
                ),
                "protocol": transaction.networkProtocolName ?? "-",
                "cellular": transaction.isCellular ? "yes" : "no",
                "expensive": transaction.isExpensive ? "yes" : "no",
                "constrained": transaction.isConstrained ? "yes" : "no",
                "remoteAddress": transaction.remoteAddress ?? "-"
            ])
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !isFinished else { return }
        if isPlaylist {
            guard error == nil else {
                finish(with: error)
                return
            }
            sendPlaylist()
            return
        }
        if retryInterruptedTransfer(after: error) {
            return
        }
        guard error == nil else {
            finish(with: error)
            return
        }
        if continueChunkedMediaResponseIfNeeded() {
            return
        }
        if continueContinuousRangeResponseIfNeeded() {
            return
        }
        bufferLock.lock()
        upstreamCompleted = true
        bufferLock.unlock()
        drainBufferedBody()
    }

    private func sendPlaylist() {
        guard !isFinished else { return }
        let body = rewritePlaylist(playlistBody)
        let reason = HTTPURLResponse.localizedString(forStatusCode: playlistStatusCode).capitalized
        let header = [
            "HTTP/1.1 \(playlistStatusCode) \(reason)",
            "Content-Type: \(playlistContentType)",
            "Content-Length: \(body.count)",
            "Cache-Control: no-store",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        connection.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            if let error {
                self.finish(with: error)
                return
            }
            self.connection.send(content: body, isComplete: true, completion: .contentProcessed { [weak self] error in
                if let error { self?.finish(with: error) } else { self?.finish(with: nil) }
            })
        })
    }

    private static func authenticationToken(from url: URL) -> String? {
        guard let queryItems = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems else {
            return nil
        }
        let names = Set(["api_key", "apikey", "token", "access_token"])
        return queryItems.first {
            names.contains($0.name.lowercased()) && !($0.value ?? "").isEmpty
        }?.value
    }

    private func rewritePlaylist(_ data: Data) -> Data {
        guard
            let token = playlistToken,
            let filename = playlistFilename,
            let port = playlistPort,
            let playlist = String(data: data, encoding: .utf8)
        else { return data }

        let lines = playlist.components(separatedBy: "\n").map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return line }
            if trimmed.hasPrefix("#") {
                return rewriteURIAttributes(
                    in: line,
                    token: token,
                    filename: filename,
                    port: port
                )
            }
            return localPlaylistURL(
                for: trimmed,
                token: token,
                filename: filename,
                port: port
            ) ?? line
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    private func rewriteURIAttributes(
        in line: String,
        token: String,
        filename: String,
        port: NWEndpoint.Port
    ) -> String {
        var result = line
        var searchStart = result.startIndex
        while let start = result.range(of: "URI=\"", range: searchStart..<result.endIndex) {
            guard let end = result[start.upperBound...].firstIndex(of: "\"") else { break }
            let uri = String(result[start.upperBound..<end])
            guard let localURL = localPlaylistURL(
                for: uri,
                token: token,
                filename: filename,
                port: port
            ) else {
                searchStart = result.index(after: end)
                continue
            }
            result.replaceSubrange(start.lowerBound..<result.index(after: end), with: "URI=\"\(localURL)\"")
            searchStart = result.index(start.lowerBound, offsetBy: "URI=\"\(localURL)\"".count, limitedBy: result.endIndex)
                ?? result.endIndex
        }
        return result
    }

    private func localPlaylistURL(
        for uri: String,
        token: String,
        filename: String,
        port: NWEndpoint.Port
    ) -> String? {
        guard
            let target = URL(string: uri, relativeTo: upstreamURL)?.absoluteURL,
            ["http", "https"].contains(target.scheme?.lowercased() ?? "")
        else { return nil }

        // Jellyfin commonly puts api_key/DeviceId/PlaySessionId on the
        // master playlist URL only. AVPlayer requests rewritten child
        // playlists and segments independently, so inherit only the
        // authentication/session query items instead of relying on headers
        // that AVPlayer will not propagate.
        let authenticatedTarget = targetWithInheritedAuthenticationQuery(target)

        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port.rawValue)
        components.path = "/media/\(token)/\(filename)"
        components.queryItems = [URLQueryItem(name: "u", value: authenticatedTarget.absoluteString)]
        return components.url?.absoluteString
    }

    private func targetWithInheritedAuthenticationQuery(_ target: URL) -> URL {
        guard
            let upstreamComponents = URLComponents(url: upstreamURL, resolvingAgainstBaseURL: false),
            var targetComponents = URLComponents(url: target, resolvingAgainstBaseURL: false)
        else {
            return target
        }
        let inheritedNames = Set([
            "api_key", "apikey", "token", "access_token",
            "deviceid", "mediasourceid", "playsessionid"
        ])
        var queryItems = targetComponents.queryItems ?? []
        let existingNames = Set(queryItems.map { $0.name.lowercased() })
        for item in upstreamComponents.queryItems ?? [] {
            guard inheritedNames.contains(item.name.lowercased()),
                  !existingNames.contains(item.name.lowercased()) else {
                continue
            }
            queryItems.append(item)
        }
        targetComponents.queryItems = queryItems.isEmpty ? nil : queryItems
        return targetComponents.url ?? target
    }

    private func drainBufferedBody() {
        var chunk: Data?
        var taskToResume: URLSessionDataTask?
        var shouldClose = false

        bufferLock.lock()
        if !isSendingBody, pendingBodyBytes > 0, !pendingBodyChunks.isEmpty {
            let count = min(sendChunkSize, pendingBodyBytes)
            if let first = pendingBodyChunks.first {
                if first.count <= count {
                    chunk = first
                    pendingBodyChunks.removeFirst()
                    pendingBodyBytes -= first.count
                } else {
                    chunk = first.subdata(in: 0..<count)
                    pendingBodyChunks[0] = first.subdata(in: count..<first.count)
                    pendingBodyBytes -= count
                }
            }
            isSendingBody = true
        }
        if pendingBodyBytes <= lowWaterMark, let suspendedDataTask {
            taskToResume = suspendedDataTask
            self.suspendedDataTask = nil
        }
        if pendingBodyBytes == 0,
           !isSendingBody,
           upstreamCompleted,
           !didScheduleConnectionClose {
            didScheduleConnectionClose = true
            shouldClose = true
        }
        bufferLock.unlock()

        taskToResume?.resume()
        if let chunk {
            let wireChunk: Data
            if clientUsesChunkedMediaResponse {
                wireChunk = Data("\(String(chunk.count, radix: 16))\r\n".utf8)
                    + chunk
                    + Data("\r\n".utf8)
            } else {
                wireChunk = chunk
            }
            connection.send(content: wireChunk, completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                if let error {
                    self.finish(with: error)
                    return
                }
                self.bufferLock.lock()
                self.isSendingBody = false
                self.bufferLock.unlock()
                self.drainBufferedBody()
            })
        } else if shouldClose {
            let terminalChunk = clientUsesChunkedMediaResponse
                ? Data("0\r\n\r\n".utf8)
                : nil
            connection.send(content: terminalChunk, isComplete: true, completion: .contentProcessed { [weak self] error in
                self?.finish(with: error)
            })
        }
    }

    private func continueChunkedMediaResponseIfNeeded() -> Bool {
        guard clientUsesChunkedMediaResponse,
              let total = responseTotalLength,
              let responseStartOffset else {
            return false
        }
        let (nextOffset, overflow) = responseStartOffset.addingReportingOverflow(deliveredBodyBytes)
        guard !overflow, nextOffset < total else {
            return false
        }
        upstreamCompleted = false
        let nextRange = "bytes=\(nextOffset)-\(min(nextOffset + maximumMediaSegmentBytes - 1, total - 1))"
        startUpstreamTask(rangeOverride: nextRange)
        return true
    }

    private func continueContinuousRangeResponseIfNeeded() -> Bool {
        guard clientUsesContinuousRangeResponse,
              let total = responseTotalLength,
              let responseStartOffset else {
            return false
        }
        let (nextOffset, overflow) = responseStartOffset.addingReportingOverflow(deliveredBodyBytes)
        guard !overflow, nextOffset < total else {
            return false
        }
        upstreamCompleted = false
        let nextRange = "bytes=\(nextOffset)-\(min(nextOffset + maximumMediaSegmentBytes - 1, total - 1))"
        startUpstreamTask(rangeOverride: nextRange)
        return true
    }

    private func retryInterruptedTransfer(after error: Error?) -> Bool {
        let madeProgress = deliveredBodyBytes > bodyBytesAtTaskStart
        if madeProgress {
            consecutiveRetryFailures = 0
        } else {
            consecutiveRetryFailures += 1
        }
        let deliveredBytesInTask = max(deliveredBodyBytes - bodyBytesAtTaskStart, 0)
        guard !isFinished,
              method == "GET",
              let expectedBodyBytes,
              deliveredBytesInTask < expectedBodyBytes,
              (madeProgress || consecutiveRetryFailures < maximumConsecutiveRetryFailures),
              let responseStartOffset else {
            return false
        }
        retryAttempts += 1
        let nextOffset = responseStartOffset + deliveredBodyBytes
        let rangeEnd = responseEndOffset.flatMap { end in
            end >= nextOffset ? end : nil
        } ?? responseTotalLength.map { total in
            min(nextOffset + maximumMediaSegmentBytes - 1, total - 1)
        }
        let range = "bytes=\(nextOffset)-\(rangeEnd.map { String($0) } ?? "")"
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_retry",
            details: diagnosticDetails([
                "attempt": "\(retryAttempts)",
                "consecutiveFailures": "\(consecutiveRetryFailures)",
                "deliveredBytes": "\(deliveredBodyBytes)",
                "expectedBytes": "\(expectedBodyBytes)",
                "reason": error?.localizedDescription ?? "prematureEOF"
            ])
        )
        startUpstreamTask(rangeOverride: range)
        return true
    }

    private func rejectUpstreamResponse() {
        let response = "HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(
            content: Data(response.utf8),
            isComplete: true,
            completion: .contentProcessed { [weak self] _ in
                self?.finish(with: URLError(.cannotParseResponse))
            }
        )
        lastStatusCode = 502
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            allowsSelfSignedCertificates,
            let credential = CertificatePinStore.shared.credential(
                for: challenge,
                expectedHost: upstreamURL.host
            )
        else {
            let shouldReject = allowsSelfSignedCertificates
                && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
            completionHandler(shouldReject ? .cancelAuthenticationChallenge : .performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }

    private func finish(with error: Error?) {
        finishLock.lock()
        guard !finished else {
            finishLock.unlock()
            return
        }
        finished = true
        finishLock.unlock()
        bufferLock.lock()
        suspendedDataTask = nil
        pendingBodyChunks.removeAll(keepingCapacity: false)
        pendingBodyBytes = 0
        bufferLock.unlock()
        DiagnosticLogStore.shared.record(
            error == nil ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished",
            details: diagnosticDetails([
                "status": lastStatusCode.map(String.init) ?? "-",
                "deliveredBytes": "\(isPlaylist ? Int64(playlistBody.count) : deliveredBodyBytes)",
                "expectedBytes": (isPlaylist ? playlistExpectedBodyBytes : expectedBodyBytes)
                    .map(String.init) ?? "-",
                "durationMs": "\(Int(Date().timeIntervalSince(startedAt) * 1_000))",
                "retries": "\(retryAttempts)",
                "result": error?.localizedDescription ?? "complete"
            ])
        )
        connection.stateUpdateHandler = nil
        connection.cancel()
        task = nil
        session?.invalidateAndCancel()
        session = nil
        completion()
    }

    private var isFinished: Bool {
        finishLock.lock()
        defer { finishLock.unlock() }
        return finished
    }
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
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trustedHost,
           challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost) != .orderedSame {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        guard
            allowsSelfSignedCertificates,
            let credential = CertificatePinStore.shared.credential(
                for: challenge,
                expectedHost: trustedHost
            )
        else {
            let shouldReject = allowsSelfSignedCertificates
                && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
            completionHandler(shouldReject ? .cancelAuthenticationChallenge : .performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
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
            let expectedExtension = (filename as NSString).pathExtension.lowercased()
            let mimeType = response.mimeType?.lowercased() ?? ""
            let expectsJSON = expectedExtension == "json" || expectedExtension == "geojson"
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200...299).contains(httpResponse.statusCode),
                expectsJSON || !mimeType.contains("json"),
                !mimeType.contains("html")
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
    let endpoints: DSMConnectionEndpoints?
    let actualRoute: DSMConnectionRoute?

    var body: some View {
        List {
            Section {
                LabeledContent("devices.network.address", value: baseURL?.absoluteString ?? "-")
                LabeledContent("devices.network.protocol", value: baseURL?.scheme?.uppercased() ?? "-")
                LabeledContent("devices.network.scope") {
                    Text(LocalizedStringKey(networkScopeKey))
                }
                LabeledContent("devices.network.actual_route") {
                    Text(LocalizedStringKey(actualRoute?.titleKey ?? "status.unknown"))
                }
            } header: {
                Text("devices.network.connection")
            }

            Section {
                LabeledContent("devices.network.primary_domain", value: endpointSummary(endpoints?.primaryDomain))
                LabeledContent("devices.network.lan_address", value: endpointSummary(endpoints?.lanAddress))
                LabeledContent("devices.network.public_address", value: endpointSummary(endpoints?.publicAddress))
            } header: {
                Text("devices.network.endpoints")
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
                            Text(endpointSummary(service.preferredEndpoint(for: baseURL)))
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
                let endpoint = service.preferredEndpoint(for: baseURL)
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
        if NetworkHostClassifier.isPrivate(host) {
            return "devices.network.scope.lan"
        }
        return "devices.network.scope.remote"
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

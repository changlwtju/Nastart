import SwiftUI
import UIKit
import QuickLook
import Network
import JellyfinAPI
import NetworkMedia

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
                }.nastartListSection()

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
                }.nastartListSection()
            }
            .listStyle(.insetGrouped)
            .padding(.top, -12)
            .nastartReadableWidth()
            .nastartPageTheme()
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
                if let temperature = device.temperatureText {
                    LabeledContent("devices.status.temperature", value: temperature)
                }
                LabeledContent("devices.security.ssh", value: sshStatusText(device.sshStatus))
            } header: {
                Text("devices.detail.status")
            }.nastartListSection()

            Section {
                LabeledContent("metric.memory_ram", value: device.memoryDisplayText)
                LabeledContent("metric.storage_disk", value: device.storageDisplayText)
                LabeledContent("devices.status.storage_free", value: device.storageFreeText)
            } header: {
                Text("devices.status.capacity")
            }.nastartListSection()

            Section {
                DiagnosisRow(titleKey: "devices.diagnosis.reachable", valueKey: "devices.diagnosis.good", symbol: "checkmark.circle")
                DiagnosisRow(
                    titleKey: "devices.diagnosis.certificate",
                    valueKey: device.certificate == nil ? "status.unknown" : "devices.diagnosis.watch",
                    symbol: "lock.shield"
                )
                DiagnosisRow(
                    titleKey: "devices.diagnosis.agent",
                    valueKey: device.mode == .dsmWithAgent ? "devices.diagnosis.good" : "state.not_connected",
                    symbol: "antenna.radiowaves.left.and.right"
                )
            } header: {
                Text("devices.status.diagnosis")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .padding(.top, -12)
        .nastartReadableWidth().nastartPageTheme()
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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
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
            }.nastartListSection()

            Section {
                Picker("devices.resources.sort", selection: $sort) {
                    ForEach(ServiceResourceSort.allCases) { option in
                        Text(option.titleKey).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }.nastartListSection()

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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
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

    private func packageStatusKey(_ status: ServiceStatus) -> LocalizedStringKey {
        switch status {
        case .online: return "devices.packages.running"
        case .offline: return "devices.packages.stopped"
        default: return status.devicesTitleKey
        }
    }

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
                                Text(packageStatusKey(service.status))
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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
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
            }.nastartListSection()

            Section {
                LabeledContent("metric.cpu", value: containerPercentText(container.cpu))
                LabeledContent(
                    "devices.container.memory_percent",
                    value: containerPercentText(container.memoryPercent)
                )
                LabeledContent("devices.container.runtime_memory", value: container.memoryText)
            } header: {
                Text("devices.container.metrics")
            }.nastartListSection()

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
            }.nastartListSection()

            Section {
                Label("devices.container.agent_required", systemImage: "lock.shield")
                    .foregroundStyle(.secondary)
            } header: {
                Text("devices.container.actions")
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle(container.name)
    }
}

struct FileBrowserView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    let titleKey: LocalizedStringKey
    let items: [FileItem]
    let folderPath: String?
    @State private var query = ""
    @AppStorage("devices.files.sort") private var sort: FileBrowserSort = .name
    @AppStorage("devices.files.sort.ascending") private var sortAscending = true
    @AppStorage("devices.files.showSystemItems") private var showsSystemItems = false
    @StateObject private var loader = FolderBrowserLoader()
    @State private var retryRevision = 0

    private struct LoadID: Equatable {
        let sourceID: UUID
        let retry: Int
    }
    private var isLoading: Bool { folderPath != nil && (loader.isLoading || loader.sourceID != dataStore.folderSourceID) }
    private var loadErrorKey: String? {
        loader.sourceID == dataStore.folderSourceID ? loader.errorKey : nil
    }

    init(titleKey: LocalizedStringKey, items: [FileItem], folderPath: String? = nil) {
        self.titleKey = titleKey
        self.items = items
        self.folderPath = folderPath
    }

    private var baseItems: [FileItem] {
        if folderPath == nil { return items }
        return loader.sourceID == dataStore.folderSourceID ? loader.items : []
    }

    private var visibleItems: [FileItem] {
        let shown = showsSystemItems ? baseItems : baseItems.filter { !FileBrowserSystemItems.isSystemItem(named: $0.name) }
        return sort.sorted(filteredItems(shown), ascending: sortAscending)
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
                            retryRevision += 1
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }

                if !isLoading && loader.needsRetry && loadErrorKey == nil {
                    Button("action.retry") { retryRevision += 1 }
                }
                if !isLoading && !loader.needsRetry && visibleItems.isEmpty && loadErrorKey == nil {
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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle(titleKey)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: Text("devices.files.search"))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("devices.files.sort", selection: $sort) {
                        ForEach(FileBrowserSort.allCases) { option in
                            Text(LocalizedStringKey(option.titleKey)).tag(option)
                        }
                    }
                    Picker("devices.files.sort.direction", selection: $sortAscending) {
                        Text("devices.files.sort.ascending").tag(true)
                        Text("devices.files.sort.descending").tag(false)
                    }
                    Text("devices.files.sort.folders_first")
                    Divider()
                    Toggle("devices.files.show_system", isOn: $showsSystemItems)
                    if let folderPath {
                        Divider()
                        Text(folderPath)
                        Button {
                            UIPasteboard.general.string = folderPath
                        } label: {
                            Label("devices.files.copy_path", systemImage: "doc.on.doc")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("devices.files.options"))
            }
        }

        .task(id: LoadID(sourceID: dataStore.folderSourceID, retry: retryRevision)) {
            await loadFolder(forceRefresh: retryRevision > 0)
        }
        .refreshable { await loadFolder(forceRefresh: true) }
        .onDisappear { loader.invalidate() }
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

    @MainActor
    private func loadFolder(forceRefresh: Bool) async {
        guard let folderPath else { return }
        let sourceID = dataStore.folderSourceID
        await loader.load(sourceID: sourceID, forceRefresh: forceRefresh,
                          isConnected: { connectionStore.dsmSession != nil }) {
            var result = try await dataStore.loadFolder(path: folderPath, forceRefresh: forceRefresh)
            try Task.checkCancellation()
            guard sourceID == dataStore.folderSourceID else { throw CancellationError() }
            if !forceRefresh, result.isEmpty, let session = connectionStore.dsmSession {
                // Retain the existing single empty-snapshot refresh, scoped to
                // this directory source. A source change starts a new view task.
                _ = await dataStore.refreshDSM(session: session, useAgent: connectionStore.usesAgent)
                try Task.checkCancellation()
                guard sourceID == dataStore.folderSourceID else { throw CancellationError() }
                result = try await dataStore.loadFolder(path: folderPath, forceRefresh: true)
                try Task.checkCancellation()
                guard sourceID == dataStore.folderSourceID else { throw CancellationError() }
            }
            if result.isEmpty, folderPath == "/", dataStore.folderSnapshotMatchesSource, !dataStore.files.isEmpty {
                result = dataStore.files
            }
            return result
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
                if item.subtitle != item.path {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let modifiedAt = item.modifiedAt {
                    Text(modifiedAt, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
    @ObservedObject private var resumeStore = LocalPlaybackResumeStore.shared
    private let usesGreenfieldPlayer = true
    @State private var greenfieldPlaybackRequest: GreenfieldPlaybackLaunchRequest?
    @State private var localPreview: LocalFilePreview?
    @StateObject private var preparation = PlaybackPreparation()
    private var isPreparingPreview: Bool { preparation.isPreparing }
    @State private var verifiedStreamLookup: Task<JellyfinMatchedFileStream.Match?, Never>?
    @State private var playsFromBeginning = false
    @State private var recordingIdentityTask: Task<String?, Never>?
    @State private var recordingResumeKey: String?
    @State private var externalPlaybackURL: URL?
    @State private var showExternalPicker = false
    @State private var externalSharePayload: FileExternalSharePayload?
    @State private var pendingExternalTarget: ExternalOpenTarget?
    @State private var pendingExternalShare = false
    @State private var showCredentialHandoffWarning = false

    private var hasLocalResumePosition: Bool {
        guard let key = localResumeKey else { return false }
        return (resumeStore.entry(for: key)?.positionSeconds ?? 0) > 0
    }

    private var previewTitleKey: String {
        if usesGreenfieldPlayer, hasLocalResumePosition {
            return "media.continue.title"
        }
        return item.kind == .video || item.kind == .discImage ? "player.play" : "devices.files.preview"
    }

    private var localResumeKey: String? {
        guard let session = connectionStore.dsmSession else { return nil }
        if isTransportStreamRecording { return recordingResumeKey }
        return LocalPlaybackResumeStore.key(server: session.endpoints.primaryDomain ?? session.endpoints.publicAddress ?? session.endpoints.lanAddress ?? session.baseURL,
            account: session.account, path: item.path, byteLength: item.sizeBytes, modifiedAt: item.modifiedAt)
    }

    private var isTransportStreamRecording: Bool {
        item.kind == .video && ["ts", "m2ts", "mts"].contains((item.name as NSString).pathExtension.lowercased())
    }

    private func prepareRecordingIdentity() {
        guard isTransportStreamRecording, recordingIdentityTask == nil,
              let session = connectionStore.dsmSession else { return }
        let file = item
        let server = session.endpoints.primaryDomain ?? session.endpoints.publicAddress
            ?? session.endpoints.lanAddress ?? session.baseURL
        recordingIdentityTask = Task {
            let candidates = session.fileStationOpenURLs(path: file.path)
            guard let url = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                candidates: candidates, allowsSelfSignedCertificates: session.allowsSelfSignedCertificates,
                diagnosticStage: "recordingIdentity", timeout: 2,
                expectedContentLength: file.sizeBytes.flatMap(Int.init(exactly:)), allowsContentGrowth: true)
            else { return nil }
            let key = await LocalPlaybackResumeStore.shared.prepareRecordingKey(
                server: server, account: session.account, path: file.path,
                byteLength: file.sizeBytes, modifiedAt: file.modifiedAt,
                readRange: { offset, count in
                    await AuthenticatedMediaPlaybackResolver.recordingIdentityBytes(
                        url: url, offset: offset, count: count,
                        allowsSelfSignedCertificates: session.allowsSelfSignedCertificates,
                        minimumLength: file.sizeBytes ?? 0)
                })
            guard !Task.isCancelled else { return nil }
            await MainActor.run { recordingResumeKey = key }
            return key
        }
    }

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
            }.nastartListSection()

            Section {
                Button {
                    playsFromBeginning = false
                    previewFile()
                } label: {
                    if isPreparingPreview {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("devices.files.preparing_preview")
                        }
                    } else {
                        Label(LocalizedStringKey(previewTitleKey), systemImage: previewSymbolName)
                    }
                }
                .disabled(isPreparingPreview)
                if usesGreenfieldPlayer && (item.kind == .video || item.kind == .discImage), hasLocalResumePosition {
                    Button {
                        playsFromBeginning = true
                        previewFile()
                    } label: {
                        Label("player.play_from_beginning", systemImage: "backward.end.fill")
                    }
                    .disabled(isPreparingPreview)
                }
#if DEBUG
                if usesGreenfieldPlayer && item.kind == .video &&
                    ProcessInfo.processInfo.environment["NASTART_TEST_STATIC_HLS"] == "1" {
                    Button("静态 HLS 弱网测试") { prepareStaticHLSPlayback() }
                        .disabled(isPreparingPreview)
                }
#endif
            } header: {
                Text("devices.files.actions")
            } footer: {
                if item.kind == .discImage {
                    Text("devices.files.iso_playback_hint")
                }
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("devices.files.detail")
        .onAppear { warmVerifiedStreamMatch(); prepareRecordingIdentity() }
        .onDisappear {
            preparation.cancel()
            verifiedStreamLookup?.cancel()
            verifiedStreamLookup = nil
            recordingIdentityTask?.cancel()
            recordingIdentityTask = nil
        }
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
        .greenfieldPlaybackCover(item: $greenfieldPlaybackRequest)
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
            SystemShareView(items: [payload.url], includesVideoPlayers: item.kind == .video)
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

#if DEBUG
    private func prepareStaticHLSPlayback() {
        preparation.start { preparationID in
            let request = await DebugStaticHLSFixture.makeRequest(source: .dsmFile)
            guard preparation.isCurrent(preparationID) else {
                request?.playbackTracker?.releasePreparedResources()
                return
            }
            guard let request else {
                showFailure("external.open_failed")
                return
            }
            PlayerOrientationController.prepareForPresentation(request.initialOrientationMode)
            greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
        }
    }
#endif

    private func prepareDiscImagePlayback(from fallbackURL: URL) {
        let session = connectionStore.dsmSession
        let candidates = session?.fileStationOpenURLs(path: item.path) ?? [fallbackURL]
        preparation.start { preparationID in
            let selectedURL = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                candidates: candidates,
                allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true,
                diagnosticStage: "dsmDiscImageRange"
            ) ?? fallbackURL
            guard preparation.isCurrent(preparationID) else { return }
            do {
                let prepared = try await ISOPlaybackAdapter.prepare(
                    sourceURL: selectedURL,
                    allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true
                )
                await MainActor.run {
                    guard preparation.isCurrent(preparationID) else {
                        ISOPlaybackAdapter.release(prepared.playbackURL)
                        return
                    }
                    externalPlaybackURL = selectedURL
                    PlayerOrientationController.prepareForPresentation(.landscape)
                    let request = MediaPlaybackRequest(
                        url: prepared.playbackURL,
                        title: item.name,
                        source: .dsmFile,
                        contentKind: .discImage,
                        fileExtensionOverride: prepared.fileExtension,
                        initialPosition: playsFromBeginning ? 0 : nil,
                        initialOrientationMode: .landscape,
                        isPrivateNetworkRoute: NetworkHostClassifier.isPrivate(selectedURL.host),
                        playbackTracker: prepared.makePlaybackTracker(),
                        externalHandoffResource: MediaPlaybackResource(
                            url: selectedURL,
                            fileExtensionOverride: "iso",
                            allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates
                        ),
                        localResumeKey: localResumeKey
                    )
                    if usesGreenfieldPlayer {
                        PlayerOrientationController.prepareForPresentation(request.initialOrientationMode)
                        greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
                    } else { playbackRequest = request }
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
                    guard preparation.isCurrent(preparationID) else { return }
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

    private func warmVerifiedStreamMatch() {
        guard usesGreenfieldPlayer, item.kind == .video,
              (item.sizeBytes ?? 0) >= 16 * 1024 * 1024 * 1024,
              PlaybackNetworkObserver.shared.snapshot().cacheKey != "wifi",
              verifiedStreamLookup == nil else { return }
        let file = item
        let services = dataStore.services.filter(\.isJellyfin)
        let session = connectionStore.dsmSession
        let store = dataStore
        verifiedStreamLookup = Task {
            let directory = (file.path as NSString).deletingLastPathComponent
            let siblings = try? await store.loadFolder(path: directory)
            return await JellyfinMatchedFileStream.resolve(
                file: file, services: services,
                siblingItems: siblings, dsmSession: session)
        }
    }

    private func prepareMediaPlayback(from url: URL) {
        let requestedAt = Date()
        let playbackTraceID = String(UUID().uuidString.prefix(8))
        let preparationStartedAt = ProcessInfo.processInfo.systemUptime
        // Bounded phase timing separates metadata/route waiting from decoder
        // startup without recording file paths, credentials or folder contents.
        func recordPhase(_ phase: String, result: String, startedAt: TimeInterval) {
#if DEBUG
            let now = ProcessInfo.processInfo.systemUptime
            DiagnosticLogStore.shared.record(.info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.playback_preparation_phase",
                details: ["phase": phase, "result": result,
                          "elapsedMs": String(Int(max(0, now - startedAt) * 1_000)),
                          "sinceRequestMs": String(Int(max(0, now - preparationStartedAt) * 1_000)),
                          "playbackTraceID": playbackTraceID])
#endif
        }
        func measured<T>(_ phase: String, operation: () async -> T) async -> T {
            let startedAt = ProcessInfo.processInfo.systemUptime
            recordPhase(phase, result: "started", startedAt: startedAt)
            let value = await operation()
            recordPhase(phase, result: Task.isCancelled ? "cancelled" : "completed", startedAt: startedAt)
            return value
        }
        let fileExtension = (item.name as NSString).pathExtension.lowercased()
        let session = connectionStore.dsmSession
        let candidates = session?.fileStationOpenURLs(path: item.path) ?? [url]
        let jellyfinServices = dataStore.services.filter(\.isJellyfin)
        let expectedContentLength = item.sizeBytes.flatMap { $0 > 0 ? Int(exactly: $0) : nil }
        // A transport-stream recording can grow after the directory snapshot.
        // Keep exact length checks for other files and reject TS truncation.
        let allowsContentGrowth = ["ts", "m2ts", "mts"].contains(fileExtension)
        let greenfieldRequested = usesGreenfieldPlayer && item.kind == .video
        preparation.start { preparationID in
            let playbackResumeKey = isTransportStreamRecording
                ? await recordingIdentityTask?.value : localResumeKey
            let directory = (item.path as NSString).deletingLastPathComponent
            let siblingItems = await measured("siblingDirectory") {
                try? await dataStore.loadFolder(path: directory)
            }
            guard preparation.isCurrent(preparationID) else { return }
            let lyricsItem = item.kind == .audio ? siblingItems?.first {
                ($0.name as NSString).pathExtension.lowercased() == "lrc"
                    && ($0.name as NSString).deletingPathExtension.caseInsensitiveCompare(
                        (item.name as NSString).deletingPathExtension) == .orderedSame
            } : nil
            let lyricsURL = lyricsItem.flatMap { session?.fileStationOpenURL(path: $0.path) }
            async let sidecarSubtitle = measured("sidecarSubtitle") {
                await NASSubtitleAssetResolver.resolve(
                    videoPath: item.path, videoName: item.name,
                    session: session, siblingItems: siblingItems)
            }
            // A verified Jellyfin copy can supply a sustainable stream before
            // a large original repeatedly stalls on cellular.
            let fileNetwork = PlaybackNetworkObserver.shared.snapshot()
            let matchedStreamStartedAt = ProcessInfo.processInfo.systemUptime
            recordPhase("verifiedStreamMatch", result: "started", startedAt: matchedStreamStartedAt)
            let matchedStream: JellyfinMatchedFileStream.Match?
            if greenfieldRequested, fileNetwork.cacheKey != "wifi" {
                if let warm = await verifiedStreamLookup?.value,
                   Date().timeIntervalSince(warm.measuredAt) < 30 {
                    matchedStream = warm
                } else {
                    matchedStream = await JellyfinMatchedFileStream.resolve(
                        file: item, services: jellyfinServices,
                        siblingItems: siblingItems, dsmSession: session)
                }
            } else {
                matchedStream = nil
            }
            recordPhase("verifiedStreamMatch", result: matchedStream == nil ? "unavailable" : "matched",
                        startedAt: matchedStreamStartedAt)
            if let match = matchedStream,
               let sourceBitrate = match.sourceBitrate ?? match.durationSeconds.flatMap({ duration in
                    duration > 0 ? Int(Double(item.sizeBytes ?? 0) * 8 / duration) : nil
               }),
               // The same verdict and rendition ceiling as the Jellyfin entry
               // on this network, with this lookup's probe as the evidence.
               let bitrate = JellyfinMatchedFileStream.startupRendition(
                    sourceBitrate: sourceBitrate, probe: match.measuredCapacity,
                    probeAge: Date().timeIntervalSince(match.measuredAt),
                    networkBitrateCap: fileNetwork.bitrateCap),
               let selection = JellyfinMatchedFileStream.initialSelection(
                    match: match,
                    resume: playbackResumeKey.flatMap { LocalPlaybackResumeStore.shared.entry(for: $0) },
                    playsFromBeginning: playsFromBeginning,
                    externalSubtitleURL: (await sidecarSubtitle)?.playbackURL),
               let request = await JellyfinMatchedFileStream.playbackRequest(
                    file: item, match: match, bitrate: bitrate,
                    startSeconds: nil, initialPosition: selection.initialPosition,
                    subtitleURL: selection.tracks.externalSubtitleURL,
                    localResumeKey: playbackResumeKey, requestedAt: requestedAt,
                    preferredAudioStreamIndex: selection.tracks.audioIndex,
                    preferredSubtitleStreamIndex: selection.tracks.subtitleIndex,
                    availableExternalSubtitleURL: (await sidecarSubtitle)?.playbackURL) {
                await preparation.holdPreparedResultForDebugIfRequested(preparationID, entry: "dsmMatchedHLS")
                await MainActor.run {
                    guard preparation.isCurrent(preparationID) else {
                        request.playbackTracker?.releasePreparedResources()
                        AuthenticatedMediaStreamProxy.shared.unregister(request.url)
                        return
                    }
                    DiagnosticLogStore.shared.record(.info,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.files.preview_stream_started",
                        details: ["transport": "verifiedJellyfinHLS",
                                  "bitrate": String(bitrate),
                                  "sourceBitrate": String(sourceBitrate),
                                  "probeCapacity": match.measuredCapacity.map(String.init) ?? "none",
                                  "prepareMs": String(Int(Date().timeIntervalSince(requestedAt) * 1_000)),
                                  "playbackTraceID": request.playbackTraceID ?? "-"])
                    PlayerOrientationController.prepareForPresentation(.landscape)
                    greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
                }
                return
            }
            guard preparation.isCurrent(preparationID) else { return }
            // Validate DSM's authenticated Range endpoint before passing it
            // to KSPlayer; a login/error JSON response is not a media stream.
            var matchingJellyfinOriginal: URL?
            let selectedURL: URL
            if greenfieldRequested {
                let localCandidates = candidates.filter { NetworkHostClassifier.isPrivate($0.host) }
                let remoteCandidates = candidates.filter { !NetworkHostClassifier.isPrivate($0.host) }
                let resolved = await PlaybackFileOriginalRouteSelection.resolve(
                    publicFirst: PlaybackFileOriginalRouteSelection.prefersPublicFirst(
                        networkKey: PlaybackNetworkObserver.shared.snapshot().cacheKey,
                        remoteCandidates: remoteCandidates),
                    isCurrent: { preparation.isCurrent(preparationID) },
                    local: {
                        // Both routes authenticate the same original file. A
                        // slow optional Jellyfin lookup must not delay a valid
                        // File Station Range response on the local network.
                        let winner = await PlaybackOriginalRouteRace.resolve(jellyfin: {
                            guard !Task.isCancelled, preparation.isCurrent(preparationID) else { return nil }
                            let startedAt = ProcessInfo.processInfo.systemUptime
                            recordPhase("verifiedOriginalRoute", result: "started", startedAt: startedAt)
                            let matching = await JellyfinOriginalFileRouteResolver.resolve(
                                file: item, services: jellyfinServices, dsmSession: session)
                            recordPhase("verifiedOriginalRoute",
                                        result: Task.isCancelled ? "cancelled" : (matching == nil ? "unavailable" : "matched"),
                                        startedAt: startedAt)
                            return matching
                        }, fileStation: {
                            guard !Task.isCancelled, preparation.isCurrent(preparationID) else { return nil }
                            let startedAt = ProcessInfo.processInfo.systemUptime
                            recordPhase("localRange", result: "started", startedAt: startedAt)
                            let localURL = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                                candidates: localCandidates,
                                allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true,
                                diagnosticStage: "dsmGreenfieldLANRange", timeout: 2,
                                expectedContentLength: expectedContentLength,
                                allowsContentGrowth: allowsContentGrowth)
                            recordPhase("localRange",
                                        result: Task.isCancelled ? "cancelled" : (localURL == nil ? "unavailable" : "validated"),
                                        startedAt: startedAt)
                            return localURL
                        })
                        guard !Task.isCancelled, preparation.isCurrent(preparationID) else { return nil }
                        matchingJellyfinOriginal = winner?.source == .jellyfin ? winner?.url : nil
                        return winner?.url
                    }, remote: {
                        let startedAt = ProcessInfo.processInfo.systemUptime
                        recordPhase("remoteRange", result: "started", startedAt: startedAt)
                        let remoteURL = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                            candidates: remoteCandidates,
                            allowsSelfSignedCertificates: session?.allowsSelfSignedCertificates == true,
                            diagnosticStage: "dsmGreenfieldRange", timeout: 4,
                            expectedContentLength: expectedContentLength,
                            allowsContentGrowth: allowsContentGrowth)
                        recordPhase("remoteRange", result: remoteURL == nil ? "unavailable" : "validated",
                                    startedAt: startedAt)
                        return remoteURL
                    })
                guard let resolved else {
                    await MainActor.run {
                        guard preparation.isCurrent(preparationID) else { return }
                        showFailure("player.load_failed")
                    }
                    return
                }
                selectedURL = resolved
            } else {
                selectedURL = candidates.first ?? url
            }
            guard preparation.isCurrent(preparationID) else { return }
            let subtitleAsset = await sidecarSubtitle
            guard preparation.isCurrent(preparationID) else { return }
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
                preparedProxyURL = try? await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
                    upstreamURL: selectedURL,
                    filename: item.name,
                    allowsSelfSignedCertificates: fallbackAllowsSelfSigned,
                    usesGreenfieldPlayback: greenfieldRequested,
                    playbackTraceID: playbackTraceID
                )
            } else {
                preparedProxyURL = nil
            }
            let playbackURL = preparedProxyURL ?? selectedURL
            let playbackUsesLocalProxy = preparedProxyURL != nil
            // Healthy Wi-Fi keeps the original route. Resolve and negotiate a
            // verified candidate only when the common downshift policy asks.
            let originalFallbackLoader = greenfieldRequested
                ? JellyfinMatchedFileStream.originalFallbackRequestLoader(
                    file: item, sourceTraceID: playbackTraceID,
                    networkKey: fileNetwork.cacheKey, subtitleURL: subtitleAsset?.playbackURL,
                    localResumeKey: playbackResumeKey, resolveMatch: {
                        if let matchedStream,
                           Date().timeIntervalSince(matchedStream.measuredAt) < 30 {
                            return matchedStream
                        }
                        return await JellyfinMatchedFileStream.resolve(
                            file: item, services: jellyfinServices,
                            siblingItems: siblingItems, dsmSession: session)
                    }) : nil
            await preparation.holdPreparedResultForDebugIfRequested(preparationID, entry: "dsmOriginal")
            await MainActor.run {
                guard preparation.isCurrent(preparationID) else {
                    if let preparedProxyURL { AuthenticatedMediaStreamProxy.shared.unregister(preparedProxyURL) }
                    return
                }
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
                        "greenfield": greenfieldRequested ? "on" : "off",
                        "playbackTraceID": playbackTraceID,
                        "upstreamSource": matchingJellyfinOriginal == nil ? "dsmFileStation" : "jellyfinVerifiedOriginal"
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
                    initialPosition: playsFromBeginning ? 0 : nil,
                    externalSubtitleURL: subtitleAsset?.playbackURL,
                    initialOrientationMode: item.kind == .video ? .landscape : .automatic,
                    byteLength: item.sizeBytes,
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
                            guard let proxyURL = try? await AuthenticatedMediaStreamProxy.shared.registerOriginalStream(
                                upstreamURL: resolvedFallbackURL,
                                filename: fallbackFilename,
                                allowsSelfSignedCertificates: fallbackAllowsSelfSigned,
                                usesGreenfieldPlayback: greenfieldRequested,
                                playbackTraceID: playbackTraceID
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
                        : nil,
                    compatibilityFallbackRequestLoader: originalFallbackLoader,
                    playbackTraceID: playbackTraceID,
                    audioLyricsURL: lyricsURL,
                    localResumeKey: item.kind == .video ? playbackResumeKey : nil
                )
                if greenfieldRequested {
                    PlayerOrientationController.prepareForPresentation(request.initialOrientationMode)
                        greenfieldPlaybackRequest = request.greenfieldPlaybackLaunchRequest()
                } else {
                    PlayerOrientationController.prepareForPresentation(
                        item.kind == .video ? .landscape : .automatic
                    )
                    playbackRequest = request
                }
            }
        }
    }

    private func prepareLocalPreview(from url: URL) {
        preparation.start { preparationID in
            do {
                let fileURL = try await AuthenticatedFilePreviewLoader.download(
                    from: url,
                    filename: item.name,
                    allowsSelfSignedCertificates: connectionStore.dsmSession?.allowsSelfSignedCertificates == true
                )
                await MainActor.run {
                    guard preparation.isCurrent(preparationID) else { return }
                    localPreview = LocalFilePreview(url: fileURL)
                }
            } catch {
                await MainActor.run {
                    guard preparation.isCurrent(preparationID) else { return }
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

/// A large DSM file may be served more efficiently by the same NAS's
/// Jellyfin original endpoint. Keep the device-file identity and controls;
/// switch only the authenticated bytes, after checking server and file identity.
@MainActor
enum JellyfinOriginalFileRouteResolver {
    private struct Match {
        let itemID: String
        let sourceID: String?
        let container: String
        let path: String
    }

    static func resolve(file: FileItem, services: [LaunchpadService],
                        dsmSession: DSMSession?) async -> URL? {
        guard let size = file.sizeBytes, size >= 16 * 1024 * 1024 * 1024,
              let expectedLength = Int(exactly: size),
              let lanHost = dsmSession?.endpoints.lanAddress?.host,
              NetworkHostClassifier.isPrivate(lanHost) else { return nil }
        let endpoints = services.flatMap {
            JellyfinSessionEndpointPolicy.configuredEndpoints(for: $0, dsmBaseURL: dsmSession?.baseURL)
        }
        let restored = JellyfinSessionEndpointPolicy.candidates(from: endpoints).lazy
            .compactMap { candidate in
                KeychainStore.shared.loadJellyfinSession(endpoint: candidate).map {
                    (endpoint: candidate, session: $0)
                }
            }
            .first
        guard let restored else { return nil }
        let stored = restored.session
        let publicEndpoint = restored.endpoint
        guard let lanEndpoint = URL(string: "http://\(lanHost):8096"),
              let publicID = await publicServerID(at: publicEndpoint),
              let lanID = await publicServerID(at: lanEndpoint),
              publicID == lanID else { return nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        let client = JellyfinClient(
            configuration: .init(
                url: lanEndpoint,
                accessToken: stored.accessToken,
                client: "Nastart",
                deviceName: UIDevice.current.model,
                deviceID: JellyfinDeviceIdentity.persistentDeviceID,
                version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
            ), sessionConfiguration: configuration
        )
        var parameters = Paths.GetItemsParameters()
        parameters.userID = stored.userID
        parameters.isRecursive = true
        parameters.limit = 500
        parameters.fields = [.mediaSources, .path]
        parameters.includeItemTypes = [.movie, .episode, .video, .musicVideo]
        let items: [BaseItemDto]
        do {
            items = try await client.send(Paths.getItems(parameters: parameters)).value.items ?? []
        } catch {
            if JellyfinHTTPStatus.code(for: error) == 401 {
                DiagnosticLogStore.shared.record(.warning, categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.files.jellyfin_original_lookup",
                    details: ["stage": "originalRouteLookup", "httpStatus": "401",
                              "deviceIDPrefix": String(client.configuration.deviceID.prefix(8))])
            }
            return nil
        }
        let filename = file.name.lowercased()
        let matches: [Match] = items.flatMap { item in
            (item.mediaSources ?? []).compactMap { source -> Match? in
                guard let itemID = item.id,
                      let sourceSize = source.size, Int64(sourceSize) == size,
                      let path = source.path ?? item.path,
                      (path.replacingOccurrences(of: "\\", with: "/") as NSString)
                        .lastPathComponent.lowercased() == filename,
                      let container = (source.container ?? item.container)?
                        .split(separator: ",", maxSplits: 1).first.map(String.init),
                      !container.isEmpty else { return nil }
                return Match(itemID: itemID, sourceID: source.id,
                             container: container, path: path)
            }
        }
        let exactPathMatches = matches.filter {
            $0.path.replacingOccurrences(of: "\\", with: "/")
                .lowercased().hasSuffix(file.path.lowercased())
        }
        guard let match = (exactPathMatches.count == 1 ? exactPathMatches : matches).onlyElement else {
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "ambiguousOrUnavailable",
                          "sizeAndNameMatches": String(matches.count),
                          "exactPathMatches": String(exactPathMatches.count)])
            return nil
        }
        var streamParameters = Paths.GetVideoStreamByContainerParameters()
        streamParameters.isStatic = true
        streamParameters.mediaSourceID = match.sourceID
        guard let url = client.url(with: Paths.getVideoStreamByContainer(
            itemID: match.itemID, container: match.container,
            parameters: streamParameters), queryAPIKey: true),
            let validated = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                candidates: [url], allowsSelfSignedCertificates: false,
                diagnosticStage: "dsmMatchedJellyfinOriginal", timeout: 3,
                expectedContentLength: expectedLength
            ) else { return nil }
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.files.jellyfin_original_lookup",
            details: ["result": "verifiedOriginal", "identity": "sizeAndFilename",
                      "exactPath": exactPathMatches.count == 1 ? "yes" : "no"])
        return validated
    }

    private static func publicServerID(at endpoint: URL) async -> String? {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else { return nil }
        let base = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = (base.isEmpty ? "" : "/\(base)") + "/System/Info/Public"
        components.query = nil
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object["Id"] as? String
    }
}

/// A DSM file can use Jellyfin's lower bitrate stream only after the server
/// reports the same source file. The exact DSM path suffix, size, and filename
/// must identify one media source; title matching is never sufficient.
@MainActor
enum JellyfinMatchedFileStream {
    struct Match {
        let client: JellyfinClient
        let itemID: String
        let mediaSourceID: String
        let sourceBitrate: Int?
        let durationSeconds: Double?
        let measuredCapacity: Int?
        let measuredAt: Date
        var firstAudioStreamIndex: Int? = nil
        var mediaStreams: [MediaStream] = []
    }

    /// The rendition to start on instead of the original, or nil to play the
    /// original. The lookup's 1 MB probe is the only evidence here; like the
    /// Jellyfin entry's small probe it shows the route does at least that
    /// much, so the original is left only when the source is clearly beyond
    /// it. The rendition stays within the public ceiling for this network.
    nonisolated static func startupRendition(sourceBitrate: Int, probe: Int?, probeAge: TimeInterval,
                                             networkBitrateCap: Int?) -> Int? {
        let assessment = PlaybackRouteCapacityPolicy.assess(sustained: [], rendition: [],
            probe: probe.map { .init(bitrate: $0, age: max(probeAge, 0), boundsBothSides: false) })
        guard let capacity = assessment.capacity,
              PlaybackRouteDecisionPolicy.originalVerdict(
                sourceBitrate: sourceBitrate, assessment: assessment).prefersServerRendition else { return nil }
        let ceiling = PlaybackRouteDecisionPolicy.renditionCeiling(networkBitrateCap: networkBitrateCap)
        let rendition = PlaybackRouteDecisionPolicy.startupBitrate(
            capacity: capacity, ceiling: ceiling, unknownCapacityBitrate: ceiling)
        // The lowest rung is not a step down from a source already below it.
        return rendition < sourceBitrate ? rendition : nil
    }

    static func resolve(file: FileItem, services: [LaunchpadService],
                        siblingItems: [FileItem]?, dsmSession: DSMSession?) async -> Match? {
        guard let size = file.sizeBytes, size >= 16 * 1024 * 1024 * 1024 else { return nil }
        let rawEndpoints = services.flatMap { [$0.endpoint, $0.alternateEndpoint].compactMap { $0 } }
        let endpoints = services.flatMap {
            JellyfinSessionEndpointPolicy.configuredEndpoints(for: $0, dsmBaseURL: dsmSession?.baseURL)
        }
        let candidates = JellyfinSessionEndpointPolicy.candidates(from: endpoints)
        let sessions = candidates.compactMap { candidate in
            KeychainStore.shared.loadJellyfinSession(endpoint: candidate).map {
                (endpoint: candidate, session: $0)
            }
        }
        let selected = sessions.first(where: {
            !NetworkHostClassifier.isPrivate($0.endpoint.host)
        }) ?? sessions.first
        let rawSessionCount = rawEndpoints.filter {
            KeychainStore.shared.loadJellyfinSession(endpoint: $0) != nil
        }.count
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.files.jellyfin_original_lookup",
            details: ["result": "sessionCandidates", "serviceCount": String(services.count),
                      "candidateCount": String(candidates.count), "rawSessionCount": String(rawSessionCount),
                      "storedSessionCount": String(sessions.count),
                      "selectedPath": selected.map {
                          let path = $0.endpoint.path
                          return path.isEmpty || path == "/" ? "root"
                              : path == "/jellyfin" ? "jellyfin" : path == "/emby" ? "emby" : "custom"
                      } ?? "none"])
        guard let selected else {
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "noStoredJellyfinSession"])
            return nil
        }
        let stored = selected.session
        let endpoint = selected.endpoint
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 5
        configuration.timeoutIntervalForResource = 10
        configuration.waitsForConnectivity = false
        let client = JellyfinClient(configuration: .init(
            url: endpoint, accessToken: stored.accessToken, client: "Nastart",
            deviceName: UIDevice.current.model,
            deviceID: JellyfinDeviceIdentity.persistentDeviceID,
            version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        ), sessionConfiguration: configuration)
        let playbackClient = JellyfinClient(configuration: client.configuration,
            sessionConfiguration: JellyfinPlaybackSessionPolicy.configuration())
        var parameters = Paths.GetItemsParameters()
        parameters.userID = stored.userID
        parameters.isRecursive = true
        parameters.limit = 200
        parameters.fields = [.mediaSources, .path]
        let pathLower = file.path.lowercased()
        let itemTypes: [BaseItemKind] = pathLower.contains("/movie/")
            ? [.movie]
            : pathLower.contains("/tv/") ? [.episode] : [.movie, .episode, .video, .musicVideo]
        parameters.includeItemTypes = itemTypes
        let probeTask = Task { () -> Int? in
            let started = ProcessInfo.processInfo.systemUptime
            let delegate = PlaybackBandwidthProbeDelegate()
            guard let data = try? await playbackClient.send(
                Paths.getBitrateTestBytes(size: 1024 * 1024), delegate: delegate).value,
                !Task.isCancelled, data.count == 1024 * 1024,
                let sample = delegate.sample(bytes: data.count,
                    totalSeconds: ProcessInfo.processInfo.systemUptime - started) else { return nil }
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "bandwidthProbe", "sampleBytes": String(data.count),
                          "measuredBitrate": String(sample.bitrate),
                          "measurementBasis": sample.usesNetworkBodyTiming ? "networkBody" : "totalRequest",
                          "totalMs": String(Int(sample.totalSeconds * 1000)),
                          "bodyMs": sample.bodySeconds.map { String(Int($0 * 1000)) } ?? "unknown"])
            return sample.usesNetworkBodyTiming ? sample.bitrate : nil
        }
        let parentName = ((file.path as NSString).deletingLastPathComponent as NSString)
            .lastPathComponent
        let folderName = parentName.replacingOccurrences(
            of: #"\s*\(\d{4}\)$"#, with: "", options: .regularExpression)
        let nfoName = await nfoTitle(siblingItems: siblingItems, dsmSession: dsmSession)
        let searchName = nfoName ?? folderName
        if itemTypes == [.movie], searchName.count >= 4 {
            parameters.searchTerm = searchName
        }
        func exactMatches(in items: [BaseItemDto]) -> [(String, String, Int?, Double?, Int?, [MediaStream])] {
            items.flatMap { item in
                (item.mediaSources ?? []).compactMap { source -> (String, String, Int?, Double?, Int?, [MediaStream])? in
                    guard let itemID = item.id, let sourceID = source.id,
                          let sourceSize = source.size, Int64(sourceSize) == size,
                          let path = source.path ?? item.path,
                          VerifiedFileIdentityPolicy.matches(
                            dsmPath: file.path, dsmSize: size,
                            jellyfinPath: path, jellyfinSize: Int64(sourceSize)) else { return nil }
                    return (itemID, sourceID, source.bitrate,
                            item.runTimeTicks.map { Double($0) / 10_000_000 },
                            source.mediaStreams?.first(where: { $0.type == .audio })?.index,
                            source.mediaStreams ?? [])
                }
            }
        }
        let lookup: VerifiedFileLookupPolicy.Outcome<BaseItemDto>
        do {
            lookup = try await VerifiedFileLookupPolicy.load(searchHint: parameters.searchTerm,
                fetch: { hint, startIndex in
                    var query = parameters
                    query.searchTerm = hint
                    query.startIndex = startIndex
                    let page = try await client.send(Paths.getItems(parameters: query)).value
                    return .init(items: page.items ?? [], totalCount: page.totalRecordCount)
                }, hasExactMatch: { !exactMatches(in: $0).isEmpty })
        } catch {
            probeTask.cancel()
            let nsError = error as NSError
            var details = ["result": "mediaLookupFailed",
                           "errorDomain": nsError.domain, "errorCode": String(nsError.code),
                           "target": DiagnosticLogStore.redactedURL(endpoint)]
            if let status = JellyfinHTTPStatus.code(for: error) {
                details["httpStatus"] = String(status)
                if status == 401 {
                    details["stage"] = "mediaLookup"
                    details["deviceIDPrefix"] = String(client.configuration.deviceID.prefix(8))
                }
            }
            DiagnosticLogStore.shared.record(.warning, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: details)
            return nil
        }
        let items = lookup.items
        let filename = file.name.lowercased()
        let sources = items.flatMap { $0.mediaSources ?? [] }
        let matchingSizes = sources.filter {
            $0.size.map { Int64($0) == size } == true
        }
        let matchingNames = matchingSizes.filter { source in
            source.path.map {
                ($0.replacingOccurrences(of: "\\", with: "/") as NSString)
                    .lastPathComponent.lowercased() == filename
            } == true
        }
        let matches = exactMatches(in: items)
        guard lookup.isComplete, matches.count == 1, let match = matches.first else {
            probeTask.cancel()
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "noUniqueExactFile", "exactPathMatches": String(matches.count),
                          "items": String(items.count), "sources": String(sources.count),
                          "sizeMatches": String(matchingSizes.count),
                          "nameMatches": String(matchingNames.count),
                          "movieFolder": pathLower.contains("/movie/") ? "yes" : "no",
                          "searchUsed": parameters.searchTerm == nil ? "no" : "yes",
                          "searchBroadened": lookup.broadenedSearch ? "yes" : "no",
                          "lookupComplete": lookup.isComplete ? "yes" : "no",
                          "searchSource": nfoName == nil ? "folder" : "nfo"])
            return nil
        }
        let capacity = await probeTask.value
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.files.jellyfin_original_lookup",
            details: ["result": "verifiedTranscodeSource", "identity": "parentTailSizeAndFilename",
                      "searchBroadened": lookup.broadenedSearch ? "yes" : "no",
                      "lookupComplete": "yes",
                      "measuredBitrate": capacity.map(String.init) ?? "unknown"])
        return Match(client: playbackClient, itemID: match.0, mediaSourceID: match.1,
                     sourceBitrate: match.2, durationSeconds: match.3,
                     measuredCapacity: capacity, measuredAt: Date(), firstAudioStreamIndex: match.4,
                     mediaStreams: match.5)
    }

    struct TrackSelection: Equatable {
        let audioIndex: Int
        let subtitleIndex: Int?
        let externalSubtitleURL: URL?
    }

    struct InitialSelection: Equatable {
        let tracks: TrackSelection
        let initialPosition: Double?
    }

    /// An initial HLS renderer's ordinal zero is not a source stream identity.
    /// Verify the saved selection before taking this shortcut, as we do for a
    /// runtime handoff. Otherwise leave preparation on the original-file path.
    static func initialSelection(match: Match, resume: LocalPlaybackResumeStore.Entry?,
                                 playsFromBeginning: Bool,
                                 externalSubtitleURL: URL?) -> InitialSelection? {
        guard let audio = resume?.audioTrackID ?? match.firstAudioStreamIndex else { return nil }
        let subtitle: Int?
        let external: URL?
        if let resume {
            if resume.subtitlesDisabled {
                subtitle = nil; external = nil
            } else if resume.subtitleTrackID == -2 {
                guard let externalSubtitleURL else { return nil }
                subtitle = nil; external = externalSubtitleURL
            } else {
                guard let savedSubtitle = resume.subtitleTrackID, savedSubtitle >= 0 else { return nil }
                subtitle = savedSubtitle; external = nil
            }
        } else {
            subtitle = nil; external = externalSubtitleURL
        }
        let state = MediaPlaybackRuntimeState(
            normalizedPosition: 0, positionSeconds: 0, playbackRate: 1,
            audioTrackOrdinal: nil, subtitleTrackOrdinal: subtitle == nil ? nil : 0,
            subtitlesDisabled: subtitle == nil && external == nil,
            subtitleSelectionKnown: true, orientationMode: .landscape,
            sourceAudioStreamIndex: audio, sourceSubtitleStreamIndex: subtitle,
            activeExternalSubtitleURL: external)
        guard let tracks = verifiedTracks(match: match, runtime: state) else { return nil }
        let position: Double?
        if playsFromBeginning {
            position = 0
        } else if let resume {
            guard resume.positionSeconds.isFinite, resume.positionSeconds >= 0,
                  let duration = match.durationSeconds, duration.isFinite, duration > 0,
                  resume.positionSeconds <= duration else { return nil }
            position = resume.positionSeconds / duration
        } else {
            position = nil
        }
        return InitialSelection(tracks: tracks, initialPosition: position)
    }

    static func verifiedTracks(match: Match, runtime: MediaPlaybackRuntimeState) -> TrackSelection? {
        guard runtime.subtitleSelectionKnown, let audio = runtime.sourceAudioStreamIndex,
              audio >= 0, match.mediaStreams.filter({ $0.index == audio }).count == 1,
              match.mediaStreams.first(where: { $0.index == audio })?.type == .audio else { return nil }
        if runtime.subtitlesDisabled {
            guard runtime.subtitleTrackOrdinal == nil, runtime.activeExternalSubtitleURL == nil else { return nil }
            return .init(audioIndex: audio, subtitleIndex: nil, externalSubtitleURL: nil)
        }
        if let external = runtime.activeExternalSubtitleURL {
            return .init(audioIndex: audio, subtitleIndex: nil, externalSubtitleURL: external)
        }
        guard let subtitle = runtime.sourceSubtitleStreamIndex, subtitle >= 0,
              match.mediaStreams.filter({ $0.index == subtitle }).count == 1,
              match.mediaStreams.filter({ $0.type == .subtitle && $0.index == subtitle
                  && $0.isExternal != true && $0.codec?.isEmpty == false }).count == 1 else { return nil }
        return .init(audioIndex: audio, subtitleIndex: subtitle, externalSubtitleURL: nil)
    }

    static func originalFallbackRequestLoader(
        file: FileItem, sourceTraceID: String, networkKey: String,
        subtitleURL: URL?, localResumeKey: String?,
        resolveMatch: @escaping () async -> Match?,
        prepareRequest: ((Match, Int, Double, TrackSelection) async -> MediaPlaybackRequest?)? = nil
    ) -> ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)? {
        guard file.kind == .video, (file.sizeBytes ?? 0) >= 16 * 1024 * 1024 * 1024 else { return nil }
        return { runtime in
            guard !Task.isCancelled else { return nil }
            guard let runtime, let position = runtime.positionSeconds,
                  position.isFinite, position >= 0, runtime.subtitleSelectionKnown,
                  runtime.sourceAudioStreamIndex != nil,
                  runtime.subtitlesDisabled
                    ? (runtime.subtitleTrackOrdinal == nil && runtime.activeExternalSubtitleURL == nil)
                    : (runtime.activeExternalSubtitleURL != nil || runtime.sourceSubtitleStreamIndex != nil) else {
                recordTrackDecline(runtime, traceID: sourceTraceID, reason: "runtimeTracks")
                return nil
            }
            guard let match = await resolveMatch(), !Task.isCancelled else { return nil }
            guard let tracks = verifiedTracks(match: match, runtime: runtime) else {
                recordTrackDecline(runtime, traceID: sourceTraceID, reason: "unverifiedSourceTracks")
                return nil
            }
            let sourceBitrate = match.sourceBitrate.flatMap { $0 > 0 ? $0 : nil }
                ?? match.durationSeconds.flatMap { duration -> Int? in
                    guard duration.isFinite, duration > 0, let size = file.sizeBytes else { return nil }
                    let value = Double(size) * 8 / duration
                    return value.isFinite && value > 0 && value < Double(Int.max) ? Int(value) : nil
                }
            let observed = PlaybackRecentThroughputStore.shared.estimate(
                traceID: sourceTraceID, now: ProcessInfo.processInfo.systemUptime)
            let freshProbe = Date().timeIntervalSince(match.measuredAt) < 30 ? match.measuredCapacity : nil
            let capacity = PlaybackRouteDecisionPolicy.fallbackCapacity(live: observed, route: freshProbe)
            guard let sourceBitrate, let bitrate = PlaybackAdaptiveBitratePolicy.target(
                currentCeiling: sourceBitrate, capacity: capacity, networkKey: networkKey) else { return nil }
            let request: MediaPlaybackRequest?
            if let prepareRequest { request = await prepareRequest(match, bitrate, position, tracks) }
            else {
                request = await playbackRequest(file: file, match: match, bitrate: bitrate,
                    startSeconds: position, initialPosition: nil, subtitleURL: tracks.externalSubtitleURL,
                    localResumeKey: localResumeKey, preferredAudioStreamIndex: tracks.audioIndex,
                    preferredSubtitleStreamIndex: tracks.subtitleIndex,
                    availableExternalSubtitleURL: tracks.externalSubtitleURL ?? subtitleURL)
            }
            guard let request else { return nil }
            guard !Task.isCancelled else {
                request.playbackTracker?.releasePreparedResources()
                return nil
            }
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "originalFallbackPrepared", "bitrate": String(bitrate),
                          "audioStreamIndex": String(tracks.audioIndex),
                          "subtitleStreamIndex": tracks.subtitleIndex.map(String.init) ?? "-1",
                          "externalSubtitleActive": tracks.externalSubtitleURL == nil ? "no" : "yes",
                          "playbackTraceID": sourceTraceID])
            return request.applyingRuntimePreferences(runtime)
        }
    }

    private static func recordTrackDecline(_ runtime: MediaPlaybackRuntimeState?, traceID: String, reason: String) {
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.files.jellyfin_original_lookup",
            details: ["result": "originalFallbackUnavailable", "reason": reason,
                      "audioOrdinal": runtime?.audioTrackOrdinal.map(String.init) ?? "unknown",
                      "audioStreamIndex": runtime?.sourceAudioStreamIndex.map(String.init) ?? "unknown",
                      "subtitleOrdinal": runtime?.subtitleTrackOrdinal.map(String.init) ?? "none",
                      "subtitleStreamIndex": runtime?.sourceSubtitleStreamIndex.map(String.init) ?? "none",
                      "subtitleSelectionKnown": runtime?.subtitleSelectionKnown == true ? "yes" : "no",
                      "subtitlesDisabled": runtime?.subtitlesDisabled == true ? "yes" : "no",
                      "externalSubtitleActive": runtime?.activeExternalSubtitleURL == nil ? "no" : "yes",
                      "playbackTraceID": traceID])
    }

    static func negotiatedTracksMatch(url: URL, audioIndex: Int, subtitleIndex: Int?,
        negotiatedAudioIndex: Int? = nil, negotiatedSubtitleIndex: Int? = nil) -> Bool {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func values(_ name: String) -> [String] {
            items.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }.map { $0.value ?? "" }
        }
        guard values("AudioStreamIndex") == [String(audioIndex)],
              negotiatedAudioIndex == nil || negotiatedAudioIndex == audioIndex else { return false }
        let subtitles = values("SubtitleStreamIndex")
        if let subtitleIndex {
            return subtitles == [String(subtitleIndex)]
                && (negotiatedSubtitleIndex == nil || negotiatedSubtitleIndex == subtitleIndex)
                && values("SubtitleMethod").map { $0.lowercased() } == ["encode"]
        }
        guard negotiatedSubtitleIndex == nil || negotiatedSubtitleIndex == -1 else { return false }
        // Jellyfin StreamInfo.ToUrl deliberately omits SubtitleStreamIndex=-1.
        // Accept that form only when PlaybackInfo explicitly confirms Off;
        // an absent query on its own is never proof of the user's selection.
        return subtitles == ["-1"] || (subtitles.isEmpty && negotiatedSubtitleIndex == -1)
    }

    private static func queryIndex(_ name: String, in url: URL) -> String {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = items.filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        guard values.count == 1, let value = values.first?.value, let index = Int(value) else {
            return values.isEmpty ? "none" : "invalidOrRepeated"
        }
        return String(index)
    }

    private static func nfoTitle(siblingItems: [FileItem]?,
                                 dsmSession: DSMSession?) async -> String? {
        guard let nfo = siblingItems?.first(where: {
            $0.name.lowercased() == "movie.nfo" && ($0.sizeBytes ?? 0) < 128 * 1024
        }), let url = dsmSession?.fileStationOpenURL(path: nfo.path),
            let local = try? await AuthenticatedFilePreviewLoader.download(
                from: url, filename: nfo.name,
                allowsSelfSignedCertificates: dsmSession?.allowsSelfSignedCertificates == true,
                timeoutInterval: 5)
        else { return nil }
        defer { try? FileManager.default.removeItem(at: local.deletingLastPathComponent()) }
        guard let xml = try? String(contentsOf: local, encoding: .utf8),
              let range = xml.range(of: #"<title>[^<]{2,120}</title>"#,
                                    options: [.regularExpression, .caseInsensitive])
        else { return nil }
        let title = String(xml[range]).replacingOccurrences(of: "<title>", with: "")
            .replacingOccurrences(of: "</title>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private struct PreparedStream {
        let url: URL
        let playSessionID: String?
    }

    private static func stopEncoding(match: Match, playSessionID: String?) {
        guard let playSessionID else { return }
        Task {
            _ = try? await match.client.send(Paths.stopEncodingProcess(
                deviceID: match.client.configuration.deviceID,
                playSessionID: playSessionID
            )).value
        }
    }

    static func playbackInfoRequest(for match: Match, bitrate: Int, startSeconds: Double?,
                                    preferredAudioStreamIndex: Int? = nil,
                                    preferredSubtitleStreamIndex: Int? = nil) -> PlaybackInfoDto {
        let size = GreenfieldQualityPolicy.maximumVideoSize(bitrate: bitrate)
        // A bitrate ceiling does not constrain the encoder's pixel workload.
        // Keep this verified-file HLS route on the same resolution ladder as
        // Jellyfin playback; the 20 Mbps rung otherwise negotiated 1440p.
        let profile = DeviceProfile(codecProfiles: [CodecProfile(codec: "h264", conditions: [
            ProfileCondition(condition: .lessThanEqual, isRequired: true,
                property: .width, value: String(size.width)),
            ProfileCondition(condition: .lessThanEqual, isRequired: true,
                property: .height, value: String(size.height))
        ], type: .video)], maxStreamingBitrate: bitrate,
            name: "Nastart Verified File HLS",
            subtitleProfiles: preferredSubtitleStreamIndex.flatMap { index in
                match.mediaStreams.first { $0.type == .subtitle && $0.index == index }?.codec
            }.map { [SubtitleProfile(format: $0, method: .encode)] },
            transcodingProfiles: [TranscodingProfile(
                protocol: .hls, audioCodec: "aac", container: "ts",
                context: .streaming, isBreakOnNonKeyFrames: true,
                maxAudioChannels: "8", minSegments: 1, segmentLength: 4,
                transcodeSeekInfo: .auto, type: .video, videoCodec: "h264")])
        var request = PlaybackInfoDto(allowAudioStreamCopy: false,
            allowVideoStreamCopy: false, deviceProfile: profile,
            enableDirectPlay: false, enableDirectStream: false,
            enableTranscoding: true, maxStreamingBitrate: bitrate,
            mediaSourceID: match.mediaSourceID,
            startTimeTicks: startSeconds.map { Int(max($0, 0) * 10_000_000) })
        if let preferredAudioStreamIndex {
            request.audioStreamIndex = preferredAudioStreamIndex
            request.subtitleStreamIndex = preferredSubtitleStreamIndex ?? -1
        }
        return request
    }

    private static func stream(for match: Match, bitrate: Int, startSeconds: Double?,
                               playbackTraceID: String, preferredAudioStreamIndex: Int? = nil,
                               preferredSubtitleStreamIndex: Int? = nil) async -> PreparedStream? {
        let request = playbackInfoRequest(for: match, bitrate: bitrate, startSeconds: startSeconds,
            preferredAudioStreamIndex: preferredAudioStreamIndex,
            preferredSubtitleStreamIndex: preferredSubtitleStreamIndex)
        let started = ProcessInfo.processInfo.systemUptime
        let response: PlaybackInfoResponse
        do {
            response = try await match.client.send(Paths.getPostedPlaybackInfo(
                itemID: match.itemID, parameters: nil, request)).value
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "playbackInfoPrepared", "bitrate": String(bitrate),
                          "requestedMaxWidth": String(GreenfieldQualityPolicy.maximumVideoSize(bitrate: bitrate).width),
                          "requestedMaxHeight": String(GreenfieldQualityPolicy.maximumVideoSize(bitrate: bitrate).height),
                          "elapsedMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))])
        } catch {
            let error = error as NSError
            DiagnosticLogStore.shared.record(.warning, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "playbackInfoFailed", "errorDomain": error.domain,
                          "errorCode": String(error.code), "bitrate": String(bitrate),
                          "elapsedMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))])
            return nil
        }
        guard let mediaSource = response.mediaSources?.first(where: { $0.id == match.mediaSourceID }),
              mediaSource.transcodingSubProtocol == .hls,
              let path = mediaSource.transcodingURL,
              let serverURL = match.client.url(path: path),
              var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        else {
            stopEncoding(match: match, playSessionID: response.playSessionID)
            return nil
        }
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.files.jellyfin_original_lookup",
            details: ["result": "negotiatedDimensions", "bitrate": String(bitrate),
                      "maxWidth": queryIndex("MaxWidth", in: serverURL),
                      "maxHeight": queryIndex("MaxHeight", in: serverURL),
                      "playbackTraceID": playbackTraceID])
        if let audio = preferredAudioStreamIndex,
           !negotiatedTracksMatch(url: serverURL, audioIndex: audio, subtitleIndex: preferredSubtitleStreamIndex,
                negotiatedAudioIndex: mediaSource.defaultAudioStreamIndex,
                negotiatedSubtitleIndex: mediaSource.defaultSubtitleStreamIndex) {
            stopEncoding(match: match, playSessionID: response.playSessionID)
            DiagnosticLogStore.shared.record(.warning, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.files.jellyfin_original_lookup",
                details: ["result": "negotiatedTracksRejected", "audioStreamIndex": String(audio),
                          "subtitleStreamIndex": preferredSubtitleStreamIndex.map(String.init) ?? "-1",
                          "returnedAudioIndex": mediaSource.defaultAudioStreamIndex.map(String.init) ?? "none",
                          "returnedSubtitleIndex": mediaSource.defaultSubtitleStreamIndex.map(String.init) ?? "none",
                          "urlAudioIndex": queryIndex("AudioStreamIndex", in: serverURL),
                          "urlSubtitleIndex": queryIndex("SubtitleStreamIndex", in: serverURL),
                          "playbackTraceID": playbackTraceID])
            return nil
        }
        if components.queryItems?.contains(where: {
            $0.name.caseInsensitiveCompare("api_key") == .orderedSame
        }) != true, let token = match.client.accessToken {
            components.queryItems = (components.queryItems ?? []) + [
                URLQueryItem(name: "api_key", value: token)
            ]
        }
        guard let authenticatedURL = components.url else {
            stopEncoding(match: match, playSessionID: response.playSessionID)
            return nil
        }
        guard let proxyURL = try? await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: authenticatedURL, filename: "verified-file.m3u8",
            allowsSelfSignedCertificates: false, playbackTraceID: playbackTraceID,
            jellyfinMediaPath: PlaybackJellyfinOutputDiagnostics.mediaPath(
                path: mediaSource.path, encoderPath: mediaSource.encoderPath,
                hasEncoderProtocol: mediaSource.encoderProtocol != nil)) else {
            stopEncoding(match: match, playSessionID: response.playSessionID)
            return nil
        }
        if startSeconds == nil, PlaybackNetworkObserver.shared.snapshot().cacheKey == "cellular" {
            let started = ProcessInfo.processInfo.systemUptime
            do {
                let warmed = try await AuthenticatedMediaStreamProxy.shared.prewarmVODPlaylist(proxyURL)
                try Task.checkCancellation()
                DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.files.jellyfin_original_lookup",
                    details: ["result": warmed ? "cachedVOD" : "notCacheable",
                              "stage": "cellularVODPlaylistPrewarm",
                              "elapsedMs": String(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))])
            } catch {
                AuthenticatedMediaStreamProxy.shared.unregister(proxyURL)
                stopEncoding(match: match, playSessionID: response.playSessionID)
                let error = error as NSError
                DiagnosticLogStore.shared.record(.warning, categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.files.jellyfin_original_lookup",
                    details: ["result": "playlistPrewarmFailed", "errorDomain": error.domain,
                              "errorCode": String(error.code)])
                return nil
            }
        }
        return PreparedStream(url: proxyURL, playSessionID: response.playSessionID)
    }

    static func playbackRequest(file: FileItem, match: Match, bitrate: Int,
                                startSeconds: Double?, initialPosition: Double?,
                                subtitleURL: URL?, localResumeKey: String?,
                                requestedAt: Date = Date(),
                                preferredAudioStreamIndex: Int? = nil,
                                preferredSubtitleStreamIndex: Int? = nil,
                                availableExternalSubtitleURL: URL? = nil) async -> MediaPlaybackRequest? {
        let traceID = String(UUID().uuidString.prefix(8))
        guard let prepared = await stream(for: match, bitrate: bitrate,
                                          startSeconds: startSeconds, playbackTraceID: traceID,
                                          preferredAudioStreamIndex: preferredAudioStreamIndex,
                                          preferredSubtitleStreamIndex: preferredSubtitleStreamIndex) else { return nil }
        let url = prepared.url
        let tracker = MediaPlaybackTracker(releaseResources: {
            AuthenticatedMediaStreamProxy.shared.unregister(url)
            stopEncoding(match: match, playSessionID: prepared.playSessionID)
        }, eventHandler: { _ in })
        let networkKey = PlaybackNetworkObserver.shared.snapshot().cacheKey
        let hasVerifiedSelection = preferredAudioStreamIndex != nil
        let audioTracks = hasVerifiedSelection ? match.mediaStreams.filter { $0.type == .audio }
            .compactMap { stream -> MediaPlaybackSourceTrack? in
                guard let index = stream.index, index >= 0 else { return nil }
                return .init(id: index, name: stream.displayTitle ?? stream.title ?? stream.language ?? String(index))
            }.sorted { $0.id < $1.id } : []
        let availableSidecar = availableExternalSubtitleURL ?? subtitleURL
        let subtitleTracks = hasVerifiedSelection
            ? subtitleCatalog(match: match, availableExternalSubtitleURL: availableSidecar) : []
        let selectedSubtitle = subtitleURL == nil ? preferredSubtitleStreamIndex : -2
        let trackLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = hasVerifiedSelection ? { audio, subtitle, state in
            let selected = MediaPlaybackRuntimeState(normalizedPosition: state.normalizedPosition,
                positionSeconds: state.positionSeconds, playbackRate: state.playbackRate,
                audioTrackOrdinal: state.audioTrackOrdinal,
                subtitleTrackOrdinal: subtitle == nil ? nil : 0,
                subtitlesDisabled: subtitle == nil, subtitleSelectionKnown: true,
                orientationMode: state.orientationMode,
                sourceAudioStreamIndex: audio ?? state.sourceAudioStreamIndex ?? preferredAudioStreamIndex,
                sourceSubtitleStreamIndex: subtitle == -2 ? nil : subtitle,
                activeExternalSubtitleURL: subtitle == -2 ? availableSidecar : nil)
            return await requestForVerifiedRuntime(file: file, match: match, bitrate: bitrate,
                runtime: selected, localResumeKey: localResumeKey, availableExternalSubtitleURL: availableSidecar)
        } : nil
        let seekLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = hasVerifiedSelection ? { seconds, state in
            await requestForVerifiedRuntime(file: file, match: match, bitrate: bitrate,
                runtime: state, position: seconds, localResumeKey: localResumeKey, availableExternalSubtitleURL: availableSidecar)
        } : nil
        return MediaPlaybackRequest(
            requestedAt: requestedAt, url: url, title: file.name,
            source: .dsmFile, contentKind: .video,
            fileExtensionOverride: "m3u8", initialPosition: initialPosition,
            externalSubtitleURL: subtitleURL,
            prefersSubtitlesDisabled: hasVerifiedSelection && preferredSubtitleStreamIndex == nil && subtitleURL == nil,
            initialOrientationMode: .landscape,
            timelineOffsetSeconds: startSeconds ?? 0,
            timelineDomain: .sourceAbsolute,
            totalDurationSeconds: match.durationSeconds,
            estimatedBitrate: bitrate,
            streamBitrateCeiling: bitrate,
            isPrivateNetworkRoute: false,
            playbackTracker: tracker,
            compatibilityFallbackRequestLoader: { runtime in
                let observed = PlaybackRecentThroughputStore.shared.estimate(
                    traceID: traceID, now: ProcessInfo.processInfo.systemUptime)
                let freshProbe = Date().timeIntervalSince(match.measuredAt) < 30 ? match.measuredCapacity : nil
                let capacity = PlaybackRouteDecisionPolicy.fallbackCapacity(live: observed, route: freshProbe)
                guard let lower = PlaybackAdaptiveBitratePolicy.target(
                    currentCeiling: bitrate, capacity: capacity,
                    networkKey: networkKey) else { return nil }
                if hasVerifiedSelection {
                    guard let runtime else { return nil }
                    return await requestForVerifiedRuntime(file: file, match: match, bitrate: lower,
                        runtime: runtime, localResumeKey: localResumeKey, availableExternalSubtitleURL: availableSidecar)
                }
                guard let replacement = await playbackRequest(file: file, match: match,
                    bitrate: lower, startSeconds: runtime?.positionSeconds,
                    initialPosition: nil, subtitleURL: subtitleURL,
                    localResumeKey: localResumeKey) else { return nil }
                return runtime.map { replacement.applyingRuntimePreferences($0) } ?? replacement
            },
            sourceAudioTracks: audioTracks, sourceSubtitleTracks: subtitleTracks,
            selectedSourceAudioTrackID: preferredAudioStreamIndex,
            selectedSourceSubtitleTrackID: selectedSubtitle,
            sourceTrackRequestLoader: trackLoader, serverSeekRequestLoader: seekLoader,
            selectedQualityID: "auto", playbackTraceID: traceID,
            localResumeKey: localResumeKey)
    }

    static func subtitleCatalog(match: Match, availableExternalSubtitleURL: URL?) -> [MediaPlaybackSourceTrack] {
        var tracks = match.mediaStreams.filter { $0.type == .subtitle && $0.isExternal != true }
            .compactMap { stream -> MediaPlaybackSourceTrack? in
                guard let index = stream.index, index >= 0 else { return nil }
                return .init(id: index, name: stream.displayTitle ?? stream.title ?? stream.language ?? String(index))
            }.sorted { $0.id < $1.id }
        if let url = availableExternalSubtitleURL {
            tracks.append(.init(id: -2, name: NSLocalizedString("player.subtitles.external", comment: ""), externalURL: url))
        }
        return tracks
    }

    private static func requestForVerifiedRuntime(file: FileItem, match: Match, bitrate: Int,
        runtime: MediaPlaybackRuntimeState, position: Double? = nil, localResumeKey: String?,
        availableExternalSubtitleURL: URL?) async -> MediaPlaybackRequest? {
        guard !Task.isCancelled, let seconds = position ?? runtime.positionSeconds,
              seconds.isFinite, seconds >= 0, let tracks = verifiedTracks(match: match, runtime: runtime) else { return nil }
        guard let request = await playbackRequest(file: file, match: match, bitrate: bitrate,
            startSeconds: seconds, initialPosition: nil, subtitleURL: tracks.externalSubtitleURL,
            localResumeKey: localResumeKey, preferredAudioStreamIndex: tracks.audioIndex,
            preferredSubtitleStreamIndex: tracks.subtitleIndex,
            availableExternalSubtitleURL: availableExternalSubtitleURL) else { return nil }
        guard !Task.isCancelled else { request.playbackTracker?.releasePreparedResources(); return nil }
        return request.applyingRuntimePreferences(runtime)
    }

}

private extension Collection {
    var onlyElement: Element? { count == 1 ? first : nil }
}

enum AuthenticatedMediaPlaybackResolver {
    static func recordingIdentityResponseIsValid(_ response: HTTPURLResponse,
                                                 offset: Int64, count: Int, minimumLength: Int64) -> Bool {
        guard response.statusCode == 206,
              isPlayableResponse(response, expectedContentLength: nil, allowsContentGrowth: true),
              let range = MediaRangePolicy.contentRange(from: response.value(forHTTPHeaderField: "Content-Range")),
              range.start == offset, range.bodyLength == Int64(count),
              range.totalLength >= minimumLength else { return false }
        return response.value(forHTTPHeaderField: "Content-Encoding").map {
            $0.caseInsensitiveCompare("identity") == .orderedSame
        } ?? true
    }

    static func recordingIdentityBytes(url: URL, offset: Int64, count: Int,
                                       allowsSelfSignedCertificates: Bool, minimumLength: Int64) async -> Data? {
        guard offset >= 0, count > 0, count <= LocalPlaybackResumeStore.recordingSampleBytes,
              offset <= Int64.max - Int64(count) else { return nil }
        let delegate = FilePreviewTrustDelegate(trustedHost: url.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates && url.scheme?.lowercased() == "https")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 4
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("bytes=\(offset)-\(offset + Int64(count) - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse,
                  recordingIdentityResponseIsValid(response, offset: offset, count: count,
                                                   minimumLength: minimumLength) else { return nil }
            var data = Data()
            data.reserveCapacity(count)
            for try await byte in bytes {
                guard !Task.isCancelled else { return nil }
                data.append(byte)
                if data.count == count { return data }
            }
            return nil
        } catch { return nil }
    }

    static func contentLengthMatches(expected: Int?, actual: Int64?, allowsGrowth: Bool) -> Bool {
        guard let expected, expected > 0, let actual else { return true }
        return allowsGrowth ? actual >= Int64(expected) : actual == Int64(expected)
    }

    static func isPlayableResponse(_ response: HTTPURLResponse,
                                  expectedContentLength: Int?, allowsContentGrowth: Bool) -> Bool {
        let mime = response.mimeType?.lowercased() ?? ""
        return contentLengthMatches(expected: expectedContentLength,
                                    actual: totalContentLength(from: response), allowsGrowth: allowsContentGrowth)
            && (response.statusCode == 200 || response.statusCode == 206)
            && !mime.contains("json") && !mime.contains("html")
    }

    static func firstPlayableURL(
        candidates: [URL],
        allowsSelfSignedCertificates: Bool,
        diagnosticStage: String,
        timeout: TimeInterval = 8,
        expectedContentLength: Int? = nil,
        allowsContentGrowth: Bool = false
    ) async -> URL? {
        let cacheKey = candidates.map(\.absoluteString).joined(separator: "|")
            + "|length=\(expectedContentLength.map(String.init) ?? "unknown")"
            + "|growth=\(allowsContentGrowth)"
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
                        expectedContentLength: expectedContentLength,
                        allowsContentGrowth: allowsContentGrowth
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
        expectedContentLength: Int?,
        allowsContentGrowth: Bool
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
            let contentLengthMatches = Self.contentLengthMatches(expected: expectedContentLength,
                actual: responseContentLength, allowsGrowth: allowsContentGrowth)
            let isMediaResponse = isPlayableResponse(response,
                expectedContentLength: expectedContentLength, allowsContentGrowth: allowsContentGrowth)
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
                    "lengthCheck": contentLengthMatches ? "matchedOrUnavailable" : "mismatch",
                    "allowsContentGrowth": String(allowsContentGrowth),
                    "expectedBytes": expectedContentLength.map(String.init) ?? "-",
                    "responseTotalBytes": responseContentLength.map(String.init) ?? "-"
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

    enum RequestedRange: Equatable {
        case offset(start: Int64, end: Int64?)
        case suffix(Int64)
    }

    static func requestedRange(_ value: String) -> RequestedRange? {
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
        guard let firstRange = rangeText, !firstRange.contains(","),
              let separator = firstRange.firstIndex(of: "-"),
              firstRange.filter({ $0 == "-" }).count == 1 else { return nil }
        func decimal(_ text: Substring) -> Int64? {
            guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
            return Int64(text)
        }
        let startText = firstRange[..<separator]
        let endText = firstRange[firstRange.index(after: separator)...]
        if startText.isEmpty {
            guard let count = decimal(endText), count > 0 else { return nil }
            return .suffix(count)
        }
        guard let start = decimal(startText) else { return nil }
        if endText.isEmpty { return .offset(start: start, end: nil) }
        guard let end = decimal(endText), end >= start else { return nil }
        return .offset(start: start, end: end)
    }

    // A suffix cannot be converted into offsets until the upstream length is
    // known. Never substitute the file head or issue an unbounded suffix read.
    static func boundedRange(_ value: String, maximumLength: Int64 = upstreamWindowBytes,
                             totalLength: Int64? = nil) -> String? {
        guard maximumLength > 0, let range = requestedRange(value) else { return nil }
        let start: Int64
        let requestedEnd: Int64?
        switch range {
        case let .offset(offset, end):
            start = offset
            requestedEnd = end
        case let .suffix(count):
            guard let totalLength, totalLength > 0 else { return nil }
            start = totalLength - min(count, totalLength)
            requestedEnd = totalLength - 1
        }
        if let totalLength, start >= totalLength { return nil }
        let remaining = min(maximumLength - 1, Int64.max - start)
        var end = min(requestedEnd ?? Int64.max, start + remaining)
        if let totalLength { end = min(end, totalLength - 1) }
        return "bytes=\(start)-\(end)"
    }

    static func isOpenEnded(_ value: String) -> Bool {
        if case .offset(_, nil) = requestedRange(value) { return true }
        return false
    }

    /// Resolve the full client interval when a versioned Reader already
    /// knows the length. The serving transport applies finite upstream windows
    /// independently of the client-facing interval.
    static func readerRange(_ value: String?, totalLength: Int64) -> ContentRange? {
        guard totalLength > 0 else { return nil }
        let end = totalLength - 1
        guard let value else { return .init(start: 0, end: end, totalLength: totalLength) }
        switch requestedRange(value) {
        case .offset(let start, let requestedEnd) where start < totalLength:
            return .init(start: start, end: min(end, requestedEnd ?? end), totalLength: totalLength)
        case .suffix(let count):
            return .init(start: totalLength - min(totalLength, count), end: end, totalLength: totalLength)
        default:
            return nil
        }
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

/// Structural HLS evidence only. Do not include URIs, paths or query values.
enum PlaybackHLSRequestDiagnostics {
    static func segmentOrdinal(_ url: URL) -> Int? {
        guard ["ts", "m4s", "mp4", "aac"].contains(url.pathExtension.lowercased()) else { return nil }
        let name = url.deletingPathExtension().lastPathComponent
        guard !name.isEmpty, name.utf8.allSatisfy({ (48...57).contains($0) }),
              let ordinal = Int(name), ordinal >= 0 else { return nil }
        return ordinal
    }

    static func playlistFields(_ playlist: String) -> [String: String] {
        let lines = playlist.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let sequence = lines.first { $0.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") }
            .flatMap { Int($0.dropFirst("#EXT-X-MEDIA-SEQUENCE:".count)) }
        let durations = lines.filter { $0.hasPrefix("#EXTINF:") }.compactMap {
            Double($0.dropFirst(8).split(separator: ",").first ?? "")
        }.filter { $0.isFinite && $0 >= 0 }
        let segments = lines.filter { !$0.isEmpty && !$0.hasPrefix("#") }
        let firstOrdinal = segments.first.flatMap(URL.init(string:)).flatMap(segmentOrdinal)
        let targets = lines.filter { $0.hasPrefix("#EXT-X-TARGETDURATION:") }
        let target = targets.count == 1 ? targets[0].dropFirst("#EXT-X-TARGETDURATION:".count) : ""
        let targetSeconds = !target.isEmpty && target.utf8.allSatisfy({ (48...57).contains($0) })
            ? Int(target).flatMap { $0 > 0 ? $0 : nil } : nil
        // Use the first declared duration, never the next parsable duration.
        // Otherwise a malformed first segment would silently acquire a peer's time.
        let firstDuration = lines.first { $0.hasPrefix("#EXTINF:") }.flatMap {
            Double($0.dropFirst(8).split(separator: ",", omittingEmptySubsequences: false).first ?? "")
        }.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        return [
            "playlistMediaSequence": sequence.map(String.init) ?? "unknown",
            "playlistSegments": String(durations.count),
            "playlistDurationSeconds": String(durations.reduce(0, +)),
            "playlistEndlist": String(lines.contains("#EXT-X-ENDLIST")),
            "playlistFirstSegmentOrdinal": firstOrdinal.map(String.init) ?? "unknown",
            "playlistTargetDurationSeconds": targetSeconds.map(String.init) ?? "unknown",
            "playlistFirstSegmentDurationSeconds": firstDuration.map { String($0) } ?? "unknown"
        ]
    }
}

enum PlaybackHLSStartOffset {
    static func applying(_ seconds: Double?, to playlist: String) -> String {
        guard let seconds, seconds.isFinite, seconds > 0 else { return playlist }
        var lines = playlist.components(separatedBy: "\n")
        let tags = lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        // Only complete, zero-based VOD timelines use absolute media seconds.
        // Live/sliding playlists and master playlists retain server semantics.
        guard tags.contains("#EXTM3U"), tags.contains("#EXT-X-ENDLIST"),
              tags.contains(where: { $0.hasPrefix("#EXTINF:") }),
              !tags.contains(where: { $0.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") && $0 != "#EXT-X-MEDIA-SEQUENCE:0" }) else { return playlist }
        let duration = tags.filter { $0.hasPrefix("#EXTINF:") }.compactMap {
            Double($0.dropFirst(8).split(separator: ",").first ?? "")
        }.reduce(0, +)
        guard duration.isFinite, duration > seconds else { return playlist }
        lines.removeAll { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#EXT-X-START:") }
        lines.insert(String(format: "#EXT-X-START:TIME-OFFSET=%.3f,PRECISE=YES",
                            locale: Locale(identifier: "en_US_POSIX"), seconds), at: 1)
        return lines.joined(separator: "\n")
    }
}

#if DEBUG
/// Process-local test fixture. Only a devicectl launch with all three explicit
/// values can enable it; it never changes the device's cellular configuration.
private final class DebugMediaDeliveryThrottle: @unchecked Sendable {
    static let shared = DebugMediaDeliveryThrottle()

    private let bitsPerSecond: Double
    private let delaySeconds: Double
    private let durationSeconds: Double
    private let lock = NSLock()
    private var firstMediaAt: TimeInterval?
    private var nextDeliveryAt: TimeInterval?
    private var loggedStart = false
    private var loggedEnd = false

    private init() {
        let environment = ProcessInfo.processInfo.environment
        let cap = Double(environment["NASTART_TEST_MEDIA_CAP_BPS"] ?? "") ?? 0
        let delay = Double(environment["NASTART_TEST_MEDIA_DELAY_SECONDS"] ?? "") ?? -1
        let duration = Double(environment["NASTART_TEST_MEDIA_DURATION_SECONDS"] ?? "") ?? -1
        if (1_000_000...50_000_000).contains(cap),
           (5...300).contains(delay), (10...600).contains(duration) {
            bitsPerSecond = cap
            delaySeconds = delay
            durationSeconds = duration
        } else {
            bitsPerSecond = 0
            delaySeconds = 0
            durationSeconds = 0
        }
    }

    func deliveryDelay(bytes: Int, isMedia: Bool) -> TimeInterval {
        guard bitsPerSecond > 0, bytes > 0, isMedia else { return 0 }
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        if firstMediaAt == nil { firstMediaAt = now }
        let age = now - (firstMediaAt ?? now)
        let active = age >= delaySeconds && age < delaySeconds + durationSeconds
        let shouldLogStart = active && !loggedStart
        let shouldLogEnd = age >= delaySeconds + durationSeconds && loggedStart && !loggedEnd
        if shouldLogStart { loggedStart = true }
        if shouldLogEnd {
            loggedEnd = true
            nextDeliveryAt = nil
        }
        let wait: TimeInterval
        if active {
            let deadline = max(now, nextDeliveryAt ?? now) + Double(bytes) * 8 / bitsPerSecond
            nextDeliveryAt = deadline
            wait = deadline - now
        } else {
            wait = 0
        }
        lock.unlock()
        if shouldLogStart || shouldLogEnd {
            DiagnosticLogStore.shared.record(.info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_started",
                details: ["stage": shouldLogStart ? "debugThrottleStarted" : "debugThrottleRestored",
                          "capBps": String(Int(bitsPerSecond)),
                          "elapsedSeconds": String(Int(age))])
        }
        return wait
    }
}
#endif

/// The presentation keeps the capability alive across dismissal for PiP.
final class PlaybackProxyRouteLease {
    let url: URL
    private let release: () -> Void

    convenience init(url: URL) {
        self.init(url: url) { AuthenticatedMediaStreamProxy.shared.unregister(url) }
    }
    init(url: URL, release: @escaping () -> Void) {
        self.url = url
        self.release = release
    }

    deinit { release() }
}

final class AuthenticatedMediaStreamProxy: @unchecked Sendable {
    static let shared = AuthenticatedMediaStreamProxy()

    private enum Upstream: Sendable {
        case http(URL)
        case networkReader(any NetworkMediaByteReader, origin: URL, byteCount: Int64)

        var url: URL {
            switch self {
            case .http(let url): return url
            case .networkReader(_, let origin, _): return origin
            }
        }
        var isHTTP: Bool { if case .http = self { return true }; return false }
    }

    private struct Route {
        let upstream: Upstream
        var upstreamURL: URL { upstream.url }
        let allowsSelfSignedCertificates: Bool
        let filename: String
        let isPlaylist: Bool
        let prefersFiniteRangeResponse: Bool
        let upstreamIsNetworkLibraryBridge: Bool
        let playbackTraceID: String?
        let jellyfinMediaPath: String?
        let localPort: NWEndpoint.Port
        let createdAt: Date
        let pinnedTransport: PlaybackPinnedRouteTransport?
        var playlistStartSeconds: Double? = nil
        let children = PlaybackPlaylistChildren()
        let requestDiagnostics = PlaybackProxyRequestDiagnostics()
        var startupPrimer: PlaybackHLSStartupPrimer?
        var originalReadStarted = false
    }

    private let queue = DispatchQueue(label: "com.nastart.authenticated-media-stream-proxy")
    private var listener: NWListener?
    private var port: NWEndpoint.Port?
    private var routes: [String: Route] = [:]
    private let vodPlaylistCache = PlaybackVODPlaylistCache()
    private var transfers: [UUID: AuthenticatedMediaProxyTransfer] = [:]
    private var readerTransfers: [UUID: NetworkMediaProxyTransfer] = [:]
    private var manifestPreparations: [UUID: (permit: PlaybackStartupPrimerPermit, route: String, port: NWEndpoint.Port)] = [:]
    private var listenerWaiters: [(Result<NWEndpoint.Port, Error>) -> Void] = []
    private var originalPrefixPreparation: (
        route: String, id: UUID, task: Task<PlaybackOriginalStartupPrefix?, Error>
    )?
    private var originalStartupPrefix: (route: String, id: UUID, prefix: PlaybackOriginalStartupPrefix)?
    private var preparedOriginal: (route: String, transferID: UUID, deadline: DispatchTime)?
#if DEBUG
    private struct CandidateSegmentLease {
        let id: UUID
        let route: String
        let port: NWEndpoint.Port
        let segments: Set<URL>
        var used = false
        var transfer: PlaybackCandidateSegmentRetry?
    }
    private var candidateSegmentLease: CandidateSegmentLease?
#endif

    private init() {}

    /// Read-only lookup on this exact route; revoked/other routes stay unknown.
    func diagnosticResource(_ uri: String?, for rootURL: URL) -> [String: String] {
        guard rootURL.host == "127.0.0.1" else { return ["binding": "notLocalProxy"] }
        let parts = rootURL.path.split(separator: "/")
        guard parts.count == 3, parts[0] == "media" else { return ["binding": "invalidRoot"] }
        return queue.sync {
            guard let route = routes[String(parts[1])],
                  rootURL.port == Int(route.localPort.rawValue) else { return ["binding": "routeInactive"] }
            var fields = route.requestDiagnostics.fields(uri: uri)
            fields["proxyPlaybackTraceID"] = PlaybackProxyRequestDiagnostics.safeTrace(route.playbackTraceID)
            return fields
        }
    }

    func unregister(_ url: URL) {
        guard url.host == "127.0.0.1" else { return }
        let parts = url.path.split(separator: "/")
        guard parts.count >= 3, parts[0] == "media" else { return }
        let token = String(parts[1])
        queue.async {
            guard let route = self.routes[token], url.port == Int(route.localPort.rawValue) else { return }
            route.startupPrimer?.cancel()
            route.pinnedTransport?.invalidate()
            self.discardOriginalPrefix(for: token)
            self.discardPreparedOriginal(for: token)
#if DEBUG
            if self.candidateSegmentLease?.route == token { self.cancelCandidateSegmentRetry() }
#endif
            self.routes[token] = nil
            self.vodPlaylistCache.remove(route: token)
            // Removing the URL must also release already accepted readers.
            // Each transfer belongs to this route, even when its upstream
            // transport session is shared with another playing source.
            for transfer in self.transfers.values {
                transfer.cancelIfOwned(byRoute: token, port: route.localPort)
            }
            self.cancelReaderTransfers(for: token, reason: "routeRevoked")
        }
    }

    func setPlaylistStart(_ url: URL, seconds: Double) {
        guard url.host == "127.0.0.1", seconds.isFinite, seconds >= 0 else { return }
        let parts = url.path.split(separator: "/")
        guard parts.count >= 3, parts[0] == "media" else { return }
        queue.sync {
            let token = String(parts[1])
            guard let route = routes[token], route.isPlaylist,
                  url.port == Int(route.localPort.rawValue) else { return }
            if seconds > 0 { route.startupPrimer?.cancel() }
            routes[token]?.playlistStartSeconds = seconds
        }
    }

    /// Candidate preparation may only read a route already owned by this proxy.
    /// A loopback host alone does not identify one of our HLS registrations.
    func isRegisteredPlaylistRoot(_ url: URL) -> Bool {
        guard url.host == "127.0.0.1", url.pathExtension.lowercased() == "m3u8" else { return false }
        let parts = url.path.split(separator: "/")
        guard parts.count == 3, parts[0] == "media" else { return false }
        return queue.sync {
            guard let route = routes[String(parts[1])], route.isPlaylist,
                  url.port == Int(route.localPort.rawValue) else { return false }
            return true
        }
    }

#if DEBUG
    /// Only the warmup of a complete, simple TS candidate can arm this probe.
    /// The first matching decoder GET owns the single global bounded slot.
    func beginCandidateSegmentRetry(_ url: URL) -> UUID? {
        guard url.scheme == "http", url.host == "127.0.0.1", url.query == nil,
              url.fragment == nil, url.user == nil, url.password == nil else { return nil }
        let parts = url.path.split(separator: "/")
        guard parts.count == 3, parts[0] == "media" else { return nil }
        let token = String(parts[1])
        return queue.sync {
            guard candidateSegmentLease == nil, let route = routes[token], route.isPlaylist,
                  port == route.localPort, url.port == Int(route.localPort.rawValue),
                  url.path == "/media/\(token)/\(route.filename)",
                  !route.allowsSelfSignedCertificates || route.upstreamURL.scheme == "http",
                  let (body, mediaURL) = vodPlaylistCache.candidateMedia(route: token, root: route.upstreamURL),
                  let segments = PlaybackCandidateSegmentRetry.segmentURLs(body, mediaURL: mediaURL,
                      root: route.upstreamURL) else { return nil }
            let id = UUID()
            candidateSegmentLease = CandidateSegmentLease(id: id, route: token, port: route.localPort,
                segments: segments)
            return id
        }
    }

    func endCandidateSegmentRetry(_ id: UUID) {
        queue.sync {
            if candidateSegmentLease?.id == id { cancelCandidateSegmentRetry() }
        }
    }

    private func cancelCandidateSegmentRetry() {
        let transfer = candidateSegmentLease?.transfer
        candidateSegmentLease = nil
        transfer?.cancel()
    }
#endif

    /// Both media-library and file-browser originals use the same response
    /// semantics, regardless of initial launch, quality switch, or TLS policy.
    func registerOriginalStream(
        upstreamURL: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool,
        usesGreenfieldPlayback: Bool = true,
        playbackTraceID: String? = nil,
        upstreamIsNetworkLibraryBridge: Bool = false
    ) async throws -> URL {
        try await register(upstreamURL: upstreamURL, filename: filename,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            prefersFiniteRangeResponse: usesGreenfieldPlayback,
            playbackTraceID: playbackTraceID,
            upstreamIsNetworkLibraryBridge: upstreamIsNetworkLibraryBridge)
    }

    func registerNetworkReader(_ reader: any NetworkMediaByteReader, originURL: URL,
                               playbackTraceID: String? = nil) async throws -> URL {
        let byteCount = reader.byteCount
        guard byteCount > 0 else { throw URLError(.badURL) }
        let ext = (reader.fileName as NSString).pathExtension.lowercased()
        let safeExtension = ext.utf8.count <= 12 && ext.utf8.allSatisfy {
            (97...122).contains($0) || (48...57).contains($0)
        } && !ext.isEmpty ? ext : "bin"
        return try await register(upstream: .networkReader(reader, origin: originURL, byteCount: byteCount),
            filename: "video." + safeExtension, allowsSelfSignedCertificates: false,
            prefersFiniteRangeResponse: true, playbackTraceID: playbackTraceID,
            jellyfinMediaPath: nil, upstreamIsNetworkLibraryBridge: false)
    }

    /// Starts the same bounded upstream GET that an unconditional renderer
    /// read from byte zero would start. The caller does not wait for a reply.
    func prepareOriginalResponse(_ url: URL) -> Bool {
        let parts = url.path.split(separator: "/")
        guard url.scheme == "http", url.host == "127.0.0.1", url.query == nil,
              parts.count == 3, parts[0] == "media", !Task.isCancelled else { return false }
        let token = String(parts[1])
        return queue.sync {
            guard let route = routes[token], port == route.localPort,
                  url.port == Int(route.localPort.rawValue),
                  url.path == "/media/\(token)/\(route.filename)",
                  route.upstream.isHTTP, route.prefersFiniteRangeResponse, !route.isPlaylist,
                  !route.originalReadStarted,
                  !route.upstreamIsNetworkLibraryBridge, !route.allowsSelfSignedCertificates,
                  ["http", "https"].contains(route.upstreamURL.scheme?.lowercased() ?? ""),
                  preparedOriginal == nil, originalPrefixPreparation == nil,
                  originalStartupPrefix == nil else { return false }
            let id = UUID()
            let transfer = makeTransfer(id: id, route: route, token: token,
                connection: nil, upstreamURL: route.upstreamURL, method: "GET",
                headers: ["range": "bytes=0-"])
            let deadline = DispatchTime.now() + .seconds(2)
            preparedOriginal = (token, id, deadline)
            transfer.startOriginalPreparation(on: queue)
            queue.asyncAfter(deadline: deadline) {
                guard self.preparedOriginal?.transferID == id else { return }
                self.discardPreparedOriginal(for: token)
            }
            return true
        }
    }

    // Accessed on the proxy queue, which also serializes the prepared transfer.
    private func discardPreparedOriginal(for token: String) {
        guard let slot = preparedOriginal, slot.route == token else { return }
        preparedOriginal = nil
        transfers[slot.transferID]?.abandonOriginalPreparation()
    }

    /// Explicit preparation for the first open-ended original GET. This stage
    /// is opt-in and is independent of the coordinator's observation-only I/O.
    func prepareOriginalStartupPrefix(_ url: URL, byteCount: Int) async throws -> Int {
        let parts = url.path.split(separator: "/")
        guard url.host == "127.0.0.1", url.query == nil, parts.count == 3,
              parts[0] == "media", (1...PlaybackOriginalStartupPrefix.maximumBytes).contains(byteCount) else {
            return 0
        }
        try Task.checkCancellation()
        let token = String(parts[1])
        let id = UUID()
        let task = queue.sync { () -> Task<PlaybackOriginalStartupPrefix?, Error>? in
            guard let route = routes[token], url.port == Int(route.localPort.rawValue),
                  url.path == "/media/\(token)/\(route.filename)",
                  route.upstream.isHTTP, route.prefersFiniteRangeResponse, !route.isPlaylist,
                  !route.upstreamIsNetworkLibraryBridge, !route.allowsSelfSignedCertificates,
                  preparedOriginal == nil, originalPrefixPreparation == nil,
                  originalStartupPrefix == nil else { return nil }
            let task = Task { try await PlaybackOriginalStartupPrefix.fetch(route.upstreamURL, count: byteCount) }
            originalPrefixPreparation = (token, id, task)
            return task
        }
        guard let task else { return 0 }
        defer {
            queue.sync {
                if originalPrefixPreparation?.id == id { originalPrefixPreparation = nil }
            }
        }
        return try await withTaskCancellationHandler {
            let prefix = try await task.value
            try Task.checkCancellation()
            return queue.sync {
                guard !Task.isCancelled, originalPrefixPreparation?.id == id, let prefix else { return 0 }
                originalStartupPrefix = (token, id, prefix)
                queue.asyncAfter(deadline: .now() + .seconds(2)) {
                    if self.originalStartupPrefix?.id == id { self.originalStartupPrefix = nil }
                }
                DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.proxy_transfer_finished", details: [
                        "stage": "originalPrefixPrepared", "bytes": String(prefix.data.count),
                        "playbackTraceID": routes[token]?.playbackTraceID ?? "-",
                        "measurementBoundary": "sourceReadForPreload"
                    ])
                return prefix.data.count
            }
        } onCancel: {
            task.cancel()
            self.queue.async {
                if self.originalPrefixPreparation?.id == id || self.originalStartupPrefix?.id == id {
                    self.discardOriginalPrefix(for: token)
                }
            }
        }
    }

    // Accessed only on the proxy queue.
    private func discardOriginalPrefix(for token: String) {
        if originalPrefixPreparation?.route == token {
            originalPrefixPreparation?.task.cancel()
            originalPrefixPreparation = nil
        }
        if originalStartupPrefix?.route == token { originalStartupPrefix = nil }
    }

    func register(
        upstreamURL: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool,
        prefersFiniteRangeResponse: Bool = false,
        playbackTraceID: String? = nil,
        jellyfinMediaPath: String? = nil,
        upstreamIsNetworkLibraryBridge: Bool = false
    ) async throws -> URL {
        if upstreamIsNetworkLibraryBridge {
            guard upstreamURL.scheme == "http", upstreamURL.host == "127.0.0.1",
                  upstreamURL.port != nil, upstreamURL.user == nil, upstreamURL.password == nil,
                  upstreamURL.query == nil, upstreamURL.fragment == nil else {
                throw URLError(.badURL)
            }
        }
        return try await register(upstream: .http(upstreamURL), filename: filename,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            prefersFiniteRangeResponse: prefersFiniteRangeResponse, playbackTraceID: playbackTraceID,
            jellyfinMediaPath: jellyfinMediaPath, upstreamIsNetworkLibraryBridge: upstreamIsNetworkLibraryBridge)
    }

    private func register(upstream: Upstream, filename: String, allowsSelfSignedCertificates: Bool,
                          prefersFiniteRangeResponse: Bool, playbackTraceID: String?, jellyfinMediaPath: String?,
                          upstreamIsNetworkLibraryBridge: Bool) async throws -> URL {
        let port = try await healthyListenerPort()
        try Task.checkCancellation()
        let token = UUID().uuidString.lowercased()
        let safeFilename = filename
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "\\", with: "_")
        var components = URLComponents()
        components.scheme = "http"
        components.host = "127.0.0.1"
        components.port = Int(port.rawValue)
        components.path = "/media/\(token)/\(safeFilename)"
        guard let url = components.url else { throw URLError(.badURL) }
        let registered = await withCheckedContinuation { continuation in
            queue.async {
                guard self.port == port else { continuation.resume(returning: false); return }
                let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
                for (expired, route) in self.routes where route.createdAt <= cutoff {
                    route.startupPrimer?.cancel()
                    route.pinnedTransport?.invalidate()
                    self.discardOriginalPrefix(for: expired)
                    self.discardPreparedOriginal(for: expired)
#if DEBUG
                    if self.candidateSegmentLease?.route == expired { self.cancelCandidateSegmentRetry() }
#endif
                    self.cancelReaderTransfers(for: expired, reason: "routeExpired")
                    self.vodPlaylistCache.remove(route: expired)
                }
                self.routes = self.routes.filter { $0.value.createdAt > cutoff }
                self.routes[token] = Route(
                    upstream: upstream,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                    filename: safeFilename,
                    isPlaylist: upstream.isHTTP && !upstreamIsNetworkLibraryBridge && upstream.url.pathExtension.lowercased() == "m3u8",
                    prefersFiniteRangeResponse: prefersFiniteRangeResponse,
                    upstreamIsNetworkLibraryBridge: upstreamIsNetworkLibraryBridge,
                    playbackTraceID: playbackTraceID?.isEmpty == false ? playbackTraceID : nil,
                    jellyfinMediaPath: jellyfinMediaPath,
                    localPort: port,
                    createdAt: Date(),
                    pinnedTransport: allowsSelfSignedCertificates
                        ? PlaybackPinnedRouteTransport(upstreamURL: upstream.url) : nil
                )
                continuation.resume(returning: true)
            }
        }
        guard registered else { throw URLError(.cannotConnectToHost) }
        if Task.isCancelled {
            unregister(url)
            throw CancellationError()
        }
        return url
    }

    private func cancelReaderTransfers(for token: String, reason: String) {
        for transfer in readerTransfers.values where transfer.routeToken == token { transfer.cancel(reason) }
    }

    private func revokeReaderRoutes(on port: NWEndpoint.Port?) {
        guard let port else { return }
        let tokens = routes.compactMap { token, route in !route.upstream.isHTTP && route.localPort == port ? token : nil }
        for token in tokens {
            routes[token] = nil
            cancelReaderTransfers(for: token, reason: "listenerInvalidated")
        }
    }

    /// Slow cellular manifests can exceed AVFoundation's initial resource wait.
    /// Fetch text before creating the decoder; its subsequent VOD read is local.
    /// Optional from-head priming only starts after complete VOD validation.
    /// It never waits for segment generation on the preparation return path.
    func prewarmVODPlaylist(_ url: URL, primesFirstSegment: Bool = false) async throws -> Bool {
        try Task.checkCancellation()
        guard url.host == "127.0.0.1" else { return false }
        let permit = PlaybackStartupPrimerPermit()
        let preparationID = UUID()
        let registered = queue.sync { () -> Bool in
            let parts = url.path.split(separator: "/")
            guard parts.count == 3, parts[0] == "media", let route = routes[String(parts[1])],
                  route.isPlaylist, url.port == Int(route.localPort.rawValue) else { return false }
            manifestPreparations[preparationID] = (permit, String(parts[1]), route.localPort)
            return true
        }
        guard registered else { return false }
        defer { queue.sync { _ = manifestPreparations.removeValue(forKey: preparationID) } }
        do { return try await withTaskCancellationHandler(operation: {
            try await withThrowingTaskGroup(of: Bool.self) { group in
                group.addTask { try await self.loadVODPlaylist(url, primesFirstSegment: primesFirstSegment,
                    permit: permit, preparationID: preparationID) }
                group.addTask {
                    try await Task.sleep(nanoseconds: 35_000_000_000)
                    throw URLError(.timedOut)
                }
                defer { group.cancelAll() }
                return try await group.next() ?? false
            }
        }, onCancel: {
            permit.cancel()
            guard primesFirstSegment else { return }
            let parts = url.path.split(separator: "/")
            guard parts.count >= 3, parts[0] == "media" else { return }
            let token = String(parts[1])
            self.queue.async {
                guard let route = self.routes[token], url.port == Int(route.localPort.rawValue) else { return }
                route.startupPrimer?.cancel()
            }
        }) } catch {
            // The local reader closing is not proof that its proxy upstream
            // stopped. Cancel only the transfers attached to this preparation.
            permit.cancel()
            throw error
        }
    }

    private func hasCachedVOD(_ url: URL) -> Bool {
        let parts = url.path.split(separator: "/")
        guard parts.count >= 3, parts[0] == "media" else { return false }
        return queue.sync {
            let token = String(parts[1])
            guard let route = routes[token], url.port == Int(route.localPort.rawValue) else { return false }
            let upstream = parts.count == 4 && parts[2] == "child"
                ? route.children.url(for: String(parts[3])) : route.upstreamURL
            return upstream.flatMap { vodPlaylistCache.data(route: token, url: $0) } != nil
        }
    }

    private func loadVODPlaylist(_ url: URL, primesFirstSegment: Bool, permit: PlaybackStartupPrimerPermit,
                                preparationID: UUID) async throws -> Bool {
        let configuration = URLSessionConfiguration.ephemeral
        // The proxy buffers a complete manifest before sending its headers.
        // Use the enclosing 35-second prewarm deadline, rather than expiring
        // an otherwise progressing child manifest at 30 seconds.
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 35
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = ["X-Nastart-Manifest-Preparation": preparationID.uuidString]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let (root, response) = try await session.data(from: url)
        try Task.checkCancellation()
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: root, encoding: .utf8), text.hasPrefix("#EXTM3U") else {
            throw URLError(.cannotParseResponse)
        }
        if text.components(separatedBy: .newlines).contains("#EXT-X-ENDLIST") {
            let cached = hasCachedVOD(url)
            if cached && primesFirstSegment { startStartupPrimer(text: text, playlistURL: url, permit: permit) }
            return cached
        }
        guard text.contains("#EXT-X-STREAM-INF:"),
              let child = text.components(separatedBy: .newlines)
                .map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty && !$0.hasPrefix("#") }).flatMap(URL.init(string:)),
              child.scheme == url.scheme, child.host == url.host, child.port == url.port,
              child.path.hasPrefix(url.deletingLastPathComponent().path + "/child/") else { return false }
        let (childData, childResponse) = try await session.data(from: child)
        try Task.checkCancellation()
        guard (childResponse as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let cached = hasCachedVOD(child)
        if cached && primesFirstSegment, let text = String(data: childData, encoding: .utf8) {
            startStartupPrimer(text: text, playlistURL: child, permit: permit)
        }
        return cached
    }

    private func startStartupPrimer(text: String, playlistURL: URL, permit: PlaybackStartupPrimerPermit) {
        guard !Task.isCancelled,
              let local = PlaybackHLSStartupPrimerPolicy.candidate(in: text, playlistURL: playlistURL) else { return }
        let parts = local.path.split(separator: "/")
        guard parts.count == 4, parts[0] == "media", parts[2] == "child" else { return }
        queue.sync {
            let token = String(parts[1])
            guard permit.isActive, let route = routes[token], local.port == Int(route.localPort.rawValue),
                  route.startupPrimer == nil, (route.playlistStartSeconds ?? 0) == 0,
                  route.jellyfinMediaPath != nil,
                  let upstream = route.children.url(for: String(parts[3])),
                  upstream.scheme == route.upstreamURL.scheme, upstream.host == route.upstreamURL.host,
                  upstream.port == route.upstreamURL.port,
                  PlaybackHLSRequestDiagnostics.segmentOrdinal(upstream) == 0 else { return }
            let localPort = route.localPort
            let primer = PlaybackHLSStartupPrimer(url: local, traceID: route.playbackTraceID) { [weak self] in
                self?.queue.async { [weak self] in
                    guard let self else { return }
                    for transfer in self.transfers.values {
                        transfer.cancelStartupPrimerIfOwned(byRoute: token, port: localPort)
                    }
                }
            }
            routes[token]?.startupPrimer = primer
            primer.start()
        }
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

    /// A listener can retain its last ready port after an iOS network or app
    /// lifecycle transition even though new loopback requests no longer reach
    /// the proxy. Verify the HTTP handler before handing its URL to FFmpeg.
    private func healthyListenerPort() async throws -> NWEndpoint.Port {
        try Task.checkCancellation()
        let firstPort = try await listenerPort()
        let firstHealthy = await respondsOnLoopback(firstPort)
        try Task.checkCancellation()
        if firstHealthy { return firstPort }
        DiagnosticLogStore.shared.record(.warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_listener_restarting",
            details: ["port": String(firstPort.rawValue)])
        await invalidateListener(ifUsing: firstPort)
        let replacementPort = try await listenerPort()
        let replacementHealthy = await respondsOnLoopback(replacementPort)
        try Task.checkCancellation()
        guard replacementHealthy else {
            await invalidateListener(ifUsing: replacementPort)
            throw URLError(.cannotConnectToHost)
        }
        return replacementPort
    }

    private func respondsOnLoopback(_ port: NWEndpoint.Port) async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:\(port.rawValue)/health") else {
            return false
        }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 1.5
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return response is HTTPURLResponse
        } catch {
            return false
        }
    }

    private func invalidateListener(ifUsing stalePort: NWEndpoint.Port) async {
        await withCheckedContinuation { continuation in
            queue.async {
                if self.port?.rawValue == stalePort.rawValue {
                    if let slot = self.preparedOriginal { self.discardPreparedOriginal(for: slot.route) }
#if DEBUG
                    if self.candidateSegmentLease?.port == stalePort { self.cancelCandidateSegmentRetry() }
#endif
                    self.revokeReaderRoutes(on: stalePort)
                    self.listener?.cancel()
                    self.listener = nil
                    self.port = nil
                }
                continuation.resume()
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
                guard let self, self.listener === listener else { return }
                switch state {
                case .ready:
                    guard let port = listener?.port else {
                        self.failListener(URLError(.cannotCreateFile))
                        return
                    }
                    self.port = port
                    DiagnosticLogStore.shared.record(.info,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.proxy_listener_ready",
                        details: ["port": String(port.rawValue)])
                    let waiters = self.listenerWaiters
                    self.listenerWaiters.removeAll()
                    waiters.forEach { $0(.success(port)) }
                case .failed(let error):
                    DiagnosticLogStore.shared.record(.warning,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.proxy_listener_failed",
                        details: ["state": "failed", "error": String(describing: error)])
                    self.failListener(error)
                case .waiting(let error):
                    DiagnosticLogStore.shared.record(.warning,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.proxy_listener_failed",
                        details: ["state": "waiting", "error": String(describing: error)])
                    self.failListener(error)
                case .cancelled:
                    self.failListener(URLError(.cannotConnectToHost))
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
        if let slot = preparedOriginal { discardPreparedOriginal(for: slot.route) }
#if DEBUG
        cancelCandidateSegmentRetry()
#endif
        revokeReaderRoutes(on: port)
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
                self.handleRequest(requestData, on: connection,
                    initialReadComplete: isComplete, initialReadError: error)
                return
            }
            if error != nil || isComplete || requestData.count > 64 * 1024 {
                self.sendError(400, on: connection)
                return
            }
            self.receiveRequest(on: connection, buffer: requestData)
        }
    }

    private func handleRequest(_ data: Data, on connection: NWConnection,
                               initialReadComplete: Bool, initialReadError: NWError?) {
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
            DiagnosticLogStore.shared.record(.warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_request_rejected",
                details: ["reason": "missingRoute", "routeCount": String(routes.count)])
            sendError(404, on: connection)
            return
        }
        var headers: [String: String] = [:]
        var repeatedReaderHeader = false
#if DEBUG
        var repeatedCandidateSessionHeader = false
#endif
        for line in header.components(separatedBy: "\r\n").dropFirst() {
            if line.isEmpty { break }
            guard let separator = line.firstIndex(of: ":") else { continue }
            let key = line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            if headers.updateValue(value, forKey: key) != nil {
                if ["range", "if-range", "content-length", "transfer-encoding"].contains(key) {
                    repeatedReaderHeader = true
                }
#if DEBUG
                if key == "x-playback-session-id" { repeatedCandidateSessionHeader = true }
#endif
            }
        }
        if case let .networkReader(reader, origin, byteCount) = route.upstream {
            guard let requestComponents, requestTarget.hasPrefix("/"), requestComponents.query == nil,
                  requestComponents.fragment == nil, path == "/media/\(token)/\(route.filename)" else {
                sendError(404, on: connection); return
            }
            guard initialReadError == nil, data.count <= 16 * 1024,
                  !repeatedReaderHeader, headers["transfer-encoding"] == nil,
                  ["HTTP/1.0", "HTTP/1.1"].contains(requestParts[2]),
                  headers["content-length"].map({ $0 == "0" }) ?? true,
                  data.range(of: Data([13, 10, 13, 10]))?.upperBound == data.endIndex else {
                sendError(400, on: connection); return
            }
            // This local capability does not advertise a validator. An
            // If-Range supplied by the decoder therefore cannot match it.
            let range = headers["if-range"] == nil ? headers["range"] : nil
            guard let interval = MediaRangePolicy.readerRange(range, totalLength: byteCount) else {
                sendError(416, on: connection, extraHeaders: "Content-Range: bytes */\(byteCount)\r\n")
                return
            }
            guard readerTransfers.values.lazy.filter({ $0.routeToken == token }).prefix(4).count < 4 else {
                sendError(503, on: connection, extraHeaders: "Retry-After: 1\r\n")
                return
            }
            let id = UUID()
            if let localURL = URL(string: "http://127.0.0.1:\(route.localPort.rawValue)\(requestTarget)") {
                route.requestDiagnostics.record(localURL: localURL, upstreamURL: origin, transferID: id, childID: nil)
            }
            let transfer = NetworkMediaProxyTransfer(queue: queue, connection: connection,
                routeToken: token, reader: reader, interval: interval, partial: range != nil,
                head: requestParts[0] == "HEAD", traceID: route.playbackTraceID, id: id) { [weak self] in
                    self?.readerTransfers[id] = nil
                }
            readerTransfers[id] = transfer
            transfer.start(watchClient: !initialReadComplete)
            return
        }
        let requestedUpstreamURL: URL
        if route.upstreamIsNetworkLibraryBridge {
            guard path == "/media/\(token)/\(route.filename)", requestComponents?.percentEncodedQuery == nil else {
                sendError(404, on: connection)
                return
            }
            requestedUpstreamURL = route.upstreamURL
        } else if pathParts.count == 4, pathParts[2] == "child" {
            guard let child = route.children.url(for: String(pathParts[3])) else {
                sendError(404, on: connection)
                return
            }
            requestedUpstreamURL = child
        } else if let redirected = requestComponents?.queryItems?.first(where: {
            $0.name.caseInsensitiveCompare("u") == .orderedSame
        })?.value,
           let redirectedURL = URL(string: redirected),
           ["http", "https"].contains(redirectedURL.scheme?.lowercased() ?? "") {
            requestedUpstreamURL = redirectedURL
        } else {
            requestedUpstreamURL = route.upstreamURL
        }
        var manifestPermit: PlaybackStartupPrimerPermit?
        if let identity = headers["x-nastart-manifest-preparation"] {
            guard requestParts[0] == "GET", requestedUpstreamURL.pathExtension.lowercased() == "m3u8",
                  let id = UUID(uuidString: identity), let preparation = manifestPreparations[id],
                  preparation.route == token, preparation.port == route.localPort,
                  preparation.permit.isActive else { sendError(410, on: connection); return }
            manifestPermit = preparation.permit
        }

        let isStartupPrimer = headers["x-nastart-startup-primer"] == "1"
        if isStartupPrimer && (requestParts[0] != "GET" || headers["range"] != "bytes=0-0"
            || pathParts.count != 4 || pathParts[2] != "child") {
            sendError(400, on: connection); return
        }
        if isStartupPrimer && (route.startupPrimer?.isActive != true || (route.playlistStartSeconds ?? 0) > 0) {
            sendError(410, on: connection); return
        }
        let childID = pathParts.count == 4 && pathParts[2] == "child" ? String(pathParts[3]) : nil
#if DEBUG
        let clientSession = headers["x-playback-session-id"]
        let validClientSession = !repeatedCandidateSessionHeader && (clientSession.map {
            !$0.isEmpty && $0.utf8.count <= 128 && $0.utf8.allSatisfy { byte in
                (48...57).contains(byte) || (65...90).contains(byte) || (97...122).contains(byte)
                    || byte == 45 || byte == 95
            }
        } ?? true)
        let hasOtherPrivateHeader = headers.keys.contains { key in
            key.hasPrefix("if-") || (key.hasPrefix("x-") && key != "x-playback-session-id")
                || ["authorization", "cookie", "range", "transfer-encoding"].contains(key)
        }
        if let lease = candidateSegmentLease, lease.route == token, lease.port == route.localPort,
           lease.segments.contains(requestedUpstreamURL),
           let childID, path == "/media/\(token)/child/\(childID)", requestTarget == path,
           requestParts[0] == "GET", ["HTTP/1.0", "HTTP/1.1"].contains(requestParts[2]),
           initialReadError == nil, data.count <= 16 * 1024, !repeatedReaderHeader, headers["content-length"] == nil,
           data.range(of: Data([13, 10, 13, 10]))?.upperBound == data.endIndex,
           validClientSession, !hasOtherPrivateHeader {
            let fallback: () -> Void = { [weak self] in
                self?.handleRequest(data, on: connection,
                    initialReadComplete: initialReadComplete, initialReadError: initialReadError)
            }
            if let transfer = lease.transfer,
               transfer.join(connection, url: requestedUpstreamURL, clientSession: clientSession,
                   fallback: fallback) { return }
            if !lease.used {
                let transfer = PlaybackCandidateSegmentRetry(url: requestedUpstreamURL,
                    clientSession: clientSession, queue: queue, trace: route.playbackTraceID) { [weak self] in
                        if self?.candidateSegmentLease?.id == lease.id {
                            self?.candidateSegmentLease?.transfer = nil
                        }
                    }
                candidateSegmentLease?.used = true
                candidateSegmentLease?.transfer = transfer
                if transfer.join(connection, url: requestedUpstreamURL, clientSession: clientSession, fallback: fallback) {
                    transfer.start()
                    return
                }
            }
        } else if let lease = candidateSegmentLease, lease.route == token, !lease.used,
                  childID != nil, requestedUpstreamURL.pathExtension.lowercased() == "ts" {
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_started", details: [
                    "stage": "candidateSegmentProbeBypassed",
                    "playbackTraceID": PlaybackProxyRequestDiagnostics.safeTrace(route.playbackTraceID),
                    "manifestMember": String(lease.segments.contains(requestedUpstreamURL)),
                    "clientSessionValid": String(validClientSession),
                    "clientSessionPresent": String(clientSession != nil),
                    "otherPrivateHeader": String(hasOtherPrivateHeader),
                    "rangePresent": String(headers["range"] != nil),
                    "contentLengthPresent": String(headers["content-length"] != nil),
                    "requestIsExact": String(requestTarget == path),
                    "requestFramingComplete": String(data.range(of: Data([13, 10, 13, 10]))?.upperBound == data.endIndex)
                ])
        }
#endif
        let originalRootGET = route.prefersFiniteRangeResponse && !route.isPlaylist && requestParts[0] == "GET"
            && path == "/media/\(token)/\(route.filename)"
        let originalGET = originalRootGET && requestComponents?.percentEncodedQuery == nil
        let requestedRange = MediaRangePolicy.requestedRange(headers["range"] ?? "bytes=0-")
        if originalRootGET, requestedRange != nil {
            routes[token]?.originalReadStarted = true
        }
        let canAdoptOriginal = requestedRange == .offset(start: 0, end: nil)
            && !headers.keys.contains { $0.hasPrefix("if-") || $0.hasPrefix("x-nastart-")
                || ["authorization", "cookie", "x-emby-token"].contains($0) }
        if originalRootGET, let slot = preparedOriginal, slot.route == token {
            if originalGET, canAdoptOriginal, DispatchTime.now() < slot.deadline,
               let transfer = transfers[slot.transferID],
               transfer.adoptOriginalPreparation(connection, initialReadComplete: initialReadComplete,
                                                 initialReadError: initialReadError) {
                preparedOriginal = nil
                if let localURL = URL(string: "http://127.0.0.1:\(route.localPort.rawValue)\(requestTarget)") {
                    route.requestDiagnostics.record(localURL: localURL, upstreamURL: requestedUpstreamURL,
                        transferID: slot.transferID, childID: nil)
                }
                return
            }
            if requestedRange != nil { discardPreparedOriginal(for: token) }
        }
        let transferID = UUID()
        if let localURL = URL(string: "http://127.0.0.1:\(route.localPort.rawValue)\(requestTarget)") {
            route.requestDiagnostics.record(localURL: localURL, upstreamURL: requestedUpstreamURL,
                transferID: transferID, childID: childID)
        }
        var originalPrefix: PlaybackOriginalStartupPrefix?
        if originalGET, requestedRange == .offset(start: 0, end: nil) {
            if originalStartupPrefix?.route == token,
               !headers.keys.contains(where: { $0.hasPrefix("if-") || $0 == "authorization" || $0 == "cookie" }) {
                originalPrefix = originalStartupPrefix?.prefix
            }
            discardOriginalPrefix(for: token)
        }
        let transfer = makeTransfer(id: transferID, route: route, token: token,
            connection: connection, upstreamURL: requestedUpstreamURL, method: requestParts[0],
            headers: headers, childID: childID, isStartupPrimer: isStartupPrimer, originalPrefix: originalPrefix)
        if let manifestPermit, !manifestPermit.registerCancellation({ [weak self, weak transfer] in
            self?.queue.async { transfer?.cancelManifestPreparation() }
        }) {
            transfers[transferID] = nil
            sendError(410, on: connection)
            return
        }
        transfer.start(initialReadComplete: initialReadComplete, initialReadError: initialReadError)
    }

    private func makeTransfer(id: UUID, route: Route, token: String, connection: NWConnection?,
                              upstreamURL: URL, method: String, headers: [String: String],
                              childID: String? = nil, isStartupPrimer: Bool = false,
                              originalPrefix: PlaybackOriginalStartupPrefix? = nil) -> AuthenticatedMediaProxyTransfer {
        let transfer = AuthenticatedMediaProxyTransfer(
            connection: connection, upstreamURL: upstreamURL, method: method, requestHeaders: headers,
            diagnosticTransferID: id, isStartupPrimer: isStartupPrimer, originalPrefix: originalPrefix,
            allowsSelfSignedCertificates: route.allowsSelfSignedCertificates,
            pinnedTransport: route.pinnedTransport,
            prefersFiniteRangeResponse: route.prefersFiniteRangeResponse,
            upstreamIsNetworkLibraryBridge: route.upstreamIsNetworkLibraryBridge,
            isPlaylist: route.isPlaylist
                && upstreamURL.pathExtension.lowercased() == "m3u8",
            isHLSChildRequest: route.isPlaylist
                && upstreamURL.pathExtension.lowercased() != "m3u8",
            playbackTraceID: route.playbackTraceID,
            jellyfinMediaPath: route.jellyfinMediaPath,
            playlistToken: token,
            playlistFilename: route.filename,
            playlistPort: route.localPort,
            playlistStartSeconds: route.playlistStartSeconds,
            playlistChildren: route.children,
            vodPlaylistCache: vodPlaylistCache,
            playlistChildID: childID
        ) { [weak self] in
            self?.queue.async {
                self?.transfers[id] = nil
                if self?.preparedOriginal?.transferID == id { self?.preparedOriginal = nil }
            }
        }
        transfers[id] = transfer
        return transfer
    }

    private func sendError(_ statusCode: Int, on connection: NWConnection, extraHeaders: String = "") {
        let reason = HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
        let response = "HTTP/1.1 \(statusCode) \(reason)\r\n\(extraHeaders)Content-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

/// Low-frequency timing for one Reader-backed local Range response. Each
/// delivered chunk splits its interval into waiting for the Reader to return
/// the chunk and waiting for the local player socket to accept it. Times use
/// monotonic system uptime. This is local delivery evidence only: it carries
/// no URL, account, path or payload and is not an upstream throughput sample.
struct NetworkMediaProxyTransferTimeline: Equatable, Sendable {
    enum Phase: String, Sendable { case reader, consumer }

    struct Summary: Equatable, Sendable {
        var startedAt: TimeInterval
        var endedAt: TimeInterval
        var chunks = 0
        var bytes: Int64 = 0
        var firstOffset: Int64?
        var endOffset: Int64?
        var readerWait: TimeInterval = 0
        var consumerWait: TimeInterval = 0
        var maxReaderWait: TimeInterval = 0
        var maxConsumerWait: TimeInterval = 0
        var pending: Phase?
        var pendingWait: TimeInterval = 0
        // Inside the Reader wait, for a Reader that reports it: how long its
        // reads queued behind an earlier read on the same connection, and how
        // long they spent on that connection. The rest of the Reader wait is
        // scheduling between the two.
        var readerReads = 0
        var readerQueueWait: TimeInterval = 0
        var readerReadTime: TimeInterval = 0
        var maxReaderQueueWait: TimeInterval = 0
        var maxReaderReadTime: TimeInterval = 0

        var wall: TimeInterval { max(0, endedAt - startedAt) }

        /// The side that held this window. A side must cover at least half
        /// the window and twice the other side's wait to be named alone.
        var dominantWait: String {
            let wall = max(self.wall, 0.001)
            if readerWait + consumerWait < wall * 0.5 { return "unattributed" }
            if readerWait >= wall * 0.5, readerWait >= consumerWait * 2 { return "reader" }
            if consumerWait >= wall * 0.5, consumerWait >= readerWait * 2 { return "consumer" }
            return "mixed"
        }

        func fields() -> [String: String] {
            func ms(_ value: TimeInterval) -> String { String(Int((value * 1000).rounded())) }
            var fields = [
                "windowStartUptimeMs": ms(startedAt), "windowEndUptimeMs": ms(endedAt),
                "windowMs": ms(wall), "chunks": "\(chunks)", "windowBytes": "\(bytes)",
                "readerWaitMs": ms(readerWait), "consumerWaitMs": ms(consumerWait),
                "maxReaderWaitMs": ms(maxReaderWait), "maxConsumerWaitMs": ms(maxConsumerWait),
                "dominantWait": dominantWait,
                "deliveredOffsets": firstOffset.flatMap { start in
                    endOffset.map { "\(start)-\($0 - 1)" }
                } ?? "none"
            ]
            if let pending {
                fields["pendingWait"] = pending.rawValue
                fields["pendingWaitMs"] = ms(pendingWait)
            }
            if readerReads > 0 {
                fields["readerReads"] = "\(readerReads)"
                fields["readerQueueWaitMs"] = ms(readerQueueWait)
                fields["readerReadMs"] = ms(readerReadTime)
                fields["maxReaderQueueWaitMs"] = ms(maxReaderQueueWait)
                fields["maxReaderReadMs"] = ms(maxReaderReadTime)
            }
            return fields
        }

        mutating func add(_ timing: NetworkMediaReadTimingRecorder.Summary?) {
            guard let timing, timing.reads > 0 else { return }
            readerReads += timing.reads
            readerQueueWait += timing.queueWait
            readerReadTime += timing.readTime
            maxReaderQueueWait = max(maxReaderQueueWait, timing.maxQueueWait)
            maxReaderReadTime = max(maxReaderReadTime, timing.maxReadTime)
        }

        mutating func add(offset: Int64, bytes count: Int, readerWait: TimeInterval,
                          consumerWait: TimeInterval, now: TimeInterval) {
            chunks += 1
            bytes += Int64(count)
            if firstOffset == nil { firstOffset = offset }
            endOffset = offset + Int64(count)
            self.readerWait += readerWait
            self.consumerWait += consumerWait
            maxReaderWait = max(maxReaderWait, readerWait)
            maxConsumerWait = max(maxConsumerWait, consumerWait)
            endedAt = now
        }

        mutating func close(pending phase: Phase?, wait: TimeInterval, now: TimeInterval) {
            if let phase, wait > 0 {
                pending = phase
                pendingWait = wait
                switch phase {
                case .reader:
                    readerWait += wait; maxReaderWait = max(maxReaderWait, wait)
                case .consumer:
                    consumerWait += wait; maxConsumerWait = max(maxConsumerWait, wait)
                }
            }
            endedAt = max(endedAt, now)
        }
    }

    let reportInterval: TimeInterval
    private(set) var window: Summary
    private(set) var total: Summary

    init(startedAt: TimeInterval, reportInterval: TimeInterval = 1) {
        self.reportInterval = reportInterval
        window = Summary(startedAt: startedAt, endedAt: startedAt)
        total = Summary(startedAt: startedAt, endedAt: startedAt)
    }

    /// Adds one delivered chunk and returns the closed window once it spans
    /// the report interval. A long single wait closes in one window.
    /// `readTiming` is what the Reader reported for the reads behind this chunk.
    mutating func record(offset: Int64, bytes: Int, readerWait: TimeInterval,
                         consumerWait: TimeInterval, now: TimeInterval,
                         readTiming: NetworkMediaReadTimingRecorder.Summary? = nil) -> Summary? {
        window.add(offset: offset, bytes: bytes, readerWait: readerWait,
                   consumerWait: consumerWait, now: now)
        total.add(offset: offset, bytes: bytes, readerWait: readerWait,
                  consumerWait: consumerWait, now: now)
        window.add(readTiming)
        total.add(readTiming)
        guard now - window.startedAt >= reportInterval else { return nil }
        let closed = window
        window = Summary(startedAt: now, endedAt: now)
        return closed
    }

    /// Closes the open window and the transfer total. An unfinished wait at
    /// termination is charged to the phase that was still waiting.
    /// `readTiming` is a read the Reader finished without delivering a chunk:
    /// one that failed, or one the transfer no longer wanted.
    mutating func finish(pending phase: Phase?, wait: TimeInterval, now: TimeInterval,
                         readTiming: NetworkMediaReadTimingRecorder.Summary? = nil)
        -> (window: Summary?, total: Summary) {
        window.close(pending: phase, wait: wait, now: now)
        total.close(pending: phase, wait: wait, now: now)
        window.add(readTiming)
        total.add(readTiming)
        let open = window.chunks > 0 || window.pending != nil || window.readerReads > 0 ? window : nil
        window = Summary(startedAt: now, endedAt: now)
        return (open, total)
    }
}

/// Reader credentials and version validation stay in NetworkMedia. The local
/// transport sends one chunk at a time; a slow client naturally delays reads.
/// Lifecycle, socket operations and the pending send live on the proxy queue.
private final class NetworkMediaProxyTransfer: @unchecked Sendable {
    let routeToken: String
    private let queue: DispatchQueue
    private let connection: NWConnection
    private let reader: any NetworkMediaByteReader
    private let interval: MediaRangePolicy.ContentRange
    private let partial: Bool
    private let head: Bool
    private let traceID: String?
    private let id: UUID
    private let onFinish: () -> Void
    private var task: Task<Void, Never>?
    private var idle: DispatchWorkItem?
    private var pendingSend: (UUID, CheckedContinuation<Void, Error>)?
    private var cancellation: String?

    init(queue: DispatchQueue, connection: NWConnection, routeToken: String,
         reader: any NetworkMediaByteReader, interval: MediaRangePolicy.ContentRange,
         partial: Bool, head: Bool, traceID: String?, id: UUID, onFinish: @escaping () -> Void) {
        self.queue = queue; self.connection = connection; self.routeToken = routeToken
        self.reader = reader; self.interval = interval; self.partial = partial; self.head = head
        self.traceID = traceID; self.id = id; self.onFinish = onFinish
    }

    func start(watchClient: Bool) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.cancel("clientDisconnected")
            default: break
            }
        }
        if watchClient {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1) { [weak self] data, _, _, error in
                // A client may half-close its write direction and still
                // consume the entire response. Only errors or a second
                // request (unsupported on this socket) stop the transfer.
                if error != nil || data?.isEmpty == false { self?.cancel("clientDisconnected") }
            }
        }
        touch()
        task = Task { [self] in await run() }
    }

    func cancel(_ reason: String) {
        guard cancellation == nil else { return }
        cancellation = reason
        task?.cancel()
        closeSocket()
    }

    private func closeSocket() {
        idle?.cancel()
        idle = nil
        if let pendingSend {
            self.pendingSend = nil
            pendingSend.1.resume(throwing: CancellationError())
        }
        connection.stateUpdateHandler = nil
        connection.cancel()
    }

    private func touch() {
        idle?.cancel()
        let timeout = DispatchWorkItem { [weak self] in self?.cancel("readerIdleTimeout") }
        idle = timeout
        queue.asyncAfter(deadline: .now() + 30, execute: timeout)
    }

    private func send(_ data: Data?, final: Bool = false) async throws {
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard self.cancellation == nil else { continuation.resume(throwing: CancellationError()); return }
                let token = UUID()
                self.pendingSend = (token, continuation)
                self.touch()
                self.connection.send(content: data, contentContext: final ? .finalMessage : .defaultMessage,
                    isComplete: true, completion: .contentProcessed { error in
                        guard let pending = self.pendingSend, pending.0 == token else { return }
                        self.pendingSend = nil
                        if let error { pending.1.resume(throwing: error) } else { pending.1.resume() }
                    })
            }
        }
    }

    private func run() async {
        let started = ProcessInfo.processInfo.systemUptime
        let status = partial ? 206 : 200
        let length = interval.bodyLength
        var headers = "HTTP/1.1 \(partial ? "206 Partial Content" : "200 OK")\r\nContent-Length: \(length)\r\nAccept-Ranges: bytes\r\nContent-Type: application/octet-stream\r\nConnection: close\r\n"
        if partial {
            headers += "Content-Range: bytes \(interval.start)-\(interval.end)/\(interval.totalLength)\r\n"
        }
        let header = Data((headers + "\r\n").utf8)
        var sentHeaders = false
        var delivered: Int64 = 0
        var outcome = "complete"
        var errorKind: String?
        var responseStatus = status
        // The proxy waits on exactly one side at a time: the Reader for the
        // next chunk, or the local player socket for the chunk just read.
        var timeline = NetworkMediaProxyTransferTimeline(startedAt: started)
        var phase = NetworkMediaProxyTransferTimeline.Phase.reader
        var phaseStartedAt = started
        let timingBase = timingFields()
        // A Reader that can tell queueing from time on its connection reports
        // each read here; the chunk that read produced takes it on arrival.
        let readTiming = NetworkMediaReadTimingRecorder()
        do {
            if head {
                try await send(header, final: true)
            } else {
                while delivered < length {
                    let offset = interval.start + delivered
                    let count = min(MediaRangePolicy.upstreamWindowBytes, length - delivered)
                    let windowEnd = delivered + count
                    try await reader.stream(offset: offset, count: count, timing: readTiming) { data in
                        try Task.checkCancellation()
                        let arrived = ProcessInfo.processInfo.systemUptime
                        let readerWait = arrived - phaseStartedAt
                        let chunkReadTiming = readTiming.take()
                        phase = .consumer
                        phaseStartedAt = arrived
                        guard !data.isEmpty, Int64(data.count) <= windowEnd - delivered else {
                            outcome = "invalidReaderChunk"
                            throw NetworkMediaPlaybackError.invalidRangeResponse
                        }
                        do {
                            if !sentHeaders {
                                sentHeaders = true
                                try await send(header)
                            }
                            try await send(data)
                        } catch {
                            outcome = "clientSendError"
                            throw error
                        }
                        let accepted = ProcessInfo.processInfo.systemUptime
                        phase = .reader
                        phaseStartedAt = accepted
                        if let closed = timeline.record(offset: interval.start + delivered, bytes: data.count,
                                                        readerWait: readerWait, consumerWait: accepted - arrived,
                                                        now: accepted, readTiming: chunkReadTiming) {
                            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                                messageKey: "diagnostics.media.proxy_transfer_progress",
                                details: timingBase.merging(closed.fields()) { _, new in new }
                                    .merging(["stage": "readerTimingWindow"]) { _, new in new })
                        }
                        if delivered == 0 {
                            var firstChunk = [
                                "stage": "readerFirstChunkDelivered", "transportScope": "networkReader",
                                "measurementBoundary": "readerDelivery",
                                "playbackTraceID": PlaybackProxyRequestDiagnostics.safeTrace(traceID),
                                "transferID": id.uuidString, "bytes": "\(data.count)",
                                "readerToDeliveryMs": "\(Int((ProcessInfo.processInfo.systemUptime - started) * 1000))"
                            ]
                            // How much of a request's first-chunk delay was
                            // spent behind an earlier read, and how much reading.
                            if chunkReadTiming.reads > 0 {
                                firstChunk["firstReadQueueWaitMs"] = "\(Int((chunkReadTiming.queueWait * 1000).rounded()))"
                                firstChunk["firstReadMs"] = "\(Int((chunkReadTiming.readTime * 1000).rounded()))"
                            }
                            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                                messageKey: "diagnostics.media.proxy_transfer_started", details: firstChunk)
                        }
                        delivered += Int64(data.count)
                        PlaybackDownloadMeter.shared.receive(bytes: data.count, traceID: traceID)
                    }
                    guard delivered == windowEnd else {
                        outcome = "shortReaderWindow"
                        throw NetworkMediaPlaybackError.invalidRangeResponse
                    }
                }
                do { try await send(nil, final: true) } catch {
                    outcome = "clientSendError"
                    throw error
                }
            }
        } catch {
            if Task.isCancelled || error is CancellationError {
                outcome = "cancelled"
            } else if outcome == "complete" {
                // Not raised by the chunk checks or the socket send above.
                outcome = "readerError"
            }
            if outcome == "readerError" || outcome == "clientSendError" {
                errorKind = Self.safeErrorKind(error)
            }
            if !sentHeaders, !head, !Task.isCancelled {
                responseStatus = 502
                let errorHeader = Data("HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8)
                try? await send(errorHeader, final: true)
            }
        }
        let finishedAt = ProcessInfo.processInfo.systemUptime
        let unfinished = outcome != "complete"
        let closing = timeline.finish(pending: unfinished ? phase : nil,
                                      wait: unfinished ? finishedAt - phaseStartedAt : 0, now: finishedAt,
                                      readTiming: readTiming.take())
        let result = (delivered, outcome, responseStatus)
        queue.async { [self] in
            if !head, let open = closing.window {
                DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.proxy_transfer_progress",
                    details: timingBase.merging(open.fields()) { _, new in new }
                        .merging(["stage": "readerTimingWindow", "windowClosedBy": "transferEnd"]) { _, new in new })
            }
            var details = [
                "stage": "readerTransferFinished", "transportScope": "networkReader",
                "measurementBoundary": "readerDelivery", "adaptiveMeasurementBoundary": "ineligibleReaderDelivery",
                "playbackTraceID": PlaybackProxyRequestDiagnostics.safeTrace(traceID),
                "transferID": id.uuidString, "method": head ? "HEAD" : "GET",
                "range": "bytes=\(interval.start)-\(interval.end)", "status": "\(result.2)",
                "deliveredBytes": "\(result.0)", "expectedBytes": head ? "0" : "\(length)",
                "result": cancellation ?? result.1,
                // Distinguishes a finite Range that ended normally, a player
                // that closed or replaced its request, and a real read error.
                "terminalKind": Self.terminalKind(outcome: result.1, cancellation: cancellation),
                "finishedUptimeMs": "\(Int((finishedAt * 1000).rounded()))"
            ]
            if let errorKind { details["errorKind"] = errorKind }
            if !head {
                for (key, value) in closing.total.fields() where key != "dominantWait" {
                    details["total" + key.prefix(1).uppercased() + key.dropFirst()] = value
                }
                details["totalDominantWait"] = closing.total.dominantWait
            }
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished", details: details)
            closeSocket()
            task = nil
            onFinish()
        }
    }

    private func timingFields() -> [String: String] {
        [
            "transportScope": "networkReader", "measurementBoundary": "readerDelivery",
            "adaptiveMeasurementBoundary": "ineligibleReaderDelivery",
            "playbackTraceID": PlaybackProxyRequestDiagnostics.safeTrace(traceID),
            "transferID": id.uuidString, "method": head ? "HEAD" : "GET",
            "range": "bytes=\(interval.start)-\(interval.end)"
        ]
    }

    static func terminalKind(outcome: String, cancellation: String?) -> String {
        switch cancellation {
        case "clientDisconnected": return "playerClosedRequest"
        case "readerIdleTimeout": return "idleTimeout"
        case let reason?: return "cancelled:" + reason
        case nil: break
        }
        switch outcome {
        case "complete": return "rangeComplete"
        case "cancelled": return "cancelled"
        case "clientSendError": return "playerSocketError"
        default: return "readerFailure"
        }
    }

    /// Error identity without messages, which could include paths or hosts.
    static func safeErrorKind(_ error: Error) -> String {
        if let error = error as? NetworkMediaPlaybackError { return "networkMedia.\(error)" }
        if let error = error as? URLError { return "url.\(error.code.rawValue)" }
        let ns = error as NSError
        let domain = ns.domain.utf8.count <= 64 && ns.domain.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_")
        } ? ns.domain : "other"
        return "\(domain).\(ns.code)"
    }
}

private struct PlaybackOriginalStartupPrefix: Sendable {
    static let maximumBytes = 256 * 1024
    let data: Data
    let totalLength: Int64
    let etag: String

    private final class RejectRedirects: NSObject, URLSessionTaskDelegate, Sendable {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    static func fetch(_ url: URL, count: Int) async throws -> Self? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(count - 1)", forHTTPHeaderField: "Range")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if let token = AuthenticatedMediaProxyTransfer.authenticationToken(from: url) {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        let (bytes, response) = try await session.bytes(for: request, delegate: RejectRedirects())
        guard let response = response as? HTTPURLResponse, response.url == url,
              let range = MediaRangePolicy.validatedPartialResponse(statusCode: response.statusCode,
                  contentRange: response.value(forHTTPHeaderField: "Content-Range"), expectedStart: 0),
              range.bodyLength == Int64(count), range.totalLength > range.bodyLength,
              response.expectedContentLength == range.bodyLength, acceptsRepresentation(response),
              let etag = strongETag(response.value(forHTTPHeaderField: "ETag")) else {
            return nil
        }
        var data = Data()
        data.reserveCapacity(count)
        for try await byte in bytes {
            guard data.count < count else { return nil }
            data.append(byte)
        }
        guard data.count == count else { return nil }
        return Self(data: data, totalLength: range.totalLength, etag: etag)
    }

    static func strongETag(_ value: String?) -> String? {
        guard let value, value.count >= 2, value.first == "\"", value.last == "\"",
              value.utf8.dropFirst().dropLast().allSatisfy({
                  $0 == 0x21 || (0x23...0x7e).contains($0) || $0 >= 0x80
              }) else { return nil }
        return value
    }

    static func validatorEvidence(_ response: HTTPURLResponse, upstreamURL: URL,
                                  usesPinnedTrust: Bool, isBridge: Bool) -> [String: String] {
        let etag = response.value(forHTTPHeaderField: "ETag")
        let tagKind: String
        if strongETag(etag) != nil {
            tagKind = "strong"
        } else if let etag {
            tagKind = etag.hasPrefix("W/") && strongETag(String(etag.dropFirst(2))) != nil ? "weak" : "invalid"
        } else {
            tagKind = "missing"
        }
        return [
            "originalETagKind": tagKind,
            "originalLastModifiedPresent": String(response.value(forHTTPHeaderField: "Last-Modified") != nil),
            "originalURLUnchanged": String(response.url == upstreamURL),
            "originalPrefixCompatibleHeaders": String(acceptsRepresentation(response)),
            "originalPrefixTransportSupported": String(!usesPinnedTrust && !isBridge)
        ]
    }

    static func acceptsRepresentation(_ response: HTTPURLResponse) -> Bool {
        let cacheControl = response.value(forHTTPHeaderField: "Cache-Control") ?? ""
        let vary = response.value(forHTTPHeaderField: "Vary")?.lowercased() ?? ""
        return (response.value(forHTTPHeaderField: "Content-Encoding").map { $0.lowercased() == "identity" } ?? true)
            && !cacheControl.lowercased().split(separator: ",").contains {
                $0.trimmingCharacters(in: .whitespaces) == "no-store"
            }
            && (vary.isEmpty || vary == "accept-encoding")
    }
}

private final class PlaybackStartupPrimerPermit: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private var cancellations: [@Sendable () -> Void] = []
    var isActive: Bool { lock.lock(); defer { lock.unlock() }; return !cancelled }
    func registerCancellation(_ action: @escaping @Sendable () -> Void) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !cancelled else { return false }
        cancellations.append(action)
        return true
    }
    func cancel() {
        lock.lock()
        guard !cancelled else { lock.unlock(); return }
        cancelled = true
        let actions = cancellations
        cancellations.removeAll()
        lock.unlock()
        actions.forEach { $0() }
    }
}

private final class PlaybackHLSStartupPrimer: @unchecked Sendable {
    private let url: URL
    private let traceID: String?
    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.nastart.startup-segment-primer")
    private var connection: NWConnection?
    private var timeout: DispatchWorkItem?
    private var stopped = false

    private let onCancel: @Sendable () -> Void
    init(url: URL, traceID: String?, onCancel: @escaping @Sendable () -> Void) {
        self.url = url; self.traceID = traceID; self.onCancel = onCancel
    }

    func start() {
        lock.lock(); defer { lock.unlock() }
        guard !stopped, connection == nil, let port = url.port.flatMap({ NWEndpoint.Port(rawValue: UInt16($0)) }) else { return }
        // A one-shot loopback request has no automatic HTTP retries. The proxy
        // still owns the authenticated upstream task, telemetry and cancellation.
        let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            switch state {
            case .ready:
                let request = "GET \(self.url.path) HTTP/1.1\r\nHost: 127.0.0.1\r\nRange: bytes=0-0\r\nX-Nastart-Startup-Primer: 1\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(request.utf8), completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.cancel() } else { self?.read(connection, data: Data()) }
                })
            case .failed, .cancelled: self.cancel()
            default: break
            }
        }
        let timeout = DispatchWorkItem { [weak self] in self?.cancel() }
        self.timeout = timeout
        queue.asyncAfter(deadline: .now() + 5, execute: timeout)
        connection.start(queue: queue)
    }

    var isActive: Bool {
        lock.lock(); defer { lock.unlock() }
        return !stopped && connection != nil
    }

    private func read(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] chunk, _, complete, error in
            guard let self else { return }
            let received = data + (chunk ?? Data())
            if let boundary = received.range(of: Data("\r\n\r\n".utf8)) {
                let lines = String(decoding: received[..<boundary.lowerBound], as: UTF8.self).components(separatedBy: "\r\n")
                let status = lines.first?.split(separator: " ").dropFirst().first.flatMap { Int($0) } ?? 0
                var headers: [String: String] = [:]
                for line in lines.dropFirst() {
                    guard let colon = line.firstIndex(of: ":") else { continue }
                    headers[String(line[..<colon]).lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                }
                guard PlaybackHLSStartupPrimerPolicy.accepts(status: status,
                    contentRange: headers["content-range"], contentLength: headers["content-length"]) else { self.cancel(); return }
                let bodyCount = received.distance(from: boundary.upperBound, to: received.endIndex)
                if bodyCount == 1 { self.finish(complete: true); return }
                if bodyCount > 1 { self.cancel(); return }
            }
            guard error == nil, !complete, received.count < 16 * 1024 else { self.cancel(); return }
            self.read(connection, data: received)
        }
    }

    func cancel() { finish(complete: false) }

    private func finish(complete: Bool) {
        lock.lock()
        guard !stopped else { lock.unlock(); return }
        stopped = true
        let connection = self.connection; self.connection = nil
        timeout?.cancel(); timeout = nil
        lock.unlock()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        if !complete { onCancel() }
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.startup_segment_primer",
            details: ["result": complete ? "complete" : "stopped", "playbackTraceID": traceID ?? "-", "optional": "true"])
    }
}

// Keep long authenticated segment URLs in the route, rather than duplicating
// and percent-encoding them in every line sent to AVPlayer. The route owns the
// index so nested playlists and repeated requests share stable, isolated IDs.
private final class PlaybackPlaylistContext {
    let baseURL: URL
    let key: String
    let inheritedQueryItems: [URLQueryItem]

    init(_ baseURL: URL) {
        self.baseURL = baseURL
        key = baseURL.absoluteString
        let names = Set(["api_key", "apikey", "token", "access_token",
                         "deviceid", "mediasourceid", "playsessionid"])
        inheritedQueryItems = (URLComponents(url: baseURL, resolvingAgainstBaseURL: false)?.queryItems ?? [])
            .filter { names.contains($0.name.lowercased()) }
    }

    func resolve(_ uri: String) -> URL? {
        guard let target = URL(string: uri, relativeTo: baseURL)?.absoluteURL,
              ["http", "https"].contains(target.scheme?.lowercased() ?? "") else { return nil }
        guard !inheritedQueryItems.isEmpty,
              var components = URLComponents(url: target, resolvingAgainstBaseURL: false) else { return target }
        var items = components.queryItems ?? []
        let names = Set(items.map { $0.name.lowercased() })
        items.append(contentsOf: inheritedQueryItems.filter { !names.contains($0.name.lowercased()) })
        components.queryItems = items
        return components.url ?? target
    }
}

#if DEBUG
/// The experimental candidate owns at most one ordinary full TS response.
/// URLSession callbacks, peer attachment and route revocation share the proxy queue.
private final class PlaybackCandidateSegmentRetry: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private struct Peer {
        let connection: NWConnection
        let fallback: () -> Void
    }
    private static let maximumBytes = 4 * 1024 * 1024
    private let url: URL
    private let clientSession: String?
    private let queue: DispatchQueue
    private let trace: String?
    private let finished: () -> Void
    private var peers: [ObjectIdentifier: Peer] = [:]
    private var acceptedPeers = 0
    private var session: URLSession?
    private var expectedBytes: Int?
    private var body = Data()
    private var accepting = true
    private var ended = false

    init(url: URL, clientSession: String?, queue: DispatchQueue, trace: String?, finished: @escaping () -> Void) {
        self.url = url
        self.clientSession = clientSession
        self.queue = queue
        self.trace = trace
        self.finished = finished
    }

    static func segmentURLs(_ data: Data, mediaURL: URL, root: URL) -> Set<URL>? {
        func sameOrigin(_ url: URL) -> Bool {
            url.scheme == root.scheme && url.host == root.host && url.port == root.port
                && url.user == nil && url.password == nil && url.fragment == nil
        }
        guard sameOrigin(mediaURL), let text = String(data: data, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard lines.first == "#EXTM3U", lines.last == "#EXT-X-ENDLIST" else { return nil }
        let context = PlaybackPlaylistContext(mediaURL)
        var urls = Set<URL>()
        var pendingSegment = false
        for line in lines.dropFirst().dropLast() {
            if line.hasPrefix("#EXTINF:") {
                guard !pendingSegment,
                      let seconds = Double(line.dropFirst(8).prefix { $0 != "," }),
                      seconds.isFinite, seconds > 0 else { return nil }
                pendingSegment = true
            } else if line.hasPrefix("#") {
                guard !pendingSegment,
                      line == "#EXT-X-INDEPENDENT-SEGMENTS" || line == "#EXT-X-PLAYLIST-TYPE:VOD"
                        || ["#EXT-X-VERSION:", "#EXT-X-TARGETDURATION:", "#EXT-X-MEDIA-SEQUENCE:"]
                            .contains(where: { line.hasPrefix($0) }) else { return nil }
            } else {
                guard pendingSegment, urls.count < 8192, let url = context.resolve(line),
                      sameOrigin(url), url.pathExtension.lowercased() == "ts" else { return nil }
                pendingSegment = false
                urls.insert(url)
            }
        }
        return !pendingSegment && !urls.isEmpty ? urls : nil
    }

    func join(_ connection: NWConnection, url: URL, clientSession: String?,
              fallback: @escaping () -> Void) -> Bool {
        guard self.url == url, self.clientSession == clientSession, accepting, acceptedPeers < 4 else { return false }
        let id = ObjectIdentifier(connection)
        acceptedPeers += 1
        peers[id] = Peer(connection: connection, fallback: fallback)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled: self?.removePeer(id)
            default: break
            }
        }
        record(acceptedPeers == 1 ? "candidateSegmentProbeStarted" : "candidateSegmentProbeJoined")
        return true
    }

    func start() {
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = queue
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        self.session = session
        var request = URLRequest(url: url)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        if let token = AuthenticatedMediaProxyTransfer.authenticationToken(from: url) {
            request.setValue(token, forHTTPHeaderField: "X-Emby-Token")
        }
        session.dataTask(with: request).resume()
        queue.asyncAfter(deadline: .now() + .seconds(6)) { [weak self] in
            guard let self, !self.ended else { return }
            if self.accepting { self.fallback() }
            else { self.cancel() }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard accepting, let response = response as? HTTPURLResponse,
              response.url == url, response.statusCode == 200,
              response.value(forHTTPHeaderField: "Content-Range") == nil,
              (response.value(forHTTPHeaderField: "Content-Encoding")?.lowercased() ?? "identity") == "identity",
              response.value(forHTTPHeaderField: "Vary") == nil,
              response.value(forHTTPHeaderField: "Set-Cookie") == nil,
              ["video/mp2t", "application/octet-stream"].contains(response.mimeType?.lowercased() ?? ""),
              (1...Int64(Self.maximumBytes)).contains(response.expectedContentLength) else {
            completionHandler(.cancel)
            if accepting { fallback() }
            return
        }
        expectedBytes = Int(response.expectedContentLength)
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard accepting else { return }
        guard let expectedBytes, data.count <= expectedBytes - body.count else { fallback(); return }
        body.append(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard accepting else { return }
        guard error == nil, let expectedBytes, body.count == expectedBytes else { fallback(); return }
        accepting = false
        session.finishTasksAndInvalidate()
        self.session = nil
        record("candidateSegmentProbeReady")
        let header = Data(("HTTP/1.1 200 OK\r\nContent-Type: video/mp2t\r\n"
            + "Content-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n").utf8)
        let response = body
        body = Data()
        for (id, peer) in peers {
            peer.connection.batch {
                peer.connection.send(content: header, completion: .idempotent)
                peer.connection.send(content: response, isComplete: true, completion: .contentProcessed { [weak self] error in
                    if error == nil { self?.record("candidateSegmentProbeDelivered", bytes: response.count) }
                    self?.removePeer(id)
                })
            }
        }
        if peers.isEmpty { end() }
    }

    private func record(_ stage: String, bytes: Int? = nil) {
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished", details: [
                "stage": stage, "playbackTraceID": PlaybackProxyRequestDiagnostics.safeTrace(trace),
                "acceptedReaders": String(acceptedPeers), "bytes": String(bytes ?? body.count)
            ])
    }

    private func removePeer(_ id: ObjectIdentifier) {
        guard let peer = peers.removeValue(forKey: id) else { return }
        peer.connection.stateUpdateHandler = nil
        peer.connection.cancel()
        if !accepting, peers.isEmpty { end() }
    }

    private func fallback() {
        record("candidateSegmentProbeFallback")
        let remaining = peers.values
        peers.removeAll()
        end()
        for peer in remaining {
            peer.connection.stateUpdateHandler = nil
            peer.fallback()
        }
    }

    func cancel() {
        record("candidateSegmentProbeCancelled")
        let remaining = peers.values
        peers.removeAll()
        end()
        for peer in remaining {
            peer.connection.stateUpdateHandler = nil
            peer.connection.cancel()
        }
    }

    private func end() {
        guard !ended else { return }
        ended = true
        accepting = false
        body = Data()
        session?.invalidateAndCancel()
        session = nil
        finished()
    }
}
#endif

private final class PlaybackPlaylistChildren {
    private struct Child {
        let uri: String
        let context: PlaybackPlaylistContext
    }
    private let lock = NSLock()
    private var identifiers: [String: [String: String]] = [:]
    private var children: [String: Child] = [:]

    func identifier(for uri: String, context: PlaybackPlaylistContext) -> String? {
        // Preserve non-HTTP schemes (e.g. data keys) instead of routing them to
        // the HTTP proxy. Resolve/parse long URLs only when a segment is read.
        let path = uri.prefix { $0 != "?" && $0 != "#" }
        if let colon = path.firstIndex(of: ":"),
           !path[..<colon].contains("/"),
           !["http", "https"].contains(path[..<colon].lowercased()) { return nil }
        let ext = path.split(separator: "/").last?.split(separator: ".").last.map(String.init) ?? ""
        let safeExtension = !ext.isEmpty && ext.utf8.allSatisfy {
            (97...122).contains($0) || (48...57).contains($0)
        } ? ".\(ext)" : ""
        lock.lock()
        defer { lock.unlock() }
        if let existing = identifiers[context.key]?[uri] { return existing }
        let identifier = String(children.count, radix: 36) + safeExtension
        identifiers[context.key, default: [:]][uri] = identifier
        children[identifier] = Child(uri: uri, context: context)
        return identifier
    }

    func url(for identifier: String) -> URL? {
        lock.lock()
        let child = children[identifier]
        lock.unlock()
        return child.flatMap { $0.context.resolve($0.uri) }
    }
}

/// One registration owns this connection pool. Pinned trust must never become
/// a process-wide session decision or survive revocation of its route.
final class PlaybackPinnedRouteTransport {
    let session: URLSession
    private let origin: URL

    init(upstreamURL: URL) {
        origin = upstreamURL
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        session = URLSession(configuration: configuration,
            delegate: PlaybackPinnedRouteTrustDelegate(host: upstreamURL.host), delegateQueue: queue)
    }

    func accepts(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return false }
        func port(_ url: URL) -> Int? { url.port ?? (url.scheme?.lowercased() == "https" ? 443 : 80) }
        return scheme == origin.scheme?.lowercased()
            && host.lowercased() == origin.host?.lowercased() && port(url) == port(origin)
    }

    func invalidate() { session.invalidateAndCancel() }
    deinit { session.invalidateAndCancel() }
}

private final class PlaybackPinnedRouteTrustDelegate: NSObject, URLSessionDelegate {
    let host: String?
    init(host: String?) { self.host = host }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // Identical pin lookup and rejection behavior to the isolated transfer.
        guard let credential = CertificatePinStore.shared.credential(for: challenge, expectedHost: host) else {
            completionHandler(challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
                ? .cancelAuthenticationChallenge : .performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

private final class AuthenticatedMediaProxyTransfer: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate {
    // Share transport connections, not request credentials or cookies. Creating
    // a session per HLS segment repeatedly pays DNS/TCP/TLS costs on WAN routes.
    private static let transportSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return URLSession(configuration: configuration, delegate: nil, delegateQueue: queue)
    }()
    private var usesSharedTransport = false
    // Metrics can arrive after finish() releases session. Preserve the selected
    // transport instead of comparing optional session identities at callback time.
    private var selectedTransportScope = "unselected"
    private var connection: NWConnection?
    private let upstreamURL: URL
    private let method: String
    private let requestHeaders: [String: String]
    private let allowsSelfSignedCertificates: Bool
    private let pinnedTransport: PlaybackPinnedRouteTransport?
    private let prefersFiniteRangeResponse: Bool
    private let upstreamIsNetworkLibraryBridge: Bool
    private let isPlaylist: Bool
    private let isHLSChildRequest: Bool
    private let playbackTraceID: String?
    private let jellyfinMediaPath: String?
    // Task indices restart for every transfer, including concurrent HLS
    // children. Correlate metrics/completion without exposing request URLs.
    private let diagnosticTransferID: String
    private var playlistDeliveryDiagnostics = PlaybackPlaylistDeliveryDiagnostics()
    private let playlistToken: String?
    private let playlistFilename: String?
    private let playlistPort: NWEndpoint.Port?
    private let playlistStartSeconds: Double?
    private let playlistChildren: PlaybackPlaylistChildren
    private let vodPlaylistCache: PlaybackVODPlaylistCache
    private let playlistChildID: String?
    private let playlistContext: PlaybackPlaylistContext
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
    private var resolvingSuffixLength = false
    private var suffixTotalLength: Int64?
    private var suffixValidator: String?
    private var originalPrefix: PlaybackOriginalStartupPrefix?
    private var originalPrefixValidator: (etag: String, totalLength: Int64)?
    private var pendingOriginalPrefixBytes = 0
    private let preparesOriginalResponse: Bool
    private var heldOriginalHeader: Data?
    private var heldOriginalCompletion = false
    private var preparedOriginalIdentity: (url: URL?, total: Int64, etag: String?)?
    private var preparedOriginalTaskID: Int?
    private var lastStatusCode: Int?
    private let isStartupPrimer: Bool
    private let startedAt = Date()
    private let startedUptime = ProcessInfo.processInfo.systemUptime
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
    private var suspendedSinceUptime: TimeInterval?
    private var upstreamSuspendedSeconds: TimeInterval = 0
    private var upstreamSuspendCount = 0
    private var upstreamCompleted = false
    private var didScheduleConnectionClose = false
    private var upstreamTaskIndex = 0
    private let taskDiagnostics = PlaybackProxyTaskDiagnostics()
    private var bodyWindowSampler = PlaybackBodyWindowSampler()
    private var retriesUncompactedPlaylist = false
    private var usesCompactedPlaylistQuery = false
#if DEBUG
    private var firstShapedSendAt: TimeInterval?
    private var shapedBodyBytes: Int64 = 0
    private var shapedWindowStartedAt: TimeInterval?
    private var shapedWindowBytes: Int64 = 0
#endif
    private let sendChunkSize = 512 * 1024
    private let highWaterMark = 4 * 1024 * 1024
    private let lowWaterMark = 1 * 1024 * 1024
    private let preparedHighWaterMark = 64 * 1024
    private let preparedMaximumBytes = 256 * 1024
    private let maximumConsecutiveRetryFailures = 5
    private let maximumMediaSegmentBytes = MediaRangePolicy.upstreamWindowBytes

    private var clientUsesChunkedMediaResponse: Bool {
        guard !prefersFiniteRangeResponse else { return false }
        guard !isPlaylist, !isHLSChildRequest else { return false }
        return clientRequestsThroughEnd
    }

    private var clientUsesContinuousRangeResponse: Bool {
        guard prefersFiniteRangeResponse, !isPlaylist, !isHLSChildRequest else { return false }
        return clientRequestsThroughEnd
    }

    private var clientRequestsThroughEnd: Bool {
        let value = requestHeaders["range"] ?? "bytes=0-"
        if case .suffix = MediaRangePolicy.requestedRange(value) { return true }
        return MediaRangePolicy.isOpenEnded(value)
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
            "startupPrimer": String(isStartupPrimer),
            "hlsRole": hlsRole,
            "pathExtension": upstreamURL.pathExtension.lowercased().isEmpty
                ? "-"
                : upstreamURL.pathExtension.lowercased(),
            "upstreamTaskIndex": "\(upstreamTaskIndex)",
            "transferID": diagnosticTransferID,
            "playlistChildID": playlistChildID ?? "root",
            "segmentOrdinal": isHLSChildRequest
                ? PlaybackHLSRequestDiagnostics.segmentOrdinal(upstreamURL).map(String.init) ?? "unknown" : "-",
            "playbackTraceID": playbackTraceID ?? "-",
            "transportScope": selectedTransportScope
        ]
    }

    private func diagnosticDetails(_ details: [String: String]) -> [String: String] {
        var fields = diagnosticContext.merging(details) { _, new in new }
        if upstreamIsNetworkLibraryBridge {
            fields["measurementBoundary"] = "bridgeDelivery"
            fields["upstreamKind"] = "networkLibraryBridge"
        }
        return fields
    }

    init(
        connection: NWConnection?,
        upstreamURL: URL,
        method: String,
        requestHeaders: [String: String],
        diagnosticTransferID: UUID = UUID(),
        isStartupPrimer: Bool = false,
        originalPrefix: PlaybackOriginalStartupPrefix? = nil,
        allowsSelfSignedCertificates: Bool,
        pinnedTransport: PlaybackPinnedRouteTransport?,
        prefersFiniteRangeResponse: Bool,
        upstreamIsNetworkLibraryBridge: Bool,
        isPlaylist: Bool,
        isHLSChildRequest: Bool,
        playbackTraceID: String?,
        jellyfinMediaPath: String?,
        playlistToken: String?,
        playlistFilename: String?,
        playlistPort: NWEndpoint.Port?,
        playlistStartSeconds: Double? = nil,
        playlistChildren: PlaybackPlaylistChildren,
        vodPlaylistCache: PlaybackVODPlaylistCache,
        playlistChildID: String? = nil,
        completion: @escaping () -> Void
    ) {
        self.connection = connection
        self.preparesOriginalResponse = connection == nil
        self.upstreamURL = upstreamURL
        self.method = method
        self.requestHeaders = requestHeaders
        self.isStartupPrimer = isStartupPrimer
        self.originalPrefix = originalPrefix
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.pinnedTransport = pinnedTransport
        self.prefersFiniteRangeResponse = prefersFiniteRangeResponse
        self.upstreamIsNetworkLibraryBridge = upstreamIsNetworkLibraryBridge
        self.isPlaylist = isPlaylist
        self.isHLSChildRequest = isHLSChildRequest
        self.playbackTraceID = playbackTraceID?.isEmpty == false ? playbackTraceID : nil
        self.jellyfinMediaPath = jellyfinMediaPath
        self.playlistToken = playlistToken
        self.playlistFilename = playlistFilename
        self.playlistPort = playlistPort
        self.playlistStartSeconds = playlistStartSeconds
        self.playlistChildren = playlistChildren
        self.vodPlaylistCache = vodPlaylistCache
        self.playlistChildID = playlistChildID
        self.diagnosticTransferID = diagnosticTransferID.uuidString
        self.playlistContext = PlaybackPlaylistContext(upstreamURL)
        self.completion = completion
    }

    func cancelStartupPrimerIfOwned(byRoute token: String, port: NWEndpoint.Port) {
        guard isStartupPrimer else { return }
        cancelIfOwned(byRoute: token, port: port)
    }

    func cancelManifestPreparation() {
        let cancel = { [self] in finish(with: URLError(.cancelled), source: "manifestPreparationCancelled") }
        if let session { session.delegateQueue.addOperation(cancel) }
        else { cancel() }
    }

    func cancelIfOwned(byRoute token: String, port: NWEndpoint.Port) {
        guard playlistToken == token, playlistPort == port else { return }
        let cancel = { [self] in
            finish(with: URLError(.cancelled), source: "routeRevoked")
            // A previously queued playlist callback may have populated the
            // cache after the route was removed; release that data as well.
            vodPlaylistCache.remove(route: token)
        }
        if let session {
            // Serialize with upstream completion and continuation callbacks.
            // Do not invalidate the shared session or another route's tasks.
            session.delegateQueue.addOperation(cancel)
        } else {
            cancel()
        }
    }

    // This optional transfer uses the proxy queue for both the upstream
    // delegate and client attachment. Neither side can race the handoff.
    func startOriginalPreparation(on queue: DispatchQueue) {
        configureIsolatedSession(underlyingQueue: queue)
        selectedTransportScope = "preparedOriginal"
        startUpstreamTask()
    }

    func abandonOriginalPreparation() {
        guard connection == nil else { return }
        finish(with: URLError(.cancelled), source: "originalPreparationAbandoned")
    }

    func adoptOriginalPreparation(_ connection: NWConnection, initialReadComplete: Bool,
                                  initialReadError: NWError?) -> Bool {
        guard self.connection == nil, !isFinished, initialReadError == nil else { return false }
        self.connection = connection
        observeClient(connection, initialReadComplete: initialReadComplete, initialReadError: nil)
        pendingOriginalPrefixBytes = pendingBodyBytes
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_started", details: diagnosticDetails([
                "stage": "originalResponseAdopted",
                "preparedBytes": String(pendingOriginalPrefixBytes),
                "headersReady": String(heldOriginalHeader != nil)
            ]))
        if pendingOriginalPrefixBytes > 0 {
            PlaybackDownloadMeter.shared.receive(bytes: pendingOriginalPrefixBytes, traceID: playbackTraceID)
        }
        if let header = heldOriginalHeader {
            heldOriginalHeader = nil
            sendResponseHeader(header, on: connection)
        }
        drainBufferedBody()
        if heldOriginalCompletion { completeMediaBody(after: nil) }
        return true
    }

    func start(initialReadComplete: Bool, initialReadError: NWError?) {
        guard let connection else { return }
        observeClient(connection, initialReadComplete: initialReadComplete, initialReadError: initialReadError)
        if isPlaylist, method == "GET", requestHeaders["range"] == nil,
           let token = playlistToken,
           let cached = vodPlaylistCache.data(route: token, url: upstreamURL) {
            playlistBody = cached
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_started",
                details: diagnosticDetails(["stage": "vodPlaylistCacheHit", "bytes": String(cached.count)]))
            sendPlaylist()
            return
        }
        let firstRange = originalPrefix.map {
            "bytes=\($0.data.count)-\(min(maximumMediaSegmentBytes, $0.totalLength) - 1)"
        }
        if !allowsSelfSignedCertificates {
            usesSharedTransport = true
            selectedTransportScope = "systemShared"
            session = Self.transportSession
        } else if let pinnedTransport, pinnedTransport.accepts(upstreamURL) {
            usesSharedTransport = true
            selectedTransportScope = "pinnedRoute"
            session = pinnedTransport.session
        } else {
            configureIsolatedSession()
        }
        startUpstreamTask(rangeOverride: firstRange)
    }

    private func observeClient(_ connection: NWConnection, initialReadComplete: Bool, initialReadError: NWError?) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled:
                self?.finish(with: URLError(.cancelled), source: "clientCancelled")
            case .failed(let error):
                self?.finish(with: error, source: "clientFailed")
            default:
                break
            }
        }
        if initialReadComplete || initialReadError != nil {
            recordClientReadEnd(isComplete: initialReadComplete, error: initialReadError,
                bytes: 0, observation: "requestHeader")
        } else {
            observeClientReadEnd()
        }
    }

    private func configureIsolatedSession(underlyingQueue: DispatchQueue? = nil) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 24 * 60 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 4
        if underlyingQueue != nil {
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
        }
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let delegateQueue = OperationQueue()
        delegateQueue.maxConcurrentOperationCount = 1
        delegateQueue.underlyingQueue = underlyingQueue
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: delegateQueue)
        selectedTransportScope = "isolated"
        self.session = session
    }

    // TCP receive completion describes the peer's write direction. A valid
    // GET may send FIN and still read our entire response. Observe EOF/errors
    // without cancelling upstream or changing the existing send/state rules.
    private func observeClientReadEnd() {
        guard let connection, !isFinished else { return }
        connection.receive(minimumIncompleteLength: 1, maximumLength: 32 * 1024) {
            [weak self] data, _, isComplete, error in
            guard let self else { return }
            if isComplete || error != nil {
                self.recordClientReadEnd(isComplete: isComplete, error: error,
                    bytes: data?.count ?? 0, observation: "afterRequest")
                return
            }
            self.observeClientReadEnd()
        }
    }

    private func recordClientReadEnd(isComplete: Bool, error: NWError?, bytes: Int,
                                     observation: String) {
        let transport = transportErrorDetails(error)
        let details: [String: String] = [
            "stage": "clientReadEnded",
            "clientReadComplete": String(isComplete),
            "clientReadAfterFinish": String(isFinished),
            "clientReadObservation": observation,
            "clientReadBytes": String(bytes),
            "clientReadErrorKind": transport["transportErrorKind"] ?? "unknown",
            "clientReadErrorCode": transport["transportErrorCode"] ?? "unknown",
            "requestReceivedToReadEndMs": String(Int(max(
                ProcessInfo.processInfo.systemUptime - startedUptime, 0) * 1_000))
        ]
        DiagnosticLogStore.shared.record(error == nil ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_started",
            details: diagnosticDetails(details))
    }

    private func startUpstreamTask(rangeOverride: String? = nil) {
        bufferLock.lock()
        suspendedSinceUptime = nil
        upstreamSuspendedSeconds = 0
        upstreamSuspendCount = 0
        bufferLock.unlock()
        upstreamTaskIndex += 1
        bodyBytesAtTaskStart = deliveredBodyBytes
        expectedBodyBytes = nil
        responseEndOffset = nil
        let activeRange: String?
        if isPlaylist || isHLSChildRequest {
            activeRange = rangeOverride ?? requestHeaders["range"]
        } else {
            let requestedRange = rangeOverride ?? requestHeaders["range"] ?? "bytes=0-"
            guard let parsed = MediaRangePolicy.requestedRange(requestedRange) else {
                rejectClientRange()
                return
            }
            // Never turn a client's open-ended first request into a
            // progressive 200 response. VLC can retain the resulting
            // Matroska stream while probing/seeking and push the app past
            // iOS's per-process memory limit. Every media request therefore
            // starts with a finite Range window; interrupted transfers are
            // resumed from the received offset below.
            resolvingSuffixLength = false
            if case .suffix = parsed, suffixTotalLength == nil {
                // Learn only the length from a one-byte Range response header.
                // Cancel before accepting its body, then request finite tail
                // windows using that length and an If-Range validator if given.
                resolvingSuffixLength = true
                activeRange = "bytes=0-0"
            } else {
                guard let bounded = MediaRangePolicy.boundedRange(requestedRange,
                    maximumLength: maximumMediaSegmentBytes, totalLength: suffixTotalLength) else {
                    rejectClientRange(totalLength: suffixTotalLength)
                    return
                }
                activeRange = bounded
            }
        }
        activeRequestedRange = activeRange
        activeRequestedRangeStart = MediaRangePolicy.requestedRangeStart(from: activeRange)
        let compacted = isPlaylist && activeRange == nil && !retriesUncompactedPlaylist
            ? PlaybackJellyfinPlaylistQuery.compact(upstreamURL) : nil
        usesCompactedPlaylistQuery = compacted != nil
        let requestURL = compacted ?? upstreamURL
        var request = URLRequest(url: requestURL)
        request.httpMethod = method
        // Let URLSession negotiate/decompress full text playlists. Binary and
        // byte-range responses must retain their original byte offsets.
        if !isPlaylist || activeRange != nil {
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        }
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
        if let validator = originalPrefix?.etag ?? originalPrefixValidator?.etag
            ?? preparedOriginalIdentity?.etag ?? suffixValidator {
            request.setValue(validator, forHTTPHeaderField: "If-Range")
        }
        guard let session else {
            finish(with: URLError(.cancelled))
            return
        }
        let task = session.dataTask(with: request)
        if usesSharedTransport { task.delegate = self }
        self.task = task
        if preparesOriginalResponse && upstreamTaskIndex == 1 { preparedOriginalTaskID = task.taskIdentifier }
        taskDiagnostics.issued(taskID: task.taskIdentifier, now: ProcessInfo.processInfo.systemUptime)
        if method == "GET" {
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_started", details: diagnosticDetails([
                    "stage": "upstreamRequestIssued", "method": method,
                    "range": activeRange ?? "full", "suffixLengthProbe": String(resolvingSuffixLength),
                    "playlistQueryCompacted": String(usesCompactedPlaylistQuery),
                    "queryBytesBefore": String(URLComponents(url: upstreamURL, resolvingAgainstBaseURL: false)?.percentEncodedQuery?.utf8.count ?? 0),
                    "queryBytesAfter": String(URLComponents(url: requestURL, resolvingAgainstBaseURL: false)?.percentEncodedQuery?.utf8.count ?? 0),
                    "requestReceivedToIssueMs": String(Int(Date().timeIntervalSince(startedAt) * 1_000))
                ]))
        }
        task.resume()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        // Optional work must never follow another endpoint with inherited auth.
        completionHandler(connection == nil || isStartupPrimer || originalPrefix != nil
            || originalPrefixValidator != nil ? nil : request)
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard !isFinished, task === dataTask else {
            completionHandler(.cancel)
            return
        }
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            finish(with: URLError(.badServerResponse))
            return
        }
        taskDiagnostics.responseHeadersReceived(taskID: dataTask.taskIdentifier,
            now: ProcessInfo.processInfo.systemUptime)
        if isPlaylist, usesCompactedPlaylistQuery, !retriesUncompactedPlaylist,
           [400, 422].contains(response.statusCode) {
            retriesUncompactedPlaylist = true
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished", details: diagnosticDetails([
                    "stage": "playlistQueryCompatibilityFallback", "status": String(response.statusCode)
                ]))
            completionHandler(.cancel)
            startUpstreamTask()
            return
        }
        lastStatusCode = response.statusCode
        if isStartupPrimer && !PlaybackHLSStartupPrimerPolicy.accepts(status: response.statusCode,
            contentRange: response.value(forHTTPHeaderField: "Content-Range"),
            contentLength: response.value(forHTTPHeaderField: "Content-Length")) {
            completionHandler(.cancel)
            finish(with: URLError(.badServerResponse), source: "startupPrimerRejected")
            return
        }
        bodyWindowSampler.beginResponse(now: ProcessInfo.processInfo.systemUptime)
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
        if let identity = preparedOriginalIdentity,
           response.url != identity.url || parsedRange?.totalLength != identity.total
            || (identity.etag != nil && response.value(forHTTPHeaderField: "ETag") != identity.etag) {
            completionHandler(.cancel)
            rejectUpstreamResponse()
            return
        }
        if let prefix = originalPrefix, !matchesOriginalPrefix(response, range: parsedRange,
                                                               etag: prefix.etag, totalLength: prefix.totalLength) {
            completionHandler(.cancel)
            restartOriginalWithoutPrefix()
            return
        }
        if let validator = originalPrefixValidator, !matchesOriginalPrefix(response, range: parsedRange,
                                            etag: validator.etag, totalLength: validator.totalLength) {
            completionHandler(.cancel)
            rejectUpstreamResponse()
            return
        }
        if !isHLSChildRequest, !didSendResponseHeaders, response.statusCode == 416 {
            completionHandler(.cancel)
            let total = contentRange.flatMap { value -> Int64? in
                guard value.hasPrefix("bytes */") else { return nil }
                let text = value.dropFirst("bytes */".count)
                guard !text.isEmpty, text.utf8.allSatisfy({ (48...57).contains($0) }),
                      let length = Int64(text), length >= 0 else { return nil }
                return length
            }
            rejectClientRange(totalLength: total)
            return
        }
        if resolvingSuffixLength {
            completionHandler(.cancel)
            guard response.statusCode == 206, let parsedRange,
                  parsedRange.start == 0, parsedRange.end == 0,
                  response.value(forHTTPHeaderField: "Content-Length").map({ $0 == "1" }) ?? true,
                  response.value(forHTTPHeaderField: "Content-Encoding").map({ $0.lowercased() == "identity" }) ?? true else {
                rejectUpstreamResponse()
                return
            }
            suffixTotalLength = parsedRange.totalLength
            let etag = response.value(forHTTPHeaderField: "ETag")
            suffixValidator = etag.flatMap { $0.hasPrefix("W/") ? nil : $0 }
                ?? response.value(forHTTPHeaderField: "Last-Modified")
            resolvingSuffixLength = false
            startUpstreamTask()
            return
        }
        if let suffixTotalLength, parsedRange?.totalLength != suffixTotalLength {
            completionHandler(.cancel)
            rejectUpstreamResponse()
            return
        }
        if !isHLSChildRequest, let parsedRange,
           let activeRequestedRange,
           case let .offset(_, requestedEnd) = MediaRangePolicy.requestedRange(activeRequestedRange) {
            let bodyLength = response.value(forHTTPHeaderField: "Content-Length")
            let encoding = response.value(forHTTPHeaderField: "Content-Encoding")
            guard requestedEnd.map({ parsedRange.end <= $0 }) ?? false,
                  bodyLength.map({ Int64($0) == parsedRange.bodyLength }) ?? true,
                  encoding.map({ $0.lowercased() == "identity" }) ?? true else {
                completionHandler(.cancel)
                rejectUpstreamResponse()
                return
            }
        }
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
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_started",
                details: diagnosticDetails([
                    "stage": "continuationResponse",
                    "range": activeRequestedRange ?? "-",
                    "status": "\(response.statusCode)",
                    "contentRange": contentRange ?? "-",
                    "contentLength": expectedBodyBytes.map(String.init) ?? "-",
                    "cumulativeReceivedBytes": "\(deliveredBodyBytes)"
                ])
            )
            completionHandler(.allow)
            return
        }

        didSendResponseHeaders = true
        responseStartOffset = originalPrefix == nil ? parsedRange?.start ?? 0 : 0
        responseEndOffset = parsedRange?.end
        if let contentLength = response.value(forHTTPHeaderField: "Content-Length"),
           let parsedLength = Int64(contentLength), parsedLength >= 0 {
            expectedBodyBytes = parsedLength
        }
        if preparesOriginalResponse, let parsedRange {
            preparedOriginalIdentity = (response.url, parsedRange.totalLength,
                PlaybackOriginalStartupPrefix.strongETag(response.value(forHTTPHeaderField: "ETag")))
            expectedBodyBytes = parsedRange.bodyLength
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
            ].merging(
                !isHLSChildRequest && method == "GET" && response.statusCode == 206
                    ? PlaybackOriginalStartupPrefix.validatorEvidence(response, upstreamURL: upstreamURL,
                        usesPinnedTrust: allowsSelfSignedCertificates, isBridge: upstreamIsNetworkLibraryBridge)
                    : [:]
            ) { _, new in new })
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
           let start = responseStartOffset,
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
        let header = Data((lines.joined(separator: "\r\n") + "\r\n\r\n").utf8)
        if let connection {
            sendResponseHeader(header, on: connection)
        } else {
            heldOriginalHeader = header
        }
        if let prefix = originalPrefix {
            originalPrefix = nil
            originalPrefixValidator = (prefix.etag, prefix.totalLength)
            deliveredBodyBytes = Int64(prefix.data.count)
            bodyBytesAtTaskStart = deliveredBodyBytes
            bufferLock.lock()
            pendingBodyChunks.append(prefix.data)
            pendingBodyBytes += prefix.data.count
            pendingOriginalPrefixBytes = prefix.data.count
            bufferLock.unlock()
            drainBufferedBody()
        }
        completionHandler(.allow)
    }

    private func sendResponseHeader(_ header: Data, on connection: NWConnection) {
        connection.send(content: header, completion: .contentProcessed { [weak self] error in
            if let error { self?.finish(with: error, source: "clientHeaderSend") }
        })
    }

    private func matchesOriginalPrefix(_ response: HTTPURLResponse, range: MediaRangePolicy.ContentRange?,
                                       etag: String, totalLength: Int64) -> Bool {
        guard response.statusCode == 206, response.url == upstreamURL, let range,
              range.start == activeRequestedRangeStart, range.totalLength == totalLength,
              let activeRequestedRange,
              case let .offset(_, end?) = MediaRangePolicy.requestedRange(activeRequestedRange),
              range.end <= end, response.expectedContentLength == range.bodyLength,
              response.value(forHTTPHeaderField: "ETag") == etag else { return false }
        return PlaybackOriginalStartupPrefix.acceptsRepresentation(response)
    }

    private func restartOriginalWithoutPrefix() {
        originalPrefix = nil
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_started",
            details: diagnosticDetails(["stage": "originalPrefixRejected"]))
        startUpstreamTask()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !isFinished, task === dataTask else { return }
        if preparesOriginalResponse, let expectedBodyBytes,
           Int64(data.count) > expectedBodyBytes - (deliveredBodyBytes - bodyBytesAtTaskStart) {
            finish(with: URLError(.cannotParseResponse), source: "preparedOriginalInvalidBodyLength")
            return
        }
        taskDiagnostics.receivedBody(taskID: dataTask.taskIdentifier, bytes: Int64(data.count),
            now: ProcessInfo.processInfo.systemUptime)
        if isPlaylist {
            playlistBody.append(data)
            return
        }
        bufferLock.lock()
        let waitingForOriginalClient = connection == nil
        if waitingForOriginalClient && data.count > preparedMaximumBytes - pendingBodyBytes {
            bufferLock.unlock()
            finish(with: URLError(.dataLengthExceedsMaximum), source: "originalPreparationOverflow")
            return
        }
        deliveredBodyBytes += Int64(data.count)
        pendingBodyChunks.append(Data(data))
        pendingBodyBytes += data.count
        var pausedPreparationBytes: Int?
        if pendingBodyBytes >= (waitingForOriginalClient ? preparedHighWaterMark : highWaterMark),
           suspendedDataTask == nil {
            suspendedDataTask = dataTask
            suspendedSinceUptime = ProcessInfo.processInfo.systemUptime
            upstreamSuspendCount += 1
            dataTask.suspend()
            if waitingForOriginalClient { pausedPreparationBytes = pendingBodyBytes }
        }
        bufferLock.unlock()
        if let pausedPreparationBytes {
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished", details: diagnosticDetails([
                    "stage": "originalResponsePreparationPaused", "preparedBytes": String(pausedPreparationBytes)
                ]))
        }
        guard !waitingForOriginalClient else { return }
        recordBodyProgress(bytes: data.count)
        drainBufferedBody()
    }

    /// Two stable, unthrottled Range windows can supply a short-lived estimate
    /// before completion, superseding older startup/tail completions. A newer
    /// completed transfer can still replace this short-lived estimate.
    private func recordBodyProgress(bytes: Int) {
        guard !isStartupPrimer, method == "GET", !isPlaylist,
              !isHLSChildRequest || hlsRole == "segment" else { return }
        PlaybackDownloadMeter.shared.receive(bytes: bytes, traceID: playbackTraceID)
        let now = ProcessInfo.processInfo.systemUptime
        bufferLock.lock()
        let pressure = upstreamSuspendedSeconds
            + (suspendedSinceUptime.map { max(now - $0, 0) } ?? 0)
        let queued = pendingBodyBytes
        bufferLock.unlock()
        guard let window = bodyWindowSampler.receive(bytes: bytes, now: now,
            totalBackpressure: pressure, queuedBytes: queued,
            eligible: !upstreamIsNetworkLibraryBridge && !isHLSChildRequest
                && !(preparesOriginalResponse && upstreamTaskIndex == 1)
                && lastStatusCode == 206 && activeRequestedRange != nil) else { return }
        let capacity = window.capacity
        if let capacity {
            PlaybackRecentThroughputStore.shared.recordQualifiedBodyWindow(
                traceID: playbackTraceID, bitrate: capacity, now: now)
        }
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished", details: diagnosticDetails([
                "stage": "upstreamBodyProgress", "measurementBoundary": "receivedBodyWindow",
                "bytes": String(window.bytes), "elapsedMs": String(Int(window.seconds * 1_000)),
                "effectiveBps": String(Int(Double(window.bytes) * 8 / window.seconds)),
                "bodyWindowIncludesRangeBoundaries": "true",
                "bodyWindowMinimumBytes": "131072",
                "bodyWindowPressured": String(window.pressured),
                "proxyBackpressureMs": String(Int(pressure * 1_000)),
                "proxyQueuedBytes": String(queued),
                "qualifiedBodyCapacity": capacity.map(String.init) ?? "unknown",
                "recordedForAdaptiveEstimate": String(capacity != nil)
            ]))
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didFinishCollecting metrics: URLSessionTaskMetrics
    ) {
        guard let observation = taskDiagnostics.callback(taskID: task.taskIdentifier) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard let transaction = metrics.transactionMetrics.last else {
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished",
                details: diagnosticDetails(observation.fields(at: now).merging([
                    "stage": "urlSessionTaskMetrics", "transactionCount": "0",
                    "taskIntervalMs": String(Int(metrics.taskInterval.duration * 1_000))
                ]) { _, new in new }))
            return
        }
        bufferLock.lock()
        let backpressureSeconds = observation.clientFinished ? observation.finalBackpressure
            : upstreamSuspendedSeconds + (suspendedSinceUptime.map { max(now - $0, 0) } ?? 0)
        let suspendCount = observation.clientFinished ? observation.finalSuspendCount : upstreamSuspendCount
        let queuedBytes = observation.clientFinished ? observation.finalQueuedBytes : pendingBodyBytes
        bufferLock.unlock()
        let isHLSSegment = isHLSChildRequest && hlsRole == "segment"
        let measurementSeconds = PlaybackTransferCapacityPolicy.seconds(
            isHLSSegment: isHLSSegment,
            fetchStart: transaction.fetchStartDate,
            responseStart: transaction.responseStartDate,
            responseEnd: transaction.responseEndDate
        )
        let preparedWindow = task.taskIdentifier == preparedOriginalTaskID
        if !upstreamIsNetworkLibraryBridge, !isStartupPrimer, !preparedWindow,
           !observation.clientFinished, !isFinished, task === self.task,
           !isPlaylist, (!isHLSChildRequest || isHLSSegment), let measurementSeconds {
            PlaybackRecentThroughputStore.shared.record(
                traceID: playbackTraceID,
                bytes: task.countOfBytesReceived,
                seconds: measurementSeconds,
                backpressureSeconds: backpressureSeconds,
                now: ProcessInfo.processInfo.systemUptime,
                isServerRendition: isHLSSegment
            )
        }
        func milliseconds(_ start: Date?, _ end: Date?) -> String {
            guard let start, let end else { return "-" }
            return String(Int(max(end.timeIntervalSince(start), 0) * 1_000))
        }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished",
            details: diagnosticDetails(observation.fields(at: now).merging(
                PlaybackRequestPhaseDiagnostics.fields(
                    created: metrics.taskInterval.start,
                    firstFetch: metrics.transactionMetrics.first?.fetchStartDate,
                    lastFetch: transaction.fetchStartDate,
                    requestStart: transaction.requestStartDate,
                    requestEnd: transaction.requestEndDate,
                    responseStart: transaction.responseStartDate,
                    responseEnd: transaction.responseEndDate,
                    callback: Date())) { _, new in new }.merging(
                PlaybackResponseBodyDiagnostics.fields(
                    received: transaction.countOfResponseBodyBytesReceived,
                    decoded: transaction.countOfResponseBodyBytesAfterDecoding,
                    contentLength: (transaction.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Length"),
                    contentEncoding: (transaction.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Encoding"),
                    status: (transaction.response as? HTTPURLResponse)?.statusCode)
            ) { _, new in new }.merging(
                PlaybackJellyfinOutputDiagnostics.fields(mediaPath: jellyfinMediaPath,
                    request: transaction.request, redirectCount: metrics.redirectCount)
            ) { _, new in new }.merging([
                "stage": "urlSessionTaskMetrics",
                "transactionCount": String(metrics.transactionMetrics.count),
                "redirectCount": String(metrics.redirectCount),
                "taskIntervalMs": String(Int(metrics.taskInterval.duration * 1_000)),
                "adaptiveMeasurementBoundary": upstreamIsNetworkLibraryBridge ? "ineligibleBridgeDelivery"
                    : preparedWindow ? "ineligiblePreparedResponse" : isHLSSegment ? "fetchToResponseEnd" : "responseBody",
                "adaptiveTransferMs": upstreamIsNetworkLibraryBridge || preparedWindow ? "unknown"
                    : measurementSeconds.map { String(Int($0 * 1_000)) } ?? "unknown",
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
                "proxyBackpressureMs": String(Int(backpressureSeconds * 1_000)),
                "proxySuspendCount": String(suspendCount),
                "proxyQueuedBytes": String(queuedBytes),
                "protocol": transaction.networkProtocolName ?? "-",
                "connectionReused": transaction.isReusedConnection ? "yes" : "no",
                "cellular": transaction.isCellular ? "yes" : "no",
                "expensive": transaction.isExpensive ? "yes" : "no",
                "constrained": transaction.isConstrained ? "yes" : "no",
                "remoteAddress": transaction.remoteAddress ?? "-"
            ]) { _, new in new })
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let observation = taskDiagnostics.callback(taskID: task.taskIdentifier, completed: true) else { return }
        // Built key by key: the .merging() dictionary literal times out the type checker.
        // Plain assignment overwrites duplicate keys, same as merging with { _, new in new }.
        var mergedFields = observation.fields(at: ProcessInfo.processInfo.systemUptime)
        mergedFields["stage"] = "upstreamTaskCompleted"
        mergedFields["range"] = activeRequestedRange ?? "-"
        mergedFields["taskReceivedBytes"] = String(observation.receivedBodyBytes)
        mergedFields["cumulativeReceivedBytes"] = String(isPlaylist ? Int64(playlistBody.count) : deliveredBodyBytes)
        mergedFields["expectedBytes"] = (isPlaylist ? playlistExpectedBodyBytes : expectedBodyBytes).map(String.init) ?? "-"
        mergedFields["errorDomain"] = error.map { ($0 as NSError).domain } ?? "-"
        mergedFields["errorCode"] = error.map { String(($0 as NSError).code) } ?? "-" 
        DiagnosticLogStore.shared.record(
            error == nil ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished",
            details: diagnosticDetails(mergedFields)
        )
        // A late completion is evidence only; never resume a closed client.
        guard !isFinished, task === self.task else { return }
        if originalPrefix != nil {
            restartOriginalWithoutPrefix()
            return
        }
        if isPlaylist {
            guard error == nil else { finish(with: error); return }
            sendPlaylist()
            return
        }
        if connection == nil {
            // A complete first window can wait for its client. Starting a
            // continuation here would consume media without a reader.
            if error == nil, let expectedBodyBytes, deliveredBodyBytes == expectedBodyBytes {
                heldOriginalCompletion = true
            } else {
                finish(with: error ?? URLError(.cannotParseResponse), source: "originalPreparationIncomplete")
            }
            return
        }
        completeMediaBody(after: error)
    }

    private func completeMediaBody(after error: Error?) {
        if retryInterruptedTransfer(after: error) {
            return
        }
        guard error == nil else {
            finish(with: error)
            return
        }
        // A HEAD completes after the headers. Its zero body bytes must never
        // advance an open-ended Range or repeat the first upstream request.
        if method == "GET",
           continueChunkedMediaResponseIfNeeded() || continueContinuousRangeResponseIfNeeded() {
            return
        }
        bufferLock.lock()
        upstreamCompleted = true
        bufferLock.unlock()
        drainBufferedBody()
    }

    private func sendPlaylist() {
        guard let connection, !isFinished else { return }
        if playlistStatusCode == 200, activeRequestedRange == nil, let token = playlistToken {
            vodPlaylistCache.store(playlistBody, route: token, url: upstreamURL)
            if let text = String(data: playlistBody, encoding: .utf8),
               let uri = PlaybackVODPlaylistCache.singleVariantURI(in: text),
               let child = playlistContext.resolve(uri) {
                vodPlaylistCache.storeMaster(playlistBody, route: token, url: upstreamURL, childURL: child)
            }
        }
        let rewriteStarted = Date()
        let body = rewritePlaylist(playlistBody)
        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished", details: diagnosticDetails([
                "stage": "playlistRewritten", "inputBytes": String(playlistBody.count),
                "outputBytes": String(body.count),
                "rewriteMs": String(Int(Date().timeIntervalSince(rewriteStarted) * 1_000))
            ].merging(PlaybackHLSRequestDiagnostics.playlistFields(String(decoding: playlistBody, as: UTF8.self))) { _, new in new }))
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
            self.bufferLock.lock()
            self.playlistDeliveryDiagnostics.headerCompleted()
            let headerEvidence = self.playlistDeliveryDiagnostics.fields(upstreamReceived: self.playlistBody.count)
            self.bufferLock.unlock()
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished",
                details: self.diagnosticDetails(headerEvidence.merging([
                    "stage": "playlistClientHeaderSendCompleted",
                    "callbackAfterClientFinish": String(self.isFinished)
                ]) { _, new in new }))
            connection.send(content: body, isComplete: true, completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                if let error { self.finish(with: error) } else {
                    self.bufferLock.lock()
                    self.playlistDeliveryDiagnostics.bodyCompleted(bytes: body.count)
                    let bodyEvidence = self.playlistDeliveryDiagnostics.fields(upstreamReceived: self.playlistBody.count)
                    self.bufferLock.unlock()
                    DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.proxy_transfer_finished",
                        details: self.diagnosticDetails(bodyEvidence.merging([
                            "stage": "playlistClientBodySendCompleted",
                            "callbackAfterClientFinish": String(self.isFinished)
                        ]) { _, new in new }))
                    self.finish(with: nil)
                }
            })
        })
    }

    fileprivate static func authenticationToken(from url: URL) -> String? {
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
        return Data(PlaybackHLSStartOffset.applying(playlistStartSeconds,
            to: lines.joined(separator: "\n")).utf8)
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
        guard let identifier = playlistChildren.identifier(for: uri, context: playlistContext) else { return nil }
        return "http://127.0.0.1:\(port.rawValue)/media/\(token)/child/\(identifier)"
    }

    private func drainBufferedBody() {
        guard let connection else { return }
        var chunk: Data?
        var originalPrefixBytes = 0
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
            originalPrefixBytes = min(chunk?.count ?? 0, pendingOriginalPrefixBytes)
            pendingOriginalPrefixBytes -= originalPrefixBytes
            isSendingBody = true
        }
        if pendingBodyBytes <= lowWaterMark, let suspendedDataTask {
            taskToResume = suspendedDataTask
            self.suspendedDataTask = nil
            if let suspendedSinceUptime {
                upstreamSuspendedSeconds += max(ProcessInfo.processInfo.systemUptime - suspendedSinceUptime, 0)
                self.suspendedSinceUptime = nil
            }
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
            let cachedBytes = originalPrefixBytes
            let wireChunk: Data
            if clientUsesChunkedMediaResponse {
                wireChunk = Data("\(String(chunk.count, radix: 16))\r\n".utf8)
                    + chunk
                    + Data("\r\n".utf8)
            } else {
                wireChunk = chunk
            }
#if DEBUG
            let delay = DebugMediaDeliveryThrottle.shared.deliveryDelay(
                bytes: chunk.count,
                isMedia: method == "GET" && !isPlaylist
                    && (!isHLSChildRequest || hlsRole == "segment"))
            bufferLock.lock()
            if delay > 0 {
                let now = ProcessInfo.processInfo.systemUptime
                if firstShapedSendAt == nil { firstShapedSendAt = now }
                if shapedWindowStartedAt == nil { shapedWindowStartedAt = now }
            } else {
                shapedWindowStartedAt = nil
                shapedWindowBytes = 0
            }
            bufferLock.unlock()
#endif
            let send = { [weak self] in
                guard let self else { return }
                guard !self.isFinished else { return }
                connection.send(content: wireChunk, completion: .contentProcessed { [weak self] error in
                    guard let self else { return }
                    if let error {
                        self.finish(with: error, source: "clientBodySend")
                        return
                    }
                    if cachedBytes > 0 {
                        DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                            messageKey: "diagnostics.media.proxy_transfer_finished", details: self.diagnosticDetails([
                                "stage": self.preparesOriginalResponse ? "originalResponsePreparedBytesDelivered"
                                    : "originalPrefixDelivered",
                                "bytes": String(cachedBytes),
                                "measurementBoundary": "clientDeliveryFromPreload"
                            ]))
                    }
#if DEBUG
                    var shapedWindow: (bytes: Int64, seconds: TimeInterval)?
                    let deliveredAt = ProcessInfo.processInfo.systemUptime
                    self.bufferLock.lock()
                    if self.firstShapedSendAt != nil { self.shapedBodyBytes += Int64(chunk.count) }
                    if delay > 0, let startedAt = self.shapedWindowStartedAt {
                        self.shapedWindowBytes += Int64(chunk.count)
                        // Open-ended originals can outlive the entire test.
                        // Publish actual capped delivery before connection EOF;
                        // never treat this fixture as upstream network capacity.
                        if self.shapedWindowBytes >= 8 * 1024 * 1024 {
                            shapedWindow = (self.shapedWindowBytes, deliveredAt - startedAt)
                            self.shapedWindowBytes = 0
                            self.shapedWindowStartedAt = deliveredAt
                        }
                    }
                    self.bufferLock.unlock()
                    if !self.upstreamIsNetworkLibraryBridge, let window = shapedWindow, window.seconds >= 0.25 {
                        PlaybackRecentThroughputStore.shared.record(
                            traceID: self.playbackTraceID, bytes: window.bytes,
                            seconds: window.seconds, backpressureSeconds: 0, now: deliveredAt)
                        DiagnosticLogStore.shared.record(.info,
                            categoryKey: "diagnostics.category.media",
                            messageKey: "diagnostics.media.proxy_transfer_finished",
                            details: self.diagnosticDetails([
                                "stage": "debugThrottleWindow",
                                "measurementBoundary": "cappedClientDelivery",
                                "bytes": String(window.bytes),
                                "elapsedMs": String(Int(window.seconds * 1_000)),
                                "effectiveBps": String(Int(Double(window.bytes) * 8 / window.seconds))]))
                    }
#endif
                    self.bufferLock.lock()
                    self.isSendingBody = false
                    self.bufferLock.unlock()
                    self.drainBufferedBody()
                })
            }
#if DEBUG
            if delay > 0 {
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + delay, execute: send)
            } else {
                send()
            }
#else
            send()
#endif
        } else if shouldClose {
            let terminalChunk = method == "GET" && clientUsesChunkedMediaResponse
                ? Data("0\r\n\r\n".utf8)
                : nil
            connection.send(content: terminalChunk, isComplete: true, completion: .contentProcessed { [weak self] error in
                self?.finish(with: error, source: "clientTerminalSend")
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
        let end = nextOffset + min(maximumMediaSegmentBytes - 1, total - 1 - nextOffset)
        let nextRange = "bytes=\(nextOffset)-\(end)"
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
        let end = nextOffset + min(maximumMediaSegmentBytes - 1, total - 1 - nextOffset)
        let nextRange = "bytes=\(nextOffset)-\(end)"
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
            nextOffset + min(maximumMediaSegmentBytes - 1, max(total - 1 - nextOffset, 0))
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

    private func rejectClientRange(totalLength: Int64? = nil) {
        guard let connection else {
            finish(with: URLError(.badURL), source: "originalPreparationInvalidRange")
            return
        }
        lastStatusCode = 416
        let lengthHeader = totalLength.map { "Content-Range: bytes */\($0)\r\n" } ?? ""
        let response = "HTTP/1.1 416 Range Not Satisfiable\r\n\(lengthHeader)Content-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), isComplete: true,
            completion: .contentProcessed { [weak self] _ in
                self?.finish(with: URLError(.badURL), source: "invalidOrUnsatisfiableRange")
            })
    }

    private func rejectUpstreamResponse() {
        guard let connection else {
            finish(with: URLError(.cannotParseResponse), source: "originalPreparationRejected")
            return
        }
        guard !didSendResponseHeaders else {
            finish(with: URLError(.cannotParseResponse), source: "invalidContinuationResponse")
            return
        }
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

    private func transportErrorDetails(_ error: Error?) -> [String: String] {
        guard let error else { return ["transportErrorKind": "none"] }
        if let networkError = error as? NWError {
            switch networkError {
            case .posix(let code): return ["transportErrorKind": "posix", "transportErrorCode": String(code.rawValue)]
            case .dns(let code): return ["transportErrorKind": "dns", "transportErrorCode": String(code)]
            case .tls(let code): return ["transportErrorKind": "tls", "transportErrorCode": String(code)]
            @unknown default: return ["transportErrorKind": "unknown"]
            }
        }
        return ["transportErrorKind": "other", "transportErrorCode": String((error as NSError).code)]
    }

    private func finish(with error: Error?, source: String = #function) {
        finishLock.lock()
        guard !finished else {
            finishLock.unlock()
            return
        }
        finished = true
        finishLock.unlock()
        bufferLock.lock()
#if DEBUG
        let shapedStart = firstShapedSendAt
        let shapedBytes = shapedBodyBytes
#endif
        taskDiagnostics.clientFinished(
            backpressure: upstreamSuspendedSeconds
                + (suspendedSinceUptime.map { max(ProcessInfo.processInfo.systemUptime - $0, 0) } ?? 0),
            suspendCount: upstreamSuspendCount, queuedBytes: pendingBodyBytes)
        suspendedDataTask = nil
        suspendedSinceUptime = nil
        pendingBodyChunks.removeAll(keepingCapacity: false)
        pendingBodyBytes = 0
        let playlistDeliveryEvidence = isPlaylist
            ? playlistDeliveryDiagnostics.fields(upstreamReceived: playlistBody.count) : [:]
        bufferLock.unlock()
#if DEBUG
        if !upstreamIsNetworkLibraryBridge, error == nil, let shapedStart, shapedBytes >= 1_048_576 {
            let elapsed = ProcessInfo.processInfo.systemUptime - shapedStart
            PlaybackRecentThroughputStore.shared.record(
                traceID: playbackTraceID, bytes: shapedBytes,
                seconds: elapsed, backpressureSeconds: 0,
                now: ProcessInfo.processInfo.systemUptime)
            DiagnosticLogStore.shared.record(.info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished",
                details: diagnosticDetails(["stage": "debugThrottleMeasured",
                    "bytes": String(shapedBytes),
                    "elapsedMs": String(Int(elapsed * 1_000)),
                    "effectiveBps": String(Int(Double(shapedBytes) * 8 / max(elapsed, 0.001)))])
            )
        }
#endif
        let terminalDetails: [String: String] = [
                "status": lastStatusCode.map(String.init) ?? "-",
                "finishSource": source,
                "errorDomain": error.map { ($0 as NSError).domain } ?? "-",
                "errorCode": error.map { String(($0 as NSError).code) } ?? "-",
                "taskReceivedBytes": task.flatMap {
                    taskDiagnostics.callback(taskID: $0.taskIdentifier).map { String($0.receivedBodyBytes) }
                } ?? "unknown",
                "responseStartOffset": responseStartOffset.map(String.init) ?? "-",
                "responseEndOffset": responseEndOffset.map(String.init) ?? "-",
                "range": activeRequestedRange ?? "-",
                "deliveredBytes": "\(isPlaylist ? Int64(playlistBody.count) : deliveredBodyBytes)",
                "expectedBytes": (isPlaylist ? playlistExpectedBodyBytes : expectedBodyBytes)
                    .map(String.init) ?? "-",
                "durationMs": "\(Int(Date().timeIntervalSince(startedAt) * 1_000))",
                "retries": "\(retryAttempts)",
                "result": error?.localizedDescription ?? "complete"
        ]
        let terminalWithTransport = terminalDetails.merging(transportErrorDetails(error)) { _, new in new }
            .merging(playlistDeliveryEvidence) { _, new in new }
        DiagnosticLogStore.shared.record(
            error == nil ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.proxy_transfer_finished",
            details: diagnosticDetails(terminalWithTransport)
        )
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        if let task, task.state != .completed {
            taskDiagnostics.cancellationRequested(now: ProcessInfo.processInfo.systemUptime)
            DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.proxy_transfer_finished",
                details: diagnosticDetails(["stage": "upstreamCancellationRequested"]))
        }
        task?.cancel()
        task = nil
        if !usesSharedTransport { session?.invalidateAndCancel() }
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

final class FilePreviewTrustDelegate: NSObject, URLSessionDelegate {
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
        allowsSelfSignedCertificates: Bool,
        timeoutInterval: TimeInterval = 20
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
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = min(180, timeoutInterval * 9)
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
                .nastartPageTheme()
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
            }.nastartListSection()

            Section {
                LabeledContent("devices.network.primary_domain", value: endpointSummary(endpoints?.primaryDomain))
                LabeledContent("devices.network.lan_address", value: endpointSummary(endpoints?.lanAddress))
                LabeledContent("devices.network.public_address", value: endpointSummary(endpoints?.publicAddress))
            } header: {
                Text("devices.network.endpoints")
            }.nastartListSection()

            Section {
                LabeledContent("devices.network.online_count", value: "\(reachableEntries.count)")
                LabeledContent("devices.network.proxy_count", value: "\(reverseProxyCount)")
            } header: {
                Text("devices.network.summary")
            }.nastartListSection()

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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
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
            }.nastartListSection()

            Section {
                LabeledContent("devices.security.ssh", value: sshStatusText(device.sshStatus))
            } footer: {
                Text("devices.security.ssh.footer")
            }.nastartListSection()

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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .padding(.top, -12)
        .nastartReadableWidth().nastartPageTheme()
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
            }.nastartListSection()

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
            }.nastartListSection()

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
            }.nastartListSection()
        }
        .listStyle(.insetGrouped)
        .nastartReadableWidth().nastartPageTheme()
        .navigationTitle("devices.maintenance.agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// DSM and macOS bookkeeping such as `#recycle`, `@eaDir` and `.fseventsd`.
enum FileBrowserSystemItems {
    static func isSystemItem(named name: String) -> Bool {
        name.hasPrefix(".") || name.hasPrefix("#") || name.hasPrefix("@")
    }
}

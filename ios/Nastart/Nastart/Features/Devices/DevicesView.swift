import SwiftUI

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
                            MetricPillSpec("metric.memory", value: dataStore.device.memoryDisplayText, progress: dataStore.device.memory),
                            MetricPillSpec("metric.storage", value: dataStore.device.storageDisplayText, progress: dataStore.device.storageUsed)
                        ])
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        DeviceStatusView(device: dataStore.device)
                    } label: {
                        Label("devices.resource.overview", systemImage: "chart.line.uptrend.xyaxis")
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
                        NetworkDetailView(services: dataStore.services)
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
                VStack(alignment: .leading, spacing: 14) {
                    Text("devices.status.title")
                        .font(.title2.weight(.bold))
                    MetricPillRow(metrics: [
                        MetricPillSpec("metric.cpu", value: devicePercentText(device.cpu), progress: device.cpu),
                        MetricPillSpec("metric.memory", value: device.memoryDisplayText, progress: device.memory),
                        MetricPillSpec("metric.storage", value: device.storageDisplayText, progress: device.storageUsed)
                    ])
                }
                .padding(.vertical, 4)
            }

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
                LabeledContent("metric.memory", value: device.memoryDisplayText)
                LabeledContent("metric.storage", value: device.storageDisplayText)
                LabeledContent("devices.detail.certificate", value: certificateDaysText(device.certificateDaysRemaining))
                LabeledContent("devices.status.temperature", value: device.temperatureText ?? "-")
                LabeledContent("devices.security.ssh", value: sshStatusText(device.sshStatus))
            } header: {
                Text("devices.detail.status")
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
                LabeledContent("metric.cpu", value: devicePercentText(container.cpu))
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
                if portRows.isEmpty {
                    Text("devices.network.ports.empty")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(portRows, id: \.self) { row in
                        LabeledContent(row.service, value: row.port)
                    }
                }
            } header: {
                Text("devices.network.ports")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.resource.network")
    }

    private var portRows: [ServicePortRow] {
        services.flatMap { service in
            let ports = service.ports.isEmpty
                ? service.endpoint?.port.map { ["\($0)"] } ?? []
                : service.ports
            return ports.map { ServicePortRow(service: service.name, port: $0) }
        }
    }
}

private struct ServicePortRow: Hashable {
    let service: String
    let port: String
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
    var body: some View {
        List {
            Section {
                LabeledContent(
                    "devices.agent.mode",
                    value: NSLocalizedString("state.not_connected", comment: "")
                )
            }

            Section {
                Label("devices.agent.not_connected", systemImage: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("devices.maintenance.agent")
        .navigationBarTitleDisplayMode(.inline)
    }
}

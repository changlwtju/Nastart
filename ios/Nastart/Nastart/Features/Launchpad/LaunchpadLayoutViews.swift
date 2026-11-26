import SwiftUI
import JellyfinAPI
import NetworkMedia

struct LaunchpadDisplayOptions {
    let compactMetrics: Bool
    let showServiceStatus: Bool
    let showSubtitle: Bool
}

struct LaunchpadDataStatusBanner: View {
    let state: AppDataRefreshState
    let sourceKey: String
    let dsmConnected: Bool
    var cachedAt: Date? = nil
    let retry: () -> Void

    var body: some View {
        Button(action: retry) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .frame(width: 30, height: 30)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(titleKey)
                        .font(.subheadline.weight(.semibold))
                    if let cachedAt, state == .cached || state == .stale {
                        Text(LaunchpadCachedTime.text(cachedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(LocalizedStringKey(sourceKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !dsmConnected {
                        Text("data.refresh.services_independent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: dsmConnected ? "arrow.clockwise" : "link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nastartSurface()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text(dsmConnected ? "action.refresh" : "connect.welcome.action"))
    }

    private var titleKey: LocalizedStringKey {
        switch state {
        case .cached: return "data.refresh.cached"
        case .stale: return "data.refresh.stale"
        case .unavailable: return "data.refresh.unavailable"
        case .refreshing: return "data.refresh.scanning_services"
        case .localPreview, .current: return "data.refresh.ready"
        }
    }

    private var symbolName: String {
        switch state {
        case .cached: return "clock"
        case .stale: return "exclamationmark.triangle"
        case .unavailable: return "wifi.slash"
        case .localPreview, .current, .refreshing: return "info.circle"
        }
    }

    private var color: Color {
        switch state {
        case .cached: return .orange
        case .stale, .unavailable: return .red
        case .localPreview, .current, .refreshing: return .secondary
        }
    }
}

struct LaunchpadAgentHealthText {
    let titleKey: String
    let detailKey: String?

    init(state: AgentHealthState, failureReasonKey: String?) {
        switch state {
        case .connected:
            titleKey = "agent.health.connected"
            detailKey = nil
        case .stale:
            titleKey = "devices.agent.state.stale"
            detailKey = "devices.agent.state.stale_detail"
        case .failed:
            titleKey = "devices.agent.state.failed"
            switch failureReasonKey {
            case "agent.health.identity_changed", "agent.health.auth_failed", "agent.health.unsupported",
                 "agent.health.invalid_address", "agent.health.unreachable":
                detailKey = failureReasonKey
            default:
                detailKey = "agent.health.unknown"
            }
        }
    }
}

struct LaunchpadAgentHealthRow: View {
    let health: AgentHealthSnapshot?
    let repair: () -> Void
    @State private var refreshedAtExpiry: Date?

    var body: some View {
        if let health {
            let expiry = health.lastSeenAt?.addingTimeInterval(AgentHealthSnapshot.staleInterval)
            statusContent(state: health.state, failureReasonKey: health.failureReasonKey)
                .id(refreshedAtExpiry)
                .task(id: expiry) {
                    guard let expiry, expiry > Date() else { return }
                    do {
                        try await Task.sleep(for: .seconds(expiry.timeIntervalSinceNow))
                        refreshedAtExpiry = expiry
                    } catch {
                        // The snapshot changed or the row left the screen.
                    }
                }
        }
    }

    private func statusContent(state: AgentHealthState, failureReasonKey: String?) -> some View {
        let text = LaunchpadAgentHealthText(state: state, failureReasonKey: failureReasonKey)
        let symbol: String
        let color: Color
        switch state {
        case .connected:
            symbol = "checkmark.circle.fill"
            color = .green
        case .stale:
            symbol = "clock"
            color = .orange
        case .failed:
            symbol = "exclamationmark.circle.fill"
            color = .red
        }
        return VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(text.titleKey))
                        .font(.subheadline.weight(.semibold))
                    if let detailKey = text.detailKey {
                        Text(LocalizedStringKey(detailKey))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: symbol)
                    .foregroundStyle(color)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("launchpad.agent.health")

            if state == .failed {
                Button("agent.action.repair", action: repair)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("launchpad.agent.repair")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .nastartSurface()
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

enum LaunchpadReminderPolicy {
    static let certificateWarningDays = 14
}

struct CommandCenterLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let isConnected: Bool
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeviceSummaryPanel(device: device, compact: options.compactMetrics, isConnected: isConnected, theme: .commandCenter)
            LaunchpadMediaShortcuts()

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(titleKey: "launchpad.command.quick_actions", trailingKey: "launchpad.section.generated")
                ForEach(categories) { category in
                    let categoryServices = services.filter { $0.category == category }
                    if !categoryServices.isEmpty {
                        CommandCategorySection(category: category, services: categoryServices, options: options, initiallyExpanded: groupDefaultExpanded(category))
                    }
                }
            }

            if shouldShowCertificateReminder {
                NavigationLink {
                    DeviceStatusView(device: device)
                } label: {
                    CertificateReminderStrip(days: device.certificateDaysRemaining ?? 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shouldShowCertificateReminder: Bool {
        guard let days = device.certificateDaysRemaining else { return false }
        return days <= LaunchpadReminderPolicy.certificateWarningDays
    }
}

private struct CommandCategorySection: View {
    let category: ServiceCategory
    let services: [LaunchpadService]
    let options: LaunchpadDisplayOptions
    @State private var isExpanded: Bool

    init(category: ServiceCategory, services: [LaunchpadService], options: LaunchpadDisplayOptions, initiallyExpanded: Bool) {
        self.category = category
        self.services = services
        self.options = options
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(category.titleKey))
                        .font(.subheadline.weight(.medium))
                    Text("\(services.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 2)

            if isExpanded {
                LaunchpadServiceColumns(spacing: 8) {
                    ForEach(services) { service in
                        CommandServiceRailRow(service: service, options: options)
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                } label: {
                    CommandCollapsedGroupRow(category: category, services: services)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// iPad 等宽屏上服务卡片排成两列（分组多为 1～3 个服务，三列会留出大片空白）；iPhone 和无障碍字号仍是单列。
/// 分组标题和折叠行仍占整行，排序、隐藏和折叠逻辑不变。
private struct LaunchpadServiceColumns<Content: View>: View {
    let spacing: CGFloat
    /// 窄屏时沿用各主题原来的容器：默认主题是 `LazyVStack`，另两个是 `VStack`。
    var lazy = false
    @ViewBuilder let content: Content
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if widthClass == .regular && !typeSize.isAccessibilitySize {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: 2),
                      alignment: .leading, spacing: spacing) { content }
        } else if lazy {
            LazyVStack(spacing: spacing) { content }
        } else {
            VStack(spacing: spacing) { content }
        }
    }
}

private struct CommandCollapsedGroupRow: View {
    let category: ServiceCategory
    let services: [LaunchpadService]

    var body: some View {
        HStack(spacing: 10) {
            CollapsedCategoryIcon(category: category, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(category.titleKey))
                    .font(.body.weight(.medium))
                CollapsedServiceNames(services: services)
            }
            Spacer()
            Text("launchpad.group.collapsed_hint")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .nastartSurface()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct CommandServiceRailRow: View {
    let service: LaunchpadService
    let options: LaunchpadDisplayOptions
    @EnvironmentObject private var dataStore: AppDataStore

    private var displayedStatus: ServiceStatus {
        service.source == .dsm && service.name == "DSM"
            && !dataStore.isDSMReachable && !dataStore.isRestoringConnection
            ? .warning : service.status
    }

    var body: some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            HStack(spacing: 12) {
                ServiceIconView(service: service, size: 38)

                VStack(alignment: .leading, spacing: 4) {
                    Text(service.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    if options.showSubtitle {
                        Text(LocalizedStringKey(service.detail))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if options.showServiceStatus {
                    StatusDot(status: displayedStatus)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .nastartSurface()
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .contextMenu {
            Button(role: .destructive) {
                dataStore.setService(service, visibleOnLaunchpad: false)
            } label: {
                Label("launchpad.service.hide", systemImage: "eye.slash")
            }
        }
    }
}

struct GlassDeckLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let isConnected: Bool
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSummaryPanel(device: device, compact: options.compactMetrics, isConnected: isConnected, theme: .glassDeck)
            LaunchpadMediaShortcuts()

            if shouldShowCertificateReminder {
                NavigationLink {
                    DeviceStatusView(device: device)
                } label: {
                    CertificateReminderStrip(days: device.certificateDaysRemaining ?? 0)
                }
                .buttonStyle(.plain)
            }

            ForEach(categories) { category in
                let categoryServices = services.filter { $0.category == category }
                if !categoryServices.isEmpty {
                    GlassGroupSection(category: category, services: categoryServices, options: options, initiallyExpanded: groupDefaultExpanded(category))
                }
            }
        }
    }

    private var shouldShowCertificateReminder: Bool {
        guard let days = device.certificateDaysRemaining else { return false }
        return days <= LaunchpadReminderPolicy.certificateWarningDays
    }
}

private struct GlassGroupSection: View {
    let category: ServiceCategory
    let services: [LaunchpadService]
    let options: LaunchpadDisplayOptions
    @State private var isExpanded: Bool

    init(category: ServiceCategory, services: [LaunchpadService], options: LaunchpadDisplayOptions, initiallyExpanded: Bool) {
        self.category = category
        self.services = services
        self.options = options
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(category.titleKey))
                        .font(.subheadline.weight(.medium))
                    Text("\(services.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 2)

            if isExpanded {
                LaunchpadServiceColumns(spacing: 11) {
                    ForEach(services) { service in
                        GlassServiceRow(service: service, options: options)
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                } label: {
                    GlassCollapsedGroupRow(category: category, services: services)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GlassCollapsedGroupRow: View {
    let category: ServiceCategory
    let services: [LaunchpadService]

    var body: some View {
        HStack(spacing: 12) {
            CollapsedCategoryIcon(category: category, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(category.titleKey))
                    .font(.body.weight(.medium))
                CollapsedServiceNames(services: services)
            }
            Spacer()
            Text("\(services.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .nastartSurface()
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }
}

enum LaunchpadResourceWarning {
    case storageTight
    case memoryPressure
    case cpuPressure
    case certificateExpiring

    var titleKey: String {
        switch self {
        case .storageTight: return "launchpad.warning.storage_tight"
        case .memoryPressure: return "launchpad.warning.memory_pressure"
        case .cpuPressure: return "launchpad.warning.cpu_pressure"
        case .certificateExpiring: return "launchpad.warning.certificate_expiring"
        }
    }

    var symbolName: String {
        switch self {
        case .storageTight: return "internaldrive"
        case .memoryPressure: return "memorychip"
        case .cpuPressure: return "cpu"
        case .certificateExpiring: return "lock.shield"
        }
    }

    static func primary(for device: NASDevice) -> LaunchpadResourceWarning? {
        if device.storageUsed.map({ $0 >= 0.9 }) == true {
            return .storageTight
        }
        if device.memory.map({ $0 >= 0.9 }) == true {
            return .memoryPressure
        }
        if device.cpu.map({ $0 >= 0.9 }) == true {
            return .cpuPressure
        }
        if device.certificateDaysRemaining.map({ $0 <= LaunchpadReminderPolicy.certificateWarningDays }) == true {
            return .certificateExpiring
        }
        return nil
    }
}

private struct GlassServiceRow: View {
    let service: LaunchpadService
    let options: LaunchpadDisplayOptions
    @EnvironmentObject private var dataStore: AppDataStore

    private var displayedStatus: ServiceStatus {
        service.source == .dsm && service.name == "DSM"
            && !dataStore.isDSMReachable && !dataStore.isRestoringConnection
            ? .warning : service.status
    }

    var body: some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            HStack(spacing: 14) {
                ServiceIconView(service: service, size: 42)
                VStack(alignment: .leading, spacing: 5) {
                    Text(service.name)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                    if options.showSubtitle {
                        Text(LocalizedStringKey(service.detail))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
                Spacer()
                if options.showServiceStatus {
                    StatusDot(status: displayedStatus)
                }
            }
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .nastartSurface()
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.045), radius: 12, y: 6)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                dataStore.setService(service, visibleOnLaunchpad: false)
            } label: {
                Label("launchpad.service.hide", systemImage: "eye.slash")
            }
        }
    }
}

struct ProductLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let isConnected: Bool
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            DeviceSummaryPanel(device: device, compact: options.compactMetrics, isConnected: isConnected)
            LaunchpadMediaShortcuts()

            if shouldShowCertificateReminder {
                NavigationLink {
                    DeviceStatusView(device: device)
                } label: {
                    CertificateReminderStrip(days: device.certificateDaysRemaining ?? 0)
                }
                .buttonStyle(.plain)
            }

            ForEach(categories) { category in
                let categoryServices = services.filter { $0.category == category }
                if !categoryServices.isEmpty {
                    ServiceGroupSection(category: category, services: categoryServices, options: options, initiallyExpanded: groupDefaultExpanded(category))
                }
            }
        }
    }

    private var shouldShowCertificateReminder: Bool {
        guard let days = device.certificateDaysRemaining else { return false }
        return days <= LaunchpadReminderPolicy.certificateWarningDays
    }
}

private struct ServiceGroupSection: View {
    let category: ServiceCategory
    let services: [LaunchpadService]
    let options: LaunchpadDisplayOptions
    @State private var isExpanded: Bool

    init(category: ServiceCategory, services: [LaunchpadService], options: LaunchpadDisplayOptions, initiallyExpanded: Bool) {
        self.category = category
        self.services = services
        self.options = options
        _isExpanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(category.titleKey))
                        .font(.subheadline.weight(.medium))
                    Text("\(services.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 2)

            if isExpanded {
                LaunchpadServiceColumns(spacing: 10, lazy: true) {
                    ForEach(services) { service in
                        ServiceListRow(service: service, options: options)
                    }
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded = true
                    }
                } label: {
                    CollapsedServicePreview(category: category, services: services)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CollapsedServicePreview: View {
    let category: ServiceCategory
    let services: [LaunchpadService]

    var body: some View {
        HStack(spacing: 10) {
            CollapsedCategoryIcon(category: category, size: 30)
            CollapsedServiceNames(services: services)
            Spacer()
            Text("launchpad.group.collapsed_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(11)
        .nastartCard(cornerRadius: 16)
    }
}

private struct CollapsedCategoryIcon: View {
    let category: ServiceCategory
    let size: CGFloat

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.system(size: size * 0.42, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(width: size, height: size)
            .background(AppTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct CollapsedServiceNames: View {
    let services: [LaunchpadService]

    var body: some View {
        Text(summary)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    private var summary: String {
        let visibleNames = services.prefix(2).map(\.name).joined(separator: " · ")
        let remaining = services.count - min(services.count, 2)
        return remaining > 0 ? "\(visibleNames) · +\(remaining)" : visibleNames
    }
}

private struct ServiceListRow: View {
    let service: LaunchpadService
    let options: LaunchpadDisplayOptions
    @EnvironmentObject private var dataStore: AppDataStore

    private var needsDSMLogin: Bool {
        service.source == .dsm && service.name == "DSM"
            && !dataStore.isDSMReachable && !dataStore.isRestoringConnection
    }

    private var displayedStatus: ServiceStatus {
        needsDSMLogin ? .warning : service.status
    }

    var body: some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            HStack(alignment: .center, spacing: 13) {
                ServiceIconView(service: service, size: 38)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(service.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        if options.showServiceStatus {
                            ServiceStatusBadge(
                                status: displayedStatus,
                                titleKey: needsDSMLogin ? "service.dsm.login_required" : nil
                            )
                        }
                    }
                    if options.showSubtitle {
                        Text(LocalizedStringKey(service.detail))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                }
                .layoutPriority(1)

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                dataStore.setService(service, visibleOnLaunchpad: false)
            } label: {
                Label("launchpad.service.hide", systemImage: "eye.slash")
            }
        }
    }

    private var rowBackground: some ShapeStyle {
        AnyShapeStyle(Color(.systemBackground))
    }
}

private struct ServiceStatusBadge: View {
    let status: ServiceStatus
    var titleKey: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            // The title beside it already speaks the status to VoiceOver.
            StatusDot(status: status).accessibilityHidden(true)
            Text(LocalizedStringKey(titleKey ?? status.titleKey))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .nastartSurface()
        .clipShape(Capsule())
    }
}

/// Uses the same live File Station root and media router as the Device/service pages.
struct LaunchpadMediaShortcuts: View {
    @EnvironmentObject private var appearance: AppearanceStore
    @EnvironmentObject private var entitlement: EntitlementStore
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connection: NASConnectionStore
    @EnvironmentObject private var router: MediaLibraryRouter
    private var libraries: [LaunchpadService] {
        dataStore.uniqueLaunchpadServices(dataStore.services.filter { $0.isJellyfin && !$0.isDeveloperConsole })
    }
    var body: some View {
        NavigationLink {
            networkMediaLibraryView(nas: networkNASContext, appearance: networkAppearance, services: networkServicesContext,
                destinations: NetworkMediaDestinations(files: AnyView(fileDestination), media: AnyView(LaunchpadMediaDestinations(libraries: libraries)),
                    playback: { source, close in
                        AnyView(NetworkLibraryPlayerPresentation(source: source, close: close))
                    }, credits: networkCreditsContext, resumeSeconds: { id in
                        LocalPlaybackResumeStore.shared.entry(for: "network-file:" + id)?.positionSeconds
                    }))
                .id(connection.dsmSession?.authenticationGeneration)
                .task {
                    DiagnosticLogStore.shared.record(.info, categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.network_media.credits_context", details: networkCreditsEvidence)
                }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.wifi")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text("存储与媒体").font(.headline)
                    Text("浏览文件 · 整理媒体库").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(16)
                .nastartCard(cornerRadius: 18)
        }.buttonStyle(.plain).accessibilityIdentifier("launchpad.open.networkLibrary")
    }
    @ViewBuilder private var fileDestination: some View {
        if connection.dsmSession != nil {
            FileBrowserView(titleKey: "devices.resource.files", items: dataStore.files, folderPath: "/")
        } else { DSMConnectionFlowView(onConnected: {}) }
    }
    private var networkCreditsEvidence: [String: String] {
        let endpoints = libraries.flatMap { JellyfinSessionEndpointPolicy.configuredEndpoints(for: $0, dsmBaseURL: connection.dsmSession?.baseURL) }
        let saved = endpoints.compactMap { KeychainStore.shared.loadJellyfinSession(endpoint: $0) }
        let consistent = saved.first.map { first in saved.allSatisfy { $0.userID == first.userID && $0.accessToken == first.accessToken } } ?? false
        return ["serviceCount": String(libraries.count), "endpointCount": String(endpoints.count),
                "savedLoginCount": String(saved.count), "consistentLogin": String(consistent),
                "adapterAvailable": String(networkCreditsContext != nil)]
    }
    private var networkCreditsContext: NetworkMediaCreditsContext? {
        let generation = connection.dsmSession?.authenticationGeneration
        // Use the same ordered, endpoint-scoped restoration as the Jellyfin
        // entry. Separate logins legitimately have different tokens. Never
        // copy the selected token to an alternate route or guess across services.
        guard libraries.count == 1, let service = libraries.first else { return nil }
        let endpoints = JellyfinSessionEndpointPolicy.candidates(from:
            JellyfinSessionEndpointPolicy.configuredEndpoints(for: service, dsmBaseURL: connection.dsmSession?.baseURL))
        let candidates = endpoints.compactMap { endpoint -> (URL, StoredJellyfinSession)? in
            guard let saved = KeychainStore.shared.loadJellyfinSession(endpoint: endpoint),
                  !saved.accessToken.isEmpty, !saved.userID.isEmpty else { return nil }
            return (endpoint, saved)
        }
        guard let (endpoint, saved) = candidates.first else { return nil }
        let certificate = ServiceCertificatePolicy.allowsBypass(for: endpoint, session: connection.dsmSession)
            ? CertificatePinStore.shared.trustedCertificateData(host: endpoint.host, port: endpoint.port) : nil
        guard let source = try? JellyfinCreditsSource(endpoint: endpoint, userID: saved.userID, token: saved.accessToken, trustedCertificate: certificate) else { return nil }
        return NetworkMediaCreditsContext(source: source) {
            guard connection.dsmSession?.authenticationGeneration == generation,
                  let current = KeychainStore.shared.loadJellyfinSession(endpoint: endpoint) else { return false }
            return current.userID == saved.userID && current.accessToken == saved.accessToken
        }
    }
    private var networkServicesContext: NetworkMediaServicesContext {
        let session = connection.dsmSession
        let matches = dataStore.serviceInventoryMatches(session)
        let inventory: MediaServiceInventory = !matches ? .unavailable : (!dataStore.isDSMReachable ? .cached : (dataStore.serviceInventoryIsComplete ? .available : .partial))
        let services = matches ? dataStore.services : dataStore.services.filter { $0.source == .manual }
        let candidates = services.compactMap { service -> MediaServiceCandidate? in
            guard let product = MediaServiceProduct.hint(name: service.name, detail: service.detail) else { return nil }
            let endpoints = product == .jellyfin
                ? JellyfinSessionEndpointPolicy.candidates(from: JellyfinSessionEndpointPolicy.configuredEndpoints(for: service, dsmBaseURL: session?.baseURL))
                : [service.endpoint, service.alternateEndpoint].compactMap { $0 }
            let saved = product == .jellyfin ? endpoints.filter { endpoint in
                guard (try? MediaServiceEndpoint(endpoint)) != nil, let value = KeychainStore.shared.loadJellyfinSession(endpoint: endpoint) else { return false }
                return !value.accessToken.isEmpty && !value.userID.isEmpty
            } : []
            // A web-health result does not establish whether a container is running.
            return MediaServiceCandidate(id: service.id.uuidString, name: service.name, hint: product,
                running: nil, endpoints: saved + endpoints, savedLoginEndpoints: saved)
        }
        var trusted: [URL: Data] = [:]
        for endpoint in candidates.flatMap(\.endpoints).map(\.url) where ServiceCertificatePolicy.allowsBypass(for: endpoint, session: session) {
            if let data = CertificatePinStore.shared.trustedCertificateData(host: endpoint.host, port: endpoint.port) { trusted[endpoint] = data }
        }
        return NetworkMediaServicesContext(candidates: candidates, inventory: inventory, transport: PublicMediaServiceHTTP(trustedCertificates: trusted), savedLoginAvailable: { id, endpoint in
            guard connection.dsmSession?.authenticationGeneration == session?.authenticationGeneration,
                  candidates.contains(where: { $0.id == id && $0.hint == .jellyfin }) else { return false }
            return candidates.filter { $0.hint == .jellyfin }.flatMap(\.endpoints).map(\.url).contains { configured in
                guard MediaServiceEndpoint.matches(configured, endpoint), let saved = KeychainStore.shared.loadJellyfinSession(endpoint: configured) else { return false }
                return !saved.accessToken.isEmpty && !saved.userID.isEmpty
            }
        }, reloadInventory: {
            guard let session, connection.dsmSession?.authenticationGeneration == session.authenticationGeneration else { return nil }
            let completed = await dataStore.refreshDSM(session: session, useAgent: connection.usesAgent)
            guard !Task.isCancelled, connection.dsmSession?.authenticationGeneration == session.authenticationGeneration else { return nil }
            let current = networkServicesContext
            return completed ? current : current.withInventory(.cached)
        }) { id, requestedEndpoint in
            guard connection.dsmSession?.authenticationGeneration == session?.authenticationGeneration,
                  let service = services.first(where: { $0.id.uuidString == id }),
                  MediaServiceProduct.hint(name: service.name, detail: service.detail) == .jellyfin,
                  let candidate = candidates.first(where: { $0.id == id }),
                  let key = try? MediaServiceEndpoint(requestedEndpoint), candidate.endpoints.contains(key) else { return nil }
            let exact = candidates.filter { $0.hint == .jellyfin }.flatMap(\.endpoints).map(\.url)
                .filter { MediaServiceEndpoint.matches($0, requestedEndpoint) }
            let endpoint = exact.first(where: { KeychainStore.shared.loadJellyfinSession(endpoint: $0) != nil }) ?? requestedEndpoint
            return AnyView(JellyfinLibraryView(service: service, endpoint: endpoint,
                allowsSelfSignedCertificates: ServiceCertificatePolicy.allowsBypass(for: endpoint, session: session),
                dsmSession: session, dsmSharedFolderPaths: dataStore.files.filter { $0.isFolder }.map(\.path),
                fallbackEndpoints: candidate.endpoints.map(\.url), connectionStore: connection))
        }
    }
    private var networkAppearance: NetworkMediaAppearance {
        NetworkMediaAppearance(accent: AppTheme.accent, background: AnyView(NastartThemeBackground()),
            surface: AnyView(NastartSurfaceBackground()),
            commandStyle: appearance.launchpadTheme == .commandCenter && entitlement.canUse(.advancedThemes))
    }
    private var networkNASContext: NetworkNASContext? {
        guard let session = connection.dsmSession else { return nil }
        return NetworkNASContext(name: connection.connectedDevice?.name ?? String(localized: "当前 NAS"), address: session.baseURL.absoluteString,
                                 account: session.account) {
            guard connection.dsmSession?.authenticationGeneration == session.authenticationGeneration else { throw NetworkMediaError.fileStationUnavailable }
            return try FileStationSource(address: session.baseURL.absoluteString, sid: session.fileStationSID ?? session.sid,
                                         allowsSelfSignedCertificates: session.allowsSelfSignedCertificates) {
                try await MainActor.run {
                    guard let current = connection.dsmSession,
                          current.authenticationGeneration == session.authenticationGeneration,
                          current.fileStationGeneration == session.fileStationGeneration,
                          current.baseURL == session.baseURL else { throw NetworkMediaError.fileStationUnavailable }
                }
            }
        }
    }
}

/// Network-library originals use the same retained UIKit presentation as
/// device files and Jellyfin, including dismissal, orientation and PiP.
private struct NetworkLibraryPlayerPresentation: View {
    let source: NetworkMediaPlaybackSource
    let close: () -> Void
    @State private var request: GreenfieldPlaybackLaunchRequest?
    @State private var didPresent = false
    @State private var preparationFailed = false
    var body: some View {
        Color.black.ignoresSafeArea()
            .overlay {
                if !didPresent {
                    VStack(spacing: 16) {
                        if preparationFailed {
                            Text("无法准备此文件，请检查连接或重新整理媒体库。")
                                .multilineTextAlignment(.center)
                        } else {
                            ProgressView("正在准备播放")
                        }
                        Button(action: close) {
                            Text(preparationFailed ? LocalizedStringKey("返回") : LocalizedStringKey("取消"))
                        }
                        .accessibilityIdentifier("network.player.close")
                    }
                    .padding().foregroundStyle(.white)
                }
            }
            .greenfieldPlaybackCover(item: $request)
            .task {
                guard !didPresent else { return }
                let requestedAt = Date()
                let traceID = String(UUID().uuidString.prefix(8))
                let lease: PlaybackProxyRouteLease
                let transport: String
                do {
                    try Task.checkCancellation()
                    switch source.transport {
                    case .reader(let reader):
                        do {
                            let url = try await AuthenticatedMediaStreamProxy.shared.registerNetworkReader(
                                reader, originURL: source.originURL, playbackTraceID: traceID)
                            lease = PlaybackProxyRouteLease(url: url)
                            transport = "sharedReader"
                        } catch {
                            try Task.checkCancellation()
                            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
                            // Start the old local listener only if registration
                            // failed, before any decoder read could have started.
                            let bridge = WebDAVPlaybackSession(reader: reader)
                            let url = try await bridge.start()
                            lease = PlaybackProxyRouteLease(url: url) { bridge.stop() }
                            transport = "bridgeFallback"
                        }
                    case .bridge(let url):
                        lease = PlaybackProxyRouteLease(url: url) { }
                        transport = "bridge"
                    }
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError),
                          (error as? URLError)?.code != .cancelled else { return }
                    preparationFailed = true
                    return
                }
                // A late registration is released here if the view was closed
                // or another task already delivered the request.
                guard !Task.isCancelled, !didPresent else { return }
                didPresent = true
                DiagnosticLogStore.shared.record(transport == "bridgeFallback" ? .warning : .info,
                    categoryKey: "diagnostics.category.media", messageKey: "diagnostics.network_media.playback_proxy",
                    details: ["playbackTraceID": traceID, "route": transport,
                              "sourceScheme": source.originURL.scheme ?? "unknown",
                              "pathExtension": source.fileExtension])
                PlayerOrientationController.prepareForPresentation(.landscape)
                request = MediaPlaybackRequest(requestedAt: requestedAt, url: lease.url,
                    title: source.title, networkSource: source, contentKind: .video,
                    fileExtensionOverride: source.fileExtension,
                    initialPosition: source.startsFromBeginning ? 0 : nil,
                    byteLength: source.byteCount, playbackTraceID: traceID)
                    .greenfieldPlaybackLaunchRequest(proxyRouteLease: lease)
            }
            .onChange(of: request?.id) { value in
                if didPresent && value == nil { close() }
            }
    }
}

private struct LaunchpadMediaShortcutLabel: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let symbol: String
    var statistic: String? = nil
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                Text(statistic ?? NSLocalizedString("launchpad.media.count.unavailable", comment: ""))
                    .font(.caption2).foregroundStyle(.secondary)
            }.lineLimit(2).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 100, maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .nastartCard(cornerRadius: 10)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text(subtitle))
    }
}

private struct LaunchpadMediaDestinations: View {
    let libraries: [LaunchpadService]
    @EnvironmentObject private var router: MediaLibraryRouter
    @State private var addLibrary = false
    var body: some View {
        List {
            Section {
                ForEach(libraries) { service in
                    Button { router.open(service) } label: {
                        Label(service.name, systemImage: "play.rectangle")
                    }
                }
                if libraries.isEmpty {
                    Text("launchpad.media.library.empty").foregroundStyle(.secondary)
                }
                Button { addLibrary = true } label: {
                    Label("launchpad.media.library.add", systemImage: "plus.circle")
                }
            }.nastartListSection()
        }.nastartReadableWidth().nastartPageTheme().navigationTitle("launchpad.media.library")
            .sheet(isPresented: $addLibrary) {
                NavigationStack { ManualServiceEditorView(initialName: "Jellyfin", initialCategory: .media) }
            }
    }
}

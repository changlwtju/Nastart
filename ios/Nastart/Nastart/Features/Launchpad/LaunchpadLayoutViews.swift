import SwiftUI

struct LaunchpadDisplayOptions {
    let compactMetrics: Bool
    let showServiceStatus: Bool
    let showSubtitle: Bool
}

struct LaunchpadDataStatusBanner: View {
    let state: AppDataRefreshState
    let sourceKey: String
    let dsmConnected: Bool
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
                    Text(LocalizedStringKey(sourceKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            .background(Color(.secondarySystemGroupedBackground))
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
            DeviceSummaryPanel(device: device, compact: options.compactMetrics, isConnected: isConnected)

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
                VStack(spacing: 8) {
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
        .background(Color(.secondarySystemGroupedBackground))
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
        .background(Color(.secondarySystemGroupedBackground))
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
            DeviceSummaryPanel(device: device, compact: options.compactMetrics, isConnected: isConnected)

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
                VStack(spacing: 11) {
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
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(.white.opacity(0.58), lineWidth: 1)
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
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.68), lineWidth: 1)
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
                LazyVStack(spacing: 10) {
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
            StatusDot(status: status)
            Text(LocalizedStringKey(titleKey ?? status.titleKey))
                .font(.caption2.weight(.medium))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(AppTheme.secondarySurface)
        .clipShape(Capsule())
    }
}

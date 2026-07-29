import SwiftUI
import UIKit
import WebKit

struct LaunchpadView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue
    @AppStorage(AppearancePreferenceKeys.compactMetrics) private var compactMetrics = true
    @AppStorage(AppearancePreferenceKeys.showServiceStatus) private var showServiceStatus = true
    @AppStorage(AppearancePreferenceKeys.showCardSubtitle) private var showCardSubtitle = false
    @AppStorage(AppearancePreferenceKeys.showCardCPU) private var showCardCPU = true
    @AppStorage(AppearancePreferenceKeys.showCardMemory) private var showCardMemory = true
    @AppStorage(AppearancePreferenceKeys.showCardPorts) private var showCardPorts = false
    @AppStorage(AppearancePreferenceKeys.showCardLibraryCounts) private var showCardLibraryCounts = true
    @AppStorage(AppearancePreferenceKeys.groupFavoritesExpanded) private var groupFavoritesExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupMediaExpanded) private var groupMediaExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupDownloadsExpanded) private var groupDownloadsExpanded = false
    @AppStorage(AppearancePreferenceKeys.groupNetworkExpanded) private var groupNetworkExpanded = false
    @AppStorage(AppearancePreferenceKeys.groupToolsExpanded) private var groupToolsExpanded = false
    @AppStorage(AppearancePreferenceKeys.groupOrder) private var groupOrderRaw = ServiceCategory.defaultOrderStorageValue
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    launchpadContent
                        .id("\(selectedTheme.rawValue)-\(groupExpansionSignature)-\(groupOrderSignature)-\(displayOptionsSignature)")
                }
                .padding(18)
            }
            .background(launchpadBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        DSMConnectionFlowView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showSearch) {
                LaunchpadSearchView(services: dataStore.services)
            }
        }
    }

    @ViewBuilder
    private var launchpadContent: some View {
        switch selectedTheme {
        case .cleanGrid:
            ProductLaunchpad(device: dataStore.device, services: dataStore.services, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
        case .commandCenter:
            CommandCenterLaunchpad(device: dataStore.device, services: dataStore.services, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
        case .glassDeck:
            GlassDeckLaunchpad(device: dataStore.device, services: dataStore.services, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
        }
    }

    @ViewBuilder
    private var launchpadBackground: some View {
        switch selectedTheme {
        case .cleanGrid, .commandCenter:
            AppTheme.groupedBackground
        case .glassDeck:
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    AppTheme.softAccent.opacity(0.42),
                    Color(.secondarySystemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var selectedTheme: LaunchpadTheme {
        let theme = LaunchpadTheme(rawValue: launchpadThemeRaw) ?? .cleanGrid
        if theme == .cleanGrid {
            return theme
        }
        return entitlementStore.canUse(.advancedThemes) ? theme : .cleanGrid
    }

    private var displayOptions: LaunchpadDisplayOptions {
        LaunchpadDisplayOptions(
            compactMetrics: compactMetrics,
            showServiceStatus: showServiceStatus,
            showSubtitle: showCardSubtitle,
            showCPU: showCardCPU,
            showMemory: showCardMemory,
            showPorts: showCardPorts,
            showLibraryCounts: showCardLibraryCounts
        )
    }

    private var groupExpansionSignature: String {
        [
            groupFavoritesExpanded,
            groupMediaExpanded,
            groupDownloadsExpanded,
            groupNetworkExpanded,
            groupToolsExpanded
        ].map { $0 ? "1" : "0" }.joined()
    }

    private var orderedCategories: [ServiceCategory] {
        ServiceCategory.ordered(from: groupOrderRaw)
    }

    private var groupOrderSignature: String {
        orderedCategories.map(\.rawValue).joined(separator: "-")
    }

    private var displayOptionsSignature: String {
        [
            compactMetrics,
            showServiceStatus,
            showCardSubtitle,
            showCardCPU,
            showCardMemory,
            showCardPorts,
            showCardLibraryCounts
        ].map { $0 ? "1" : "0" }.joined()
    }

    private func isGroupExpandedByDefault(_ category: ServiceCategory) -> Bool {
        switch category {
        case .favorites:
            return groupFavoritesExpanded
        case .media:
            return groupMediaExpanded
        case .downloads:
            return groupDownloadsExpanded
        case .network:
            return groupNetworkExpanded
        case .tools:
            return groupToolsExpanded
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("N")
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(AppTheme.hairline, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
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

            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.body.weight(.semibold))
                    .frame(width: 34, height: 34)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct LaunchpadDisplayOptions {
    let compactMetrics: Bool
    let showServiceStatus: Bool
    let showSubtitle: Bool
    let showCPU: Bool
    let showMemory: Bool
    let showPorts: Bool
    let showLibraryCounts: Bool
}

private enum LaunchpadReminderPolicy {
    static let certificateWarningDays = 14
}

private struct CommandCenterLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: options.compactMetrics ? 8 : 10) {
                CommandMetricRail(device: device, compact: options.compactMetrics)

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(titleKey: "launchpad.command.quick_actions", trailingKey: "launchpad.section.generated")
                    ForEach(categories) { category in
                        let categoryServices = services.filter { $0.category == category }
                        if !categoryServices.isEmpty {
                            CommandCategorySection(category: category, services: categoryServices, options: options, initiallyExpanded: groupDefaultExpanded(category))
                        }
                    }
                }
                .layoutPriority(1)
            }

            if shouldShowCertificateReminder {
                NavigationLink {
                    DeviceStatusView(device: device)
                } label: {
                    CertificateReminderStrip(days: device.certificateDaysRemaining)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shouldShowCertificateReminder: Bool {
        device.certificateDaysRemaining <= LaunchpadReminderPolicy.certificateWarningDays
    }
}

private struct CommandMetricRail: View {
    let device: NASDevice
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            CommandRailMetric(titleKey: "metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu", progress: compact ? nil : device.cpu, compact: compact)
            CommandRailMetric(titleKey: "metric.memory", value: launchpadPercentText(device.memory), symbolName: "memorychip", progress: compact ? nil : device.memory, compact: compact)
            CommandRailMetric(titleKey: "metric.storage", value: device.storageFreeText, symbolName: "internaldrive", progress: compact ? nil : device.storageUsed, compact: compact)
            CommandRailMetric(titleKey: "metric.uptime", value: device.uptimeText, symbolName: "clock", progress: nil, compact: compact)
        }
        .frame(width: compact ? 58 : 66)
        .padding(.vertical, compact ? 8 : 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct CommandRailMetric: View {
    let titleKey: LocalizedStringKey
    let value: String
    let symbolName: String
    let progress: Double?
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 3 : 5) {
            Image(systemName: symbolName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.66)
            if !compact {
                Text(titleKey)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }

            if let progress {
                ProgressView(value: progress)
                    .tint(AppTheme.accent)
                    .scaleEffect(x: 1, y: 0.64)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 6 : 8)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 12 : 14, style: .continuous))
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
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(category.titleKey))
                        .font(.subheadline.weight(.semibold))
                    Text("\(services.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .frame(minHeight: 20)
                        .background(AppTheme.secondarySurface)
                        .clipShape(Capsule())
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
            ServiceIconStack(services: services, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(category.titleKey))
                    .font(.body.weight(.medium))
                Text("\(services.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    StatusDot(status: service.status)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }
}

private struct GlassDeckLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassHeroPanel(device: device, compact: options.compactMetrics)

            if shouldShowCertificateReminder {
                NavigationLink {
                    DeviceStatusView(device: device)
                } label: {
                    CertificateReminderStrip(days: device.certificateDaysRemaining)
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
        device.certificateDaysRemaining <= LaunchpadReminderPolicy.certificateWarningDays
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
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text(LocalizedStringKey(category.titleKey))
                        .font(.headline.weight(.semibold))
                    Text("\(services.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 22)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
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
            ServiceIconStack(services: services, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(LocalizedStringKey(category.titleKey))
                    .font(.body.weight(.medium))
                Text("launchpad.group.collapsed_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(services.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 30, height: 30)
                .background(.background.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.38), lineWidth: 1)
        }
    }
}

private struct GlassHeroPanel: View {
    let device: NASDevice
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.name)
                        .font(.title2.weight(.bold))
                    Text(device.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 42, height: 42)
                    .background(.background.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }

            if compact {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu"),
                    MetricPillSpec("metric.memory", value: launchpadPercentText(device.memory), symbolName: "memorychip"),
                    MetricPillSpec("metric.storage", value: device.storageFreeText, symbolName: "internaldrive")
                ])
            } else {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), progress: device.cpu, symbolName: "cpu"),
                    MetricPillSpec("metric.memory", value: launchpadPercentText(device.memory), progress: device.memory, symbolName: "memorychip"),
                    MetricPillSpec("metric.storage", value: device.storageFreeText, progress: device.storageUsed, symbolName: "internaldrive")
                ])
            }
        }
        .padding(19)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.46), lineWidth: 1)
        }
    }
}

private struct GlassServiceRow: View {
    let service: LaunchpadService
    let options: LaunchpadDisplayOptions

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
                    StatusDot(status: service.status)
                }
            }
            .padding(15)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.42), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct ProductLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DeviceSummaryPanel(device: device, compact: options.compactMetrics)

            if shouldShowCertificateReminder {
                NavigationLink {
                    DeviceStatusView(device: device)
                } label: {
                    CertificateReminderStrip(days: device.certificateDaysRemaining)
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
        device.certificateDaysRemaining <= LaunchpadReminderPolicy.certificateWarningDays
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
                        .font(.headline.weight(.semibold))
                    Text("\(services.count)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 22)
                        .background(AppTheme.secondarySurface)
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 2)
            .padding(.top, 2)

            if isExpanded {
                VStack(spacing: 10) {
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
                    CollapsedServicePreview(services: services)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CollapsedServicePreview: View {
    let services: [LaunchpadService]

    var body: some View {
        HStack(spacing: 10) {
            ServiceIconStack(services: services, size: 34)
            Spacer()
            Text("launchpad.group.collapsed_hint")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(14)
        .nastartCard(cornerRadius: 18)
    }
}

private struct ServiceIconStack: View {
    let services: [LaunchpadService]
    let size: CGFloat

    var body: some View {
        HStack(spacing: -8) {
            ForEach(services.prefix(3)) { service in
                ServiceIconView(service: service, size: size)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
            }

            if services.count > 3 {
                Text("+\(services.count - 3)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
                    .background(AppTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
            }
        }
    }
}

private struct ServiceListRow: View {
    let service: LaunchpadService
    let options: LaunchpadDisplayOptions
    @State private var actionMessageKey = "service.context.open_hint"
    @State private var showActionHint = false

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
                            ServiceStatusBadge(status: service.status)
                        }
                    }
                    if options.showSubtitle {
                        Text(LocalizedStringKey(service.detail))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }

                    HStack(spacing: 6) {
                        if options.showCPU, let cpu = service.cpu {
                            InlineServiceMetric(titleKey: "metric.cpu", value: "\(Int(cpu * 100))%")
                        }
                        if options.showMemory, let memoryText = service.memoryText {
                            InlineServiceMetric(titleKey: "metric.memory", value: memoryText)
                        }
                        if options.showPorts, !service.ports.isEmpty {
                            InlineServiceMetric(titleKey: "service.metric.ports", value: service.ports.prefix(2).joined(separator: " / "))
                        }
                        if options.showLibraryCounts, service.isMedia {
                            InlineServiceMetric(titleKey: "service.metric.library", valueKey: service.name == "Navidrome" ? "media.albums.title" : "media.movies.title")
                        }
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button("action.open") {
                showAction("service.context.open_hint")
            }
            Button("action.open_external") {
                showAction("service.context.external_hint")
            }
            Button("action.details") {
                showAction("service.context.details_hint")
            }
            Button("action.edit") {
                showAction("service.context.edit_hint")
            }
        }
        .alert(LocalizedStringKey(actionMessageKey), isPresented: $showActionHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func showAction(_ key: String) {
        actionMessageKey = key
        showActionHint = true
    }

    private var rowBackground: some ShapeStyle {
        AnyShapeStyle(Color(.systemBackground))
    }
}

private struct ServiceStatusBadge: View {
    let status: ServiceStatus

    var body: some View {
        HStack(spacing: 4) {
            StatusDot(status: status)
            Text(LocalizedStringKey(status.titleKey))
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

private struct InlineServiceMetric: View {
    let titleKey: LocalizedStringKey
    let valueKey: LocalizedStringKey

    init(titleKey: LocalizedStringKey, value: String) {
        self.titleKey = titleKey
        self.valueKey = LocalizedStringKey(value)
    }

    init(titleKey: LocalizedStringKey, valueKey: String) {
        self.titleKey = titleKey
        self.valueKey = LocalizedStringKey(valueKey)
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(titleKey)
            Text(valueKey)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.background)
        .clipShape(Capsule())
    }
}

private struct LaunchpadSearchView: View {
    let services: [LaunchpadService]
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredServices: [LaunchpadService] {
        guard !query.isEmpty else { return services }
        return services.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("search.placeholder", text: $query)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    FlowPills(items: ["DSM", "Jellyfin", "Docker", "HTTPS", "Navidrome", "qBittorrent"])
                } header: {
                    Text("search.hot")
                }

                Section {
                    ForEach(filteredServices) { service in
                        NavigationLink {
                            ServiceDetailView(service: service)
                        } label: {
                            ServiceSearchRow(service: service)
                        }
                    }
                } header: {
                    Text("search.services")
                }
            }
            .navigationTitle("search.title")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ServiceSearchRow: View {
    let service: LaunchpadService

    var body: some View {
        HStack(spacing: 12) {
            ServiceIconView(service: service, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(service.name)
                    .font(.body.weight(.medium))
                Text(LocalizedStringKey(service.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct FlowPills: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 10)], spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ServiceDetailView: View {
    let service: LaunchpadService
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var showExternalPicker = false
    @State private var externalMessageKey = "external.open_failed"
    @State private var showExternalHint = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 14) {
                        ServiceIconView(service: service, size: 54)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text(service.name)
                                    .font(.title2.weight(.bold))
                                StatusDot(status: service.status)
                            }
                            Text(LocalizedStringKey(service.detail))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    MetricPillRow(metrics: [
                        MetricPillSpec("metric.cpu", value: service.cpu.map { "\(Int($0 * 100))%" } ?? "-", progress: service.cpu),
                        MetricPillSpec("metric.memory", value: service.memoryText ?? "-")
                    ])
                }
                .padding(.vertical, 8)
            }

            Section {
                if service.name == "DSM" {
                    NavigationLink {
                        DeviceStatusView(device: dataStore.device)
                    } label: {
                        Label("service.action.device_control", systemImage: "server.rack")
                    }
                }

                NavigationLink {
                    ServiceWebUIView(service: service)
                } label: {
                    Label {
                        Text(LocalizedStringKey(service.isDeveloperConsole ? "service.action.open_console" : "service.action.open_web"))
                    } icon: {
                        Image(systemName: service.isDeveloperConsole ? "terminal" : "safari")
                    }
                }

                Button {
                    showExternalPicker = true
                } label: {
                    Label("service.action.open_external", systemImage: "arrow.up.forward.app")
                }

                if service.isMedia {
                    NavigationLink {
                        MediaLibraryView(service: service)
                    } label: {
                        Label("service.action.media_library", systemImage: service.name == "Navidrome" ? "music.note.list" : "play.rectangle")
                    }
                }
            } header: {
                Text("service.detail.actions")
            }

            Section {
                LabeledContent("service.detail.endpoint", value: service.suggestedEndpoint.absoluteString)
                LabeledContent("service.detail.source", value: service.isMedia ? "DSM + API" : "DSM / Agent")
                LabeledContent("service.detail.status") {
                    Text(LocalizedStringKey(service.status.titleKey))
                }
            } header: {
                Text("service.detail.connection")
            }
        }
        .navigationTitle(service.name)
        .confirmationDialog("service.external.title", isPresented: $showExternalPicker) {
            Button("external.browser") {
                openExternal(.safari)
            }

            if service.isMedia {
                Button("Infuse") {
                    openExternal(.infuse)
                }
                Button("VidHub") {
                    openExternal(.vidhub)
                }
                Button("VLC") {
                    openExternal(.vlc)
                }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .alert(LocalizedStringKey(externalMessageKey), isPresented: $showExternalHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        guard let url = target.url(for: service) else {
            externalMessageKey = "external.unsupported_hint"
            showExternalHint = true
            return
        }

        openURL(url) { accepted in
            if !accepted {
                externalMessageKey = target.failureMessageKey
                showExternalHint = true
            }
        }
    }
}

private enum ExternalOpenTarget {
    case safari
    case infuse
    case vidhub
    case vlc

    func url(for service: LaunchpadService) -> URL? {
        switch self {
        case .safari:
            return service.suggestedEndpoint
        case .infuse:
            return callbackURL(scheme: "infuse", action: "play", service: service)
        case .vidhub:
            return callbackURL(scheme: "vidhub", action: "open", service: service)
        case .vlc:
            return callbackURL(scheme: "vlc-x-callback", action: "stream", service: service)
        }
    }

    var failureMessageKey: String {
        switch self {
        case .safari:
            return "external.safari_failed"
        case .infuse, .vidhub, .vlc:
            return "external.player_failed"
        }
    }

    private func callbackURL(scheme: String, action: String, service: LaunchpadService) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "x-callback-url"
        components.path = "/\(action)"
        components.queryItems = [
            URLQueryItem(name: "url", value: service.suggestedEndpoint.absoluteString)
        ]
        return components.url
    }
}

private struct ServiceWebUIView: View {
    let service: LaunchpadService
    @Environment(\.openURL) private var openURL
    @State private var selectedMode = ServiceWebMode.automatic
    @State private var reloadToken = UUID()
    @State private var showCopiedHint = false

    var body: some View {
        VStack(spacing: 0) {
            if selectedMode != .focused, service.isDeveloperConsole {
                DeveloperConsoleToolbar(service: service)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            WebContainerView(
                url: service.suggestedEndpoint,
                prefersDesktopMode: resolvedMode.usesDesktopUserAgent,
                reloadToken: reloadToken
            )
                .background(Color(.systemBackground))
        }
        .navigationTitle(service.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker(selection: $selectedMode) {
                        ForEach(ServiceWebMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                        }
                    } label: {
                        Text("web.mode.title")
                    }
                } label: {
                    Image(systemName: "rectangle.on.rectangle")
                }

                Button {
                    reloadToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                Button {
                    UIPasteboard.general.string = service.suggestedEndpoint.absoluteString
                    showCopiedHint = true
                } label: {
                    Image(systemName: "link")
                }
                Button {
                    openURL(service.suggestedEndpoint)
                } label: {
                    Image(systemName: "safari")
                }
            }
        }
        .alert("web.copy.done", isPresented: $showCopiedHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private var resolvedMode: ResolvedWebMode {
        switch selectedMode {
        case .automatic:
            return ResolvedWebMode(usesDesktopUserAgent: service.prefersEnhancedWebMode)
        case .mobile:
            return ResolvedWebMode(usesDesktopUserAgent: false)
        case .desktop, .focused:
            return ResolvedWebMode(usesDesktopUserAgent: true)
        }
    }
}

private struct ResolvedWebMode {
    let usesDesktopUserAgent: Bool
}

private struct DeveloperConsoleToolbar: View {
    let service: LaunchpadService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ServiceIconView(service: service, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text("service.console.title")
                        .font(.headline.weight(.semibold))
                    Text("service.console.subtitle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                ConsoleShortcutKey(title: "Esc")
                ConsoleShortcutKey(title: "Tab")
                ConsoleShortcutKey(title: "Ctrl")
                ConsoleShortcutKey(title: "Cmd")
                ConsoleShortcutKey(title: "/")
            }
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

private struct ConsoleShortcutKey: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 42)
            .padding(.vertical, 8)
            .background(AppTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct WebContainerView: UIViewRepresentable {
    let url: URL
    let prefersDesktopMode: Bool
    let reloadToken: UUID

    private static let desktopUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        if prefersDesktopMode {
            webView.customUserAgent = Self.desktopUserAgent
        }
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        let wantsDesktop = prefersDesktopMode ? Self.desktopUserAgent : nil
        if uiView.customUserAgent != wantsDesktop {
            uiView.customUserAgent = wantsDesktop
            uiView.load(URLRequest(url: url))
            context.coordinator.lastReloadToken = reloadToken
            return
        }
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        } else if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            uiView.reload()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebContainerView
        var lastReloadToken: UUID

        init(parent: WebContainerView) {
            self.parent = parent
            self.lastReloadToken = parent.reloadToken
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            guard
                challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                let trust = challenge.protectionSpace.serverTrust,
                shouldTrustServer(host: challenge.protectionSpace.host)
            else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            completionHandler(.useCredential, URLCredential(trust: trust))
        }

        private func shouldTrustServer(host: String) -> Bool {
            let lowercasedHost = host.lowercased()
            if lowercasedHost == "localhost" || lowercasedHost.hasSuffix(".local") {
                return true
            }

            let segments = lowercasedHost.split(separator: ".").compactMap { Int($0) }
            guard segments.count == 4 else {
                return false
            }

            if segments[0] == 10 {
                return true
            }
            if segments[0] == 192 && segments[1] == 168 {
                return true
            }
            if segments[0] == 172 && (16...31).contains(segments[1]) {
                return true
            }
            return false
        }
    }
}

private struct MediaLibraryView: View {
    let service: LaunchpadService

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey(service.name == "Navidrome" ? "media.audio.title" : "media.video.title"))
                        .font(.title2.weight(.bold))
                    Text("media.library.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                NavigationLink {
                    MediaShelfView(service: service, shelf: .continueWatching)
                } label: {
                    Label("media.continue.title", systemImage: "play.rectangle")
                }
                NavigationLink {
                    MediaShelfView(service: service, shelf: service.name == "Navidrome" ? .albums : .movies)
                } label: {
                    Label(LocalizedStringKey(service.name == "Navidrome" ? "media.albums.title" : "media.movies.title"), systemImage: service.name == "Navidrome" ? "music.note" : "film")
                }
                NavigationLink {
                    MediaShelfView(service: service, shelf: .search)
                } label: {
                    Label("media.search.title", systemImage: "magnifyingglass")
                }
            } header: {
                Text("media.library.sections")
            }
        }
        .navigationTitle(service.name)
    }
}

private enum MediaShelf: String, Equatable {
    case continueWatching
    case movies
    case albums
    case search

    var titleKey: LocalizedStringKey {
        switch self {
        case .continueWatching: return "media.continue.title"
        case .movies: return "media.movies.title"
        case .albums: return "media.albums.title"
        case .search: return "media.search.title"
        }
    }
}

private struct MediaShelfView: View {
    let service: LaunchpadService
    let shelf: MediaShelf
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var query = ""

    private var items: [MediaItem] {
        let source = service.name == "Navidrome" ? dataStore.audioLibraryItems : dataStore.videoLibraryItems
        guard shelf == .search, !query.isEmpty else { return source }
        return source.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            if shelf == .search {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("media.search.placeholder", text: $query)
                            .textInputAutocapitalization(.never)
                    }
                }
            }

            Section {
                ForEach(items) { item in
                    NavigationLink {
                        MediaItemDetailView(service: service, item: item)
                    } label: {
                        MediaItemRow(item: item)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(shelf.titleKey)
    }
}

private struct MediaItemRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.symbolName)
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer()
            Text(item.meta)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct MediaItemDetailView: View {
    let service: LaunchpadService
    let item: MediaItem
    @State private var showPlayerPicker = false
    @State private var messageKey = "media.item.open_hint"
    @State private var showHint = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: item.symbolName)
                        .font(.system(size: 46, weight: .regular))
                    Text(item.title)
                        .font(.title2.weight(.bold))
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                LabeledContent("media.item.source", value: service.name)
                LabeledContent("media.item.location", value: item.path)
                LabeledContent("media.item.meta", value: item.meta)
            } header: {
                Text("media.item.info")
            }

            Section {
                Button("media.item.play") {
                    showPlayerPicker = true
                }
                Button("media.item.favorite") {
                    show("media.item.favorite_hint")
                }
            } header: {
                Text("media.item.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.title)
        .confirmationDialog("service.external.title", isPresented: $showPlayerPicker) {
            if item.kind == .video {
                Button("Infuse") { show("external.infuse_hint") }
                Button("VidHub") { show("external.vidhub_hint") }
                Button("VLC") { show("external.vlc_hint") }
            } else {
                Button("Navidrome") { show("external.navidrome_hint") }
                Button("player.system") { show("external.system_player_hint") }
            }
            Button("action.cancel", role: .cancel) {}
        }
        .alert(LocalizedStringKey(messageKey), isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func show(_ key: String) {
        messageKey = key
        showHint = true
    }
}

private struct DSMConnectionFlowView: View {
    @State private var host = ""
    @State private var account = ""
    @State private var password = ""
    @State private var useAgent = true

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("connect.title")
                        .font(.title2.weight(.bold))
                    Text("connect.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                TextField("connect.host", text: $host)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("connect.account", text: $account)
                    .textInputAutocapitalization(.never)
                SecureField("connect.password", text: $password)
                NavigationLink {
                    LANDiscoveryView()
                } label: {
                    Label("connect.scan.title", systemImage: "magnifyingglass")
                }
            } header: {
                Text("connect.section.dsm")
            }

            Section {
                Toggle("connect.agent.toggle", isOn: $useAgent)
                NavigationLink {
                    AgentSetupGuideView()
                } label: {
                    Label("connect.agent.guide", systemImage: "shippingbox")
                }
            } header: {
                Text("connect.section.agent")
            }

            Section {
                NavigationLink {
                    DSMConnectionReviewView(host: host, account: account, password: password, useAgent: useAgent)
                } label: {
                    Text("connect.action")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(AppTheme.accent)
                .foregroundStyle(.white)
            }
        }
        .navigationTitle("connect.nav")
    }
}

private struct LANDiscoveryView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var selectedHost = ""
    @State private var showHint = false

    var body: some View {
        List {
            Section {
                Text("connect.scan.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            Section {
                ForEach(dataStore.discoveredDevices) { device in
                    HStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .frame(width: 36, height: 36)
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.body.weight(.medium))
                            Text(device.host)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("connect.scan.use") {
                            selectedHost = device.host
                            showHint = true
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accent)
                    }
                    .padding(.vertical, 3)
                }
            } header: {
                Text("connect.scan.results")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.scan.title")
        .alert("connect.scan.use_hint \(selectedHost)", isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct AgentSetupGuideView: View {
    @State private var showCopyHint = false
    private let command = "docker run -d --name nastart-agent -p 8787:8787 nastart/agent:latest"

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("connect.agent.guide")
                        .font(.title2.weight(.bold))
                    Text("connect.agent.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                AgentStepRow(number: 1, titleKey: "connect.agent.step.package", detailKey: "connect.agent.step.package_detail")
                AgentStepRow(number: 2, titleKey: "connect.agent.step.token", detailKey: "connect.agent.step.token_detail")
                AgentStepRow(number: 3, titleKey: "connect.agent.step.verify", detailKey: "connect.agent.step.verify_detail")
            } header: {
                Text("connect.agent.steps")
            }

            Section {
                Text(command)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button("connect.agent.copy") {
                    UIPasteboard.general.string = command
                    showCopyHint = true
                }
            } header: {
                Text("connect.agent.command")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.agent.guide")
        .alert("connect.agent.copy_hint", isPresented: $showCopyHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct AgentStepRow: View {
    let number: Int
    let titleKey: LocalizedStringKey
    let detailKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 26, height: 26)
                .background(AppTheme.secondarySurface)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(titleKey)
                    .font(.body.weight(.medium))
                Text(detailKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct DSMConnectionReviewView: View {
    let host: String
    let account: String
    let password: String
    let useAgent: Bool
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var showFinishHint = false
    @State private var isConnecting = false
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("connect.review.title")
                        .font(.title2.weight(.bold))
                    Text("connect.review.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                LabeledContent("connect.host", value: host)
                LabeledContent("connect.account", value: account.isEmpty ? "-" : account)
                LabeledContent("connect.password") {
                    Text(password.isEmpty ? "-" : "••••••••")
                        .foregroundStyle(.secondary)
                }
                LabeledContent("connect.agent.toggle") {
                    Text(LocalizedStringKey(useAgent ? "state.on" : "state.off"))
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("connect.review.target")
            }

            Section {
                CapabilityRow(titleKey: "connect.scope.system", symbol: "chart.line.uptrend.xyaxis")
                CapabilityRow(titleKey: "connect.scope.files", symbol: "folder")
                CapabilityRow(titleKey: "connect.scope.docker", symbol: "shippingbox")
                CapabilityRow(titleKey: "connect.scope.services", symbol: "square.grid.2x2")
            } header: {
                Text("connect.review.scope")
            }

            Section {
                Button {
                    connectDSM()
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                        }
                        Text(LocalizedStringKey(isConnecting ? "connect.review.connecting" : "connect.review.finish"))
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .disabled(isConnecting || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || account.isEmpty || password.isEmpty)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.review.nav")
        .alert("connect.review.done", isPresented: $showFinishHint) {
            Button("action.ok", role: .cancel) {
                dismiss()
            }
        }
        .alert("connect.error.title", isPresented: $showError) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func connectDSM() {
        isConnecting = true
        errorMessage = ""
        Task {
            do {
                let baseURL = try DSMClient.normalizedBaseURL(from: host)
                let client = DSMClient(baseURL: baseURL)
                let session = try await client.login(account: account, password: password)
                let snapshot = await client.loadSnapshot(session: session, useAgent: useAgent)
                KeychainStore.shared.saveNASCredential(
                    StoredNASCredential(
                        baseURLString: baseURL.absoluteString,
                        account: account,
                        password: password,
                        useAgent: useAgent
                    )
                )
                await MainActor.run {
                    dataStore.reload(from: snapshot)
                    connectionStore.connect(device: snapshot.device, session: session)
                    isConnecting = false
                    showFinishHint = true
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

private struct CapabilityRow: View {
    let titleKey: LocalizedStringKey
    let symbol: String

    var body: some View {
        Label(titleKey, systemImage: symbol)
            .padding(.vertical, 2)
    }
}

private extension ServiceStatus {
    var titleKey: String {
        switch self {
        case .online: return "status.online"
        case .warning: return "status.warning"
        case .offline: return "status.offline"
        case .unknown: return "status.unknown"
        }
    }
}

private struct CertificateReminderStrip: View {
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

private struct DeviceSummaryPanel: View {
    let device: NASDevice
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("launchpad.summary.normal")
                        .font(.title3.weight(.bold))
                    Text("launchpad.summary.subtitle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(device.uptimeText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if compact {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu"),
                    MetricPillSpec("metric.memory", value: launchpadPercentText(device.memory), symbolName: "memorychip"),
                    MetricPillSpec("metric.storage", value: device.storageFreeText, symbolName: "internaldrive")
                ])
            } else {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), progress: device.cpu, symbolName: "cpu"),
                    MetricPillSpec("metric.memory", value: launchpadPercentText(device.memory), progress: device.memory, symbolName: "memorychip"),
                    MetricPillSpec("metric.storage", value: device.storageFreeText, progress: device.storageUsed, symbolName: "internaldrive")
                ])
            }
        }
        .padding(16)
        .nastartCard(cornerRadius: 26)
    }
}

private func launchpadPercentText(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
}

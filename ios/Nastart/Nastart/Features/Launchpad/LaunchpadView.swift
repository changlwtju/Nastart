import SwiftUI
import UIKit
import WebKit
import SafariServices
import AVFoundation
import AVKit
import CoreText
import Network
import JellyfinAPI
#if canImport(MobileVLCKit)
import MobileVLCKit
#endif

struct LaunchpadView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var entitlementStore: EntitlementStore
    @AppStorage(LaunchpadTheme.storageKey) private var launchpadThemeRaw = LaunchpadTheme.cleanGrid.rawValue
    @AppStorage(AppearancePreferenceKeys.compactMetrics) private var compactMetrics = true
    @AppStorage(AppearancePreferenceKeys.showServiceStatus) private var showServiceStatus = true
    @AppStorage(AppearancePreferenceKeys.showCardSubtitle) private var showCardSubtitle = false
    @AppStorage(AppearancePreferenceKeys.groupFavoritesExpanded) private var groupFavoritesExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupMediaExpanded) private var groupMediaExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupDownloadsExpanded) private var groupDownloadsExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupNetworkExpanded) private var groupNetworkExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupToolsExpanded) private var groupToolsExpanded = true
    @AppStorage(AppearancePreferenceKeys.groupOrder) private var groupOrderRaw = ServiceCategory.defaultOrderStorageValue
    @AppStorage(AppearancePreferenceKeys.groupDefaultVersion) private var groupDefaultVersion = 0
    @State private var showSearch = false
    @State private var showConnectionFlow = false
    @State private var showManualServiceEditor = false
    @State private var showServiceManager = false
    @State private var refreshPulseID = UUID()

    var body: some View {
        NavigationStack {
            Group {
                if connectionStore.isConnected || !dataStore.services.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            header
                            if !hiddenLaunchpadServices.isEmpty {
                                HiddenServicesRestoreStrip(
                                    count: hiddenLaunchpadServices.count,
                                    action: {
                                        showServiceManager = true
                                    }
                                )
                            }
                            launchpadContent
                                .id("\(selectedTheme.rawValue)-\(groupExpansionSignature)-\(groupOrderSignature)-\(displayOptionsSignature)")
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 6)
                        .padding(.bottom, 18)
                    }
                    .background(launchpadBackground)
                    .refreshable {
                        await refreshLaunchpad()
                    }
                } else {
                    NASConnectionWelcomeView(
                        addNASAction: {
                            showConnectionFlow = true
                        }
                    )
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if connectionStore.isConnected {
                        Button {
                            refreshPulseID = UUID()
                            Task(priority: .userInitiated) {
                                await refreshLaunchpad()
                            }
                        } label: {
                            if dataStore.isRefreshing {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .id(refreshPulseID)
                                    .transition(.opacity)
                            }
                        }
                        .disabled(dataStore.isRefreshing)
                        .accessibilityLabel(Text("action.refresh"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !dataStore.services.isEmpty {
                        Button {
                            showServiceManager = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel(Text("launchpad.services.manage"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("connect.welcome.action") {
                            showConnectionFlow = true
                        }
                        Button("manual.service.add") {
                            showManualServiceEditor = true
                        }
                        if !dataStore.services.isEmpty {
                            Button("launchpad.services.manage") {
                                showServiceManager = true
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("launchpad.add.title"))
                }
            }
            .sheet(isPresented: $showConnectionFlow) {
                NavigationStack {
                    DSMConnectionFlowView {
                        showConnectionFlow = false
                    }
                }
            }
            .sheet(isPresented: $showManualServiceEditor) {
                NavigationStack {
                    ManualServiceEditorView()
                }
            }
            .sheet(isPresented: $showServiceManager) {
                NavigationStack {
                    LaunchpadServiceManagementView()
                }
            }
            .sheet(isPresented: $showSearch) {
                LaunchpadSearchView(services: launchpadServices)
            }
            .onAppear {
                applyGroupDefaultMigrationIfNeeded()
            }
        }
    }

    @MainActor
    private func refreshLaunchpad() async {
        guard !dataStore.isRefreshing else { return }
        if let session = connectionStore.dsmSession {
            await dataStore.refreshDSM(session: session, useAgent: connectionStore.usesAgent)
        } else {
            dataStore.refreshAll()
        }
    }

    @ViewBuilder
    private var launchpadContent: some View {
        switch selectedTheme {
        case .cleanGrid:
            ProductLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, isConnected: dataStore.isDSMAvailableForDisplay, groupDefaultExpanded: isGroupExpandedByDefault)
        case .commandCenter:
            CommandCenterLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
        case .glassDeck:
            GlassDeckLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, isConnected: dataStore.isDSMAvailableForDisplay, groupDefaultExpanded: isGroupExpandedByDefault)
        }
    }

    private var launchpadServices: [LaunchpadService] {
        dataStore.services.filter(dataStore.isServiceVisibleOnLaunchpad)
    }

    private var hiddenLaunchpadServices: [LaunchpadService] {
        dataStore.services.filter { !dataStore.isServiceVisibleOnLaunchpad($0) }
    }

    @ViewBuilder
    private var launchpadBackground: some View {
        switch selectedTheme {
        case .cleanGrid:
            AppTheme.groupedBackground
        case .commandCenter:
            LinearGradient(
                colors: [
                    Color(.systemGroupedBackground),
                    Color(.secondarySystemGroupedBackground).opacity(0.72),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .glassDeck:
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemIndigo).opacity(0.13),
                    AppTheme.accent.opacity(0.09),
                    Color(.secondarySystemBackground)
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
            showSubtitle: showCardSubtitle
        )
    }

    private var groupExpansionSignature: String {
        return [
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
            showCardSubtitle
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

    private func applyGroupDefaultMigrationIfNeeded() {
        guard groupDefaultVersion < 1 else { return }
        groupFavoritesExpanded = true
        groupMediaExpanded = true
        groupDownloadsExpanded = true
        groupNetworkExpanded = true
        groupToolsExpanded = true
        groupDefaultVersion = 1
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dataStore.device.name)
                    .font(.title2.weight(.semibold))
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
                    .frame(width: 38, height: 38)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("search.title"))
        }
    }
}

private struct LaunchpadDisplayOptions {
    let compactMetrics: Bool
    let showServiceStatus: Bool
    let showSubtitle: Bool
}

private struct HiddenServicesRestoreStrip: View {
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 30, height: 30)
                    .background(AppTheme.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("launchpad.services.hidden")
                        .font(.subheadline.weight(.semibold))
                    Text(String.localizedStringWithFormat(
                        NSLocalizedString("launchpad.services.hidden_count", comment: ""),
                        count
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Text("launchpad.service.show")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
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

private struct CommandMetricRail: View {
    let device: NASDevice
    let compact: Bool

    var body: some View {
        VStack(spacing: compact ? 6 : 8) {
            CommandRailMetric(titleKey: "metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu", progress: compact ? nil : device.cpu, compact: compact)
            CommandRailMetric(titleKey: "metric.memory", value: launchpadPercentText(device.memory), symbolName: "memorychip", progress: compact ? nil : device.memory, compact: compact)
            CommandRailMetric(titleKey: "metric.storage", value: launchpadPercentText(device.storageUsed), symbolName: "internaldrive", progress: compact ? nil : device.storageUsed, compact: compact)
        }
        .frame(width: compact ? 52 : 60)
        .padding(.vertical, compact ? 10 : 12)
        .background(AppTheme.primaryAction)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
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
                .foregroundStyle(.white.opacity(0.7))

            Text(value)
                .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.66)
            if !compact {
                Text(titleKey)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
            }

            if let progress {
                ProgressView(value: progress)
                    .tint(.white.opacity(0.82))
                    .scaleEffect(x: 1, y: 0.64)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 4 : 6)
        .padding(.vertical, compact ? 8 : 10)
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

private struct GlassDeckLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let isConnected: Bool
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassHeroPanel(device: device, compact: options.compactMetrics, isConnected: isConnected)

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

private struct GlassHeroPanel: View {
    let device: NASDevice
    let compact: Bool
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack {
                Label {
                    Text(LocalizedStringKey(summaryKey))
                } icon: {
                    Image(systemName: summarySymbol)
                }
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let uptimeMinutes = device.uptimeMinutes {
                    LiveUptimeText(baseMinutes: uptimeMinutes)
                        .id(device.id)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if compact {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu"),
                    MetricPillSpec("metric.memory_ram", value: launchpadPercentText(device.memory), symbolName: "memorychip"),
                    MetricPillSpec("metric.storage_disk", value: launchpadPercentText(device.storageUsed), symbolName: "internaldrive")
                ])
            } else {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), progress: device.cpu, symbolName: "cpu"),
                    MetricPillSpec("metric.memory_ram", value: launchpadPercentText(device.memory), progress: device.memory, symbolName: "memorychip"),
                    MetricPillSpec("metric.storage_disk", value: launchpadPercentText(device.storageUsed), progress: device.storageUsed, symbolName: "internaldrive")
                ])
            }
        }
        .padding(19)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.74), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 20, y: 10)
    }

    private var summaryKey: String {
        guard isConnected else { return "state.not_connected" }
        return hasWarning ? "status.warning" : "launchpad.summary.normal"
    }

    private var summarySymbol: String {
        guard isConnected else { return "wifi.slash" }
        return hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var hasWarning: Bool {
        device.certificateDaysRemaining.map { $0 <= LaunchpadReminderPolicy.certificateWarningDays } == true
            || [device.cpu, device.memory, device.storageUsed].compactMap { $0 }.contains { $0 >= 0.9 }
    }
}

private struct GlassServiceRow: View {
    let service: LaunchpadService
    let options: LaunchpadDisplayOptions
    @EnvironmentObject private var dataStore: AppDataStore

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

private struct ProductLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]
    let categories: [ServiceCategory]
    let options: LaunchpadDisplayOptions
    let isConnected: Bool
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

private struct LaunchpadServiceManagementView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        List {
            serviceSection(
                titleKey: "launchpad.services.visible",
                services: filteredServices.filter(dataStore.isServiceVisibleOnLaunchpad)
            )
            serviceSection(
                titleKey: "launchpad.services.hidden",
                services: filteredServices.filter { !dataStore.isServiceVisibleOnLaunchpad($0) }
            )

            Section {
                Button("launchpad.services.reset") {
                    dataStore.resetLaunchpadServiceVisibility()
                }
            } footer: {
                Text("launchpad.services.footer")
            }
        }
        .navigationTitle("launchpad.services.manage")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "launchpad.services.search")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.done") {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func serviceSection(titleKey: LocalizedStringKey, services: [LaunchpadService]) -> some View {
        if !services.isEmpty {
            Section {
                ForEach(services) { service in
                    Toggle(isOn: visibilityBinding(for: service)) {
                        HStack(spacing: 12) {
                            ServiceIconView(service: service, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(service.name)
                                    .lineLimit(1)
                                Text(LocalizedStringKey(service.sourceTitleKey))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text(titleKey)
            }
        }
    }

    private var filteredServices: [LaunchpadService] {
        dataStore.services
            .filter {
                query.isEmpty
                    || $0.name.localizedCaseInsensitiveContains(query)
                    || $0.detail.localizedCaseInsensitiveContains(query)
            }
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    private func visibilityBinding(for service: LaunchpadService) -> Binding<Bool> {
        Binding(
            get: { dataStore.isServiceVisibleOnLaunchpad(service) },
            set: { dataStore.setService(service, visibleOnLaunchpad: $0) }
        )
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
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var externalMessageKey = "external.open_failed"
    @State private var showExternalHint = false
    @State private var endpointOverride: URL?
    @State private var showEndpointEditor = false
    @State private var showDeleteManualConfirmation = false

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
                            Text(LocalizedStringKey(serviceDescriptionKey))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    MetricPillRow(metrics: [
                        MetricPillSpec("metric.cpu", value: launchpadServicePercentText(effectiveCPU), progress: effectiveCPU),
                        MetricPillSpec("metric.memory_ram", value: effectiveMemoryText, progress: effectiveMemory)
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

                if let endpoint = effectiveEndpoint {
                    NavigationLink {
                        ServiceWebUIView(
                            service: service,
                            endpoint: endpoint,
                            allowsSelfSignedCertificates: ServiceCertificatePolicy.allowsBypass(
                                for: endpoint,
                                session: connectionStore.dsmSession
                            ),
                            dsmSession: service.source == .dsm || service.source == .package
                                ? connectionStore.dsmSession
                                : nil
                        )
                    } label: {
                        Label {
                            Text(LocalizedStringKey(service.isDeveloperConsole ? "service.action.open_console" : "service.action.open_web"))
                        } icon: {
                            Image(systemName: service.isDeveloperConsole ? "terminal" : "safari")
                        }
                    }
                } else {
                    Label {
                        Text("service.action.open_unavailable")
                    } icon: {
                        Image(systemName: "link.badge.plus")
                    }
                    .foregroundStyle(.secondary)
                }

                Button {
                    openExternal(.safari)
                } label: {
                    Label("service.action.open_service_external", systemImage: "arrow.up.forward.app")
                }

                if service.isMedia {
                    NavigationLink {
                        DirectMediaPlayerSetupView(
                            suggestedURL: effectiveEndpoint.flatMap {
                                DirectMediaURLPolicy.isLikelyMediaURL($0) ? $0 : nil
                            }
                        )
                    } label: {
                        Label("player.open_stream", systemImage: "play.rectangle")
                    }

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
                VStack(alignment: .leading, spacing: 7) {
                    Text("service.detail.endpoint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(effectiveEndpoint?.absoluteString
                        ?? NSLocalizedString("service.detail.endpoint_unavailable", comment: ""))
                        .font(.footnote.monospaced())
                        .foregroundStyle(effectiveEndpoint == nil ? .secondary : .primary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                LabeledContent("service.detail.status") {
                    Text(LocalizedStringKey(service.status.titleKey))
                }
                if service.usesLANOnlyEndpoint(for: connectionStore.dsmSession?.baseURL) {
                    Label("service.endpoint.lan_only", systemImage: "house.and.flag")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showEndpointEditor = true
                } label: {
                    Label {
                        Text(LocalizedStringKey(
                            endpointOverride == nil
                                ? "service.action.configure_endpoint"
                                : "service.action.edit_endpoint"
                        ))
                    } icon: {
                        Image(systemName: "link.badge.plus")
                    }
                }
            } header: {
                Text("service.detail.connection")
            }

            if service.source == .manual {
                Section {
                    Button(role: .destructive) {
                        showDeleteManualConfirmation = true
                    } label: {
                        Label("manual.service.delete", systemImage: "trash")
                    }
                }
            }

            Section {
                Button(role: isVisibleOnLaunchpad ? .destructive : nil) {
                    dataStore.setService(service, visibleOnLaunchpad: !isVisibleOnLaunchpad)
                    dismiss()
                } label: {
                    Label {
                        Text(LocalizedStringKey(
                            isVisibleOnLaunchpad ? "launchpad.service.hide" : "launchpad.service.show"
                        ))
                    } icon: {
                        Image(systemName: isVisibleOnLaunchpad ? "eye.slash" : "eye")
                    }
                }
            }
        }
        .navigationTitle(service.name)
        .onAppear {
            endpointOverride = ServiceEndpointOverrides.load(
                service: service,
                deviceHost: connectionStore.dsmSession?.baseURL.host
            )
        }
        .sheet(isPresented: $showEndpointEditor) {
            ServiceEndpointEditor(
                overrideURL: endpointOverride,
                suggestedURL: service.preferredEndpoint(for: connectionStore.dsmSession?.baseURL)
            ) { url in
                endpointOverride = url
                ServiceEndpointOverrides.save(
                    url,
                    service: service,
                    deviceHost: connectionStore.dsmSession?.baseURL.host
                )
            }
        }
        .alert(LocalizedStringKey(externalMessageKey), isPresented: $showExternalHint) {
            Button("action.ok", role: .cancel) {}
        }
        .confirmationDialog("manual.service.delete.confirm", isPresented: $showDeleteManualConfirmation) {
            Button("manual.service.delete", role: .destructive) {
                dataStore.deleteManualService(id: service.id)
                dismiss()
            }
            Button("action.cancel", role: .cancel) {}
        }
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        guard let url = target.url(endpoint: effectiveEndpoint) else {
            externalMessageKey = "external.unsupported_hint"
            showExternalHint = true
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { accepted in
                guard !accepted else { return }
                DispatchQueue.main.async {
                    externalMessageKey = target.failureMessageKey
                    showExternalHint = true
                }
            }
        }
    }

    private var effectiveEndpoint: URL? {
        endpointOverride ?? service.preferredEndpoint(for: connectionStore.dsmSession?.baseURL)
    }

    private var isVisibleOnLaunchpad: Bool {
        dataStore.isServiceVisibleOnLaunchpad(service)
    }

    private var effectiveCPU: Double? {
        service.source == .dsm ? dataStore.device.cpu : service.cpu
    }

    private var effectiveMemory: Double? {
        service.source == .dsm ? dataStore.device.memory : service.memory
    }

    private var effectiveMemoryText: String {
        if service.source == .dsm {
            return dataStore.device.memoryDisplayText
        }
        if let memory = service.memory {
            return launchpadServicePercentText(memory)
        }
        return service.memoryText ?? "-"
    }

    private var serviceDescriptionKey: String {
        if service.name == "DSM" {
            return "service.dsm.detail"
        }
        if service.isMedia {
            return "service.detail.media_service"
        }
        switch service.source {
        case .container: return "service.detail.container_service"
        case .reverseProxy: return "service.detail.web_service"
        case .package: return "service.detail.package_service"
        case .manual: return "manual.service.detail"
        case .dsm: return "service.dsm.detail"
        }
    }
}

private enum ServiceCertificatePolicy {
    static func allowsBypass(for endpoint: URL, session: DSMSession?) -> Bool {
        guard
            let session,
            session.allowsSelfSignedCertificates,
            let endpointHost = endpoint.host
        else {
            return false
        }
        let isDSMHost = endpointHost.caseInsensitiveCompare(session.baseURL.host ?? "") == .orderedSame
        return isDSMHost || NetworkHostClassifier.isPrivate(endpointHost)
    }
}

private enum ServiceEndpointOverrides {
    static func load(service: LaunchpadService, deviceHost: String?) -> URL? {
        let defaults = UserDefaults.standard
        let value = defaults.string(forKey: key(service: service, deviceHost: deviceHost))
            ?? defaults.string(forKey: legacyKey(service: service, deviceHost: deviceHost))
        return value.flatMap(UserConfiguredServiceURLPolicy.normalizedURL)
    }

    static func save(_ url: URL?, service: LaunchpadService, deviceHost: String?) {
        let storageKey = key(service: service, deviceHost: deviceHost)
        if let url {
            UserDefaults.standard.set(url.absoluteString, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
        UserDefaults.standard.removeObject(forKey: legacyKey(service: service, deviceHost: deviceHost))
    }

    private static func key(service: LaunchpadService, deviceHost: String?) -> String {
        let device = (deviceHost ?? "nas").lowercased()
        return "nastart.service.endpoint.\(device).\(service.id.uuidString.lowercased())"
    }

    private static func legacyKey(service: LaunchpadService, deviceHost: String?) -> String {
        let device = (deviceHost ?? "nas").lowercased()
        let serviceName = service.name.lowercased()
        return "nastart.service.endpoint.\(device).\(serviceName)"
    }
}

private struct ServiceEndpointEditor: View {
    let overrideURL: URL?
    let suggestedURL: URL?
    let onSave: (URL?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var showsValidationError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("service.endpoint.placeholder", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                } footer: {
                    Text("service.endpoint.hint")
                }

                if overrideURL != nil {
                    Section {
                        Button("service.endpoint.restore_auto", role: .destructive) {
                            onSave(nil)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("service.endpoint.title")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                address = (overrideURL ?? suggestedURL)?.absoluteString ?? ""
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("action.save") {
                        guard let url = normalizedURL else {
                            showsValidationError = true
                            return
                        }
                        onSave(url)
                        dismiss()
                    }
                }
            }
            .alert("service.endpoint.invalid", isPresented: $showsValidationError) {
                Button("action.ok", role: .cancel) {}
            }
        }
    }

    private var normalizedURL: URL? {
        UserConfiguredServiceURLPolicy.normalizedURL(from: address)
    }
}

private struct ServiceSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct SystemShareView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ExternalOpenTarget: String, CaseIterable, Identifiable {
    case safari
    case infuse
    case fileball
    case vidhub
    case vlc
    case outplayer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .safari: return "Safari"
        case .infuse: return "Infuse"
        case .fileball: return "Fileball"
        case .vidhub: return "VidHub"
        case .vlc: return "VLC"
        case .outplayer: return "Outplayer"
        }
    }

    @MainActor
    static var installedPlayers: [ExternalOpenTarget] {
        allCases.filter { target in
            guard target != .safari, let probeURL = target.probeURL else { return false }
            return UIApplication.shared.canOpenURL(probeURL)
        }
    }

    private var probeURL: URL? {
        switch self {
        case .safari: return nil
        case .infuse: return URL(string: "infuse://")
        case .fileball: return URL(string: "filebox://")
        case .vidhub: return URL(string: "open-vidhub://")
        case .vlc: return URL(string: "vlc-x-callback://")
        case .outplayer: return URL(string: "outplayer://")
        }
    }

    func url(
        endpoint: URL?,
        filename: String? = nil,
        subtitleURL: URL? = nil
    ) -> URL? {
        switch self {
        case .safari:
            return endpoint
        case .infuse:
            return callbackURL(
                scheme: "infuse",
                action: "play",
                endpoint: endpoint,
                filename: filename,
                subtitleURL: subtitleURL
            )
        case .fileball:
            return simplePlaybackURL(scheme: "filebox", endpoint: endpoint)
        case .vidhub:
            return callbackURL(
                scheme: "open-vidhub",
                action: "play",
                endpoint: endpoint,
                filename: filename,
                subtitleURL: subtitleURL
            )
        case .vlc:
            return callbackURL(
                scheme: "vlc-x-callback",
                action: "stream",
                endpoint: endpoint,
                filename: filename,
                subtitleURL: subtitleURL
            )
        case .outplayer:
            return callbackURL(
                scheme: "outplayer",
                action: "play",
                endpoint: endpoint,
                subtitleURL: subtitleURL
            )
        }
    }

    var failureMessageKey: String {
        switch self {
        case .safari:
            return "external.safari_failed"
        case .infuse, .fileball, .vidhub, .vlc, .outplayer:
            return "external.player_failed"
        }
    }

    var diagnosticName: String {
        switch self {
        case .safari: return "Safari"
        case .infuse: return "Infuse"
        case .fileball: return "Fileball"
        case .vidhub: return "VidHub"
        case .vlc: return "VLC"
        case .outplayer: return "Outplayer"
        }
    }

    private func callbackURL(
        scheme: String,
        action: String,
        endpoint: URL?,
        filename: String? = nil,
        subtitleURL: URL? = nil
    ) -> URL? {
        guard let endpoint else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "x-callback-url"
        components.path = "/\(action)"
        var queryItems = [
            URLQueryItem(name: "url", value: endpoint.absoluteString)
        ]
        if let filename, !filename.isEmpty {
            queryItems.append(URLQueryItem(name: "filename", value: filename))
        }
        if let subtitleURL {
            queryItems.append(URLQueryItem(name: "sub", value: subtitleURL.absoluteString))
        }
        if scheme == "infuse" || scheme == "open-vidhub" {
            let requestID = UUID().uuidString
            let target = scheme == "infuse" ? "Infuse" : "VidHub"
            if scheme == "open-vidhub" {
                queryItems.append(URLQueryItem(name: "request-id", value: requestID))
                queryItems.append(URLQueryItem(name: "x-source", value: "Nastart"))
            }
            queryItems.append(URLQueryItem(
                name: "x-success",
                value: Self.externalCallbackURL(
                    outcome: "success",
                    target: target,
                    requestID: requestID
                )?.absoluteString
            ))
            queryItems.append(URLQueryItem(
                name: "x-error",
                value: Self.externalCallbackURL(
                    outcome: "error",
                    target: target,
                    requestID: requestID
                )?.absoluteString
            ))
            if scheme == "open-vidhub" {
                queryItems.append(URLQueryItem(
                    name: "x-cancel",
                    value: Self.externalCallbackURL(
                        outcome: "cancel",
                        target: target,
                        requestID: requestID
                    )?.absoluteString
                ))
            }
        }
        let queryValueCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-._~"))
        components.percentEncodedQuery = queryItems.compactMap { item in
            guard
                let encodedName = item.name.addingPercentEncoding(
                    withAllowedCharacters: queryValueCharacters
                ),
                let encodedValue = item.value?.addingPercentEncoding(
                    withAllowedCharacters: queryValueCharacters
                )
            else {
                return nil
            }
            return "\(encodedName)=\(encodedValue)"
        }.joined(separator: "&")
        return components.url
    }

    private static func externalCallbackURL(
        outcome: String,
        target: String,
        requestID: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "nastart"
        components.host = "external-playback"
        components.path = "/\(outcome)"
        components.queryItems = [
            URLQueryItem(name: "target", value: target),
            URLQueryItem(name: "request-id", value: requestID)
        ]
        return components.url
    }

    private func simplePlaybackURL(scheme: String, endpoint: URL?) -> URL? {
        guard let endpoint else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = "play"
        let queryValueCharacters = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-._~"))
        guard let encodedEndpoint = endpoint.absoluteString.addingPercentEncoding(
            withAllowedCharacters: queryValueCharacters
        ) else {
            return nil
        }
        components.percentEncodedQuery = "url=\(encodedEndpoint)"
        return components.url
    }

}

enum ExternalPlaybackCallbackHandler {
    static func handle(_ url: URL) {
        guard url.scheme?.lowercased() == "nastart",
              url.host?.lowercased() == "external-playback" else {
            return
        }
        let outcome = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(
            queryItems.map { ($0.name, $0.value ?? "") },
            uniquingKeysWith: { current, _ in current }
        )
        let level: DiagnosticLogLevel = outcome == "error" ? .error : .info
        let messageKey: String
        switch outcome {
        case "success":
            messageKey = "diagnostics.media.external_handoff_completed"
        case "error":
            messageKey = "diagnostics.media.external_handoff_playback_failed"
        default:
            messageKey = "diagnostics.media.external_handoff_cancelled"
        }
        DiagnosticLogStore.shared.record(
            level,
            categoryKey: "diagnostics.category.media",
            messageKey: messageKey,
            details: [
                "targetApp": values["target"] ?? "-",
                "requestID": values["request-id"] ?? "-",
                "status": values["status"] ?? outcome,
                "position": values["position"] ?? "-",
                "duration": values["duration"] ?? "-",
                "errorCode": values["errorCode"] ?? "-"
            ]
        )
    }
}

private struct ServiceWebUIView: View {
    let service: LaunchpadService
    let endpoint: URL
    let allowsSelfSignedCertificates: Bool
    let dsmSession: DSMSession?
    @State private var selectedMode = ServiceWebMode.automatic
    @State private var showCompatibilityBrowser = false
    @State private var browserCommand: WebBrowserCommand?
    @State private var showCopiedHint = false
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var currentURL: URL
    @State private var estimatedProgress = 0.0
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var sharePayload: ServiceSharePayload?
    @State private var showStreamSetup = false
    @State private var playbackRequest: MediaPlaybackRequest?
    @State private var downloadedFileURL: URL?

    init(
        service: LaunchpadService,
        endpoint: URL,
        allowsSelfSignedCertificates: Bool,
        dsmSession: DSMSession? = nil
    ) {
        self.service = service
        self.endpoint = endpoint
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.dsmSession = dsmSession
        _currentURL = State(initialValue: endpoint)
    }

    var body: some View {
        webKitBrowser
            .fullScreenCover(isPresented: $showCompatibilityBrowser) {
                SystemInAppBrowserView(url: currentURL) {
                    showCompatibilityBrowser = false
                }
                .ignoresSafeArea()
            }
    }

    private var webKitBrowser: some View {
        VStack(spacing: 0) {
            ZStack {
                WebContainerView(
                    url: endpoint,
                    prefersDesktopMode: resolvedMode.usesDesktopUserAgent,
                    prefersCompatibilityFallback: service.isDeveloperConsole,
                    expectsDeveloperWorkbench: service.isDeveloperConsole,
                    expectsMetaCubeDashboard: service.isMetaCubeXD,
                    bypassesPersistentWebCache: service.isMetaCubeXD,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                    authenticationCookie: authenticationCookie,
                    command: browserCommand,
                    isLoading: $isLoading,
                    loadError: $loadError,
                    currentURL: $currentURL,
                    estimatedProgress: $estimatedProgress,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    compatibilityFallbackRequested: $showCompatibilityBrowser,
                    pendingMediaURL: Binding(
                        get: { playbackRequest?.url },
                        set: { url in
                            guard let url else { return }
                            playbackRequest = MediaPlaybackRequest(url: url, title: service.name)
                        }
                    ),
                    downloadedFileURL: Binding(
                        get: { downloadedFileURL },
                        set: { url in
                            downloadedFileURL = url
                            if let url {
                                sharePayload = ServiceSharePayload(url: url)
                            }
                        }
                    )
                )
                .background(Color(.systemBackground))

                if !isLoading, let loadError {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("web.load_failed")
                            .font(.headline)
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(4)
                        Button {
                            sendBrowserCommand(.reload)
                        } label: {
                            Label("web.retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(22)
                    .frame(maxWidth: 320)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            if isLoading {
                ProgressView(value: max(estimatedProgress, 0.04))
                    .progressViewStyle(.linear)
                    .tint(AppTheme.accent)
            }
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
                .accessibilityLabel(Text("web.mode.title"))

                Button {
                    sendBrowserCommand(isLoading ? .stop : .reload)
                } label: {
                    Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
                }
                .accessibilityLabel(
                    Text(LocalizedStringKey(isLoading ? "web.stop" : "action.refresh"))
                )

                Menu {
                    Button {
                        UIPasteboard.general.string = currentURL.absoluteString
                        showCopiedHint = true
                    } label: {
                        Label("web.copy_url", systemImage: "link")
                    }
                    Button {
                        UIApplication.shared.open(currentURL)
                    } label: {
                        Label("web.open_safari", systemImage: "safari")
                    }
                    Button {
                        showCompatibilityBrowser = true
                    } label: {
                        Label("web.open_compatibility_browser", systemImage: "safari.fill")
                    }
                    Button {
                        sharePayload = ServiceSharePayload(url: currentURL)
                    } label: {
                        Label("web.share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        showStreamSetup = true
                    } label: {
                        Label("player.open_stream", systemImage: "play.rectangle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel(Text("web.more"))
            }

            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    sendBrowserCommand(.back)
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!canGoBack)
                .accessibilityLabel(Text("web.back"))

                Button {
                    sendBrowserCommand(.forward)
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!canGoForward)
                .accessibilityLabel(Text("web.forward"))

                Spacer()

                Text(currentURL.host ?? service.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    sharePayload = ServiceSharePayload(url: currentURL)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text("web.share"))
            }
        }
        .alert("web.copy.done", isPresented: $showCopiedHint) {
            Button("action.ok", role: .cancel) {}
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .sheet(isPresented: $showStreamSetup) {
            NavigationStack {
                DirectMediaPlayerSetupView(
                    suggestedURL: DirectMediaURLPolicy.isLikelyMediaURL(currentURL) ? currentURL : nil
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("action.done") {
                            showStreamSetup = false
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $playbackRequest, onDismiss: {
            PlayerOrientationController.setPlayerActive(false)
        }) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
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

    private func sendBrowserCommand(_ action: WebBrowserAction) {
        browserCommand = WebBrowserCommand(action: action)
    }

    private var authenticationCookie: HTTPCookie? {
        guard
            let dsmSession,
            let host = endpoint.host,
            host.caseInsensitiveCompare(dsmSession.baseURL.host ?? "") == .orderedSame,
            endpoint.scheme?.lowercased() == "https" || NetworkHostClassifier.isPrivate(host)
        else {
            return nil
        }
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: host,
            .path: "/",
            .name: "id",
            .value: dsmSession.sid
        ]
        if endpoint.scheme?.lowercased() == "https" {
            properties[.secure] = "TRUE"
        }
        return HTTPCookie(properties: properties)
    }
}

private struct SystemInAppBrowserView: UIViewControllerRepresentable {
    let url: URL
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, onDone: onDone)
    }

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        configuration.barCollapsingEnabled = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.delegate = context.coordinator
        controller.dismissButtonStyle = .close
        controller.preferredControlTintColor = UIColor(AppTheme.accent)
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.web",
            messageKey: "diagnostics.web.started",
            details: [
                "engine": "SFSafariViewController",
                "target": DiagnosticLogStore.redactedURL(url)
            ]
        )
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}

    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        let url: URL
        let onDone: () -> Void

        init(url: URL, onDone: @escaping () -> Void) {
            self.url = url
            self.onDone = onDone
        }

        func safariViewController(
            _ controller: SFSafariViewController,
            didCompleteInitialLoad didLoadSuccessfully: Bool
        ) {
            DiagnosticLogStore.shared.record(
                didLoadSuccessfully ? .info : .error,
                categoryKey: "diagnostics.category.web",
                messageKey: didLoadSuccessfully
                    ? "diagnostics.web.completed"
                    : "diagnostics.web.failed",
                details: [
                    "engine": "SFSafariViewController",
                    "target": DiagnosticLogStore.redactedURL(url)
                ]
            )
        }

        func safariViewController(
            _ controller: SFSafariViewController,
            initialLoadDidRedirectTo url: URL
        ) {
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.redirected",
                details: [
                    "engine": "SFSafariViewController",
                    "target": DiagnosticLogStore.redactedURL(url)
                ]
            )
        }

        func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
            onDone()
        }
    }
}

private struct ResolvedWebMode {
    let usesDesktopUserAgent: Bool
}

private enum WebBrowserAction {
    case back
    case forward
    case reload
    case stop
}

private struct WebBrowserCommand {
    let id = UUID()
    let action: WebBrowserAction
}

private struct WebContainerView: UIViewRepresentable {
    let url: URL
    let prefersDesktopMode: Bool
    let prefersCompatibilityFallback: Bool
    let expectsDeveloperWorkbench: Bool
    let expectsMetaCubeDashboard: Bool
    let bypassesPersistentWebCache: Bool
    let allowsSelfSignedCertificates: Bool
    let authenticationCookie: HTTPCookie?
    let command: WebBrowserCommand?
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var currentURL: URL
    @Binding var estimatedProgress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var compatibilityFallbackRequested: Bool
    @Binding var pendingMediaURL: URL?
    @Binding var downloadedFileURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.websiteDataStore = bypassesPersistentWebCache ? .nonPersistent() : .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.isTextInteractionEnabled = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences.preferredContentMode = preferredContentMode
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.suppressesIncrementalRendering = false
        configuration.userContentController.add(context.coordinator, name: Self.diagnosticsHandlerName)
        configuration.userContentController.addUserScript(
            WKUserScript(
                source: Self.diagnosticsScript,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            )
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
#if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
#endif
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.keyboardDismissMode = .none
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.scrollView.delaysContentTouches = false
        context.coordinator.attach(to: webView)
        context.coordinator.load(url, in: webView)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if uiView.configuration.defaultWebpagePreferences.preferredContentMode != preferredContentMode {
            uiView.configuration.defaultWebpagePreferences.preferredContentMode = preferredContentMode
            context.coordinator.load(url, in: uiView)
            return
        }
        if context.coordinator.lastRequestedURL != url {
            context.coordinator.load(url, in: uiView)
        }
        if let command, context.coordinator.lastCommandID != command.id {
            context.coordinator.lastCommandID = command.id
            context.coordinator.perform(command.action, in: uiView)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private var preferredContentMode: WKWebpagePreferences.ContentMode {
        prefersDesktopMode ? .desktop : .mobile
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        coordinator.invalidateObservations()
        uiView.configuration.userContentController.removeScriptMessageHandler(
            forName: diagnosticsHandlerName
        )
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }

    private static let diagnosticsHandlerName = "nastartWebDiagnostics"

    private static let diagnosticsScript = """
    (() => {
      if (window.__nastartDiagnosticsInstalled) return;
      window.__nastartDiagnosticsInstalled = true;
      const send = (kind, value, details = {}) => {
        try {
          window.webkit.messageHandlers.nastartWebDiagnostics.postMessage({
            kind,
            message: String(value ?? '').slice(0, 600),
            source: String(details.source || '').slice(0, 600),
            line: Number(details.line || 0),
            column: Number(details.column || 0),
            stack: String(details.stack || '').slice(0, 1200)
          });
        } catch (_) {}
      };
      ['error', 'warn'].forEach((level) => {
        const original = console[level];
        console[level] = (...args) => {
          send(`console.${level}`, args.map((item) => String(item)).join(' '));
          original.apply(console, args);
        };
      });
      window.addEventListener('error', (event) => {
        send('window.error', event.message || event.error || 'Unknown script error', {
          source: event.filename,
          line: event.lineno,
          column: event.colno,
          stack: event.error?.stack
        });
      });
      window.addEventListener('unhandledrejection', (event) => {
        send('promise.rejection', event.reason || 'Unhandled promise rejection', {
          stack: event.reason?.stack
        });
      });
    })();
    """

    private static let renderProbeScript = """
    (() => ({
      readyState: document.readyState || '',
      bodyTextLength: (document.body?.innerText || '').trim().length,
      bodyChildCount: document.body?.children?.length || 0,
      htmlLength: document.documentElement?.outerHTML?.length || 0,
      title: document.title || '',
      viewportWidth: window.innerWidth || 0,
      viewportHeight: window.innerHeight || 0,
      hasLoginForm: Boolean(document.querySelector('input[type="password"]')),
      hasWorkbench: Boolean(document.querySelector(
        '.monaco-workbench, .monaco-editor, [id="workbench.parts.editor"]'
      )),
      nuxtChildCount: document.querySelector('#__nuxt')?.children?.length || 0,
      appRootChildCount: (() => {
        const root = document.querySelector('#__nuxt, #app, #root, [data-v-app]');
        return root?.children?.length || 0;
      })(),
      canvasCount: document.querySelectorAll('canvas').length,
      codeServerVersion: (() => {
        try {
          const raw = document.querySelector('meta#coder-options')?.dataset?.settings;
          return raw ? String(JSON.parse(raw).codeServerVersion || '') : '';
        } catch (_) {
          return '';
        }
      })()
    }))();
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate,
        WKScriptMessageHandler {
        var parent: WebContainerView
        var lastCommandID: UUID?
        var lastRequestedURL: URL?
        private var progressObservation: NSKeyValueObservation?
        private var renderCheckWorkItem: DispatchWorkItem?
        private var stateSyncWorkItem: DispatchWorkItem?
        private var downloadDestinations: [ObjectIdentifier: URL] = [:]
        private var lastPublishedURL: URL?
        private var lastPublishedProgress = -1.0
        private var lastPublishedCanGoBack: Bool?
        private var lastPublishedCanGoForward: Bool?
        private var processRecoveryCount = 0
        private var loadStartedAt: Date?
        private var didRequestCompatibilityFallback = false
        private var scriptDiagnosticCount = 0

        init(parent: WebContainerView) {
            self.parent = parent
        }

        func attach(to webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self, weak webView] _, _ in
                guard let self, let webView else { return }
                self.syncState(from: webView)
            }
        }

        func invalidateObservations() {
            progressObservation?.invalidate()
            progressObservation = nil
            renderCheckWorkItem?.cancel()
            renderCheckWorkItem = nil
            stateSyncWorkItem?.cancel()
            stateSyncWorkItem = nil
        }

        func load(_ url: URL, in webView: WKWebView) {
            lastRequestedURL = url
            loadStartedAt = Date()
            renderCheckWorkItem?.cancel()
            didRequestCompatibilityFallback = false
            scriptDiagnosticCount = 0
            setLoading(true, error: nil)
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.started",
                details: [
                    "engine": "WKWebView",
                    "target": DiagnosticLogStore.redactedURL(url),
                    "desktop": parent.prefersDesktopMode ? "on" : "off",
                    "persistentCache": parent.bypassesPersistentWebCache ? "off" : "on",
                    "selfSigned": parent.allowsSelfSignedCertificates ? "on" : "off",
                    "sessionCookie": parent.authenticationCookie == nil ? "off" : "on"
                ]
            )
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            if parent.bypassesPersistentWebCache {
                request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            }
            guard let cookie = parent.authenticationCookie else {
                webView.load(request)
                return
            }
            webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { [weak self, weak webView] in
                DispatchQueue.main.async {
                    guard let self, let webView, self.lastRequestedURL == url else { return }
                    webView.load(request)
                }
            }
        }

        func perform(_ action: WebBrowserAction, in webView: WKWebView) {
            switch action {
            case .back:
                if webView.canGoBack { webView.goBack() }
            case .forward:
                if webView.canGoForward { webView.goForward() }
            case .reload:
                didRequestCompatibilityFallback = false
                scriptDiagnosticCount = 0
                loadStartedAt = Date()
                if webView.url == nil {
                    load(parent.url, in: webView)
                } else {
                    setLoading(true, error: nil)
                    if parent.bypassesPersistentWebCache {
                        webView.reloadFromOrigin()
                    } else {
                        webView.reload()
                    }
                }
            case .stop:
                webView.stopLoading()
                setLoading(false, error: nil)
            }
            syncState(from: webView)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            renderCheckWorkItem?.cancel()
            setLoading(true, error: nil)
            syncState(from: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.committed",
                details: [
                    "engine": "WKWebView",
                    "target": DiagnosticLogStore.redactedURL(webView.url ?? parent.url)
                ]
            )
            scheduleRenderCheck(in: webView, after: 7, trigger: "commitTimeout")
            syncState(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            renderCheckWorkItem?.cancel()
            processRecoveryCount = 0
            setLoading(false, error: nil)
            syncState(from: webView, immediately: true)
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.completed",
                details: [
                    "engine": "WKWebView",
                    "target": DiagnosticLogStore.redactedURL(webView.url ?? parent.url),
                    "durationMs": loadStartedAt.map {
                        "\(Int(Date().timeIntervalSince($0) * 1000))"
                    } ?? "-"
                ]
            )
            scheduleRenderCheck(
                in: webView,
                after: parent.expectsDeveloperWorkbench ? 5 : 1.2,
                trigger: "didFinish"
            )
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            renderCheckWorkItem?.cancel()
            DiagnosticLogStore.shared.record(
                .error,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.process_terminated",
                details: [
                    "engine": "WKWebView",
                    "target": DiagnosticLogStore.redactedURL(webView.url ?? parent.url),
                    "recovery": processRecoveryCount < 1 ? "reload" : "stopped"
                ]
            )
            guard processRecoveryCount < 1 else {
                setLoading(false, error: NSLocalizedString("web.process_terminated", comment: ""))
                return
            }
            processRecoveryCount += 1
            setLoading(true, error: nil)
            webView.reload()
        }

        func webView(
            _ webView: WKWebView,
            didFail navigation: WKNavigation!,
            withError error: Error
        ) {
            handleLoadError(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleLoadError(error, in: webView)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let scheme = targetURL.scheme?.lowercased()
            if scheme == "http" || scheme == "https" || scheme == "about" {
                if navigationAction.navigationType == .linkActivated,
                   DirectMediaURLPolicy.isLikelyMediaURL(targetURL) {
                    decisionHandler(.cancel)
                    DispatchQueue.main.async {
                        self.parent.pendingMediaURL = targetURL
                    }
                    return
                }
                decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow)
            } else {
                decisionHandler(.cancel)
                guard navigationAction.navigationType == .linkActivated else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.open(targetURL)
                }
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            let contentDisposition = (navigationResponse.response as? HTTPURLResponse)?
                .value(forHTTPHeaderField: "Content-Disposition")?
                .lowercased()
            let isAttachment = contentDisposition?.contains("attachment") == true
            decisionHandler(isAttachment || !navigationResponse.canShowMIMEType ? .download : .allow)
        }

        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            let safeFilename = suggestedFilename.replacingOccurrences(of: "/", with: "-")
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("NastartDownloads", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let destination = directory.appendingPathComponent(
                "\(UUID().uuidString)-\(safeFilename.isEmpty ? "download" : safeFilename)"
            )
            downloadDestinations[ObjectIdentifier(download)] = destination
            completionHandler(destination)
        }

        func downloadDidFinish(_ download: WKDownload) {
            guard let destination = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else {
                return
            }
            DispatchQueue.main.async {
                self.parent.downloadedFileURL = destination
            }
        }

        func download(
            _ download: WKDownload,
            didFailWithError error: Error,
            resumeData: Data?
        ) {
            downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
            setLoading(false, error: error.localizedDescription)
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
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping () -> Void
        ) {
            let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("action.ok", comment: ""),
                style: .default
            ) { _ in
                completionHandler()
            })
            if !present(alert, from: webView) {
                completionHandler()
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (Bool) -> Void
        ) {
            let alert = UIAlertController(title: webView.title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("action.cancel", comment: ""),
                style: .cancel
            ) { _ in
                completionHandler(false)
            })
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("action.ok", comment: ""),
                style: .default
            ) { _ in
                completionHandler(true)
            })
            if !present(alert, from: webView) {
                completionHandler(false)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping (String?) -> Void
        ) {
            let alert = UIAlertController(title: webView.title, message: prompt, preferredStyle: .alert)
            alert.addTextField { textField in
                textField.text = defaultText
            }
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("action.cancel", comment: ""),
                style: .cancel
            ) { _ in
                completionHandler(nil)
            })
            alert.addAction(UIAlertAction(
                title: NSLocalizedString("action.ok", comment: ""),
                style: .default
            ) { _ in
                completionHandler(alert.textFields?.first?.text)
            })
            if !present(alert, from: webView) {
                completionHandler(nil)
            }
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard
                message.name == WebContainerView.diagnosticsHandlerName,
                scriptDiagnosticCount < 40,
                let payload = message.body as? [String: Any]
            else { return }
            scriptDiagnosticCount += 1
            let kind = payload["kind"] as? String ?? "script"
            let text = payload["message"] as? String ?? "-"
            let source = payload["source"] as? String ?? ""
            let line = (payload["line"] as? NSNumber)?.intValue ?? 0
            let column = (payload["column"] as? NSNumber)?.intValue ?? 0
            let stack = payload["stack"] as? String ?? ""
            DiagnosticLogStore.shared.record(
                .error,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.script_error",
                details: [
                    "kind": String(kind.prefix(80)),
                    "message": sanitizedScriptDiagnostic(text),
                    "source": sanitizedScriptSource(source),
                    "line": line > 0 ? "\(line)" : "-",
                    "column": column > 0 ? "\(column)" : "-",
                    "stack": stack.isEmpty ? "-" : sanitizedScriptDiagnostic(stack),
                    "target": DiagnosticLogStore.redactedURL(parent.currentURL)
                ]
            )
            if parent.expectsDeveloperWorkbench,
               (kind == "window.error" || kind == "promise.rejection"),
               (text.localizedCaseInsensitiveContains("syntaxerror")
                || text.localizedCaseInsensitiveContains("unexpected token")) {
                renderCheckWorkItem?.cancel()
                setLoading(
                    false,
                    error: NSLocalizedString("web.developer_script_failed", comment: "")
                )
            }
        }

        private func sanitizedScriptDiagnostic(_ value: String) -> String {
            let withoutURLs = value.replacingOccurrences(
                of: #"https?://[^\s\"'<>]+"#,
                with: "<url>",
                options: [.regularExpression, .caseInsensitive]
            )
            let withoutSecrets = withoutURLs.replacingOccurrences(
                of: #"(token|password|passwd|authorization|cookie)(\s*[:=]\s*)[^\s,;]+"#,
                with: "$1$2<redacted>",
                options: [.regularExpression, .caseInsensitive]
            )
            return String(withoutSecrets.prefix(600))
        }

        private func sanitizedScriptSource(_ value: String) -> String {
            guard !value.isEmpty else { return "-" }
            if let url = URL(string: value), !url.lastPathComponent.isEmpty {
                return String(url.lastPathComponent.prefix(160))
            }
            return String(sanitizedScriptDiagnostic(value).prefix(160))
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trustedHost = parent.url.host,
               challenge.protectionSpace.host.caseInsensitiveCompare(trustedHost) != .orderedSame {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            guard
                parent.allowsSelfSignedCertificates,
                let credential = CertificatePinStore.shared.credential(
                    for: challenge,
                    expectedHost: parent.url.host
                )
            else {
                let shouldReject = parent.allowsSelfSignedCertificates
                    && challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust
                completionHandler(shouldReject ? .cancelAuthenticationChallenge : .performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, credential)
        }

        private func inspectRenderedPage(in webView: WKWebView, trigger: String) {
            webView.evaluateJavaScript(WebContainerView.renderProbeScript) { [weak self, weak webView] result, error in
                DispatchQueue.main.async {
                    guard let self, let webView else { return }
                    self.renderCheckWorkItem = nil

                    if let error {
                        self.recordRenderCheck(
                            webView: webView,
                            details: [
                                "trigger": trigger,
                                "probeError": (error as NSError).localizedDescription
                            ]
                        )
                        self.requestCompatibilityFallbackIfNeeded(webView: webView, reason: "probeError")
                        return
                    }

                    guard let values = result as? [String: Any] else {
                        self.recordRenderCheck(
                            webView: webView,
                            details: ["trigger": trigger, "result": "invalid"]
                        )
                        self.requestCompatibilityFallbackIfNeeded(webView: webView, reason: "invalidProbe")
                        return
                    }

                    let readyState = values["readyState"] as? String ?? "-"
                    let bodyTextLength = (values["bodyTextLength"] as? NSNumber)?.intValue ?? 0
                    let bodyChildCount = (values["bodyChildCount"] as? NSNumber)?.intValue ?? 0
                    let htmlLength = (values["htmlLength"] as? NSNumber)?.intValue ?? 0
                    let title = values["title"] as? String ?? ""
                    let viewportWidth = (values["viewportWidth"] as? NSNumber)?.intValue ?? 0
                    let viewportHeight = (values["viewportHeight"] as? NSNumber)?.intValue ?? 0
                    let hasLoginForm = (values["hasLoginForm"] as? NSNumber)?.boolValue ?? false
                    let hasWorkbench = (values["hasWorkbench"] as? NSNumber)?.boolValue ?? false
                    let nuxtChildCount = (values["nuxtChildCount"] as? NSNumber)?.intValue ?? 0
                    let appRootChildCount = (values["appRootChildCount"] as? NSNumber)?.intValue ?? 0
                    let canvasCount = (values["canvasCount"] as? NSNumber)?.intValue ?? 0
                    let codeServerVersion = values["codeServerVersion"] as? String ?? ""
                    let hasRenderedContent: Bool
                    if self.parent.expectsDeveloperWorkbench {
                        hasRenderedContent = hasLoginForm || hasWorkbench
                    } else if self.parent.expectsMetaCubeDashboard {
                        hasRenderedContent = appRootChildCount > 0
                            && (bodyTextLength > 0 || canvasCount > 0)
                    } else {
                        hasRenderedContent = bodyChildCount > 0 && htmlLength >= 200
                    }

                    self.recordRenderCheck(
                        webView: webView,
                        details: [
                            "readyState": readyState,
                            "trigger": trigger,
                            "bodyTextLength": "\(bodyTextLength)",
                            "bodyChildCount": "\(bodyChildCount)",
                            "htmlLength": "\(htmlLength)",
                            "titleLength": "\(title.count)",
                            "viewport": "\(viewportWidth)x\(viewportHeight)",
                            "loginForm": hasLoginForm ? "yes" : "no",
                            "workbench": hasWorkbench ? "yes" : "no",
                            "nuxtChildCount": "\(nuxtChildCount)",
                            "appRootChildCount": "\(appRootChildCount)",
                            "canvasCount": "\(canvasCount)",
                            "codeServerVersion": codeServerVersion.isEmpty ? "-" : codeServerVersion,
                            "rendered": hasRenderedContent ? "yes" : "no"
                        ]
                    )

                    if hasRenderedContent {
                        self.setLoading(false, error: nil)
                        self.syncState(from: webView, immediately: true)
                    } else if self.parent.expectsDeveloperWorkbench {
                        DiagnosticLogStore.shared.record(
                            .error,
                            categoryKey: "diagnostics.category.web",
                            messageKey: "diagnostics.web.developer_workbench_missing",
                            details: [
                                "reason": "loginCompletedWithoutWorkbench",
                                "target": DiagnosticLogStore.redactedURL(webView.url ?? self.parent.url)
                            ]
                        )
                        self.setLoading(
                            false,
                            error: NSLocalizedString("web.developer_workbench_missing", comment: "")
                        )
                    } else {
                        self.requestCompatibilityFallbackIfNeeded(webView: webView, reason: "blankDOM")
                    }
                }
            }
        }

        private func requestCompatibilityFallbackIfNeeded(webView: WKWebView, reason: String) {
            guard parent.prefersCompatibilityFallback else {
                setLoading(false, error: NSLocalizedString("web.blank_page", comment: ""))
                return
            }
            guard !didRequestCompatibilityFallback else { return }
            didRequestCompatibilityFallback = true
            setLoading(false, error: nil)
            DiagnosticLogStore.shared.record(
                .error,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.compatibility_fallback",
                details: [
                    "reason": reason,
                    "target": DiagnosticLogStore.redactedURL(webView.url ?? parent.url)
                ]
            )
            parent.compatibilityFallbackRequested = true
        }

        private func recordRenderCheck(webView: WKWebView, details: [String: String]) {
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.render_check",
                details: details.merging([
                    "target": DiagnosticLogStore.redactedURL(webView.url ?? parent.url)
                ]) { current, _ in current }
            )
        }

        private func handleLoadError(_ error: Error, in webView: WKWebView) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            DiagnosticLogStore.shared.record(
                .error,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.failed",
                details: [
                    "engine": "WKWebView",
                    "target": DiagnosticLogStore.redactedURL(parent.url),
                    "errorDomain": nsError.domain,
                    "errorCode": "\(nsError.code)"
                ]
            )
            renderCheckWorkItem?.cancel()
            if parent.prefersCompatibilityFallback {
                requestCompatibilityFallbackIfNeeded(webView: webView, reason: "navigationError")
            } else {
                setLoading(false, error: error.localizedDescription)
            }
        }

        private func syncState(from webView: WKWebView, immediately: Bool = false) {
            if immediately {
                stateSyncWorkItem?.cancel()
                stateSyncWorkItem = nil
                publishState(from: webView)
                return
            }
            guard stateSyncWorkItem == nil else { return }
            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.stateSyncWorkItem = nil
                self.publishState(from: webView)
            }
            stateSyncWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
        }

        private func publishState(from webView: WKWebView) {
            dispatchPrecondition(condition: .onQueue(.main))
            if let url = webView.url, url != lastPublishedURL {
                lastPublishedURL = url
                parent.currentURL = url
            }

            let progress = webView.estimatedProgress
            if progress != lastPublishedProgress,
               abs(progress - lastPublishedProgress) >= 0.02 || progress == 1 {
                lastPublishedProgress = progress
                parent.estimatedProgress = progress
            }
            if webView.canGoBack != lastPublishedCanGoBack {
                lastPublishedCanGoBack = webView.canGoBack
                parent.canGoBack = webView.canGoBack
            }
            if webView.canGoForward != lastPublishedCanGoForward {
                lastPublishedCanGoForward = webView.canGoForward
                parent.canGoForward = webView.canGoForward
            }
        }

        private func scheduleRenderCheck(
            in webView: WKWebView,
            after delay: TimeInterval,
            trigger: String
        ) {
            renderCheckWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak webView] in
                guard let self, let webView, webView.url != nil else { return }
                self.inspectRenderedPage(in: webView, trigger: trigger)
            }
            renderCheckWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        private func present(_ controller: UIViewController, from webView: WKWebView) -> Bool {
            guard var presenter = webView.window?.rootViewController else { return false }
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(controller, animated: true)
            return true
        }

        private func setLoading(_ loading: Bool, error: String?) {
            DispatchQueue.main.async {
                if self.parent.isLoading != loading {
                    self.parent.isLoading = loading
                }
                if self.parent.loadError != error {
                    self.parent.loadError = error
                }
            }
        }
    }
}

enum DirectMediaURLPolicy {
    private static let mediaExtensions = [
        "m3u8", "mp4", "mkv", "mov", "m4v", "avi", "wmv", "webm",
        "ts", "m2ts", "mts", "mpeg", "mpg", "flv", "f4v", "3gp", "3g2",
        "vob", "rm", "rmvb", "ogv", "asf", "divx", "mxf", "m2v", "m1v",
        "mpv", "qt", "dv", "h264", "h265", "hevc", "av1", "nut", "amv",
        "bik", "roq", "wtv", "dvr-ms", "mod", "tod",
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "wma", "ape",
        "alac", "aiff", "aif", "amr", "ac3", "dts"
    ]

    static func canAttemptPlayback(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return url.host?.isEmpty == false
    }

    static func isLikelyMediaURL(_ url: URL) -> Bool {
        guard canAttemptPlayback(url) else { return false }
        let normalizedURL = url.absoluteString.lowercased()
        return mediaExtensions.contains(url.pathExtension.lowercased())
            || mediaExtensions.contains { normalizedURL.contains(".\($0)?") }
    }
}

private struct PlaybackNetworkSnapshot: Sendable {
    let cacheKey: String
    let bitrateCap: Int?
    let fallbackBitrate: Int
}

/// The source media and the device runtime are separate capability inputs.
/// Keep the runtime facts in diagnostics so an iPhone/iPad comparison can
/// prove whether the server plan or the local player is the diverging side.
private struct MediaPlaybackCapabilities {
    let deviceFamily: String
    let osVersion: String
    let compatibilityEngineAvailable: Bool

    static var current: MediaPlaybackCapabilities {
        let device = UIDevice.current
        let family: String
        switch device.userInterfaceIdiom {
        case .pad: family = "iPad"
        case .phone: family = "iPhone"
        case .tv: family = "AppleTV"
        default: family = "other"
        }
        return MediaPlaybackCapabilities(
            deviceFamily: family,
            osVersion: device.systemVersion,
            compatibilityEngineAvailable: MediaPlaybackPolicy.hasCompatibilityEngine
        )
    }

    var diagnosticDetails: [String: String] {
        [
            "deviceFamily": deviceFamily,
            "osVersion": osVersion,
            "compatibilityEngine": compatibilityEngineAvailable ? "available" : "unavailable"
        ]
    }
}

private final class PlaybackNetworkObserver: @unchecked Sendable {
    static let shared = PlaybackNetworkObserver()

    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var currentSnapshot = PlaybackNetworkSnapshot(
        cacheKey: "unknown",
        bitrateCap: 20_000_000,
        fallbackBitrate: 6_000_000
    )

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let snapshot: PlaybackNetworkSnapshot
            if path.isConstrained {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: "constrained",
                    bitrateCap: 6_000_000,
                    fallbackBitrate: 2_500_000
                )
            } else if path.usesInterfaceType(.cellular) {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: "cellular",
                    bitrateCap: path.isExpensive ? 12_000_000 : 16_000_000,
                    fallbackBitrate: 4_000_000
                )
            } else if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: "wifi",
                    bitrateCap: 80_000_000,
                    fallbackBitrate: 8_000_000
                )
            } else {
                snapshot = PlaybackNetworkSnapshot(
                    cacheKey: path.isExpensive ? "expensive" : "other",
                    bitrateCap: path.isExpensive ? 10_000_000 : 20_000_000,
                    fallbackBitrate: path.isExpensive ? 3_500_000 : 6_000_000
                )
            }
            self?.lock.lock()
            self?.currentSnapshot = snapshot
            self?.lock.unlock()
        }
        monitor.start(queue: DispatchQueue(label: "com.changliwen.nastart.playback-network"))
    }

    func snapshot() -> PlaybackNetworkSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return currentSnapshot
    }
}

struct MediaPlaybackResource {
    let url: URL
    let fileExtensionOverride: String?
    let subtitleURL: URL?
    let playbackTracker: MediaPlaybackTracker?
    let forcesSoftwareDecoding: Bool
    let allowsSelfSignedCertificates: Bool?
    let timelineOffsetSeconds: Double?
    let totalDurationSeconds: Double?

    init(
        url: URL,
        fileExtensionOverride: String? = nil,
        subtitleURL: URL? = nil,
        playbackTracker: MediaPlaybackTracker? = nil,
        forcesSoftwareDecoding: Bool = false,
        allowsSelfSignedCertificates: Bool? = nil,
        timelineOffsetSeconds: Double? = nil,
        totalDurationSeconds: Double? = nil
    ) {
        self.url = url
        self.fileExtensionOverride = fileExtensionOverride
        self.subtitleURL = subtitleURL
        self.playbackTracker = playbackTracker
        self.forcesSoftwareDecoding = forcesSoftwareDecoding
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.timelineOffsetSeconds = timelineOffsetSeconds
        self.totalDurationSeconds = totalDurationSeconds
    }
}

struct MediaPlaybackRuntimeState {
    let normalizedPosition: Double?
    let positionSeconds: Double?
    let playbackRate: Float
    let audioTrackOrdinal: Int?
    let subtitleTrackOrdinal: Int?
    let subtitlesDisabled: Bool
    let subtitleSelectionKnown: Bool
    let orientationMode: PlayerOrientationMode
}

struct MediaPlaybackSourceTrack: Identifiable, Equatable {
    let id: Int
    let name: String
    let externalURL: URL?

    init(id: Int, name: String, externalURL: URL? = nil) {
        self.id = id
        self.name = name
        self.externalURL = externalURL
    }
}

enum MediaPlaybackContentKind {
    case automatic
    case video
    case audio
    case discImage
}

struct MediaPlaybackQualityOption: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String?
}

struct MediaPlaybackRequest: Identifiable {
    let id = UUID()
    let requestedAt: Date
    let url: URL
    let title: String
    let allowsSelfSignedCertificates: Bool
    let source: MediaPlaybackSource
    let contentKind: MediaPlaybackContentKind
    let fileExtensionOverride: String?
    let initialPosition: Double?
    let externalSubtitleURL: URL?
    let preferredAudioTrackOrdinal: Int?
    let preferredSubtitleTrackOrdinal: Int?
    let prefersSubtitlesDisabled: Bool
    let initialOrientationMode: PlayerOrientationMode
    let initialPlaybackRate: Float
    let timelineOffsetSeconds: Double
    let totalDurationSeconds: Double?
    let isPrivateNetworkRoute: Bool?
    let forcesSoftwareDecoding: Bool
    let playbackTracker: MediaPlaybackTracker?
    let compatibilityResource: MediaPlaybackResource?
    let compatibilityFallbackResource: MediaPlaybackResource?
    let externalHandoffResource: MediaPlaybackResource?
    let compatibilityResourceLoader: (() async -> MediaPlaybackResource?)?
    let compatibilityFallbackResourceLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackResource?)?
    let compatibilityFallbackRequestLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)?
    let externalHandoffResourceLoader: (() async -> MediaPlaybackResource?)?
    let sourceAudioTracks: [MediaPlaybackSourceTrack]
    let sourceSubtitleTracks: [MediaPlaybackSourceTrack]
    let selectedSourceAudioTrackID: Int?
    let selectedSourceSubtitleTrackID: Int?
    let sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
    let qualityOptions: [MediaPlaybackQualityOption]
    let selectedQualityID: String?
    let qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?

    init(
        requestedAt: Date = Date(),
        url: URL,
        title: String,
        allowsSelfSignedCertificates: Bool = false,
        source: MediaPlaybackSource = .directURL,
        contentKind: MediaPlaybackContentKind = .automatic,
        fileExtensionOverride: String? = nil,
        initialPosition: Double? = nil,
        externalSubtitleURL: URL? = nil,
        preferredAudioTrackOrdinal: Int? = nil,
        preferredSubtitleTrackOrdinal: Int? = nil,
        prefersSubtitlesDisabled: Bool = false,
        initialOrientationMode: PlayerOrientationMode = .landscape,
        initialPlaybackRate: Float = 1,
        timelineOffsetSeconds: Double = 0,
        totalDurationSeconds: Double? = nil,
        isPrivateNetworkRoute: Bool? = nil,
        forcesSoftwareDecoding: Bool = false,
        playbackTracker: MediaPlaybackTracker? = nil,
        compatibilityResource: MediaPlaybackResource? = nil,
        compatibilityFallbackResource: MediaPlaybackResource? = nil,
        externalHandoffResource: MediaPlaybackResource? = nil,
        compatibilityResourceLoader: (() async -> MediaPlaybackResource?)? = nil,
        compatibilityFallbackResourceLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackResource?)? = nil,
        compatibilityFallbackRequestLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)? = nil,
        externalHandoffResourceLoader: (() async -> MediaPlaybackResource?)? = nil,
        sourceAudioTracks: [MediaPlaybackSourceTrack] = [],
        sourceSubtitleTracks: [MediaPlaybackSourceTrack] = [],
        selectedSourceAudioTrackID: Int? = nil,
        selectedSourceSubtitleTrackID: Int? = nil,
        sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = nil,
        serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = nil,
        qualityOptions: [MediaPlaybackQualityOption] = [],
        selectedQualityID: String? = nil,
        qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)? = nil
    ) {
        self.requestedAt = requestedAt
        self.url = url
        self.title = title
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.source = source
        self.contentKind = contentKind
        self.fileExtensionOverride = fileExtensionOverride
        self.initialPosition = initialPosition.map { min(max($0, 0), 1) }
        self.externalSubtitleURL = externalSubtitleURL
        self.preferredAudioTrackOrdinal = preferredAudioTrackOrdinal
        self.preferredSubtitleTrackOrdinal = preferredSubtitleTrackOrdinal
        self.prefersSubtitlesDisabled = prefersSubtitlesDisabled
        self.initialOrientationMode = initialOrientationMode
        self.initialPlaybackRate = min(max(initialPlaybackRate, 0.25), 4)
        self.timelineOffsetSeconds = max(timelineOffsetSeconds, 0)
        self.totalDurationSeconds = totalDurationSeconds.flatMap { $0 > 0 ? $0 : nil }
        self.isPrivateNetworkRoute = isPrivateNetworkRoute
        self.forcesSoftwareDecoding = forcesSoftwareDecoding
        self.playbackTracker = playbackTracker
        self.compatibilityResource = compatibilityResource
        self.compatibilityFallbackResource = compatibilityFallbackResource
        self.externalHandoffResource = externalHandoffResource
        self.compatibilityResourceLoader = compatibilityResourceLoader
        self.compatibilityFallbackResourceLoader = compatibilityFallbackResourceLoader
        self.compatibilityFallbackRequestLoader = compatibilityFallbackRequestLoader
        self.externalHandoffResourceLoader = externalHandoffResourceLoader
        self.sourceAudioTracks = sourceAudioTracks
        self.sourceSubtitleTracks = sourceSubtitleTracks
        self.selectedSourceAudioTrackID = selectedSourceAudioTrackID
        self.selectedSourceSubtitleTrackID = selectedSourceSubtitleTrackID
        self.sourceTrackRequestLoader = sourceTrackRequestLoader
        self.serverSeekRequestLoader = serverSeekRequestLoader
        self.qualityOptions = qualityOptions
        self.selectedQualityID = selectedQualityID
        self.qualityRequestLoader = qualityRequestLoader
    }

    var fileExtensionHint: String {
        if let fileExtensionOverride, !fileExtensionOverride.isEmpty {
            return fileExtensionOverride.lowercased()
        }
        let titleExtension = URL(fileURLWithPath: title).pathExtension.lowercased()
        return titleExtension.isEmpty ? url.pathExtension.lowercased() : titleExtension
    }

    var mimeTypeHint: String? {
        switch fileExtensionHint {
        case "mp4", "m4v": return "video/mp4"
        case "mov": return "video/quicktime"
        case "m3u8": return "application/vnd.apple.mpegurl"
        case "ts", "m2ts": return "video/mp2t"
        case "mp3": return "audio/mpeg"
        case "m4a", "aac": return "audio/mp4"
        case "wav": return "audio/wav"
        default: return nil
        }
    }

    var isAudioOnly: Bool {
        switch contentKind {
        case .audio:
            return true
        case .video, .discImage:
            return false
        case .automatic:
            return Self.audioExtensions.contains(fileExtensionHint)
        }
    }

    private static let audioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "wma",
        "ape", "alac", "aiff", "aif", "amr", "ac3", "dts"
    ]

    var allowsExternalHandoff: Bool {
        let handoffURL = externalHandoffResource?.url ?? url
        guard let scheme = handoffURL.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        return true
    }

    var containsSensitiveCredential: Bool {
        let sensitiveQueryNames = Set([
            "_sid", "api_key", "apikey", "token", "access_token", "authorization"
        ])
        let handoffURL = externalHandoffResource?.url ?? url
        let queryItems = URLComponents(url: handoffURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return queryItems.contains { sensitiveQueryNames.contains($0.name.lowercased()) }
    }

    var externalFilename: String {
        let extensionHint = externalHandoffFileExtensionHint
        guard !extensionHint.isEmpty,
              URL(fileURLWithPath: title).pathExtension.isEmpty else {
            return title
        }
        return "\(title).\(extensionHint)"
    }

    var externalHandoffURL: URL {
        externalHandoffResource?.url ?? url
    }

    var externalHandoffSubtitleURL: URL? {
        externalHandoffResource?.subtitleURL ?? externalSubtitleURL
    }

    var externalHandoffFileExtensionHint: String {
        if let override = externalHandoffResource?.fileExtensionOverride, !override.isEmpty {
            return override.lowercased()
        }
        return fileExtensionHint
    }

    var networkOriginURL: URL {
        externalHandoffResource?.url ?? url
    }

    var compatibilityPlaybackRequest: MediaPlaybackRequest {
        guard let compatibilityResource else { return self }
        return playbackRequest(using: compatibilityResource)
    }

    func playbackRequest(
        using resource: MediaPlaybackResource,
        initialPositionOverride: Double? = nil,
        runtimeState: MediaPlaybackRuntimeState? = nil,
        retainsFallback: Bool = true
    ) -> MediaPlaybackRequest {
        return MediaPlaybackRequest(
            requestedAt: requestedAt,
            url: resource.url,
            title: title,
            allowsSelfSignedCertificates: resource.allowsSelfSignedCertificates
                ?? allowsSelfSignedCertificates,
            source: source,
            contentKind: contentKind,
            fileExtensionOverride: resource.fileExtensionOverride,
            initialPosition: resource.timelineOffsetSeconds == nil
                ? runtimeState?.normalizedPosition ?? initialPositionOverride ?? initialPosition
                : nil,
            externalSubtitleURL: resource.subtitleURL,
            preferredAudioTrackOrdinal: runtimeState?.audioTrackOrdinal ?? preferredAudioTrackOrdinal,
            preferredSubtitleTrackOrdinal: runtimeState?.subtitleTrackOrdinal ?? preferredSubtitleTrackOrdinal,
            prefersSubtitlesDisabled: runtimeState.map {
                $0.subtitleSelectionKnown ? $0.subtitlesDisabled : prefersSubtitlesDisabled
            } ?? prefersSubtitlesDisabled,
            initialOrientationMode: runtimeState?.orientationMode ?? initialOrientationMode,
            initialPlaybackRate: runtimeState?.playbackRate ?? initialPlaybackRate,
            timelineOffsetSeconds: resource.timelineOffsetSeconds ?? timelineOffsetSeconds,
            totalDurationSeconds: resource.totalDurationSeconds ?? totalDurationSeconds,
            isPrivateNetworkRoute: isPrivateNetworkRoute,
            forcesSoftwareDecoding: resource.forcesSoftwareDecoding,
            playbackTracker: resource.playbackTracker ?? playbackTracker,
            compatibilityFallbackResource: retainsFallback ? compatibilityFallbackResource : nil,
            externalHandoffResource: externalHandoffResource,
            compatibilityFallbackResourceLoader: retainsFallback
                ? compatibilityFallbackResourceLoader
                : nil,
            compatibilityFallbackRequestLoader: retainsFallback
                ? compatibilityFallbackRequestLoader
                : nil,
            externalHandoffResourceLoader: externalHandoffResourceLoader,
            sourceAudioTracks: sourceAudioTracks,
            sourceSubtitleTracks: sourceSubtitleTracks,
            selectedSourceAudioTrackID: selectedSourceAudioTrackID,
            selectedSourceSubtitleTrackID: selectedSourceSubtitleTrackID,
            sourceTrackRequestLoader: sourceTrackRequestLoader,
            serverSeekRequestLoader: serverSeekRequestLoader,
            qualityOptions: qualityOptions,
            selectedQualityID: selectedQualityID,
            qualityRequestLoader: qualityRequestLoader
        )
    }

    func applyingRuntimePreferences(_ runtimeState: MediaPlaybackRuntimeState) -> MediaPlaybackRequest {
        MediaPlaybackRequest(
            requestedAt: requestedAt,
            url: url,
            title: title,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            source: source,
            contentKind: contentKind,
            fileExtensionOverride: fileExtensionOverride,
            // A replacement resource must resume at the live playhead. Keeping
            // the request's original entry.progress here makes a quality or
            // source-track switch jump back to where playback initially began.
            // Transcoded HLS carries an absolute server start time instead, so
            // its relative playhead intentionally remains nil.
            initialPosition: timelineOffsetSeconds > 0
                ? nil
                : runtimeState.normalizedPosition ?? initialPosition,
            externalSubtitleURL: externalSubtitleURL,
            preferredAudioTrackOrdinal: preferredAudioTrackOrdinal,
            preferredSubtitleTrackOrdinal: preferredSubtitleTrackOrdinal,
            prefersSubtitlesDisabled: runtimeState.subtitleSelectionKnown
                ? runtimeState.subtitlesDisabled
                : prefersSubtitlesDisabled,
            initialOrientationMode: runtimeState.orientationMode,
            initialPlaybackRate: runtimeState.playbackRate,
            timelineOffsetSeconds: timelineOffsetSeconds,
            totalDurationSeconds: totalDurationSeconds,
            isPrivateNetworkRoute: isPrivateNetworkRoute,
            forcesSoftwareDecoding: forcesSoftwareDecoding,
            playbackTracker: playbackTracker,
            compatibilityResource: compatibilityResource,
            compatibilityFallbackResource: compatibilityFallbackResource,
            externalHandoffResource: externalHandoffResource,
            compatibilityResourceLoader: compatibilityResourceLoader,
            compatibilityFallbackResourceLoader: compatibilityFallbackResourceLoader,
            compatibilityFallbackRequestLoader: compatibilityFallbackRequestLoader,
            externalHandoffResourceLoader: externalHandoffResourceLoader,
            sourceAudioTracks: sourceAudioTracks,
            sourceSubtitleTracks: sourceSubtitleTracks,
            selectedSourceAudioTrackID: selectedSourceAudioTrackID,
            selectedSourceSubtitleTrackID: selectedSourceSubtitleTrackID,
            sourceTrackRequestLoader: sourceTrackRequestLoader,
            serverSeekRequestLoader: serverSeekRequestLoader,
            qualityOptions: qualityOptions,
            selectedQualityID: selectedQualityID,
            qualityRequestLoader: qualityRequestLoader
        )
    }
}

enum MediaPlaybackTrackingEvent {
    case started(positionSeconds: Double)
    case progressed(positionSeconds: Double, isPaused: Bool)
    case stopped(positionSeconds: Double, failed: Bool)
}

final class MediaPlaybackTracker {
    private let lock = NSLock()
    private let eventHandler: (MediaPlaybackTrackingEvent) -> Void
    private var didStart = false
    private var didStop = false
    private var lastPositionSeconds = 0.0
    private var lastReportedPositionSeconds = -Double.infinity
    private var lastPausedState: Bool?

    init(eventHandler: @escaping (MediaPlaybackTrackingEvent) -> Void) {
        self.eventHandler = eventHandler
    }

    func started(positionSeconds: Double) {
        let position = max(positionSeconds, 0)
        lock.lock()
        guard !didStart, !didStop else {
            lock.unlock()
            return
        }
        didStart = true
        lastPositionSeconds = position
        lastReportedPositionSeconds = position
        lock.unlock()
        eventHandler(.started(positionSeconds: position))
    }

    func progressed(positionSeconds: Double, isPaused: Bool, force: Bool = false) {
        let position = max(positionSeconds, 0)
        lock.lock()
        guard !didStop else {
            lock.unlock()
            return
        }
        lastPositionSeconds = position
        let shouldReport = didStart && (
            force
                || abs(position - lastReportedPositionSeconds) >= 10
                || lastPausedState != isPaused
        )
        if shouldReport {
            lastReportedPositionSeconds = position
            lastPausedState = isPaused
        }
        lock.unlock()
        if shouldReport {
            eventHandler(.progressed(positionSeconds: position, isPaused: isPaused))
        }
    }

    func stopped(failed: Bool = false) {
        lock.lock()
        guard didStart, !didStop else {
            lock.unlock()
            return
        }
        didStop = true
        let position = lastPositionSeconds
        lock.unlock()
        eventHandler(.stopped(positionSeconds: position, failed: failed))
    }
}

enum MediaPlaybackSource: String {
    case directURL = "direct"
    case dsmFile = "dsmFile"
    case jellyfin
}

private final class MediaProbeTrustDelegate: NSObject, URLSessionDelegate {
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
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

enum MediaPlaybackProbe {
    static func run(_ playback: MediaPlaybackRequest) async {
        guard
            let scheme = playback.url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return
        }
        let diagnostics = DiagnosticLogStore.shared
        diagnostics.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.probe_started",
            details: baseDetails(for: playback)
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.waitsForConnectivity = true
        let delegate = MediaProbeTrustDelegate(
            trustedHost: playback.url.host,
            allowsSelfSignedCertificates: playback.allowsSelfSignedCertificates
        )
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        var request = URLRequest(url: playback.url)
        request.timeoutInterval = 15
        if playback.fileExtensionHint != "m3u8" {
            request.setValue("bytes=0-1", forHTTPHeaderField: "Range")
        }
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        do {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                diagnostics.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.probe_failed",
                    details: baseDetails(for: playback).merging(["error": "nonHTTPResponse"]) { current, _ in current }
                )
                return
            }

            let mimeType = httpResponse.mimeType?.lowercased() ?? "-"
            let looksLikeAPIError = mimeType.contains("json") || mimeType.contains("html")
            let accepted = (200...299).contains(httpResponse.statusCode) && !looksLikeAPIError
            diagnostics.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.probe_succeeded"
                    : "diagnostics.media.probe_invalid_response",
                details: baseDetails(for: playback).merging([
                    "status": "\(httpResponse.statusCode)",
                    "mime": mimeType,
                    "contentLength": httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "-",
                    "acceptRanges": httpResponse.value(forHTTPHeaderField: "Accept-Ranges") ?? "-",
                    "contentRange": httpResponse.value(forHTTPHeaderField: "Content-Range") ?? "-",
                    "contentDisposition": normalizedDisposition(
                        httpResponse.value(forHTTPHeaderField: "Content-Disposition")
                    )
                ]) { current, _ in current }
            )
            if accepted,
               playback.fileExtensionHint == "m3u8",
               let playlistData = try? await prefixData(from: bytes, limit: 256 * 1024),
               let playlist = String(data: playlistData, encoding: .utf8),
               let childURL = firstPlaylistURL(in: playlist, relativeTo: playback.url) {
                await probePlaylistChild(
                    childURL,
                    playback: playback,
                    session: session,
                    diagnostics: diagnostics
                )
            }
        } catch is CancellationError {
            return
        } catch {
            let nsError = error as NSError
            diagnostics.record(
                .error,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.probe_failed",
                details: baseDetails(for: playback).merging([
                    "errorDomain": nsError.domain,
                    "errorCode": "\(nsError.code)"
                ]) { current, _ in current }
            )
        }
    }

    static func baseDetails(for playback: MediaPlaybackRequest) -> [String: String] {
        MediaPlaybackCapabilities.current.diagnosticDetails.merging([
            "target": DiagnosticLogStore.redactedURL(playback.networkOriginURL),
            "source": playback.source.rawValue,
            "extension": playback.fileExtensionHint.isEmpty ? "-" : playback.fileExtensionHint,
            "selfSigned": playback.allowsSelfSignedCertificates ? "on" : "off",
            "transport": playback.url.host == "127.0.0.1"
                ? "localRangeProxy"
                : "sourceURL",
            "routePrivate": playback.isPrivateNetworkRoute.map { $0 ? "yes" : "no" } ?? "unknown"
        ]) { _, new in new }
    }

    private static func firstPlaylistURL(in playlist: String, relativeTo baseURL: URL) -> URL? {
        for rawLine in playlist.split(whereSeparator: { $0.isNewline }) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            return URL(string: line, relativeTo: baseURL)?.absoluteURL
        }
        return nil
    }

    private static func probePlaylistChild(
        _ url: URL,
        playback: MediaPlaybackRequest,
        session: URLSession,
        diagnostics: DiagnosticLogStore
    ) async {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        do {
            let (_, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { return }
            let mimeType = response.mimeType?.lowercased() ?? "-"
            let accepted = (200...299).contains(response.statusCode)
                && !mimeType.contains("json")
                && !mimeType.contains("html")
            diagnostics.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.probe_succeeded"
                    : "diagnostics.media.probe_invalid_response",
                details: baseDetails(for: playback).merging([
                    "stage": "hlsChild",
                    "target": DiagnosticLogStore.redactedURL(url),
                    "status": "\(response.statusCode)",
                    "mime": mimeType,
                    "bytesReceived": "headersOnly"
                ]) { _, new in new }
            )
        } catch {
            let nsError = error as NSError
            diagnostics.record(
                .error,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.probe_failed",
                details: baseDetails(for: playback).merging([
                    "stage": "hlsChild",
                    "target": DiagnosticLogStore.redactedURL(url),
                    "errorDomain": nsError.domain,
                    "errorCode": "\(nsError.code)"
                ]) { _, new in new }
            )
        }
    }

    private static func normalizedDisposition(_ value: String?) -> String {
        guard let value else { return "-" }
        let lowercased = value.lowercased()
        if lowercased.contains("attachment") { return "attachment" }
        if lowercased.contains("inline") { return "inline" }
        return "present"
    }

    private static func prefixData(
        from bytes: URLSession.AsyncBytes,
        limit: Int
    ) async throws -> Data {
        var data = Data()
        data.reserveCapacity(min(limit, 32 * 1024))
        for try await byte in bytes {
            data.append(byte)
            if data.count >= limit { break }
        }
        return data
    }
}

private enum MediaPlaybackEngine: Equatable {
    case system
    case compatibility
}

private enum MediaPlaybackPolicy {
    private static let systemPreferredExtensions: Set<String> = [
        "m3u8", "mp4", "m4v", "mov", "3gp", "3g2",
        "mp3", "m4a", "aac", "wav", "caf"
    ]

    static var hasCompatibilityEngine: Bool {
#if canImport(MobileVLCKit)
        true
#else
        false
#endif
    }

    static func allowsCompatibilityPlayer(for request: MediaPlaybackRequest) -> Bool {
        guard hasCompatibilityEngine else { return false }
        if request.source == .jellyfin || request.source == .dsmFile { return true }
        return request.fileExtensionHint != "m3u8"
            || request.compatibilityResource != nil
            || request.compatibilityResourceLoader != nil
    }

    static func preferredEngine(for request: MediaPlaybackRequest) -> MediaPlaybackEngine {
        guard allowsCompatibilityPlayer(for: request) else { return .system }
        // Jellyfin HLS is authenticated through the local playlist proxy.
        // MobileVLCKit is the more tolerant decoder for the resulting
        // MPEG-TS/fMP4 output on iPadOS; AVPlayer can report a playing/ready
        // state while rendering a black frame for the same stream. Keep VLC
        // as the visible playback engine for every Jellyfin HLS route; PiP
        // explicitly prepares a system-compatible HLS replacement in place.
        if request.source == .jellyfin,
           request.fileExtensionHint == "m3u8" {
            return .compatibility
        }
        if request.fileExtensionHint == "m3u8",
           allowsSystemPlayer(for: request) {
            return .system
        }
        if request.source == .jellyfin || request.source == .dsmFile {
            return .compatibility
        }
        if request.allowsSelfSignedCertificates {
            return .compatibility
        }
        let fileExtension = request.fileExtensionHint
        guard !fileExtension.isEmpty else { return .system }
        return systemPreferredExtensions.contains(fileExtension) ? .system : .compatibility
    }

    static func allowsSystemPlayer(for request: MediaPlaybackRequest) -> Bool {
        guard !request.allowsSelfSignedCertificates else {
            return false
        }
        let fileExtension = request.fileExtensionHint
        guard fileExtension.isEmpty || systemPreferredExtensions.contains(fileExtension) else {
            return false
        }
        return request.source == .directURL
            || request.source == .dsmFile
            || request.source == .jellyfin
    }

    static func requiresCompatibilityEngine(for request: MediaPlaybackRequest) -> Bool {
        if request.allowsSelfSignedCertificates {
            return true
        }
        if request.source == .jellyfin {
            return hasCompatibilityEngine || request.fileExtensionHint != "m3u8"
        }
        if request.source == .dsmFile, hasCompatibilityEngine { return true }
        let fileExtension = request.fileExtensionHint
        return !fileExtension.isEmpty && !systemPreferredExtensions.contains(fileExtension)
    }

    static func shouldAutomaticallyFallback(for request: MediaPlaybackRequest) -> Bool {
        guard allowsCompatibilityPlayer(for: request) else { return false }
        // Jellyfin HLS is the preferred remote transport and normally uses
        // AVPlayer for PiP/background playback.  Keep MobileVLCKit as a
        // bounded in-place fallback as well: AVPlayer can reject a valid
        // Jellyfin playlist because of a transient child-segment response or
        // a server-specific HLS tag.  Without this branch the player stays
        // black until the cover is dismissed, even though VLC can open the
        // same authenticated playlist.
        if request.source == .jellyfin, request.fileExtensionHint == "m3u8" {
            return true
        }
        return request.fileExtensionHint != "m3u8"
            || request.compatibilityResource != nil
            || request.compatibilityResourceLoader != nil
    }
}

private struct DirectMediaPlayerSetupView: View {
    @State private var address: String
    @State private var playbackRequest: MediaPlaybackRequest?
    @State private var showValidationError = false

    init(suggestedURL: URL?) {
        _address = State(initialValue: suggestedURL?.absoluteString ?? "")
    }

    var body: some View {
        Form {
            Section {
                Text("player.direct.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                TextField("player.url.placeholder", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                Button {
                    guard let url = normalizedURL else {
                        showValidationError = true
                        return
                    }
                    playbackRequest = MediaPlaybackRequest(url: url, title: url.lastPathComponent)
                } label: {
                    Label("player.play_in_app", systemImage: "play.fill")
                }
            } footer: {
                Text("player.direct.footer")
            }
        }
        .navigationTitle("player.open_stream")
        .navigationBarTitleDisplayMode(.inline)
        .alert("player.url.invalid", isPresented: $showValidationError) {
            Button("action.ok", role: .cancel) {}
        }
        .fullScreenCover(item: $playbackRequest, onDismiss: {
            PlayerOrientationController.setPlayerActive(false)
        }) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
    }

    private var normalizedURL: URL? {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            url.host?.isEmpty == false,
            DirectMediaURLPolicy.canAttemptPlayback(url)
        else {
            return nil
        }
        return url
    }
}

private final class MediaPlayerSession: ObservableObject {
    let player: AVPlayer
    @Published private(set) var errorMessage: String?
    @Published private(set) var isReady = false
    @Published private(set) var fallbackReason: String?
    private var request: MediaPlaybackRequest
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var periodicTimeObserver: Any?
    private var lastTimeControlStatus: AVPlayer.TimeControlStatus?
    private var didApplyInitialPosition = false
    private var pendingInitialPosition: Double?
    private var stallWorkItem: DispatchWorkItem?
    private var startupWorkItem: DispatchWorkItem?

    init(request: MediaPlaybackRequest) {
        self.request = request
        pendingInitialPosition = request.initialPosition
        player = AVPlayer(playerItem: Self.makePlayerItem(for: request))
        Self.configure(player, for: request)
    }

    private static func makePlayerItem(for request: MediaPlaybackRequest) -> AVPlayerItem {
        let options: [String: Any]? = request.mimeTypeHint.map {
            ["AVURLAssetOutOfBandMIMETypeKey": $0 as Any]
        }
        let asset = AVURLAsset(url: request.url, options: options)
        let item = AVPlayerItem(asset: asset)
        // AVPlayer's default anti-stall policy deliberately waits for a larger
        // buffer before starting HLS. That is safe for VOD but makes a newly
        // negotiated Jellyfin stream feel frozen. A small explicit forward
        // buffer keeps startup and seeks responsive while VLC remains the
        // engine for raw NAS files.
        item.preferredForwardBufferDuration = request.fileExtensionHint == "m3u8"
            ? 1.5
            : 0.5
        return item
    }

    private static func configure(_ player: AVPlayer, for request: MediaPlaybackRequest) {
        player.automaticallyWaitsToMinimizeStalling = request.fileExtensionHint != "m3u8"
    }

    func replaceRequest(
        _ request: MediaPlaybackRequest,
        normalizedPosition: Double?
    ) {
        pause()
        removeObservers()
        self.request = request
        pendingInitialPosition = normalizedPosition ?? request.initialPosition
        didApplyInitialPosition = false
        lastTimeControlStatus = nil
        errorMessage = nil
        fallbackReason = nil
        isReady = false
        startupWorkItem?.cancel()
        startupWorkItem = nil
        Self.configure(player, for: request)
        player.replaceCurrentItem(with: Self.makePlayerItem(for: request))
    }

    private func activateIfNeeded() {
        guard statusObservation == nil, let item = player.currentItem else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_started",
            details: MediaPlaybackProbe.baseDetails(for: request).merging([
                "engine": "AVPlayer",
                "mimeHint": request.mimeTypeHint ?? "-"
            ]) { current, _ in current }
        )
        statusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    if !self.didApplyInitialPosition,
                       let progress = self.pendingInitialPosition,
                       item.duration.seconds.isFinite,
                       item.duration.seconds > 0 {
                        self.didApplyInitialPosition = true
                        self.pendingInitialPosition = nil
                        self.player.seek(
                            to: CMTime(seconds: item.duration.seconds * progress, preferredTimescale: 600),
                            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
                            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
                        )
                    }
                    self.isReady = true
                    self.errorMessage = nil
                    DiagnosticLogStore.shared.record(
                        .info,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.player_ready",
                        details: ["engine": "AVPlayer"]
                    )
                case .failed:
                    self.isReady = false
                    let error = item.error as NSError?
                    self.errorMessage = item.error?.localizedDescription
                        ?? NSLocalizedString("player.load_failed", comment: "")
                    self.fallbackReason = "playerError"
                    DiagnosticLogStore.shared.record(
                        .error,
                        categoryKey: "diagnostics.category.media",
                        messageKey: "diagnostics.media.player_failed",
                        details: [
                            "engine": "AVPlayer",
                            "errorDomain": error?.domain ?? "-",
                            "errorCode": error.map { "\($0.code)" } ?? "-"
                        ]
                    )
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            DispatchQueue.main.async {
                guard let self, player.timeControlStatus != self.lastTimeControlStatus else { return }
                self.lastTimeControlStatus = player.timeControlStatus
                let state: String
                switch player.timeControlStatus {
                case .paused: state = "paused"
                case .playing: state = "playing"
                case .waitingToPlayAtSpecifiedRate: state = "waiting"
                @unknown default: state = "unknown"
                }
                DiagnosticLogStore.shared.record(
                    state == "waiting" ? .warning : .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.player_state",
                    details: [
                        "engine": "AVPlayer",
                        "state": state,
                        "waitingReason": player.reasonForWaitingToPlay?.rawValue ?? "-"
                    ]
                )
                let currentSeconds = player.currentTime().seconds
                if currentSeconds.isFinite {
                    if player.timeControlStatus == .playing {
                        self.request.playbackTracker?.started(positionSeconds: currentSeconds)
                    }
                    self.request.playbackTracker?.progressed(
                        positionSeconds: currentSeconds,
                        isPaused: player.timeControlStatus != .playing,
                        force: true
                    )
                }
                self.updateStallDetection(for: player.timeControlStatus)
            }
        }
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self, time.seconds.isFinite else { return }
            if self.player.timeControlStatus == .playing {
                self.request.playbackTracker?.started(positionSeconds: time.seconds)
            }
            self.request.playbackTracker?.progressed(
                positionSeconds: time.seconds,
                isPaused: self.player.timeControlStatus != .playing
            )
        }
    }

    func play(from normalizedPosition: Double? = nil) {
        if let normalizedPosition {
            pendingInitialPosition = min(max(normalizedPosition, 0), 1)
            didApplyInitialPosition = false
        }
        activateIfNeeded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        applyPendingPositionIfReady()
        player.play()
        scheduleStartupFrameWatchdog()
    }

    func pause() {
        stallWorkItem?.cancel()
        startupWorkItem?.cancel()
        player.pause()
    }

    private func scheduleStartupFrameWatchdog() {
        startupWorkItem?.cancel()
        guard request.fileExtensionHint == "m3u8" else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.fallbackReason == nil,
                  let item = self.player.currentItem,
                  self.player.timeControlStatus != .paused,
                  item.presentationSize == .zero else {
                return
            }
            self.fallbackReason = "startupNoVideoFrame"
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "startupNoVideoFrame",
                    "watchdogSeconds": "4"
                ]
            )
        }
        startupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    var normalizedPosition: Double? {
        guard let item = player.currentItem else { return nil }
        let duration = item.duration.seconds
        let current = player.currentTime().seconds
        guard duration.isFinite, duration > 0, current.isFinite else { return nil }
        return min(max(current / duration, 0), 1)
    }

    private func applyPendingPositionIfReady() {
        guard
            !didApplyInitialPosition,
            let progress = pendingInitialPosition,
            let item = player.currentItem,
            item.status == .readyToPlay,
            item.duration.seconds.isFinite,
            item.duration.seconds > 0
        else {
            return
        }
        didApplyInitialPosition = true
        pendingInitialPosition = nil
        player.seek(
            to: CMTime(seconds: item.duration.seconds * progress, preferredTimescale: 600),
            toleranceBefore: CMTime(seconds: 0.5, preferredTimescale: 600),
            toleranceAfter: CMTime(seconds: 0.5, preferredTimescale: 600)
        )
    }

    private func updateStallDetection(for status: AVPlayer.TimeControlStatus) {
        stallWorkItem?.cancel()
        stallWorkItem = nil
        guard status == .waitingToPlayAtSpecifiedRate, fallbackReason == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate,
                  self.fallbackReason == nil else {
                return
            }
            self.fallbackReason = "playbackStall"
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "playbackStall",
                    "waitingReason": self.player.reasonForWaitingToPlay?.rawValue ?? "-"
                ]
            )
        }
        stallWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: workItem)
    }

    private func removeObservers() {
        stallWorkItem?.cancel()
        stallWorkItem = nil
        startupWorkItem?.cancel()
        startupWorkItem = nil
        statusObservation?.invalidate()
        statusObservation = nil
        timeControlObservation?.invalidate()
        timeControlObservation = nil
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
            self.periodicTimeObserver = nil
        }
    }

    deinit {
        removeObservers()
        player.pause()
    }
}

struct BuiltInMediaPlayerView: View {
    let request: MediaPlaybackRequest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: MediaPlayerSession
    @State private var activeEngine: MediaPlaybackEngine
    @State private var didAutomaticallyFallback = false
    @State private var showExternalPicker = false
    @State private var sharePayload: ServiceSharePayload?
    @State private var pendingExternalTarget: ExternalOpenTarget?
    @State private var pendingShareHandoff = false
    @State private var showCredentialHandoffWarning = false
    @State private var resolvedCompatibilityRequest: MediaPlaybackRequest?
    @State private var resolvedExternalHandoffRequest: MediaPlaybackRequest?
    @State private var compatibilityLoadTask: Task<MediaPlaybackResource?, Never>?
    @State private var compatibilityFallbackLoadTask: Task<MediaPlaybackResource?, Never>?
    @State private var compatibilityFallbackRequestLoadTask: Task<MediaPlaybackRequest?, Never>?
    @State private var externalHandoffLoadTask: Task<MediaPlaybackResource?, Never>?
    @State private var sourceTrackLoadTask: Task<Void, Never>?
    @State private var serverSeekLoadTask: Task<Void, Never>?
    @State private var qualityLoadTask: Task<Void, Never>?
    @State private var isPreparingAlternative = false
    @State private var didUseCompatibilityFallback = false
    @State private var compatibilityFallbackAttemptCount = 0
    @State private var compatibilityResumePosition: Double?
    @State private var compatibilityDidFail = false
    @State private var systemQualityPanelPresented = false
    @State private var shouldStartPictureInPicture = false

    init(request: MediaPlaybackRequest) {
        self.request = request
        _session = StateObject(wrappedValue: MediaPlayerSession(request: request))
        _activeEngine = State(initialValue: MediaPlaybackPolicy.preferredEngine(for: request))
        if request.compatibilityResourceLoader == nil {
            _resolvedCompatibilityRequest = State(
                initialValue: request.compatibilityPlaybackRequest
            )
        }
    }

    var body: some View {
        if request.isAudioOnly {
            DedicatedAudioPlayerView(request: request)
        } else {
            videoPlayerBody
        }
    }

    private var videoPlayerBody: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch activeEngine {
            case .system:
                ZStack {
                    SystemPlayerController(
                        player: session.player,
                        startPictureInPicture: shouldStartPictureInPicture,
                        onSeekCommitted: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        },
                        onPictureInPictureEvent: { phase, error in
                            var details = ["phase": phase]
                            if let error {
                                details["error"] = error.localizedDescription
                            }
                            DiagnosticLogStore.shared.record(
                                phase == "failed" ? .warning : .info,
                                categoryKey: "diagnostics.category.media",
                                messageKey: "diagnostics.media.player_switch",
                                details: details.merging(["target": "pictureInPicture"]) { _, new in new }
                            )
                            if phase == "didStart" {
                                shouldStartPictureInPicture = false
                            }
                        }
                    )
                    .ignoresSafeArea(edges: .bottom)

                    if request.qualityOptions.count > 1 {
                        VStack {
                            HStack {
                                Spacer()
                                Button {
                                    systemQualityPanelPresented = true
                                } label: {
                                    Image(systemName: "4k.tv")
                                        .font(.title3.weight(.semibold))
                                        .frame(width: 44, height: 44)
                                        .background(.black.opacity(0.48), in: Circle())
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .accessibilityLabel(Text("player.quality"))
                            }
                            Spacer()
                        }
                        .padding(.top, 22)
                        .padding(.trailing, 18)
                    }
                }

                if let errorMessage = session.errorMessage {
                    playbackErrorView(
                        MediaPlaybackPolicy.requiresCompatibilityEngine(for: request)
                            ? NSLocalizedString("player.compatibility_unavailable", comment: "")
                            : errorMessage
                    )
                }
            case .compatibility:
#if canImport(MobileVLCKit)
                if let compatibilityRequest = activeCompatibilityRequest {
                    VLCBuiltInPlayerView(
                        request: compatibilityRequest,
                        close: { dismiss() },
                        useSystemPlayer: canPrepareSystemPlayback(from: compatibilityRequest)
                            ? prepareSystemPlayback
                            : nil,
                        compatibilityFailed: handleCompatibilityFailure,
                        sourceTrackChange: compatibilityRequest.sourceTrackRequestLoader == nil
                            ? nil
                            : handleSourceTrackChange,
                        serverSeek: compatibilityRequest.serverSeekRequestLoader == nil
                            ? nil
                            : handleServerSeek,
                        qualityChange: compatibilityRequest.qualityRequestLoader == nil
                            ? nil
                            : handleQualityChange,
                        openExternal: {
                            if request.allowsExternalHandoff {
                                showExternalPicker = true
                            }
                        }
                    )
                    .id(compatibilityRequest.id)
                } else {
                    ProgressView()
                        .tint(.white)
                }
#else
                playbackErrorView(NSLocalizedString("player.compatibility_unavailable", comment: ""))
#endif
            }

            if isPreparingAlternative {
                ProgressView()
                    .tint(.white)
                    .padding(14)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
            }

            if showExternalPicker {
                externalPlayerPicker
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(2)
            }

            if showCredentialHandoffWarning {
                credentialHandoffWarning
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(3)
            }

            if systemQualityPanelPresented {
                systemQualityPanel
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(4)
            }
        }
        .navigationTitle(request.title.isEmpty ? "player.title" : request.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar(activeEngine == .compatibility ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
#if canImport(MobileVLCKit)
                if MediaPlaybackPolicy.allowsSystemPlayer(for: request)
                    && MediaPlaybackPolicy.allowsCompatibilityPlayer(for: request) {
                    Menu {
                        Button {
                            selectEngine(.system)
                        } label: {
                            Label("player.engine.system", systemImage: activeEngine == .system ? "checkmark" : "play.rectangle")
                        }
                        Button {
                            selectEngine(.compatibility)
                        } label: {
                            Label("player.engine.compatibility", systemImage: activeEngine == .compatibility ? "checkmark" : "rectangle.stack")
                        }
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .accessibilityLabel(Text("player.engine.choose"))
                }
#endif
                if request.allowsExternalHandoff {
                    Button {
                        showExternalPicker = true
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .accessibilityLabel(Text("devices.files.open_external"))
                }
                if activeEngine == .system {
                    Button {
                        togglePlayerOrientation()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .accessibilityLabel(Text("player.fullscreen"))
                }
            }
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .onAppear {
            PlayerOrientationController.setPlayerActive(
                true,
                initialMode: request.initialOrientationMode
            )
            if activeEngine == .system {
                session.play()
            } else if activeCompatibilityRequest == nil {
                Task { _ = await resolveCompatibilityRequest() }
            }
        }
        .task {
            // Jellyfin and DSM resources are validated while their final playback route is
            // prepared. A second probe would compete with the player's first-frame request.
            if request.source == .directURL, request.url.host != "127.0.0.1" {
                await MediaPlaybackProbe.run(request)
            }
        }
        .onDisappear {
            compatibilityLoadTask?.cancel()
            compatibilityFallbackLoadTask?.cancel()
            compatibilityFallbackRequestLoadTask?.cancel()
            externalHandoffLoadTask?.cancel()
            sourceTrackLoadTask?.cancel()
            serverSeekLoadTask?.cancel()
            qualityLoadTask?.cancel()
            session.pause()
            // A Jellyfin direct-play request can be replaced by a negotiated
            // HLS request before the user enters system AVPlayer/PiP.  The
            // replacement owns the live tracker; using the original direct
            // tracker here reports the stale zero position on close, so the
            // next "Continue Watching" launch starts from the beginning.
            let activeTracker = activeCompatibilityRequest?.playbackTracker
                ?? request.playbackTracker
            activeTracker?.stopped(
                failed: activeEngine == .system
                    ? session.errorMessage != nil
                    : compatibilityDidFail
            )
            PlayerOrientationController.setPlayerActive(false)
        }
        .onChange(of: session.errorMessage) { errorMessage in
            guard
                errorMessage != nil,
                activeEngine == .system,
                MediaPlaybackPolicy.shouldAutomaticallyFallback(for: request),
                !didAutomaticallyFallback
            else {
                return
            }
            didAutomaticallyFallback = true
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "playerError"
                ]
            )
            selectEngine(.compatibility)
        }
        .onChange(of: session.fallbackReason) { reason in
            guard
                let reason,
                activeEngine == .system,
                MediaPlaybackPolicy.shouldAutomaticallyFallback(for: request),
                !didAutomaticallyFallback
            else {
                return
            }
            didAutomaticallyFallback = true
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": reason
                ]
            )
            selectEngine(.compatibility)
        }
    }

    @ViewBuilder
    private func playbackErrorView(_ errorMessage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
            Text("player.load_failed")
                .font(.headline)
            Text(errorMessage)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(4)
            if request.allowsExternalHandoff {
                Button {
                    showExternalPicker = true
                } label: {
                    Label("devices.files.open_external", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            } else {
                switch request.source {
                case .jellyfin:
                    Text("jellyfin.player.retry_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case .dsmFile:
                    Text("dsm.player.retry_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                case .directURL:
                    EmptyView()
                }
                Button("action.done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .foregroundStyle(.white)
        .padding(22)
    }

    private var externalPlayerPicker: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { dismissExternalPicker() }

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("service.external.title")
                        .font(.headline)
                    Spacer()
                    Button(action: dismissExternalPicker) {
                        Image(systemName: "xmark")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("action.cancel"))
                }
                .padding(.leading, 16)
                .padding(.trailing, 8)
                .padding(.vertical, 8)

                Divider()

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(ExternalOpenTarget.installedPlayers) { target in
                            externalPickerRow(
                                title: target.displayName,
                                systemImage: "play.rectangle"
                            ) {
                                dismissExternalPicker()
                                requestExternalOpen(target)
                            }
                        }
                        externalPickerRow(
                            title: NSLocalizedString("external.browser", comment: ""),
                            systemImage: "safari"
                        ) {
                            dismissExternalPicker()
                            requestExternalOpen(.safari)
                        }
                        externalPickerRow(
                            title: NSLocalizedString("external.other_apps", comment: ""),
                            systemImage: "square.and.arrow.up"
                        ) {
                            dismissExternalPicker()
                            requestExternalShare()
                        }
                    }
                }
                .frame(maxHeight: 320)
            }
            .foregroundStyle(.primary)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(24)
        }
    }

    private var credentialHandoffWarning: some View {
        ZStack {
            Color.black.opacity(0.48).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.shield")
                        .font(.title3)
                    Text("external.credential_warning.title")
                        .font(.headline)
                }

                Text("external.credential_warning.message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button("action.cancel") {
                        cancelCredentialHandoff()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("external.credential_warning.continue") {
                        continueCredentialHandoff()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
            }
            .foregroundStyle(.primary)
            .padding(20)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .padding(24)
        }
    }

    @ViewBuilder
    private func externalPickerRow(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .frame(width: 24)
                Text(title)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, 52)
    }

    private func dismissExternalPicker() {
        withAnimation(.easeOut(duration: 0.16)) {
            showExternalPicker = false
        }
    }

    private func continueCredentialHandoff() {
        showCredentialHandoffWarning = false
        if let target = pendingExternalTarget {
            openExternal(target)
        } else if pendingShareHandoff {
            sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
        }
        pendingExternalTarget = nil
        pendingShareHandoff = false
    }

    private func cancelCredentialHandoff() {
        showCredentialHandoffWarning = false
        pendingExternalTarget = nil
        pendingShareHandoff = false
    }

    private func selectEngine(
        _ engine: MediaPlaybackEngine,
        resumePosition: Double? = nil
    ) {
        guard activeEngine != engine else { return }
        didAutomaticallyFallback = true
        if engine == .compatibility {
            compatibilityResumePosition = resumePosition
                ?? session.normalizedPosition
                ?? request.initialPosition
        }
        session.pause()
        if engine == .compatibility,
           request.compatibilityResourceLoader != nil,
           resolvedCompatibilityRequest == nil {
            Task {
                _ = await resolveCompatibilityRequest()
                activeEngine = .compatibility
            }
            return
        }
        if engine == .compatibility,
           let currentRequest = resolvedCompatibilityRequest {
            let resource = MediaPlaybackResource(
                url: currentRequest.url,
                fileExtensionOverride: currentRequest.fileExtensionOverride,
                subtitleURL: currentRequest.externalSubtitleURL
            )
            // Build from the active replacement, not the original request.
            // This preserves timelineOffsetSeconds for a transcode stream and
            // carries the selected source tracks/quality into VLC.
            resolvedCompatibilityRequest = currentRequest.playbackRequest(
                using: resource,
                initialPositionOverride: compatibilityResumePosition
            )
        }
        activeEngine = engine
        if engine == .system {
            session.replaceRequest(
                activeCompatibilityRequest ?? request,
                normalizedPosition: resumePosition
            )
            session.play(from: resumePosition)
        }
    }

    private func canPrepareSystemPlayback(from activeRequest: MediaPlaybackRequest) -> Bool {
        MediaPlaybackPolicy.allowsSystemPlayer(for: activeRequest)
            || (activeRequest.source == .jellyfin
                && activeRequest.qualityRequestLoader != nil
                && activeRequest.qualityOptions.contains { $0.id == "12000000" })
    }

    private func prepareSystemPlayback(
        runtimeState: MediaPlaybackRuntimeState,
        startsPictureInPicture: Bool
    ) {
        guard let activeRequest = activeCompatibilityRequest else { return }
        if MediaPlaybackPolicy.allowsSystemPlayer(for: activeRequest) {
            shouldStartPictureInPicture = startsPictureInPicture
            selectEngine(.system, resumePosition: runtimeState.normalizedPosition)
            return
        }
        guard
            activeRequest.source == .jellyfin,
            let loader = activeRequest.qualityRequestLoader,
            activeRequest.qualityOptions.contains(where: { $0.id == "12000000" })
        else {
            return
        }

        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        qualityLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_switch",
            details: [
                "from": "MobileVLCKit",
                "to": "AVPlayer",
                "reason": "pictureInPicture",
                "preparation": "serverHLS"
            ]
        )
        qualityLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader("12000000", runtimeState)
            guard !Task.isCancelled else { return }
            qualityLoadTask = nil
            isPreparingAlternative = false
            guard let replacement,
                  MediaPlaybackPolicy.allowsSystemPlayer(for: replacement) else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.quality_switch_failed",
                    details: ["target": "pictureInPicture"]
                )
                return
            }
            compatibilityDidFail = false
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.quality_switch_ready",
                details: [
                    "target": "pictureInPicture",
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
            activateSystemPlayback(
                with: replacement,
                runtimeState: runtimeState,
                startsPictureInPicture: startsPictureInPicture
            )
        }
    }

    private func activateSystemPlayback(
        with replacement: MediaPlaybackRequest,
        runtimeState: MediaPlaybackRuntimeState,
        startsPictureInPicture: Bool
    ) {
        shouldStartPictureInPicture = startsPictureInPicture
        compatibilityResumePosition = replacement.initialPosition
        resolvedCompatibilityRequest = replacement
        let resumePosition = replacement.timelineOffsetSeconds > 0
            ? nil
            : runtimeState.normalizedPosition ?? replacement.initialPosition
        activeEngine = .system
        session.replaceRequest(replacement, normalizedPosition: resumePosition)
        session.play(from: resumePosition)
    }

    private var systemRuntimeState: MediaPlaybackRuntimeState {
        let currentSeconds = session.player.currentTime().seconds
        return MediaPlaybackRuntimeState(
            normalizedPosition: session.normalizedPosition,
            positionSeconds: currentSeconds.isFinite ? currentSeconds : nil,
            playbackRate: session.player.rate,
            audioTrackOrdinal: nil,
            subtitleTrackOrdinal: nil,
            subtitlesDisabled: false,
            subtitleSelectionKnown: false,
            orientationMode: request.initialOrientationMode
        )
    }

    private var systemQualityPanel: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { systemQualityPanelPresented = false }

            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("player.quality")
                            .font(.headline)
                        Spacer()
                        Button {
                            systemQualityPanelPresented = false
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Divider()

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach((activeCompatibilityRequest ?? request).qualityOptions) { option in
                                Button {
                                    systemQualityPanelPresented = false
                                    handleQualityChange(
                                        qualityID: option.id,
                                        runtimeState: systemRuntimeState
                                    )
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: (activeCompatibilityRequest ?? request).selectedQualityID == option.id
                                              ? "checkmark.circle.fill"
                                              : "circle")
                                        Text(option.title)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(minHeight: 48)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(width: 320)
                .foregroundStyle(.primary)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding(.trailing, 18)
            }
        }
    }

    private func handleCompatibilityFailure(runtimeState: MediaPlaybackRuntimeState) {
        compatibilityDidFail = true
        guard
            compatibilityFallbackAttemptCount < 2,
            !isPreparingAlternative,
            let failingRequest = activeCompatibilityRequest,
            failingRequest.compatibilityFallbackResource != nil
                || failingRequest.compatibilityFallbackResourceLoader != nil
                || failingRequest.compatibilityFallbackRequestLoader != nil
        else {
            return
        }

        // The automatic path is intentionally bounded: one direct reconnect
        // may be followed by one server fallback. The replacement itself does
        // not create an unbounded retry loop.
        compatibilityFallbackAttemptCount += 1
        didUseCompatibilityFallback = true
        let resumePosition = runtimeState.normalizedPosition
            ?? failingRequest.initialPosition
            ?? compatibilityResumePosition
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_fallback",
            details: [
                "from": "MobileVLCKit",
                "to": "compatibilityReplacement",
                "reason": "originalPlaybackFailed",
                "position": runtimeState.positionSeconds.map { String(format: "%.1f", $0) } ?? "-",
                "attempt": "\(compatibilityFallbackAttemptCount)"
            ]
        )

        // A DSM/direct stream can fail because its HTTP connection was dropped
        // even though the media itself is healthy. Reopen that same resource
        // once at the live playhead. A Jellyfin original has already passed
        // the server probe, so reopening its large Range resource after a
        // decoder/seek failure would repeat the iPad failure; Jellyfin switches
        // to its prepared compatibility request on the first real failure.
        if compatibilityFallbackAttemptCount == 1,
           failingRequest.fileExtensionHint != "m3u8",
           failingRequest.source != .jellyfin {
            let resource = MediaPlaybackResource(
                url: failingRequest.url,
                fileExtensionOverride: failingRequest.fileExtensionOverride,
                subtitleURL: failingRequest.externalSubtitleURL
            )
            let replacement = failingRequest.playbackRequest(
                using: resource,
                initialPositionOverride: resumePosition,
                runtimeState: runtimeState,
                retainsFallback: true
            )
            compatibilityDidFail = false
            compatibilityResumePosition = replacement.initialPosition ?? resumePosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "MobileVLCKit",
                    "to": "MobileVLCKit",
                    "reason": "directResourceReconnect",
                    "position": resumePosition.map { String(format: "%.1f", $0) } ?? "-"
                ]
            )
            return
        }

        Task { @MainActor in
            let startedAt = Date()
            let replacement = await resolveCompatibilityFallbackRequest(
                from: failingRequest,
                resumePosition: resumePosition,
                runtimeState: runtimeState
            )
            guard !Task.isCancelled else { return }
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.player_failed",
                    details: [
                        "engine": "MobileVLCKit",
                        "reason": "compatibilityReplacementUnavailable"
                    ]
                )
                return
            }
            compatibilityDidFail = false
            let preparedReplacement = replacement.applyingRuntimePreferences(runtimeState)
            compatibilityResumePosition = preparedReplacement.initialPosition ?? resumePosition
            resolvedCompatibilityRequest = preparedReplacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "MobileVLCKit",
                    "to": "MobileVLCKit",
                    "reason": "compatibilityReplacementReady",
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func handleSourceTrackChange(
        audioTrackID: Int?,
        subtitleTrackID: Int?,
        runtimeState: MediaPlaybackRuntimeState
    ) {
        guard let activeRequest = activeCompatibilityRequest,
              let loader = activeRequest.sourceTrackRequestLoader,
              activeRequest.selectedSourceAudioTrackID != audioTrackID
                || activeRequest.selectedSourceSubtitleTrackID != subtitleTrackID else {
            return
        }
        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.source_track_switch_requested",
            details: [
                "audioStreamIndex": audioTrackID.map(String.init) ?? "default",
                "subtitleStreamIndex": subtitleTrackID.map(String.init) ?? "none",
                "position": runtimeState.normalizedPosition.map { String(format: "%.4f", $0) } ?? "-"
            ]
        )
        sourceTrackLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader(audioTrackID, subtitleTrackID, runtimeState)
            guard !Task.isCancelled else { return }
            isPreparingAlternative = false
            sourceTrackLoadTask = nil
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.source_track_switch_failed"
                )
                return
            }
            compatibilityDidFail = false
            didUseCompatibilityFallback = false
            compatibilityFallbackAttemptCount = 0
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.source_track_switch_ready",
                details: [
                    "audioStreamIndex": audioTrackID.map(String.init) ?? "default",
                    "subtitleStreamIndex": subtitleTrackID.map(String.init) ?? "none",
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func handleServerSeek(
        targetSeconds: Double,
        runtimeState: MediaPlaybackRuntimeState
    ) {
        guard let activeRequest = activeCompatibilityRequest,
              let loader = activeRequest.serverSeekRequestLoader,
              targetSeconds.isFinite else {
            return
        }
        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.server_seek_requested",
            details: [
                "fromSeconds": runtimeState.positionSeconds.map { String(format: "%.1f", $0) } ?? "-",
                "targetSeconds": String(format: "%.1f", targetSeconds)
            ]
        )
        serverSeekLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader(targetSeconds, runtimeState)
            guard !Task.isCancelled else { return }
            isPreparingAlternative = false
            serverSeekLoadTask = nil
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.server_seek_failed"
                )
                return
            }
            compatibilityDidFail = false
            didUseCompatibilityFallback = false
            compatibilityFallbackAttemptCount = 0
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.server_seek_ready",
                details: [
                    "targetSeconds": String(format: "%.1f", targetSeconds),
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func handleQualityChange(
        qualityID: String,
        runtimeState: MediaPlaybackRuntimeState
    ) {
        guard let activeRequest = activeCompatibilityRequest,
              let loader = activeRequest.qualityRequestLoader,
              activeRequest.selectedQualityID != qualityID else {
            return
        }
        sourceTrackLoadTask?.cancel()
        serverSeekLoadTask?.cancel()
        qualityLoadTask?.cancel()
        isPreparingAlternative = true
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.quality_switch_requested",
            details: [
                "from": activeRequest.selectedQualityID ?? "auto",
                "target": qualityID,
                "positionSeconds": runtimeState.positionSeconds.map {
                    String(format: "%.1f", $0)
                } ?? "-"
            ]
        )
        qualityLoadTask = Task { @MainActor in
            let startedAt = Date()
            let replacement = await loader(qualityID, runtimeState)
            guard !Task.isCancelled else { return }
            isPreparingAlternative = false
            qualityLoadTask = nil
            guard let replacement else {
                DiagnosticLogStore.shared.record(
                    .error,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.quality_switch_failed",
                    details: ["target": qualityID]
                )
                return
            }
            compatibilityDidFail = false
            didUseCompatibilityFallback = false
            compatibilityFallbackAttemptCount = 0
            compatibilityResumePosition = replacement.initialPosition
            resolvedCompatibilityRequest = replacement
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.quality_switch_ready",
                details: [
                    "target": qualityID,
                    "prepareMs": String(Int(max(Date().timeIntervalSince(startedAt), 0) * 1_000)),
                    "extension": replacement.fileExtensionHint
                ]
            )
        }
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        session.pause()
        guard let targetURL = target.url(
            endpoint: handoffRequest.externalHandoffURL,
            filename: handoffRequest.externalFilename,
            subtitleURL: handoffRequest.externalHandoffSubtitleURL
        ) else {
            sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
            return
        }
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            DiagnosticLogStore.shared.record(
                accepted ? .info : .error,
                categoryKey: "diagnostics.category.media",
                messageKey: accepted
                    ? "diagnostics.media.external_handoff_accepted"
                    : "diagnostics.media.external_handoff_failed",
                details: [
                    "targetApp": target.diagnosticName,
                    "extension": handoffRequest.externalHandoffFileExtensionHint.isEmpty
                        ? "-"
                        : handoffRequest.externalHandoffFileExtensionHint,
                    "mode": externalHandoffMode(for: handoffRequest)
                ]
            )
            guard !accepted else { return }
            DispatchQueue.main.async {
                sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
            }
        }
    }

    private func requestExternalOpen(_ target: ExternalOpenTarget) {
        Task {
            _ = await resolveExternalHandoffRequest()
            guard handoffRequest.containsSensitiveCredential else {
                openExternal(target)
                return
            }
            pendingExternalTarget = target
            showCredentialHandoffWarning = true
        }
    }

    private func externalHandoffMode(for request: MediaPlaybackRequest) -> String {
        switch request.externalHandoffFileExtensionHint {
        case "m3u8": return "serverNegotiatedHLS"
        case "ts": return "serverNegotiatedTransportStream"
        default: return "directHandoff"
        }
    }

    private func requestExternalShare() {
        Task {
            _ = await resolveExternalHandoffRequest()
            guard handoffRequest.containsSensitiveCredential else {
                sharePayload = ServiceSharePayload(url: handoffRequest.externalHandoffURL)
                return
            }
            pendingExternalTarget = nil
            pendingShareHandoff = true
            showCredentialHandoffWarning = true
        }
    }

    private var activeCompatibilityRequest: MediaPlaybackRequest? {
        resolvedCompatibilityRequest
    }

    private var handoffRequest: MediaPlaybackRequest {
        resolvedExternalHandoffRequest ?? request
    }

    @MainActor
    private func resolveCompatibilityRequest() async -> MediaPlaybackRequest {
        if let resolvedCompatibilityRequest { return resolvedCompatibilityRequest }
        guard let loader = request.compatibilityResourceLoader else {
            return request.compatibilityPlaybackRequest
        }
        isPreparingAlternative = true
        defer { isPreparingAlternative = false }
        let task: Task<MediaPlaybackResource?, Never>
        if let compatibilityLoadTask {
            task = compatibilityLoadTask
        } else {
            task = Task { await loader() }
            compatibilityLoadTask = task
        }
        let resource = await task.value
        compatibilityLoadTask = nil
        let resolved = resource.map {
            request.playbackRequest(
                using: $0,
                initialPositionOverride: compatibilityResumePosition
            )
        }
            ?? request.compatibilityPlaybackRequest
        resolvedCompatibilityRequest = resolved
        return resolved
    }

    @MainActor
    private func resolveCompatibilityFallbackRequest(
        from failingRequest: MediaPlaybackRequest,
        resumePosition: Double?,
        runtimeState: MediaPlaybackRuntimeState?
    ) async -> MediaPlaybackRequest? {
        if let loader = failingRequest.compatibilityFallbackRequestLoader {
            isPreparingAlternative = true
            defer { isPreparingAlternative = false }
            let task: Task<MediaPlaybackRequest?, Never>
            if let compatibilityFallbackRequestLoadTask {
                task = compatibilityFallbackRequestLoadTask
            } else {
                task = Task { await loader(runtimeState) }
                compatibilityFallbackRequestLoadTask = task
            }
            let replacement = await task.value
            compatibilityFallbackRequestLoadTask = nil
            return replacement
        }
        if let resource = failingRequest.compatibilityFallbackResource {
            return failingRequest.playbackRequest(
                using: resource,
                initialPositionOverride: resumePosition,
                runtimeState: runtimeState,
                retainsFallback: false
            )
        }
        guard let loader = failingRequest.compatibilityFallbackResourceLoader else { return nil }
        isPreparingAlternative = true
        defer { isPreparingAlternative = false }
        let task: Task<MediaPlaybackResource?, Never>
        if let compatibilityFallbackLoadTask {
            task = compatibilityFallbackLoadTask
        } else {
            task = Task { await loader(runtimeState) }
            compatibilityFallbackLoadTask = task
        }
        let resource = await task.value
        compatibilityFallbackLoadTask = nil
        return resource.map {
            failingRequest.playbackRequest(
                using: $0,
                initialPositionOverride: resumePosition,
                runtimeState: runtimeState,
                retainsFallback: false
            )
        }
    }

    @MainActor
    private func resolveExternalHandoffRequest() async -> MediaPlaybackRequest {
        if let resolvedExternalHandoffRequest { return resolvedExternalHandoffRequest }
        if request.externalHandoffResource != nil {
            resolvedExternalHandoffRequest = request
            return request
        }
        guard let loader = request.externalHandoffResourceLoader else {
            return request
        }
        isPreparingAlternative = true
        defer { isPreparingAlternative = false }
        let task: Task<MediaPlaybackResource?, Never>
        if let externalHandoffLoadTask {
            task = externalHandoffLoadTask
        } else {
            task = Task { await loader() }
            externalHandoffLoadTask = task
        }
        let resource = await task.value
        externalHandoffLoadTask = nil
        let resolved = resource.map { resource in
            MediaPlaybackRequest(
                url: request.url,
                title: request.title,
                allowsSelfSignedCertificates: request.allowsSelfSignedCertificates,
                source: request.source,
                fileExtensionOverride: request.fileExtensionOverride,
                initialPosition: request.initialPosition,
                externalSubtitleURL: request.externalSubtitleURL,
                preferredAudioTrackOrdinal: request.preferredAudioTrackOrdinal,
                preferredSubtitleTrackOrdinal: request.preferredSubtitleTrackOrdinal,
                prefersSubtitlesDisabled: request.prefersSubtitlesDisabled,
                initialOrientationMode: request.initialOrientationMode,
                initialPlaybackRate: request.initialPlaybackRate,
                isPrivateNetworkRoute: request.isPrivateNetworkRoute,
                playbackTracker: request.playbackTracker,
                compatibilityResource: request.compatibilityResource,
                compatibilityFallbackResource: request.compatibilityFallbackResource,
                externalHandoffResource: resource,
                compatibilityResourceLoader: request.compatibilityResourceLoader,
                compatibilityFallbackResourceLoader: request.compatibilityFallbackResourceLoader,
                compatibilityFallbackRequestLoader: request.compatibilityFallbackRequestLoader
            )
        } ?? request
        resolvedExternalHandoffRequest = resolved
        return resolved
    }

    private func togglePlayerOrientation() {
        let isLandscape = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .contains { $0.interfaceOrientation.isLandscape }
        PlayerOrientationController.requestPlayerOrientation(isLandscape ? .portrait : .landscape)
    }
}

#if canImport(MobileVLCKit)
private struct VLCSubtitleTrack: Identifiable, Equatable {
    let id: Int32
    let name: String
}

private struct VLCAudioTrack: Identifiable, Equatable {
    let id: Int32
    let name: String
}

enum VLCTrustDirectory {
    static func options(for request: MediaPlaybackRequest) -> [String] {
        guard
            request.allowsSelfSignedCertificates,
            let certificateData = CertificatePinStore.shared.trustedCertificateData(
                host: request.url.host,
                port: request.url.port
            ),
            let directory = writePEMCertificate(
                certificateData,
                host: request.url.host,
                port: request.url.port
            )
        else {
            return []
        }
        return ["--gnutls-dir-trust=\(directory.path)"]
    }

    private static func writePEMCertificate(
        _ certificateData: Data,
        host: String?,
        port: Int?
    ) -> URL? {
        guard let cachesURL = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        let safeHost = (host ?? "server").map { character in
            character.isLetter || character.isNumber || character == "." ? character : "_"
        }
        let directory = cachesURL
            .appendingPathComponent("VLCTrust", isDirectory: true)
            .appendingPathComponent("\(String(safeHost))-\(port ?? 443)", isDirectory: true)
        let certificateURL = directory.appendingPathComponent("certificate.pem")
        let base64 = certificateData.base64EncodedString(options: .lineLength64Characters)
        let pem = "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try Data(pem.utf8).write(to: certificateURL, options: .atomic)
            return directory
        } catch {
            return nil
        }
    }
}

private enum VLCPlaybackRuntime {
    static let configureEventDelivery: Void = {
        VLCLibrary.sharedEventsConfiguration = VLCEventsLegacyConfiguration()
    }()
}

private enum VLCTrackSelectionKind: String {
    case audio
    case subtitle
}

private struct PendingVLCTrackSelection {
    let targetID: Int32
    let previousID: Int32
    let startedAt: Date
}

private final class VLCMediaPlayerSession: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    let player: VLCMediaPlayer
    @Published private(set) var isPlaying = false
    @Published private(set) var isMuted = false
    @Published private(set) var position: Double = 0
    @Published private(set) var isSeekable = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var subtitleTracks: [VLCSubtitleTrack] = []
    @Published private(set) var selectedSubtitleTrackID: Int32 = -1
    @Published private(set) var audioTracks: [VLCAudioTrack] = []
    @Published private(set) var selectedAudioTrackID: Int32 = -1
    @Published private(set) var isBuffering = true
    @Published private(set) var hasStartedPlayback = false
    @Published private(set) var currentTimeText = "00:00"
    @Published private(set) var currentTimeSeconds = 0.0
    @Published private(set) var durationText = "--:--"
    @Published private(set) var durationSeconds = 0.0
    @Published private(set) var playbackRate: Float = 1
    private let request: MediaPlaybackRequest
    private let hasCustomTLSRoot: Bool
    private var lastStateDescription = ""
    private let initialPosition: Double?
    private let externalSubtitleURL: URL?
    private let preferredAudioTrackOrdinal: Int?
    private let preferredSubtitleTrackOrdinal: Int?
    private let prefersSubtitlesDisabled: Bool
    private var didApplyInitialPosition = false
    private var didApplyInitialAudioTrack = false
    private var didApplyInitialSubtitleTrack = false
    private var didApplyPlaybackRate = false
    private var desiredAudioTrackID: Int32?
    private var desiredSubtitleTrackID: Int32?
    private var pendingAudioTrackSelection: PendingVLCTrackSelection?
    private var pendingSubtitleTrackSelection: PendingVLCTrackSelection?
    private var audioTrackSelectionCheckWorkItem: DispatchWorkItem?
    private var subtitleTrackSelectionCheckWorkItem: DispatchWorkItem?
    private var desiredPlaybackRate: Float
    private var didApplySubtitleStyle = false
    private var didAddExternalSubtitle = false
    private var externalSubtitleSelectionWorkItem: DispatchWorkItem?
    private var subtitleTrackIDsBeforeExternalAdd: Set<Int32> = []
    private var lastSubtitleTrackIDs: [Int32] = []
    private var lastAudioTrackIDs: [Int32] = []
    private var cachedSubtitleTracks: [VLCSubtitleTrack] = []
    private var cachedAudioTracks: [VLCAudioTrack] = []
    private var trackInventoryNeedsRefresh = true
    private var trackInventoryRefreshDeadline = Date.distantPast
    private var lastTrackInventoryRefreshAt: Date?
    private var pendingJumpSeconds = 0
    private var pendingJumpWorkItem: DispatchWorkItem?
    private var didRecordStart = false
    private var didReissueStartupPlay = false
    private var didReachPlayback = false
    private var didRequestStop = false
    private var didFinishPlaybackNaturally = false
    private var reconnectAttempts = 0
    private var reconnectWorkItem: DispatchWorkItem?
    private var isReconnecting = false
    private var reconnectStartedAt: Date?
    private var reconnectRecoveryBaselineSeconds = 0.0
    private var highestPlaybackSeconds = 0.0
    private var lastObservedPlaybackSeconds: Double?
    private var lastPlaybackProgressAt: Date?
    private var pendingResumePosition: Double?
    private var suppressNextClockAdvanceForInitialSeek = false
    private var isUserPaused = false
    private var didRecordFirstFrame = false
    private var pendingSeekStartedAt: Date?
    private var pendingSeekOriginSeconds: Double?
    private var pendingSeekTargetSeconds: Double?
    private var bufferingStartedAt: Date?
    private var lastBufferingState = true
    private var lastTimeStateSyncAt = Date.distantPast
    private var pendingTimeStateSyncWorkItem: DispatchWorkItem?
    private let minimumTimeStateSyncInterval: TimeInterval = 0.25
    private let reconnectTimeout: TimeInterval = 24

    var initialLoadTimeoutNanoseconds: UInt64 {
        let isPrivateHost = request.isPrivateNetworkRoute
            ?? NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
        switch request.source {
        case .jellyfin where request.fileExtensionHint == "m3u8" && hasAlternateTransport:
            return isPrivateHost ? 12_000_000_000 : 15_000_000_000
        case .jellyfin:
            // A Jellyfin original can be a very large Matroska file whose
            // index is near the end of the object. Waiting 10–12 seconds for
            // VLC to open that Range input makes the player look black before
            // the already-available HLS fallback is even requested. Keep a
            // small direct-play grace for fast local files, then hand off to
            // the compatibility HLS route so the first visible frame wins.
            return isPrivateHost ? 6_000_000_000 : 5_000_000_000
        case .dsmFile:
            // Device-file playback stays original-first, but must not leave a
            // remote NAS stream black for half a minute before its fallback.
            return isPrivateHost ? 8_000_000_000 : 6_000_000_000
        case .directURL:
            return 30_000_000_000
        }
    }

    init(request: MediaPlaybackRequest) {
        _ = VLCPlaybackRuntime.configureEventDelivery
        self.request = request
        initialPosition = request.initialPosition
        externalSubtitleURL = request.externalSubtitleURL
        preferredAudioTrackOrdinal = request.preferredAudioTrackOrdinal
        preferredSubtitleTrackOrdinal = request.preferredSubtitleTrackOrdinal
        prefersSubtitlesDisabled = request.prefersSubtitlesDisabled
        desiredPlaybackRate = request.initialPlaybackRate
        let trustOptions = VLCTrustDirectory.options(for: request)
        hasCustomTLSRoot = !trustOptions.isEmpty
        player = trustOptions.isEmpty
            ? VLCMediaPlayer()
            : VLCMediaPlayer(options: trustOptions)
        super.init()
        player.delegate = self
        player.media = makeMedia()
        resetTrackInventoryRefreshWindow()
    }

    private func makeMedia() -> VLCMedia {
        let media = VLCMedia(url: request.url)
        let networkCaching = networkCachingMilliseconds
        media.addOption(":network-caching=\(networkCaching)")
        media.addOption(":file-caching=\(networkCaching)")
        media.addOption(":http-reconnect")
        media.addOption(":input-fast-seek")
        if usesAVFormatDemux {
            media.addOption(":demux=avformat")
        }
        media.addOption(request.forcesSoftwareDecoding ? ":avcodec-hw=none" : ":avcodec-hw=any")
        // MobileVLCKit's freetype-font option expects a readable font file.
        // Copy the system CJK collection into the app cache once so embedded
        // subtitles can render on iOS without relying on a protected system
        // path. External normalized subtitles use the UIKit overlay below.
        media.addOption(":text-renderer=freetype")
        if let cjkFontPath = Self.cjkFontPath {
            media.addOption(":freetype-font=\(cjkFontPath)")
        }
        if request.externalSubtitleURL != nil {
            // External SRT/ASS is rendered by UIKit with a guaranteed CJK
            // font. Prevent VLC from drawing a second tofu/duplicate line.
            media.addOption(":no-spu")
        }
        // Chinese subtitle files in real NAS libraries are a mixture of UTF-8,
        // GBK and legacy GB18030.  Forcing UTF-8 makes the latter render as
        // mojibake (the problem seen in the Mission: Impossible 3 sample).
        // Keep GB18030 as the fallback while asking VLC to auto-detect UTF-8;
        // this preserves modern ASS/SRT files and decodes older ANSI files.
        media.addOption(":subsdec-encoding=GB18030")
        media.addOption(":subsdec-autodetect-utf8=1")
        // Keep text subtitles inside the safe video area. This prevents the
        // second Chinese line from being clipped by the iPhone/iPad bottom
        // inset while retaining a visible outline on bright scenes.
        media.addOption(":sub-margin=32")
        media.addOption(":freetype-outline-thickness=2")
        media.addOption(":freetype-shadow-opacity=128")
        media.addOption(":freetype-rel-fontsize=18")
        return media
    }

    private var networkCachingMilliseconds: Int {
        let isPrivateRoute = request.isPrivateNetworkRoute
            ?? NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
        // Direct HTTP Range files benefit from a short buffer: it keeps
        // startup and seeking responsive. A Jellyfin HLS fallback, however,
        // gets its data one transcoded segment at a time. The old shared
        // 900 ms private-LAN value made a brief NAS transcoder or Wi-Fi jitter
        // immediately visible as repeated stalls. Give HLS enough runway to
        // bridge several segment boundaries without penalising direct play.
        if isHLSCompatibilityStream {
            return isPrivateRoute ? 5_000 : 7_500
        }
        return isPrivateRoute ? 900 : 1_500
    }

    private var isHLSCompatibilityStream: Bool {
        request.source == .jellyfin && request.fileExtensionHint == "m3u8"
    }

    private static var cjkFontPath: String? {
        var sourcePath: String?
        for family in ["PingFangSC-Regular", "HiraginoSansGB-W3"] {
            let font = CTFontCreateWithName(family as CFString, 18, nil)
            if let url = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL {
                sourcePath = url.path
                break
            }
        }
        sourcePath = sourcePath ?? [
            "/System/Library/Fonts/LanguageSupport/PingFang.ttc",
            "/System/Library/Fonts/LanguageSupport/Hiragino Sans GB.ttc",
            "/System/Library/Fonts/PingFang.ttc",
            "/System/Library/Fonts/Hiragino Sans GB.ttc"
        ].first { FileManager.default.fileExists(atPath: $0) }
        guard let sourcePath, FileManager.default.fileExists(atPath: sourcePath) else {
            return nil
        }

        let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("Nastart/Fonts", isDirectory: true)
        let cachedFontURL = cacheDirectory.appendingPathComponent("NastartCJK.ttc")
        if !FileManager.default.fileExists(atPath: cachedFontURL.path) {
            do {
                try FileManager.default.createDirectory(
                    at: cacheDirectory,
                    withIntermediateDirectories: true
                )
                let fontData = try Data(contentsOf: URL(fileURLWithPath: sourcePath))
                try fontData.write(to: cachedFontURL, options: .atomic)
            } catch {
                return sourcePath
            }
        }
        return cachedFontURL.path
    }

    private var usesAVFormatDemux: Bool {
        request.fileExtensionHint == "ts" || request.fileExtensionHint == "m2ts"
    }

    func attach(to view: UIView) {
        if let drawable = player.drawable as AnyObject?, drawable === view {
            return
        }
        player.drawable = view
        player.scaleFactor = 0
    }

    func detach(from view: UIView) {
        guard let drawable = player.drawable as AnyObject?, drawable === view else {
            return
        }
        player.drawable = nil
    }

    func play() {
        didRequestStop = false
        didFinishPlaybackNaturally = false
        isUserPaused = false
        didReissueStartupPlay = false
        if !didRecordStart {
            didRecordStart = true
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_started",
                details: MediaPlaybackProbe.baseDetails(for: request).merging([
                    "engine": "MobileVLCKit",
                    "customTLSRoot": hasCustomTLSRoot ? "on" : "off",
                    "decoder": request.forcesSoftwareDecoding ? "software" : "automatic",
                    "demux": usesAVFormatDemux ? "avformat" : "default",
                    "networkCachingMs": "\(networkCachingMilliseconds)",
                    "transport": isHLSCompatibilityStream ? "jellyfinHLS" : "directHTTP",
                    "httpMode": "file",
                    "subtitleFont": Self.cjkFontPath ?? "default",
                    "subtitleEncoding": "GB18030+UTF8Autodetect"
                ]) { current, _ in current }
            )
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        addExternalSubtitleIfNeeded()
        syncState()
    }

    func togglePlayback() {
        if player.isPlaying {
            isUserPaused = true
            reconnectWorkItem?.cancel()
            reconnectWorkItem = nil
            player.pause()
        } else {
            isUserPaused = false
            lastPlaybackProgressAt = Date()
            player.play()
        }
        syncState()
    }

    func jump(by seconds: Int) {
        isBuffering = true
        cancelPendingReconnectForUserSeek()
        pendingJumpSeconds += seconds
        if pendingJumpWorkItem == nil {
            let originSeconds = max(Double(player.time.intValue) / 1_000, 0)
            beginSeekMeasurement(
                targetSeconds: max(originSeconds + Double(pendingJumpSeconds), 0)
            )
        } else if let pendingSeekOriginSeconds {
            pendingSeekTargetSeconds = max(
                pendingSeekOriginSeconds + Double(pendingJumpSeconds),
                0
            )
        }
        pendingJumpWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let seconds = self.pendingJumpSeconds
            self.pendingJumpSeconds = 0
            self.pendingJumpWorkItem = nil
            if seconds < 0 {
                self.player.jumpBackward(Int32(clamping: -seconds))
            } else if seconds > 0 {
                self.player.jumpForward(Int32(clamping: seconds))
            }
        }
        pendingJumpWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: workItem)
    }

    func seek(to newPosition: Double) {
        guard player.isSeekable else { return }
        isBuffering = true
        cancelPendingReconnectForUserSeek()
        let position = min(max(newPosition, 0), 1)
        let runtime = max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
        beginSeekMeasurement(targetSeconds: runtime > 0 ? runtime * position : nil)
        player.position = Float(position)
    }

    @discardableResult
    func seek(toAbsoluteSeconds targetSeconds: Double) -> Bool {
        guard player.isSeekable, targetSeconds.isFinite else { return false }
        let rawDuration = max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
        let rawTarget = targetSeconds - request.timelineOffsetSeconds
        guard rawDuration > 0, rawTarget >= 0, rawTarget <= rawDuration else { return false }
        isBuffering = true
        cancelPendingReconnectForUserSeek()
        beginSeekMeasurement(targetSeconds: targetSeconds)
        player.position = Float(min(max(rawTarget / rawDuration, 0), 1))
        return true
    }

    func setPlaybackRate(_ rate: Float) {
        let normalizedRate = min(max(rate, 0.25), 4)
        desiredPlaybackRate = normalizedRate
        didApplyPlaybackRate = true
        player.rate = normalizedRate
        playbackRate = normalizedRate
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.playback_rate_changed",
            details: ["rate": String(format: "%.2f", normalizedRate)]
        )
    }

    func toggleMute() {
        guard let audio = player.audio else { return }
        let muted = !audio.isMuted
        audio.isMuted = muted
        isMuted = muted
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.mute_changed",
            details: ["muted": muted ? "yes" : "no"]
        )
    }

    func selectSubtitle(_ track: VLCSubtitleTrack) {
        guard pendingSubtitleTrackSelection?.targetID != track.id,
              selectedSubtitleTrackID != track.id else {
            return
        }
        let selection = PendingVLCTrackSelection(
            targetID: track.id,
            previousID: player.currentVideoSubTitleIndex,
            startedAt: Date()
        )
        desiredSubtitleTrackID = track.id
        didApplyInitialSubtitleTrack = true
        pendingSubtitleTrackSelection = selection
        selectedSubtitleTrackID = track.id
        recordTrackSelectionRequested(selection, kind: .subtitle)
        player.currentVideoSubTitleIndex = track.id
        scheduleTrackSelectionCheck(kind: .subtitle)
    }

    @discardableResult
    func selectExternalSubtitle(_ url: URL?) -> Bool {
        didApplyInitialSubtitleTrack = true
        if let url {
            let startedAt = Date()
            let result = player.addPlaybackSlave(url, type: .subtitle, enforce: true)
            trackInventoryNeedsRefresh = true
            trackInventoryRefreshDeadline = Date().addingTimeInterval(4)
            DiagnosticLogStore.shared.record(
                result == 0 ? .info : .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.external_subtitle",
                details: [
                    "result": "\(result)",
                    "operation": "runtimeSelection",
                    "selectionMs": Self.elapsedMilliseconds(since: startedAt)
                ]
            )
            return result == 0
        }
        desiredSubtitleTrackID = -1
        selectedSubtitleTrackID = -1
        player.currentVideoSubTitleIndex = -1
        return true
    }

    func selectAudio(_ track: VLCAudioTrack) {
        guard pendingAudioTrackSelection?.targetID != track.id,
              selectedAudioTrackID != track.id else {
            return
        }
        let selection = PendingVLCTrackSelection(
            targetID: track.id,
            previousID: player.currentAudioTrackIndex,
            startedAt: Date()
        )
        desiredAudioTrackID = track.id
        didApplyInitialAudioTrack = true
        pendingAudioTrackSelection = selection
        selectedAudioTrackID = track.id
        recordTrackSelectionRequested(selection, kind: .audio)
        player.currentAudioTrackIndex = track.id
        scheduleTrackSelectionCheck(kind: .audio)
    }

    func stop() {
        didRequestStop = true
        isUserPaused = false
        reconnectWorkItem?.cancel()
        audioTrackSelectionCheckWorkItem?.cancel()
        subtitleTrackSelectionCheckWorkItem?.cancel()
        player.stop()
    }

    func pauseForExternalHandoff() {
        isUserPaused = true
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        player.pause()
        syncState()
    }

    func runtimeState(orientationMode: PlayerOrientationMode) -> MediaPlaybackRuntimeState {
        let selectableAudioIDs = audioTracks.map(\.id).filter { $0 >= 0 }
        let selectableSubtitleIDs = subtitleTracks.map(\.id).filter { $0 >= 0 }
        let audioOrdinal = selectableAudioIDs.firstIndex(of: selectedAudioTrackID)
        let subtitlesDisabled = selectedSubtitleTrackID < 0
        return MediaPlaybackRuntimeState(
            normalizedPosition: position,
            positionSeconds: currentTimeSeconds,
            playbackRate: desiredPlaybackRate,
            audioTrackOrdinal: audioOrdinal,
            subtitleTrackOrdinal: subtitlesDisabled
                ? nil
                : selectableSubtitleIDs.firstIndex(of: selectedSubtitleTrackID),
            subtitlesDisabled: subtitlesDisabled,
            subtitleSelectionKnown: didApplyInitialSubtitleTrack || !lastSubtitleTrackIDs.isEmpty,
            orientationMode: orientationMode
        )
    }

    func failIfStillLoading() {
        guard !didReachPlayback, errorMessage == nil else { return }
        let state = Self.stateDescription(player.state)
        let reason = player.isPlaying ? "playbackClockTimeout" : "loadTimeout"
        errorMessage = NSLocalizedString("player.load_timeout", comment: "")
        isBuffering = false
        player.stop()
        DiagnosticLogStore.shared.record(
            .error,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_failed",
            details: [
                "engine": "MobileVLCKit",
                "state": state,
                "reason": reason,
                "decoder": request.forcesSoftwareDecoding ? "software" : "automatic"
            ]
        )
    }

    func initialLoadGraceNanosecondsIfNeeded() -> UInt64 {
        guard !didReachPlayback, errorMessage == nil else { return 0 }
        // An elementary-stream notification is not a rendered frame for an
        // original file. Only HLS is allowed the longer segment-start grace.
        guard request.fileExtensionHint == "m3u8" else { return 0 }
        let state = Self.stateDescription(player.state).lowercased()
        let hasActiveInput = player.isPlaying
            || state.contains("elementarystreamadded")
        guard hasActiveInput else { return 0 }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_state",
            details: [
                "engine": "MobileVLCKit",
                "state": "initialLoadGrace",
                "observedState": state,
                "graceSeconds": "20"
            ]
        )
        return 20_000_000_000
    }

    func recoverIfStalled() {
        guard
            !didRequestStop,
            !didFinishPlaybackNaturally,
            !isUserPaused,
            player.state != .paused,
            errorMessage == nil
        else {
            return
        }
        // Jellyfin original playback is deliberately attempted first, but a
        // device-specific decoder or a large Matroska seek can stop after the
        // first frame. In that case the already-negotiated server fallback is
        // the safe recovery. Do not wait forever just because the URL is not
        // an HLS playlist.
        guard hasAlternateTransport,
              request.source == .jellyfin || request.source == .dsmFile else {
            return
        }
        let now = Date()
        if didReachPlayback,
           let lastPlaybackProgressAt,
           now.timeIntervalSince(lastPlaybackProgressAt) >= 1.5,
           !isBuffering {
            isBuffering = true
            recordBufferingTransition(isBuffering: true)
        }
        guard didReachPlayback else { return }
        if isReconnecting {
            guard let reconnectStartedAt,
                  Date().timeIntervalSince(reconnectStartedAt) >= reconnectTimeout else {
                return
            }
            isReconnecting = false
            self.reconnectStartedAt = nil
            if reconnectAttempts < maximumReconnectAttempts {
                scheduleReconnect(reason: "reconnectTimeout")
            } else {
                fail(reason: "reconnectLimit")
            }
            return
        }
        guard let lastPlaybackProgressAt,
              now.timeIntervalSince(lastPlaybackProgressAt) >= stallTimeout,
              isBuffering || !player.isPlaying else {
            return
        }
        fail(reason: request.fileExtensionHint == "m3u8"
            ? "alternateTransportPreferred"
            : "originalPlaybackStall")
    }

    func mediaPlayerStateChanged(_ notification: Notification) {
        if player.state == .esAdded {
            trackInventoryNeedsRefresh = true
        }
        pendingTimeStateSyncWorkItem?.cancel()
        pendingTimeStateSyncWorkItem = nil
        lastTimeStateSyncAt = Date()
        syncState()
    }

    func mediaPlayerTimeChanged(_ notification: Notification) {
        let elapsed = Date().timeIntervalSince(lastTimeStateSyncAt)
        if elapsed >= minimumTimeStateSyncInterval {
            pendingTimeStateSyncWorkItem?.cancel()
            pendingTimeStateSyncWorkItem = nil
            lastTimeStateSyncAt = Date()
            syncState()
            return
        }
        guard pendingTimeStateSyncWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.pendingTimeStateSyncWorkItem = nil
            self.lastTimeStateSyncAt = Date()
            self.syncState()
        }
        pendingTimeStateSyncWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + max(minimumTimeStateSyncInterval - elapsed, 0),
            execute: workItem
        )
    }

    private func syncState() {
        let isPlaying = player.isPlaying
        let isSeekable = player.isSeekable
        let rawPosition = Double(max(player.position, 0))
        let stateDescription = Self.stateDescription(player.state)
        let normalizedState = stateDescription.lowercased()
        let inputIsReadyForInitialSeek = isPlaying
            || player.state == .esAdded
            || didReachPlayback
        if !didApplyInitialPosition,
           request.timelineOffsetSeconds == 0,
           isSeekable,
           inputIsReadyForInitialSeek,
           let resumePosition = pendingResumePosition ?? initialPosition,
           resumePosition > 0 {
            didApplyInitialPosition = true
            pendingResumePosition = nil
            suppressNextClockAdvanceForInitialSeek = true
            player.position = Float(resumePosition)
        }
        let reportsBuffering = normalizedState.contains("opening") || normalizedState.contains("buffering")
        if reportsBuffering,
           !didReachPlayback,
           !isUserPaused,
           !didRequestStop,
           !player.isPlaying,
           !didReissueStartupPlay {
            // Some authenticated Jellyfin Range responses enter VLC's
            // buffering state without retaining the initial play command.
            // Reissue it once during startup so the user does not have to
            // tap Play manually after an otherwise valid first response.
            didReissueStartupPlay = true
            player.play()
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": "startupPlayReissued",
                    "reason": "bufferingWithoutPlaying"
                ]
            )
        }
        applySubtitleStyleIfNeeded(isRendererReady: reportsBuffering || player.isPlaying)
        let rawCurrentSeconds = max(Double(player.time.intValue) / 1_000, 0)
        let rawDurationSeconds = max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
        let durationSeconds = request.totalDurationSeconds ?? rawDurationSeconds
        let currentSeconds = min(
            request.timelineOffsetSeconds + rawCurrentSeconds,
            durationSeconds > 0 ? durationSeconds : .greatestFiniteMagnitude
        )
        let position = durationSeconds > 0
            ? min(max(currentSeconds / durationSeconds, 0), 1)
            : rawPosition
        let currentTimeText = Self.timeText(seconds: currentSeconds)
        let durationText = durationSeconds > 0
            ? Self.timeText(seconds: durationSeconds)
            : "--:--"
        let videoSize = player.videoSize
        let hasVideoOutput = player.hasVideoOut
            && videoSize.width > 0
            && videoSize.height > 0
        let rawPlaybackClockAdvanced = lastObservedPlaybackSeconds.map {
            abs(currentSeconds - $0) >= 0.2
        } ?? false
        let playbackClockAdvanced: Bool
        if suppressNextClockAdvanceForInitialSeek {
            // A resume seek can move VLC's clock by several minutes before a
            // single frame is rendered. Do not count that jump as first-frame
            // evidence; wait for the next real playback tick.
            suppressNextClockAdvanceForInitialSeek = false
            playbackClockAdvanced = false
        } else {
            playbackClockAdvanced = rawPlaybackClockAdvanced
        }
        let now = Date()
        if playbackClockAdvanced {
            lastPlaybackProgressAt = now
            if isReconnecting {
                isReconnecting = false
                reconnectStartedAt = nil
            }
        }
        // hasVideoOut only means that VLC created a video output object. It is
        // not proof that a frame reached the screen. Requiring the media clock
        // to advance prevents a black iPad surface from being marked ready and
        // lets the bounded Jellyfin fallback run.
        let presentedMedia = request.isAudioOnly
            ? playbackClockAdvanced
            : hasVideoOutput && playbackClockAdvanced
        if presentedMedia, !didReachPlayback {
            didReachPlayback = true
            lastPlaybackProgressAt = now
        }
        let playbackClockRecentlyAdvanced = playbackClockAdvanced
            // MobileVLCKit can publish its media clock at roughly one-second
            // intervals for HLS even while decoded frames continue flowing.
            // Keep the grace window above that cadence so the UI and
            // diagnostics do not report a 250 ms "buffer" once per second.
            || lastPlaybackProgressAt.map { now.timeIntervalSince($0) < 1.5 } == true
        let isWaitingForSeekRecovery = pendingSeekStartedAt != nil && !playbackClockAdvanced
        let hasActionableBufferingState = request.fileExtensionHint == "m3u8"
        let isBuffering = reportsBuffering
            && (!didReachPlayback
                || (hasActionableBufferingState
                    && (isWaitingForSeekRecovery || !playbackClockRecentlyAdvanced)))
        if player.isPlaying, !didApplyPlaybackRate {
            didApplyPlaybackRate = true
            player.rate = desiredPlaybackRate
        }
        if didReachPlayback, !didRecordFirstFrame {
            didRecordFirstFrame = true
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_ready",
                details: MediaPlaybackProbe.baseDetails(for: request).merging([
                    "engine": "MobileVLCKit",
                    "readySignal": request.isAudioOnly
                        ? "playbackClock"
                        : "videoOutput+playbackClock",
                    "tapToFirstFrameMs": Self.elapsedMilliseconds(since: request.requestedAt)
                ]) { current, _ in current }
            )
        }
        recordBufferingTransition(isBuffering: isBuffering)
        recordSeekRecoveryIfNeeded(currentSeconds: currentSeconds, isBuffering: isBuffering)
        lastObservedPlaybackSeconds = currentSeconds
        if currentSeconds > highestPlaybackSeconds + 0.2 {
            highestPlaybackSeconds = currentSeconds
            if reconnectAttempts > 0,
               currentSeconds >= reconnectRecoveryBaselineSeconds + 10 {
                reconnectAttempts = 0
                reconnectRecoveryBaselineSeconds = currentSeconds
            }
        }
        if isPlaying {
            request.playbackTracker?.started(positionSeconds: currentSeconds)
        }
        request.playbackTracker?.progressed(
            positionSeconds: currentSeconds,
            isPaused: !isPlaying
        )
        let stateErrorMessage = player.state == .error
            ? NSLocalizedString("player.compatibility_failed", comment: "")
            : nil
        refreshTrackInventoryIfNeeded()
        applyInitialTrackSelectionIfNeeded(
            audioIndexes: lastAudioTrackIDs,
            subtitleIndexes: lastSubtitleTrackIDs
        )
        let actualSubtitleTrackID = player.currentVideoSubTitleIndex
        let actualAudioTrackID = player.currentAudioTrackIndex
        let selectedSubtitleTrackID = reconciledTrackSelectionID(
            actualID: actualSubtitleTrackID,
            kind: .subtitle
        )
        let selectedAudioTrackID = reconciledTrackSelectionID(
            actualID: actualAudioTrackID,
            kind: .audio
        )
        let furthestPlaybackSeconds = max(currentSeconds, highestPlaybackSeconds)
        let naturalEndToleranceSeconds = min(max(durationSeconds * 0.01, 3), 10)
        let reachedNaturalEnd = durationSeconds > 0
            && furthestPlaybackSeconds >= max(
                durationSeconds - naturalEndToleranceSeconds,
                0
            )
        let finiteInputEnded = player.state == .ended
            && request.fileExtensionHint != "m3u8"
        let completedNaturally = reachedNaturalEnd || finiteInputEnded
        if completedNaturally
            && (player.state == .ended || player.state == .stopped) {
            didFinishPlaybackNaturally = true
        }
        let endedPrematurely = player.state == .ended
            && !completedNaturally
            && didRecordStart
            && didReachPlayback
            && !didRequestStop
            && !isUserPaused
            && errorMessage == nil
        if endedPrematurely {
            if hasAlternateTransport {
                fail(reason: "prematureEnd")
            } else if !isReconnecting,
                      reconnectAttempts < maximumReconnectAttempts,
                      reconnectWorkItem == nil {
                scheduleReconnect(reason: "prematureEnd")
            }
        }
        let previousState = lastStateDescription.lowercased()
        let inputEndedBeforeFirstFrame = (player.state == .ended || player.state == .stopped)
            && !didReachPlayback
            && didRecordStart
            && !didRequestStop
            && !isUserPaused
            && errorMessage == nil
            && (!lastAudioTrackIDs.isEmpty
                || previousState.contains("playing")
                || previousState.contains("elementarystreamadded")
                || previousState.contains("opening")
                || previousState.contains("buffering"))
        if inputEndedBeforeFirstFrame {
            if hasAlternateTransport {
                fail(reason: "prematureEndBeforeFirstFrame")
            } else if !isReconnecting,
                      reconnectAttempts < maximumReconnectAttempts,
                      reconnectWorkItem == nil {
                scheduleReconnect(reason: "prematureEndBeforeFirstFrame")
            }
        }
        let stoppedUnexpectedly = player.state == .stopped && !didFinishPlaybackNaturally
        if stoppedUnexpectedly,
           didRecordStart,
           didReachPlayback,
           !didRequestStop,
           errorMessage == nil,
           !isReconnecting {
            if hasAlternateTransport {
                fail(reason: "unexpectedStop")
            } else if reconnectAttempts < maximumReconnectAttempts,
                      reconnectWorkItem == nil {
                scheduleReconnect(reason: "unexpectedStop")
            }
        }

        if stateDescription != lastStateDescription {
            lastStateDescription = stateDescription
            DiagnosticLogStore.shared.record(
                player.state == .error ? .error : .info,
                categoryKey: "diagnostics.category.media",
                messageKey: player.state == .error
                    ? "diagnostics.media.player_failed"
                    : "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": stateDescription,
                    "seekable": isSeekable ? "yes" : "no"
                ]
            )
        }

        if self.isPlaying != isPlaying { self.isPlaying = isPlaying }
        let isMuted = player.audio?.isMuted ?? false
        if self.isMuted != isMuted { self.isMuted = isMuted }
        if abs(self.position - position) >= 0.0001 { self.position = position }
        if self.isSeekable != isSeekable { self.isSeekable = isSeekable }
        if let stateErrorMessage {
            if self.errorMessage != stateErrorMessage { self.errorMessage = stateErrorMessage }
        }
        if subtitleTracks != cachedSubtitleTracks {
            subtitleTracks = cachedSubtitleTracks
        }
        if self.selectedSubtitleTrackID != selectedSubtitleTrackID {
            self.selectedSubtitleTrackID = selectedSubtitleTrackID
        }
        if audioTracks != cachedAudioTracks {
            audioTracks = cachedAudioTracks
        }
        if self.selectedAudioTrackID != selectedAudioTrackID {
            self.selectedAudioTrackID = selectedAudioTrackID
        }
        if self.isBuffering != isBuffering { self.isBuffering = isBuffering }
        if hasStartedPlayback != didReachPlayback { hasStartedPlayback = didReachPlayback }
        if self.currentTimeText != currentTimeText { self.currentTimeText = currentTimeText }
        if abs(self.currentTimeSeconds - currentSeconds) >= 0.05 {
            self.currentTimeSeconds = currentSeconds
        }
        if self.durationText != durationText { self.durationText = durationText }
        if abs(self.durationSeconds - durationSeconds) >= 0.05 {
            self.durationSeconds = durationSeconds
        }
        let currentRate = player.rate
        if playbackRate != currentRate { playbackRate = currentRate }
    }

    private static func timeText(seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let totalSeconds = Int(seconds.rounded(.down))
        let hours = totalSeconds / 3_600
        let minutes = totalSeconds % 3_600 / 60
        let remainingSeconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func applyInitialTrackSelectionIfNeeded(
        audioIndexes: [Int32],
        subtitleIndexes: [Int32]
    ) {
        let selectableAudioIndexes = audioIndexes.filter { $0 >= 0 }
        if !didApplyInitialAudioTrack {
            if let desiredAudioTrackID,
               selectableAudioIndexes.contains(desiredAudioTrackID) {
                didApplyInitialAudioTrack = true
                player.currentAudioTrackIndex = desiredAudioTrackID
            } else if let preferredAudioTrackOrdinal,
                      selectableAudioIndexes.indices.contains(preferredAudioTrackOrdinal) {
                didApplyInitialAudioTrack = true
                player.currentAudioTrackIndex = selectableAudioIndexes[preferredAudioTrackOrdinal]
            }
        }

        guard !didApplyInitialSubtitleTrack else { return }
        if let desiredSubtitleTrackID {
            guard desiredSubtitleTrackID < 0 || subtitleIndexes.contains(desiredSubtitleTrackID) else {
                return
            }
            didApplyInitialSubtitleTrack = true
            player.currentVideoSubTitleIndex = desiredSubtitleTrackID
            return
        }
        if prefersSubtitlesDisabled {
            didApplyInitialSubtitleTrack = true
            player.currentVideoSubTitleIndex = -1
            return
        }
        guard externalSubtitleURL == nil,
              let preferredSubtitleTrackOrdinal else {
            return
        }
        let selectableSubtitleIndexes = subtitleIndexes.filter { $0 >= 0 }
        guard selectableSubtitleIndexes.indices.contains(preferredSubtitleTrackOrdinal) else {
            return
        }
        didApplyInitialSubtitleTrack = true
        player.currentVideoSubTitleIndex = selectableSubtitleIndexes[preferredSubtitleTrackOrdinal]
    }

    private func resetTrackInventoryRefreshWindow() {
        trackInventoryNeedsRefresh = true
        trackInventoryRefreshDeadline = Date().addingTimeInterval(8)
        lastTrackInventoryRefreshAt = nil
    }

    private func refreshTrackInventoryIfNeeded() {
        let now = Date()
        let isWithinStartupWindow = now < trackInventoryRefreshDeadline
        let startupRetryIsDue = isWithinStartupWindow
            && (lastTrackInventoryRefreshAt.map { now.timeIntervalSince($0) >= 0.75 } ?? true)
        guard trackInventoryNeedsRefresh || startupRetryIsDue else { return }
        trackInventoryNeedsRefresh = false
        lastTrackInventoryRefreshAt = now

        let subtitleNames = player.videoSubTitlesNames.compactMap { $0 as? String }
        let subtitleIndexes = player.videoSubTitlesIndexes.compactMap(Self.subtitleTrackID)
        let selectableSubtitleIndexes = subtitleIndexes.filter { $0 >= 0 }
        let subtitleDisplayNames = trackDisplayNames(
            rawNames: subtitleNames,
            allIndexes: subtitleIndexes,
            selectableIndexes: selectableSubtitleIndexes,
            sourceTracks: request.sourceSubtitleTracks,
            fallbackPrefix: NSLocalizedString("player.subtitles", comment: "")
        )
        let subtitleTracks = [VLCSubtitleTrack(
            id: -1,
            name: NSLocalizedString("player.subtitles.off", comment: "")
        )] + selectableSubtitleIndexes.enumerated().map { ordinal, id in
            VLCSubtitleTrack(id: id, name: subtitleDisplayNames[ordinal])
        }

        let audioNames = player.audioTrackNames.compactMap { $0 as? String }
        let audioIndexes = player.audioTrackIndexes.compactMap(Self.subtitleTrackID)
        let selectableAudioIndexes = audioIndexes.filter { $0 >= 0 }
        let audioDisplayNames = trackDisplayNames(
            rawNames: audioNames,
            allIndexes: audioIndexes,
            selectableIndexes: selectableAudioIndexes,
            sourceTracks: request.sourceAudioTracks,
            fallbackPrefix: NSLocalizedString("player.audio_tracks", comment: "")
        )
        let audioTracks = selectableAudioIndexes.enumerated().map { ordinal, id in
            VLCAudioTrack(id: id, name: audioDisplayNames[ordinal])
        }

        cachedSubtitleTracks = subtitleTracks
        cachedAudioTracks = audioTracks
        if didReachPlayback, !audioIndexes.isEmpty {
            trackInventoryRefreshDeadline = .distantPast
        }
        if subtitleIndexes != lastSubtitleTrackIDs {
            lastSubtitleTrackIDs = subtitleIndexes
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.subtitle_tracks",
                details: [
                    "count": "\(subtitleIndexes.filter { $0 >= 0 }.count)",
                    "selected": "\(player.currentVideoSubTitleIndex)"
                ]
            )
        }
        if audioIndexes != lastAudioTrackIDs {
            lastAudioTrackIDs = audioIndexes
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.audio_tracks",
                details: [
                    "count": "\(selectableAudioIndexes.count)",
                    "selected": "\(player.currentAudioTrackIndex)"
                ]
            )
        }
    }

    private func trackDisplayNames(
        rawNames: [String],
        allIndexes: [Int32],
        selectableIndexes: [Int32],
        sourceTracks: [MediaPlaybackSourceTrack],
        fallbackPrefix: String
    ) -> [String] {
        let indexedNames = Dictionary(
            uniqueKeysWithValues: zip(allIndexes, rawNames).map { ($0.0, $0.1) }
        )
        return selectableIndexes.enumerated().map { ordinal, id in
            if sourceTracks.indices.contains(ordinal) {
                return sourceTracks[ordinal].name
            }
            if let indexedName = indexedNames[id], !indexedName.isEmpty {
                return indexedName
            }
            return "\(fallbackPrefix) \(ordinal + 1)"
        }
    }

    private func reconciledTrackSelectionID(
        actualID: Int32,
        kind: VLCTrackSelectionKind
    ) -> Int32 {
        let pendingSelection = kind == .audio
            ? pendingAudioTrackSelection
            : pendingSubtitleTrackSelection
        guard let pendingSelection else { return actualID }
        if actualID == pendingSelection.targetID {
            finishTrackSelection(pendingSelection, kind: kind, didConfirm: true)
            return actualID
        }
        if Date().timeIntervalSince(pendingSelection.startedAt) >= 4 {
            finishTrackSelection(pendingSelection, kind: kind, didConfirm: false)
            return actualID
        }
        return pendingSelection.targetID
    }

    private func recordTrackSelectionRequested(
        _ selection: PendingVLCTrackSelection,
        kind: VLCTrackSelectionKind
    ) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.track_switch_requested",
            details: [
                "engine": "MobileVLCKit",
                "kind": kind.rawValue,
                "from": "\(selection.previousID)",
                "target": "\(selection.targetID)"
            ]
        )
    }

    private func scheduleTrackSelectionCheck(kind: VLCTrackSelectionKind) {
        let pendingSelection = kind == .audio
            ? pendingAudioTrackSelection
            : pendingSubtitleTrackSelection
        guard pendingSelection != nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if kind == .audio {
                self.audioTrackSelectionCheckWorkItem = nil
            } else {
                self.subtitleTrackSelectionCheckWorkItem = nil
            }
            let actualID = kind == .audio
                ? self.player.currentAudioTrackIndex
                : self.player.currentVideoSubTitleIndex
            let selectedID = self.reconciledTrackSelectionID(actualID: actualID, kind: kind)
            if kind == .audio {
                self.selectedAudioTrackID = selectedID
                if self.pendingAudioTrackSelection != nil {
                    self.scheduleTrackSelectionCheck(kind: kind)
                }
            } else {
                self.selectedSubtitleTrackID = selectedID
                if self.pendingSubtitleTrackSelection != nil {
                    self.scheduleTrackSelectionCheck(kind: kind)
                }
            }
        }
        if kind == .audio {
            audioTrackSelectionCheckWorkItem?.cancel()
            audioTrackSelectionCheckWorkItem = workItem
        } else {
            subtitleTrackSelectionCheckWorkItem?.cancel()
            subtitleTrackSelectionCheckWorkItem = workItem
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
    }

    private func finishTrackSelection(
        _ selection: PendingVLCTrackSelection,
        kind: VLCTrackSelectionKind,
        didConfirm: Bool
    ) {
        if kind == .audio {
            pendingAudioTrackSelection = nil
            audioTrackSelectionCheckWorkItem?.cancel()
            audioTrackSelectionCheckWorkItem = nil
        } else {
            pendingSubtitleTrackSelection = nil
            subtitleTrackSelectionCheckWorkItem?.cancel()
            subtitleTrackSelectionCheckWorkItem = nil
        }
        DiagnosticLogStore.shared.record(
            didConfirm ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: didConfirm
                ? "diagnostics.media.track_switch_confirmed"
                : "diagnostics.media.track_switch_timeout",
            details: [
                "engine": "MobileVLCKit",
                "kind": kind.rawValue,
                "target": "\(selection.targetID)",
                "selectionMs": Self.elapsedMilliseconds(since: selection.startedAt)
            ]
        )
    }

    private func scheduleReconnect(reason: String) {
        guard
            reconnectWorkItem == nil,
            !isReconnecting,
            !isUserPaused,
            !didRequestStop
        else {
            return
        }
        reconnectAttempts += 1
        let resumePosition = max(Double(player.position), 0)
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            guard !self.didRequestStop, !self.isUserPaused else { return }
            self.isReconnecting = true
            self.reconnectStartedAt = Date()
            self.reconnectRecoveryBaselineSeconds = self.highestPlaybackSeconds
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKit",
                    "state": "reconnecting",
                    "attempt": "\(self.reconnectAttempts)",
                    "reason": reason
                ]
            )
            self.pendingResumePosition = resumePosition
            if self.desiredAudioTrackID == nil, self.player.currentAudioTrackIndex >= 0 {
                self.desiredAudioTrackID = self.player.currentAudioTrackIndex
            }
            if self.desiredSubtitleTrackID == nil {
                self.desiredSubtitleTrackID = self.player.currentVideoSubTitleIndex
            }
            self.desiredPlaybackRate = self.player.rate
            self.lastPlaybackProgressAt = Date()
            self.lastObservedPlaybackSeconds = nil
            self.didApplyInitialPosition = false
            self.didApplyInitialAudioTrack = false
            self.didApplyInitialSubtitleTrack = false
            self.didApplyPlaybackRate = false
            self.didAddExternalSubtitle = false
            self.pendingAudioTrackSelection = nil
            self.pendingSubtitleTrackSelection = nil
            self.audioTrackSelectionCheckWorkItem?.cancel()
            self.subtitleTrackSelectionCheckWorkItem?.cancel()
            self.audioTrackSelectionCheckWorkItem = nil
            self.subtitleTrackSelectionCheckWorkItem = nil
            self.resetTrackInventoryRefreshWindow()
            self.player.stop()
            self.player.media = self.makeMedia()
            self.player.play()
            self.addExternalSubtitleIfNeeded()
        }
        reconnectWorkItem = workItem
        let delay = min(Double(reconnectAttempts), 3) * 0.75
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func fail(reason: String) {
        guard errorMessage == nil else { return }
        errorMessage = NSLocalizedString("player.compatibility_failed", comment: "")
        isBuffering = false
        player.stop()
        DiagnosticLogStore.shared.record(
            .error,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_failed",
            details: [
                "engine": "MobileVLCKit",
                "reason": reason,
                "reconnectAttempts": "\(reconnectAttempts)",
                "decoder": request.forcesSoftwareDecoding ? "software" : "automatic"
            ]
        )
    }

    private func cancelPendingReconnectForUserSeek() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        isReconnecting = false
        reconnectStartedAt = nil
        pendingResumePosition = nil
        lastObservedPlaybackSeconds = nil
        lastPlaybackProgressAt = Date()
    }

    private func beginSeekMeasurement(targetSeconds: Double?) {
        pendingSeekStartedAt = Date()
        pendingSeekOriginSeconds = max(Double(player.time.intValue) / 1_000, 0)
        pendingSeekTargetSeconds = targetSeconds
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.seek_requested",
            details: [
                "engine": "MobileVLCKit",
                "fromSeconds": String(format: "%.1f", pendingSeekOriginSeconds ?? 0),
                "targetSeconds": targetSeconds.map { String(format: "%.1f", $0) } ?? "-"
            ]
        )
    }

    private func recordSeekRecoveryIfNeeded(currentSeconds: Double, isBuffering: Bool) {
        guard
            let pendingSeekStartedAt,
            let pendingSeekOriginSeconds,
            !isBuffering,
            player.isPlaying
        else {
            return
        }
        let reachedRequestedRegion = pendingSeekTargetSeconds.map {
            abs(currentSeconds - $0) <= 1.5
        } ?? (abs(currentSeconds - pendingSeekOriginSeconds) >= 0.2)
        guard reachedRequestedRegion else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.seek_ready",
            details: [
                "engine": "MobileVLCKit",
                "recoveryMs": Self.elapsedMilliseconds(since: pendingSeekStartedAt),
                "fromSeconds": String(format: "%.1f", pendingSeekOriginSeconds),
                "targetSeconds": pendingSeekTargetSeconds.map { String(format: "%.1f", $0) } ?? "-",
                "actualSeconds": String(format: "%.1f", currentSeconds)
            ]
        )
        self.pendingSeekStartedAt = nil
        self.pendingSeekOriginSeconds = nil
        self.pendingSeekTargetSeconds = nil
    }

    private func recordBufferingTransition(isBuffering: Bool) {
        guard isBuffering != lastBufferingState else { return }
        lastBufferingState = isBuffering
        if isBuffering {
            if didReachPlayback { bufferingStartedAt = Date() }
            return
        }
        guard let bufferingStartedAt else { return }
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.buffer_recovered",
            details: [
                "engine": "MobileVLCKit",
                "bufferingMs": Self.elapsedMilliseconds(since: bufferingStartedAt)
            ]
        )
        self.bufferingStartedAt = nil
    }

    private static func elapsedMilliseconds(since date: Date) -> String {
        String(Int(max(Date().timeIntervalSince(date), 0) * 1_000))
    }

    private var hasAlternateTransport: Bool {
        request.compatibilityFallbackResource != nil
            || request.compatibilityFallbackResourceLoader != nil
            || request.compatibilityFallbackRequestLoader != nil
    }

    private var maximumReconnectAttempts: Int {
        request.source == .directURL ? 2 : 1
    }

    private var stallTimeout: TimeInterval {
        let isPrivateHost = request.isPrivateNetworkRoute
            ?? NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
        switch request.source {
        case .jellyfin:
            if request.fileExtensionHint == "m3u8", hasAlternateTransport {
                return isPrivateHost ? 12 : 10
            }
            // An original Jellyfin file is allowed to start slowly, but a
            // post-first-frame clock stop must not leave the player frozen for
            // half a minute before the server fallback is requested.
            return isPrivateHost ? 12 : 15
        case .dsmFile:
            return isPrivateHost ? 18 : 30
        case .directURL:
            return 20
        }
    }

    private func applySubtitleStyleIfNeeded(isRendererReady: Bool) {
        guard isRendererReady, !didApplySubtitleStyle else { return }
        let selector = NSSelectorFromString("setTextRendererFontSize:")
        guard player.responds(to: selector) else { return }
        didApplySubtitleStyle = true
        _ = player.perform(selector, with: NSNumber(value: 18))
    }

    private func addExternalSubtitleIfNeeded() {
        guard !didAddExternalSubtitle, let externalSubtitleURL else { return }
        didAddExternalSubtitle = true
        subtitleTrackIDsBeforeExternalAdd = Set(
            player.videoSubTitlesIndexes.compactMap(Self.subtitleTrackID)
        )
        let result = player.addPlaybackSlave(
            externalSubtitleURL,
            type: .subtitle,
            enforce: true
        )
        DiagnosticLogStore.shared.record(
            result == 0 ? .info : .warning,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.external_subtitle",
                details: ["result": "\(result)"]
        )
        if result == 0 {
            selectNewExternalSubtitleTrack(after: 0.35, remainingAttempts: 12)
        }
    }

    private func selectNewExternalSubtitleTrack(
        after delay: TimeInterval,
        remainingAttempts: Int
    ) {
        externalSubtitleSelectionWorkItem?.cancel()
        guard remainingAttempts > 0 else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, !self.didRequestStop else { return }
            let indexes = self.player.videoSubTitlesIndexes
                .compactMap(Self.subtitleTrackID)
                .filter { $0 >= 0 }
            let names = self.player.videoSubTitlesNames.compactMap { $0 as? String }
            let externalFilename = self.externalSubtitleURL?.lastPathComponent.lowercased() ?? ""
            let newIndexes = indexes.filter {
                !self.subtitleTrackIDsBeforeExternalAdd.contains($0)
            }
            var namedExternalIndex: Int32?
            for (ordinal, index) in indexes.enumerated() {
                if names.indices.contains(ordinal) {
                    let name = names[ordinal].lowercased()
                    if (!externalFilename.isEmpty && name.contains(externalFilename))
                        || name.contains("jellyfin.utf8")
                        || name.contains("nastart") {
                        namedExternalIndex = index
                    }
                }
            }
            let onlyTrackIsNew = self.subtitleTrackIDsBeforeExternalAdd.isEmpty
                && indexes.count == 1
            if let externalTrackID = namedExternalIndex
                ?? (onlyTrackIsNew ? indexes.first : newIndexes.last) {
                // When the media stream has not exposed its embedded subtitle
                // IDs before addPlaybackSlave, a transient inventory can make
                // every track look new. Do not select the last embedded track
                // until VLC identifies the added file by name, or until there
                // was a pre-existing inventory to compare against.
                guard !self.subtitleTrackIDsBeforeExternalAdd.isEmpty
                    || namedExternalIndex != nil
                    || onlyTrackIsNew else {
                    self.selectNewExternalSubtitleTrack(
                        after: 0.35,
                        remainingAttempts: remainingAttempts - 1
                    )
                    return
                }
                self.didApplyInitialSubtitleTrack = true
                self.desiredSubtitleTrackID = externalTrackID
                self.selectedSubtitleTrackID = externalTrackID
                self.player.currentVideoSubTitleIndex = externalTrackID
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.media",
                    messageKey: "diagnostics.media.external_subtitle",
                    details: [
                        "operation": "selectAddedTrack",
                        "trackID": "\(externalTrackID)",
                        "trackCount": "\(indexes.count)"
                    ]
                )
                self.syncState()
                return
            }
            self.selectNewExternalSubtitleTrack(
                after: 0.35,
                remainingAttempts: remainingAttempts - 1
            )
        }
        externalSubtitleSelectionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private static func subtitleTrackID(_ value: Any) -> Int32? {
        if let number = value as? NSNumber { return number.int32Value }
        if let value = value as? Int32 { return value }
        if let value = value as? Int { return Int32(clamping: value) }
        if let value = value as? String, let parsed = Int32(value) { return parsed }
        return nil
    }

    private static func stateDescription(_ state: VLCMediaPlayerState) -> String {
        switch state {
        case .stopped: return "stopped"
        case .opening: return "opening"
        case .buffering: return "buffering"
        case .ended: return "ended"
        case .error: return "error"
        case .playing: return "playing"
        case .paused: return "paused"
        case .esAdded: return "elementaryStreamAdded"
        @unknown default: return "unknown(\(state.rawValue))"
        }
    }

    deinit {
        pendingJumpWorkItem?.cancel()
        pendingTimeStateSyncWorkItem?.cancel()
        reconnectWorkItem?.cancel()
        externalSubtitleSelectionWorkItem?.cancel()
        player.stop()
    }
}

private struct VLCPlayerTrackOption: Identifiable {
    let id: Int32
    let name: String
}

private enum VLCPlayerPanel: String, Identifiable {
    case settings
    case audio
    case subtitles
    case quality

    var id: String { rawValue }
}

private enum VLCPlayerPanMode {
    case seeking
    case brightness
}

private struct CJKSubtitleCue {
    let start: Double
    let end: Double
    let text: String
}

private final class CJKSubtitleOverlayModel: ObservableObject {
    @Published private(set) var text: String?
    private var cues: [CJKSubtitleCue] = []
    private var loadTask: Task<Void, Never>?
    private var subtitleURL: URL?
    private var currentTime = 0.0

    deinit {
        loadTask?.cancel()
    }

    func setURL(_ url: URL?) {
        guard subtitleURL != url else { return }
        subtitleURL = url
        text = nil
        cues = []
        loadTask?.cancel()
        guard let url else { return }
        loadTask = Task { [weak self] in
            guard let self else { return }
            let loadedCues = await Self.loadCues(from: url)
            guard !Task.isCancelled else { return }
            cues = loadedCues
            applyCurrentTime()
        }
    }

    func update(time: Double) {
        currentTime = time
        applyCurrentTime()
    }

    private func applyCurrentTime() {
        guard !cues.isEmpty, currentTime.isFinite else {
            text = nil
            return
        }
        text = cues.first(where: { currentTime >= $0.start && currentTime < $0.end })?.text
    }

    private static func loadCues(from url: URL) async -> [CJKSubtitleCue] {
        await Task.detached(priority: .userInitiated) {
            guard let data = try? Data(contentsOf: url),
                  let value = decode(data) else { return [] }
            return parse(value)
        }.value
    }

    private static func decode(_ data: Data) -> String? {
        if data.starts(with: [0xFF, 0xFE]) {
            return String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        }
        if data.starts(with: [0xFE, 0xFF]) {
            return String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        }
        if data.starts(with: [0xEF, 0xBB, 0xBF]) {
            return String(data: data.dropFirst(3), encoding: .utf8)
        }
        return String(data: data, encoding: .utf8)
    }

    private static func parse(_ value: String) -> [CJKSubtitleCue] {
        value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n\n")
            .compactMap { block in
                let lines = block.components(separatedBy: "\n")
                guard let timeIndex = lines.firstIndex(where: { $0.contains("-->") }) else {
                    return nil
                }
                let times = lines[timeIndex].components(separatedBy: "-->")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard times.count == 2,
                      let start = timestamp(times[0]),
                      let end = timestamp(times[1]) else { return nil }
                let text = lines.dropFirst(timeIndex + 1)
                    .joined(separator: "\n")
                    .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"\{\\[^}]+\}"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return nil }
                return CJKSubtitleCue(start: start, end: max(end, start), text: text)
            }
            .sorted { $0.start < $1.start }
    }

    private static func timestamp(_ value: String) -> Double? {
        let parts = value.replacingOccurrences(of: ",", with: ".").split(separator: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else { return nil }
        return hours * 3_600 + minutes * 60 + seconds
    }
}

private struct CJKSubtitleOverlay: View {
    @ObservedObject var model: CJKSubtitleOverlayModel

    var body: some View {
        Group {
            if let text = model.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: 20, weight: .semibold, design: .default))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .shadow(color: .black, radius: 0, x: 1, y: 1)
                    .shadow(color: .black, radius: 3)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 5))
                    .frame(maxWidth: 720)
                    .accessibilityLabel(Text(text))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct VLCBuiltInPlayerView: View {
    let request: MediaPlaybackRequest
    let close: () -> Void
    let useSystemPlayer: ((MediaPlaybackRuntimeState, Bool) -> Void)?
    let compatibilityFailed: (MediaPlaybackRuntimeState) -> Void
    let sourceTrackChange: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)?
    let serverSeek: ((Double, MediaPlaybackRuntimeState) -> Void)?
    let qualityChange: ((String, MediaPlaybackRuntimeState) -> Void)?
    let openExternal: () -> Void
    @StateObject private var session: VLCMediaPlayerSession
    @State private var controlsVisible = true
    @State private var controlsLocked = false
    @State private var controlsRevision = 0
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false
    @State private var gestureStartPosition: Double?
    @State private var gestureTargetPosition: Double?
    @State private var panMode: VLCPlayerPanMode?
    @State private var brightnessGestureStart: CGFloat?
    @State private var displayBrightness: CGFloat
    @State private var brightnessHUDVisible = false
    @State private var brightnessHUDRevision = 0
    @State private var activePanel: VLCPlayerPanel?
    @State private var orientationMode: PlayerOrientationMode
    @State private var selectedSourceSubtitleTrackID: Int?
    @State private var showPiPUnavailableHint = false
    @StateObject private var subtitleOverlayModel: CJKSubtitleOverlayModel

    init(
        request: MediaPlaybackRequest,
        close: @escaping () -> Void,
        useSystemPlayer: ((MediaPlaybackRuntimeState, Bool) -> Void)?,
        compatibilityFailed: @escaping (MediaPlaybackRuntimeState) -> Void,
        sourceTrackChange: ((Int?, Int?, MediaPlaybackRuntimeState) -> Void)?,
        serverSeek: ((Double, MediaPlaybackRuntimeState) -> Void)?,
        qualityChange: ((String, MediaPlaybackRuntimeState) -> Void)?,
        openExternal: @escaping () -> Void
    ) {
        self.request = request
        self.close = close
        self.useSystemPlayer = useSystemPlayer
        self.compatibilityFailed = compatibilityFailed
        self.sourceTrackChange = sourceTrackChange
        self.serverSeek = serverSeek
        self.qualityChange = qualityChange
        self.openExternal = openExternal
        _session = StateObject(wrappedValue: VLCMediaPlayerSession(request: request))
        _orientationMode = State(initialValue: request.initialOrientationMode)
        _displayBrightness = State(initialValue: UIScreen.main.brightness)
        _selectedSourceSubtitleTrackID = State(
            initialValue: request.selectedSourceSubtitleTrackID
        )
        _subtitleOverlayModel = StateObject(
            wrappedValue: CJKSubtitleOverlayModel()
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let landscapeLayout = proxy.size.width > proxy.size.height

            ZStack {
                VLCPlayerSurface(session: session)
                    .ignoresSafeArea()

                if request.externalSubtitleURL != nil {
                    VStack {
                        Spacer()
                        CJKSubtitleOverlay(model: subtitleOverlayModel)
                            .padding(.horizontal, 24)
                            .padding(.bottom, landscapeLayout ? 72 : 118)
                    }
                }

                Color.clear
                    .contentShape(Rectangle())
                    .accessibilityElement()
                    .accessibilityLabel(Text("player.controls.toggle"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        toggleControls()
                    }
                    .onTapGesture {
                        toggleControls()
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 18)
                            .onChanged { value in
                                updatePlayerGesture(value, playerSize: proxy.size)
                            }
                            .onEnded { _ in
                                finishPlayerGesture()
                            }
                    )
                    .allowsHitTesting(!controlsLocked)

                if brightnessHUDVisible {
                    VStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.title2)
                        Text("\(Int((displayBrightness * 100).rounded()))%")
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 92, height: 82)
                    .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
                    .allowsHitTesting(false)
                    .transition(.opacity)
                }

                if controlsLocked {
                    HStack {
                        playerChromeButton(
                            systemImage: "lock.fill",
                            accessibilityKey: "player.controls.unlock"
                        ) {
                            controlsLocked = false
                            recordControlsLockChange(locked: false)
                            revealControls()
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .transition(.opacity)
                }

                if controlsVisible && !controlsLocked {
                    VStack(spacing: 0) {
                        topControls
                        Spacer()
                        playbackControls(isLandscape: landscapeLayout)
                    }
                    .transition(.opacity)
                }

                if let errorMessage = session.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text("player.load_failed")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                        if request.allowsExternalHandoff {
                            Button {
                                session.pauseForExternalHandoff()
                                openExternal()
                            } label: {
                                Label("devices.files.open_external", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        } else if let useSystemPlayer {
                            Button {
                                useSystemPlayer(
                                    session.runtimeState(orientationMode: orientationMode),
                                    false
                                )
                            } label: {
                                Label("player.engine.system", systemImage: "play.rectangle")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(AppTheme.accent)
                        } else {
                            Text(LocalizedStringKey(request.source == .jellyfin
                                ? "jellyfin.player.retry_hint"
                                : "dsm.player.retry_hint"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("action.done", action: close)
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.accent)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(22)
                } else if session.isBuffering && !session.hasStartedPlayback {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                }

                if let activePanel, session.errorMessage == nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            playerPanel(activePanel, isLandscape: landscapeLayout)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, landscapeLayout ? 56 : 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

            }
        }
        .onAppear {
            displayBrightness = UIScreen.main.brightness
            subtitleOverlayModel.setURL(request.externalSubtitleURL)
            session.play()
            revealControls()
        }
        .onDisappear {
            session.stop()
        }
        .onChange(of: session.position) { position in
            guard !isScrubbing else { return }
            scrubPosition = position
        }
        .onChange(of: session.currentTimeSeconds) { seconds in
            subtitleOverlayModel.update(time: seconds)
        }
        .onChange(of: session.isPlaying) { isPlaying in
            if isPlaying {
                revealControls()
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    controlsVisible = true
                }
            }
        }
        .onChange(of: session.errorMessage) { errorMessage in
            if errorMessage != nil {
                compatibilityFailed(session.runtimeState(orientationMode: orientationMode))
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: session.initialLoadTimeoutNanoseconds)
            guard !Task.isCancelled else { return }
            let grace = session.initialLoadGraceNanosecondsIfNeeded()
            if grace > 0 {
                try? await Task.sleep(nanoseconds: grace)
                guard !Task.isCancelled else { return }
            }
            session.failIfStillLoading()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                session.recoverIfStalled()
            }
        }
        .task(id: controlsRevision) {
            guard controlsVisible, session.isPlaying, activePanel == nil else { return }
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled, session.isPlaying, activePanel == nil else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                controlsVisible = false
            }
        }
        .task(id: brightnessHUDRevision) {
            guard brightnessHUDVisible, panMode == nil else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, panMode == nil else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                brightnessHUDVisible = false
            }
        }
        .alert("player.picture_in_picture", isPresented: $showPiPUnavailableHint) {
            Button("action.done", role: .cancel) {}
        } message: {
            Text("player.picture_in_picture_unavailable")
        }
    }

    private var topControls: some View {
        HStack(spacing: 12) {
            playerChromeButton(
                systemImage: "xmark",
                accessibilityKey: "action.done",
                action: close
            )

            Text(request.title.isEmpty ? NSLocalizedString("player.title", comment: "") : request.title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            playerChromeButton(
                systemImage: session.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                accessibilityKey: session.isMuted ? "player.unmute" : "player.mute"
            ) {
                session.toggleMute()
                revealControls()
            }

            playerChromeButton(
                systemImage: "lock.open",
                accessibilityKey: "player.controls.lock"
            ) {
                activePanel = nil
                controlsLocked = true
                controlsVisible = false
                recordControlsLockChange(locked: true)
            }

            Button {
                presentPanel(.settings)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.46), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("player.more_controls"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [.black.opacity(0.76), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)
        )
    }

    private func playbackControls(isLandscape: Bool) -> some View {
        VStack(spacing: isLandscape ? 6 : 10) {
            HStack(spacing: 10) {
                Text(session.currentTimeText)
                Slider(
                    value: $scrubPosition,
                    in: 0...1,
                    onEditingChanged: { editing in
                        isScrubbing = editing
                        if !editing {
                            commitSeek(to: scrubPosition)
                        }
                        revealControls()
                    }
                )
                .disabled(!canSeek)
                .tint(AppTheme.accent)
                Text(session.durationText)
            }
            .font(.caption.monospacedDigit())

            HStack(spacing: isLandscape ? 24 : 8) {
                controlButton(
                    systemImage: "gobackward.15",
                    accessibilityKey: "player.seek_backward"
                ) {
                    jump(by: -15)
                    revealControls()
                }

                controlButton(
                    systemImage: session.isPlaying ? "pause.fill" : "play.fill",
                    accessibilityKey: session.isPlaying ? "player.pause" : "player.play",
                    emphasized: true
                ) {
                    session.togglePlayback()
                    revealControls()
                }

                controlButton(
                    systemImage: "goforward.15",
                    accessibilityKey: "player.seek_forward"
                ) {
                    jump(by: 15)
                    revealControls()
                }

                Spacer(minLength: 4)

                Button {
                    presentPanel(.audio)
                } label: {
                    Image(systemName: "waveform")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(availableAudioTrackCount <= 1)
                .accessibilityLabel(Text("player.audio_tracks"))

                Button {
                    presentPanel(.subtitles)
                } label: {
                    Image(systemName: hasSelectedSubtitle ? "captions.bubble.fill" : "captions.bubble")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(availableSubtitleTrackCount == 0)
                .accessibilityLabel(Text("player.subtitles"))

                if qualityChange != nil, !request.qualityOptions.isEmpty {
                    Button {
                        presentPanel(.quality)
                    } label: {
                        Image(systemName: "4k.tv")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("player.quality"))
                }

                if showsPictureInPictureControl {
                    Button {
                        if let useSystemPlayer {
                            useSystemPlayer(
                                session.runtimeState(orientationMode: orientationMode),
                                true
                            )
                        } else {
                            showPiPUnavailableHint = true
                        }
                    } label: {
                        Image(systemName: "pip.enter")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(useSystemPlayer == nil ? .white.opacity(0.45) : .white)
                    .accessibilityLabel(Text("player.picture_in_picture"))
                }

                controlButton(
                    systemImage: isLandscape
                        ? "arrow.down.right.and.arrow.up.left"
                        : "arrow.up.left.and.arrow.down.right",
                    accessibilityKey: isLandscape ? "player.exit_fullscreen" : "player.fullscreen"
                ) {
                    let mode: PlayerOrientationMode = isLandscape ? .portrait : .landscape
                    orientationMode = mode
                    PlayerOrientationController.applyPlayerOrientationMode(mode)
                    revealControls()
                }
            }
            .font(.title3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isLandscape ? 28 : 18)
        .padding(.top, isLandscape ? 24 : 34)
        .padding(.bottom, isLandscape ? 8 : 14)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private func playerPanel(
        _ panel: VLCPlayerPanel,
        isLandscape: Bool
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: panelSystemImage(panel))
                    .foregroundStyle(.secondary)
                Text(panelTitle(panel))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    dismissPanel()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action.cancel"))
            }
            .padding(.leading, 16)
            .padding(.trailing, 8)
            .frame(height: 48)

            Divider()

            panelContent(panel)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: isLandscape ? 360 : 420)
        .frame(maxHeight: isLandscape ? 270 : 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .environment(\.colorScheme, .dark)
    }

    @ViewBuilder
    private func panelContent(_ panel: VLCPlayerPanel) -> some View {
        switch panel {
        case .settings:
            settingsPanel
        case .audio:
            if let sourceTrackChange {
                trackList(
                    tracks: request.sourceAudioTracks.map {
                        VLCPlayerTrackOption(id: Int32(clamping: $0.id), name: $0.name)
                    },
                    selectedID: Int32(clamping: request.selectedSourceAudioTrackID ?? -1)
                ) { id in
                    sourceTrackChange(
                        Int(id),
                        selectedSourceSubtitleTrackID,
                        session.runtimeState(orientationMode: orientationMode)
                    )
                    dismissPanel()
                }
            } else {
                trackList(
                    tracks: session.audioTracks.map {
                        VLCPlayerTrackOption(id: $0.id, name: $0.name)
                    },
                    selectedID: session.selectedAudioTrackID
                ) { id in
                    guard let track = session.audioTracks.first(where: { $0.id == id }) else { return }
                    session.selectAudio(track)
                    dismissPanel()
                }
            }
        case .subtitles:
            if let sourceTrackChange {
                trackList(
                    tracks: [VLCPlayerTrackOption(
                        id: -1,
                        name: NSLocalizedString("player.subtitles.off", comment: "")
                    )] + request.sourceSubtitleTracks.map {
                        VLCPlayerTrackOption(id: Int32(clamping: $0.id), name: $0.name)
                    },
                    selectedID: Int32(clamping: selectedSourceSubtitleTrackID ?? -1)
                ) { id in
                    let sourceID = id < 0 ? nil : Int(id)
                    let sourceTrack = sourceID.flatMap { selectedID in
                        request.sourceSubtitleTracks.first { $0.id == selectedID }
                    }
                    if sourceID == nil || sourceTrack?.externalURL != nil {
                        subtitleOverlayModel.setURL(sourceTrack?.externalURL)
                        if session.selectExternalSubtitle(sourceTrack?.externalURL) {
                            selectedSourceSubtitleTrackID = sourceID
                        }
                    } else {
                        subtitleOverlayModel.setURL(nil)
                        sourceTrackChange(
                            request.selectedSourceAudioTrackID,
                            sourceID,
                            session.runtimeState(orientationMode: orientationMode)
                        )
                    }
                    dismissPanel()
                }
            } else {
                trackList(
                    tracks: session.subtitleTracks.map {
                        VLCPlayerTrackOption(id: $0.id, name: $0.name)
                    },
                    selectedID: session.selectedSubtitleTrackID
                ) { id in
                    guard let track = session.subtitleTracks.first(where: { $0.id == id }) else { return }
                    session.selectSubtitle(track)
                    dismissPanel()
                }
            }
        case .quality:
            qualityList
        }
    }

    private var qualityList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(request.qualityOptions) { option in
                    Button {
                        qualityChange?(
                            option.id,
                            session.runtimeState(orientationMode: orientationMode)
                        )
                        dismissPanel()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: request.selectedQualityID == option.id
                                  ? "checkmark.circle.fill"
                                  : "circle")
                                .foregroundStyle(request.selectedQualityID == option.id
                                                 ? AppTheme.accent
                                                 : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.subheadline)
                                if let detail = option.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 50)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if option.id != request.qualityOptions.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private var availableAudioTrackCount: Int {
        sourceTrackChange == nil ? session.audioTracks.count : request.sourceAudioTracks.count
    }

    private var showsPictureInPictureControl: Bool {
        useSystemPlayer != nil
    }

    private func recordControlsLockChange(locked: Bool) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.controls_lock_changed",
            details: ["locked": locked ? "yes" : "no"]
        )
    }

    private var availableSubtitleTrackCount: Int {
        sourceTrackChange == nil
            ? max(session.subtitleTracks.count - 1, 0)
            : request.sourceSubtitleTracks.count
    }

    private var hasSelectedSubtitle: Bool {
        sourceTrackChange == nil
            ? session.selectedSubtitleTrackID >= 0
            : selectedSourceSubtitleTrackID != nil
    }

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("player.speed")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(playbackRates, id: \.self) { rate in
                            Button(playbackRateLabel(rate)) {
                                session.setPlaybackRate(rate)
                                revealControls()
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(
                                abs(session.playbackRate - rate) < 0.01
                                    ? AppTheme.accent
                                    : Color.white.opacity(0.1),
                                in: RoundedRectangle(cornerRadius: 6)
                            )
                        }
                    }
                }

                Text("player.orientation")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 0) {
                    ForEach(PlayerOrientationMode.allCases) { mode in
                        Button {
                            orientationMode = mode
                            PlayerOrientationController.applyPlayerOrientationMode(mode)
                            DiagnosticLogStore.shared.record(
                                .info,
                                categoryKey: "diagnostics.category.media",
                                messageKey: "diagnostics.media.orientation_changed",
                                details: ["mode": mode.rawValue]
                            )
                            revealControls()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: mode.systemImage)
                                Text(mode.localizationKey)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(
                                orientationMode == mode
                                    ? Color.white.opacity(0.18)
                                    : Color.clear
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if showsPictureInPictureControl || request.allowsExternalHandoff {
                    Divider()
                }

                if showsPictureInPictureControl {
                    panelCommand(
                        titleKey: "player.picture_in_picture",
                        systemImage: "pip.enter"
                    ) {
                        dismissPanel()
                        if let useSystemPlayer {
                            useSystemPlayer(
                                session.runtimeState(orientationMode: orientationMode),
                                true
                            )
                        } else {
                            showPiPUnavailableHint = true
                        }
                    }
                }

                if request.allowsExternalHandoff {
                    panelCommand(
                        titleKey: "devices.files.open_external",
                        systemImage: "arrow.up.forward.app"
                    ) {
                        dismissPanel()
                        session.pauseForExternalHandoff()
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            openExternal()
                        }
                    }
                }
            }
            .padding(16)
        }
    }

    private func trackList(
        tracks: [VLCPlayerTrackOption],
        selectedID: Int32,
        select: @escaping (Int32) -> Void
    ) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks, id: \.id) { track in
                    Button {
                        select(track.id)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: selectedID == track.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedID == track.id ? AppTheme.accent : .secondary)
                            Text(track.name)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .lineLimit(2)
                            Spacer(minLength: 8)
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 46)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if track.id != tracks.last?.id {
                        Divider().padding(.leading, 44)
                    }
                }
            }
        }
    }

    private func panelCommand(
        titleKey: LocalizedStringKey,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(titleKey, systemImage: systemImage)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 38)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func panelTitle(_ panel: VLCPlayerPanel) -> LocalizedStringKey {
        switch panel {
        case .settings: return "player.more_controls"
        case .audio: return "player.audio_tracks"
        case .subtitles: return "player.subtitles"
        case .quality: return "player.quality"
        }
    }

    private func panelSystemImage(_ panel: VLCPlayerPanel) -> String {
        switch panel {
        case .settings: return "gearshape"
        case .audio: return "waveform"
        case .subtitles: return "captions.bubble"
        case .quality: return "4k.tv"
        }
    }

    private func controlButton(
        systemImage: String,
        accessibilityKey: String,
        emphasized: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(emphasized ? .title2 : .title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityKey)))
    }

    private func playerChromeButton(
        systemImage: String,
        accessibilityKey: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.46), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityKey)))
    }

    private func toggleControls() {
        if activePanel != nil {
            dismissPanel()
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
        }
        if controlsVisible {
            controlsRevision += 1
        }
    }

    private func presentPanel(_ panel: VLCPlayerPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
            activePanel = activePanel == panel ? nil : panel
        }
        controlsRevision += 1
    }

    private func dismissPanel() {
        withAnimation(.easeInOut(duration: 0.2)) {
            activePanel = nil
            controlsVisible = true
        }
        controlsRevision += 1
    }

    private var playbackRates: [Float] {
        [0.5, 0.75, 1, 1.25, 1.5, 2]
    }

    private func playbackRateLabel(_ rate: Float) -> String {
        switch rate {
        case 0.5: return "0.5x"
        case 0.75: return "0.75x"
        case 1: return "1x"
        case 1.25: return "1.25x"
        case 1.5: return "1.5x"
        case 2: return "2x"
        default: return "\(rate)x"
        }
    }

    private func updatePlayerGesture(_ value: DragGesture.Value, playerSize: CGSize) {
        guard activePanel == nil, session.errorMessage == nil else { return }
        if panMode == nil {
            let horizontalDistance = abs(value.translation.width)
            let verticalDistance = abs(value.translation.height)
            if horizontalDistance > verticalDistance * 1.2 {
                panMode = .seeking
            } else if verticalDistance > horizontalDistance * 1.2 {
                panMode = .brightness
                brightnessGestureStart = UIScreen.main.brightness
                displayBrightness = UIScreen.main.brightness
                withAnimation(.easeInOut(duration: 0.15)) {
                    brightnessHUDVisible = true
                }
            } else {
                return
            }
        }

        switch panMode {
        case .seeking:
            updateSeekGesture(value, playerWidth: playerSize.width)
        case .brightness:
            updateBrightnessGesture(value, playerHeight: playerSize.height)
        case nil:
            break
        }
    }

    private func finishPlayerGesture() {
        let completedMode = panMode
        panMode = nil
        switch completedMode {
        case .seeking:
            finishSeekGesture()
        case .brightness:
            brightnessGestureStart = nil
            brightnessHUDRevision += 1
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.brightness_changed",
                details: [
                    "percent": "\(Int((displayBrightness * 100).rounded()))"
                ]
            )
        case nil:
            break
        }
    }

    private func updateSeekGesture(_ value: DragGesture.Value, playerWidth: CGFloat) {
        guard
            canSeek,
            session.durationSeconds > 0,
            playerWidth > 0
        else {
            return
        }
        let startPosition = gestureStartPosition ?? session.position
        gestureStartPosition = startPosition
        let secondsPerPoint = min(max(session.durationSeconds / 7_200, 0.35), 1.2)
        let rawOffset = Double(value.translation.width) * secondsPerPoint
        let boundedOffset = min(max(rawOffset, -300), 300)
        let targetPosition = min(
            max(startPosition + boundedOffset / session.durationSeconds, 0),
            1
        )
        gestureTargetPosition = targetPosition
        controlsVisible = true
        controlsRevision += 1
    }

    private func finishSeekGesture() {
        defer { gestureStartPosition = nil }
        guard let targetPosition = gestureTargetPosition else { return }
        commitSeek(to: targetPosition)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        revealControls()
        gestureTargetPosition = nil
    }

    private var canSeek: Bool {
        session.isSeekable || (serverSeek != nil && session.durationSeconds > 0)
    }

    private func commitSeek(to normalizedPosition: Double) {
        let position = min(max(normalizedPosition, 0), 1)
        let targetSeconds = session.durationSeconds * position
        if serverSeek != nil, session.seek(toAbsoluteSeconds: targetSeconds) {
            return
        }
        guard let serverSeek else {
            session.seek(to: position)
            return
        }
        serverSeek(
            targetSeconds,
            session.runtimeState(orientationMode: orientationMode)
        )
    }

    private func jump(by seconds: Int) {
        let targetSeconds = min(
            max(session.currentTimeSeconds + Double(seconds), 0),
            session.durationSeconds
        )
        if serverSeek != nil, session.seek(toAbsoluteSeconds: targetSeconds) {
            return
        }
        guard let serverSeek else {
            session.jump(by: seconds)
            return
        }
        serverSeek(
            targetSeconds,
            session.runtimeState(orientationMode: orientationMode)
        )
    }

    private func updateBrightnessGesture(_ value: DragGesture.Value, playerHeight: CGFloat) {
        guard playerHeight > 0 else { return }
        let startBrightness = brightnessGestureStart ?? UIScreen.main.brightness
        brightnessGestureStart = startBrightness
        let dragRange = max(playerHeight * 0.7, 180)
        let targetBrightness = min(
            max(startBrightness - value.translation.height / dragRange, 0),
            1
        )
        displayBrightness = targetBrightness
        UIScreen.main.brightness = targetBrightness
        brightnessHUDVisible = true
        brightnessHUDRevision += 1
    }

    private func revealControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible = true
        }
        controlsRevision += 1
    }
}

private struct VLCPlayerSurface: UIViewRepresentable {
    let session: VLCMediaPlayerSession

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        session.attach(to: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        session.attach(to: view)
    }

    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) {
        coordinator.session?.detach(from: view)
    }

    final class Coordinator {
        weak var session: VLCMediaPlayerSession?

        init(session: VLCMediaPlayerSession) {
            self.session = session
        }
    }
}
#endif

private struct SystemPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    let startPictureInPicture: Bool
    let onSeekCommitted: () -> Void
    let onPictureInPictureEvent: (String, Error?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        context.coordinator.installGesture(on: controller)
        context.coordinator.installPictureInPicture(on: controller)
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        context.coordinator.parent = self
        if controller.player !== player {
            controller.player = player
        }
        // The representable can be created before AVPlayerViewController has
        // its final bounds.  A zero-sized auxiliary layer is still eligible
        // for PiP, so AVPictureInPictureController may report success while
        // capturing a black frame. Keep the PiP source layer in sync with the
        // actual controller bounds on every SwiftUI update.
        controller.view.layoutIfNeeded()
        context.coordinator.updatePictureInPictureLayerFrame(
            controller.view.bounds,
            player: player
        )
        context.coordinator.updatePictureInPictureRequest(startPictureInPicture)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, AVPictureInPictureControllerDelegate {
        var parent: SystemPlayerController
        private weak var controller: AVPlayerViewController?
        private var gestureStartSeconds: Double?
        private var gestureTargetSeconds: Double?
        private var wasPlaying = false
        private var pictureInPictureController: AVPictureInPictureController?
        private var pictureInPictureLayer: AVPlayerLayer?
        private var pictureInPictureStartWorkItem: DispatchWorkItem?
        private var pictureInPictureStartRequested = false

        init(parent: SystemPlayerController) {
            self.parent = parent
        }

        func installGesture(on controller: AVPlayerViewController) {
            self.controller = controller
            let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            gesture.maximumNumberOfTouches = 1
            gesture.cancelsTouchesInView = false
            gesture.delegate = self
            controller.view.addGestureRecognizer(gesture)
        }

        func installPictureInPicture(on controller: AVPlayerViewController) {
            let layer = AVPlayerLayer(player: parent.player)
            layer.videoGravity = .resizeAspect
            // Keep this as a real rendered layer. A transparent auxiliary
            // layer can make AVPictureInPictureController report a successful
            // transition while capturing a black frame on iPadOS.
            layer.opacity = 1
            layer.frame = controller.view.bounds
            controller.view.layer.insertSublayer(layer, at: 0)
            pictureInPictureLayer = layer

            guard AVPictureInPictureController.isPictureInPictureSupported() else {
                return
            }
            guard let pictureInPictureController = AVPictureInPictureController(playerLayer: layer) else {
                return
            }
            pictureInPictureController.delegate = self
            self.pictureInPictureController = pictureInPictureController
            updatePictureInPictureRequest(parent.startPictureInPicture)
        }

        func updatePictureInPictureLayerFrame(_ frame: CGRect, player: AVPlayer) {
            pictureInPictureLayer?.player = player
            guard frame.width > 0, frame.height > 0 else { return }
            pictureInPictureLayer?.frame = frame
        }

        func updatePictureInPictureRequest(_ requested: Bool) {
            guard requested else { return }
            guard let pictureInPictureController,
                  !pictureInPictureController.isPictureInPictureActive,
                  !pictureInPictureStartRequested else {
                return
            }
            pictureInPictureStartRequested = true
            attemptPictureInPictureStart(controller: pictureInPictureController, remainingAttempts: 40)
        }

        private func attemptPictureInPictureStart(
            controller: AVPictureInPictureController,
            remainingAttempts: Int
        ) {
            guard remainingAttempts > 0,
                  !controller.isPictureInPictureActive else {
                pictureInPictureStartRequested = false
                return
            }
            let ready = parent.player.currentItem?.status == .readyToPlay
                && (parent.player.currentItem?.presentationSize.width ?? 0) > 0
                && (parent.player.currentItem?.presentationSize.height ?? 0) > 0
                && pictureInPictureLayer?.isReadyForDisplay == true
                && (pictureInPictureLayer?.bounds.width ?? 0) > 0
                && (pictureInPictureLayer?.bounds.height ?? 0) > 0
            if ready, controller.isPictureInPicturePossible {
                parent.onPictureInPictureEvent("willStart", nil)
                controller.startPictureInPicture()
                return
            }
            pictureInPictureStartWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self, weak controller] in
                guard let self, let controller else { return }
                self.attemptPictureInPictureStart(
                    controller: controller,
                    remainingAttempts: remainingAttempts - 1
                )
            }
            pictureInPictureStartWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard
                let pan = gestureRecognizer as? UIPanGestureRecognizer,
                let view = pan.view,
                playbackDuration > 0
            else {
                return false
            }
            let velocity = pan.velocity(in: view)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldReceive touch: UITouch
        ) -> Bool {
            var view = touch.view
            while let currentView = view, currentView !== controller?.view {
                if currentView is UIControl { return false }
                view = currentView.superview
            }
            return true
        }

        @objc
        private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view else { return }
            let duration = playbackDuration
            guard duration > 0 else { return }

            switch gesture.state {
            case .began:
                let currentSeconds = parent.player.currentTime().seconds
                gestureStartSeconds = currentSeconds.isFinite ? max(currentSeconds, 0) : 0
                gestureTargetSeconds = gestureStartSeconds
                wasPlaying = parent.player.timeControlStatus == .playing
            case .changed:
                guard let startSeconds = gestureStartSeconds else { return }
                let translation = gesture.translation(in: view)
                guard abs(translation.x) > abs(translation.y) * 1.2 else { return }
                let secondsPerPoint = min(max(duration / 7_200, 0.35), 1.2)
                let offset = min(max(Double(translation.x) * secondsPerPoint, -300), 300)
                let target = min(max(startSeconds + offset, 0), duration)
                gestureTargetSeconds = target
            case .ended:
                commitSeek()
            case .cancelled, .failed:
                gestureStartSeconds = nil
                gestureTargetSeconds = nil
            default:
                break
            }
        }

        private func commitSeek() {
            defer {
                gestureStartSeconds = nil
                gestureTargetSeconds = nil
            }
            guard
                let startSeconds = gestureStartSeconds,
                let targetSeconds = gestureTargetSeconds,
                abs(targetSeconds - startSeconds) >= 0.5
            else {
                return
            }
            let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)
            parent.player.seek(
                to: targetTime,
                toleranceBefore: CMTime(seconds: 0.25, preferredTimescale: 600),
                toleranceAfter: CMTime(seconds: 0.25, preferredTimescale: 600)
            ) { [weak self] _ in
                guard let self, self.wasPlaying else { return }
                self.parent.player.play()
            }
            parent.onSeekCommitted()
        }

        private var playbackDuration: Double {
            guard let item = parent.player.currentItem else { return 0 }
            let seconds = item.duration.seconds
            guard seconds.isFinite, seconds > 0 else { return 0 }
            return seconds
        }

        func pictureInPictureControllerWillStartPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            parent.onPictureInPictureEvent("willStart", nil)
        }

        func pictureInPictureControllerDidStartPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            pictureInPictureStartRequested = false
            parent.onPictureInPictureEvent("didStart", nil)
        }

        func pictureInPictureController(
            _ pictureInPictureController: AVPictureInPictureController,
            failedToStartPictureInPictureWithError error: Error
        ) {
            pictureInPictureStartRequested = false
            parent.onPictureInPictureEvent("failed", error)
        }

        func pictureInPictureControllerWillStopPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            parent.onPictureInPictureEvent("willStop", nil)
        }

        func pictureInPictureControllerDidStopPictureInPicture(
            _ pictureInPictureController: AVPictureInPictureController
        ) {
            pictureInPictureStartRequested = false
            parent.onPictureInPictureEvent("didStop", nil)
        }

        func pictureInPictureController(
            _ pictureInPictureController: AVPictureInPictureController,
            restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
        ) {
            parent.onPictureInPictureEvent("restore", nil)
            completionHandler(true)
        }
    }
}

private enum JellyfinEntryKind: String {
    case library
    case movie
    case series
    case episode
    case audio
    case video
    case unknown
}

private struct JellyfinMediaTrack: Identifiable, Hashable {
    let index: Int
    let title: String
    let codec: String?
    let isDefault: Bool
    let isForced: Bool

    var id: Int { index }
}

private struct JellyfinPlaybackSelection: Equatable {
    let audioStreamIndex: Int?
    let subtitleStreamIndex: Int?
}

private struct JellyfinPreparedPlayback {
    let resource: MediaPlaybackResource
    let externalHandoffResource: MediaPlaybackResource
    let playSessionID: String?
    let mediaSourceID: String?
    let playMethod: PlayMethod
    let mode: String
    let isPrivateNetworkRoute: Bool
    let allowsSelfSignedCertificates: Bool
}

private struct JellyfinDirectPlaybackRoute {
    let url: URL
    let handoffURL: URL
    let source: String
    let allowsSelfSignedCertificates: Bool
    let isPrivateNetworkRoute: Bool
}

private struct JellyfinPlaybackBitrateDecision {
    let maximumBitrate: Int
    let directPlayMaximumBitrate: Int
    let isPrivateRoute: Bool
    let basis: String
    let networkKey: String
}

private struct JellyfinPersonEntry: Identifiable, Hashable {
    let id: String
    let imageItemID: String?
    let name: String
    let role: String?
    let type: String?
    let imageTag: String?
}

private struct JellyfinExternalLink: Identifiable, Hashable {
    let name: String
    let url: URL

    var id: String { url.absoluteString }
}

private struct JellyfinMediaEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let overview: String
    let kind: JellyfinEntryKind
    let collectionType: String?
    let imageItemID: String
    let imageTag: String?
    let thumbImageTag: String?
    let backdropImageTag: String?
    let container: String?
    let mediaSourceID: String?
    let defaultAudioStreamIndex: Int?
    let preferredSubtitleStreamIndex: Int?
    let preferredSubtitleCodec: String?
    let audioTracks: [JellyfinMediaTrack]
    let subtitleTracks: [JellyfinMediaTrack]
    let progress: Double?
    let playbackPositionTicks: Int?
    let runTimeTicks: Int?
    let seasonNumber: Int?
    let episodeNumber: Int?
    let isFavorite: Bool
    let genres: [String]
    let communityRating: Double?
    let officialRating: String?
    let videoDescription: String?
    let audioDescription: String?
    let originalTitle: String?
    let tagline: String?
    let productionYear: Int?
    let premiereDate: Date?
    let people: [JellyfinPersonEntry]
    let studios: [String]
    let externalLinks: [JellyfinExternalLink]
    let mediaPath: String?
    let mediaSize: Int?
    let mediaBitrate: Int?

    var isPlayable: Bool {
        [.movie, .episode, .audio, .video].contains(kind)
    }
}

private final class JellyfinCertificateTrustDelegate: NSObject, URLSessionDelegate {
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
            completionHandler(.performDefaultHandling, nil)
            return
        }
        completionHandler(.useCredential, credential)
    }
}

/// Jellyfin can expose an ASS/SSA subtitle as an SRT endpoint, but the
/// returned bytes may still carry legacy Chinese encoding or styling that
/// MobileVLCKit renders as tofu on iOS.  Normalize only the problematic text
/// codecs to a local UTF-8 SRT; image subtitles and ordinary SRT tracks keep
/// their original path.
private enum JellyfinSubtitleNormalizer {
    private static let maximumSubtitleBytes = 16 * 1024 * 1024

    static func normalize(
        url: URL,
        sourceCodec: String?,
        allowsSelfSignedCertificates: Bool
    ) async -> URL? {
        let codec = sourceCodec?.lowercased()
        guard codec == "ass" || codec == "ssa" else { return nil }

        let delegate = JellyfinCertificateTrustDelegate(
            trustedHost: url.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
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

        var request = URLRequest(url: url)
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode),
                  data.count <= maximumSubtitleBytes,
                  let decoded = decode(data),
                  let normalized = normalizeToSRT(decoded),
                  !normalized.isEmpty else {
                return nil
            }
            let cacheDirectory = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("Nastart/Subtitles", isDirectory: true)
            try FileManager.default.createDirectory(
                at: cacheDirectory,
                withIntermediateDirectories: true
            )
            let outputURL = cacheDirectory.appendingPathComponent(
                "\(UUID().uuidString).jellyfin.utf8.srt"
            )
            guard let outputData = normalized.data(using: .utf8) else { return nil }
            try outputData.write(to: outputURL, options: .atomic)
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.subtitle_normalized",
                details: [
                    "source": DiagnosticLogStore.redactedURL(url),
                    "sourceCodec": codec ?? "-",
                    "encoding": detectedEncoding(data),
                    "bytes": "\(data.count)",
                    "format": "utf8-srt",
                    "convertedASS": decoded.lowercased().contains("[events]") ? "yes" : "no"
                ]
            )
            return outputURL
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
        if let utf8 = String(data: data, encoding: .utf8) { return utf8 }
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

    private static func normalizeToSRT(_ value: String) -> String? {
        let normalized = value
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.contains("-->") {
            // Jellyfin's ASS endpoint can return an SRT-shaped document while
            // retaining ASS override tags such as {\\blur3}. Strip those
            // tags even on the SRT-shaped path; otherwise VLC treats them as
            // literal subtitle text and CJK rendering falls back to tofu.
            return normalized
                .components(separatedBy: "\n")
                .map { assTextToPlainText($0) }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
        }

        let lines = normalized.components(separatedBy: "\n")
        let formatLine = lines.first {
            $0.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("format:")
        }
        let formatFields = formatLine.map {
            String($0.drop { $0 != ":" }.dropFirst())
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        } ?? []
        guard let startIndex = formatFields.firstIndex(of: "start"),
              let endIndex = formatFields.firstIndex(of: "end"),
              let textIndex = formatFields.firstIndex(of: "text") else {
            return nil
        }

        var cues: [(start: String, end: String, text: String)] = []
        for line in lines {
            guard line.lowercased().hasPrefix("dialogue:") else { continue }
            let payload = String(line.drop { $0 != ":" }.dropFirst())
            let fields = payload.split(separator: ",", maxSplits: max(formatFields.count - 1, 0))
                .map(String.init)
            guard fields.indices.contains(startIndex),
                  fields.indices.contains(endIndex),
                  fields.indices.contains(textIndex),
                  let start = assTimestamp(fields[startIndex]),
                  let end = assTimestamp(fields[endIndex]) else { continue }
            let text = assTextToPlainText(fields[textIndex])
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            cues.append((start, end, text))
        }
        guard !cues.isEmpty else { return nil }
        return cues.enumerated().map { index, cue in
            "\(index + 1)\n\(cue.start) --> \(cue.end)\n\(cue.text)"
        }.joined(separator: "\n\n") + "\n"
    }

    private static func assTimestamp(_ value: String) -> String? {
        let fields = value.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard fields.count == 3,
              let hours = Int(fields[0]),
              let minutes = Int(fields[1]) else { return nil }
        let secondParts = fields[2].split(separator: ".", maxSplits: 1).map(String.init)
        guard let seconds = Int(secondParts[0]), seconds < 60 else { return nil }
        let centiseconds = secondParts.count > 1
            ? Int(String(secondParts[1].prefix(2)).padding(toLength: 2, withPad: "0", startingAt: 0)) ?? 0
            : 0
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, centiseconds * 10)
    }

    private static func assTextToPlainText(_ value: String) -> String {
        var text = value
        while let start = text.firstIndex(of: "{") {
            guard let end = text[start...].firstIndex(of: "}") else { break }
            text.removeSubrange(start...end)
        }
        return text
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\h", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor
private final class JellyfinLibraryStore: ObservableObject {
    @Published private(set) var endpoint: URL
    let playbackEndpoint: URL?
    let allowsSelfSignedCertificates: Bool

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published private(set) var username = ""
    @Published private(set) var libraries: [JellyfinMediaEntry] = []
    @Published private(set) var continueWatching: [JellyfinMediaEntry] = []
    @Published private(set) var movies: [JellyfinMediaEntry] = []
    @Published private(set) var series: [JellyfinMediaEntry] = []
    @Published private(set) var recentlyAdded: [JellyfinMediaEntry] = []
    @Published private(set) var favorites: [JellyfinMediaEntry] = []
    @Published private(set) var favoriteItemIDs: Set<String> = []
    @Published var errorMessage: String?

    private var client: JellyfinClient?
    private var userID: String?
    private var didRestore = false
    private var trustDelegate: JellyfinCertificateTrustDelegate?
    private let endpointCandidates: [URL]
    private var bitrateMeasurements: [String: (bitrate: Int, rawBitrate: Int, measuredAt: Date)] = [:]
    private var bitrateMeasurementTasks: [String: Task<Void, Never>] = [:]
    private var resolvedPlaybackRouteIsPrivate: Bool?
    private var dsmSession: DSMSession?
    private var dsmSharedFolderPaths: [String]
    private var unavailableDSMPlaybackPaths: [String: Date] = [:]

    init(
        endpoint: URL,
        playbackEndpoint: URL?,
        allowsSelfSignedCertificates: Bool,
        dsmSession: DSMSession? = nil,
        dsmSharedFolderPaths: [String] = [],
        fallbackEndpoints: [URL] = []
    ) {
        self.endpoint = endpoint
        self.playbackEndpoint = playbackEndpoint.flatMap(Self.originURL)
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.dsmSession = dsmSession
        self.dsmSharedFolderPaths = dsmSharedFolderPaths
        self.endpointCandidates = Self.jellyfinEndpointCandidates(
            from: [endpoint] + fallbackEndpoints
        )
        Task { @MainActor [weak self] in
            await self?.refreshPlaybackRouteClassification()
        }
    }

    func updateDSMPlaybackContext(
        session: DSMSession?,
        sharedFolderPaths: [String]
    ) {
        let normalizedSharedFolderPaths = Array(Set(sharedFolderPaths)).sorted()
        guard dsmSession?.sid != session?.sid
            || dsmSession?.baseURL != session?.baseURL
            || dsmSharedFolderPaths != normalizedSharedFolderPaths else {
            return
        }
        dsmSession = session
        dsmSharedFolderPaths = normalizedSharedFolderPaths
        unavailableDSMPlaybackPaths.removeAll()
    }

    private static func jellyfinEndpointCandidates(from endpoints: [URL]) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        for endpoint in endpoints {
            for path in [endpoint.path, "/jellyfin", "/emby"] {
                guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
                    continue
                }
                components.path = path == "/" ? "" : path
                components.query = nil
                components.fragment = nil
                guard let candidate = components.url,
                      seen.insert(candidate.absoluteString).inserted else {
                    continue
                }
                result.append(candidate)
            }
        }
        return result
    }

    private static func originURL(for url: URL) -> URL? {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    func restoreIfNeeded() async {
        guard !didRestore else { return }
        didRestore = true
        guard let restored = endpointCandidates.compactMap({ candidate in
            KeychainStore.shared.loadJellyfinSession(endpoint: candidate).map {
                (endpoint: candidate, session: $0)
            }
        }).first else {
            isLoading = false
            return
        }
        endpoint = restored.endpoint
        await refreshPlaybackRouteClassification()
        let stored = restored.session
        username = stored.username
        userID = stored.userID
        client = makeClient(accessToken: stored.accessToken)
        isAuthenticated = true
        await refresh()
    }

    func signIn(username: String, password: String) async {
        let cleanedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedUsername.isEmpty else {
            errorMessage = NSLocalizedString("jellyfin.login.required", comment: "")
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            var authenticatedClient: JellyfinClient?
            var authenticatedAccessToken: String?
            var authenticatedUserID: String?
            var authenticatedUsername: String?
            var lastError: Error?
            for candidate in endpointCandidates {
                endpoint = candidate
                let candidateClient = makeClient(accessToken: nil)
                do {
                    let result = try await candidateClient.signIn(
                        username: cleanedUsername,
                        password: password
                    )
                    guard let accessToken = result.accessToken,
                          let userID = result.user?.id else {
                        throw JellyfinLibraryError.missingSession
                    }
                    authenticatedClient = candidateClient
                    authenticatedAccessToken = accessToken
                    authenticatedUserID = userID
                    authenticatedUsername = result.user?.name
                    break
                } catch {
                    lastError = error
                }
            }
            guard
                let newClient = authenticatedClient,
                let accessToken = authenticatedAccessToken,
                let authenticatedUserID
            else {
                throw lastError ?? JellyfinLibraryError.missingSession
            }
            client = newClient
            userID = authenticatedUserID
            self.username = authenticatedUsername ?? cleanedUsername
            isAuthenticated = true
            try KeychainStore.shared.saveJellyfinSession(
                StoredJellyfinSession(
                    endpointString: endpoint.absoluteString,
                    userID: authenticatedUserID,
                    username: self.username,
                    accessToken: accessToken
                ),
                endpoint: endpoint
            )
            record("diagnostics.jellyfin.login_succeeded", level: .info)
            await refreshPlaybackRouteClassification()
            await loadHome()
        } catch {
            try? await client?.signOut()
            client = nil
            userID = nil
            self.username = ""
            isAuthenticated = false
            errorMessage = loginErrorMessage(for: error)
            isLoading = false
            record(
                "diagnostics.jellyfin.login_failed",
                level: .error,
                details: diagnosticDetails(for: error)
            )
        }
    }

    func refresh() async {
        guard isAuthenticated else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        await loadHome()
    }

    func signOut() async {
        let activeClient = client
        KeychainStore.shared.clearJellyfinSession(endpoint: endpoint)
        client = nil
        userID = nil
        username = ""
        isAuthenticated = false
        isLoading = false
        libraries = []
        continueWatching = []
        movies = []
        series = []
        recentlyAdded = []
        favorites = []
        favoriteItemIDs = []
        try? await activeClient?.signOut()
    }

    func loadLibrary(_ library: JellyfinMediaEntry) async throws -> [JellyfinMediaEntry] {
        let kinds: [BaseItemKind]
        switch library.collectionType {
        case CollectionType.tvshows.rawValue:
            kinds = [.series]
        case CollectionType.music.rawValue, CollectionType.musicvideos.rawValue:
            kinds = [.musicAlbum, .audio, .musicVideo]
        default:
            kinds = [.movie, .series, .video]
        }
        let items = try await loadItems(parentID: library.id, kinds: kinds, limit: 250)
        registerFavoriteState(from: items)
        return items
    }

    func loadEpisodes(seriesID: String) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetEpisodesParameters()
        parameters.userID = userID
        parameters.fields = itemFields
        parameters.limit = 500
        parameters.enableImages = true
        parameters.enableImageTypes = [.primary, .thumb, .backdrop]
        parameters.enableUserData = true
        parameters.sortBy = .sortName
        let response = try await client.send(
            Paths.getEpisodes(seriesID: seriesID, parameters: parameters)
        ).value
        let items = (response.items ?? [])
            .compactMap(mapItem)
            .sorted { lhs, rhs in
                let left = (lhs.seasonNumber ?? Int.max, lhs.episodeNumber ?? Int.max, lhs.title)
                let right = (rhs.seasonNumber ?? Int.max, rhs.episodeNumber ?? Int.max, rhs.title)
                if left.0 != right.0 { return left.0 < right.0 }
                if left.1 != right.1 { return left.1 < right.1 }
                return left.2.localizedStandardCompare(right.2) == .orderedAscending
            }
        registerFavoriteState(from: items)
        return items
    }

    func imageURL(
        for entry: JellyfinMediaEntry,
        width: Int = 480,
        landscape: Bool = false,
        prefersBackdrop: Bool = false,
        quality: Int? = nil
    ) -> URL? {
        guard let client else { return nil }
        let useBackdrop = prefersBackdrop && entry.backdropImageTag != nil
        let useThumb = !useBackdrop && landscape && entry.thumbImageTag != nil
        let imageType: ImageType = useBackdrop ? .backdrop : (useThumb ? .thumb : .primary)
        let imageTag = useBackdrop
            ? entry.backdropImageTag
            : (useThumb ? entry.thumbImageTag : entry.imageTag)
        var parameters = Paths.GetItemImageParameters()
        parameters.maxWidth = width
        parameters.quality = quality ?? (prefersBackdrop ? 94 : 88)
        parameters.tag = imageTag
        return client.url(
            with: Paths.getItemImage(
                itemID: useBackdrop || useThumb ? entry.id : entry.imageItemID,
                imageType: imageType.rawValue,
                parameters: parameters
            ),
            queryAPIKey: true
        )
    }

    func isFavorite(_ entry: JellyfinMediaEntry) -> Bool {
        favoriteItemIDs.contains(entry.id)
    }

    func toggleFavorite(_ entry: JellyfinMediaEntry) async {
        guard let client, let userID else { return }
        let shouldFavorite = !isFavorite(entry)
        do {
            if shouldFavorite {
                _ = try await client.send(
                    Paths.markFavoriteItem(itemID: entry.id, userID: userID)
                ).value
                favoriteItemIDs.insert(entry.id)
                if !favorites.contains(where: { $0.id == entry.id }) {
                    favorites.insert(entry, at: 0)
                }
            } else {
                _ = try await client.send(
                    Paths.unmarkFavoriteItem(itemID: entry.id, userID: userID)
                ).value
                favoriteItemIDs.remove(entry.id)
                favorites.removeAll { $0.id == entry.id }
            }
        } catch {
            errorMessage = NSLocalizedString("jellyfin.favorite.failed", comment: "")
        }
    }

    func search(query: String) async throws -> [JellyfinMediaEntry] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return [] }
        let items = try await loadItems(
            parentID: nil,
            kinds: [.movie, .series, .episode, .audio, .video, .musicAlbum, .musicVideo],
            limit: 80,
            searchTerm: cleanedQuery
        )
        registerFavoriteState(from: items)
        return items
    }

    func loadDetail(itemID: String) async throws -> JellyfinMediaEntry {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        let response = try await client.send(
            Paths.getItem(itemID: itemID, userID: userID)
        ).value
        guard let item = mapItem(response) else {
            throw JellyfinLibraryError.missingItem
        }
        registerFavoriteState(from: [item])
        return item
    }

    func loadSimilarItems(itemID: String) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetSimilarItemsParameters()
        parameters.userID = userID
        parameters.limit = 12
        parameters.fields = itemFields
        let response = try await client.send(
            Paths.getSimilarItems(itemID: itemID, parameters: parameters)
        ).value
        let items = (response.items ?? []).compactMap(mapItem)
        registerFavoriteState(from: items)
        return items
    }

    func personImageURL(for person: JellyfinPersonEntry, width: Int = 320) -> URL? {
        guard let client, let imageItemID = person.imageItemID, person.imageTag != nil else {
            return nil
        }
        var parameters = Paths.GetItemImageParameters()
        parameters.maxWidth = width
        parameters.quality = 88
        parameters.tag = person.imageTag
        return client.url(
            with: Paths.getItemImage(
                itemID: imageItemID,
                imageType: ImageType.primary.rawValue,
                parameters: parameters
            ),
            queryAPIKey: true
        )
    }

    func playbackRequest(
        for entry: JellyfinMediaEntry,
        selection: JellyfinPlaybackSelection? = nil,
        forcedServerBitrate: Int? = nil,
        forcedStartTimeTicks: Int? = nil,
        forcedServerReason: String? = nil,
        forcesOriginalPlayback: Bool = false,
        selectedQualityID: String? = nil
    ) async throws -> MediaPlaybackRequest? {
        guard let client, entry.isPlayable else { return nil }
        let requestedAt = Date()
        if entry.kind == .audio {
            var parameters = Paths.GetAudioStreamParameters()
            parameters.container = entry.container
            parameters.isStatic = true
            guard let apiStreamURL = client.url(
                with: Paths.getAudioStream(itemID: entry.id, parameters: parameters),
                queryAPIKey: true
            ) else {
                throw JellyfinLibraryError.missingPlaybackURL
            }
            let streamURL = preferredPlaybackURL(apiStreamURL)
            let extensionHint = entry.container
                .flatMap { $0.split(separator: ",", maxSplits: 1).first }
                .map(String.init)
            return MediaPlaybackRequest(
                requestedAt: requestedAt,
                url: streamURL,
                title: entry.title,
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL),
                source: .jellyfin,
                contentKind: .audio,
                fileExtensionOverride: extensionHint,
                initialPosition: entry.progress,
                initialOrientationMode: .automatic,
                isPrivateNetworkRoute: playbackRouteIsPrivate,
                playbackTracker: makePlaybackTracker(
                    for: entry,
                    playMethod: .directPlay,
                    playSessionID: nil,
                    mediaSourceID: entry.mediaSourceID,
                    subtitleStreamIndex: nil
                )
            )
        }

        let selectedAudioStreamIndex = selection?.audioStreamIndex
            ?? entry.defaultAudioStreamIndex
        let selectedSubtitleStreamIndex = selection == nil
            ? entry.preferredSubtitleStreamIndex
            : selection?.subtitleStreamIndex
        let selectedSubtitleCodec = entry.subtitleTracks
            .first(where: { $0.index == selectedSubtitleStreamIndex })?
            .codec
        let selectedAudioCodec = entry.audioTracks
            .first(where: { $0.index == selectedAudioStreamIndex })?
            .codec
        let selectedAudioTrackOrdinal = selectedAudioStreamIndex.flatMap { selectedIndex in
            entry.audioTracks.firstIndex { $0.index == selectedIndex }
        }
        let selectedSubtitleTrackOrdinal = selectedSubtitleStreamIndex.flatMap { selectedIndex in
            entry.subtitleTracks.firstIndex { $0.index == selectedIndex }
        }

        let bitrateDecision = playbackBitrateDecision()
        // Direct-play eligibility and the server transcoding target solve two
        // different problems. A measured 60+ Mbps Wi-Fi route should be allowed
        // to direct-play a matching source instead of being forced through the
        // old 30 Mbps transcoding ceiling. When transcoding really is needed,
        // cap automatic remote HLS at 20 Mbps so the server can produce the first
        // segment quickly; explicit quality choices remain exact.
        let directPlayBudget = bitrateDecision.directPlayMaximumBitrate
        let maxBitrate = forcedServerBitrate ?? (playbackRouteIsPrivate
            ? directPlayBudget
            : min(directPlayBudget, 20_000_000))
        record(
            "diagnostics.jellyfin.playback_preparing",
            level: .info,
            details: [
                "itemKind": entry.kind.rawValue,
                "container": entry.container ?? "-",
                "subtitleCodec": selectedSubtitleCodec ?? "-",
                "audioCodec": selectedAudioCodec ?? "-",
                "subtitleStreamIndex": selectedSubtitleStreamIndex.map(String.init) ?? "none",
                "audioStreamIndex": selectedAudioStreamIndex.map(String.init) ?? "default",
                "bitrateBasis": bitrateDecision.basis,
                "maximumBitrate": "\(maxBitrate)",
                "networkMaximumBitrate": "\(bitrateDecision.maximumBitrate)",
                "directPlayMaximumBitrate": "\(directPlayBudget)",
                "requestReason": forcedServerReason ?? "initialPlayback",
                "allowsDirectPlay": "preferred",
                "defaultMode": "adaptiveAuto",
                "deviceFamily": MediaPlaybackCapabilities.current.deviceFamily,
                "osVersion": MediaPlaybackCapabilities.current.osVersion
            ]
        )
        do {
            let requestedStartTimeTicks = max(
                forcedStartTimeTicks ?? entry.playbackPositionTicks ?? 0,
                0
            )
            let prepared: JellyfinPreparedPlayback
            // Treat a measured, bitrate-safe original stream like a device-file
            // playback route on Wi-Fi and cellular. This lets VLC start from
            // the authenticated Range proxy instead of waiting for Jellyfin
            // to create the first HLS segment. The probe is bounded and the
            // existing HLS branch remains the fallback when the source cannot
            // be opened or the selected audio needs server conversion.
            let sourceBitrateFitsDirectBudget = entry.mediaBitrate.map {
                $0 <= directPlayBudget
            } ?? false
            let prefersRemoteOriginalPlayback = (
                bitrateDecision.networkKey == "cellular"
                    || (bitrateDecision.networkKey == "wifi" && sourceBitrateFitsDirectBudget)
            ) && !Self.requiresAudioTranscode(audioCodec: selectedAudioCodec)
            let requiresServerSubtitleRendering = selectedSubtitleStreamIndex != nil
                && Self.requiresBurnIn(subtitleCodec: selectedSubtitleCodec)
            let shouldAttemptDirectPlayback = forcedServerBitrate == nil
                && !Self.requiresAudioTranscode(audioCodec: selectedAudioCodec)
                && !requiresServerSubtitleRendering
                && (playbackRouteIsPrivate || forcesOriginalPlayback || prefersRemoteOriginalPlayback)
            let directRoute = shouldAttemptDirectPlayback
                ? await preferredOriginalPlaybackRoute(for: entry, client: client)
                : nil
            if let directRoute {
                let directURL = directRoute.url
                let extensionHint = Self.firstContainer(entry.container) ?? "mp4"
                let directSubtitleSourceURL = Self.requiresBurnIn(subtitleCodec: selectedSubtitleCodec)
                    ? nil
                    : externalSubtitleURL(
                        for: entry,
                        subtitleStreamIndex: selectedSubtitleStreamIndex,
                        client: client
                )
                let directSubtitleURL: URL?
                if let directSubtitleSourceURL {
                    directSubtitleURL = await JellyfinSubtitleNormalizer.normalize(
                        url: directSubtitleSourceURL,
                        sourceCodec: selectedSubtitleCodec,
                        allowsSelfSignedCertificates: requiresCertificateBypass(
                            for: directSubtitleSourceURL
                        )
                    ) ?? directSubtitleSourceURL
                } else {
                    directSubtitleURL = nil
                }
                let externalResource = MediaPlaybackResource(
                    url: directRoute.handoffURL,
                    fileExtensionOverride: extensionHint,
                    subtitleURL: directSubtitleSourceURL
                )
                let internalResource = MediaPlaybackResource(
                    url: directURL,
                    fileExtensionOverride: extensionHint,
                    // Use Jellyfin's UTF-8 SRT conversion for text subtitles
                    // in the in-app VLC path as well as external handoff. This
                    // avoids relying on an embedded ASS font/style that can
                    // render Chinese glyphs as tofu boxes on iOS.
                    subtitleURL: directSubtitleURL,
                    allowsSelfSignedCertificates: directRoute.allowsSelfSignedCertificates
                )
                let mode = "\(directRoute.source)DirectPlay"
                prepared = JellyfinPreparedPlayback(
                    resource: internalResource,
                    externalHandoffResource: externalResource,
                    playSessionID: nil,
                    mediaSourceID: entry.mediaSourceID,
                    playMethod: .directPlay,
                    mode: mode,
                    isPrivateNetworkRoute: directRoute.isPrivateNetworkRoute,
                    allowsSelfSignedCertificates: directRoute.allowsSelfSignedCertificates
                )
                record(
                    "diagnostics.jellyfin.playback_prepared",
                    level: .info,
                    details: [
                        "mode": mode,
                        "container": extensionHint,
                        "playSession": "notRequired",
                        "subtitleCodec": selectedSubtitleCodec ?? "-",
                        "audioCodec": selectedAudioCodec ?? "-",
                        "subtitleStreamIndex": selectedSubtitleStreamIndex.map(String.init) ?? "none",
                        "audioStreamIndex": selectedAudioStreamIndex.map(String.init) ?? "default",
                        "maxBitrate": "unlimitedOriginal",
                        "directPlay": "selected",
                        "remoteOriginalPreferred": prefersRemoteOriginalPlayback ? "yes" : "no",
                        "sourceBitrate": entry.mediaBitrate.map(String.init) ?? "-",
                        "upstream": directRoute.source,
                        "transport": directURL.host == "127.0.0.1" ? "localRangeProxy" : "sourceURL",
                        "prepareMs": Self.elapsedMilliseconds(since: requestedAt)
                    ]
                )
            } else {
                let isForcedServerPlayback = forcedServerBitrate != nil
                let originalRouteWasSkipped = !shouldAttemptDirectPlayback
                record(
                    "diagnostics.jellyfin.playback_preparing",
                    level: originalRouteWasSkipped || isForcedServerPlayback ? .info : .warning,
                    details: [
                        "mode": isForcedServerPlayback
                            ? "serverHLSRequested"
                            : originalRouteWasSkipped
                                ? "originalRangeSkipped"
                                : "originalRangeUnavailable",
                        "reason": isForcedServerPlayback
                            ? forcedServerReason ?? "runtimeReconfigure"
                                : originalRouteWasSkipped
                                    ? "automaticBitrateBudget"
                                : "routeUnavailable",
                        "fallback": "serverHLS",
                        "remoteOriginalPreferred": prefersRemoteOriginalPlayback ? "yes" : "no",
                        "maximumBitrate": "\(maxBitrate)",
                        "sourceBitrate": entry.mediaBitrate.map(String.init) ?? "-",
                        "audioCodec": selectedAudioCodec ?? "-",
                        "network": bitrateDecision.networkKey,
                        "directSource": directRoute?.source ?? "-"
                    ]
                )
                prepared = try await negotiatedVideoPlayback(
                    for: entry,
                    audioStreamIndex: selectedAudioStreamIndex,
                    subtitleStreamIndex: selectedSubtitleStreamIndex,
                    subtitleCodec: selectedSubtitleCodec,
                    client: client,
                    maxStreamingBitrate: maxBitrate,
                    allowsDirectPlay: false,
                    startTimeTicks: requestedStartTimeTicks,
                    requestedAt: requestedAt
                )
            }
            let playbackTracker = makePlaybackTracker(
                for: entry,
                playMethod: prepared.playMethod,
                playSessionID: prepared.playSessionID,
                mediaSourceID: prepared.mediaSourceID ?? entry.mediaSourceID,
                subtitleStreamIndex: selectedSubtitleStreamIndex
            )
            // A private original route may carry the 360 Mbps direct-play
            // budget. Feeding half of that value into a compatibility HLS
            // request would ask Jellyfin for an impractical 180 Mbps
            // transcode. Compatibility startup is latency-oriented, so cap
            // the direct-play fallback envelope before applying the one-step
            // bitrate reduction. Explicit quality choices remain unchanged.
            let compatibilityFallbackInitialBitrate = prepared.playMethod == .directPlay
                ? min(maxBitrate, 20_000_000)
                : maxBitrate
            // Direct-play ASS/SSA subtitles are normalized to an external SRT
            // so VLC does not draw tofu glyphs from the embedded styled track.
            // That also makes VLC report the native subtitle track as disabled.
            // A server HLS fallback still needs the original Jellyfin stream
            // index, otherwise the fallback silently starts without subtitles.
            let preservesServerSubtitleSelection = prepared.playMethod == .directPlay
                && prepared.resource.subtitleURL != nil
            let compatibilityFallbackRequestLoader: ((MediaPlaybackRuntimeState?) async -> MediaPlaybackRequest?)? =
                compatibilityFallbackInitialBitrate > 1_750_000
                ? { [weak self] runtimeState in
                    let runtimeAudioStreamIndex: Int?
                    let runtimeSubtitleStreamIndex: Int?
                    if prepared.playMethod == .transcode {
                        runtimeAudioStreamIndex = selectedAudioStreamIndex
                        runtimeSubtitleStreamIndex = selectedSubtitleStreamIndex
                    } else {
                        runtimeAudioStreamIndex = runtimeState?.audioTrackOrdinal.flatMap { ordinal in
                            entry.audioTracks.indices.contains(ordinal)
                                ? entry.audioTracks[ordinal].index
                                : nil
                        } ?? selectedAudioStreamIndex
                        if runtimeState?.subtitlesDisabled == true,
                           runtimeState?.subtitleSelectionKnown == true,
                           !preservesServerSubtitleSelection {
                            runtimeSubtitleStreamIndex = nil
                        } else {
                            runtimeSubtitleStreamIndex = runtimeState?.subtitleTrackOrdinal.flatMap { ordinal in
                                entry.subtitleTracks.indices.contains(ordinal)
                                    ? entry.subtitleTracks[ordinal].index
                                    : nil
                            } ?? selectedSubtitleStreamIndex
                        }
                    }
                    let runtimeSubtitleCodec = entry.subtitleTracks
                        .first(where: { $0.index == runtimeSubtitleStreamIndex })?
                        .codec
                    let fallbackPositionSeconds = runtimeState?.positionSeconds
                        .flatMap { $0 > 0.5 ? $0 : nil }
                        ?? Double(requestedStartTimeTicks) / 10_000_000
                    return await self?.adaptiveFallbackRequest(
                        for: entry,
                        audioStreamIndex: runtimeAudioStreamIndex,
                        subtitleStreamIndex: runtimeSubtitleStreamIndex,
                        subtitleCodec: runtimeSubtitleCodec,
                        initialBitrate: compatibilityFallbackInitialBitrate,
                        startTimeTicks: Self.jellyfinTicks(for: fallbackPositionSeconds),
                        runtimeState: runtimeState
                    )
                }
                : nil
            let sourceTrackRequestLoader: ((Int?, Int?, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
            if prepared.playMethod == .transcode {
                sourceTrackRequestLoader = { [weak self] audioStreamIndex, subtitleStreamIndex, runtimeState in
                    guard let self else { return nil }
                    do {
                        let replacement = try await self.playbackRequest(
                            for: entry,
                            selection: JellyfinPlaybackSelection(
                                audioStreamIndex: audioStreamIndex,
                                subtitleStreamIndex: subtitleStreamIndex
                            ),
                            forcedServerBitrate: maxBitrate,
                            forcedStartTimeTicks: runtimeState.positionSeconds.map {
                                Self.jellyfinTicks(for: $0)
                            },
                            forcedServerReason: "sourceTrackSwitch"
                        )
                        return replacement?.applyingRuntimePreferences(runtimeState)
                    } catch {
                        self.record(
                            "diagnostics.jellyfin.playback_failed",
                            level: .error,
                            details: self.diagnosticDetails(for: error).merging([
                                "stage": "sourceTrackSwitch",
                                "audioStreamIndex": audioStreamIndex.map(String.init) ?? "default",
                                "subtitleStreamIndex": subtitleStreamIndex.map(String.init) ?? "none"
                            ]) { current, _ in current }
                        )
                        return nil
                    }
                }
            } else {
                sourceTrackRequestLoader = nil
            }
            let serverSeekRequestLoader: ((Double, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?)?
            if prepared.playMethod == .transcode {
                serverSeekRequestLoader = { [weak self] targetSeconds, runtimeState in
                    guard let self else { return nil }
                    do {
                        let replacement = try await self.playbackRequest(
                            for: entry,
                            selection: JellyfinPlaybackSelection(
                                audioStreamIndex: selectedAudioStreamIndex,
                                subtitleStreamIndex: selectedSubtitleStreamIndex
                            ),
                            forcedServerBitrate: maxBitrate,
                            forcedStartTimeTicks: Self.jellyfinTicks(for: targetSeconds),
                            forcedServerReason: "serverSeek"
                        )
                        return replacement?.applyingRuntimePreferences(runtimeState)
                    } catch {
                        self.record(
                            "diagnostics.jellyfin.playback_failed",
                            level: .error,
                            details: self.diagnosticDetails(for: error).merging([
                                "stage": "serverSeek",
                                "targetSeconds": String(format: "%.1f", targetSeconds)
                            ]) { current, _ in current }
                        )
                        return nil
                    }
                }
            } else {
                serverSeekRequestLoader = nil
            }
            let qualityOptions = Self.videoQualityOptions(sourceBitrate: entry.mediaBitrate)
            let effectiveQualityID = selectedQualityID ?? "auto"
            let qualityRequestLoader: ((String, MediaPlaybackRuntimeState) async -> MediaPlaybackRequest?) = {
                [weak self] qualityID, runtimeState in
                guard let self else { return nil }
                let runtimeAudioStreamIndex = runtimeState.audioTrackOrdinal.flatMap { ordinal in
                    entry.audioTracks.indices.contains(ordinal) ? entry.audioTracks[ordinal].index : nil
                } ?? selectedAudioStreamIndex
                let runtimeSubtitleStreamIndex: Int?
                if runtimeState.subtitlesDisabled,
                   runtimeState.subtitleSelectionKnown,
                   !preservesServerSubtitleSelection {
                    runtimeSubtitleStreamIndex = nil
                } else {
                    runtimeSubtitleStreamIndex = runtimeState.subtitleTrackOrdinal.flatMap { ordinal in
                        entry.subtitleTracks.indices.contains(ordinal)
                            ? entry.subtitleTracks[ordinal].index
                            : nil
                    } ?? selectedSubtitleStreamIndex
                }
                let bitrate = Int(qualityID)
                do {
                    let replacement = try await self.playbackRequest(
                        for: entry,
                        selection: JellyfinPlaybackSelection(
                            audioStreamIndex: runtimeAudioStreamIndex,
                            subtitleStreamIndex: runtimeSubtitleStreamIndex
                        ),
                        forcedServerBitrate: bitrate,
                        forcedStartTimeTicks: runtimeState.positionSeconds.map(Self.jellyfinTicks(for:)),
                        forcedServerReason: "qualitySwitch",
                        forcesOriginalPlayback: qualityID == "original",
                        selectedQualityID: qualityID
                    )
                    return replacement?.applyingRuntimePreferences(runtimeState)
                } catch {
                    self.record(
                        "diagnostics.jellyfin.playback_failed",
                        level: .error,
                        details: self.diagnosticDetails(for: error).merging([
                            "stage": "qualitySwitch",
                            "quality": qualityID
                        ]) { current, _ in current }
                    )
                    return nil
                }
            }
            let timelineOffsetSeconds = prepared.playMethod == .transcode
                ? Double(requestedStartTimeTicks) / 10_000_000
                : 0
            let totalDurationSeconds = entry.runTimeTicks.map { Double($0) / 10_000_000 }
            let usesExternalNormalizedSubtitle = prepared.playMethod == .directPlay
                && prepared.resource.subtitleURL != nil
            return MediaPlaybackRequest(
                requestedAt: requestedAt,
                url: prepared.resource.url,
                title: entry.title,
                allowsSelfSignedCertificates: prepared.allowsSelfSignedCertificates,
                source: .jellyfin,
                contentKind: .video,
                fileExtensionOverride: prepared.resource.fileExtensionOverride,
                initialPosition: prepared.playMethod == .transcode ? nil : entry.progress,
                externalSubtitleURL: prepared.resource.subtitleURL,
                // Jellyfin has already selected the requested source audio track for HLS.
                // Its single output track can receive a transient VLC identifier while the
                // playlist is opening, so selecting ordinal zero here can abort startup with
                // "Track identifier not found". Let VLC adopt that sole output track itself.
                preferredAudioTrackOrdinal: prepared.playMethod == .transcode
                    ? nil
                    : selectedAudioTrackOrdinal,
                preferredSubtitleTrackOrdinal: prepared.playMethod == .transcode
                    ? nil
                    : selectedSubtitleTrackOrdinal,
                // When Jellyfin supplies a normalized SRT for an ASS/SSA
                // source, disable the embedded styled track first. VLC then
                // renders only the external text track, avoiding tofu boxes
                // and duplicate subtitle lines.
                prefersSubtitlesDisabled: selectedSubtitleStreamIndex == nil
                    || usesExternalNormalizedSubtitle,
                timelineOffsetSeconds: timelineOffsetSeconds,
                totalDurationSeconds: totalDurationSeconds,
                isPrivateNetworkRoute: prepared.isPrivateNetworkRoute,
                playbackTracker: playbackTracker,
                externalHandoffResource: prepared.externalHandoffResource,
                compatibilityFallbackRequestLoader: compatibilityFallbackRequestLoader,
                sourceAudioTracks: entry.audioTracks.map {
                    MediaPlaybackSourceTrack(id: $0.index, name: $0.title)
                },
                sourceSubtitleTracks: entry.subtitleTracks.map { track in
                    MediaPlaybackSourceTrack(
                        id: track.index,
                        name: track.title,
                        externalURL: Self.requiresBurnIn(subtitleCodec: track.codec)
                            ? nil
                            : externalSubtitleURL(
                                for: entry,
                                subtitleStreamIndex: track.index,
                                client: client
                            )
                    )
                },
                selectedSourceAudioTrackID: selectedAudioStreamIndex,
                selectedSourceSubtitleTrackID: selectedSubtitleStreamIndex,
                sourceTrackRequestLoader: sourceTrackRequestLoader,
                serverSeekRequestLoader: serverSeekRequestLoader,
                qualityOptions: qualityOptions,
                selectedQualityID: effectiveQualityID,
                qualityRequestLoader: qualityRequestLoader
            )
        } catch {
            record(
                "diagnostics.jellyfin.playback_failed",
                level: .error,
                details: diagnosticDetails(for: error)
            )
            throw error
        }
    }

    private static func videoQualityOptions(sourceBitrate: Int?) -> [MediaPlaybackQualityOption] {
        var options = [
            MediaPlaybackQualityOption(
                id: "auto",
                title: NSLocalizedString("player.quality.auto", comment: ""),
                detail: NSLocalizedString("player.quality.auto.detail", comment: "")
            ),
            MediaPlaybackQualityOption(
                id: "original",
                title: NSLocalizedString("player.quality.original", comment: ""),
                detail: sourceBitrate.map { Self.bitrateLabel($0) }
            )
        ]
        let bitrates = [30_000_000, 20_000_000, 12_000_000, 8_000_000, 4_000_000, 2_000_000]
        options.append(contentsOf: bitrates.map { bitrate in
            MediaPlaybackQualityOption(
                id: String(bitrate),
                title: Self.qualityTitle(for: bitrate),
                detail: Self.bitrateLabel(bitrate)
            )
        })
        return options
    }

    private static func qualityTitle(for bitrate: Int) -> String {
        switch bitrate {
        case 25_000_000...: return "4K"
        case 10_000_000...: return "1080p"
        case 5_000_000...: return "720p"
        default: return "480p"
        }
    }

    private static func bitrateLabel(_ bitrate: Int) -> String {
        String(format: "%.0f Mbps", Double(bitrate) / 1_000_000)
    }

    private func adaptiveFallbackRequest(
        for entry: JellyfinMediaEntry,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?,
        subtitleCodec: String?,
        initialBitrate: Int,
        startTimeTicks: Int?,
        runtimeState: MediaPlaybackRuntimeState?
    ) async -> MediaPlaybackRequest? {
        guard client != nil else { return nil }
        let network = PlaybackNetworkObserver.shared.snapshot()
        let fallbackBitrate = max(1_500_000, initialBitrate / 2)
        guard fallbackBitrate < initialBitrate else { return nil }
        do {
            let replacement = try await playbackRequest(
                for: entry,
                selection: JellyfinPlaybackSelection(
                    audioStreamIndex: audioStreamIndex,
                    subtitleStreamIndex: subtitleStreamIndex
                ),
                forcedServerBitrate: fallbackBitrate,
                forcedStartTimeTicks: startTimeTicks,
                forcedServerReason: "bitrateFallback"
            )
            guard let replacement else { return nil }
            record(
                "diagnostics.jellyfin.playback_downshifted",
                level: .warning,
                details: [
                    "fromBitrate": "\(initialBitrate)",
                    "toBitrate": "\(fallbackBitrate)",
                    "network": network.cacheKey,
                    "mode": "serverNegotiatedHLS",
                    "subtitleCodec": subtitleCodec ?? "-"
                ]
            )
            return runtimeState.map { replacement.applyingRuntimePreferences($0) } ?? replacement
        } catch {
            record(
                "diagnostics.jellyfin.playback_downshift_failed",
                level: .error,
                details: diagnosticDetails(for: error).merging([
                    "fromBitrate": "\(initialBitrate)",
                    "toBitrate": "\(fallbackBitrate)",
                    "network": network.cacheKey
                ]) { current, _ in current }
            )
            return nil
        }
    }

    func externalPlaybackRequest(
        for entry: JellyfinMediaEntry,
        selection: JellyfinPlaybackSelection? = nil
    ) async throws -> MediaPlaybackRequest? {
        guard let prepared = try await playbackRequest(for: entry, selection: selection) else {
            return nil
        }
        let resource = prepared.externalHandoffResource ?? MediaPlaybackResource(
            url: prepared.url,
            fileExtensionOverride: prepared.fileExtensionOverride,
            subtitleURL: prepared.externalSubtitleURL
        )
        return MediaPlaybackRequest(
            requestedAt: prepared.requestedAt,
            url: resource.url,
            title: entry.title,
            allowsSelfSignedCertificates: requiresCertificateBypass(for: resource.url),
            source: .jellyfin,
            fileExtensionOverride: resource.fileExtensionOverride,
            initialPosition: entry.progress,
            externalSubtitleURL: resource.subtitleURL,
            preferredAudioTrackOrdinal: prepared.preferredAudioTrackOrdinal,
            preferredSubtitleTrackOrdinal: prepared.preferredSubtitleTrackOrdinal,
            prefersSubtitlesDisabled: prepared.prefersSubtitlesDisabled,
            initialOrientationMode: prepared.initialOrientationMode,
            initialPlaybackRate: prepared.initialPlaybackRate,
            isPrivateNetworkRoute: prepared.isPrivateNetworkRoute
        )
    }

    private func negotiatedVideoPlayback(
        for entry: JellyfinMediaEntry,
        audioStreamIndex: Int?,
        subtitleStreamIndex: Int?,
        subtitleCodec: String?,
        client: JellyfinClient,
        maxStreamingBitrate: Int,
        allowsDirectPlay: Bool,
        startTimeTicks: Int?,
        requestedAt: Date
    ) async throws -> JellyfinPreparedPlayback {
        let requestBody = PlaybackInfoDto(
            allowAudioStreamCopy: false,
            allowVideoStreamCopy: false,
            audioStreamIndex: audioStreamIndex,
            deviceProfile: Self.vlcPlaybackProfile(maxBitrate: maxStreamingBitrate),
            enableDirectPlay: allowsDirectPlay,
            // Public routes must stay on Jellyfin's segmented HLS path. A
            // direct-stream/remux response can still be a long-lived raw
            // connection and defeats the cellular startup policy.
            enableDirectStream: playbackRouteIsPrivate,
            enableTranscoding: true,
            // HLS transcoding is the compatibility path. Keep the selected
            // subtitle in the server-rendered video so ASS/SSA/legacy CJK
            // glyphs do not depend on VLC's iOS text renderer or a child
            // playlist subtitle encoding.
            isAlwaysBurnInSubtitleWhenTranscoding: subtitleStreamIndex != nil,
            maxStreamingBitrate: maxStreamingBitrate,
            mediaSourceID: entry.mediaSourceID,
            startTimeTicks: startTimeTicks,
            subtitleStreamIndex: subtitleStreamIndex,
            userID: userID
        )
        let response = try await client.send(
            Paths.getPostedPlaybackInfo(
                itemID: entry.id,
                parameters: nil,
                requestBody
            )
        ).value
        let mediaSource = response.mediaSources?.first(where: { source in
            source.id == entry.mediaSourceID
        }) ?? response.mediaSources?.first
        guard let mediaSource else {
            throw JellyfinLibraryError.missingPlaybackURL
        }
        let streamURL: URL
        let extensionHint: String
        let playMethod: PlayMethod
        let mode: String
        if let transcodingPath = mediaSource.transcodingURL,
           let transcodingURL = authenticatedJellyfinURL(path: transcodingPath, client: client) {
            streamURL = transcodingURL
            extensionHint = mediaSource.transcodingSubProtocol == .hls
                ? "m3u8"
                : Self.firstContainer(mediaSource.transcodingContainer) ?? "mp4"
            playMethod = .transcode
            mode = mediaSource.transcodingSubProtocol == .hls
                ? "serverNegotiatedHLS"
                : "serverNegotiatedTranscode"
        } else {
            guard let directURL = negotiatedDirectURL(
                for: entry,
                mediaSource: mediaSource,
                playSessionID: response.playSessionID,
                client: client
            ) else {
                throw JellyfinLibraryError.missingPlaybackURL
            }
            streamURL = directURL
            extensionHint = Self.firstContainer(mediaSource.container)
                ?? Self.firstContainer(entry.container)
                ?? "mp4"
            playMethod = .directPlay
            mode = "serverNegotiatedDirectPlay"
        }
        // AVPlayer must be able to request every child playlist/segment with
        // the Jellyfin credentials. A plain authenticated m3u8 URL is not
        // sufficient on cellular routes because AVPlayer does not inherit the
        // client's X-Emby-Token header for child requests. The local proxy
        // rewrites child URIs and forwards the authenticated requests while
        // keeping external handoff on the original server URL.
        let internalStreamURL: URL
        if playMethod == .transcode,
           extensionHint == "m3u8" {
            internalStreamURL = (try? await AuthenticatedMediaStreamProxy.shared.register(
                upstreamURL: streamURL,
                filename: entry.title + ".m3u8",
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL)
            )) ?? streamURL
        } else {
            internalStreamURL = streamURL
        }
        let externalHandoffResource = MediaPlaybackResource(
            url: streamURL,
            fileExtensionOverride: extensionHint,
            subtitleURL: Self.requiresBurnIn(subtitleCodec: subtitleCodec)
                ? nil
                : externalSubtitleURL(
                    for: entry,
                    subtitleStreamIndex: subtitleStreamIndex,
                    client: client
                )
        )
        let resource: MediaPlaybackResource
        if playMethod == .directPlay {
            resource = MediaPlaybackResource(
                url: internalStreamURL,
                fileExtensionOverride: extensionHint,
                // Keep direct-play subtitle behavior identical to the
                // handoff path: text tracks use Jellyfin's normalized SRT,
                // image tracks stay on the server burn-in path.
                subtitleURL: externalHandoffResource.subtitleURL,
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL)
            )
        } else {
            resource = MediaPlaybackResource(
                url: internalStreamURL,
                fileExtensionOverride: extensionHint,
                // The server burns subtitles into HLS for consistent CJK
                // rendering; adding the same track as a VLC slave would
                // duplicate it and reintroduce the missing-glyph path.
                subtitleURL: nil,
                allowsSelfSignedCertificates: false
            )
        }
        record(
            "diagnostics.jellyfin.playback_prepared",
            level: .info,
            details: [
                "mode": mode,
                "container": extensionHint,
                "playSession": response.playSessionID == nil ? "missing" : "present",
                "subtitleCodec": subtitleCodec ?? "-",
                "subtitleStreamIndex": subtitleStreamIndex.map(String.init) ?? "none",
                "audioStreamIndex": audioStreamIndex.map(String.init) ?? "default",
                "startTimeTicks": startTimeTicks.map(String.init) ?? "0",
                "maxBitrate": "\(maxStreamingBitrate)",
                "directPlay": allowsDirectPlay ? "allowed" : "disabled",
                "sourceBitrate": mediaSource.bitrate.map(String.init) ?? "-",
                "transport": resource.url.host == "127.0.0.1"
                    ? "localHLSProxy"
                    : resource.url.scheme?.lowercased() ?? "serverURL",
                "prepareMs": Self.elapsedMilliseconds(since: requestedAt)
            ]
        )
        return JellyfinPreparedPlayback(
            resource: resource,
            externalHandoffResource: externalHandoffResource,
            playSessionID: response.playSessionID,
            mediaSourceID: mediaSource.id,
            playMethod: playMethod,
            mode: mode,
            isPrivateNetworkRoute: playbackRouteIsPrivate,
            allowsSelfSignedCertificates: requiresCertificateBypass(for: resource.url)
        )
    }

    private var playbackRouteIsPrivate: Bool {
        resolvedPlaybackRouteIsPrivate
            ?? NetworkHostClassifier.isPrivate((playbackEndpoint ?? endpoint).host)
    }

    private func refreshPlaybackRouteClassification() async {
        let isPrivate = NetworkHostClassifier.isPrivate((playbackEndpoint ?? endpoint).host)
        resolvedPlaybackRouteIsPrivate = isPrivate
        if isPrivate {
            bitrateMeasurementTasks.values.forEach { $0.cancel() }
            bitrateMeasurementTasks.removeAll()
        }
    }

    private func playbackBitrateDecision() -> JellyfinPlaybackBitrateDecision {
        let route = playbackEndpoint ?? endpoint
        let network = PlaybackNetworkObserver.shared.snapshot()
        if playbackRouteIsPrivate {
            return JellyfinPlaybackBitrateDecision(
                maximumBitrate: 360_000_000,
                directPlayMaximumBitrate: 360_000_000,
                isPrivateRoute: true,
                basis: "privateRoute",
                networkKey: network.cacheKey
            )
        }
        let originKey = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let cacheKey = "\(originKey)|\(network.cacheKey)"
        if let cached = bitrateMeasurements[cacheKey],
           Date().timeIntervalSince(cached.measuredAt) < 10 * 60 {
            // A short throughput sample is deliberately reduced for an HLS
            // target, but applying that same safety factor to direct play makes
            // a 50-55 Mbps Wi-Fi sample reject a 60-65 Mbps source and pay the
            // full server-transcode startup cost. Direct playback can absorb
            // short bursts in its local cache, so use the raw Wi-Fi sample with
            // a small burst allowance while keeping cellular conservative.
            let directPlayMaximumBitrate: Int
            if network.cacheKey == "wifi" {
                directPlayMaximumBitrate = min(
                    max(Int(Double(cached.rawBitrate) * 1.25), cached.bitrate),
                    network.bitrateCap ?? 80_000_000
                )
            } else {
                directPlayMaximumBitrate = cached.bitrate
            }
            return JellyfinPlaybackBitrateDecision(
                maximumBitrate: cached.bitrate,
                directPlayMaximumBitrate: directPlayMaximumBitrate,
                isPrivateRoute: false,
                basis: "measured",
                networkKey: network.cacheKey
            )
        }
        // On Wi-Fi, prefer the source stream and fall back only after an actual
        // playback failure. Treating the conservative 8 Mbps bootstrap value as
        // a hard gate forced ordinary 9-20 Mbps files through full H.264/AAC
        // transcoding before the bandwidth probe had completed.
        let fallbackBitrate = network.cacheKey == "wifi"
            ? (network.bitrateCap ?? network.fallbackBitrate)
            : min(
                network.bitrateCap ?? network.fallbackBitrate,
                network.fallbackBitrate
            )
        return JellyfinPlaybackBitrateDecision(
            maximumBitrate: fallbackBitrate,
            directPlayMaximumBitrate: fallbackBitrate,
            isPrivateRoute: false,
            basis: "networkFallback",
            networkKey: network.cacheKey
        )
    }

    private func scheduleBitrateMeasurementIfNeeded(client: JellyfinClient) {
        let route = playbackEndpoint ?? endpoint
        guard !playbackRouteIsPrivate else { return }
        let network = PlaybackNetworkObserver.shared.snapshot()
        let originKey = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let cacheKey = "\(originKey)|\(network.cacheKey)"
        if let cached = bitrateMeasurements[cacheKey],
           Date().timeIntervalSince(cached.measuredAt) < 10 * 60 {
            return
        }
        guard bitrateMeasurementTasks[cacheKey] == nil else { return }
        bitrateMeasurementTasks[cacheKey] = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.measureMaximumBitrate(
                client: client,
                network: network,
                cacheKey: cacheKey
            )
            self.bitrateMeasurementTasks[cacheKey] = nil
        }
    }

    private func ensureBitrateMeasurementIfNeeded(client: JellyfinClient) async {
        let route = playbackEndpoint ?? endpoint
        guard !playbackRouteIsPrivate else { return }
        let network = PlaybackNetworkObserver.shared.snapshot()
        let originKey = Self.originURL(for: route)?.absoluteString ?? route.absoluteString
        let cacheKey = "\(originKey)|\(network.cacheKey)"
        if let cached = bitrateMeasurements[cacheKey],
           Date().timeIntervalSince(cached.measuredAt) < 10 * 60 {
            return
        }
        scheduleBitrateMeasurementIfNeeded(client: client)
        let task = bitrateMeasurementTasks[cacheKey]
        await task?.value
    }

    private func measureMaximumBitrate(
        client: JellyfinClient,
        network: PlaybackNetworkSnapshot,
        cacheKey: String
    ) async {
        let testSize: Int
        switch network.cacheKey {
        case "wifi": testSize = 4 * 1024 * 1024
        case "cellular": testSize = 1024 * 1024
        default: testSize = 512 * 1024
        }
        let startedAt = Date()
        do {
            let data = try await client.send(Paths.getBitrateTestBytes(size: testSize)).value
            guard !data.isEmpty else { throw URLError(.zeroByteResource) }
            let elapsed = max(Date().timeIntervalSince(startedAt), 0.05)
            let measured = Double(data.count * 8) / elapsed
            let measuredSafeBitrate = max(Int(measured * 0.80), 1_500_000)
            let safeBitrate = min(measuredSafeBitrate, network.bitrateCap ?? 80_000_000)
            bitrateMeasurements[cacheKey] = (safeBitrate, Int(measured), Date())
            record(
                "diagnostics.jellyfin.bitrate_measured",
                level: .info,
                details: [
                    "measuredBitrate": "\(Int(measured))",
                    "selectedBitrate": "\(safeBitrate)",
                    "durationMs": Self.elapsedMilliseconds(since: startedAt),
                    "sampleBytes": "\(data.count)",
                    "network": network.cacheKey
                ]
            )
        } catch {
            guard !Task.isCancelled else { return }
            let fallbackBitrate = min(
                network.bitrateCap ?? network.fallbackBitrate,
                network.fallbackBitrate
            )
            record(
                "diagnostics.jellyfin.bitrate_measured",
                level: .warning,
                details: diagnosticDetails(for: error).merging([
                    "selectedBitrate": "\(fallbackBitrate)",
                    "mode": "fallback",
                    "network": network.cacheKey
                ]) { current, _ in current }
            )
        }
    }

    private func negotiatedDirectURL(
        for entry: JellyfinMediaEntry,
        mediaSource: MediaSourceInfo,
        playSessionID: String?,
        client: JellyfinClient
    ) -> URL? {
        guard let container = Self.firstContainer(mediaSource.container)
            ?? Self.firstContainer(entry.container) else { return nil }
        var parameters = Paths.GetVideoStreamByContainerParameters()
        parameters.isStatic = true
        parameters.tag = mediaSource.eTag
        parameters.playSessionID = playSessionID
        parameters.mediaSourceID = mediaSource.id ?? entry.mediaSourceID
        return client.url(
            with: Paths.getVideoStreamByContainer(
                itemID: entry.id,
                container: container,
                parameters: parameters
            ),
            queryAPIKey: true
        ).map(preferredPlaybackURL)
    }

    private func originalVideoPlaybackURLs(
        for entry: JellyfinMediaEntry,
        client: JellyfinClient
    ) -> [URL] {
        guard let container = Self.firstContainer(entry.container) else { return [] }
        var parameters = Paths.GetVideoStreamByContainerParameters()
        parameters.isStatic = true
        parameters.mediaSourceID = entry.mediaSourceID
        guard let serverURL = client.url(
            with: Paths.getVideoStreamByContainer(
                itemID: entry.id,
                container: container,
                parameters: parameters
            ),
            queryAPIKey: true
        ) else {
            return []
        }
        var result: [URL] = []
        var seen = Set<String>()
        for candidate in [preferredPlaybackURL(serverURL), serverURL] {
            if seen.insert(candidate.absoluteString).inserted {
                result.append(candidate)
            }
        }
        return result
    }

    private func preferredOriginalPlaybackRoute(
        for entry: JellyfinMediaEntry,
        client: JellyfinClient
    ) async -> JellyfinDirectPlaybackRoute? {
        let jellyfinCandidates = originalVideoPlaybackURLs(for: entry, client: client)
        if let url = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
            candidates: jellyfinCandidates,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            diagnosticStage: "jellyfinRange",
            timeout: 4,
            expectedContentLength: entry.mediaSize
        ) {
            return JellyfinDirectPlaybackRoute(
                url: await preferredDirectPlaybackURL(
                    url,
                    filename: entry.title,
                    allowsSelfSignedCertificates: requiresCertificateBypass(for: url)
                ),
                handoffURL: url,
                source: "jellyfinOriginal",
                allowsSelfSignedCertificates: requiresCertificateBypass(for: url),
                isPrivateNetworkRoute: NetworkHostClassifier.isPrivate(url.host)
            )
        }

        if let dsmSession,
           let mediaPath = entry.mediaPath,
           !shouldSkipDSMPlaybackPath(mediaPath) {
            let candidates = dsmOriginalVideoPlaybackURLs(
                mediaPath: mediaPath,
                session: dsmSession
            )
            if !candidates.isEmpty,
               let url = await AuthenticatedMediaPlaybackResolver.firstPlayableURL(
                   candidates: candidates,
                   allowsSelfSignedCertificates: dsmSession.allowsSelfSignedCertificates,
                   diagnosticStage: "jellyfinDSMRange",
                   timeout: 3,
                   expectedContentLength: entry.mediaSize
               ) {
                unavailableDSMPlaybackPaths.removeValue(forKey: mediaPath)
                return JellyfinDirectPlaybackRoute(
                    url: await preferredDirectPlaybackURL(
                        url,
                        filename: entry.title,
                        allowsSelfSignedCertificates: dsmSession.allowsSelfSignedCertificates
                    ),
                    handoffURL: url,
                    source: "dsmFileStation",
                    allowsSelfSignedCertificates: dsmSession.allowsSelfSignedCertificates,
                    isPrivateNetworkRoute: NetworkHostClassifier.isPrivate(url.host)
                )
            }
            unavailableDSMPlaybackPaths[mediaPath] = Date()
            record(
                "diagnostics.jellyfin.playback_preparing",
                level: .warning,
                details: [
                    "mode": "dsmPathUnavailable",
                    "fallback": "serverHLS",
                    "candidateCount": "\(candidates.count)"
                ]
            )
        }
        return nil
    }

    private func dsmOriginalVideoPlaybackURLs(
        mediaPath: String,
        session: DSMSession
    ) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        for path in Self.dsmFileStationPathCandidates(
            mediaPath,
            sharedFolderPaths: dsmSharedFolderPaths
        ) {
            for url in session.fileStationOpenURLs(path: path)
            where seen.insert(url.absoluteString).inserted {
                result.append(url)
            }
        }
        return result
    }

    private func preferredDirectPlaybackURL(
        _ url: URL,
        filename: String,
        allowsSelfSignedCertificates: Bool
    ) async -> URL {
        guard !NetworkHostClassifier.isPrivate(url.host) else { return url }
        return (try? await AuthenticatedMediaStreamProxy.shared.register(
            upstreamURL: url,
            filename: filename,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )) ?? url
    }

    private func shouldSkipDSMPlaybackPath(_ mediaPath: String) -> Bool {
        guard let failedAt = unavailableDSMPlaybackPaths[mediaPath] else { return false }
        if Date().timeIntervalSince(failedAt) < 5 * 60 {
            return true
        }
        unavailableDSMPlaybackPaths.removeValue(forKey: mediaPath)
        return false
    }

    private static func dsmFileStationPathCandidates(
        _ mediaPath: String,
        sharedFolderPaths: [String]
    ) -> [String] {
        let normalized = mediaPath
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("/") else { return [] }

        var result: [String] = []
        var seen = Set<String>()
        func append(_ path: String) {
            let cleaned = path.replacingOccurrences(of: "//", with: "/")
            guard cleaned.hasPrefix("/"), seen.insert(cleaned).inserted else { return }
            result.append(cleaned)
        }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: true)
        let isVolumePath: Bool
        if let volume = components.first?.lowercased(),
           volume.hasPrefix("volume"),
           !volume.dropFirst("volume".count).isEmpty,
           volume.dropFirst("volume".count).allSatisfy(\.isNumber),
           components.count > 1 {
            append("/" + components.dropFirst().joined(separator: "/"))
            isVolumePath = true
        } else {
            isVolumePath = false
        }
        append(normalized)
        guard !isVolumePath, components.count > 1 else { return result }

        let sharedRoots = sharedFolderPaths.compactMap { path -> String? in
            let normalizedShare = path
                .replacingOccurrences(of: "\\", with: "/")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedShare.hasPrefix("/") else { return nil }
            let shareComponents = normalizedShare.split(separator: "/", omittingEmptySubsequences: true)
            if let first = shareComponents.first?.lowercased(),
               first.hasPrefix("volume"),
               !first.dropFirst("volume".count).isEmpty,
               first.dropFirst("volume".count).allSatisfy(\.isNumber),
               shareComponents.count > 1 {
                return "/" + shareComponents.dropFirst().joined(separator: "/")
            }
            return normalizedShare
        }
        for sharedRoot in sharedRoots {
            let sharedName = sharedRoot.split(separator: "/").last?.lowercased()
            if let sharedName,
               let matchingIndex = components.firstIndex(where: {
                   $0.lowercased() == sharedName
               }) {
                let suffix = components.dropFirst(matchingIndex + 1).joined(separator: "/")
                append(suffix.isEmpty ? sharedRoot : "\(sharedRoot)/\(suffix)")
            }
            append("\(sharedRoot)/\(components.dropFirst().joined(separator: "/"))")
        }

        let commonContainerRoots: Set<String> = [
            "data", "media", "mnt", "movie", "movies", "storage", "tv", "video", "videos"
        ]
        if components.count > 2,
           let first = components.first?.lowercased(),
           commonContainerRoots.contains(first) {
            for sharedRoot in sharedRoots {
                append("\(sharedRoot)/\(components.dropFirst(2).joined(separator: "/"))")
            }
        }
        return result
    }

    private func externalSubtitleURL(
        for entry: JellyfinMediaEntry,
        subtitleStreamIndex: Int?,
        client: JellyfinClient
    ) -> URL? {
        guard
            let mediaSourceID = entry.mediaSourceID,
            let subtitleIndex = subtitleStreamIndex,
            let url = client.url(
                with: Paths.getSubtitle(
                    routeItemID: entry.id,
                    routeMediaSourceID: mediaSourceID,
                    routeIndex: subtitleIndex,
                    routeFormat: "srt"
                ),
                queryAPIKey: true
            )
        else {
            return nil
        }
        return preferredPlaybackURL(url)
    }

    private static func requiresBurnIn(subtitleCodec: String?) -> Bool {
        guard let subtitleCodec = subtitleCodec?.lowercased() else { return false }
        return [
            "dvbsub", "dvb_subtitle",
            "pgssub", "hdmv_pgs_subtitle",
            "dvdsub", "dvd_subtitle",
            "xsub"
        ].contains(subtitleCodec)
    }

    private static func requiresAudioTranscode(audioCodec: String?) -> Bool {
        guard let audioCodec = audioCodec?.lowercased() else { return false }
        // MobileVLCKit on iOS can enumerate these streams but may not expose
        // a usable PCM output, especially for TrueHD/MLP in MKV/BD sources.
        // Ask Jellyfin for AAC HLS so the video keeps its position while the
        // server performs the audio-only compatibility conversion.
        return [
            "truehd", "mlp", "ac4", "dts-hd", "dtshd", "dts-hd ma",
            "eac3-joc", "atmos"
        ].contains(audioCodec)
    }

    private func makePlaybackTracker(
        for entry: JellyfinMediaEntry,
        playMethod: PlayMethod,
        playSessionID: String?,
        mediaSourceID: String?,
        subtitleStreamIndex: Int?
    ) -> MediaPlaybackTracker {
        MediaPlaybackTracker { [weak self] event in
            Task { @MainActor [weak self] in
                await self?.reportPlayback(
                    event,
                    entry: entry,
                    playMethod: playMethod,
                    playSessionID: playSessionID,
                    mediaSourceID: mediaSourceID,
                    subtitleStreamIndex: subtitleStreamIndex
                )
            }
        }
    }

    private func reportPlayback(
        _ event: MediaPlaybackTrackingEvent,
        entry: JellyfinMediaEntry,
        playMethod: PlayMethod,
        playSessionID: String?,
        mediaSourceID: String?,
        subtitleStreamIndex: Int?
    ) async {
        guard let client else { return }
        do {
            switch event {
            case .started(let positionSeconds):
                let body = PlaybackStateInfo(
                    canSeek: true,
                    isPaused: false,
                    itemID: entry.id,
                    mediaSourceID: mediaSourceID,
                    playMethod: playMethod,
                    playSessionID: playSessionID,
                    positionTicks: Self.jellyfinTicks(for: positionSeconds),
                    subtitleStreamIndex: subtitleStreamIndex,
                    volumeLevel: 100
                )
                _ = try await client.send(Paths.reportPlaybackStart(body)).value
            case .progressed(let positionSeconds, let isPaused):
                let body = PlaybackStateInfo(
                    canSeek: true,
                    isPaused: isPaused,
                    itemID: entry.id,
                    mediaSourceID: mediaSourceID,
                    playMethod: playMethod,
                    playSessionID: playSessionID,
                    positionTicks: Self.jellyfinTicks(for: positionSeconds),
                    subtitleStreamIndex: subtitleStreamIndex,
                    volumeLevel: 100
                )
                _ = try await client.send(Paths.reportPlaybackProgress(body)).value
            case .stopped(let positionSeconds, let failed):
                let body = PlaybackStopInfo(
                    isFailed: failed,
                    itemID: entry.id,
                    mediaSourceID: mediaSourceID,
                    playSessionID: playSessionID,
                    positionTicks: Self.jellyfinTicks(for: positionSeconds)
                )
                _ = try await client.send(Paths.reportPlaybackStopped(body)).value
                continueWatching = try await loadResumeItems()
                registerFavoriteState(from: continueWatching)
            }
        } catch {
            if !isExpectedCancellation(error) {
                record(
                    "diagnostics.jellyfin.playback_report_failed",
                    level: .warning,
                    details: diagnosticDetails(for: error)
                )
            }
        }
    }

    private static func jellyfinTicks(for seconds: Double) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(min(seconds * 10_000_000, Double(Int.max)))
    }

    private static func firstContainer(_ value: String?) -> String? {
        value?
            .split(separator: ",", maxSplits: 1)
            .first
            .map(String.init)
            .flatMap { $0.isEmpty ? nil : $0.lowercased() }
    }

    private static func elapsedMilliseconds(since date: Date) -> String {
        String(Int(max(Date().timeIntervalSince(date), 0) * 1_000))
    }

    private func authenticatedJellyfinURL(path: String, client: JellyfinClient) -> URL? {
        guard
            let url = client.url(path: path),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return nil
        }
        if components.queryItems?.contains(where: { $0.name.caseInsensitiveCompare("api_key") == .orderedSame }) != true,
           let accessToken = client.accessToken {
            var queryItems = components.queryItems ?? []
            queryItems.append(URLQueryItem(name: "api_key", value: accessToken))
            components.queryItems = queryItems
        }
        return components.url.map(preferredPlaybackURL)
    }

    private func preferredPlaybackURL(_ url: URL) -> URL {
        guard
            let playbackEndpoint,
            var streamComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let playbackComponents = URLComponents(
                url: playbackEndpoint,
                resolvingAgainstBaseURL: false
            )
        else {
            return url
        }
        streamComponents.scheme = playbackComponents.scheme
        streamComponents.host = playbackComponents.host
        streamComponents.port = playbackComponents.port
        let prefix = playbackComponents.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !prefix.isEmpty, !streamComponents.path.hasPrefix("/\(prefix)/") {
            streamComponents.path = "/\(prefix)" + streamComponents.path
        }
        return streamComponents.url ?? url
    }

    private func requiresCertificateBypass(for url: URL) -> Bool {
        guard allowsSelfSignedCertificates, url.scheme?.lowercased() == "https" else {
            return false
        }
        return CertificatePinStore.shared.trustedCertificateData(
            host: url.host,
            port: url.port
        ) != nil
    }

    private static func vlcPlaybackProfile(maxBitrate: Int) -> DeviceProfile {
        let audioCodecs = [
            "aac", "ac3", "alac", "amr_nb", "amr_wb", "dts", "eac3", "flac",
            "mp1", "mp2", "mp3", "opus", "pcm_alaw", "pcm_bluray", "pcm_dvd",
            "pcm_mulaw", "pcm_s16be", "pcm_s16le", "pcm_s24be", "pcm_s24le",
            "pcm_u8", "speex", "vorbis", "wavpack", "wmalossless", "wmapro",
            "wmav1", "wmav2"
        ].joined(separator: ",")
        let videoCodecs = [
            "av1", "dirac", "dv", "ffv1", "flv1", "h261", "h263", "h264", "hevc",
            "mjpeg", "mpeg1video", "mpeg2video", "mpeg4", "msmpeg4v1",
            "msmpeg4v2", "msmpeg4v3", "prores", "theora", "vc1", "vp8", "vp9",
            "wmv1", "wmv2", "wmv3"
        ].joined(separator: ",")
        let videoContainers = [
            "3g2", "3gp", "avi", "flv", "m2ts", "m4v", "mkv", "mov", "mp4",
            "mpeg", "mpegts", "mts", "ogm", "ogv", "ts", "vob", "webm", "wmv"
        ].joined(separator: ",")
        let textSubtitles = [
            "ass", "cc_dec", "mov_text", "mpl2", "pjs", "realtext", "sami",
            "srt", "ssa", "subrip", "subviewer", "subviewer1", "text", "ttml",
            "vplayer", "vtt"
        ]
        let imageSubtitles = ["dvbsub", "dvdsub", "pgssub", "xsub"]
        return DeviceProfile(
            codecProfiles: ["h264", "hevc", "vp9", "av1"].map { codec in
                CodecProfile(
                    codec: codec,
                    conditions: [
                        ProfileCondition(
                            condition: .equalsAny,
                            isRequired: false,
                            property: .videoRangeType,
                            value: "SDR|Unknown"
                        )
                    ],
                    type: .video
                )
            },
            directPlayProfiles: [
                DirectPlayProfile(
                    audioCodec: audioCodecs,
                    container: videoContainers,
                    type: .video,
                    videoCodec: videoCodecs
                ),
                DirectPlayProfile(
                    audioCodec: audioCodecs,
                    container: "aac,ac3,alac,flac,m4a,mp3,ogg,opus,wav,wma",
                    type: .audio
                )
            ],
            maxStaticBitrate: 360_000_000,
            maxStaticMusicBitrate: min(maxBitrate, 8_000_000),
            maxStreamingBitrate: maxBitrate,
            musicStreamingTranscodingBitrate: 320_000,
            name: "Nastart MobileVLCKit \(MediaPlaybackCapabilities.current.deviceFamily)",
            subtitleProfiles: textSubtitles.map {
                SubtitleProfile(format: $0, method: .embed)
            } + textSubtitles.map {
                SubtitleProfile(format: $0, method: .external)
            } + imageSubtitles.map {
                SubtitleProfile(format: $0, method: .embed)
            },
            transcodingProfiles: [
                TranscodingProfile(
                    protocol: .hls,
                    audioCodec: "aac",
                    container: "mp4",
                    context: .streaming,
                    isBreakOnNonKeyFrames: true,
                    maxAudioChannels: "8",
                    minSegments: 2,
                    transcodeSeekInfo: .auto,
                    type: .video,
                    videoCodec: "h264"
                )
            ]
        )
    }

    private func loadHome() async {
        do {
            let startedAt = Date()
            async let loadedLibraries = loadViews()
            async let loadedContinueWatching = loadResumeItems()
            async let loadedMovies = loadItems(parentID: nil, kinds: [.movie], limit: 36)
            async let loadedSeries = loadItems(parentID: nil, kinds: [.series], limit: 36)
            async let loadedRecentlyAdded = loadItems(
                parentID: nil,
                kinds: [.movie, .series],
                limit: 24,
                sortBy: [.dateCreated],
                sortOrder: [.descending]
            )
            async let loadedFavorites = loadItems(
                parentID: nil,
                kinds: [.movie, .series, .episode, .audio, .video, .musicAlbum, .musicVideo],
                limit: 60,
                favoriteOnly: true
            )
            movies = try await loadedMovies
            series = try await loadedSeries
            record(
                "diagnostics.jellyfin.library_loaded",
                level: .info,
                details: [
                    "stage": "primaryShelves",
                    "movies": "\(movies.count)",
                    "series": "\(series.count)",
                    "durationMs": Self.elapsedMilliseconds(since: startedAt)
                ]
            )
            libraries = try await loadedLibraries
            isLoading = false
            continueWatching = try await loadedContinueWatching
            recentlyAdded = try await loadedRecentlyAdded
            favorites = try await loadedFavorites
            let serverFavoriteIDs = (continueWatching + movies + series + recentlyAdded + favorites)
                .filter(\.isFavorite)
                .map(\.id)
            favoriteItemIDs = Set(serverFavoriteIDs + favorites.map(\.id))
            record(
                "diagnostics.jellyfin.library_loaded",
                level: .info,
                details: [
                    "libraries": "\(libraries.count)",
                    "resume": "\(continueWatching.count)",
                    "movies": "\(movies.count)",
                    "series": "\(series.count)",
                    "recentlyAdded": "\(recentlyAdded.count)",
                    "favorites": "\(favorites.count)",
                    "durationMs": Self.elapsedMilliseconds(since: startedAt)
                ]
            )
            if let client {
                scheduleBitrateMeasurementIfNeeded(client: client)
            }
        } catch {
            isLoading = false
            if isExpectedCancellation(error) {
                return
            }
            errorMessage = NSLocalizedString("jellyfin.library.load_failed", comment: "")
            record(
                "diagnostics.jellyfin.library_failed",
                level: .error,
                details: diagnosticDetails(for: error)
            )
        }
    }

    private func isExpectedCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let value = error as NSError
        return value.domain == NSURLErrorDomain && value.code == NSURLErrorCancelled
    }

    private func loadViews() async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetUserViewsParameters()
        parameters.userID = userID
        parameters.isIncludeHidden = false
        let response = try await client.send(Paths.getUserViews(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private func loadResumeItems() async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetResumeItemsParameters()
        parameters.userID = userID
        parameters.limit = 20
        parameters.fields = itemFields
        parameters.mediaTypes = [.video, .audio]
        parameters.enableUserData = true
        parameters.enableImages = true
        parameters.enableImageTypes = [.primary, .thumb, .backdrop]
        parameters.includeItemTypes = [.movie, .episode, .audio, .video]
        let response = try await client.send(Paths.getResumeItems(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private func loadItems(
        parentID: String?,
        kinds: [BaseItemKind],
        limit: Int,
        searchTerm: String? = nil,
        favoriteOnly: Bool? = nil,
        sortBy: [ItemSortBy] = [.sortName],
        sortOrder: [JellyfinAPI.SortOrder] = [.ascending]
    ) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetItemsParameters()
        parameters.userID = userID
        parameters.parentID = parentID
        parameters.limit = limit
        parameters.isRecursive = true
        parameters.searchTerm = searchTerm
        parameters.isFavorite = favoriteOnly
        parameters.fields = itemFields
        parameters.includeItemTypes = kinds
        parameters.sortBy = sortBy
        parameters.sortOrder = sortOrder
        parameters.enableUserData = true
        parameters.enableImages = true
        parameters.imageTypeLimit = 1
        parameters.enableImageTypes = [.primary, .thumb, .backdrop]
        let response = try await client.send(Paths.getItems(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private var itemFields: [ItemFields] {
        [
            .overview,
            .primaryImageAspectRatio,
            .mediaSources,
            .mediaStreams,
            .path,
            .genres,
            .dateCreated
        ]
    }

    private func registerFavoriteState(from items: [JellyfinMediaEntry]) {
        favoriteItemIDs.formUnion(items.filter(\.isFavorite).map(\.id))
    }

    private func mapItem(_ item: BaseItemDto) -> JellyfinMediaEntry? {
        guard let id = item.id, let title = item.name, !title.isEmpty else { return nil }
        let kind: JellyfinEntryKind
        switch item.type {
        case .collectionFolder, .folder: kind = .library
        case .movie: kind = .movie
        case .series: kind = .series
        case .episode: kind = .episode
        case .audio, .musicAlbum: kind = .audio
        case .video, .musicVideo: kind = .video
        default: kind = .unknown
        }
        let imageItemID = item.imageTags?[ImageType.primary.rawValue] == nil
            ? (item.parentPrimaryImageItemID ?? id)
            : id
        let imageTag = item.imageTags?[ImageType.primary.rawValue] ?? item.parentPrimaryImageTag
        let mediaSource = preferredMediaSource(from: item.mediaSources ?? [])
        let mediaStreams = mediaSource?.mediaStreams ?? item.mediaStreams ?? []
        let videoStream = mediaStreams.first { $0.type == .video }
        let audioStreams = mediaStreams.filter { $0.type == .audio }
        let audioStream = audioStreams.first
        let subtitleStreams = mediaStreams.filter { $0.type == .subtitle }
        let audioTracks = audioStreams.compactMap(Self.mediaTrack)
        let subtitleTracks = subtitleStreams.compactMap(Self.mediaTrack)
        let defaultAudioStreamIndex = mediaSource?.defaultAudioStreamIndex
            ?? audioStreams.first(where: { $0.isDefault == true })?.index
            ?? audioStreams.first?.index
        let preferredSubtitle = subtitleStreams.first(where: { $0.index == mediaSource?.defaultSubtitleStreamIndex })
            ?? subtitleStreams.first(where: { $0.isForced == true })
            ?? subtitleStreams.first(where: { $0.isDefault == true })
        let people = (item.people ?? []).compactMap { person -> JellyfinPersonEntry? in
            guard let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty else {
                return nil
            }
            return JellyfinPersonEntry(
                id: person.id ?? "\(name)|\(person.role ?? "")",
                imageItemID: person.id,
                name: name,
                role: person.role,
                type: person.type?.rawValue,
                imageTag: person.primaryImageTag
            )
        }
        return JellyfinMediaEntry(
            id: id,
            title: title,
            subtitle: subtitle(for: item, kind: kind),
            overview: item.overview ?? "",
            kind: kind,
            collectionType: item.collectionType?.rawValue,
            imageItemID: imageItemID,
            imageTag: imageTag,
            thumbImageTag: item.imageTags?[ImageType.thumb.rawValue],
            backdropImageTag: item.backdropImageTags?.first,
            container: item.container ?? mediaSource?.container,
            mediaSourceID: mediaSource?.id,
            defaultAudioStreamIndex: defaultAudioStreamIndex,
            preferredSubtitleStreamIndex: preferredSubtitle?.index,
            preferredSubtitleCodec: preferredSubtitle?.codec,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks,
            progress: item.userData?.playedPercentage.map { min(max($0 / 100, 0), 1) },
            playbackPositionTicks: item.userData?.playbackPositionTicks,
            runTimeTicks: item.runTimeTicks ?? mediaSource?.runTimeTicks,
            seasonNumber: item.parentIndexNumber,
            episodeNumber: item.indexNumber,
            isFavorite: item.userData?.isFavorite == true,
            genres: item.genres ?? [],
            communityRating: item.communityRating.map(Double.init),
            officialRating: item.officialRating,
            videoDescription: Self.videoDescription(for: videoStream),
            audioDescription: Self.audioDescription(for: audioStream),
            originalTitle: item.originalTitle,
            tagline: item.taglines?.first(where: { !$0.isEmpty }),
            productionYear: item.productionYear,
            premiereDate: item.premiereDate,
            people: people,
            studios: (item.studios ?? []).compactMap(\.name).filter { !$0.isEmpty },
            externalLinks: Self.externalLinks(for: item),
            mediaPath: mediaSource?.path ?? item.path,
            mediaSize: mediaSource?.size,
            mediaBitrate: mediaSource?.bitrate
        )
    }

    private func preferredMediaSource(from sources: [MediaSourceInfo]) -> MediaSourceInfo? {
        guard !sources.isEmpty else { return nil }
        // Automatic playback must describe the original asset consistently.
        // Never choose a lower-bitrate MediaSource just because a previous
        // throughput sample was conservative; that silently changes the title
        // before the player has had a chance to try the original route. Manual
        // quality selection is the only place that should request HLS.
        return sources.max { lhs, rhs in
            (lhs.bitrate ?? 0) < (rhs.bitrate ?? 0)
        } ?? sources.first
    }

    private static func externalLinks(for item: BaseItemDto) -> [JellyfinExternalLink] {
        var links: [JellyfinExternalLink] = []
        var seen = Set<String>()

        for link in item.externalURLs ?? [] {
            guard let value = link.url,
                  let url = URL(string: value),
                  ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
                  seen.insert(url.absoluteString).inserted else {
                continue
            }
            links.append(JellyfinExternalLink(name: link.name ?? url.host ?? value, url: url))
        }

        let providers = item.providerIDs ?? [:]
        let providerLinks: [(String, String?)] = [
            ("IMDb", providers.first { $0.key.caseInsensitiveCompare("imdb") == .orderedSame }
                .map { "https://www.imdb.com/title/\($0.value)/" }),
            ("TMDB", providers.first { $0.key.caseInsensitiveCompare("tmdb") == .orderedSame }
                .map { "https://www.themoviedb.org/\(item.type == .series ? "tv" : "movie")/\($0.value)" })
        ]
        for (name, value) in providerLinks {
            guard let value,
                  let url = URL(string: value),
                  seen.insert(url.absoluteString).inserted else {
                continue
            }
            links.append(JellyfinExternalLink(name: name, url: url))
        }
        return links
    }

    private static func mediaTrack(_ stream: MediaStream) -> JellyfinMediaTrack? {
        guard let index = stream.index else { return nil }
        let fallbackTitle = [stream.language, stream.codec?.uppercased()]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        let displayTitle = stream.displayTitle
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { $0.isEmpty ? nil : $0 }
        return JellyfinMediaTrack(
            index: index,
            title: displayTitle ?? (fallbackTitle.isEmpty ? "#\(index)" : fallbackTitle),
            codec: stream.codec,
            isDefault: stream.isDefault == true,
            isForced: stream.isForced == true
        )
    }

    private static func videoDescription(for stream: MediaStream?) -> String? {
        guard let stream else { return nil }
        var components: [String] = []
        if let height = stream.height {
            if height >= 2_000 {
                components.append("4K")
            } else if height >= 1_000 {
                components.append("1080p")
            } else if height >= 700 {
                components.append("720p")
            } else {
                components.append("\(height)p")
            }
        }
        if let codec = stream.codec?.uppercased() {
            switch codec {
            case "HEVC", "H265": components.append("H.265")
            case "H264", "AVC": components.append("H.264")
            default: components.append(codec)
            }
        }
        if let videoRangeType = stream.videoRangeType,
           videoRangeType != .unknown,
           videoRangeType != .sdr {
            components.append("HDR")
        }
        let description = components.joined(separator: " · ")
        return description.isEmpty ? stream.displayTitle : description
    }

    private static func audioDescription(for stream: MediaStream?) -> String? {
        guard let stream else { return nil }
        var components: [String] = []
        if let codec = stream.codec?.uppercased() {
            components.append(codec == "EAC3" ? "E-AC3" : codec)
        }
        if let channels = stream.channels {
            switch channels {
            case 1: components.append("Mono")
            case 2: components.append("2.0")
            case 6: components.append("5.1")
            case 8: components.append("7.1")
            default: components.append("\(channels) ch")
            }
        }
        let description = components.joined(separator: " · ")
        return description.isEmpty ? stream.displayTitle : description
    }

    private func subtitle(for item: BaseItemDto, kind: JellyfinEntryKind) -> String {
        if kind == .episode {
            let season = item.parentIndexNumber.map { "S\($0)" } ?? ""
            let episode = item.indexNumber.map { "E\($0)" } ?? ""
            return [item.seriesName, season + episode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let duration = item.runTimeTicks.flatMap { ticks -> String? in
            guard ticks > 0 else { return nil }
            let minutes = Int(ticks / 600_000_000)
            guard minutes > 0 else { return nil }
            return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        }
        return [item.productionYear.map(String.init), duration]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private func makeClient(accessToken: String?) -> JellyfinClient {
        let delegate = JellyfinCertificateTrustDelegate(
            trustedHost: endpoint.host,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
        )
        trustDelegate = delegate
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.waitsForConnectivity = false
        let deviceID = Self.persistentDeviceID()
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
        return JellyfinClient(
            configuration: .init(
                url: endpoint,
                accessToken: accessToken,
                client: "Nastart",
                deviceName: UIDevice.current.model,
                deviceID: deviceID,
                version: appVersion
            ),
            sessionConfiguration: configuration,
            sessionDelegate: delegate
        )
    }

    private static func persistentDeviceID() -> String {
        let key = "jellyfin.client.device-id"
        if let current = UserDefaults.standard.string(forKey: key) { return current }
        let value = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(value, forKey: key)
        return value
    }

    private func record(
        _ messageKey: String,
        level: DiagnosticLogLevel,
        details: [String: String] = [:]
    ) {
        DiagnosticLogStore.shared.record(
            level,
            categoryKey: "diagnostics.category.media",
            messageKey: messageKey,
            details: details.merging([
                "target": DiagnosticLogStore.redactedURL(endpoint)
            ]) { current, _ in current }
        )
    }

    private func diagnosticDetails(for error: Error) -> [String: String] {
        let value = error as NSError
        var details = [
            "errorDomain": value.domain,
            "errorCode": "\(value.code)",
            "description": value.localizedDescription,
            "errorType": String(reflecting: type(of: error)),
            "transport": endpoint.scheme?.lowercased() ?? "-"
        ]
        if let status = httpStatusCode(for: error) {
            details["httpStatus"] = "\(status)"
        }
        return details
    }

    private func loginErrorMessage(for error: Error) -> String {
        switch httpStatusCode(for: error) {
        case 401:
            return NSLocalizedString("jellyfin.login.invalid_credentials", comment: "")
        case 403:
            return NSLocalizedString("jellyfin.login.denied", comment: "")
        case 429:
            return NSLocalizedString("jellyfin.login.rate_limited", comment: "")
        default:
            return NSLocalizedString("jellyfin.login.failed", comment: "")
        }
    }

    private func httpStatusCode(for error: Error) -> Int? {
        let descriptions = [String(describing: error), (error as NSError).localizedDescription]
        for description in descriptions {
            let tokens = description.components(separatedBy: CharacterSet.decimalDigits.inverted)
            if let status = tokens.compactMap(Int.init).first(where: { (100...599).contains($0) }) {
                return status
            }
        }
        return nil
    }
}

private enum JellyfinLibraryError: Error {
    case missingSession
    case missingItem
    case missingPlaybackURL
}

private struct JellyfinLibraryView: View {
    let service: LaunchpadService
    let dsmSession: DSMSession?
    let dsmSharedFolderPaths: [String]
    @StateObject private var store: JellyfinLibraryStore

    init(
        service: LaunchpadService,
        endpoint: URL,
        allowsSelfSignedCertificates: Bool,
        dsmSession: DSMSession? = nil,
        dsmSharedFolderPaths: [String] = [],
        fallbackEndpoints: [URL] = []
    ) {
        self.service = service
        self.dsmSession = dsmSession
        self.dsmSharedFolderPaths = dsmSharedFolderPaths
        _store = StateObject(wrappedValue: JellyfinLibraryStore(
            endpoint: endpoint,
            playbackEndpoint: nil,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
            dsmSession: dsmSession,
            dsmSharedFolderPaths: dsmSharedFolderPaths,
            fallbackEndpoints: fallbackEndpoints
        ))
    }

    var body: some View {
        Group {
            if store.isLoading && !store.isAuthenticated {
                ProgressView("jellyfin.library.connecting")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !store.isAuthenticated {
                JellyfinLoginView(store: store)
            } else {
                JellyfinHomeView(store: store)
            }
        }
        .background(AppTheme.groupedBackground)
        .task(id: dsmPlaybackContextID) {
            store.updateDSMPlaybackContext(
                session: dsmSession,
                sharedFolderPaths: dsmSharedFolderPaths
            )
            await store.restoreIfNeeded()
        }
        .toolbar {
            if store.isAuthenticated {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    NavigationLink {
                        JellyfinFavoritesView(store: store)
                    } label: {
                        Image(systemName: "heart")
                    }
                    .accessibilityLabel(Text("jellyfin.favorites.title"))

                    NavigationLink {
                        JellyfinSearchView(store: store)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel(Text("jellyfin.search.title"))

                    Menu {
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Label("action.refresh", systemImage: "arrow.clockwise")
                        }
                        Button(role: .destructive) {
                            Task { await store.signOut() }
                        } label: {
                            Label("jellyfin.logout", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var dsmPlaybackContextID: String {
        ([dsmSession?.sid ?? "-"] + dsmSharedFolderPaths.sorted()).joined(separator: "|")
    }
}

private struct JellyfinLoginView: View {
    @ObservedObject var store: JellyfinLibraryStore
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(AppTheme.accent)
                    Text("jellyfin.login.title")
                        .font(.title2.weight(.bold))
                    Text("jellyfin.login.description")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 0) {
                    TextField("jellyfin.login.username", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(16)
                    Divider()
                    SecureField("jellyfin.login.password", text: $password)
                        .textContentType(.password)
                        .padding(16)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                if let errorMessage = store.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await store.signIn(username: username, password: password) }
                } label: {
                    HStack {
                        if store.isLoading { ProgressView().tint(.white) }
                        Text("jellyfin.login.action")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.primaryAction)
                .disabled(store.isLoading || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(24)
        }
    }
}

private struct JellyfinHomeView: View {
    @ObservedObject var store: JellyfinLibraryStore

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 26) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.username)
                            .font(.headline.weight(.semibold))
                        Text("jellyfin.library.connected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if store.isLoading { ProgressView() }
                }

                if let errorMessage = store.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                        Button("action.retry") {
                            Task { await store.refresh() }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                if !featuredItems.isEmpty {
                    JellyfinHeroCarousel(store: store, items: featuredItems)
                }

                if !store.libraries.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        JellyfinShelfHeader(
                            titleKey: "jellyfin.library.mine",
                            count: store.libraries.count
                        )
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(store.libraries) { library in
                                    NavigationLink {
                                        JellyfinCollectionView(store: store, library: library)
                                    } label: {
                                        JellyfinLibraryCard(store: store, library: library)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                if !store.continueWatching.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "media.continue.title",
                        items: store.continueWatching,
                        posterWidth: 230,
                        landscape: true
                    )
                }

                if !store.favorites.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "jellyfin.favorites.title",
                        items: Array(store.favorites.prefix(18)),
                        posterWidth: 128,
                        landscape: false
                    )
                }

                if !store.movies.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "media.movies.title",
                        items: store.movies,
                        posterWidth: 128,
                        landscape: false
                    )
                }

                if !store.series.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "jellyfin.series.title",
                        items: store.series,
                        posterWidth: 128,
                        landscape: false
                    )
                }

                if !store.isLoading,
                   store.libraries.isEmpty,
                   store.continueWatching.isEmpty,
                   store.movies.isEmpty,
                   store.series.isEmpty,
                   store.errorMessage == nil {
                    VStack(spacing: 12) {
                        Image(systemName: "rectangle.stack.badge.play")
                            .font(.system(size: 34))
                            .foregroundStyle(.secondary)
                        Text("jellyfin.library.empty")
                            .font(.headline)
                        Text("jellyfin.library.empty_detail")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 44)
                }
            }
            .frame(maxWidth: 960, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
        .refreshable { await store.refresh() }
    }

    private var featuredItems: [JellyfinMediaEntry] {
        var seen = Set<String>()
        let resumableMovies = store.continueWatching.filter { $0.kind == .movie }
        return (resumableMovies + store.recentlyAdded + store.favorites + store.movies + store.series)
            .filter { item in
                guard
                    item.kind == .movie || item.kind == .series,
                    item.backdropImageTag != nil
                else {
                    return false
                }
                return seen.insert(item.id).inserted
            }
            .prefix(6)
            .map { $0 }
    }
}

private struct JellyfinShelfHeader: View {
    let titleKey: LocalizedStringKey
    let count: Int?

    init(titleKey: LocalizedStringKey, count: Int? = nil) {
        self.titleKey = titleKey
        self.count = count
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titleKey)
                .font(.title2.weight(.bold))
            Spacer()
            if let count {
                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct JellyfinHeroCarousel: View {
    @ObservedObject var store: JellyfinLibraryStore
    let items: [JellyfinMediaEntry]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                NavigationLink {
                    JellyfinMediaRouteView(store: store, item: item)
                } label: {
                    JellyfinHeroSlide(store: store, item: item)
                }
                .buttonStyle(.plain)
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .frame(maxHeight: horizontalSizeClass == .regular ? 400 : 240)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if items.count > 1 {
                HStack(spacing: 6) {
                    ForEach(items.indices, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(index == selection ? 0.95 : 0.48))
                            .frame(width: index == selection ? 18 : 6, height: 6)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.black.opacity(0.32), in: Capsule())
                .padding(14)
                .accessibilityHidden(true)
            }
        }
        .task(id: items.map(\.id)) {
            selection = min(selection, max(items.count - 1, 0))
            guard items.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    selection = (selection + 1) % items.count
                }
            }
        }
    }
}

private struct JellyfinHeroSlide: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(
                url: store.imageURL(
                    for: item,
                    width: 1_280,
                    landscape: true,
                    prefersBackdrop: true,
                    quality: 90
                )
            )

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.28),
                    .init(color: .black.opacity(0.18), location: 0.52),
                    .init(color: .black.opacity(0.88), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 7) {
                Text(LocalizedStringKey(
                    item.kind == .series ? "jellyfin.series.title" : "media.movies.title"
                ))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(item.title)
                    .font(
                        horizontalSizeClass == .regular
                            ? .title2.weight(.bold)
                            : .title3.weight(.bold)
                    )
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.82))
                        .lineLimit(1)
                }
                Label {
                    Text(LocalizedStringKey(
                        item.isPlayable ? "player.play_in_app" : "jellyfin.view_details"
                    ))
                } icon: {
                    Image(systemName: item.isPlayable ? "play.fill" : "arrow.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(horizontalSizeClass == .regular ? 20 : 14)
        }
        .background(Color.black)
        .contentShape(Rectangle())
    }
}

private struct JellyfinLibraryCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let library: JellyfinMediaEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(
                url: store.imageURL(for: library, width: 560, landscape: true)
            )
            LinearGradient(
                colors: [.clear, .black.opacity(0.72)],
                startPoint: .center,
                endPoint: .bottom
            )
            Text(library.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(12)
        }
        .frame(width: 220, height: 124)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct JellyfinPosterShelf: View {
    @ObservedObject var store: JellyfinLibraryStore
    let titleKey: LocalizedStringKey
    let items: [JellyfinMediaEntry]
    let posterWidth: CGFloat
    let landscape: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            JellyfinShelfHeader(titleKey: titleKey, count: items.count)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            JellyfinMediaRouteView(store: store, item: item)
                        } label: {
                            JellyfinPosterCard(
                                store: store,
                                item: item,
                                width: posterWidth,
                                landscape: landscape
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct JellyfinPosterCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    let width: CGFloat
    let landscape: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                JellyfinPosterImage(
                    url: store.imageURL(
                        for: item,
                        width: Int(width * 3),
                        landscape: landscape
                    )
                )
                if let progress = item.progress, progress > 0 {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                }
            }
            .frame(width: width, height: landscape ? width * 0.58 : width * 1.48)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(item.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: width, alignment: .leading)
    }
}

private struct JellyfinGridPosterCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .bottomLeading) {
                JellyfinPosterImage(
                    url: store.imageURL(for: item, width: 540)
                )
                if let progress = item.progress, progress > 0 {
                    GeometryReader { geometry in
                        VStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .fill(AppTheme.accent)
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                    }
                }
            }
            .aspectRatio(2.0 / 3.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            Text(item.title)
                .font(
                    horizontalSizeClass == .compact
                        ? .caption.weight(.semibold)
                        : .subheadline.weight(.semibold)
                )
                .foregroundStyle(.primary)
                .lineLimit(2)
            if !item.subtitle.isEmpty {
                Text(item.subtitle)
                    .font(horizontalSizeClass == .compact ? .caption2 : .caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private final class JellyfinImagePipeline: @unchecked Sendable {
    static let shared = JellyfinImagePipeline()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private let session: URLSession

    private init() {
        memoryCache.countLimit = 240
        memoryCache.totalCostLimit = 64 * 1_024 * 1_024
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 64 * 1_024 * 1_024,
            diskCapacity: 320 * 1_024 * 1_024,
            diskPath: "nastart-jellyfin-images"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.httpMaximumConnectionsPerHost = 8
        session = URLSession(configuration: configuration)
    }

    func image(for url: URL) async -> UIImage? {
        let key = url as NSURL
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        do {
            let (data, response) = try await session.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200..<300).contains(response.statusCode),
                let image = UIImage(data: data)
            else {
                return nil
            }
            memoryCache.setObject(image, forKey: key, cost: data.count)
            return image
        } catch {
            return nil
        }
    }
}

@MainActor
private final class JellyfinPosterImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var didFail = false
    private var currentURL: URL?

    func load(_ url: URL?) async {
        guard currentURL != url || image == nil else { return }
        currentURL = url
        image = nil
        didFail = false
        guard let url else { return }
        let loadedImage = await JellyfinImagePipeline.shared.image(for: url)
        guard currentURL == url, !Task.isCancelled else { return }
        image = loadedImage
        didFail = loadedImage == nil
    }
}

private struct JellyfinPosterImage: View {
    let url: URL?
    var scalesToFit = false
    @StateObject private var loader = JellyfinPosterImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                if scalesToFit {
                    Image(uiImage: image).resizable().scaledToFit()
                } else {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            } else if loader.didFail || url == nil {
                placeholder
            } else {
                ZStack {
                    placeholder
                    ProgressView()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: url) {
            await loader.load(url)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .overlay {
                Image(systemName: "play.rectangle")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
    }
}

private struct JellyfinFavoritesView: View {
    @ObservedObject var store: JellyfinLibraryStore

    var body: some View {
        Group {
            if store.favorites.isEmpty {
                JellyfinEmptyState(
                    systemImage: "heart",
                    titleKey: "jellyfin.favorites.empty",
                    detailKey: "jellyfin.favorites.empty_detail"
                )
            } else {
                JellyfinResultGrid(store: store, items: store.favorites)
            }
        }
        .navigationTitle("jellyfin.favorites.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JellyfinSearchView: View {
    @ObservedObject var store: JellyfinLibraryStore
    @State private var query = ""
    @State private var results: [JellyfinMediaEntry] = []
    @State private var isSearching = false
    @State private var searchFailed = false

    var body: some View {
        Group {
            if isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchFailed {
                JellyfinEmptyState(
                    systemImage: "exclamationmark.magnifyingglass",
                    titleKey: "jellyfin.search.failed",
                    detailKey: "jellyfin.search.failed_detail"
                )
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                JellyfinEmptyState(
                    systemImage: "magnifyingglass",
                    titleKey: "jellyfin.search.start",
                    detailKey: "jellyfin.search.start_detail"
                )
            } else if results.isEmpty {
                JellyfinEmptyState(
                    systemImage: "rectangle.stack.badge.minus",
                    titleKey: "jellyfin.search.empty",
                    detailKey: "jellyfin.search.empty_detail"
                )
            } else {
                JellyfinResultGrid(store: store, items: results)
            }
        }
        .navigationTitle("jellyfin.search.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "jellyfin.search.placeholder")
        .task(id: query) {
            let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanedQuery.isEmpty else {
                results = []
                searchFailed = false
                isSearching = false
                return
            }
            isSearching = true
            searchFailed = false
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            do {
                results = try await store.search(query: cleanedQuery)
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                searchFailed = true
            }
            isSearching = false
        }
    }
}

private struct JellyfinResultGrid: View {
    @ObservedObject var store: JellyfinLibraryStore
    let items: [JellyfinMediaEntry]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: gridColumns,
                spacing: 18
            ) {
                ForEach(items) { item in
                    NavigationLink {
                        JellyfinMediaRouteView(store: store, item: item)
                    } label: {
                        JellyfinGridPosterCard(store: store, item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 960)
            .padding(.horizontal, horizontalSizeClass == .compact ? 12 : 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemBackground))
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return Array(
                repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                count: 3
            )
        }
        return [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14, alignment: .top)]
    }
}

private struct JellyfinEmptyState: View {
    let systemImage: String
    let titleKey: LocalizedStringKey
    let detailKey: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text(titleKey)
                .font(.headline)
            Text(detailKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct JellyfinCollectionView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let library: JellyfinMediaEntry
    @State private var items: [JellyfinMediaEntry] = []
    @State private var isLoading = true
    @State private var failed = false
    @State private var query = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if failed {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("jellyfin.library.load_failed")
                        .font(.headline)
                    Button("action.retry") { Task { await load() } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if visibleItems.isEmpty {
                        JellyfinEmptyState(
                            systemImage: query.isEmpty ? "rectangle.stack.badge.minus" : "magnifyingglass",
                            titleKey: query.isEmpty ? "jellyfin.library.empty" : "jellyfin.search.empty",
                            detailKey: query.isEmpty ? "jellyfin.library.empty_detail" : "jellyfin.search.empty_detail"
                        )
                        .frame(minHeight: 420)
                    } else {
                        LazyVGrid(
                            columns: gridColumns,
                            spacing: 20
                        ) {
                            ForEach(visibleItems) { item in
                                NavigationLink {
                                    JellyfinMediaRouteView(store: store, item: item)
                                } label: {
                                    JellyfinGridPosterCard(store: store, item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: 960)
                        .padding(.horizontal, horizontalSizeClass == .compact ? 12 : 18)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .navigationTitle(library.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "jellyfin.search.placeholder")
        .task { await load() }
    }

    private var visibleItems: [JellyfinMediaEntry] {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedQuery.isEmpty else { return items }
        return items.filter {
            $0.title.localizedCaseInsensitiveContains(cleanedQuery)
                || $0.subtitle.localizedCaseInsensitiveContains(cleanedQuery)
        }
    }

    private var gridColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return Array(
                repeating: GridItem(.flexible(), spacing: 10, alignment: .top),
                count: 3
            )
        }
        return [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: 14, alignment: .top)]
    }

    private func load() async {
        isLoading = true
        failed = false
        do {
            items = try await store.loadLibrary(library)
        } catch {
            failed = true
        }
        isLoading = false
    }
}

private struct JellyfinMediaRouteView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry

    var body: some View {
        if item.kind == .series {
            JellyfinSeriesView(store: store, series: item)
        } else {
            JellyfinMediaDetailView(store: store, item: item)
        }
    }
}

private struct JellyfinSeriesView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let series: JellyfinMediaEntry
    @State private var episodes: [JellyfinMediaEntry] = []
    @State private var isLoading = true
    @State private var failed = false

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 36, 0), 820)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    JellyfinDetailHeader(store: store, item: series)

                    LazyVStack(alignment: .leading, spacing: 22) {
                        JellyfinMetadataStrip(item: series)

                        if !series.overview.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("jellyfin.overview.title")
                                    .font(.title3.weight(.bold))
                                Text(series.overview)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        JellyfinShelfHeader(
                            titleKey: "jellyfin.episodes.title",
                            count: isLoading ? nil : episodes.count
                        )

                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 36)
                        } else if failed {
                            Button("action.retry") { Task { await loadEpisodes() } }
                                .buttonStyle(.bordered)
                        } else if episodes.isEmpty {
                            JellyfinEmptyState(
                                systemImage: "rectangle.stack.badge.minus",
                                titleKey: "jellyfin.library.empty",
                                detailKey: "jellyfin.library.empty_detail"
                            )
                            .frame(minHeight: 240)
                        } else {
                            ForEach(seasonGroups, id: \.number) { season in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(seasonTitle(season.number))
                                        .font(.headline.weight(.bold))

                                    ForEach(season.episodes) { episode in
                                        NavigationLink {
                                            JellyfinMediaDetailView(store: store, item: episode)
                                        } label: {
                                            JellyfinEpisodeRow(store: store, episode: episode)
                                        }
                                        .buttonStyle(.plain)
                                        if episode.id != season.episodes.last?.id {
                                            Divider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.top, 22)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(series.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEpisodes() }
    }

    private func loadEpisodes() async {
        isLoading = true
        failed = false
        do {
            episodes = try await store.loadEpisodes(seriesID: series.id)
        } catch {
            failed = true
        }
        isLoading = false
    }

    private var seasonGroups: [(number: Int?, episodes: [JellyfinMediaEntry])] {
        let grouped = Dictionary(grouping: episodes, by: \.seasonNumber)
        return grouped
            .map { (number: $0.key, episodes: $0.value) }
            .sorted { ($0.number ?? Int.max) < ($1.number ?? Int.max) }
    }

    private func seasonTitle(_ number: Int?) -> String {
        guard let number else {
            return NSLocalizedString("jellyfin.season.unknown", comment: "")
        }
        if number == 0 {
            return NSLocalizedString("jellyfin.season.specials", comment: "")
        }
        return String.localizedStringWithFormat(
            NSLocalizedString("jellyfin.season.format", comment: ""),
            number
        )
    }
}

private struct JellyfinEpisodeRow: View {
    @ObservedObject var store: JellyfinLibraryStore
    let episode: JellyfinMediaEntry

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .bottomLeading) {
                JellyfinPosterImage(
                    url: store.imageURL(for: episode, width: 480, landscape: true)
                )
                if let progress = episode.progress, progress > 0 {
                    GeometryReader { geometry in
                        VStack {
                            Spacer()
                            Rectangle()
                                .fill(AppTheme.accent)
                                .frame(width: geometry.size.width * progress, height: 3)
                        }
                    }
                }
            }
            .frame(width: 132, height: 76)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(episode.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !episode.subtitle.isEmpty {
                    Text(episode.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct JellyfinMediaDetailView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @State private var playbackRequest: MediaPlaybackRequest?
    @State private var isPreparingPlayback = false
    @State private var showPlaybackError = false
    @State private var pendingExternalPlayback: PendingExternalPlayback?
    @State private var pendingShareRequest: MediaPlaybackRequest?
    @State private var showCredentialHandoffWarning = false
    @State private var sharePayload: ServiceSharePayload?
    @State private var selectedAudioStreamIndex: Int?
    @State private var selectedSubtitleStreamIndex: Int?
    @State private var detailedItem: JellyfinMediaEntry?
    @State private var similarItems: [JellyfinMediaEntry] = []
    @State private var isLoadingDetails = false
    @State private var isOverviewExpanded = false

    init(store: JellyfinLibraryStore, item: JellyfinMediaEntry) {
        self.store = store
        self.item = item
        _selectedAudioStreamIndex = State(initialValue: item.defaultAudioStreamIndex)
        _selectedSubtitleStreamIndex = State(initialValue: item.preferredSubtitleStreamIndex)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    JellyfinDetailHeader(store: store, item: mediaItem)

                    VStack(alignment: .leading, spacing: 26) {
                        JellyfinMetadataStrip(item: mediaItem)

                    if let tagline = mediaItem.tagline, !tagline.isEmpty {
                        Text(tagline)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if mediaItem.isPlayable {
                        if mediaItem.audioTracks.count > 1 || !mediaItem.subtitleTracks.isEmpty {
                            playbackTrackControls
                        }

                        HStack(spacing: 10) {
                            Button(action: preparePlayback) {
                                HStack(spacing: 10) {
                                    if isPreparingPlayback {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "play.fill")
                                    }
                                    Text(
                                        LocalizedStringKey(
                                            (mediaItem.progress ?? 0) > 0
                                                ? "media.continue.title"
                                                : "player.play_in_app"
                                        )
                                    )
                                        .font(.headline.weight(.semibold))
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 54)
                                .background(AppTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)

                            Menu {
                                if !ExternalOpenTarget.installedPlayers.isEmpty {
                                    Section {
                                        ForEach(ExternalOpenTarget.installedPlayers) { target in
                                            Button(target.displayName) {
                                                prepareExternalPlayback(target)
                                            }
                                        }
                                    } header: {
                                        Text("external.installed_players")
                                    }
                                }
                                Section {
                                    Button("external.other_apps") {
                                        prepareSharePlayback()
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.forward.app")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .frame(width: 54, height: 54)
                                    .background(AppTheme.secondarySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .accessibilityLabel(Text("devices.files.open_external"))
                        }
                        .disabled(isPreparingPlayback)
                    }

                    if !mediaItem.overview.isEmpty {
                        JellyfinDetailSection(titleKey: "jellyfin.overview.title") {
                            Text(mediaItem.overview)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineSpacing(5)
                                .lineLimit(isOverviewExpanded ? nil : 6)
                                .fixedSize(horizontal: false, vertical: true)
                            if mediaItem.overview.count > 180 {
                                Button(isOverviewExpanded ? "jellyfin.overview.collapse" : "jellyfin.overview.expand") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isOverviewExpanded.toggle()
                                    }
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                            }
                        }
                    }

                    if !mediaItem.people.isEmpty {
                        JellyfinPeopleShelf(store: store, people: Array(mediaItem.people.prefix(18)))
                    }

                    if !similarItems.isEmpty {
                        JellyfinSimilarShelf(store: store, items: similarItems)
                    }

                    if !mediaItem.studios.isEmpty {
                        JellyfinDetailSection(titleKey: "jellyfin.studios.title") {
                            Text(mediaItem.studios.joined(separator: " · "))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !mediaItem.externalLinks.isEmpty {
                        JellyfinExternalLinksSection(links: mediaItem.externalLinks)
                    }

                    if mediaItem.mediaPath != nil || mediaItem.mediaSize != nil || mediaItem.mediaBitrate != nil {
                        JellyfinFileInformation(item: mediaItem)
                    }

                    if isLoadingDetails {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel(Text("jellyfin.details.loading"))
                    }
                    }
                    .frame(
                        width: min(820, max(geometry.size.width - 36, 0)),
                        alignment: .leading
                    )
                    .padding(.horizontal, 18)
                    .padding(.top, 20)
                    .padding(.bottom, 36)
                    .frame(maxWidth: .infinity)
                }
                .frame(width: geometry.size.width, alignment: .leading)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(mediaItem.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: item.id) {
            await loadDetailContent()
        }
        .alert("jellyfin.player.prepare_failed", isPresented: $showPlaybackError) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text("jellyfin.player.prepare_failed_detail")
        }
        .confirmationDialog(
            "external.credential_warning.title",
            isPresented: $showCredentialHandoffWarning,
            titleVisibility: .visible
        ) {
            Button("external.credential_warning.continue") {
                if let pendingExternalPlayback {
                    openExternalPlayback(pendingExternalPlayback)
                } else if let pendingShareRequest {
                    sharePayload = ServiceSharePayload(url: pendingShareRequest.url)
                }
                pendingExternalPlayback = nil
                pendingShareRequest = nil
            }
            Button("action.cancel", role: .cancel) {
                pendingExternalPlayback = nil
                pendingShareRequest = nil
            }
        } message: {
            Text("external.credential_warning.message")
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .fullScreenCover(item: $playbackRequest, onDismiss: {
            PlayerOrientationController.setPlayerActive(false)
        }) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
    }

    private var mediaItem: JellyfinMediaEntry {
        detailedItem ?? item
    }

    @MainActor
    private func loadDetailContent() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let loadedItem = try await store.loadDetail(itemID: item.id)
            detailedItem = loadedItem
            if selectedAudioStreamIndex == nil {
                selectedAudioStreamIndex = loadedItem.defaultAudioStreamIndex
            }
            if selectedSubtitleStreamIndex == nil {
                selectedSubtitleStreamIndex = loadedItem.preferredSubtitleStreamIndex
            }
        } catch {
            detailedItem = nil
        }
        do {
            similarItems = try await store.loadSimilarItems(itemID: item.id)
        } catch {
            similarItems = []
        }
    }

    private func preparePlayback() {
        Task {
            isPreparingPlayback = true
            defer { isPreparingPlayback = false }
            do {
                let request = try await store.playbackRequest(
                    for: mediaItem,
                    selection: JellyfinPlaybackSelection(
                        audioStreamIndex: selectedAudioStreamIndex,
                        subtitleStreamIndex: selectedSubtitleStreamIndex
                    )
                )
                if let request {
                    PlayerOrientationController.prepareForPresentation(
                        request.initialOrientationMode
                    )
                    playbackRequest = request
                }
            } catch {
                showPlaybackError = true
            }
        }
    }

    private var playbackTrackControls: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 240), spacing: 10, alignment: .leading)],
            alignment: .leading,
            spacing: 10
        ) {
            if mediaItem.audioTracks.count > 1 {
                Menu {
                    ForEach(mediaItem.audioTracks) { track in
                        Button {
                            selectedAudioStreamIndex = track.index
                        } label: {
                            if selectedAudioStreamIndex == track.index {
                                Label(track.title, systemImage: "checkmark")
                            } else {
                                Text(track.title)
                            }
                        }
                    }
                } label: {
                    playbackTrackLabel(
                        systemImage: "waveform",
                        titleKey: "player.audio_tracks",
                        value: mediaItem.audioTracks
                            .first(where: { $0.index == selectedAudioStreamIndex })?
                            .title
                    )
                }
                .frame(maxWidth: .infinity)
            }

            if !mediaItem.subtitleTracks.isEmpty {
                Menu {
                    Button {
                        selectedSubtitleStreamIndex = nil
                    } label: {
                        if selectedSubtitleStreamIndex == nil {
                            Label("player.subtitles.off", systemImage: "checkmark")
                        } else {
                            Text("player.subtitles.off")
                        }
                    }
                    ForEach(mediaItem.subtitleTracks) { track in
                        Button {
                            selectedSubtitleStreamIndex = track.index
                        } label: {
                            if selectedSubtitleStreamIndex == track.index {
                                Label(track.title, systemImage: "checkmark")
                            } else {
                                Text(track.title)
                            }
                        }
                    }
                } label: {
                    playbackTrackLabel(
                        systemImage: "captions.bubble",
                        titleKey: "player.subtitles",
                        value: mediaItem.subtitleTracks
                            .first(where: { $0.index == selectedSubtitleStreamIndex })?
                            .title
                            ?? NSLocalizedString("player.subtitles.off", comment: "")
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playbackTrackLabel(
        systemImage: String,
        titleKey: LocalizedStringKey,
        value: String?
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
            VStack(alignment: .leading, spacing: 1) {
                Text(titleKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value ?? "-")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func prepareExternalPlayback(_ target: ExternalOpenTarget) {
        Task {
            isPreparingPlayback = true
            defer { isPreparingPlayback = false }
            do {
                guard let request = try await store.externalPlaybackRequest(
                    for: mediaItem,
                    selection: JellyfinPlaybackSelection(
                        audioStreamIndex: selectedAudioStreamIndex,
                        subtitleStreamIndex: selectedSubtitleStreamIndex
                    )
                ) else {
                    throw JellyfinLibraryError.missingPlaybackURL
                }
                let pending = PendingExternalPlayback(request: request, target: target)
                if request.containsSensitiveCredential {
                    pendingExternalPlayback = pending
                    showCredentialHandoffWarning = true
                } else {
                    openExternalPlayback(pending)
                }
            } catch {
                showPlaybackError = true
            }
        }
    }

    private func prepareSharePlayback() {
        Task {
            isPreparingPlayback = true
            defer { isPreparingPlayback = false }
            do {
                guard let request = try await store.externalPlaybackRequest(
                    for: mediaItem,
                    selection: JellyfinPlaybackSelection(
                        audioStreamIndex: selectedAudioStreamIndex,
                        subtitleStreamIndex: selectedSubtitleStreamIndex
                    )
                ) else {
                    throw JellyfinLibraryError.missingPlaybackURL
                }
                if request.containsSensitiveCredential {
                    pendingExternalPlayback = nil
                    pendingShareRequest = request
                    showCredentialHandoffWarning = true
                } else {
                    sharePayload = ServiceSharePayload(url: request.url)
                }
            } catch {
                showPlaybackError = true
            }
        }
    }

    private func openExternalPlayback(_ pending: PendingExternalPlayback) {
        guard let targetURL = pending.target.url(
            endpoint: pending.request.url,
            filename: pending.request.externalFilename,
            subtitleURL: pending.request.externalSubtitleURL
        ) else {
            recordExternalHandoff(accepted: false, pending: pending, reason: "invalidCallbackURL")
            sharePayload = ServiceSharePayload(url: pending.request.url)
            return
        }
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            recordExternalHandoff(
                accepted: accepted,
                pending: pending,
                reason: accepted ? "accepted" : "applicationRejectedURL"
            )
            if !accepted {
                DispatchQueue.main.async {
                    sharePayload = ServiceSharePayload(url: pending.request.url)
                }
            }
        }
    }

    private func recordExternalHandoff(
        accepted: Bool,
        pending: PendingExternalPlayback,
        reason: String
    ) {
        DiagnosticLogStore.shared.record(
            accepted ? .info : .error,
            categoryKey: "diagnostics.category.media",
            messageKey: accepted
                ? "diagnostics.media.external_handoff_accepted"
                : "diagnostics.media.external_handoff_failed",
            details: [
                "targetApp": pending.target.diagnosticName,
                "extension": pending.request.fileExtensionHint.isEmpty
                    ? "-"
                    : pending.request.fileExtensionHint,
                "mode": pending.request.fileExtensionHint == "m3u8"
                    ? "serverNegotiatedHLS"
                    : "serverNegotiatedMedia",
                "reason": reason
            ]
        )
    }
}

private struct PendingExternalPlayback {
    let request: MediaPlaybackRequest
    let target: ExternalOpenTarget
}

private struct JellyfinDetailHeader: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(
                url: store.imageURL(
                    for: item,
                    width: 1600,
                    landscape: true,
                    prefersBackdrop: true
                )
            )
            LinearGradient(
                colors: [.black.opacity(0.08), .clear, .black.opacity(0.86)],
                startPoint: .top,
                endPoint: .bottom
            )
            HStack(alignment: .bottom, spacing: 14) {
                if item.imageTag != nil {
                    JellyfinPosterImage(
                        url: store.imageURL(for: item, width: 360),
                        scalesToFit: true
                    )
                    .frame(width: horizontalSizeClass == .regular ? 118 : 92)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .background(Color.black.opacity(0.24))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 0.5)
                    }
                    .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                    if !item.subtitle.isEmpty {
                        Text(item.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(2)
                    }
                    if let originalTitle = item.originalTitle,
                       !originalTitle.isEmpty,
                       originalTitle.caseInsensitiveCompare(item.title) != .orderedSame {
                        Text(originalTitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: horizontalSizeClass == .regular ? 390 : 310)
        .overlay(alignment: .topTrailing) {
            Button {
                Task { await store.toggleFavorite(item) }
            } label: {
                Image(systemName: store.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(store.isFavorite(item) ? AppTheme.accent : .white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("jellyfin.favorite.toggle"))
            .padding(.top, 12)
            .padding(.trailing, 12)
        }
    }
}

private struct JellyfinMetadataStrip: View {
    let item: JellyfinMediaEntry

    var body: some View {
        if hasMetadata {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 132), spacing: 14, alignment: .leading)],
                alignment: .leading,
                spacing: 12
            ) {
                if let communityRating = item.communityRating {
                    JellyfinMetadataFact(
                        value: communityRating.formatted(.number.precision(.fractionLength(1))),
                        systemImage: "star.fill",
                        iconColor: .yellow
                    )
                }
                if let officialRating = item.officialRating, !officialRating.isEmpty {
                    JellyfinMetadataFact(value: officialRating, systemImage: "person.crop.rectangle")
                }
                if let videoDescription = item.videoDescription, !videoDescription.isEmpty {
                    JellyfinMetadataFact(value: videoDescription, systemImage: "film")
                }
                if let audioDescription = item.audioDescription, !audioDescription.isEmpty {
                    JellyfinMetadataFact(value: audioDescription, systemImage: "speaker.wave.2")
                }
                if let premiereDate = item.premiereDate {
                    JellyfinMetadataFact(
                        value: premiereDate.formatted(date: .abbreviated, time: .omitted),
                        systemImage: "calendar"
                    )
                } else if let productionYear = item.productionYear {
                    JellyfinMetadataFact(value: String(productionYear), systemImage: "calendar")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if !item.genres.isEmpty {
                Label(item.genres.joined(separator: " · "), systemImage: "tag")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var hasMetadata: Bool {
        item.communityRating != nil
            || item.officialRating?.isEmpty == false
            || !item.genres.isEmpty
            || item.videoDescription?.isEmpty == false
            || item.audioDescription?.isEmpty == false
            || item.productionYear != nil
            || item.premiereDate != nil
    }
}

private struct JellyfinMetadataFact: View {
    let value: String
    let systemImage: String
    var iconColor: Color = .secondary

    var body: some View {
        Label {
            Text(value)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JellyfinDetailSection<Content: View>: View {
    let titleKey: LocalizedStringKey
    let content: Content

    init(titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titleKey)
                .font(.title3.weight(.bold))
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct JellyfinPeopleShelf: View {
    @ObservedObject var store: JellyfinLibraryStore
    let people: [JellyfinPersonEntry]

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.people.title") {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(people) { person in
                        VStack(alignment: .leading, spacing: 7) {
                            JellyfinPosterImage(url: store.personImageURL(for: person, width: 280))
                                .frame(width: 104, height: 132)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            Text(person.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(person.role.flatMap { $0.isEmpty ? nil : $0 } ?? (person.type ?? ""))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .frame(width: 104, alignment: .leading)
                    }
                }
            }
        }
    }
}

private struct JellyfinSimilarShelf: View {
    @ObservedObject var store: JellyfinLibraryStore
    let items: [JellyfinMediaEntry]

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.similar.title") {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink {
                            JellyfinMediaDetailView(store: store, item: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                JellyfinPosterImage(url: store.imageURL(for: item, width: 360))
                                    .frame(width: 126, height: 186)
                                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                Text(item.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)
                                if !item.subtitle.isEmpty {
                                    Text(item.subtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(width: 126, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct JellyfinExternalLinksSection: View {
    let links: [JellyfinExternalLink]

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.links.title") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(links) { link in
                        Link(destination: link.url) {
                            Label(link.name, systemImage: "arrow.up.right.square")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                }
            }
        }
    }
}

private struct JellyfinFileInformation: View {
    let item: JellyfinMediaEntry

    var body: some View {
        JellyfinDetailSection(titleKey: "jellyfin.file.title") {
            VStack(spacing: 0) {
                if let path = item.mediaPath, !path.isEmpty {
                    row(titleKey: "jellyfin.file.name", value: URL(fileURLWithPath: path).lastPathComponent)
                }
                if let container = item.container, !container.isEmpty {
                    row(titleKey: "jellyfin.file.container", value: container.uppercased())
                }
                if let size = item.mediaSize, size > 0 {
                    row(
                        titleKey: "jellyfin.file.size",
                        value: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
                    )
                }
                if let bitrate = item.mediaBitrate, bitrate > 0 {
                    row(
                        titleKey: "jellyfin.file.bitrate",
                        value: String(format: "%.1f Mbps", Double(bitrate) / 1_000_000)
                    )
                }
            }
            .background(AppTheme.secondarySurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func row(titleKey: LocalizedStringKey, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(titleKey)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct MediaLibraryView: View {
    let service: LaunchpadService
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore

    var body: some View {
        Group {
            if service.isJellyfin,
               let endpoint = effectiveJellyfinEndpoint {
                JellyfinLibraryView(
                    service: service,
                    endpoint: endpoint,
                    allowsSelfSignedCertificates: jellyfinEndpointCandidates.contains { candidate in
                        ServiceCertificatePolicy.allowsBypass(
                            for: candidate,
                            session: connectionStore.dsmSession
                        )
                    },
                    dsmSession: connectionStore.dsmSession,
                    dsmSharedFolderPaths: dataStore.files
                        .filter { $0.kind == .folder }
                        .map(\.path),
                    fallbackEndpoints: jellyfinEndpointCandidates
                )
            } else {
                fallbackLibrary
            }
        }
        .navigationTitle(service.name)
    }

    private var effectiveJellyfinEndpoint: URL? {
        ServiceEndpointOverrides.load(
            service: service,
            deviceHost: connectionStore.dsmSession?.baseURL.host
        ) ?? service.preferredEndpoint(for: connectionStore.dsmSession?.baseURL)
    }

    private var jellyfinEndpointCandidates: [URL] {
        [effectiveJellyfinEndpoint, service.endpoint, service.alternateEndpoint].compactMap { $0 }
    }

    private var fallbackLibrary: some View {
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

            if libraryItems.isEmpty {
                Section {
                    if let endpoint = service.preferredEndpoint(for: connectionStore.dsmSession?.baseURL) {
                        NavigationLink {
                            ServiceWebUIView(
                                service: service,
                                endpoint: endpoint,
                                allowsSelfSignedCertificates: ServiceCertificatePolicy.allowsBypass(
                                    for: endpoint,
                                    session: connectionStore.dsmSession
                                ),
                                dsmSession: nil
                            )
                        } label: {
                            MediaActionRow(
                                titleKey: "media.service.open_web",
                                detail: endpoint.absoluteString,
                                systemImage: "safari"
                            )
                        }
                    }

                } header: {
                    Text("media.service.entry")
                }
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
    }

    private var libraryItems: [MediaItem] {
        service.name == "Navidrome" ? dataStore.audioLibraryItems : dataStore.videoLibraryItems
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
                if items.isEmpty {
                    ForEach(emptyRows) { row in
                        MediaPlaceholderRow(row: row)
                    }
                } else {
                    ForEach(items) { item in
                        NavigationLink {
                            MediaItemDetailView(service: service, item: item)
                        } label: {
                            MediaItemRow(item: item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(shelf.titleKey)
    }

    private var emptyRows: [MediaPlaceholderEntry] {
        [
            MediaPlaceholderEntry(
                titleKey: service.name == "Navidrome" ? "media.albums.title" : "media.movies.title",
                detailKey: "media.service.open_web",
                systemImage: service.name == "Navidrome" ? "music.note" : "film"
            ),
            MediaPlaceholderEntry(
                titleKey: "media.search.title",
                detailKey: "media.library.requires_integration",
                systemImage: "magnifyingglass"
            )
        ]
    }
}

private struct MediaActionRow: View {
    let titleKey: LocalizedStringKey
    let detail: String?
    let detailKey: LocalizedStringKey?
    let systemImage: String

    init(titleKey: LocalizedStringKey, detail: String, systemImage: String) {
        self.titleKey = titleKey
        self.detail = detail
        self.detailKey = nil
        self.systemImage = systemImage
    }

    init(titleKey: LocalizedStringKey, detailKey: LocalizedStringKey, systemImage: String) {
        self.titleKey = titleKey
        self.detail = nil
        self.detailKey = detailKey
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
                .frame(width: 34, height: 34)
                .background(AppTheme.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(titleKey)
                    .font(.body.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else if let detailKey {
                    Text(detailKey)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct MediaPlaceholderEntry: Identifiable {
    let id = UUID()
    let titleKey: LocalizedStringKey
    let detailKey: LocalizedStringKey
    let systemImage: String
}

private struct MediaPlaceholderRow: View {
    let row: MediaPlaceholderEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: row.systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(width: 38, height: 38)
                .background(AppTheme.secondarySurface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(row.titleKey)
                    .font(.body.weight(.medium))
                Text(row.detailKey)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 3)
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
    @State private var messageKey = "external.open_failed"
    @State private var showHint = false
    @State private var sharePayload: MediaSharePayload?

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
                NavigationLink {
                    DirectMediaPlayerSetupView(suggestedURL: suggestedStreamURL)
                } label: {
                    Label("player.play_in_app", systemImage: "play.fill")
                }
                Button {
                    showPlayerPicker = true
                } label: {
                    Label("service.action.open_external", systemImage: "arrow.up.forward.app")
                }
            } header: {
                Text("media.item.actions")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.title)
        .confirmationDialog("service.external.title", isPresented: $showPlayerPicker) {
            if item.kind == .video {
                Button("Infuse") { openExternal(.infuse) }
                Button("VidHub") { openExternal(.vidhub) }
                Button("VLC") { openExternal(.vlc) }
            } else {
                Button("VLC") { openExternal(.vlc) }
            }
            Button("external.other_apps") { presentShareSheet() }
            Button("action.cancel", role: .cancel) {}
        }
        .alert(LocalizedStringKey(messageKey), isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        guard let targetURL = target.url(endpoint: suggestedStreamURL, filename: item.title) else {
            showFailure("external.unsupported_hint")
            return
        }
        showPlayerPicker = false
        UIApplication.shared.open(targetURL, options: [:]) { accepted in
            guard !accepted else { return }
            DispatchQueue.main.async {
                showFailure(target.failureMessageKey)
            }
        }
    }

    private func presentShareSheet() {
        guard let suggestedStreamURL else {
            showFailure("external.unsupported_hint")
            return
        }
        showPlayerPicker = false
        sharePayload = MediaSharePayload(url: suggestedStreamURL)
    }

    private func showFailure(_ key: String) {
        messageKey = key
        showHint = true
    }

    private var suggestedStreamURL: URL? {
        guard let url = URL(string: item.path), DirectMediaURLPolicy.canAttemptPlayback(url) else {
            return nil
        }
        return url
    }
}

private struct MediaSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

private struct NASConnectionWelcomeView: View {
    let addNASAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "server.rack")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(AppTheme.primaryAction)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("connect.welcome.title")
                        .font(.title2.weight(.bold))
                    Text("connect.welcome.subtitle")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: addNASAction) {
                    Label("connect.welcome.action", systemImage: "plus")
                }
                .buttonStyle(NastartPrimaryButtonStyle())

                Label("connect.welcome.security", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 34)
        }
        .background(AppTheme.groupedBackground)
    }
}

private struct ManualServiceEditorView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    @State private var category: ServiceCategory = .tools
    @State private var showsValidationError = false

    var body: some View {
        Form {
            Section {
                Text("manual.service.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                TextField("manual.service.name.placeholder", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                TextField("manual.service.url.placeholder", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                Picker("manual.service.category", selection: $category) {
                    ForEach(ServiceCategory.defaultOrder.filter { $0 != .favorites }) { category in
                        Label(LocalizedStringKey(category.titleKey), systemImage: category.symbolName)
                            .tag(category)
                    }
                }
            } footer: {
                Text("manual.service.footer")
            }
        }
        .navigationTitle("manual.service.add")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("action.save") {
                    guard let endpoint = normalizedURL, !normalizedName.isEmpty else {
                        showsValidationError = true
                        return
                    }
                    dataStore.addManualService(
                        name: normalizedName,
                        endpoint: endpoint,
                        category: category,
                        iconText: ""
                    )
                    dismiss()
                }
            }
        }
        .alert("manual.service.invalid", isPresented: $showsValidationError) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedURL: URL? {
        UserConfiguredServiceURLPolicy.normalizedURL(from: address)
    }
}

private enum DSMConnectionLocation: String, CaseIterable, Identifiable {
    case local
    case remote

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .local: return "connect.location.local"
        case .remote: return "connect.location.remote"
        }
    }
}

private enum DSMConnectionProtocol: String, CaseIterable, Identifiable {
    case http
    case https

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
}

private struct DSMConnectionFlowView: View {
    let onConnected: () -> Void
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var host = ""
    @State private var account = ""
    @State private var password = ""
    @State private var oneTimeCode = ""
    @State private var connectionLocation: DSMConnectionLocation = .local
    @State private var connectionProtocol: DSMConnectionProtocol = .https
    @State private var allowsSelfSignedCertificates = false
    @State private var isConnecting = false
    @State private var connectionStatusKey = "connect.review.authenticating"
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showFinishHint = false
    @State private var connectionTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "externaldrive.connected.to.line.below")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                    Text("connect.title")
                        .font(.title2.weight(.bold))
                    Text("connect.subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("connect.section.dsm")
                        .font(.headline)

                    Picker("connect.location", selection: $connectionLocation) {
                        ForEach(DSMConnectionLocation.allCases) { location in
                            Text(LocalizedStringKey(location.titleKey)).tag(location)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: connectionLocation) { location in
                        if location == .remote {
                            connectionProtocol = .https
                        }
                    }

                    Picker("connect.protocol", selection: $connectionProtocol) {
                        ForEach(DSMConnectionProtocol.allCases) { connectionProtocol in
                            Text(connectionProtocol.title).tag(connectionProtocol)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(connectionLocation == .remote)

                    if connectionLocation == .local {
                        NavigationLink {
                            LANDiscoveryView(selectedHost: $host)
                        } label: {
                            Label("connect.scan.title", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Divider()
                    }

                    connectionFieldLabel("connect.host")
                    TextField(LocalizedStringKey(hostExampleKey), text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .connectionInputStyle()

                    Text(LocalizedStringKey(addressHintKey))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Toggle(isOn: $allowsSelfSignedCertificates) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("connect.trust_self_signed")
                            Text("connect.trust_self_signed.inline_hint")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(connectionProtocol == .http)
                    .onChange(of: connectionProtocol) { connectionProtocol in
                        if connectionProtocol == .http {
                            allowsSelfSignedCertificates = false
                        }
                    }

                    Text("connect.trust_self_signed.protocol_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    connectionFieldLabel("connect.account")
                    TextField("connect.account.example", text: $account)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                        .textContentType(.username)
                        .connectionInputStyle()

                    connectionFieldLabel("connect.password")
                    SecureField("connect.password.example", text: $password)
                        .textContentType(.password)
                        .connectionInputStyle()

                    connectionFieldLabel("connect.otp", optional: true)
                    SecureField("connect.otp.example", text: $oneTimeCode)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .connectionInputStyle()
                }
                .connectionSectionStyle()

                VStack(alignment: .leading, spacing: 14) {
                    Text("connect.section.agent")
                        .font(.headline)
                    Text("connect.agent.not_connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Divider()
                    NavigationLink {
                        AgentSetupGuideView()
                    } label: {
                        Label("connect.agent.guide", systemImage: "shippingbox")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .connectionSectionStyle()

                Button {
                    connectDSM()
                } label: {
                    HStack {
                        if isConnecting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(LocalizedStringKey(isConnecting ? connectionStatusKey : "connect.action"))
                            .font(.headline.weight(.semibold))
                    }
                }
                .buttonStyle(NastartPrimaryButtonStyle())
                .disabled(isConnecting || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || account.isEmpty || password.isEmpty)

                Label("connect.scope.footer", systemImage: "lock.shield")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle("connect.nav")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    connectionTask?.cancel()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel(Text("action.cancel"))
            }
        }
        .alert("connect.review.done", isPresented: $showFinishHint) {
            Button("action.ok", role: .cancel) {
                onConnected()
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
        connectionStatusKey = "connect.review.authenticating"
        errorMessage = ""
        connectionTask = Task {
            do {
                let baseURL = try DSMClient.normalizedBaseURL(
                    from: protocolAdjustedHost,
                    defaultScheme: connectionProtocol.rawValue
                )
                let client = DSMClient(
                    baseURL: baseURL,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates
                )
                let mainSession = try await client.login(
                    account: account,
                    password: password,
                    oneTimeCode: oneTimeCode
                )
                let session = await client.addingFileStationSession(
                    to: mainSession,
                    account: account,
                    password: password,
                    oneTimeCode: oneTimeCode
                )
                await MainActor.run {
                    connectionStatusKey = "connect.review.loading"
                }
                let snapshot = await client.loadSnapshot(session: session, useAgent: false)
                try Task.checkCancellation()
                do {
                    try KeychainStore.shared.saveNASCredential(
                        StoredNASCredential(
                            baseURLString: baseURL.absoluteString,
                            account: account,
                            password: password,
                            useAgent: false,
                            allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                            deviceID: session.deviceID
                        )
                    )
                } catch {
                    await client.logout(session: session)
                    throw error
                }
                await MainActor.run {
                    dataStore.activateDSM(snapshot: snapshot, session: session, useAgent: false)
                    connectionStore.connect(device: snapshot.device, session: session)
                    isConnecting = false
                    connectionTask = nil
                    showFinishHint = true
                }
            } catch is CancellationError {
                await MainActor.run {
                    isConnecting = false
                    connectionTask = nil
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    connectionTask = nil
                    errorMessage = connectionErrorMessage(for: error)
                    showError = true
                }
            }
        }
    }

    private var protocolAdjustedHost: String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            var components = URLComponents(string: trimmed),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            return trimmed
        }
        components.scheme = connectionProtocol.rawValue
        if connectionProtocol == .http, components.port == 5001 {
            components.port = 5000
        } else if connectionProtocol == .https, components.port == 5000 {
            components.port = 5001
        }
        return components.string ?? trimmed
    }

    private var hostExampleKey: String {
        connectionLocation == .local
            ? "connect.host.example.local"
            : "connect.host.example.remote"
    }

    private var addressHintKey: String {
        connectionLocation == .local
            ? "connect.host.hint.local"
            : "connect.host.hint.remote"
    }

    private func connectionErrorMessage(for error: Error) -> String {
        guard let urlError = error as? URLError else {
            return error.localizedDescription
        }
        switch urlError.code {
        case .networkConnectionLost, .cannotConnectToHost, .timedOut, .notConnectedToInternet:
            return NSLocalizedString(
                connectionLocation == .remote
                    ? "connect.error.remote_unreachable"
                    : "connect.error.local_unreachable",
                comment: ""
            )
        case .serverCertificateUntrusted, .serverCertificateHasBadDate,
                .serverCertificateHasUnknownRoot, .secureConnectionFailed:
            return NSLocalizedString("connect.error.certificate", comment: "")
        default:
            return error.localizedDescription
        }
    }

    private func connectionFieldLabel(_ key: String, optional: Bool = false) -> some View {
        HStack(spacing: 6) {
            Text(LocalizedStringKey(key))
                .font(.subheadline.weight(.medium))
            if optional {
                Text("connect.optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, -8)
    }
}

private struct LANDiscoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedHost: String
    @StateObject private var discoveryService = LANDiscoveryService()

    var body: some View {
        List {
            Section {
                Text("connect.scan.description")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            }

            Section {
                if discoveryService.devices.isEmpty {
                    VStack(spacing: 10) {
                        if discoveryService.isSearching {
                            ProgressView()
                            Text("connect.scan.searching")
                        } else {
                            Image(systemName: discoveryService.errorKey == nil ? "server.rack" : "exclamationmark.triangle")
                                .font(.title2)
                            Text(LocalizedStringKey(discoveryService.errorKey ?? "connect.scan.empty"))
                                .multilineTextAlignment(.center)
                            Button("connect.scan.retry") {
                                discoveryService.start()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                } else {
                    ForEach(discoveryService.devices) { device in
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
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            .tint(AppTheme.accent)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } header: {
                Text("connect.scan.results")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.scan.title")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            discoveryService.start()
        }
        .onDisappear {
            discoveryService.stop()
        }
    }
}

private extension View {
    func connectionInputStyle() -> some View {
        self
            .padding(.horizontal, 13)
            .frame(minHeight: 48)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
    }

    func connectionSectionStyle() -> some View {
        self
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct AgentSetupGuideView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var agentAddress = ""
    @State private var pairingCode = ""
    @State private var allowsSelfSignedCertificates = false
    @State private var isPairing = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?
    @State private var showCopyHint = false

    private var desktopCommand: String {
        let host = connectionStore.dsmSession?.baseURL.host ?? "NAS_HOST"
        return "./scripts/install_agent_via_ssh.sh --host \(host) --user SSH_USER --pairing-code 123456"
    }

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
                TextField("agent.address.placeholder", text: $agentAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                TextField("agent.pairing_code.placeholder", text: $pairingCode)
                    .keyboardType(.numberPad)
                Toggle("connect.trust_self_signed", isOn: $allowsSelfSignedCertificates)

                Button {
                    pairAgent()
                } label: {
                    HStack {
                        if isPairing { ProgressView() }
                        Label(
                            connectionStore.usesAgent ? "agent.action.repair" : "agent.action.pair",
                            systemImage: "link"
                        )
                    }
                }
                .disabled(
                    isPairing
                        || agentAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || pairingCode.count != 6
                )

                if connectionStore.usesAgent {
                    LabeledContent("agent.connected_host") {
                        Text(connectionStore.agentConnection?.hostIdentity ?? "-")
                            .foregroundStyle(.green)
                    }
                    Button(role: .destructive) {
                        connectionStore.disconnectAgent()
                        resultMessage = NSLocalizedString("agent.disconnected", comment: "")
                    } label: {
                        Label("agent.action.disconnect", systemImage: "link.badge.minus")
                    }
                }

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("agent.pairing.section")
            } footer: {
                Text("agent.pairing.footer")
            }

            Section {
                AgentStepRow(number: 1, titleKey: "connect.agent.step.package", detailKey: "connect.agent.step.package_detail")
                AgentStepRow(number: 2, titleKey: "connect.agent.step.token", detailKey: "connect.agent.step.token_detail")
                AgentStepRow(number: 3, titleKey: "connect.agent.step.verify", detailKey: "connect.agent.step.verify_detail")

                Text(desktopCommand)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button("connect.agent.copy") {
                    UIPasteboard.general.string = desktopCommand
                    showCopyHint = true
                }
            } header: {
                Text("agent.desktop_ssh.section")
            } footer: {
                Text("agent.desktop_ssh.footer")
            }

            Section {
                NavigationLink {
                    MobileSSHAgentInstallerView()
                } label: {
                    Label("agent.mobile_ssh.title", systemImage: "iphone.and.arrow.forward")
                }
            } header: {
                Text("agent.mobile_ssh.section")
            } footer: {
                Text("agent.mobile_ssh.footer")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.agent.guide")
        .task {
            guard agentAddress.isEmpty, let host = connectionStore.dsmSession?.baseURL.host else { return }
            agentAddress = "http://\(host):8787"
        }
        .alert("connect.agent.copy_hint", isPresented: $showCopyHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private func pairAgent() {
        errorMessage = nil
        resultMessage = nil
        isPairing = true
        Task {
            do {
                guard let url = UserConfiguredServiceURLPolicy.normalizedURL(from: agentAddress) else {
                    throw AgentClientError.invalidAddress
                }
                let client = try AgentClient(
                    baseURL: url,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates
                )
                let connection = try await client.pair(
                    code: pairingCode,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates
                )
                _ = try await client.handshake(connection: connection)
                try await MainActor.run {
                    try connectionStore.connectAgent(connection)
                }
                if let session = connectionStore.dsmSession {
                    await dataStore.refreshDSM(session: session, useAgent: true)
                }
                await MainActor.run {
                    pairingCode = ""
                    resultMessage = NSLocalizedString("agent.pairing.success", comment: "")
                    isPairing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isPairing = false
                }
            }
        }
    }
}

struct MobileSSHAgentInstallerView: View {
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var pairingCode = ""
    @State private var inspectedIdentity: SSHHostIdentity?
    @State private var trustedHostKey: String?
    @State private var isInspecting = false
    @State private var isInstalling = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private var normalizedHost: String {
        let value = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("["), value.hasSuffix("]") else { return value }
        return String(value.dropFirst().dropLast())
    }

    private var sshPort: Int? {
        Int(port).flatMap { (1...65_535).contains($0) ? $0 : nil }
    }

    private var hasTrustedCurrentKey: Bool {
        guard let inspectedIdentity, let trustedHostKey else { return false }
        return inspectedIdentity.openSSHKey == trustedHostKey
    }

    var body: some View {
        Form {
            Section {
                TextField("agent.ssh.host", text: $host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("agent.ssh.port", text: $port)
                    .keyboardType(.numberPad)
                TextField("agent.ssh.username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("agent.ssh.password", text: $password)
                TextField("agent.pairing_code.placeholder", text: $pairingCode)
                    .keyboardType(.numberPad)
            } header: {
                Text("agent.ssh.connection.section")
            } footer: {
                Text("agent.ssh.connection.footer")
            }

            Section {
                Button {
                    inspectHostKey()
                } label: {
                    HStack {
                        if isInspecting { ProgressView() }
                        Label("agent.ssh.inspect", systemImage: "checkmark.shield")
                    }
                }
                .disabled(isInspecting || isInstalling || normalizedHost.isEmpty || sshPort == nil)

                if let identity = inspectedIdentity {
                    LabeledContent("agent.ssh.fingerprint") {
                        Text(identity.fingerprint)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    if hasTrustedCurrentKey {
                        Label("agent.ssh.trusted", systemImage: "checkmark.shield.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button("agent.ssh.trust") {
                            trustInspectedHostKey()
                        }
                    }
                }
            } header: {
                Text("agent.ssh.host_key.section")
            } footer: {
                Text("agent.ssh.host_key.footer")
            }

            Section {
                Button {
                    installAndPair()
                } label: {
                    HStack {
                        if isInstalling { ProgressView() }
                        Label("agent.ssh.install", systemImage: "shippingbox.and.arrow.backward")
                    }
                }
                .disabled(
                    isInstalling
                        || !hasTrustedCurrentKey
                        || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || password.isEmpty
                        || pairingCode.count != 6
                )

                if let resultMessage {
                    Label(resultMessage, systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("agent.ssh.install.section")
            } footer: {
                Text("agent.ssh.install.footer")
            }
        }
        .navigationTitle("agent.mobile_ssh.title")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard host.isEmpty, let dsmHost = connectionStore.dsmSession?.baseURL.host else { return }
            host = dsmHost
            reloadTrustedHostKey()
        }
        .onChange(of: host) { _ in
            inspectedIdentity = nil
            reloadTrustedHostKey()
        }
        .onChange(of: port) { _ in
            inspectedIdentity = nil
            reloadTrustedHostKey()
        }
    }

    private func reloadTrustedHostKey() {
        guard let sshPort, !normalizedHost.isEmpty else {
            trustedHostKey = nil
            return
        }
        trustedHostKey = KeychainStore.shared.loadSSHHostKey(host: normalizedHost, port: sshPort)
    }

    private func inspectHostKey() {
        guard let sshPort else { return }
        isInspecting = true
        errorMessage = nil
        resultMessage = nil
        Task {
            do {
                let identity = try await SSHAgentInstaller.inspectHost(host: normalizedHost, port: sshPort)
                await MainActor.run {
                    inspectedIdentity = identity
                    reloadTrustedHostKey()
                    isInspecting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isInspecting = false
                }
            }
        }
    }

    private func trustInspectedHostKey() {
        guard let identity = inspectedIdentity, let sshPort else { return }
        do {
            try KeychainStore.shared.saveSSHHostKey(
                identity.openSSHKey,
                host: normalizedHost,
                port: sshPort
            )
            trustedHostKey = identity.openSSHKey
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func installAndPair() {
        guard let sshPort, let trustedHostKey else { return }
        isInstalling = true
        errorMessage = nil
        resultMessage = nil
        let installationPassword = password
        Task {
            do {
                _ = try await SSHAgentInstaller.install(
                    host: normalizedHost,
                    port: sshPort,
                    username: username,
                    password: installationPassword,
                    pairingCode: pairingCode,
                    trustedHostKey: trustedHostKey
                )
                var components = URLComponents()
                components.scheme = "http"
                components.host = normalizedHost
                components.port = 8_787
                guard let baseURL = components.url else {
                    throw AgentClientError.invalidAddress
                }
                let client = try AgentClient(baseURL: baseURL, allowsSelfSignedCertificates: false)
                let connection = try await client.pair(
                    code: pairingCode,
                    allowsSelfSignedCertificates: false
                )
                _ = try await client.handshake(connection: connection)
                try await MainActor.run {
                    try connectionStore.connectAgent(connection)
                }
                if let session = connectionStore.dsmSession {
                    await dataStore.refreshDSM(session: session, useAgent: true)
                }
                await MainActor.run {
                    password = ""
                    pairingCode = ""
                    resultMessage = NSLocalizedString("agent.ssh.install.success", comment: "")
                    isInstalling = false
                }
                DiagnosticLogStore.shared.record(
                    .info,
                    categoryKey: "diagnostics.category.agent",
                    messageKey: "diagnostics.agent.install_succeeded"
                )
            } catch {
                await MainActor.run {
                    password = ""
                    errorMessage = error.localizedDescription
                    isInstalling = false
                }
                DiagnosticLogStore.shared.record(
                    .warning,
                    categoryKey: "diagnostics.category.agent",
                    messageKey: "diagnostics.agent.install_failed",
                    details: ["error": String(describing: error)]
                )
            }
        }
    }
}

struct AgentStepRow: View {
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

private extension ServiceStatus {
    var titleKey: String {
        switch self {
        case .online: return "status.online"
        case .installed: return "status.installed"
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

private struct LiveUptimeText: View {
    let baseMinutes: Int
    @State private var startedAt = Date()

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 60)) { context in
            Text(displayText(at: context.date))
        }
    }

    private func displayText(at date: Date) -> String {
        let elapsedMinutes = max(0, Int(date.timeIntervalSince(startedAt)) / 60)
        return NASUptimeFormatter.string(totalMinutes: baseMinutes + elapsedMinutes)
    }
}

private struct DeviceSummaryPanel: View {
    let device: NASDevice
    let compact: Bool
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label {
                    Text(LocalizedStringKey(summaryKey))
                } icon: {
                    Image(systemName: summarySymbol)
                }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                if let uptimeMinutes = device.uptimeMinutes {
                    LiveUptimeText(baseMinutes: uptimeMinutes)
                        .id(device.id)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            if compact {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), symbolName: "cpu"),
                    MetricPillSpec("metric.memory_ram", value: launchpadPercentText(device.memory), symbolName: "memorychip"),
                    MetricPillSpec("metric.storage_disk", value: launchpadPercentText(device.storageUsed), symbolName: "internaldrive")
                ])
            } else {
                MetricPillRow(metrics: [
                    MetricPillSpec("metric.cpu", value: launchpadPercentText(device.cpu), progress: device.cpu, symbolName: "cpu"),
                    MetricPillSpec("metric.memory_ram", value: launchpadPercentText(device.memory), progress: device.memory, symbolName: "memorychip"),
                    MetricPillSpec("metric.storage_disk", value: launchpadPercentText(device.storageUsed), progress: device.storageUsed, symbolName: "internaldrive")
                ])
            }
        }
        .padding(14)
        .nastartCard(cornerRadius: 22)
    }

    private var summaryKey: String {
        guard isConnected else { return "state.not_connected" }
        return hasWarning ? "status.warning" : "launchpad.summary.normal"
    }

    private var summarySymbol: String {
        guard isConnected else { return "wifi.slash" }
        return hasWarning ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
    }

    private var hasWarning: Bool {
        device.certificateDaysRemaining.map { $0 <= LaunchpadReminderPolicy.certificateWarningDays } == true
            || [device.cpu, device.memory, device.storageUsed].compactMap { $0 }.contains { $0 >= 0.9 }
    }
}

private func launchpadPercentText(_ value: Double?) -> String {
    guard let value else { return "-" }
    return "\(Int((value * 100).rounded()))%"
}

private func launchpadServicePercentText(_ value: Double?) -> String {
    guard let value else { return "-" }
    let percentage = value * 100
    if percentage > 0, percentage < 10 {
        return String(format: "%.1f%%", percentage)
    }
    return "\(Int(percentage.rounded()))%"
}

import SwiftUI
import UIKit
import WebKit
import SafariServices
import AVFoundation
import AVKit
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
    @State private var showAddOptions = false
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
            .confirmationDialog("launchpad.add.title", isPresented: $showAddOptions) {
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
                Button("action.cancel", role: .cancel) {}
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
                    Button {
                        if connectionStore.isConnected || !launchpadServices.isEmpty {
                            showAddOptions = true
                        } else {
                            showConnectionFlow = true
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
            ProductLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
        case .commandCenter:
            CommandCenterLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
        case .glassDeck:
            GlassDeckLaunchpad(device: dataStore.device, services: launchpadServices, categories: orderedCategories, options: displayOptions, groupDefaultExpanded: isGroupExpandedByDefault)
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
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassHeroPanel(device: device, compact: options.compactMetrics)

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

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 16) {
            HStack {
                Label("launchpad.summary.normal", systemImage: "checkmark.circle.fill")
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
    let groupDefaultExpanded: (ServiceCategory) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DeviceSummaryPanel(device: device, compact: options.compactMetrics)

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
                            allowsSelfSignedCertificates: connectionStore.dsmSession?.allowsSelfSignedCertificates == true,
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

private enum ServiceEndpointOverrides {
    static func load(service: LaunchpadService, deviceHost: String?) -> URL? {
        guard
            let value = UserDefaults.standard.string(forKey: key(service: service, deviceHost: deviceHost))
        else {
            return nil
        }
        return URL(string: value)
    }

    static func save(_ url: URL?, service: LaunchpadService, deviceHost: String?) {
        let storageKey = key(service: service, deviceHost: deviceHost)
        if let url {
            UserDefaults.standard.set(url.absoluteString, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private static func key(service: LaunchpadService, deviceHost: String?) -> String {
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
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else {
            return nil
        }
        return components.url
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

enum ExternalOpenTarget {
    case safari
    case infuse
    case vidhub
    case vlc

    func url(endpoint: URL?, filename: String? = nil) -> URL? {
        switch self {
        case .safari:
            return endpoint
        case .infuse:
            return callbackURL(
                scheme: "infuse",
                action: "play",
                endpoint: endpoint,
                filename: filename
            )
        case .vidhub:
            return callbackURL(scheme: "open-vidhub", action: "open", endpoint: endpoint)
        case .vlc:
            return callbackURL(scheme: "vlc-x-callback", action: "stream", endpoint: endpoint)
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

    var diagnosticName: String {
        switch self {
        case .safari: return "Safari"
        case .infuse: return "Infuse"
        case .vidhub: return "VidHub"
        case .vlc: return "VLC"
        }
    }

    private func callbackURL(
        scheme: String,
        action: String,
        endpoint: URL?,
        filename: String? = nil
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
        components.queryItems = queryItems
        return components.url
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
        .fullScreenCover(item: $playbackRequest) { request in
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
            host.caseInsensitiveCompare(dsmSession.baseURL.host ?? "") == .orderedSame
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
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
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
      hasLoginForm: Boolean(document.querySelector('input[type="password"]')),
      hasWorkbench: Boolean(document.querySelector('.monaco-workbench')),
      nuxtChildCount: document.querySelector('#__nuxt')?.children?.length || 0,
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
            guard
                challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
                let trust = challenge.protectionSpace.serverTrust,
                parent.allowsSelfSignedCertificates,
                challenge.protectionSpace.host.caseInsensitiveCompare(parent.url.host ?? "") == .orderedSame
            else {
                completionHandler(.performDefaultHandling, nil)
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let credential = URLCredential(trust: trust)
                completionHandler(.useCredential, credential)
            }
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
                    let hasLoginForm = (values["hasLoginForm"] as? NSNumber)?.boolValue ?? false
                    let hasWorkbench = (values["hasWorkbench"] as? NSNumber)?.boolValue ?? false
                    let nuxtChildCount = (values["nuxtChildCount"] as? NSNumber)?.intValue ?? 0
                    let codeServerVersion = values["codeServerVersion"] as? String ?? ""
                    let hasRenderedContent: Bool
                    if self.parent.expectsDeveloperWorkbench {
                        hasRenderedContent = hasLoginForm || hasWorkbench
                    } else if self.parent.expectsMetaCubeDashboard {
                        hasRenderedContent = nuxtChildCount > 0 && bodyTextLength > 0
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
                            "loginForm": hasLoginForm ? "yes" : "no",
                            "workbench": hasWorkbench ? "yes" : "no",
                            "nuxtChildCount": "\(nuxtChildCount)",
                            "codeServerVersion": codeServerVersion.isEmpty ? "-" : codeServerVersion,
                            "rendered": hasRenderedContent ? "yes" : "no"
                        ]
                    )

                    if hasRenderedContent {
                        if trigger == "commitTimeout", self.parent.prefersCompatibilityFallback {
                            self.requestCompatibilityFallbackIfNeeded(
                                webView: webView,
                                reason: "loadTimeout"
                            )
                            return
                        }
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

struct MediaPlaybackRequest: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
    let allowsSelfSignedCertificates: Bool
    let source: MediaPlaybackSource
    let fileExtensionOverride: String?

    init(
        url: URL,
        title: String,
        allowsSelfSignedCertificates: Bool = false,
        source: MediaPlaybackSource = .directURL,
        fileExtensionOverride: String? = nil
    ) {
        self.url = url
        self.title = title
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
        self.source = source
        self.fileExtensionOverride = fileExtensionOverride
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
        case "mp3": return "audio/mpeg"
        case "m4a", "aac": return "audio/mp4"
        case "wav": return "audio/wav"
        default: return nil
        }
    }

    var allowsExternalHandoff: Bool {
        source == .directURL
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

private enum MediaPlaybackProbe {
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
            let (data, response) = try await session.data(for: request)
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
               let playlist = String(data: data, encoding: .utf8),
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
        [
            "target": DiagnosticLogStore.redactedURL(playback.url),
            "source": playback.source.rawValue,
            "extension": playback.fileExtensionHint.isEmpty ? "-" : playback.fileExtensionHint,
            "selfSigned": playback.allowsSelfSignedCertificates ? "on" : "off",
            "compatibilityEngine": MediaPlaybackPolicy.hasCompatibilityEngine ? "available" : "unavailable"
        ]
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
        do {
            let (data, response) = try await session.data(for: request)
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
                    "bytesReceived": "\(data.count)"
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

    static func preferredEngine(for request: MediaPlaybackRequest) -> MediaPlaybackEngine {
        guard hasCompatibilityEngine else { return .system }
        let fileExtension = request.fileExtensionHint
        guard !fileExtension.isEmpty else { return .system }
        return systemPreferredExtensions.contains(fileExtension) ? .system : .compatibility
    }

    static func requiresCompatibilityEngine(for request: MediaPlaybackRequest) -> Bool {
        let fileExtension = request.fileExtensionHint
        return !fileExtension.isEmpty && !systemPreferredExtensions.contains(fileExtension)
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
        .fullScreenCover(item: $playbackRequest) { request in
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
    private let request: MediaPlaybackRequest
    private var statusObservation: NSKeyValueObservation?
    private var timeControlObservation: NSKeyValueObservation?
    private var lastTimeControlStatus: AVPlayer.TimeControlStatus?

    init(request: MediaPlaybackRequest) {
        self.request = request
        let options: [String: Any]? = request.mimeTypeHint.map {
            ["AVURLAssetOutOfBandMIMETypeKey": $0 as Any]
        }
        let asset = AVURLAsset(url: request.url, options: options)
        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
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
        }
    }

    func play() {
        activateIfNeeded()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
    }

    func pause() {
        player.pause()
    }

    deinit {
        statusObservation?.invalidate()
        timeControlObservation?.invalidate()
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
    @State private var externalMessageKey = "external.open_failed"
    @State private var showExternalHint = false

    init(request: MediaPlaybackRequest) {
        self.request = request
        _session = StateObject(wrappedValue: MediaPlayerSession(request: request))
        _activeEngine = State(initialValue: MediaPlaybackPolicy.preferredEngine(for: request))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch activeEngine {
            case .system:
                SystemPlayerController(player: session.player)
                    .ignoresSafeArea(edges: .bottom)

                if let errorMessage = session.errorMessage,
                   !MediaPlaybackPolicy.hasCompatibilityEngine {
                    playbackErrorView(
                        MediaPlaybackPolicy.requiresCompatibilityEngine(for: request)
                            ? NSLocalizedString("player.compatibility_unavailable", comment: "")
                            : errorMessage
                    )
                }
            case .compatibility:
#if canImport(MobileVLCKit)
                VLCBuiltInPlayerView(request: request) {
                    if request.allowsExternalHandoff {
                        showExternalPicker = true
                    }
                }
#else
                playbackErrorView(NSLocalizedString("player.compatibility_unavailable", comment: ""))
#endif
            }
        }
        .navigationTitle(request.title.isEmpty ? "player.title" : request.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("action.done") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
#if canImport(MobileVLCKit)
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
#endif
                if request.allowsExternalHandoff {
                    Button {
                        showExternalPicker = true
                    } label: {
                        Image(systemName: "arrow.up.forward.app")
                    }
                    .accessibilityLabel(Text("devices.files.open_external"))
                }
            }
        }
        .confirmationDialog("service.external.title", isPresented: $showExternalPicker) {
            Button("Infuse") { openExternal(.infuse) }
            Button("VidHub") { openExternal(.vidhub) }
            Button("VLC") { openExternal(.vlc) }
            Button("external.browser") { openExternal(.safari) }
            Button("external.other_apps") {
                sharePayload = ServiceSharePayload(url: request.url)
            }
            Button("action.cancel", role: .cancel) {}
        }
        .sheet(item: $sharePayload) { payload in
            SystemShareView(items: [payload.url])
        }
        .alert(LocalizedStringKey(externalMessageKey), isPresented: $showExternalHint) {
            Button("action.ok", role: .cancel) {}
        }
        .onAppear {
            PlayerOrientationController.setPlayerActive(true)
            if activeEngine == .system {
                session.play()
            }
        }
        .task {
            await MediaPlaybackProbe.run(request)
        }
        .task(id: activeEngine) {
            guard
                activeEngine == .system,
                MediaPlaybackPolicy.hasCompatibilityEngine,
                !didAutomaticallyFallback
            else {
                return
            }
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard
                !Task.isCancelled,
                activeEngine == .system,
                !session.isReady,
                session.errorMessage == nil,
                !didAutomaticallyFallback
            else {
                return
            }
            DiagnosticLogStore.shared.record(
                .warning,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_fallback",
                details: [
                    "from": "AVPlayer",
                    "to": "MobileVLCKit",
                    "reason": "readyTimeout"
                ]
            )
            didAutomaticallyFallback = true
            selectEngine(.compatibility)
        }
        .onDisappear {
            session.pause()
            PlayerOrientationController.setPlayerActive(false)
        }
        .onChange(of: session.errorMessage) { errorMessage in
            guard
                errorMessage != nil,
                activeEngine == .system,
                MediaPlaybackPolicy.hasCompatibilityEngine,
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
                Text("jellyfin.player.retry_hint")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
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

    private func selectEngine(_ engine: MediaPlaybackEngine) {
        guard activeEngine != engine else { return }
        didAutomaticallyFallback = true
        session.pause()
        activeEngine = engine
        if engine == .system {
            session.play()
        }
    }

    private func openExternal(_ target: ExternalOpenTarget) {
        guard let targetURL = target.url(endpoint: request.url, filename: request.title) else {
            externalMessageKey = "external.unsupported_hint"
            showExternalHint = true
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
                    "extension": request.fileExtensionHint.isEmpty ? "-" : request.fileExtensionHint
                ]
            )
            guard !accepted else { return }
            DispatchQueue.main.async {
                externalMessageKey = target.failureMessageKey
                showExternalHint = true
            }
        }
    }
}

#if canImport(MobileVLCKit)
private final class VLCMediaPlayerSession: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    let player = VLCMediaPlayer()
    @Published private(set) var isPlaying = false
    @Published private(set) var position: Double = 0
    @Published private(set) var isSeekable = false
    @Published private(set) var errorMessage: String?
    private var lastStateDescription = ""

    init(request: MediaPlaybackRequest) {
        super.init()
        player.delegate = self
        player.media = VLCMedia(url: request.url)
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.media",
            messageKey: "diagnostics.media.player_started",
            details: MediaPlaybackProbe.baseDetails(for: request).merging([
                "engine": "MobileVLCKit"
            ]) { current, _ in current }
        )
    }

    func attach(to view: UIView) {
        player.drawable = view
    }

    func play() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player.play()
        syncState()
    }

    func togglePlayback() {
        player.isPlaying ? player.pause() : player.play()
        syncState()
    }

    func jump(by seconds: Int) {
        if seconds < 0 {
            player.jumpBackward(-seconds)
        } else {
            player.jumpForward(seconds)
        }
    }

    func seek(to newPosition: Double) {
        guard player.isSeekable else { return }
        player.position = Float(min(max(newPosition, 0), 1))
        syncState()
    }

    func stop() {
        player.stop()
    }

    func mediaPlayerStateChanged(_ notification: Notification) {
        syncState()
    }

    func mediaPlayerTimeChanged(_ notification: Notification) {
        syncState()
    }

    private func syncState() {
        let isPlaying = player.isPlaying
        let position = Double(max(player.position, 0))
        let isSeekable = player.isSeekable
        let stateDescription = String(describing: player.state)
        let errorMessage = player.state == .error
            ? NSLocalizedString("player.compatibility_failed", comment: "")
            : nil

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

        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = isPlaying
            self?.position = position
            self?.isSeekable = isSeekable
            self?.errorMessage = errorMessage
        }
    }

    deinit {
        player.stop()
    }
}

private struct VLCBuiltInPlayerView: View {
    let request: MediaPlaybackRequest
    let openExternal: () -> Void
    @StateObject private var session: VLCMediaPlayerSession

    init(request: MediaPlaybackRequest, openExternal: @escaping () -> Void) {
        self.request = request
        self.openExternal = openExternal
        _session = StateObject(wrappedValue: VLCMediaPlayerSession(request: request))
    }

    var body: some View {
        ZStack {
            VLCPlayerSurface(session: session)
                .ignoresSafeArea(edges: .bottom)

            VStack(spacing: 0) {
                Spacer()
                VStack(spacing: 10) {
                    Slider(
                        value: Binding(
                            get: { session.position },
                            set: { session.seek(to: $0) }
                        ),
                        in: 0...1
                    )
                    .disabled(!session.isSeekable)
                    .tint(AppTheme.accent)

                    HStack(spacing: 34) {
                        Button {
                            session.jump(by: -15)
                        } label: {
                            Image(systemName: "gobackward.15")
                        }
                        .accessibilityLabel(Text("player.seek_backward"))

                        Button {
                            session.togglePlayback()
                        } label: {
                            Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title2)
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(
                            Text(LocalizedStringKey(session.isPlaying ? "player.pause" : "player.play"))
                        )

                        Button {
                            session.jump(by: 15)
                        } label: {
                            Image(systemName: "goforward.15")
                        }
                        .accessibilityLabel(Text("player.seek_forward"))
                    }
                    .font(.title3)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .background(.ultraThinMaterial)
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
                    Button(action: openExternal) {
                        Label("devices.files.open_external", systemImage: "arrow.up.forward.app")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
                }
                .foregroundStyle(.white)
                .padding(22)
            }
        }
        .onAppear {
            session.play()
        }
        .onDisappear {
            session.stop()
        }
    }
}

private struct VLCPlayerSurface: UIViewRepresentable {
    @ObservedObject var session: VLCMediaPlayerSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        session.attach(to: view)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        session.attach(to: view)
    }
}
#endif

private struct SystemPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = true
        controller.canStartPictureInPictureAutomaticallyFromInline = true
        controller.videoGravity = .resizeAspect
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
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

private struct JellyfinMediaEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let overview: String
    let kind: JellyfinEntryKind
    let collectionType: String?
    let imageItemID: String
    let imageTag: String?
    let container: String?
    let mediaSourceID: String?
    let preferredSubtitleStreamIndex: Int?
    let preferredSubtitleCodec: String?
    let progress: Double?
    let playbackPositionTicks: Int?

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

@MainActor
private final class JellyfinLibraryStore: ObservableObject {
    let endpoint: URL
    let playbackEndpoint: URL?
    let allowsSelfSignedCertificates: Bool

    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoading = true
    @Published private(set) var username = ""
    @Published private(set) var libraries: [JellyfinMediaEntry] = []
    @Published private(set) var continueWatching: [JellyfinMediaEntry] = []
    @Published private(set) var movies: [JellyfinMediaEntry] = []
    @Published private(set) var series: [JellyfinMediaEntry] = []
    @Published var errorMessage: String?

    private var client: JellyfinClient?
    private var userID: String?
    private var didRestore = false
    private var trustDelegate: JellyfinCertificateTrustDelegate?

    init(
        endpoint: URL,
        playbackEndpoint: URL?,
        allowsSelfSignedCertificates: Bool
    ) {
        self.endpoint = endpoint
        self.playbackEndpoint = playbackEndpoint.flatMap(Self.originURL)
        self.allowsSelfSignedCertificates = allowsSelfSignedCertificates
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
        guard let stored = KeychainStore.shared.loadJellyfinSession(endpoint: endpoint) else {
            isLoading = false
            return
        }
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
            let newClient = makeClient(accessToken: nil)
            let result = try await newClient.signIn(username: cleanedUsername, password: password)
            guard
                let accessToken = result.accessToken,
                let authenticatedUserID = result.user?.id
            else {
                throw JellyfinLibraryError.missingSession
            }
            client = newClient
            userID = authenticatedUserID
            self.username = result.user?.name ?? cleanedUsername
            isAuthenticated = true
            KeychainStore.shared.saveJellyfinSession(
                StoredJellyfinSession(
                    endpointString: endpoint.absoluteString,
                    userID: authenticatedUserID,
                    username: self.username,
                    accessToken: accessToken
                ),
                endpoint: endpoint
            )
            record("diagnostics.jellyfin.login_succeeded", level: .info)
            await loadHome()
        } catch {
            isAuthenticated = false
            errorMessage = NSLocalizedString("jellyfin.login.failed", comment: "")
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
        return try await loadItems(parentID: library.id, kinds: kinds, limit: 250)
    }

    func loadEpisodes(seriesID: String) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetEpisodesParameters()
        parameters.userID = userID
        parameters.fields = itemFields
        parameters.limit = 500
        parameters.enableImages = true
        parameters.enableImageTypes = [.primary, .thumb]
        parameters.enableUserData = true
        parameters.sortBy = .sortName
        let response = try await client.send(
            Paths.getEpisodes(seriesID: seriesID, parameters: parameters)
        ).value
        return (response.items ?? []).compactMap(mapItem)
    }

    func imageURL(for entry: JellyfinMediaEntry, width: Int = 480) -> URL? {
        guard let client else { return nil }
        var parameters = Paths.GetItemImageParameters()
        parameters.maxWidth = width
        parameters.quality = 88
        parameters.tag = entry.imageTag
        return client.url(
            with: Paths.getItemImage(
                itemID: entry.imageItemID,
                imageType: ImageType.primary.rawValue,
                parameters: parameters
            ),
            queryAPIKey: true
        )
    }

    func playbackRequest(for entry: JellyfinMediaEntry) async throws -> MediaPlaybackRequest? {
        guard let client, entry.isPlayable else { return nil }
        if entry.kind == .audio {
            var parameters = Paths.GetAudioStreamParameters()
            parameters.container = entry.container
            parameters.isStatic = true
            parameters.startTimeTicks = entry.playbackPositionTicks
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
                url: streamURL,
                title: entry.title,
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL),
                source: .jellyfin,
                fileExtensionOverride: extensionHint
            )
        }

        record(
            "diagnostics.jellyfin.playback_preparing",
            level: .info,
            details: [
                "itemKind": entry.kind.rawValue,
                "container": entry.container ?? "-",
                "subtitleCodec": entry.preferredSubtitleCodec ?? "-",
                "subtitleStreamIndex": entry.preferredSubtitleStreamIndex.map(String.init) ?? "none"
            ]
        )
        do {
            let profile = Self.iOSPlaybackProfile
            let requestBody = PlaybackInfoDto(
                allowAudioStreamCopy: false,
                allowVideoStreamCopy: false,
                deviceProfile: profile,
                enableDirectPlay: false,
                enableDirectStream: false,
                enableTranscoding: true,
                isAlwaysBurnInSubtitleWhenTranscoding: entry.preferredSubtitleStreamIndex != nil,
                maxAudioChannels: 2,
                maxStreamingBitrate: 20_000_000,
                mediaSourceID: entry.mediaSourceID,
                startTimeTicks: entry.playbackPositionTicks,
                subtitleStreamIndex: entry.preferredSubtitleStreamIndex,
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
            guard
                let transcodingPath = mediaSource?.transcodingURL,
                let streamURL = authenticatedJellyfinURL(path: transcodingPath, client: client)
            else {
                throw JellyfinLibraryError.missingPlaybackURL
            }
            record(
                "diagnostics.jellyfin.playback_prepared",
                level: .info,
                details: [
                    "mode": "serverTranscode",
                    "container": mediaSource?.transcodingContainer ?? "hls",
                    "playSession": response.playSessionID == nil ? "missing" : "present",
                    "subtitleCodec": entry.preferredSubtitleCodec ?? "-",
                    "subtitleStreamIndex": entry.preferredSubtitleStreamIndex.map(String.init) ?? "none",
                    "transport": playbackEndpoint == nil ? "primary" : "reachableLAN"
                ]
            )
            return MediaPlaybackRequest(
                url: streamURL,
                title: entry.title,
                allowsSelfSignedCertificates: requiresCertificateBypass(for: streamURL),
                source: .jellyfin,
                fileExtensionOverride: "m3u8"
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
        allowsSelfSignedCertificates && url.scheme?.lowercased() == "https"
    }

    private static let iOSPlaybackProfile = DeviceProfile(
        directPlayProfiles: [],
        maxStaticBitrate: 20_000_000,
        maxStaticMusicBitrate: 2_000_000,
        maxStreamingBitrate: 20_000_000,
        musicStreamingTranscodingBitrate: 320_000,
        name: "Nastart iOS",
        subtitleProfiles: [
            SubtitleProfile(format: "srt", method: .encode),
            SubtitleProfile(format: "subrip", method: .encode),
            SubtitleProfile(format: "vtt", method: .encode),
            SubtitleProfile(format: "ass", method: .encode),
            SubtitleProfile(format: "ssa", method: .encode),
            SubtitleProfile(format: "pgssub", method: .encode),
            SubtitleProfile(format: "dvdsub", method: .encode)
        ],
        transcodingProfiles: [
            TranscodingProfile(
                protocol: .hls,
                audioCodec: "aac",
                container: "ts",
                context: .streaming,
                enableSubtitlesInManifest: false,
                maxAudioChannels: "2",
                minSegments: 1,
                segmentLength: 6,
                transcodeSeekInfo: .auto,
                type: .video,
                videoCodec: "h264"
            )
        ]
    )

    private func loadHome() async {
        do {
            libraries = try await loadViews()
            continueWatching = try await loadResumeItems()
            movies = try await loadItems(parentID: nil, kinds: [.movie], limit: 36)
            series = try await loadItems(parentID: nil, kinds: [.series], limit: 36)
            isLoading = false
            record(
                "diagnostics.jellyfin.library_loaded",
                level: .info,
                details: [
                    "libraries": "\(libraries.count)",
                    "resume": "\(continueWatching.count)",
                    "movies": "\(movies.count)",
                    "series": "\(series.count)"
                ]
            )
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
        parameters.enableImageTypes = [.primary, .thumb]
        parameters.includeItemTypes = [.movie, .episode, .audio, .video]
        let response = try await client.send(Paths.getResumeItems(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private func loadItems(
        parentID: String?,
        kinds: [BaseItemKind],
        limit: Int
    ) async throws -> [JellyfinMediaEntry] {
        guard let client, let userID else { throw JellyfinLibraryError.missingSession }
        var parameters = Paths.GetItemsParameters()
        parameters.userID = userID
        parameters.parentID = parentID
        parameters.limit = limit
        parameters.isRecursive = true
        parameters.fields = itemFields
        parameters.includeItemTypes = kinds
        parameters.sortBy = [.sortName]
        parameters.sortOrder = [.ascending]
        parameters.enableUserData = true
        parameters.enableImages = true
        parameters.imageTypeLimit = 1
        parameters.enableImageTypes = [.primary, .thumb]
        let response = try await client.send(Paths.getItems(parameters: parameters)).value
        return (response.items ?? []).compactMap(mapItem)
    }

    private var itemFields: [ItemFields] {
        [.overview, .primaryImageAspectRatio, .mediaSources, .path, .genres]
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
        let mediaSource = item.mediaSources?.first
        let subtitleStreams = mediaSource?.mediaStreams?.filter { $0.type == .subtitle } ?? []
        let preferredSubtitle = subtitleStreams.first(where: { $0.index == mediaSource?.defaultSubtitleStreamIndex })
            ?? subtitleStreams.first(where: { $0.isForced == true })
            ?? subtitleStreams.first(where: { $0.isDefault == true })
            ?? subtitleStreams.first
        return JellyfinMediaEntry(
            id: id,
            title: title,
            subtitle: subtitle(for: item, kind: kind),
            overview: item.overview ?? "",
            kind: kind,
            collectionType: item.collectionType?.rawValue,
            imageItemID: imageItemID,
            imageTag: imageTag,
            container: item.container ?? mediaSource?.container,
            mediaSourceID: mediaSource?.id,
            preferredSubtitleStreamIndex: preferredSubtitle?.index,
            preferredSubtitleCodec: preferredSubtitle?.codec,
            progress: item.userData?.playedPercentage.map { min(max($0 / 100, 0), 1) },
            playbackPositionTicks: item.userData?.playbackPositionTicks
        )
    }

    private func subtitle(for item: BaseItemDto, kind: JellyfinEntryKind) -> String {
        if kind == .episode {
            let season = item.parentIndexNumber.map { "S\($0)" } ?? ""
            let episode = item.indexNumber.map { "E\($0)" } ?? ""
            return [item.seriesName, season + episode].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        }
        let duration = item.runTimeTicks.map { ticks -> String in
            let minutes = Int(ticks / 600_000_000)
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
        return [
            "errorDomain": value.domain,
            "errorCode": "\(value.code)"
        ]
    }
}

private enum JellyfinLibraryError: Error {
    case missingSession
    case missingPlaybackURL
}

private struct JellyfinLibraryView: View {
    let service: LaunchpadService
    @StateObject private var store: JellyfinLibraryStore

    init(service: LaunchpadService, endpoint: URL, allowsSelfSignedCertificates: Bool) {
        self.service = service
        _store = StateObject(wrappedValue: JellyfinLibraryStore(
            endpoint: endpoint,
            playbackEndpoint: service.alternateEndpoint,
            allowsSelfSignedCertificates: allowsSelfSignedCertificates
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
        .task { await store.restoreIfNeeded() }
        .toolbar {
            if store.isAuthenticated {
                ToolbarItem(placement: .navigationBarTrailing) {
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
            LazyVStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.username)
                            .font(.headline)
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

                if !store.libraries.isEmpty {
                    JellyfinShelfHeader(titleKey: "jellyfin.library.mine")
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

                if !store.continueWatching.isEmpty {
                    JellyfinPosterShelf(
                        store: store,
                        titleKey: "media.continue.title",
                        items: store.continueWatching,
                        posterWidth: 230,
                        landscape: true
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
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .refreshable { await store.refresh() }
    }
}

private struct JellyfinShelfHeader: View {
    let titleKey: LocalizedStringKey

    var body: some View {
        Text(titleKey)
            .font(.title3.weight(.bold))
    }
}

private struct JellyfinLibraryCard: View {
    @ObservedObject var store: JellyfinLibraryStore
    let library: JellyfinMediaEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            JellyfinPosterImage(url: store.imageURL(for: library, width: 560))
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
            JellyfinShelfHeader(titleKey: titleKey)
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
                JellyfinPosterImage(url: store.imageURL(for: item, width: Int(width * 3)))
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

private struct JellyfinPosterImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut(duration: 0.2))) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                placeholder
            case .empty:
                ZStack {
                    placeholder
                    ProgressView()
                }
            @unknown default:
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
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

private struct JellyfinCollectionView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let library: JellyfinMediaEntry
    @State private var items: [JellyfinMediaEntry] = []
    @State private var isLoading = true
    @State private var failed = false

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
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 126), spacing: 14)],
                        spacing: 18
                    ) {
                        ForEach(items) { item in
                            NavigationLink {
                                JellyfinMediaRouteView(store: store, item: item)
                            } label: {
                                JellyfinPosterCard(store: store, item: item, width: 126, landscape: false)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(18)
                }
            }
        }
        .navigationTitle(library.title)
        .task { await load() }
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
        List {
            JellyfinDetailHeader(store: store, item: series)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            Section {
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if failed {
                    Button("action.retry") { Task { await loadEpisodes() } }
                } else {
                    ForEach(episodes) { episode in
                        NavigationLink {
                            JellyfinMediaDetailView(store: store, item: episode)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(episode.title)
                                    .font(.body.weight(.medium))
                                Text(episode.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            } header: {
                Text("jellyfin.episodes.title")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(series.title)
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
}

private struct JellyfinMediaDetailView: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry
    @State private var playbackRequest: MediaPlaybackRequest?
    @State private var isPreparingPlayback = false
    @State private var showPlaybackError = false

    var body: some View {
        List {
            JellyfinDetailHeader(store: store, item: item)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            if !item.overview.isEmpty {
                Section {
                    Text(item.overview)
                        .font(.subheadline)
                } header: {
                    Text("jellyfin.overview.title")
                }
            }

            if item.isPlayable {
                Section {
                    Button {
                        Task {
                            isPreparingPlayback = true
                            defer { isPreparingPlayback = false }
                            do {
                                playbackRequest = try await store.playbackRequest(for: item)
                            } catch {
                                showPlaybackError = true
                            }
                        }
                    } label: {
                        HStack {
                            Label("player.play_in_app", systemImage: "play.fill")
                            Spacer()
                            if isPreparingPlayback {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isPreparingPlayback)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(item.title)
        .alert("jellyfin.player.prepare_failed", isPresented: $showPlaybackError) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text("jellyfin.player.prepare_failed_detail")
        }
        .fullScreenCover(item: $playbackRequest) { request in
            NavigationStack {
                BuiltInMediaPlayerView(request: request)
            }
        }
    }
}

private struct JellyfinDetailHeader: View {
    @ObservedObject var store: JellyfinLibraryStore
    let item: JellyfinMediaEntry

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            JellyfinPosterImage(url: store.imageURL(for: item, width: 480))
                .frame(width: 118, height: 174)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.title2.weight(.bold))
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
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
               let endpoint = service.preferredEndpoint(for: connectionStore.dsmSession?.baseURL) {
                JellyfinLibraryView(
                    service: service,
                    endpoint: endpoint,
                    allowsSelfSignedCertificates: connectionStore.dsmSession?.allowsSelfSignedCertificates == true
                )
            } else {
                fallbackLibrary
            }
        }
        .navigationTitle(service.name)
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
                                allowsSelfSignedCertificates: connectionStore.dsmSession?.allowsSelfSignedCertificates == true,
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
            .frame(maxWidth: 520, alignment: .leading)
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
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value = trimmed.contains("://") ? trimmed : "http://\(trimmed)"
        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            components.host?.isEmpty == false
        else {
            return nil
        }
        return components.url
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
            .frame(maxWidth: 560)
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
                    from: host,
                    defaultsToHTTPOnLocalNetwork: connectionLocation == .local
                )
                let client = DSMClient(
                    baseURL: baseURL,
                    allowsSelfSignedCertificates: allowsSelfSignedCertificates
                )
                let session = try await client.login(
                    account: account,
                    password: password,
                    oneTimeCode: oneTimeCode
                )
                await MainActor.run {
                    connectionStatusKey = "connect.review.loading"
                }
                let snapshot = await client.loadSnapshot(session: session, useAgent: false)
                try Task.checkCancellation()
                KeychainStore.shared.saveNASCredential(
                    StoredNASCredential(
                        baseURLString: baseURL.absoluteString,
                        account: account,
                        password: password,
                        useAgent: false,
                        allowsSelfSignedCertificates: allowsSelfSignedCertificates,
                        deviceID: session.deviceID
                    )
                )
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("launchpad.summary.normal", systemImage: "checkmark.circle.fill")
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

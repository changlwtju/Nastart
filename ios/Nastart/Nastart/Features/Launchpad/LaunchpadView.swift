import SwiftUI

struct LaunchpadView: View {
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var appearanceStore: AppearanceStore
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    launchpadContent
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
        switch appearanceStore.launchpadTheme {
        case .cleanGrid:
            ProductLaunchpad(device: dataStore.device, services: dataStore.services)
        case .commandCenter:
            CommandCenterLaunchpad(device: dataStore.device, services: dataStore.services)
        case .glassDeck:
            GlassDeckLaunchpad(device: dataStore.device, services: dataStore.services)
        }
    }

    @ViewBuilder
    private var launchpadBackground: some View {
        switch appearanceStore.launchpadTheme {
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

private struct CommandCenterLaunchpad: View {
    let device: NASDevice
    let services: [LaunchpadService]

    private var onlineCount: Int {
        services.filter { $0.status == .online }.count
    }

    private var actionCount: Int {
        services.filter { $0.status == .warning || $0.status == .offline }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DeviceSummaryPanel(device: device)

            HStack(spacing: 10) {
                CommandMetricTile(titleKey: "status.online", value: "\(onlineCount)")
                CommandMetricTile(titleKey: "tasks.segment.pending", value: "\(actionCount)")
                CommandMetricTile(titleKey: "metric.storage", value: device.storageFreeText)
            }

            CertificateReminderStrip(days: device.certificateDaysRemaining)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(titleKey: "launchpad.command.quick_actions", trailingKey: "launchpad.section.generated")
                ForEach(services.prefix(6)) { service in
                    ServiceListRow(service: service)
                }
            }
        }
    }
}

private struct CommandMetricTile: View {
    let titleKey: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(titleKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
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

    private var featuredServices: [LaunchpadService] {
        Array(services.filter { $0.category == .favorites || $0.category == .media }.prefix(4))
    }

    private var remainingServices: [LaunchpadService] {
        let featuredIDs = Set(featuredServices.map(\.id))
        return Array(services.filter { !featuredIDs.contains($0.id) }.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassHeroPanel(device: device)

            CertificateReminderStrip(days: device.certificateDaysRemaining)

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(titleKey: "category.favorites", trailingKey: "launchpad.section.generated")
                VStack(spacing: 10) {
                    ForEach(featuredServices) { service in
                        GlassServiceRow(service: service)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(titleKey: "launchpad.section.services", trailingKey: nil)
                ForEach(remainingServices) { service in
                    ServiceListRow(service: service)
                }
            }
        }
    }
}

private struct GlassHeroPanel: View {
    let device: NASDevice

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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

            MetricPillRow(metrics: [
                MetricPillSpec("metric.cpu", value: "11%", progress: device.cpu, symbolName: "cpu"),
                MetricPillSpec("metric.memory", value: "32%", progress: device.memory, symbolName: "memorychip"),
                MetricPillSpec("metric.storage", value: device.storageFreeText, progress: device.storageUsed, symbolName: "internaldrive")
            ])
        }
        .padding(18)
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
                    Text(LocalizedStringKey(service.detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
                Spacer()
                StatusDot(status: service.status)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DeviceSummaryPanel(device: device)
            CertificateReminderStrip(days: device.certificateDaysRemaining)

            ForEach(ServiceCategory.allCases) { category in
                let categoryServices = services.filter { $0.category == category }
                if !categoryServices.isEmpty {
                    ServiceGroupSection(category: category, services: categoryServices)
                }
            }
        }
    }
}

private struct ServiceGroupSection: View {
    let category: ServiceCategory
    let services: [LaunchpadService]
    @State private var isExpanded: Bool

    init(category: ServiceCategory, services: [LaunchpadService]) {
        self.category = category
        self.services = services
        _isExpanded = State(initialValue: category == .favorites || category == .media)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 22, minHeight: 22)
                        .background(AppTheme.secondarySurface)
                        .clipShape(Capsule())
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(services) { service in
                        ServiceListRow(service: service)
                    }
                }
            } else {
                CollapsedServicePreview(services: services)
            }
        }
    }
}

private struct CollapsedServicePreview: View {
    let services: [LaunchpadService]

    var body: some View {
        HStack(spacing: 10) {
            ForEach(services.prefix(4)) { service in
                ServiceIconView(service: service, size: 34)
            }

            if services.count > 4 {
                Text("+\(services.count - 4)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .background(AppTheme.secondarySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

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

private struct ServiceListRow: View {
    let service: LaunchpadService
    @State private var actionMessageKey = "service.context.open_hint"
    @State private var showActionHint = false

    var body: some View {
        NavigationLink {
            ServiceDetailView(service: service)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ServiceIconView(service: service, size: 38)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Text(service.name)
                            .font(.body.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                        ServiceStatusBadge(status: service.status)
                    }
                    Text(LocalizedStringKey(service.detail))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    HStack(spacing: 6) {
                        if let cpu = service.cpu {
                            InlineServiceMetric(titleKey: "metric.cpu", value: "\(Int(cpu * 100))%")
                        }
                        if let memoryText = service.memoryText {
                            InlineServiceMetric(titleKey: "metric.memory", value: memoryText)
                        }
                        if service.isMedia {
                            InlineServiceMetric(titleKey: "service.metric.library", valueKey: service.name == "Navidrome" ? "media.albums.title" : "media.movies.title")
                        }
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(service.displayProfile.prefersFeaturedRow ? AppTheme.accent.opacity(0.18) : AppTheme.hairline, lineWidth: 1)
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
        service.displayProfile.prefersFeaturedRow ? AnyShapeStyle(AppTheme.softAccent.opacity(0.24)) : AnyShapeStyle(Color(.secondarySystemGroupedBackground))
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
    let value: String

    init(titleKey: LocalizedStringKey, value: String) {
        self.titleKey = titleKey
        self.value = value
    }

    init(titleKey: LocalizedStringKey, valueKey: String) {
        self.titleKey = titleKey
        value = NSLocalizedString(valueKey, comment: "")
    }

    var body: some View {
        HStack(spacing: 3) {
            Text(titleKey)
            Text(value)
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

                Section("search.hot") {
                    FlowPills(items: ["DSM", "Jellyfin", "Docker", "HTTPS", "Navidrome", "qBittorrent"])
                }

                Section("search.services") {
                    ForEach(filteredServices) { service in
                        NavigationLink {
                            ServiceDetailView(service: service)
                        } label: {
                            ServiceSearchRow(service: service)
                        }
                    }
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
    @State private var showOpenHint = false
    @State private var showExternalPicker = false
    @State private var externalMessageKey = "external.safari_hint"
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

            Section("service.detail.actions") {
                if service.name == "DSM" {
                    NavigationLink {
                        DeviceStatusView(device: dataStore.device)
                    } label: {
                        Label("service.action.device_control", systemImage: "server.rack")
                    }
                }

                Button {
                    showOpenHint = true
                } label: {
                    Label("service.action.open_web", systemImage: "safari")
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
            }

            Section("service.detail.connection") {
                LabeledContent("service.detail.endpoint", value: "https://nas.example.com/\(service.name.lowercased())")
                LabeledContent("service.detail.source", value: service.isMedia ? "DSM + API" : "DSM / Agent")
                LabeledContent("service.detail.status") {
                    Text(LocalizedStringKey(service.status.titleKey))
                }
            }
        }
        .navigationTitle(service.name)
        .alert("service.open.hint", isPresented: $showOpenHint) {
            Button("action.ok", role: .cancel) {}
        }
        .confirmationDialog("service.external.title", isPresented: $showExternalPicker) {
            if service.isMedia {
                Button("Infuse") {
                    showExternal("external.infuse_hint")
                }
                Button("VidHub") {
                    showExternal("external.vidhub_hint")
                }
                Button("VLC") {
                    showExternal("external.vlc_hint")
                }
            }
            Button("Safari") {
                showExternal("external.safari_hint")
            }
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

            Section("media.library.sections") {
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

            Section("media.item.info") {
                LabeledContent("media.item.source", value: service.name)
                LabeledContent("media.item.location", value: item.path)
                LabeledContent("media.item.meta", value: item.meta)
            }

            Section("media.item.actions") {
                Button("media.item.play") {
                    showPlayerPicker = true
                }
                Button("media.item.favorite") {
                    show("media.item.favorite_hint")
                }
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
    @State private var host = "https://nas.example.com:5001"
    @State private var account = ""
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

            Section("connect.section.dsm") {
                TextField("connect.host", text: $host)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                TextField("connect.account", text: $account)
                    .textInputAutocapitalization(.never)
                NavigationLink {
                    LANDiscoveryView()
                } label: {
                    Label("connect.scan.title", systemImage: "magnifyingglass")
                }
            }

            Section("connect.section.agent") {
                Toggle("connect.agent.toggle", isOn: $useAgent)
                NavigationLink {
                    AgentSetupGuideView()
                } label: {
                    Label("connect.agent.guide", systemImage: "shippingbox")
                }
            }

            Section {
                NavigationLink {
                    DSMConnectionReviewView(host: host, account: account, useAgent: useAgent)
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

            Section("connect.scan.results") {
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
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.scan.title")
        .alert(String(format: NSLocalizedString("connect.scan.use_hint", comment: ""), selectedHost), isPresented: $showHint) {
            Button("action.ok", role: .cancel) {}
        }
    }
}

private struct AgentSetupGuideView: View {
    @State private var showCopyHint = false

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

            Section("connect.agent.steps") {
                AgentStepRow(number: 1, titleKey: "connect.agent.step.package", detailKey: "connect.agent.step.package_detail")
                AgentStepRow(number: 2, titleKey: "connect.agent.step.token", detailKey: "connect.agent.step.token_detail")
                AgentStepRow(number: 3, titleKey: "connect.agent.step.verify", detailKey: "connect.agent.step.verify_detail")
            }

            Section("connect.agent.command") {
                Text("docker run -d --name nastart-agent -p 8787:8787 nastart/agent:latest")
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                Button("connect.agent.copy") {
                    showCopyHint = true
                }
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
    let useAgent: Bool
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @State private var showFinishHint = false

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

            Section("connect.review.target") {
                LabeledContent("connect.host", value: host)
                LabeledContent("connect.account", value: account.isEmpty ? "-" : account)
                LabeledContent("connect.agent.toggle") {
                    Text(LocalizedStringKey(useAgent ? "state.on" : "state.off"))
                        .foregroundStyle(.secondary)
                }
            }

            Section("connect.review.scope") {
                CapabilityRow(titleKey: "connect.scope.system", symbol: "chart.line.uptrend.xyaxis")
                CapabilityRow(titleKey: "connect.scope.files", symbol: "folder")
                CapabilityRow(titleKey: "connect.scope.docker", symbol: "shippingbox")
                CapabilityRow(titleKey: "connect.scope.services", symbol: "square.grid.2x2")
            }

            Section {
                Button {
                    connectionStore.connect(device: dataStore.device)
                    showFinishHint = true
                } label: {
                    Text("connect.review.finish")
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("connect.review.nav")
        .alert("connect.review.done", isPresented: $showFinishHint) {
            Button("action.ok", role: .cancel) {}
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
            Text(String(format: NSLocalizedString("launchpad.reminder.cert", comment: ""), days))
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

            MetricPillRow(metrics: [
                MetricPillSpec("metric.cpu", value: "11%", progress: device.cpu),
                MetricPillSpec("metric.memory", value: "32%", progress: device.memory),
                MetricPillSpec("metric.storage", value: device.storageFreeText, progress: device.storageUsed)
            ])
        }
        .padding(16)
        .nastartCard(cornerRadius: 26)
    }
}

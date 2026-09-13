import SwiftUI
import UIKit
import WebKit
import SafariServices

struct LaunchpadServiceManagementView: View {
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
                                HStack(spacing: 6) {
                                    Text(LocalizedStringKey(service.sourceTitleKey))
                                    Text("·")
                                    Text(LocalizedStringKey(
                                        LaunchpadDefaultVisibilityPolicy.reason(for: service).titleKey
                                    ))
                                }
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

struct LaunchpadSearchView: View {
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

struct ServiceDetailView: View {
    let service: LaunchpadService
    @EnvironmentObject private var dataStore: AppDataStore
    @EnvironmentObject private var connectionStore: NASConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var externalMessageKey = "external.open_failed"
    @State private var showExternalHint = false
    @State private var endpointOverride: URL?
    @State private var systemBrowserPresentation: SystemBrowserPresentation?
    @State private var webBrowserPresentation: SystemBrowserPresentation?
    @State private var mediaLibraryPresentation: MediaLibraryPresentation?
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
                    if service.usesSystemInAppBrowser {
                        Button {
                            recordServiceRouteRequest(
                                action: "web",
                                endpoint: endpoint,
                                engine: "SFSafariViewController"
                            )
                            systemBrowserPresentation = SystemBrowserPresentation(url: endpoint)
                        } label: {
                            Label {
                                Text(LocalizedStringKey(service.isDeveloperConsole ? "service.action.open_console" : "service.action.open_web"))
                            } icon: {
                                Image(systemName: service.isDeveloperConsole ? "terminal" : "safari")
                            }
                        }
                    } else {
                        Button {
                            recordServiceRouteRequest(action: "web", endpoint: endpoint, engine: "WKWebView")
                            webBrowserPresentation = SystemBrowserPresentation(url: endpoint)
                        } label: {
                            Label {
                                Text(LocalizedStringKey(service.isDeveloperConsole ? "service.action.open_console" : "service.action.open_web"))
                            } icon: {
                                Image(systemName: service.isDeveloperConsole ? "terminal" : "safari")
                            }
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

                    Button {
                        recordServiceRouteRequest(
                            action: "mediaLibrary",
                            endpoint: effectiveEndpoint,
                            engine: service.isJellyfin ? "JellyfinLibraryView" : "MediaLibraryView"
                        )
                        mediaLibraryPresentation = MediaLibraryPresentation(service: service)
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
                if let health = dataStore.healthSnapshot(for: service) {
                    if let latency = health.latencyMilliseconds {
                        LabeledContent("service.detail.latency") {
                            Text("\(latency) ms")
                        }
                    }
                    LabeledContent("service.detail.last_checked") {
                        Text(health.checkedAt, style: .relative)
                    }
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
        .fullScreenCover(item: $systemBrowserPresentation) { presentation in
            SystemInAppBrowserView(url: presentation.url) {
                systemBrowserPresentation = nil
            }
            .ignoresSafeArea()
        }
        // Own a separate navigation stack: changing both the tab bar and
        // bottom toolbar visibility during a push loops SwiftUI layout on iOS 16.
        .fullScreenCover(item: $webBrowserPresentation) { presentation in
            NavigationStack {
                ServiceWebUIView(
                    service: service,
                    endpoint: presentation.url,
                    allowsSelfSignedCertificates: ServiceCertificatePolicy.allowsBypass(
                        for: presentation.url, session: connectionStore.dsmSession),
                    dsmSession: service.source == .dsm || service.source == .package
                        ? connectionStore.dsmSession : nil
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { webBrowserPresentation = nil } label: {
                            Label("web.back", systemImage: "chevron.backward")
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $mediaLibraryPresentation) { presentation in
            NavigationStack {
                MediaLibraryView(service: presentation.service)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("action.done") {
                                mediaLibraryPresentation = nil
                            }
                        }
                    }
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

    private func recordServiceRouteRequest(
        action: String,
        endpoint: URL?,
        engine: String
    ) {
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: action == "mediaLibrary"
                ? "diagnostics.category.media"
                : "diagnostics.category.web",
            messageKey: action == "mediaLibrary"
                ? "diagnostics.jellyfin.library_route_requested"
                : "diagnostics.web.route_requested",
            details: [
                "action": action,
                "target": endpoint.map(DiagnosticLogStore.redactedURL) ?? "-",
                "service": service.name,
                "profile": service.webProfileName,
                "isJellyfin": service.isJellyfin ? "yes" : "no",
                "engine": engine
            ]
        )
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

private struct SystemBrowserPresentation: Identifiable {
    let id = UUID()
    let url: URL
}

private struct MediaLibraryPresentation: Identifiable {
    let id = UUID()
    let service: LaunchpadService
}

enum ServiceCertificatePolicy {
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

enum ServiceEndpointOverrides {
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

struct ServiceSharePayload: Identifiable {
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

struct ServiceWebUIView: View {
    let service: LaunchpadService
    let endpoint: URL
    let allowsSelfSignedCertificates: Bool
    let dsmSession: DSMSession?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMode = ServiceWebMode.automatic
    @AppStorage("web.compact_browsing") private var compactBrowsing = true
    @State private var showModeHelp = false
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
        Group {
            if service.usesSystemInAppBrowser {
                SystemInAppBrowserView(url: endpoint) {
                    dismiss()
                }
                .ignoresSafeArea()
            } else {
                webKitBrowser
                    .fullScreenCover(isPresented: $showCompatibilityBrowser) {
                        SystemInAppBrowserView(url: currentURL) {
                            showCompatibilityBrowser = false
                        }
                        .ignoresSafeArea()
                    }
            }
        }
        .onAppear {
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.web",
                messageKey: "diagnostics.web.entry_presented",
                details: [
                    "target": DiagnosticLogStore.redactedURL(endpoint),
                    "service": service.name,
                    "profile": service.webProfileName,
                    "isJellyfin": service.isJellyfin ? "yes" : "no",
                    "engine": service.usesSystemInAppBrowser ? "SFSafariViewController" : "WKWebView"
                ]
            )
        }
    }

    private var webKitBrowser: some View {
        VStack(spacing: 0) {
            ZStack {
                WebContainerView(
                    url: endpoint,
                    prefersDesktopMode: resolvedMode.usesDesktopUserAgent,
                    prefersCompatibilityFallback: service.isDeveloperConsole || service.isJellyfin,
                    expectsDeveloperWorkbench: service.isDeveloperConsole,
                    expectsMetaCubeDashboard: service.isMetaCubeXD,
                    bypassesPersistentWebCache: service.isMetaCubeXD,
                    webProfileName: service.webProfileName,
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
                    if !service.forcesMobileWebMode {
                        Picker(selection: $selectedMode) {
                            ForEach(ServiceWebMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.titleKey)).tag(mode)
                            }
                        } label: {
                            Text("web.mode.title")
                        }
                    }
                    Toggle("web.compact_browsing", isOn: $compactBrowsing)
                    Button("web.mode.help") { showModeHelp = true }
                    Divider()
                    Button {
                        sendBrowserCommand(.back)
                    } label: {
                        Label("web.back", systemImage: "chevron.backward")
                    }
                    .disabled(!canGoBack)
                    Button {
                        sendBrowserCommand(.forward)
                    } label: {
                        Label("web.forward", systemImage: "chevron.forward")
                    }
                    .disabled(!canGoForward)
                    Button {
                        sendBrowserCommand(isLoading ? .stop : .reload)
                    } label: {
                        Label(LocalizedStringKey(isLoading ? "web.stop" : "action.refresh"),
                              systemImage: isLoading ? "xmark" : "arrow.clockwise")
                    }
                    Divider()
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

        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !compactBrowsing {
                HStack(spacing: 24) {
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
                .padding(.horizontal)
                .frame(height: 44)
                .background(.bar)
            }
        }
        .alert("web.copy.done", isPresented: $showCopiedHint) {
            Button("action.ok", role: .cancel) {}
        }
        .alert("web.mode.help", isPresented: $showModeHelp) {
            Button("action.ok", role: .cancel) {}
        } message: {
            Text("web.mode.explanation")
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
        if service.forcesMobileWebMode {
            return ResolvedWebMode(usesDesktopUserAgent: false)
        }
        switch selectedMode {
        case .automatic:
            return ResolvedWebMode(usesDesktopUserAgent: service.prefersEnhancedWebMode)
        case .mobile:
            return ResolvedWebMode(usesDesktopUserAgent: false)
        case .desktop:
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
    let webProfileName: String
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
        let modeChanged = context.coordinator.parent.prefersDesktopMode != prefersDesktopMode
        context.coordinator.parent = self
        if context.coordinator.lastRequestedURL != url {
            context.coordinator.load(url, in: uiView)
        } else if modeChanged {
            // Reload the page the user reached, preserving endpoint identity
            // and history. Navigation preferences below apply the new mode.
            uiView.reload()
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
                    "profile": parent.webProfileName,
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
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            preferences.preferredContentMode = parent.preferredContentMode
            guard let targetURL = navigationAction.request.url else {
                decisionHandler(.cancel, preferences)
                return
            }
            let scheme = targetURL.scheme?.lowercased()
            if scheme == "http" || scheme == "https" || scheme == "about" {
                if navigationAction.navigationType == .linkActivated,
                   DirectMediaURLPolicy.isLikelyMediaURL(targetURL) {
                    decisionHandler(.cancel, preferences)
                    DispatchQueue.main.async {
                        self.parent.pendingMediaURL = targetURL
                    }
                    return
                }
                decisionHandler(navigationAction.shouldPerformDownload ? .download : .allow, preferences)
            } else {
                decisionHandler(.cancel, preferences)
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

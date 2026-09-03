import SwiftUI
import UIKit

struct MediaLibraryView: View {
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
                    dsmSharedFolderPaths: dsmSharedFolderRootPaths,
                    fallbackEndpoints: jellyfinEndpointCandidates
                )
            } else {
                fallbackLibrary
            }
        }
        .navigationTitle(service.name)
        .onAppear {
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.jellyfin.library_entry_presented",
                details: [
                    "target": effectiveJellyfinEndpoint.map(DiagnosticLogStore.redactedURL) ?? "-",
                    "service": service.name,
                    "profile": service.webProfileName,
                    "isJellyfin": service.isJellyfin ? "yes" : "no",
                    "candidateCount": "\(jellyfinEndpointCandidates.count)"
                ]
            )
        }
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

    private var dsmSharedFolderRootPaths: [String] {
        let roots = Set(dataStore.files.lazy.compactMap { item -> String? in
            guard item.kind == .folder else { return nil }
            return dsmSharedFolderRootPath(for: item.path)
        })
        return Array(roots).sorted().prefix(80).map { $0 }
    }

    private func dsmSharedFolderRootPath(for path: String) -> String? {
        let normalized = path
            .replacingOccurrences(of: "\\", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.hasPrefix("/") else { return nil }
        let components = normalized.split(separator: "/", omittingEmptySubsequences: true)
        guard let first = components.first else { return nil }
        let lowercasedFirst = first.lowercased()
        if lowercasedFirst.hasPrefix("volume"),
           !lowercasedFirst.dropFirst("volume".count).isEmpty,
           lowercasedFirst.dropFirst("volume".count).allSatisfy(\.isNumber),
           components.count > 1 {
            return "/" + [first, components[1]].joined(separator: "/")
        }
        return "/" + first
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

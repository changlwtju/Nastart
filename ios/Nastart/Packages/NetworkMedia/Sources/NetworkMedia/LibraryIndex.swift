import Foundation

/// A saved server remains available even when its last media folder is removed.
/// Secrets live in Keychain under this ID, never in the source catalog.
public struct NetworkStorageConnection: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let address: String
    public init(id: UUID = UUID(), name: String, scope: WebDAVScope) {
        self.id = id; self.name = name; address = scope.baseURL.absoluteString
    }
    func credentialLibrary() throws -> NetworkLibrary {
        NetworkLibrary(id: id, name: name, scope: try WebDAVScope(storageAddress: address), root: try DAVPath())
    }
    func replacement(for library: NetworkLibrary) throws -> NetworkLibrary {
        guard library.fileStationAccount == nil,
              var old = URLComponents(string: library.address),
              let next = URLComponents(string: address) else { throw NetworkMediaError.invalidAddress }
        old.scheme = next.scheme; old.host = next.host; old.port = next.port
        guard let url = old.url else { throw NetworkMediaError.invalidAddress }
        return NetworkLibrary(name: library.name, scope: try WebDAVScope(storageAddress: url.absoluteString),
                              root: library.root, connectionID: id)
    }
}

public struct NetworkLibrary: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let address: String
    public let root: DAVPath
    public let fileStationAccount: String?
    public var connectionID: UUID?
    public var files: [RemoteMediaEntry]
    public var lastCompletedScan: Date?
    public var corrections: [LocalMediaCorrection]?
    public var artworkScanVersion: Int?
    public init(id: UUID = UUID(), name: String, scope: WebDAVScope, root: DAVPath, fileStationAccount: String? = nil, connectionID: UUID? = nil) {
        self.connectionID = connectionID
        self.fileStationAccount = fileStationAccount
        self.id = id; self.name = name; address = scope.baseURL.absoluteString; self.root = root
        files = []; lastCompletedScan = nil; corrections = nil; artworkScanVersion = nil
    }
    /// Full folder path as entered in a connection form, not a URL or a
    /// percent-encoded path. The origin and account stay unchanged.
    public var folderPath: String {
        guard fileStationAccount == nil,
              let parts = URLComponents(string: address), let base = try? DAVPath(encodedPath: parts.percentEncodedPath) else {
            return "/" + root.displayPath
        }
        return "/" + DAVPath(validated: base.encodedSegments + root.encodedSegments).displayPath
    }
    /// Browsing a replacement folder lists directories on this same server;
    /// it does not change the library's indexed root or read sidecar contents.
    func folderBrowsingLocation(path: String? = nil) throws -> (scope: WebDAVScope, path: DAVPath) {
        let folder = try DAVPath(path ?? folderPath)
        if fileStationAccount != nil { return (try WebDAVScope(storageAddress: address), folder) }
        guard var parts = URLComponents(string: address) else { throw NetworkMediaError.invalidAddress }
        parts.percentEncodedPath = "/"
        guard let url = parts.url else { throw NetworkMediaError.invalidAddress }
        let scope = try WebDAVScope(storageAddress: url.absoluteString)
        guard try WebDAVScope(storageAddress: address).sameOrigin(scope.baseURL) else { throw NetworkMediaError.outsideRoot }
        return (scope, folder)
    }
    /// A no-op edit must not allocate a new library identity or discard its index.
    func replacementForFolderEdit(_ path: String) throws -> NetworkLibrary? {
        guard try DAVPath(path) != DAVPath(folderPath) else { return nil }
        return try replacingFolder(with: path)
    }
    public func replacingFolder(with path: String) throws -> NetworkLibrary {
        let folder = try DAVPath(path)
        guard fileStationAccount == nil else {
            return NetworkLibrary(name: name, scope: try WebDAVScope(storageAddress: address), root: folder, fileStationAccount: fileStationAccount)
        }
        guard var parts = URLComponents(string: address) else { throw NetworkMediaError.invalidAddress }
        parts.percentEncodedPath = "/" + folder.key
        guard let address = parts.url?.absoluteString else { throw NetworkMediaError.invalidAddress }
        return NetworkLibrary(name: name, scope: try WebDAVScope(storageAddress: address), root: try DAVPath(), connectionID: connectionID)
    }
}

public enum ReadOnlyLibraryScanner {
    /// Fully stage a bounded scan. Failure/cancellation never returns a partial replacement index.
    public static func scan(source: any ReadOnlyDirectorySource, root: DAVPath,
                            maxEntries: Int = 100_000, maxDirectories: Int = 10_000,
                            maxMetadataBytes: Int = 32 * 1024 * 1024, maxMetadataFiles: Int = 4096,
                            progress: @Sendable (Int) async -> Void = { _ in }) async throws -> [RemoteMediaEntry] {
        guard maxEntries > 0, maxDirectories > 0 else { throw NetworkMediaError.limitExceeded }
        var pending = [root], cursor = 0, seen = Set<String>(), videos: [RemoteMediaEntry] = []
        var metadataBytes = 0, metadataFiles = 0
        var discMetadata: [DAVPath: LocalMediaMetadata] = [:]
        var seriesMetadata: [DAVPath: LocalSeriesMetadata] = [:]
        while cursor < pending.count {
            try Task.checkCancellation()
            let directory = pending[cursor]; cursor += 1
            guard cursor <= maxDirectories, directory.encodedSegments.count - root.encodedSegments.count <= 64 else { throw NetworkMediaError.limitExceeded }
            let entries = try await source.list(directory)
            try Task.checkCancellation()
            for item in entries {
                guard item.path.isWithin(root), item.path.parent == directory, seen.insert(item.id).inserted else { throw NetworkMediaError.incompleteListing }
                guard seen.count <= maxEntries else { throw NetworkMediaError.limitExceeded }
                if item.isDirectory { pending.append(item.path) }
            }
            let sidecars = NFOSidecarSelection(siblings: entries)
            let seriesNFO = entries.filter { !$0.isDirectory && $0.path.name.lowercased() == "tvshow.nfo" }
            if seriesNFO.count == 1, let nfo = seriesNFO.first, (nfo.size ?? 0) <= NFOReader.maxBytes,
               let reader = source as? any ReadOnlyMetadataSource {
                metadataFiles += 1
                guard metadataFiles <= maxMetadataFiles else { throw NetworkMediaError.limitExceeded }
                do {
                    let data = try await reader.readNFO(nfo.path, root: root)
                    try Task.checkCancellation(); metadataBytes += data.count
                    guard metadataBytes <= maxMetadataBytes else { throw NetworkMediaError.limitExceeded }
                    seriesMetadata[directory] = try NFOReader.parseSeries(data, folder: directory)
                } catch NetworkMediaError.invalidMetadata { }
            }
            // Existing movie-level TMM output lives above BDMV/STREAM. Read it
            // once only when that folder was actually visited inside the root.
            if let proxy = try BluRayLayout.metadataProxy(in: directory, siblings: entries) {
                let siblings = entries + [proxy]
                var metadata = MediaFilenameParser.identify(proxy.path)
                let (nfo, notice) = NFOSidecarSelection(siblings: siblings).candidate(video: proxy)
                metadata.notice = notice
                if let nfo, let reader = source as? any ReadOnlyMetadataSource {
                    if (nfo.size ?? 0) > NFOReader.maxBytes { metadata.notice = .oversizedNFO }
                    else {
                        metadataFiles += 1
                        guard metadataFiles <= maxMetadataFiles else { throw NetworkMediaError.limitExceeded }
                        do {
                            let data = try await reader.readNFO(nfo.path, root: root)
                            try Task.checkCancellation()
                            metadataBytes += data.count
                            guard metadataBytes <= maxMetadataBytes else { throw NetworkMediaError.limitExceeded }
                            metadata = try NFOReader.parse(data, fallback: metadata, path: nfo.path)
                        } catch NetworkMediaError.invalidMetadata { metadata.notice = .invalidNFO }
                    }
                }
                metadata.artwork = LocalArtworkSelection(siblings: siblings).candidate(video: proxy)
                discMetadata[directory] = metadata
            }
            var directoryVideos: [RemoteMediaEntry] = []
            for var item in entries where item.isVideo {
                try Task.checkCancellation()
                var metadata = MediaFilenameParser.identify(item.path)
                if metadata.details == nil { metadata.details = MediaFilenameParser.technicalDetails(item.path) }
                let (sidecar, notice) = sidecars.candidate(video: item)
                metadata.notice = notice
                if let sidecar, let reader = source as? any ReadOnlyMetadataSource {
                    if (sidecar.size ?? 0) > NFOReader.maxBytes { metadata.notice = .oversizedNFO }
                    else {
                        metadataFiles += 1
                        guard metadataFiles <= maxMetadataFiles else { throw NetworkMediaError.limitExceeded }
                        do {
                            let data = try await reader.readNFO(sidecar.path, root: root)
                            try Task.checkCancellation()
                            metadataBytes += data.count
                            guard metadataBytes <= maxMetadataBytes else { throw NetworkMediaError.limitExceeded }
                            metadata = try NFOReader.parseOrReleaseNotes(data, fallback: metadata, path: sidecar.path)
                        } catch NetworkMediaError.invalidMetadata { metadata.notice = .invalidNFO }
                        // An advertised sidecar that becomes inaccessible is an incomplete scan.
                        // Do not erase previously good metadata on permission/network failures.
                    }
                }
                if let folder = BluRayLayout.movieFolder(for: item.path), let inherited = discMetadata[folder] {
                    if metadata.origin != .nfo { metadata = inherited }
                    else if metadata.artwork == nil { metadata.artwork = inherited.artwork }
                }
                item.metadata = metadata; directoryVideos.append(item)
            }
            // Use resolved NFO identities when deciding whether CD files may
            // share a generic poster; conflicting movies must stay distinct.
            let artwork = LocalArtworkSelection(siblings: entries.filter { !$0.isVideo } + directoryVideos)
            let hasSeasonFolders = entries.contains { $0.isDirectory && SeriesLayout.season($0.path.name) != nil }
            let episodeNames = Set(directoryVideos.filter { $0.metadata?.kind == .episode }.compactMap { SeriesLayout.explicitTitle($0) })
            let onlyEpisodes = !directoryVideos.isEmpty && directoryVideos.allSatisfy { $0.metadata?.kind == .episode }
            let inheritsSeries = seriesMetadata.keys.contains { $0 != directory && directory.isWithin($0) }
            if seriesMetadata[directory] != nil || (!inheritsSeries && SeriesLayout.season(directory.name) == nil &&
                ((hasSeasonFolders && directoryVideos.isEmpty) || (onlyEpisodes && episodeNames.count <= 1))) {
                var info = seriesMetadata[directory] ?? LocalSeriesMetadata(folder: directory, title: episodeNames.first ?? directory.name)
                if !info.title.isEmpty {
                    info.artwork = LocalArtworkSelection.seriesCandidate(siblings: entries, folder: directory)
                    seriesMetadata[directory] = info
                }
            }
            for var item in directoryVideos {
                if let reference = artwork.candidate(video: item) { item.metadata?.artwork = reference }
                if item.metadata?.kind == .episode {
                    item.metadata?.series = seriesMetadata.filter { item.path.isWithin($0.key) }
                        .max { $0.key.encodedSegments.count < $1.key.encodedSegments.count }?.value
                }
                videos.append(item)
            }
            await progress(videos.count)
        }
        try Task.checkCancellation()
        return videos.sorted { $0.path.displayPath.localizedStandardCompare($1.path.displayPath) == .orderedAscending }
    }
}

/// App-private, atomic snapshots. Generation checks also protect against late successful scans.
public actor NetworkLibraryStore {
    public static let shared = NetworkLibraryStore()
    private struct Snapshot: Codable { let version: Int; var libraries: [NetworkLibrary]; var connections: [NetworkStorageConnection]? = nil }
    private struct Configuration: Codable {
        let id: UUID; let name: String; let address: String; let root: DAVPath
        let fileStationAccount: String?
        let connectionID: UUID?
        init(_ library: NetworkLibrary) { id = library.id; name = library.name; address = library.address; root = library.root; fileStationAccount = library.fileStationAccount; connectionID = library.connectionID }
        func library() throws -> NetworkLibrary { NetworkLibrary(id: id, name: name, scope: try WebDAVScope(storageAddress: address), root: root, fileStationAccount: fileStationAccount, connectionID: connectionID) }
    }
    private struct SourceCorrections: Codable { let id: UUID; let values: [LocalMediaCorrection] }
    private struct DurableCatalog: Codable {
        let version: Int
        let configurations: [Configuration]
        let corrections: [SourceCorrections]
        var connections: [NetworkStorageConnection]? = nil
    }
    private let file: URL
    private let catalog: UserDefaults?
    private let catalogKey = "networkMedia.sourceCatalog.v1"
    private let durableKey = "networkMedia.sourceCatalog.v2"
    private static let correctionBytes = 256 * 1024
    private var snapshot: Snapshot?
    private var generations: [UUID: UUID] = [:]
    public init() {
        #if os(tvOS)
        // tvOS denies Application Support writes. Only the rebuildable index belongs in Caches.
        let location: FileManager.SearchPathDirectory = .cachesDirectory
        catalog = .standard
        #else
        let location: FileManager.SearchPathDirectory = .applicationSupportDirectory
        catalog = nil
        #endif
        let root = FileManager.default.urls(for: location, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Nastart", isDirectory: true)
            .appendingPathComponent("NetworkMedia", isDirectory: true)
        file = root.appendingPathComponent("libraries-v1.json")
    }
    init(directory: URL, catalog: UserDefaults? = nil) { file = directory.appendingPathComponent("libraries-v1.json"); self.catalog = catalog }
    public func libraries() throws -> [NetworkLibrary] { try load().libraries }
    public func connections() throws -> [NetworkStorageConnection] { try load().connections ?? [] }
    /// Adopt legacy libraries without changing their index, identity or credentials.
    public func adoptConnections(expected: [NetworkLibrary], connections: [NetworkStorageConnection], assignments: [UUID: UUID]) throws {
        var next = try load()
        guard next.libraries == expected,
              Set(assignments.keys).isSubset(of: Set(expected.filter { $0.connectionID == nil && $0.fileStationAccount == nil }.map(\.id))),
              Set(connections.map(\.id)).isDisjoint(with: Set((next.connections ?? []).map(\.id))) else { throw NetworkMediaError.staleCorrection }
        next.connections = (next.connections ?? []) + connections
        for i in next.libraries.indices { if let id = assignments[next.libraries[i].id] { next.libraries[i].connectionID = id } }
        try write(next)
    }
    public func addConnection(_ connection: NetworkStorageConnection, library: NetworkLibrary? = nil) throws {
        var next = try load()
        guard !(next.connections ?? []).contains(where: { $0.id == connection.id }) else { throw NetworkMediaError.localStore }
        next.connections = (next.connections ?? []) + [connection]
        if let library {
            guard library.connectionID == connection.id, !next.libraries.contains(where: { $0.id == library.id }) else { throw NetworkMediaError.localStore }
            next.libraries.append(library)
        }
        try write(next)
    }
    public func renameConnection(_ connection: NetworkStorageConnection, name: String) throws {
        var next = try load()
        guard let i = next.connections?.firstIndex(of: connection) else { throw NetworkMediaError.staleCorrection }
        next.connections?[i] = NetworkStorageConnection(id: connection.id, name: name, scope: try WebDAVScope(storageAddress: connection.address))
        try write(next)
    }
    public func add(_ library: NetworkLibrary) throws {
        _ = try WebDAVScope(storageAddress: library.address)
        var next = try load()
        guard !next.libraries.contains(where: { $0.id == library.id }) else { throw NetworkMediaError.localStore }
        next.libraries.append(library); try write(next)
    }
    /// Only removes this app's local index. There is no remote operation.
    public func remove(_ id: UUID) throws {
        var next = try load()
        next.libraries.removeAll { $0.id == id }
        try write(next); generations[id] = nil
    }
    public func saveCorrection(_ id: UUID, expected: RemoteMediaEntry, values: LocalMediaCorrection.Values) throws {
        try Task.checkCancellation()
        var next = try load()
        guard let index = next.libraries.firstIndex(where: { $0.id == id }),
              next.libraries[index].files.contains(expected) else { throw NetworkMediaError.staleCorrection }
        var corrections = next.libraries[index].corrections ?? []
        corrections.removeAll { $0.path == expected.path }
        corrections.append(LocalMediaCorrection(file: expected, values: values))
        next.libraries[index].corrections = corrections
        try write(next)
    }
    public func restoreIdentification(_ id: UUID, path: DAVPath) throws {
        try Task.checkCancellation()
        var next = try load()
        guard let index = next.libraries.firstIndex(where: { $0.id == id }), path.isWithin(next.libraries[index].root) else {
            throw NetworkMediaError.staleCorrection
        }
        next.libraries[index].corrections?.removeAll { $0.path == path }
        if next.libraries[index].corrections?.isEmpty == true { next.libraries[index].corrections = nil }
        try write(next)
    }
    public func beginScan(_ id: UUID) throws -> UUID {
        guard try load().libraries.contains(where: { $0.id == id }) else { throw NetworkMediaError.localStore }
        let token = UUID(); generations[id] = token; return token
    }
    public func abort(_ id: UUID, token: UUID) { if generations[id] == token { generations[id] = nil } }
    public func commit(_ id: UUID, token: UUID, files: [RemoteMediaEntry]) throws {
        guard generations[id] == token, !Task.isCancelled else { throw CancellationError() }
        var next = try load()
        guard let index = next.libraries.firstIndex(where: { $0.id == id }) else { throw NetworkMediaError.localStore }
        let root = next.libraries[index].root
        guard files.allSatisfy({ !$0.isDirectory && $0.isVideo && $0.path.isWithin(root) }), Set(files.map(\.id)).count == files.count else { throw NetworkMediaError.incompleteListing }
        next.libraries[index].files = files
        next.libraries[index].lastCompletedScan = Date()
        next.libraries[index].artworkScanVersion = 5
        try write(next); generations[id] = nil
    }
    public func scan(_ library: NetworkLibrary, source: any ReadOnlyDirectorySource,
                     progress: @Sendable (Int) async -> Void = { _ in }) async throws {
        guard let current = try load().libraries.first(where: { $0.id == library.id }),
              sameConfiguration(current, library) else { throw NetworkMediaError.staleCorrection }
        let token = try beginScan(library.id)
        do {
            let files = try await ReadOnlyLibraryScanner.scan(source: source, root: library.root, progress: progress)
            try Task.checkCancellation()
            try commit(library.id, token: token, files: files)
        } catch { abort(library.id, token: token); throw error }
    }
    /// Stage the new folder before committing configuration and index together.
    /// A new local identity isolates credentials and cached artwork; no NAS mutation exists.
    public func relocate(_ library: NetworkLibrary, replacement: NetworkLibrary, source: any ReadOnlyDirectorySource,
                         progress: @Sendable (Int) async -> Void = { _ in }) async throws {
        guard let current = try load().libraries.first(where: { $0.id == library.id }),
              sameConfiguration(current, library) else { throw NetworkMediaError.staleCorrection }
        guard replacement.id != library.id, replacement.files.isEmpty,
              replacement.name == library.name, replacement.fileStationAccount == library.fileStationAccount,
              replacement.connectionID == library.connectionID,
              try WebDAVScope(storageAddress: library.address).sameOrigin(WebDAVScope(storageAddress: replacement.address).baseURL),
              try !load().libraries.contains(where: { $0.id == replacement.id }) else { throw NetworkMediaError.localStore }
        let root = replacement.root
        let token = try beginScan(library.id)
        do {
            let files = try await ReadOnlyLibraryScanner.scan(source: source, root: root, progress: progress)
            try Task.checkCancellation()
            guard generations[library.id] == token else { throw CancellationError() }
            var next = try load()
            guard let index = next.libraries.firstIndex(where: { $0.id == library.id }),
                  sameConfiguration(next.libraries[index], library) else { throw NetworkMediaError.staleCorrection }
            guard files.allSatisfy({ !$0.isDirectory && $0.isVideo && $0.path.isWithin(root) }),
                  Set(files.map(\.id)).count == files.count else { throw NetworkMediaError.incompleteListing }
            var replacement = replacement
            replacement.files = files; replacement.lastCompletedScan = Date(); replacement.artworkScanVersion = 5
            let corrections = (library.address == replacement.address ? next.libraries[index].corrections ?? [] : []).filter { correction in
                files.contains { $0.path == correction.path && correction.applies(to: $0) }
            }
            replacement.corrections = corrections.isEmpty ? nil : corrections
            next.libraries[index] = replacement
            try write(next); generations[library.id] = nil
        } catch { abort(library.id, token: token); throw error }
    }
    /// All linked folders and the new endpoint commit together after complete scans.
    /// The old connection remains usable throughout failure or cancellation.
    public func replaceConnection(_ connection: NetworkStorageConnection, replacement: NetworkStorageConnection,
                                  folders: [(original: NetworkLibrary, replacement: NetworkLibrary)],
                                  preservingCorrections: Bool,
                                  source: @Sendable (NetworkLibrary) throws -> any ReadOnlyDirectorySource,
                                  progress: @Sendable (Int) async -> Void = { _ in }) async throws {
        let initial = try load()
        let linked = initial.libraries.filter { $0.connectionID == connection.id }
        guard (initial.connections ?? []).contains(connection), replacement.id != connection.id,
              !(initial.connections ?? []).contains(where: { $0.id == replacement.id }),
              Set(linked.map(\.id)) == Set(folders.map { $0.original.id }), folders.count == linked.count,
              Set(folders.map { $0.replacement.id }).count == folders.count else { throw NetworkMediaError.staleCorrection }
        for folder in folders {
            let expected = try replacement.replacement(for: folder.original)
            guard linked.contains(folder.original), folder.replacement.id != folder.original.id,
                  !initial.libraries.contains(where: { $0.id == folder.replacement.id }),
                  folder.replacement.address == expected.address, folder.replacement.root == expected.root,
                  folder.replacement.name == expected.name, folder.replacement.fileStationAccount == nil,
                  folder.replacement.connectionID == replacement.id, folder.replacement.files.isEmpty else { throw NetworkMediaError.localStore }
        }
        var tokens: [UUID: UUID] = [:]
        for folder in folders { tokens[folder.original.id] = try beginScan(folder.original.id) }
        do {
            var staged: [UUID: NetworkLibrary] = [:]
            var total = 0
            for folder in folders {
                var next = folder.replacement
                let completedCount = total
                next.files = try await ReadOnlyLibraryScanner.scan(source: source(next), root: next.root) { count in await progress(completedCount + count) }
                try Task.checkCancellation()
                next.lastCompletedScan = Date(); next.artworkScanVersion = 5
                total += next.files.count
                if preservingCorrections, try WebDAVScope(storageAddress: connection.address).sameOrigin(WebDAVScope(storageAddress: replacement.address).baseURL) {
                    let values = (folder.original.corrections ?? []).filter { correction in next.files.contains { correction.applies(to: $0) } }
                    next.corrections = values.isEmpty ? nil : values
                }
                staged[folder.original.id] = next
            }
            var next = try load()
            guard let i = next.connections?.firstIndex(of: connection),
                  next.libraries.filter({ $0.connectionID == connection.id }) == linked,
                  tokens.allSatisfy({ generations[$0.key] == $0.value }) else { throw NetworkMediaError.staleCorrection }
            try Task.checkCancellation()
            next.connections?[i] = replacement
            for j in next.libraries.indices { if let replacement = staged[next.libraries[j].id] { next.libraries[j] = replacement } }
            try write(next)
            for (id, token) in tokens { abort(id, token: token) }
        } catch {
            for (id, token) in tokens { abort(id, token: token) }
            throw error
        }
    }
    private func sameConfiguration(_ lhs: NetworkLibrary, _ rhs: NetworkLibrary) -> Bool {
        lhs.id == rhs.id && lhs.address == rhs.address && lhs.root == rhs.root
            && lhs.name == rhs.name && lhs.fileStationAccount == rhs.fileStationAccount && lhs.connectionID == rhs.connectionID
    }
    private func load() throws -> Snapshot {
        if let snapshot { return snapshot }
        let configurations: [Configuration]?
        var savedConnections: [NetworkStorageConnection]?
        var savedCorrections: [UUID: [LocalMediaCorrection]] = [:]
        if let catalog {
            do {
                if let raw = catalog.data(forKey: durableKey) {
                    guard raw.count <= 330 * 1024 else { throw NetworkMediaError.localStore }
                    let durable = try JSONDecoder().decode(DurableCatalog.self, from: raw)
                    guard durable.version == 2, Set(durable.corrections.map(\.id)).count == durable.corrections.count,
                          try JSONEncoder().encode(durable.configurations).count <= 64 * 1024,
                          try JSONEncoder().encode(durable.configurations).count + JSONEncoder().encode(durable.connections ?? []).count <= 64 * 1024,
                          try JSONEncoder().encode(durable.corrections).count <= Self.correctionBytes else { throw NetworkMediaError.localStore }
                    configurations = durable.configurations
                    savedConnections = durable.connections
                    savedCorrections = Dictionary(uniqueKeysWithValues: durable.corrections.map { ($0.id, $0.values) })
                    guard Set(savedCorrections.keys).isSubset(of: Set(durable.configurations.map(\.id))) else { throw NetworkMediaError.localStore }
                } else if let raw = catalog.data(forKey: catalogKey) {
                    guard raw.count <= 64 * 1024 else { throw NetworkMediaError.localStore }
                    configurations = try JSONDecoder().decode([Configuration].self, from: raw)
                } else { configurations = [] }
                guard Set(configurations!.map(\.id)).count == configurations!.count else { throw NetworkMediaError.localStore }
                for item in configurations! {
                    var library = try item.library(); library.corrections = savedCorrections[item.id]
                    try validateCorrections(library)
                }
            } catch { throw NetworkMediaError.localStore }
        } else { configurations = nil }
        // The catalog is authoritative; a leftover cache cannot resurrect a removed source.
        if configurations?.isEmpty == true {
            let empty = Snapshot(version: 1, libraries: [], connections: savedConnections)
            try validateConnections(empty); snapshot = empty; return empty
        }
        var result: Snapshot
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= 50 * 1024 * 1024 else { throw NetworkMediaError.localStore }
                result = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: file))
                guard result.version == 1, Set(result.libraries.map(\.id)).count == result.libraries.count else { throw NetworkMediaError.localStore }
                for library in result.libraries {
                    _ = try WebDAVScope(storageAddress: library.address)
                    guard library.files.allSatisfy({ $0.path.isWithin(library.root) && $0.isVideo && !$0.isDirectory }),
                          Set(library.files.map(\.id)).count == library.files.count else { throw NetworkMediaError.localStore }
                    try validateCorrections(library)
                }
            } catch { throw NetworkMediaError.localStore }
        } else { result = Snapshot(version: 1, libraries: []) }
        if let configurations {
            let cached = Dictionary(uniqueKeysWithValues: result.libraries.map { ($0.id, $0) })
            do {
                result.libraries = try configurations.map { configuration in
                    var library = try configuration.library()
                    if let indexed = cached[library.id], indexed.address == library.address, indexed.root == library.root, indexed.fileStationAccount == library.fileStationAccount {
                        library.files = indexed.files; library.lastCompletedScan = indexed.lastCompletedScan
                        library.artworkScanVersion = indexed.artworkScanVersion
                    }
                    library.corrections = savedCorrections[library.id]
                    return library
                }
            } catch { throw NetworkMediaError.localStore }
            result.connections = savedConnections
        }
        try validateConnections(result)
        snapshot = result; return result
    }
    private func write(_ next: Snapshot) throws {
        do {
            try validateConnections(next)
            for library in next.libraries { try validateCorrections(library) }
            let data = try JSONEncoder().encode(next)
            guard data.count <= 50 * 1024 * 1024 else { throw NetworkMediaError.localStore }
            let configurations = try JSONEncoder().encode(next.libraries.map(Configuration.init))
            let connections = try JSONEncoder().encode(next.connections ?? [])
            guard configurations.count + connections.count <= 64 * 1024 else { throw NetworkMediaError.localStore }
            let corrections = next.libraries.compactMap { library -> SourceCorrections? in
                guard let values = library.corrections, !values.isEmpty else { return nil }
                return SourceCorrections(id: library.id, values: values)
            }
            // Separate budgets; user corrections cannot crowd out the connection configuration.
            guard try JSONEncoder().encode(corrections).count <= Self.correctionBytes else { throw NetworkMediaError.correctionLimit }
            let durable = try JSONEncoder().encode(DurableCatalog(version: 2, configurations: next.libraries.map(Configuration.init), corrections: corrections, connections: next.connections))
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            if let catalog {
                // One durable value commits source configuration and corrections together.
                if next.libraries.isEmpty && (next.connections ?? []).isEmpty { catalog.removeObject(forKey: durableKey) }
                else if catalog.data(forKey: durableKey) != durable { catalog.set(durable, forKey: durableKey) }
                catalog.removeObject(forKey: catalogKey)
            }
            snapshot = next
        } catch {
            LocalStorageDiagnostics.record("index-write", error: error)
            if error as? NetworkMediaError == .correctionLimit { throw NetworkMediaError.correctionLimit }
            throw NetworkMediaError.localStore
        }
    }
    private func validateConnections(_ snapshot: Snapshot) throws {
        let connections = snapshot.connections ?? []
        guard Set(connections.map(\.id)).count == connections.count,
              Set(connections.map(\.id)).isDisjoint(with: Set(snapshot.libraries.map(\.id))),
              try JSONEncoder().encode(connections).count <= 64 * 1024 else { throw NetworkMediaError.localStore }
        for connection in connections {
            _ = try WebDAVScope(storageAddress: connection.address)
            guard !connection.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, connection.name.count <= 256 else { throw NetworkMediaError.localStore }
        }
        for library in snapshot.libraries {
            if let id = library.connectionID {
                guard library.fileStationAccount == nil, let connection = connections.first(where: { $0.id == id }),
                      try WebDAVScope(storageAddress: library.address).sameOrigin(WebDAVScope(storageAddress: connection.address).baseURL) else { throw NetworkMediaError.localStore }
            }
        }
    }
    private func validateCorrections(_ library: NetworkLibrary) throws {
        guard library.files.allSatisfy({ file in
            (file.metadata?.artwork.map { $0.isValid(root: library.root, video: file.path) } ?? true)
                && (file.metadata?.series.map { file.metadata?.kind == .episode && $0.isValid(root: library.root, video: file.path) } ?? true)
        }) else { throw NetworkMediaError.localStore }
        let values = library.corrections ?? []
        guard Set(values.map { $0.path.key }).count == values.count,
              values.allSatisfy({ $0.path.isWithin(library.root) && $0.path != library.root && RemoteMediaEntry(path: $0.path, isDirectory: false).isVideo }) else { throw NetworkMediaError.localStore }
    }
}

import XCTest
@testable import Nastart

final class NonPlaybackPolicyTests: XCTestCase {
    func testFileSortingUsesNaturalNamesExtensionsAndBothDirections() {
        let items = [file("Episode10.mkv"), file("Episode2.mp4"), file("Episode1.mkv"), file("Folder", folder: true)]
        XCTAssertEqual(FileBrowserSort.name.sorted(items, ascending: true).map(\.name),
                       ["Folder", "Episode1.mkv", "Episode2.mp4", "Episode10.mkv"])
        XCTAssertEqual(FileBrowserSort.name.sorted(items, ascending: false).map(\.name),
                       ["Folder", "Episode10.mkv", "Episode2.mp4", "Episode1.mkv"])
        XCTAssertEqual(FileBrowserSort.kind.sorted(items, ascending: true).map(\.name),
                       ["Folder", "Episode1.mkv", "Episode10.mkv", "Episode2.mp4"])
    }

    func testFileSortingUsesNumericMetadataAndKeepsUnknownValuesLast() {
        let items = [file("Large", size: 128_800_000_000, modified: 200),
                     file("Unknown"), file("Small", size: 900_000_000, modified: 100),
                     file("Zero", size: 0, modified: 50), file("Folder", folder: true)]
        for sort in [FileBrowserSort.size, .modified] {
            XCTAssertEqual(sort.sorted(items, ascending: true).map(\.name),
                           ["Folder", "Zero", "Small", "Large", "Unknown"])
            XCTAssertEqual(sort.sorted(items, ascending: false).map(\.name),
                           ["Folder", "Large", "Small", "Zero", "Unknown"])
        }
    }

    func testFileMetadataMappingUsesDSMTimeAndDoesNotTreatDirectorySizeAsContents() throws {
        let json = #"{"files":[{"name":"Film.mkv","isdir":false,"additional":{"size":128800000000,"time":{"mtime":1700000000}}},{"name":"Folder","isdir":true,"additional":{"size":4096,"time":{"mtime":1700000100}}},{"name":"Missing.mkv","isdir":false}]}"#
        let data = try JSONDecoder().decode(DSMJSONValue.self, from: Data(json.utf8))
        let items = DSMClient.mapFileItems(data, parentPath: "/video")
        let movie = try XCTUnwrap(items.first { $0.name == "Film.mkv" })
        XCTAssertEqual(movie.sizeBytes, 128_800_000_000)
        XCTAssertEqual(movie.modifiedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNil(items.first { $0.isFolder }?.sizeBytes)
        XCTAssertEqual(items.first { $0.isFolder }?.modifiedAt, Date(timeIntervalSince1970: 1_700_000_100))
        XCTAssertNil(items.first { $0.name == "Missing.mkv" }?.modifiedAt)
    }

    func testLegacyFileSnapshotDecodesWithoutNewMetadata() throws {
        let json = #"{"id":"148B71EC-9C60-449C-9196-4D3E9F4016DC","name":"Film.mkv","subtitle":"/video/Film.mkv","path":"/video/Film.mkv","kind":"video","sizeText":"128 GB","children":[]}"#
        let item = try JSONDecoder().decode(FileItem.self, from: Data(json.utf8))
        XCTAssertNil(item.sizeBytes)
        XCTAssertNil(item.modifiedAt)
        let roundTrip = try JSONDecoder().decode(FileItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(roundTrip.path, item.path)
    }

    private func file(_ name: String, folder: Bool = false, size: Int64? = nil, modified: TimeInterval? = nil) -> FileItem {
        FileItem(id: UUID(), name: name, subtitle: "/\(name)", kind: folder ? .folder : .video,
                 sizeText: nil, children: [], sizeBytes: size,
                 modifiedAt: modified.map { Date(timeIntervalSince1970: $0) })
    }

    func testMediaRangePolicyKeepsOpenResponsesFiniteUpstreamAndDetectsContinuation() {
        XCTAssertEqual(
            MediaRangePolicy.boundedRange("bytes=0-"),
            "bytes=0-33554431"
        )
        XCTAssertEqual(
            MediaRangePolicy.boundedRange("bytes=90000000-"),
            "bytes=90000000-123554431"
        )
        XCTAssertTrue(MediaRangePolicy.isOpenEnded("bytes=0-"))
        XCTAssertFalse(MediaRangePolicy.isOpenEnded("bytes=0-4095"))
        XCTAssertFalse(MediaRangePolicy.isOpenEnded("bytes=abc-"))
    }

    func testMediaRangePolicyDoesNotTurnMalformedRangesIntoAnOpenResponse() {
        XCTAssertEqual(
            MediaRangePolicy.boundedRange("invalid"),
            "bytes=0-33554431"
        )
        XCTAssertEqual(
            MediaRangePolicy.boundedRange("bytes=12-999", maximumLength: 128),
            "bytes=12-139"
        )
    }

    func testMediaRangePolicyParsesStrictContentRangeMetadata() {
        XCTAssertEqual(
            MediaRangePolicy.contentRange(from: "bytes 100-199/1000"),
            MediaRangePolicy.ContentRange(start: 100, end: 199, totalLength: 1_000)
        )
        XCTAssertEqual(MediaRangePolicy.requestedRangeStart(from: "bytes=100-"), 100)
        XCTAssertEqual(MediaRangePolicy.requestedRangeStart(from: "bytes 100-199"), 100)
        XCTAssertNil(MediaRangePolicy.contentRange(from: "bytes */1000"))
        XCTAssertNil(MediaRangePolicy.contentRange(from: "bytes 200-199/1000"))
        XCTAssertNil(MediaRangePolicy.contentRange(from: "bytes 100-1000/1000"))
        XCTAssertNil(MediaRangePolicy.contentRange(from: "bytes 100-199/*"))
    }

    func testMediaRangePolicyRejectsUnexpectedUpstreamPartialResponses() {
        XCTAssertEqual(
            MediaRangePolicy.validatedPartialResponse(
                statusCode: 206,
                contentRange: "bytes 33554432-67108863/2684354560",
                expectedStart: 33_554_432
            ),
            MediaRangePolicy.ContentRange(
                start: 33_554_432,
                end: 67_108_863,
                totalLength: 2_684_354_560
            )
        )
        XCTAssertNil(MediaRangePolicy.validatedPartialResponse(
            statusCode: 200,
            contentRange: nil,
            expectedStart: 0
        ))
        XCTAssertNil(MediaRangePolicy.validatedPartialResponse(
            statusCode: 206,
            contentRange: "bytes 0-33554431/2684354560",
            expectedStart: 33_554_432
        ))
        XCTAssertNil(MediaRangePolicy.validatedPartialResponse(
            statusCode: 206,
            contentRange: "bytes 33554432-67108863/*",
            expectedStart: 33_554_432
        ))
    }

    func testPrivateNetworkClassification() {
        XCTAssertTrue(NetworkHostClassifier.isPrivate("192.168.1.20"))
        XCTAssertTrue(NetworkHostClassifier.isPrivate("nas.local"))
        XCTAssertTrue(NetworkHostClassifier.isPrivate("fd12:3456::1"))
        XCTAssertFalse(NetworkHostClassifier.isPrivate("203.0.113.10"))
    }

    func testManualServiceURLPolicyRejectsCredentialsAndPublicHTTP() {
        XCTAssertNil(UserConfiguredServiceURLPolicy.normalizedURL(from: "http://203.0.113.10:8080"))
        XCTAssertNil(UserConfiguredServiceURLPolicy.normalizedURL(from: "https://user:password@nas.local"))
        XCTAssertNotNil(UserConfiguredServiceURLPolicy.normalizedURL(from: "http://192.168.1.20:8080"))
        XCTAssertNotNil(UserConfiguredServiceURLPolicy.normalizedURL(from: "https://example.com"))
    }

    func testDSMBaseURLNormalizationRemovesQueryAndAddsDefaultPort() throws {
        let url = try DSMClient.normalizedBaseURL(from: "nas.local/path?secret=ignored", defaultScheme: "https")
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "nas.local")
        XCTAssertEqual(url.port, 5001)
        XCTAssertNil(url.query)
        XCTAssertNil(url.fragment)
    }

    func testDSMBaseURLAcceptsRemoteHTTPSDomainWithExplicitPort() throws {
        let bareDomain = try DSMClient.normalizedBaseURL(from: "nas.example.com:5443", defaultScheme: "https")
        XCTAssertEqual(bareDomain.scheme, "https")
        XCTAssertEqual(bareDomain.host, "nas.example.com")
        XCTAssertEqual(bareDomain.port, 5443)

        let fullURL = try DSMClient.normalizedBaseURL(from: "https://nas.example.com:5001")
        XCTAssertEqual(fullURL.scheme, "https")
        XCTAssertEqual(fullURL.host, "nas.example.com")
        XCTAssertEqual(fullURL.port, 5001)
    }

    func testDSMBaseURLRejectsPublicHTTP() {
        XCTAssertThrowsError(try DSMClient.normalizedBaseURL(from: "http://203.0.113.10:5000")) { error in
            guard case DSMClientError.insecureHTTP = error else {
                return XCTFail("Expected insecureHTTP, got \(error)")
            }
        }
    }

    func testDSMURLBuilderPreservesBasePathAndDropsQuery() {
        let baseURL = URL(string: "https://nas.local/nastart?sid=redacted")!
        let requestURL = DSMURLBuilder.url(baseURL: baseURL, appending: "/webapi/entry.cgi")
        XCTAssertEqual(requestURL?.path, "/nastart/webapi/entry.cgi")
        XCTAssertNil(requestURL?.query)
        XCTAssertNil(requestURL?.fragment)
    }

    func testServiceStatusReplacementPreservesEndpointIdentity() {
        let endpoint = URL(string: "http://192.168.1.20:8080")!
        let service = LaunchpadService(
            id: UUID(),
            name: "Test",
            iconText: "T",
            category: .tools,
            status: .unknown,
            subtitle: "service.subtitle.manual",
            detail: "service.detail.manual",
            isMedia: false,
            cpu: nil,
            memoryText: nil,
            endpoint: endpoint,
            source: .manual
        )

        let updated = service.replacing(status: .online)
        XCTAssertEqual(updated.id, service.id)
        XCTAssertEqual(updated.endpoint, endpoint)
        XCTAssertEqual(updated.status, .online)
        XCTAssertEqual(updated.source, .manual)
    }

    func testJellyfinServiceDetectionUsesNameAndKnownPorts() {
        let namedService = LaunchpadService(
            id: UUID(),
            name: "Jellyfin",
            iconText: "J",
            category: .media,
            status: .online,
            subtitle: "jellyfin/jellyfin",
            detail: "Agent · 18444",
            isMedia: true,
            cpu: nil,
            memoryText: nil,
            endpoint: URL(string: "https://media.example.com:18444")!,
            source: .container
        )
        XCTAssertTrue(namedService.isJellyfin)
        XCTAssertEqual(namedService.webProfileName, "jellyfin")
        XCTAssertTrue(namedService.forcesMobileWebMode)
        XCTAssertTrue(namedService.usesSystemInAppBrowser)

        let portMappedService = LaunchpadService(
            id: UUID(),
            name: "Media Server",
            iconText: "MS",
            category: .media,
            status: .online,
            subtitle: "container.image",
            detail: "Agent · 18444",
            isMedia: true,
            cpu: nil,
            memoryText: nil,
            ports: ["0.0.0.0:18444->8096/tcp"],
            endpoint: URL(string: "https://media.example.com:18444")!,
            source: .container
        )
        XCTAssertTrue(portMappedService.isJellyfin)
        XCTAssertEqual(portMappedService.webProfileName, "jellyfin")
        XCTAssertTrue(portMappedService.forcesMobileWebMode)
        XCTAssertTrue(portMappedService.usesSystemInAppBrowser)

        let apiPortService = LaunchpadService(
            id: UUID(),
            name: "Media API",
            iconText: "MA",
            category: .media,
            status: .online,
            subtitle: "container.image",
            detail: "Agent · 8097",
            isMedia: true,
            cpu: nil,
            memoryText: nil,
            endpoint: URL(string: "https://media.example.com:8097")!,
            source: .container
        )
        XCTAssertTrue(apiPortService.isJellyfin)
        XCTAssertEqual(apiPortService.webProfileName, "jellyfin")
        XCTAssertTrue(apiPortService.usesSystemInAppBrowser)
    }

    func testArrSuiteServicesUseDistinctLaunchpadIconIdentities() {
        let services = [
            LaunchpadService(
                id: UUID(),
                name: "Prowlarr",
                iconText: "PR",
                category: .downloads,
                status: .online,
                subtitle: "linuxserver/prowlarr",
                detail: "Agent · 9696",
                isMedia: false,
                cpu: nil,
                memoryText: nil,
                source: .container
            ),
            LaunchpadService(
                id: UUID(),
                name: "Radarr",
                iconText: "RD",
                category: .media,
                status: .online,
                subtitle: "linuxserver/radarr",
                detail: "Agent · 7878",
                isMedia: false,
                cpu: nil,
                memoryText: nil,
                source: .container
            ),
            LaunchpadService(
                id: UUID(),
                name: "Sonarr",
                iconText: "SN",
                category: .media,
                status: .online,
                subtitle: "linuxserver/sonarr",
                detail: "Agent · 8989",
                isMedia: false,
                cpu: nil,
                memoryText: nil,
                source: .container
            )
        ]

        XCTAssertEqual(Set(services.map(\.symbolName)).count, services.count)
        XCTAssertEqual(services.compactMap(\.iconBadgeText), ["PR", "RD", "SN"])
    }

    func testServiceIconRegistryCoversCommonHomeLabFixtures() {
        let fixtures: [(name: String, symbol: String, badge: String?, category: ServiceCategory)] = [
            ("Jellyfin", "play.rectangle", "JF", .media),
            ("Plex", "play.circle", "PX", .media),
            ("Navidrome", "music.note.list", "NV", .media),
            ("Audiobookshelf", "books.vertical", "AB", .media),
            ("Immich", "photo.on.rectangle", "IM", .media),
            ("PhotoPrism", "camera.aperture", "PP", .media),
            ("qBittorrent", "arrow.down.circle", "QB", .downloads),
            ("Transmission", "arrow.down.circle", "TR", .downloads),
            ("Prowlarr", "magnifyingglass.circle", "PR", .downloads),
            ("Radarr", "film", "RD", .media),
            ("Sonarr", "tv", "SN", .media),
            ("Lidarr", "music.mic", "LD", .media),
            ("Readarr", "book", "RA", .media),
            ("Bazarr", "captions.bubble", "BZ", .media),
            ("Overseerr", "person.badge.plus", "OS", .downloads),
            ("Home Assistant", "house", "HA", .tools),
            ("Portainer", "square.stack.3d.up", "PT", .tools),
            ("Grafana", "chart.xyaxis.line", "GF", .tools),
            ("Paperless-ngx", "doc.text", "PN", .tools),
            ("Vaultwarden", "key", "VW", .tools),
            ("Nextcloud", "cloud", "NC", .tools),
            ("Calibre-Web", "books.vertical", "CW", .media),
            ("Mealie", "fork.knife", "ML", .tools),
            ("AdGuard", "shield", "AG", .network),
            ("Uptime Kuma", "waveform.path.ecg", nil, .tools)
        ]

        for fixture in fixtures {
            let identity = ServiceIconRegistry.identity(
                name: fixture.name,
                subtitle: "linuxserver/\(fixture.name.lowercased())"
            )
            XCTAssertEqual(identity.symbolName, fixture.symbol, fixture.name)
            XCTAssertEqual(identity.badgeText, fixture.badge, fixture.name)
            XCTAssertEqual(identity.category, fixture.category, fixture.name)
        }
    }

    func testServiceIconRegistryDoesNotTreatGenericDSMPackageTextAsDSM() {
        let identity = ServiceIconRegistry.identity(
            name: "Package Center",
            subtitle: "DSM package",
            detail: "package metadata"
        )

        XCTAssertNotEqual(identity.symbolName, "server.rack")
        XCTAssertNotEqual(identity.displayName, "DSM")
    }

    func testUnknownLaunchpadServiceFallsBackToCategorySymbolWithBadge() {
        let service = LaunchpadService(
            id: UUID(),
            name: "Custom Backup",
            iconText: "CB",
            category: .tools,
            status: .online,
            subtitle: "custom/image",
            detail: "Agent · 8181",
            isMedia: false,
            cpu: nil,
            memoryText: nil,
            source: .container
        )

        XCTAssertEqual(service.symbolName, ServiceCategory.tools.symbolName)
        XCTAssertEqual(service.iconBadgeText, "CB")
    }

    func testDownloaderServiceKeepsDefaultWebProfile() {
        let service = LaunchpadService(
            id: UUID(),
            name: "qBittorrent",
            iconText: "QB",
            category: .downloads,
            status: .online,
            subtitle: "linuxserver/qbittorrent",
            detail: "Agent · 8081",
            isMedia: false,
            cpu: nil,
            memoryText: nil,
            endpoint: URL(string: "https://downloads.example.com:8081")!,
            source: .container
        )
        XCTAssertFalse(service.isJellyfin)
        XCTAssertEqual(service.webProfileName, "default")
        XCTAssertFalse(service.forcesMobileWebMode)
        XCTAssertFalse(service.usesSystemInAppBrowser)
    }

    func testLaunchpadDefaultVisibilityUsesActionableServicePolicy() {
        XCTAssertTrue(
            LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
                name: "Download Station",
                hasEndpoint: true
            )
        )
        XCTAssertTrue(
            LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
                name: "Plex Media Server",
                hasEndpoint: true
            )
        )
        XCTAssertFalse(
            LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
                name: "Container Manager",
                hasEndpoint: true
            )
        )
        XCTAssertFalse(
            LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
                name: "File Station",
                hasEndpoint: true
            )
        )
        XCTAssertEqual(
            LaunchpadDefaultVisibilityPolicy.reason(for: LaunchpadService(
                id: UUID(),
                name: "File Station",
                iconText: "FS",
                category: .tools,
                status: .installed,
                subtitle: "DSM package",
                detail: "File Station",
                isMedia: false,
                cpu: nil,
                memoryText: nil,
                endpoint: URL(string: "https://nas.example.com/file"),
                source: .package,
                isLaunchpadVisible: false
            )),
            .systemOrUnknown
        )
        XCTAssertFalse(
            LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
                name: "Unknown System Package",
                hasEndpoint: true
            )
        )
        XCTAssertFalse(
            LaunchpadDefaultVisibilityPolicy.shouldShowPackage(
                name: "Download Station",
                hasEndpoint: false
            )
        )
        XCTAssertTrue(
            LaunchpadDefaultVisibilityPolicy.shouldShowContainer(
                name: "jellyfin",
                image: "jellyfin/jellyfin:latest",
                hasEndpoint: true
            )
        )
        XCTAssertTrue(
            LaunchpadDefaultVisibilityPolicy.shouldShowContainer(
                name: "homeassistant",
                image: "ghcr.io/home-assistant/home-assistant:stable",
                hasEndpoint: true
            )
        )
        XCTAssertTrue(
            LaunchpadDefaultVisibilityPolicy.shouldShowContainer(
                name: "paperless",
                image: "ghcr.io/paperless-ngx/paperless-ngx:latest",
                hasEndpoint: true
            )
        )
        XCTAssertEqual(
            LaunchpadDefaultVisibilityPolicy.packageReason(
                name: "Synology Photos",
                hasEndpoint: true
            ),
            .synologyApp
        )
        XCTAssertFalse(
            LaunchpadDefaultVisibilityPolicy.shouldShowContainer(
                name: "postgres",
                image: "postgres:16",
                hasEndpoint: true
            )
        )
        XCTAssertFalse(
            LaunchpadDefaultVisibilityPolicy.shouldShowContainer(
                name: "random-worker",
                image: "acme/worker:latest",
                hasEndpoint: true
            )
        )
    }

    func testAgentSnapshotMergerUsesSharedServiceRegistryForVisibility() throws {
        let agent = AgentSnapshot(
            agentId: "agent-1",
            apiVersion: 1,
            agentVersion: "0.1.0",
            timestamp: 1_800_000_000,
            host: AgentSnapshot.Host(
                hostname: "nas",
                platform: "linux",
                platformRelease: "7.2",
                architecture: "x86_64",
                loadAverage: [0.1, 0.2, 0.3],
                memory: AgentSnapshot.Host.Memory(totalBytes: 8_000, usedBytes: 4_000),
                storage: AgentSnapshot.Host.Storage(totalBytes: 16_000, usedBytes: 8_000, freeBytes: 8_000)
            ),
            containers: [
                AgentSnapshot.Container(
                    id: "paperless-container",
                    name: "paperless",
                    image: "ghcr.io/paperless-ngx/paperless-ngx:latest",
                    state: "running",
                    status: "Up",
                    ports: ["8000:8000/tcp"],
                    endpoints: [AgentSnapshot.Container.Endpoint(scheme: "http", port: 8000)]
                ),
                AgentSnapshot.Container(
                    id: "postgres-container",
                    name: "postgres",
                    image: "postgres:16",
                    state: "running",
                    status: "Up",
                    ports: ["5432:5432/tcp"],
                    endpoints: [AgentSnapshot.Container.Endpoint(scheme: "http", port: 5432)]
                )
            ],
            inventory: AgentSnapshot.Inventory(dockerAvailable: true, dockerError: nil)
        )

        let merged = AgentSnapshotMerger.merge(
            dsm: Self.emptyDSMSnapshot(),
            agent: agent,
            agentBaseURL: URL(string: "http://192.168.1.20:8787")!,
            health: AgentHealthSnapshot(handshake: AgentHandshake(
                agentId: "agent-1",
                apiVersion: 1,
                agentVersion: "0.1.0",
                hostIdentity: "nas",
                providerHint: "generic-linux",
                permissionLevel: "read",
                capabilities: ["docker.containers.read", "services.detect"],
                containerCount: 2,
                timestamp: 1_800_000_000
            ))
        )

        let paperless = try XCTUnwrap(merged.services.first { $0.name == "Paperless-ngx" })
        XCTAssertEqual(paperless.iconText, "PN")
        XCTAssertEqual(paperless.category, .tools)
        XCTAssertTrue(paperless.isLaunchpadVisible)

        let postgres = try XCTUnwrap(merged.services.first { $0.name == "postgres" })
        XCTAssertEqual(postgres.category, .tools)
        XCTAssertFalse(postgres.isLaunchpadVisible)
    }

    func testServiceCategoryOrderingRestoresMissingCategories() {
        let ordered = ServiceCategory.ordered(from: "tools,tools,media")
        XCTAssertEqual(ordered, [.tools, .media, .favorites, .downloads, .network])
    }

    func testDiagnosticRedactionMasksCredentialsAndPairingCodes() {
        let detail = DiagnosticLogStore.redactedDetail(
            "token=abc123, pairingCode=123456, Authorization=Bearer secret-token, url=https://user:password@example.com"
        )
        XCTAssertFalse(detail.contains("abc123"))
        XCTAssertFalse(detail.contains("123456"))
        XCTAssertFalse(detail.contains("secret-token"))
        XCTAssertFalse(detail.contains("user:password"))
        XCTAssertTrue(detail.contains("<redacted>"))
    }

    func testNetworkErrorClassificationUsesStableCategories() {
        XCTAssertEqual(NetworkErrorKind.classify(URLError(.timedOut)), .timeout)
        XCTAssertEqual(NetworkErrorKind.classify(URLError(.notConnectedToInternet)), .unreachable)
        XCTAssertEqual(NetworkErrorKind.classify(URLError(.badURL)), .invalidAddress)
        XCTAssertEqual(NetworkErrorKind.classify(URLError(.userAuthenticationRequired)), .authentication)
        XCTAssertEqual(NetworkErrorKind.classify(DSMClientError.insecureHTTP), .insecureTransport)
        XCTAssertEqual(NetworkErrorKind.classify(AgentClientError.unauthorized), .authentication)
        XCTAssertEqual(NetworkErrorKind.classify(KeychainStoreError.encodingFailed), .storage)
        XCTAssertEqual(NetworkErrorKind.diagnosticMessage(for: DSMClientError.apiFailed(code: 403)), "apiFailure:403")
    }

    func testDiagnosticURLRedactionDropsPathQueryAndCredentials() {
        let url = URL(string: "https://user:password@example.com/private?token=secret")!
        let redacted = DiagnosticLogStore.redactedURL(url)
        XCTAssertFalse(redacted.contains("user"))
        XCTAssertFalse(redacted.contains("password"))
        XCTAssertFalse(redacted.contains("private"))
        XCTAssertFalse(redacted.contains("token"))
        XCTAssertFalse(redacted.contains("secret"))
        XCTAssertTrue(redacted.hasPrefix("https://"))
    }

    func testAgentURLPolicyRejectsQueryAndFragment() {
        XCTAssertThrowsError(
            try AgentClient(
                baseURL: URL(string: "https://example.com?token=secret")!,
                allowsSelfSignedCertificates: false
            )
        ) { error in
            guard case AgentClientError.invalidAddress = error else {
                return XCTFail("Expected invalidAddress, got \(error)")
            }
        }
    }

    func testLocalTaskStateDeduplicatesAndBoundsHistory() {
        let pendingID = UUID()
        let pending = TaskItem(
            id: pendingID,
            title: "Pending",
            subtitle: "",
            symbol: "checkmark",
            isUrgent: false
        )
        let completedTasks = (0...LocalTaskStore.maxHistoryCount).map { index -> TaskItem in
            var task = TaskItem(
                id: UUID(),
                title: "Completed \(index)",
                subtitle: "",
                symbol: "checkmark",
                isUrgent: false
            )
            task.completedAt = Date()
            return task
        }

        let state = LocalTaskStore.normalizedState(
            pending: [pending, pending],
            history: completedTasks
        )
        XCTAssertEqual(state.pending.map(\.id), [pendingID])
        XCTAssertEqual(state.history.count, LocalTaskStore.maxHistoryCount)
        XCTAssertEqual(state.history.map(\.id), completedTasks.prefix(LocalTaskStore.maxHistoryCount).map(\.id))
    }

    func testCloudSyncMergePolicyProtectsNewerLocalChanges() {
        let localDate = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(
            CloudSyncMergePolicy.decision(
                remoteUpdatedAt: Date(timeIntervalSince1970: 1_999),
                localChangedAt: localDate
            ),
            .uploadLocal
        )
        XCTAssertEqual(
            CloudSyncMergePolicy.decision(
                remoteUpdatedAt: Date(timeIntervalSince1970: 2_001),
                localChangedAt: localDate
            ),
            .applyRemote
        )
        XCTAssertEqual(
            CloudSyncMergePolicy.decision(remoteUpdatedAt: nil, localChangedAt: localDate),
            .uploadLocal
        )
    }

    private static func emptyDSMSnapshot() -> DSMDataSnapshot {
        DSMDataSnapshot(
            device: NASDevice(
                id: UUID(),
                name: "DS920+",
                subtitle: "DSM",
                model: nil,
                dsmVersion: nil,
                mode: .dsmOnly,
                cpu: nil,
                memory: nil,
                memoryUsedText: nil,
                memoryTotalText: nil,
                storageUsed: nil,
                storageUsedText: nil,
                storageTotalText: nil,
                storageFreeText: "-",
                uptimeMinutes: nil,
                temperatureText: nil,
                certificate: nil,
                sshStatus: .unavailable
            ),
            services: [],
            containers: [],
            files: [],
            tasks: [],
            videoLibraryItems: [],
            audioLibraryItems: [],
            discoveredDevices: [],
            containerInventoryAvailable: false,
            packageInventoryAvailable: false,
            reverseProxyInventoryAvailable: false,
            agentHealth: nil
        )
    }
}

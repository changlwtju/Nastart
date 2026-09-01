import XCTest
@testable import Nastart

final class NonPlaybackPolicyTests: XCTestCase {
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
}

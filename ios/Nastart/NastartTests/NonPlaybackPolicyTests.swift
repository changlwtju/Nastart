import XCTest
@testable import Nastart

final class NonPlaybackPolicyTests: XCTestCase {
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

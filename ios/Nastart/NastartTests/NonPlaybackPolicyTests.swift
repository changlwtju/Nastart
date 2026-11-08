import XCTest
import Get
@testable import Nastart

final class NonPlaybackPolicyTests: XCTestCase {
    @MainActor
    func testRestoreChecksServiceHealthAfterPublishingSnapshotWithoutWaitingForMonitorTick() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<Void>()
        var operations = fixture.operations()
        var checks = 0
        operations.refreshServiceHealth = { store in
            checks += 1
            XCTAssertTrue(store.folderSnapshotMatchesSource)
            XCTAssertTrue(fixture.connection.isConnected)
            XCTAssertEqual(fixture.savedCredentials.count, 1)
            _ = try! await gate.load()
        }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        XCTAssertEqual(checks, 1)
        gate.finish(.success(()))
        await task.value
        XCTAssertEqual(checks, 1)
        XCTAssertFalse(fixture.store.isRefreshing)
    }

    @MainActor
    func testServiceHealthPublishesFastEndpointBeforeUnrelatedSlowEndpoint() async {
        let slow = RestoreStageGate<ServiceHealthSnapshot>()
        let fastID = UUID(), slowID = UUID()
        let ready = expectation(description: "fast service published while slow service is pending")
        var published: [UUID] = []
        let task = Task {
            await ServiceHealthProbe.check([
                ServiceHealthTarget(id: fastID, url: URL(string: "https://fast.example.test")!),
                ServiceHealthTarget(id: slowID, url: URL(string: "https://slow.example.test")!)
            ], perform: { target in
                if target.id == slowID { return try! await slow.load() }
                return ServiceHealthSnapshot(status: .online, latencyMilliseconds: 1, checkedAt: Date())
            }, onResult: { id, _ in
                published.append(id)
                if id == fastID { ready.fulfill() }
            })
        }
        await fulfillment(of: [ready, slow.entered], timeout: 2)
        XCTAssertEqual(published, [fastID])
        slow.finish(.success(ServiceHealthSnapshot(status: .offline, latencyMilliseconds: 3500, checkedAt: Date())))
        let result = await task.value
        XCTAssertEqual(Set(published), [fastID, slowID])
        XCTAssertEqual(result[fastID]?.status, .online)
        XCTAssertEqual(result[slowID]?.status, .offline)
    }

    @MainActor
    func testCancelledServiceHealthDoesNotPublishLateResult() async {
        let gate = RestoreStageGate<ServiceHealthSnapshot>()
        var published = 0
        let task = Task {
            await ServiceHealthProbe.check([
                ServiceHealthTarget(id: UUID(), url: URL(string: "https://late.example.test")!)
            ], perform: { _ in try! await gate.load() }, onResult: { _, _ in published += 1 })
        }
        await fulfillment(of: [gate.entered], timeout: 2)
        task.cancel()
        gate.finish(.success(ServiceHealthSnapshot(status: .online, latencyMilliseconds: 1, checkedAt: Date())))
        let result = await task.value
        XCTAssertEqual(published, 0)
        XCTAssertTrue(result.isEmpty)
    }

    func testFixedDSMAddressCredentialRoundTripAndLegacyDefault() throws {
        let domain = URL(string: "https://configured.example.test:5443/dsm")!
        let endpoints = DSMConnectionEndpoints(primaryDomain: domain,
            lanAddress: URL(string: "http://192.168.42.10:5000")!)
        let fixed = StoredNASCredential(baseURLString: domain.absoluteString,
            account: "fixture-account", password: "fixture-password", useAgent: false,
            endpoints: endpoints, lastKnownRoute: .lan, usesOnlyConfiguredAddress: true)
        let data = try JSONEncoder().encode(fixed)
        let restored = try JSONDecoder().decode(StoredNASCredential.self, from: data)
        XCTAssertTrue(restored.usesOnlyConfiguredAddress)
        XCTAssertEqual(restored.baseURLString, domain.absoluteString)
        XCTAssertEqual(restored.endpoints, endpoints)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "usesOnlyConfiguredAddress")
        let old = try JSONDecoder().decode(StoredNASCredential.self,
            from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertFalse(old.usesOnlyConfiguredAddress,
                       "Existing devices must retain automatic routing until the user enables the option")
        XCTAssertEqual(old.baseURLString, domain.absoluteString)
        XCTAssertEqual(old.endpoints, endpoints)
    }

    @MainActor
    func testFixedDSMAddressRestoresOnlyDomainAndPersistsAcrossDiscoveredLANAndRestart() async throws {
        let transport = EndpointPreparationFixture()
        let f = RestoreOwnershipFixture()
        var saved = StoredNASCredential(baseURLString: transport.external.absoluteString,
            account: "fixture-account", password: "fixture-password", useAgent: false,
            endpoints: transport.endpoints, lastKnownRoute: .lan, usesOnlyConfiguredAddress: true)
        var operations = f.operations()
        operations.loadCredential = { saved }
        operations.login = { credential, endpoints in
            f.loginCalls += 1
            return try await DSMClient.login(endpoints: endpoints,
                account: credential.account, password: credential.password,
                preferredRoute: credential.lastKnownRoute, prepareConfiguredEndpoints: true,
                urlSession: transport.session)
        }
        operations.discoverLAN = { _ in transport.lan }
        for _ in 0..<2 {
            await f.store.restoreDSMConnection(using: f.connection, operations: operations)
            XCTAssertEqual(f.connection.dsmSession?.baseURL, transport.external)
            XCTAssertEqual(f.connection.dsmSession?.actualRoute, .external)
            let persisted = try XCTUnwrap(f.savedCredentials.last)
            XCTAssertTrue(persisted.usesOnlyConfiguredAddress)
            XCTAssertEqual(persisted.baseURLString, transport.external.absoluteString)
            XCTAssertEqual(persisted.endpoints.lanAddress, transport.lan,
                           "Optional media discovery must not change DSM authentication policy")
            saved = try JSONDecoder().decode(StoredNASCredential.self,
                from: JSONEncoder().encode(persisted))
        }
        XCTAssertEqual(f.loginCalls, 2)
        XCTAssertEqual(f.fallbackCalls, 0)
        XCTAssertEqual(transport.getHosts, [transport.external.host!, transport.external.host!])
        XCTAssertEqual(transport.postHosts, [transport.external.host!, transport.external.host!])
        XCTAssertTrue(transport.credentialFreeMetadata)
        XCTAssertTrue(transport.credentialsOnlyInPOSTBody)
    }

    @MainActor
    func testFixedDSMAddressFailureDoesNotDiscoverOrAuthenticateAnotherAddress() async {
        let f = RestoreOwnershipFixture()
        let domain = URL(string: "https://configured.example.test:5443/dsm")!
        let lan = URL(string: "http://192.168.42.10:5000")!
        let credential = StoredNASCredential(baseURLString: domain.absoluteString,
            account: "fixture-account", password: "fixture-password", useAgent: false,
            endpoints: .init(primaryDomain: domain, lanAddress: lan),
            lastKnownRoute: .lan, usesOnlyConfiguredAddress: true)
        var operations = f.operations()
        operations.loadCredential = { credential }
        operations.login = { _, endpoints in
            f.loginCalls += 1
            XCTAssertEqual(endpoints.candidates.map(\.url), [domain])
            throw URLError(.cannotConnectToHost)
        }
        operations.discoverFallback = { f.fallbackCalls += 1; return [lan] }
        await f.store.restoreDSMConnection(using: f.connection, operations: operations)
        XCTAssertEqual(f.loginCalls, 1)
        XCTAssertEqual(f.fallbackCalls, 0)
        XCTAssertEqual(f.fileLoginCalls, 0)
        XCTAssertEqual(f.store.connectionRecoveryState, .failed)
        XCTAssertNil(f.connection.dsmSession)
        XCTAssertTrue(f.savedCredentials.isEmpty)
    }

    func testAutomaticRestoreSelectsResponsiveConfiguredLANBeforeCredentials() async throws {
        let f = EndpointPreparationFixture(holdMetadata: true)
        f.metadataStopped.expectedFulfillmentCount = 1
        let task = Task { try await f.login() }
        await fulfillment(of: [f.metadataStarted], timeout: 2)
        f.finishMetadata(host: f.lan.host!)
        let result = try await task.value
        await fulfillment(of: [f.metadataStopped], timeout: 2)
        XCTAssertEqual(result.session.baseURL, f.lan)
        XCTAssertEqual(result.session.actualRoute, .lan)
        XCTAssertEqual(result.session.endpoints, f.endpoints)
        XCTAssertEqual(f.getHosts.sorted(), [f.external.host!, f.lan.host!].sorted())
        XCTAssertEqual(f.postHosts, [f.lan.host!])
        XCTAssertEqual(f.cancelledHosts, [f.external.host!])
        XCTAssertTrue(f.credentialFreeMetadata)
        XCTAssertTrue(f.credentialsOnlyInPOSTBody)
    }

    func testCancellingAutomaticRestoreCancelsAllProbesWithoutCredentialPOST() async throws {
        let f = EndpointPreparationFixture(holdMetadata: true)
        let task = Task { try await f.login() }
        await fulfillment(of: [f.metadataStarted], timeout: 2)
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled restore must not authenticate") }
        catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
        await fulfillment(of: [f.metadataStopped], timeout: 2)
        XCTAssertEqual(f.cancelledHosts.sorted(), [f.external.host!, f.lan.host!].sorted())
        XCTAssertTrue(f.postHosts.isEmpty)
    }

    func testSelectedEndpointAmbiguousPOSTNeverReplaysOnOtherConfiguredAddress() async throws {
        for outcome in [EndpointPreparationFixture.PostOutcome.timeout, .httpError, .missingSID, .rejected] {
            let f = EndpointPreparationFixture(holdMetadata: true, postOutcome: outcome)
            let task = Task { try await f.login() }
            await fulfillment(of: [f.metadataStarted], timeout: 2)
            f.finishMetadata(host: f.lan.host!)
            do { _ = try await task.value; XCTFail("Expected the controlled authentication failure") }
            catch { XCTAssertFalse(DSMClient.shouldRetryLogin(on: error)) }
            XCTAssertEqual(f.postHosts, [f.lan.host!])
            XCTAssertEqual(f.getHosts.count, 2)
        }
    }

    func testPreparedEndpointStillAllowsExplicitVersionCompatibilityOnSameHost() async throws {
        let f = EndpointPreparationFixture(holdMetadata: true, postOutcome: .unsupportedThenSuccess)
        let task = Task { try await f.login() }
        await fulfillment(of: [f.metadataStarted], timeout: 2)
        f.finishMetadata(host: f.lan.host!)
        let result = try await task.value
        XCTAssertEqual(result.session.sid, "prepared-session")
        XCTAssertEqual(f.postHosts, [f.lan.host!, f.lan.host!])
        XCTAssertEqual(f.postVersions, [6, 5])
        XCTAssertEqual(f.getHosts.count, 2)
    }

    func testUnavailableMetadataKeepsOriginalRouteAndDoesNotQueryAgain() async throws {
        let f = EndpointPreparationFixture(metadataBody: #"{"success":false,"error":{"code":102}}"#)
        let result = try await f.login()
        XCTAssertEqual(result.session.baseURL, f.external)
        XCTAssertEqual(f.getHosts.sorted(), [f.external.host!, f.lan.host!].sorted())
        XCTAssertEqual(f.postHosts, [f.external.host!])
        XCTAssertEqual(f.postVersions, [7])
    }

    func testUnusableOrCrossOriginMetadataCannotWinEndpointSelection() async throws {
        for body in [#"{"success":true,"data":{}}"#,
                     #"{"success":true,"data":{"SYNO.API.Auth":{"path":"auth.cgi","maxVersion":1e100}}}"#,
                     EndpointPreparationFixture.validMetadata] {
            let f = EndpointPreparationFixture(holdMetadata: true)
            let task = Task { try await f.login() }
            await fulfillment(of: [f.metadataStarted], timeout: 2)
            f.finishMetadata(host: f.external.host!, body: body,
                             responseURL: body == EndpointPreparationFixture.validMetadata
                                ? URL(string: "https://unconfigured.example.test/webapi/query.cgi")! : nil)
            f.finishMetadata(host: f.lan.host!)
            let result = try await task.value
            XCTAssertEqual(result.session.baseURL, f.lan)
            XCTAssertEqual(f.postHosts, [f.lan.host!])
            XCTAssertFalse(f.getHosts.contains("unconfigured.example.test"))
        }
    }

    func testManualLoginAndSingleEndpointRestoreKeepTheirOriginalQueryOrder() async throws {
        let manual = EndpointPreparationFixture()
        let first = try await manual.login(prepare: false)
        XCTAssertEqual(first.session.baseURL, manual.external)
        XCTAssertEqual(manual.getHosts, [manual.external.host!])
        XCTAssertEqual(manual.postHosts, [manual.external.host!])
        let single = EndpointPreparationFixture()
        let second = try await single.login(endpoints: DSMConnectionEndpoints(lanAddress: single.lan))
        XCTAssertEqual(second.session.baseURL, single.lan)
        XCTAssertEqual(single.getHosts, [single.lan.host!])
        XCTAssertEqual(single.postHosts, [single.lan.host!])
    }

    func testEndpointPreparationFiltersInvalidAndDuplicateAddressesBeforeRequests() async throws {
        let duplicate = EndpointPreparationFixture()
        _ = try await duplicate.login(endpoints: DSMConnectionEndpoints(
            primaryDomain: duplicate.external, lanAddress: duplicate.lan, publicAddress: duplicate.external))
        XCTAssertEqual(Set(duplicate.getHosts).count, duplicate.getHosts.count)
        for invalid in ["http://unsafe.example.test:5000", "https://user:password@unsafe.example.test",
                        "https://unsafe.example.test/?sid=secret", "ftp://unsafe.example.test"] {
            let f = EndpointPreparationFixture()
            _ = try await f.login(endpoints: DSMConnectionEndpoints(primaryDomain: URL(string: invalid), lanAddress: f.lan))
            XCTAssertEqual(f.getHosts, [f.lan.host!])
            XCTAssertEqual(f.postHosts, [f.lan.host!])
        }
    }

    @MainActor
    func testResumeCheckpointTracksImmediateASSBackToPGSAndIsolatesOtherKeys() throws {
        let suite = "ResumeCheckpoint." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "other-account", position: 900, duration: 7200, audioTrackID: 2,
                   subtitleTrackID: 9, subtitlesDisabled: false)
        let other = store.entry(for: "other-account")
        let sidecar = URL(string: "https://private.example/subtitle/5.srt?token=private-token")!
        let request = MediaPlaybackRequest(url: URL(string: "https://private.example/video?sid=private-sid")!,
            title: "private-title", source: .jellyfin, externalSubtitleURL: sidecar,
            sourceSubtitleTracks: [.init(id: 5, name: "ASS", externalURL: sidecar), .init(id: 7, name: "PGS")],
            selectedSourceSubtitleTrackID: 5, localResumeKey: "private-resume-key")
        let controls = GreenfieldPlaybackControls()
        controls.beginSession()
        controls.isReady = true
        controls.durationSeconds = 7200
        controls.updateClock(61)
        controls.originalStreamIndexesKnown = true
        controls.selectedAudioTrackID = 1
        controls.externalSubtitleAction = { _ in }
        controls.subtitleAction = { controls.pipExternalSubtitle.setURL(nil); controls.selectedSubtitleTrackID = $0 }
        controls.selectSourceSubtitle(5, externalURL: sidecar)
        let ass = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
        XCTAssertEqual(ass.fields["subtitleTrackID"], "5")
        XCTAssertEqual(ass.fields["memoryReadback"], "match")
        controls.selectSourceSubtitle(7, externalURL: nil)
        // Same source selection update used by the direct-play callback.
        controls.sourceRuntimeStreamIndexes = (1, 7)
        controls.sourceRuntimeTracks = (nil, 1, false)
        let pgs = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
        XCTAssertTrue(pgs.enteredStore)
        XCTAssertEqual(pgs.fields["subtitleTrackID"], "7")
        XCTAssertEqual(pgs.fields["externalSubtitleActive"], "false")
        XCTAssertEqual(pgs.fields["memoryReadback"], "match")
        XCTAssertEqual(pgs.fields["durabilityEvidence"], "sameProcessOnly")
        XCTAssertEqual(store.entry(for: "private-resume-key")?.subtitleTrackID, 7)
        XCTAssertEqual(store.entry(for: "other-account"), other)
        for secret in ["private.example", "private-token", "private-sid", "private-title", "private-resume-key", "http"] {
            XCTAssertFalse(ass.fields.description.contains(secret), secret)
            XCTAssertFalse(pgs.fields.description.contains(secret), secret)
        }
    }

    @MainActor
    func testResumeCheckpointDoesNotOverwriteDuringStartupOrPendingSeek() throws {
        let suite = "ResumeCheckpointGuard." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "fixture", position: 6200, duration: 14000, audioTrackID: 3, subtitleTrackID: 8, subtitlesDisabled: false)
        let prior = store.entry(for: "fixture")
        let request = MediaPlaybackRequest(url: URL(string: "https://fixture.example/video")!, title: "fixture",
                                          source: .dsmFile, localResumeKey: "fixture")
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialPosition: 6200)
        controls.isReady = true
        controls.isSeekable = true
        controls.durationSeconds = 14000
        controls.seekPlayback = { _ in }
        let startup = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
        XCTAssertFalse(startup.enteredStore)
        XCTAssertEqual(startup.fields["resumeTimelineConfirmed"], "false")
        XCTAssertEqual(store.entry(for: "fixture"), prior)
        controls.updateClock(6200)
        controls.seekSeconds(1000)
        let pending = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
        XCTAssertEqual(pending.fields["pendingSeek"], "true")
        XCTAssertFalse(pending.enteredStore)
        XCTAssertEqual(store.entry(for: "fixture"), prior)
        controls.seekDidComplete(true)
        controls.updateClock(1000)
        let complete = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
        XCTAssertTrue(complete.enteredStore)
        XCTAssertEqual(complete.fields["memoryReadback"], "match")
        XCTAssertEqual(store.entry(for: "fixture")?.positionSeconds, 1000)
    }

    @MainActor
    func testResumeCheckpointCompletedSeekStillWaitsForPausedPreview() throws {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession()
        controls.isReady = true
        controls.isSeekable = true
        controls.isPlaying = false
        controls.expectsPausedSeekPreview = true
        controls.durationSeconds = 1000
        controls.seekPlayback = { _ in }
        controls.seekSeconds(200)
        controls.seekDidComplete(true)
        XCTAssertEqual(controls.resumePersistenceDiagnostics["pendingSeekPosition"], "false")
        XCTAssertEqual(controls.resumePersistenceDiagnostics["waitingForPausedPreview"], "true")
        XCTAssertFalse(controls.canPersistResumeProgress)
        controls.acceptPausedSeekPreview(200)
        XCTAssertTrue(controls.canPersistResumeProgress)
    }

    @MainActor
    func testResumeCheckpointInvalidTimelineIsNotReportedAsSubmitted() throws {
        let suite = "ResumeCheckpointInvalid." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        store.save(key: "fixture", position: 20, duration: 1000, audioTrackID: 1, subtitleTrackID: 7, subtitlesDisabled: false)
        let prior = store.entry(for: "fixture")
        let request = MediaPlaybackRequest(url: URL(string: "https://fixture.example/video")!, title: "fixture",
                                          source: .jellyfin, localResumeKey: "fixture")
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(); controls.isReady = true
        for duration in [0, -1, Double.nan, Double.infinity] {
            controls.durationSeconds = duration
            let result = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
            XCTAssertTrue(result.enteredStore, "Retain the player's existing guard/cadence behavior")
            XCTAssertEqual(result.fields["saveOutcome"], "invalidTimeline")
            XCTAssertEqual(result.fields["memoryReadback"], "notObserved")
            XCTAssertEqual(store.entry(for: "fixture"), prior)
        }
    }

    @MainActor
    func testResumeCheckpointUnknownSidecarDoesNotBorrowStaleSourceID() throws {
        let suite = "ResumeCheckpointSidecar." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let sidecar = URL(string: "https://fixture.example/sidecar.srt")!
        let request = MediaPlaybackRequest(url: URL(string: "https://fixture.example/video")!, title: "fixture",
            source: .jellyfin, sourceSubtitleTracks: [.init(id: 5, name: "one", externalURL: sidecar), .init(id: 6, name: "two", externalURL: sidecar)],
            selectedSourceSubtitleTrackID: 7, localResumeKey: "fixture")
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(initialExternalSubtitleURL: sidecar)
        controls.isReady = true; controls.durationSeconds = 1000
        controls.sourceRuntimeStreamIndexes = (1, 7)
        let result = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, store: store, observeMemory: true)
        XCTAssertEqual(result.fields["subtitleTrackID"], "none")
        XCTAssertNil(store.entry(for: "fixture")?.subtitleTrackID)
        XCTAssertEqual(result.fields["memoryReadback"], "match")
    }

    func testResumeStoreReadbackCanDistinguishRejectedMemoryWriteWithoutDiskClaim() throws {
        let suite = "ResumeCheckpointDropped." + UUID().uuidString
        let defaults = try XCTUnwrap(DroppingResumeDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalPlaybackResumeStore(defaults: defaults)
        let result = store.save(key: "fixture", position: 20, duration: 1000,
                               audioTrackID: 1, subtitleTrackID: 7, subtitlesDisabled: false, observeMemory: true)
        XCTAssertEqual(result.status, .submitted, "UserDefaults.set has no write acknowledgement")
        XCTAssertEqual(result.memoryReadbackMatches, false)
        XCTAssertNil(store.entry(for: "fixture"))
        let unobserved = store.save(key: "fixture", position: 20, duration: 1000,
                                   audioTrackID: 1, subtitleTrackID: 7, subtitlesDisabled: false)
        XCTAssertNil(unobserved.memoryReadbackMatches)
    }

    @MainActor
    func testResumeCheckpointMissingIdentityAndDirectURLNeverSubmit() throws {
        let controls = GreenfieldPlaybackControls()
        controls.beginSession(); controls.isReady = true; controls.durationSeconds = 1000
        for (source, key, reason) in [(MediaPlaybackSource.directURL, Optional("private-key"), "directURL"),
                                     (.jellyfin, nil, "missingResumeKey")] {
            let request = MediaPlaybackRequest(url: URL(string: "https://fixture.example/video")!, title: "fixture",
                                              source: source, localResumeKey: key)
            let result = PlaybackLocalResumeCheckpoint.save(controls: controls, request: request, observeMemory: true)
            XCTAssertFalse(result.enteredStore)
            XCTAssertEqual(result.fields["skipReason"], reason)
            XCTAssertEqual(result.fields["memoryReadback"], "notObserved")
        }
    }

    func testAVNSErrorMissingChainDoesNotInventUnderlyingFailure() {
        var calls = 0
        let fields = PlaybackAVFailureDiagnostics.errorChainFields(nil) { _ in calls += 1; return [:] }
        XCTAssertEqual(fields["candidateNSErrorCount"], "0")
        XCTAssertEqual(fields["candidateNSErrorEnd"], "missing")
        XCTAssertEqual(calls, 0)
    }

    func testAVNSErrorUnderlyingFailingURLBindsWithoutExportingUserInfo() {
        let registry = PlaybackProxyRequestDiagnostics()
        let local = URL(string: "http://127.0.0.1:1234/media/fixture/child/0.m3u8")!
        let upstream = URL(string: "https://private.example/media.m3u8?api_key=fixture-secret")!
        let transfer = UUID()
        registry.record(localURL: local, upstreamURL: upstream, transferID: transfer, childID: "0.m3u8")
        let underlying = NSError(domain: NSURLErrorDomain, code: -1008, userInfo: [
            NSURLErrorFailingURLErrorKey: upstream,
            NSLocalizedDescriptionKey: "private-description", "password": "private-password"
        ])
        let root = NSError(domain: "private-domain", code: -1, userInfo: [NSUnderlyingErrorKey: underlying])
        let fields = PlaybackAVFailureDiagnostics.errorChainFields(root, resource: registry.fields)
        XCTAssertEqual(fields["candidateNSErrorCount"], "2")
        XCTAssertEqual(fields["candidateNSError0_domain"], "other")
        XCTAssertEqual(fields["candidateNSError0_binding"], "missingURI")
        XCTAssertEqual(fields["candidateNSError1_code"], "-1008")
        XCTAssertEqual(fields["candidateNSError1_hlsRole"], "mediaPlaylist")
        XCTAssertEqual(fields["candidateNSError1_transferID"], transfer.uuidString)
        for secret in ["private.example", "fixture-secret", "private-description", "private-password", "private-domain", "http"] {
            XCTAssertFalse(fields.description.contains(secret), secret)
        }
        let stringError = NSError(domain: NSURLErrorDomain, code: -1008,
            userInfo: [NSURLErrorFailingURLStringErrorKey: local.absoluteString])
        XCTAssertEqual(PlaybackAVFailureDiagnostics.errorChainFields(stringError,
            resource: registry.fields)["candidateNSError0_transferID"], transfer.uuidString)
    }

    func testAVNSErrorChainIsBoundedEvenWithMoreUnderlyingErrors() {
        var error = NSError(domain: NSURLErrorDomain, code: -8)
        for n in 1...7 { error = NSError(domain: NSURLErrorDomain, code: n, userInfo: [NSUnderlyingErrorKey: error]) }
        let fields = PlaybackAVFailureDiagnostics.errorChainFields(error) { _ in ["binding": "missingURI"] }
        XCTAssertEqual(fields["candidateNSErrorCount"], "4")
        XCTAssertEqual(fields["candidateNSErrorEnd"], "limit")
        XCTAssertNil(fields["candidateNSError4_code"])
    }

    func testProxyDiagnosticTraceAcceptsOnlyUUIDOrExistingShortHexTrace() {
        let uuid = UUID().uuidString
        XCTAssertEqual(PlaybackProxyRequestDiagnostics.safeTrace(uuid.lowercased()), uuid)
        XCTAssertEqual(PlaybackProxyRequestDiagnostics.safeTrace("17468426"), "17468426")
        XCTAssertEqual(PlaybackProxyRequestDiagnostics.safeTrace("cbB40e06"), "CBB40E06")
        for value in [nil, "", "private-user", "token=secret", "ABCDEFGH", "123456789"] {
            XCTAssertEqual(PlaybackProxyRequestDiagnostics.safeTrace(value), "unknown")
        }
    }

    func testAVFailureEmptyLogIsExplicitWithoutInventingAResource() {
        var lookups = 0
        let fields = PlaybackAVFailureDiagnostics.fields(events: [], candidateCurrent: false) { _ in
            lookups += 1; return [:]
        }
        XCTAssertEqual(fields["candidateErrorLogEvents"], "0")
        XCTAssertEqual(fields["candidateErrorLogRecorded"], "0")
        XCTAssertEqual(fields["candidateCurrentAtFailure"], "false")
        XCTAssertEqual(lookups, 0)
    }

    func testAVFailureOnlyExportsFourTypedEventsAndNoCredentialURI() {
        let registry = PlaybackProxyRequestDiagnostics()
        let local = URL(string: "http://127.0.0.1:1234/media/fixture/child/1.m3u8")!
        let upstream = URL(string: "https://fixture-user:fixture-password@private.example/private-name.m3u8?api_key=fixture-secret")!
        let transfer = UUID()
        registry.record(localURL: local, upstreamURL: upstream, transferID: transfer, childID: "1.m3u8")
        let events = (0..<6).map { index in
            PlaybackAVFailureDiagnostics.ErrorEvent(domain: index == 5 ? "private-domain-secret" : NSURLErrorDomain,
                status: -1000 - index, date: Date(timeIntervalSince1970: Double(index)),
                uri: index == 5 ? upstream.absoluteString : local.absoluteString)
        }
        let fields = PlaybackAVFailureDiagnostics.fields(events: events, candidateCurrent: true,
            resource: registry.fields)
        XCTAssertEqual(fields["candidateErrorLogEvents"], "6")
        XCTAssertEqual(fields["candidateErrorLogRecorded"], "4")
        XCTAssertEqual(fields["candidateError0_status"], "-1002")
        XCTAssertEqual(fields["candidateError3_domain"], "other")
        XCTAssertEqual(fields["candidateError3_transferID"], transfer.uuidString)
        XCTAssertEqual(fields["candidateError3_hlsRole"], "mediaPlaylist")
        let text = fields.description
        for secret in ["fixture-user", "fixture-password", "fixture-secret", "private.example", "private-name", "private-domain-secret", "/media/"] {
            XCTAssertFalse(text.contains(secret), secret)
        }
    }

    func testProxyDiagnosticBindingNeverFallsAcrossRoutesOrChoosesLatestRetry() {
        let old = PlaybackProxyRequestDiagnostics(), next = PlaybackProxyRequestDiagnostics()
        let first = URL(string: "http://127.0.0.1:1234/media/old/master.m3u8")!
        let second = URL(string: "http://127.0.0.1:1234/media/new/master.m3u8")!
        let upstream = URL(string: "https://example.test/master.m3u8?token=fixture")!
        old.record(localURL: first, upstreamURL: upstream, transferID: UUID(), childID: nil)
        next.record(localURL: second, upstreamURL: upstream, transferID: UUID(), childID: nil)
        XCTAssertEqual(next.fields(uri: first.absoluteString)["binding"], "unmatchedURI")
        XCTAssertNotEqual(old.routeID, next.routeID)
        old.record(localURL: first, upstreamURL: upstream, transferID: UUID(), childID: nil)
        let retry = old.fields(uri: first.absoluteString)
        XCTAssertEqual(retry["matchingTransfers"], "2")
        XCTAssertEqual(retry["binding"], "ambiguousOrTruncated")
        XCTAssertEqual(retry["transferID"], "unknown")
    }

    func testProxyDiagnosticHistoryIsBoundedAndDoesNotClaimFalseUniqueness() {
        let registry = PlaybackProxyRequestDiagnostics()
        for i in 0..<65 {
            let url = URL(string: "https://example.test/\(i).ts")!
            registry.record(localURL: url, upstreamURL: url, transferID: UUID(), childID: "\(i).ts")
        }
        let fields = registry.fields(uri: "https://example.test/64.ts")
        XCTAssertEqual(fields["historyTruncated"], "true")
        XCTAssertEqual(fields["binding"], "ambiguousOrTruncated")
        XCTAssertEqual(fields["transferID"], "unknown")
        XCTAssertEqual(registry.fields(uri: "https://example.test/0.ts")["matchingTransfers"], "0")
    }

    func testProxyDiagnosticMissingOrUnmatchedURIAndUnsafeChildStayUnknown() {
        let registry = PlaybackProxyRequestDiagnostics()
        XCTAssertEqual(registry.fields(uri: nil)["binding"], "missingURI")
        XCTAssertEqual(registry.fields(uri: "relative.m3u8")["binding"], "missingURI")
        let url = URL(string: "https://example.test/master.m3u8")!
        registry.record(localURL: url, upstreamURL: url, transferID: UUID(), childID: "private/path?api_key=secret")
        XCTAssertEqual(registry.fields(uri: url.absoluteString)["playlistChildID"], "unknown")
        XCTAssertEqual(registry.fields(uri: "https://other.example/master.m3u8")["binding"], "unmatchedURI")
    }

    func testRevokedOrWrongPortProxyDiagnosticCannotAttachToActiveRoute() async throws {
        let proxy = AuthenticatedMediaStreamProxy.shared
        let root = try await proxy.register(upstreamURL: URL(string: "https://example.test/master.m3u8")!,
            filename: "master.m3u8", allowsSelfSignedCertificates: false)
        defer { proxy.unregister(root) }
        XCTAssertEqual(proxy.diagnosticResource(nil, for: root)["binding"], "missingURI")
        var wrong = URLComponents(url: root, resolvingAgainstBaseURL: false)!
        wrong.port = (wrong.port ?? 0) + 1
        XCTAssertEqual(proxy.diagnosticResource(root.absoluteString, for: wrong.url!)["binding"], "routeInactive")
        proxy.unregister(root)
        // The serial lookup follows revocation; no global history fallback.
        XCTAssertEqual(proxy.diagnosticResource(root.absoluteString, for: root)["binding"], "routeInactive")
    }

    func testPartialPlaylistDoesNotBecomeClientDeliveredBytes() {
        var evidence = PlaybackPlaylistDeliveryDiagnostics()
        let partial = evidence.fields(upstreamReceived: 170_692)
        XCTAssertEqual(partial["playlistUpstreamBodyReceivedBytes"], "170692")
        XCTAssertEqual(partial["playlistClientHeaderSendCompleted"], "false")
        XCTAssertEqual(partial["playlistClientBodySendCompletedBytes"], "0")
        evidence.headerCompleted()
        XCTAssertEqual(evidence.fields(upstreamReceived: 1_527_158)["playlistClientBodySendCompletedBytes"], "0")
        // Rewritten bytes need not equal upstream bytes. Only a successful
        // body completion advances the downstream observation.
        evidence.bodyCompleted(bytes: 1_600_000)
        XCTAssertEqual(evidence.fields(upstreamReceived: 1_527_158)["playlistClientBodySendCompletedBytes"], "1600000")
    }

    func testCredentialPOSTDeadlineCancelsUnderlyingTaskWithoutReplay() async throws {
        let entered = expectation(description: "credential POST entered")
        let stopped = expectation(description: "underlying POST cancelled")
        let lock = NSLock()
        var requests = 0
        StalledCredentialProtocol.onStart = { lock.lock(); requests += 1; lock.unlock(); entered.fulfill() }
        StalledCredentialProtocol.onStop = { stopped.fulfill() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StalledCredentialProtocol.self]
        let session = URLSession(configuration: configuration)
        defer {
            session.invalidateAndCancel()
            StalledCredentialProtocol.onStart = nil
            StalledCredentialProtocol.onStop = nil
        }
        let client = DSMClient(baseURL: URL(string: "https://deadline.example.test")!, urlSession: session)
        var request = URLRequest(url: URL(string: "https://deadline.example.test/webapi/entry.cgi")!)
        request.httpMethod = "POST"
        request.httpBody = Data("fixture=credential".utf8)
        request.timeoutInterval = 60
        let start = Date()
        do {
            _ = try await client.dataWithAbsoluteTimeout(for: request, timeout: 0.15)
            XCTFail("An indefinitely stalled POST must end at the wall deadline")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .timedOut)
        }
        await fulfillment(of: [entered, stopped], timeout: 2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 2)
        lock.lock(); let count = requests; lock.unlock()
        XCTAssertEqual(count, 1, "Credential POST must not be silently replayed")
    }

    func testRefusedLoginCodesBecomeSpecificErrorsWithoutRetry() {
        for code in [400, 401, 402, 407, 408, 409, 410, 411] {
            guard case DSMClientError.loginRejected(code) = DSMClientError.rejectedLoginError(from: DSMClientError.apiFailed(code: code)) else {
                return XCTFail("Code \(code) must be a refused login")
            }
            XCTAssertFalse(DSMClient.shouldRetryLogin(on: DSMClientError.loginRejected(code: code)))
            XCTAssertEqual(NetworkErrorKind.classify(DSMClientError.loginRejected(code: code)), .authentication)
        }
        // 2FA prompts and session errors keep their existing handling.
        for code in [403, 404, 406, 119] {
            guard case DSMClientError.apiFailed(code) = DSMClientError.rejectedLoginError(from: DSMClientError.apiFailed(code: code)) else {
                return XCTFail("Code \(code) must stay an API failure")
            }
        }
        XCTAssertTrue(DSMClientError.loginRejected(code: 407).allowsRetryWithSameCredential)
        XCTAssertFalse(DSMClientError.loginRejected(code: 400).allowsRetryWithSameCredential)
    }

    func testAutomaticLANTrustDoesNotBecomeTheSavedSSLChoice() {
        XCTAssertFalse(DSMCertificateTrustPolicy.initialToggle(savedTrust: true, savedAddress: "https://192.168.1.64:5001"))
        XCTAssertTrue(DSMCertificateTrustPolicy.initialToggle(savedTrust: true, savedAddress: "https://nas.example.com:5001"))
        XCTAssertFalse(DSMCertificateTrustPolicy.initialToggle(savedTrust: false, savedAddress: "https://nas.example.com:5001"))
        XCTAssertFalse(DSMCertificateTrustPolicy.initialToggle(savedTrust: true, savedAddress: ""))
    }

    func testFileBrowserTreatsOnlyBookkeepingNamesAsSystemItems() {
        for name in [".fseventsd", ".Spotlight-V100", "#recycle", "@eaDir"] {
            XCTAssertTrue(FileBrowserSystemItems.isSystemItem(named: name))
        }
        for name in ["video", "碟中谍3", "a.b", "movie#1.mkv"] {
            XCTAssertFalse(FileBrowserSystemItems.isSystemItem(named: name))
        }
    }

    func testAmbiguousAuthenticationOutcomeCannotTryAnotherEndpoint() {
        for code: URLError.Code in [.timedOut, .networkConnectionLost, .cancelled] {
            XCTAssertFalse(DSMClient.shouldRetryLogin(on: URLError(code)))
        }
        XCTAssertFalse(DSMClient.shouldRetryLogin(on: DSMClientError.apiFailed(code: 400)))
        XCTAssertFalse(DSMClient.shouldRetryLogin(on: DSMClientError.invalidResponse))
        XCTAssertFalse(DSMClient.shouldRetryLogin(on: DSMClientError.missingSession))
        XCTAssertTrue(DSMClient.shouldRetryLogin(on: URLError(.cannotConnectToHost)))
        XCTAssertTrue(DSMClient.shouldRetryLogin(on: URLError(.cannotFindHost)))
    }

    func testSuccessfulAuthenticationWithoutUsableSIDDoesNotReplayCredentials() async throws {
        for body in [#"{"success":true,"data":{}}"#,
                     #"{"success":true,"data":{"sid":""}}"#,
                     #"{"success":true,"data":{"sid":"  \n "}}"#] {
            let fixture = AuthenticationAPIFixture(loginResponses: [body])
            let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
            do {
                _ = try await client.login(account: "fixture-account", password: "fixture-password")
                XCTFail("A successful envelope must contain a usable SID")
            } catch DSMClientError.missingSession {
                // Preserve the uncertain server outcome rather than trying another version.
            }
            XCTAssertEqual(fixture.loginAttempts, 1)
        }
    }

    func testExplicitUnsupportedAuthenticationVersionCanStillUseCompatibleVersion() async throws {
        let fixture = AuthenticationAPIFixture(loginResponses: [
            #"{"success":false,"error":{"code":104}}"#,
            #"{"success":true,"data":{"sid":"compatible-session"}}"#
        ])
        let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let session = try await client.login(account: "fixture-account", password: "fixture-password")
        XCTAssertEqual(session.sid, "compatible-session")
        XCTAssertEqual(fixture.loginAttempts, 2)
    }

    @MainActor
    func testRefusedLoginIsExplainedAndNotRepeatedOnForeground() async {
        let fixture = AuthenticationAPIFixture(loginResponses: [#"{"success":false,"error":{"code":407}}"#])
        let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let f = RestoreOwnershipFixture()
        var operations = f.operations()
        operations.login = { _, _ in
            f.loginCalls += 1
            let session = try await client.login(account: "fixture-account", password: "fixture-password")
            return DSMLoginResult(client: client, session: session)
        }
        await f.store.restoreDSMConnection(using: f.connection, operations: operations)
        guard case .loginRejected(407)? = f.store.connectionRecoveryRejection else {
            return XCTFail("DSM's refusal must reach the recovery card")
        }
        XCTAssertEqual(f.store.connectionRecoveryState, .failed)
        XCTAssertEqual(f.fallbackCalls, 0)
        await f.store.refreshForForeground(using: f.connection, operations: operations)
        XCTAssertEqual(f.loginCalls, 1, "Returning to the foreground must not send another refused login")
    }

    @MainActor
    func testHTTPErrorAfterCredentialPOSTDoesNotCauseRestoreFallback() async {
        let fixture = AuthenticationAPIFixture(loginHTTPStatus: 502)
        let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let f = RestoreOwnershipFixture()
        var operations = f.operations()
        operations.login = { _, _ in
            f.loginCalls += 1
            let session = try await client.login(account: "fixture-account", password: "fixture-password")
            return DSMLoginResult(client: client, session: session)
        }
        await f.store.restoreDSMConnection(using: f.connection, operations: operations)
        XCTAssertEqual(fixture.loginAttempts, 1)
        XCTAssertEqual(f.loginCalls, 1)
        XCTAssertEqual(f.fallbackCalls, 0)
        XCTAssertEqual(f.store.connectionRecoveryState, .failed)
        XCTAssertNil(f.connection.dsmSession)
    }

    @MainActor
    func testAmbiguousResponseRestoreDoesNotScanLANOrReauthenticate() async {
        for error in [DSMClientError.invalidResponse, .missingSession] {
            let f = RestoreOwnershipFixture()
            var operations = f.operations()
            operations.login = { _, _ in f.loginCalls += 1; throw error }
            await f.store.restoreDSMConnection(using: f.connection, operations: operations)
            XCTAssertEqual(f.loginCalls, 1)
            XCTAssertEqual(f.fallbackCalls, 0)
            XCTAssertEqual(f.store.connectionRecoveryState, .failed)
            XCTAssertNil(f.connection.dsmSession)
            XCTAssertTrue(f.savedCredentials.isEmpty)
        }
    }

    @MainActor
    func testTimedOutRestoreShowsRecoveryFailureWithoutLANScanOrReauthentication() async {
        let f = RestoreOwnershipFixture()
        var operations = f.operations()
        operations.login = { _, _ in f.loginCalls += 1; throw URLError(.timedOut) }
        await f.store.restoreDSMConnection(using: f.connection, operations: operations)
        XCTAssertEqual(f.loginCalls, 1)
        XCTAssertEqual(f.fallbackCalls, 0)
        XCTAssertEqual(f.store.connectionRecoveryState, .failed)
        XCTAssertFalse(f.store.isRestoringConnection)
        XCTAssertFalse(f.store.isRefreshing)
        XCTAssertNil(f.connection.dsmSession)
        XCTAssertTrue(f.savedCredentials.isEmpty)
    }

    @MainActor
    func testRetryOfFailedRestorePublishesRestoringThenConnectedState() async {
        let f = RestoreOwnershipFixture()
        var failed = f.operations()
        failed.login = { _, _ in throw URLError(.timedOut) }
        await f.store.restoreDSMConnection(using: f.connection, operations: failed)
        let gate = RestoreStageGate<DSMLoginResult>()
        var retry = f.operations()
        retry.login = { _, _ in try await gate.load() }
        let task = Task { await f.store.restoreDSMConnection(using: f.connection, operations: retry) }
        await fulfillment(of: [gate.entered], timeout: 2)
        XCTAssertEqual(f.store.connectionRecoveryState, .restoring)
        XCTAssertTrue(f.store.isRestoringConnection)
        gate.finish(.success(f.result()))
        await task.value
        XCTAssertEqual(f.store.connectionRecoveryState, .idle)
        XCTAssertTrue(f.connection.isConnected)
        XCTAssertFalse(f.store.isRestoringConnection)
    }

    @MainActor
    func testForegroundAlreadyCancelledDoesNotConsumeCooldownOrStartIO() async {
        let f = ForegroundOwnershipFixture()
        f.connect()
        let sourceID = f.store.folderSourceID
        let task = Task { await f.store.refreshForForeground(using: f.connection, operations: f.operations()) }
        task.cancel()
        await task.value
        XCTAssertEqual(f.reachabilityCalls, 0)
        XCTAssertEqual(f.snapshotCalls, 0)
        XCTAssertEqual(f.store.folderSourceID, sourceID)
        XCTAssertFalse(f.store.isForegroundRefreshing)
        await f.store.refreshForForeground(using: f.connection, operations: f.operations())
        XCTAssertEqual(f.snapshotCalls, 1, "cancelled entry must not consume foreground cooldown")
        XCTAssertEqual(f.store.files.first?.name, "current.mkv")
    }

    @MainActor
    func testForegroundDirectRefreshAlreadyCancelledCannotClaimSource() async {
        let f = ForegroundOwnershipFixture(), sourceID = f.store.folderSourceID
        let task = Task { await f.store.refreshDSM(session: f.session(), useAgent: false, operations: f.operations()) }
        task.cancel()
        let result = await task.value
        XCTAssertFalse(result)
        XCTAssertEqual(f.reachabilityCalls, 0)
        XCTAssertEqual(f.snapshotCalls, 0)
        XCTAssertEqual(f.store.folderSourceID, sourceID)
        XCTAssertEqual(f.store.sourceKind, .mock)
        XCTAssertFalse(f.store.isRefreshing)
    }

    @MainActor
    func testForegroundOldReachabilityCleanupKeepsNewForegroundFlags() async {
        let f = ForegroundOwnershipFixture(), oldGate = RestoreStageGate<Bool>(), newGate = RestoreStageGate<AppDataProviding>()
        f.connect()
        var old = f.operations(); old.isReachable = { _ in try! await oldGate.load() }
        let oldTask = Task { await f.store.refreshForForeground(using: f.connection, operations: old) }
        await fulfillment(of: [oldGate.entered], timeout: 2)
        f.store.clearConnectionData(); f.connect(); f.now = f.now.addingTimeInterval(3600)
        let newSourceID = f.store.folderSourceID
        var current = f.operations(); current.loadRefreshSnapshot = { _ in try! await newGate.load() }
        let newTask = Task { await f.store.refreshForForeground(using: f.connection, operations: current) }
        await fulfillment(of: [newGate.entered], timeout: 2)
        oldGate.finish(.success(false)); await oldTask.value
        XCTAssertTrue(f.store.isForegroundRefreshing)
        XCTAssertTrue(f.store.isRefreshing)
        XCTAssertTrue(f.store.isDSMReachable)
        XCTAssertEqual(f.store.folderSourceID, newSourceID)
        newGate.finish(.success(f.snapshot("new.mkv"))); await newTask.value
        XCTAssertEqual(f.store.files.first?.name, "new.mkv")
        XCTAssertFalse(f.store.isForegroundRefreshing)
        XCTAssertFalse(f.store.isRefreshing)
    }

    @MainActor
    func testForegroundOldSnapshotWithReusedSIDCannotPublishNewLoginInventory() async {
        let f = ForegroundOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        let oldSession = f.connect()
        var old = f.operations(); old.loadRefreshSnapshot = { _ in try! await gate.load() }
        let task = Task { await f.store.refreshForForeground(using: f.connection, operations: old) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let current = f.connect()
        XCTAssertEqual(oldSession.sid, current.sid)
        XCTAssertNotEqual(oldSession.authenticationGeneration, current.authenticationGeneration)
        let sourceID = f.store.folderSourceID
        gate.finish(.success(f.snapshot("old.mkv"))); await task.value
        XCTAssertEqual(f.store.folderSourceID, sourceID)
        XCTAssertNotEqual(f.store.files.first?.name, "old.mkv")
        XCTAssertFalse(f.store.folderSnapshotMatchesSource)
        XCTAssertEqual(f.connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertFalse(f.store.isForegroundRefreshing)
    }

    @MainActor
    func testForegroundCancelledReachabilityFailureCannotMarkCurrentOffline() async {
        let f = ForegroundOwnershipFixture(), gate = RestoreStageGate<Bool>()
        f.connect()
        var operations = f.operations(); operations.isReachable = { _ in try! await gate.load() }
        let task = Task { await f.store.refreshForForeground(using: f.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        task.cancel(); gate.finish(.success(false)); await task.value
        XCTAssertTrue(f.store.isDSMReachable)
        XCTAssertEqual(f.snapshotCalls, 0)
        XCTAssertFalse(f.store.isRefreshing)
        XCTAssertFalse(f.store.isForegroundRefreshing)
    }

    @MainActor
    func testForegroundCancelledSnapshotCannotPublishOrMarkSnapshotCurrent() async {
        let f = ForegroundOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        f.connect()
        var operations = f.operations(); operations.loadRefreshSnapshot = { _ in try! await gate.load() }
        let task = Task { await f.store.refreshForForeground(using: f.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        task.cancel(); gate.finish(.success(f.snapshot("cancelled.mkv"))); await task.value
        XCTAssertNotEqual(f.store.files.first?.name, "cancelled.mkv")
        XCTAssertFalse(f.store.folderSnapshotMatchesSource)
        XCTAssertFalse(f.store.isRefreshing)
        XCTAssertFalse(f.store.isForegroundRefreshing)
    }

    @MainActor
    func testForegroundAcceptedSnapshotHonorsCooldownAndReleasesFlags() async {
        let f = ForegroundOwnershipFixture(); f.connect()
        await f.store.refreshForForeground(using: f.connection, operations: f.operations())
        XCTAssertEqual(f.store.files.first?.name, "current.mkv")
        XCTAssertTrue(f.store.folderSnapshotMatchesSource)
        XCTAssertFalse(f.store.isForegroundRefreshing)
        XCTAssertFalse(f.store.isRefreshing)
        f.now = f.now.addingTimeInterval(1)
        await f.store.refreshForForeground(using: f.connection, operations: f.operations())
        XCTAssertEqual(f.reachabilityCalls, 1)
        XCTAssertEqual(f.snapshotCalls, 1)
    }

    @MainActor
    func testForegroundRestoreOldCleanupKeepsNewConnectedForegroundWork() async {
        let f = ForegroundOwnershipFixture(), oldGate = RestoreStageGate<DSMLoginResult>(), newGate = RestoreStageGate<AppDataProviding>()
        var old = f.operations(); old.login = { _, _ in try await oldGate.load() }
        let task = Task { await f.store.refreshForForeground(using: f.connection, operations: old) }
        await fulfillment(of: [oldGate.entered], timeout: 2)
        f.store.clearConnectionData(); let current = f.connect(); f.now = f.now.addingTimeInterval(3600)
        var latest = f.operations(); latest.loadRefreshSnapshot = { _ in try! await newGate.load() }
        let newTask = Task { await f.store.refreshForForeground(using: f.connection, operations: latest) }
        await fulfillment(of: [newGate.entered], timeout: 2)
        let obsolete = f.session(sid: "obsolete-main")
        oldGate.finish(.success(DSMLoginResult(client: DSMClient(baseURL: obsolete.baseURL), session: obsolete)))
        await task.value
        XCTAssertTrue(f.store.isRefreshing)
        XCTAssertTrue(f.store.isForegroundRefreshing)
        XCTAssertFalse(f.store.isRestoringConnection)
        XCTAssertEqual(f.connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertEqual(f.savedCredentials.count, 0)
        XCTAssertEqual(f.logoutSessions.count, 1)
        newGate.finish(.success(f.snapshot("new.mkv"))); await newTask.value
        XCTAssertEqual(f.store.files.first?.name, "new.mkv")
        XCTAssertFalse(f.store.isForegroundRefreshing)
    }

    @MainActor
    func testSignOutSuspendedMainLogoutProtectsReusedNewFileSID() async {
        await checkSignOutDuringNewLogin(reusedSIDRole: "file", expectFileLogout: false)
    }

    @MainActor
    func testSignOutSuspendedMainLogoutProtectsFileSIDReusedAsNewMain() async {
        await checkSignOutDuringNewLogin(reusedSIDRole: "main", expectFileLogout: false)
    }

    @MainActor
    func testSignOutFailedMainLogoutStillProtectsReusedNewFileSID() async {
        await checkSignOutDuringNewLogin(reusedSIDRole: "file", expectFileLogout: false, mainFails: true)
    }

    @MainActor
    func testSignOutCanReleaseUnusedOldFileSIDWithoutClearingNewConnection() async {
        await checkSignOutDuringNewLogin(reusedSIDRole: nil, expectFileLogout: true)
    }

    @MainActor
    func testSignOutSameSIDOnSeparateAuthorityDoesNotSuppressOldCleanup() async {
        await checkSignOutDuringNewLogin(reusedSIDRole: "file", expectFileLogout: true, differentAuthority: true)
    }

    @MainActor
    private func checkSignOutDuringNewLogin(reusedSIDRole: String?, expectFileLogout: Bool,
                                           mainFails: Bool = false, differentAuthority: Bool = false) async {
        let http = DeferredLogoutFixture(mainFails: mainFails)
        let connection = NASConnectionStore(), device = MockAppDataProvider().device
        let old = DSMSession(baseURL: http.baseURL, sid: "old-main", fileStationSID: "old-file",
            account: "fixture-account", allowsSelfSignedCertificates: false, deviceID: nil)
        connection.connect(device: device, session: old)
        // Only fake HTTP and the test simulator's empty credential store are involved.
        let task = Task { await connection.signOut(client: http.client) }
        await fulfillment(of: [http.mainEntered], timeout: 2)
        XCTAssertNil(connection.dsmSession)
        XCTAssertFalse(connection.isConnected)
        let baseURL = differentAuthority ? URL(string: "https://separate.example.test")! : http.baseURL
        let current = DSMSession(baseURL: baseURL,
            sid: reusedSIDRole == "main" ? "old-file" : "new-main",
            fileStationSID: reusedSIDRole == "file" ? "old-file" : "new-file",
            account: "fixture-new-account", allowsSelfSignedCertificates: false, deviceID: nil)
        let operationID = connection.beginDSMConnectionAttempt()
        connection.connect(device: device, session: current)
        http.releaseMain()
        await task.value
        XCTAssertEqual(http.logoutTargets["Nastart"], "old-main")
        XCTAssertEqual(http.logoutTargets["FileStation"], expectFileLogout ? "old-file" : nil)
        XCTAssertEqual(connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertEqual(connection.dsmSession?.fileStationSID, current.fileStationSID)
        XCTAssertTrue(connection.isConnected)
        XCTAssertTrue(connection.ownsDSMConnectionAttempt(operationID))
    }

    @MainActor
    func testRestoreSnapshotInvalidatedByCacheClearCannotSaveOrRepublish() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        var operations = fixture.operations()
        operations.loadSnapshot = { _, _ in try! await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        fixture.store.clearCachedSnapshot()
        let sourceID = fixture.store.folderSourceID
        gate.finish(.success(MockAppDataProvider()))
        await task.value
        XCTAssertEqual(fixture.store.folderSourceID, sourceID)
        XCTAssertFalse(fixture.store.folderSnapshotMatchesSource)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        XCTAssertEqual(fixture.store.lastRefreshSummaryKey, "data.refresh.cache_cleared")
    }

    @MainActor
    func testManualLoginIntentPreemptsRestoreBeforeItsLoginReturns() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<DSMLoginResult>()
        var operations = fixture.operations()
        operations.login = { _, _ in try await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let manualID = fixture.store.beginDSMConnectionAttempt(using: fixture.connection)
        XCTAssertFalse(fixture.store.isRestoringConnection)
        gate.finish(.success(fixture.result()))
        await task.value
        XCTAssertTrue(fixture.connection.ownsDSMConnectionAttempt(manualID))
        XCTAssertNil(fixture.connection.dsmSession)
        XCTAssertEqual(fixture.fileLoginCalls, 0)
        XCTAssertEqual(fixture.logoutSessions.count, 1)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testRestoreCancelledFileLoginCannotPublishSourceOrStartSnapshot() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<DSMSession>()
        var operations = fixture.operations()
        var snapshotCalls = 0
        operations.attachFileStation = { _, _, _ in try! await gate.load() }
        operations.loadSnapshot = { _, _ in snapshotCalls += 1; return MockAppDataProvider() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let main = fixture.connection.dsmSession!, sourceID = fixture.store.folderSourceID
        task.cancel()
        gate.finish(.success(main.attachingFileStationSession(fixture.session(sid: "late-file"))))
        await task.value
        XCTAssertEqual(fixture.store.folderSourceID, sourceID)
        XCTAssertNil(fixture.connection.dsmSession?.fileStationSID)
        XCTAssertEqual(snapshotCalls, 0)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        XCTAssertEqual(fixture.logoutSessions.last?.fileStationSID, "late-file")
        XCTAssertNotEqual(fixture.store.lastRefreshSummaryKey, "data.refresh.restore_failed")
    }

    @MainActor
    func testRestorePublishesFileSessionWhileLANDiscoveryIsStillPending() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<URL?>()
        let result = fixture.result()
        let full = result.session.attachingFileStationSession(fixture.session(sid: "ready-file"))
        var operations = fixture.operations()
        var snapshotCalls = 0
        operations.login = { _, _ in result }
        operations.discoverLAN = { _ in try! await gate.load() }
        operations.attachFileStation = { _, _, _ in full }
        operations.loadSnapshot = { _, _ in snapshotCalls += 1; return MockAppDataProvider() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        XCTAssertEqual(fixture.connection.dsmSession?.fileStationGeneration, full.fileStationGeneration)
        XCTAssertFalse(fixture.store.folderSnapshotMatchesSource)
        XCTAssertEqual(snapshotCalls, 0)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        let fileSourceID = fixture.store.folderSourceID
        gate.finish(.success(nil))
        await task.value
        XCTAssertEqual(fixture.store.folderSourceID, fileSourceID)
        XCTAssertTrue(fixture.store.folderSnapshotMatchesSource)
        XCTAssertEqual(snapshotCalls, 1)
        XCTAssertEqual(fixture.savedCredentials.count, 1)
    }

    @MainActor
    func testManualTailLateLANDiscoveryCannotPublishToNewLogin() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<URL?>()
        let id = fixture.store.beginDSMConnectionAttempt(using: fixture.connection), result = fixture.result()
        fixture.store.activateDSMSession(session: result.session, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: result.session)
        var operations = fixture.operations()
        operations.discoverLAN = { _ in try! await gate.load() }
        let task = Task { try? await fixture.store.finishDSMConnection(result, credential: fixture.credential,
            operationID: id, using: fixture.connection, useAgent: false, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let current = fixture.session()
        fixture.store.activateDSMSession(session: current, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: current)
        let sourceID = fixture.store.folderSourceID
        gate.finish(.success(URL(string: "https://192.0.2.5")))
        await task.value
        XCTAssertEqual(fixture.connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertEqual(fixture.store.folderSourceID, sourceID)
        XCTAssertNil(fixture.connection.dsmSession?.endpoints.lanAddress)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testManualTailSnapshotCannotOverwriteNewLoginWithSameSID() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        let id = fixture.store.beginDSMConnectionAttempt(using: fixture.connection), result = fixture.result()
        fixture.store.activateDSMSession(session: result.session, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: result.session)
        var operations = fixture.operations()
        operations.loadSnapshot = { _, _ in try! await gate.load() }
        let task = Task { try? await fixture.store.finishDSMConnection(result, credential: fixture.credential,
            operationID: id, using: fixture.connection, useAgent: false, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let current = fixture.session()
        _ = fixture.store.beginDSMConnectionAttempt(using: fixture.connection)
        fixture.store.activateDSMSession(session: current, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: current)
        let sourceID = fixture.store.folderSourceID
        gate.finish(.success(MockAppDataProvider()))
        await task.value
        XCTAssertEqual(fixture.connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertEqual(fixture.store.folderSourceID, sourceID)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testManualTailPublishesFileSourceBeforeSnapshotWithoutSavingPassword() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        let id = fixture.store.beginDSMConnectionAttempt(using: fixture.connection), result = fixture.result()
        fixture.store.activateDSMSession(session: result.session, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: result.session)
        var operations = fixture.operations()
        let full = result.session.attachingFileStationSession(fixture.session(sid: "ready-file"))
        operations.attachFileStation = { _, _, code in XCTAssertEqual(code, "fixture-otp"); return full }
        operations.loadSnapshot = { _, _ in try! await gate.load() }
        let task = Task { try? await fixture.store.finishDSMConnection(result, credential: fixture.credential,
            operationID: id, using: fixture.connection, useAgent: false, saveCredential: false,
            oneTimeCode: "fixture-otp", operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        XCTAssertEqual(fixture.connection.dsmSession?.fileStationGeneration, full.fileStationGeneration)
        XCTAssertFalse(fixture.store.folderSnapshotMatchesSource)
        gate.finish(.success(MockAppDataProvider()))
        await task.value
        XCTAssertTrue(fixture.store.folderSnapshotMatchesSource)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testManualTailAlreadyCancelledCannotBeginOptionalWork() async {
        let fixture = RestoreOwnershipFixture(), result = fixture.result()
        let id = fixture.store.beginDSMConnectionAttempt(using: fixture.connection)
        fixture.store.activateDSMSession(session: result.session, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: result.session)
        let task = Task { try? await fixture.store.finishDSMConnection(result, credential: fixture.credential,
            operationID: id, using: fixture.connection, useAgent: false, operations: fixture.operations()) }
        task.cancel()
        await task.value
        XCTAssertEqual(fixture.fileLoginCalls, 0)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testRestoreCurrentCredentialWriteFailureRemainsVisibleAndDoesNotPublishSnapshot() async {
        let fixture = RestoreOwnershipFixture()
        var operations = fixture.operations()
        operations.saveCredential = { _ in throw URLError(.cannotWriteToFile) }
        await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations)
        XCTAssertEqual(fixture.store.lastRefreshSummaryKey, "data.refresh.restore_failed")
        XCTAssertFalse(fixture.store.isDSMReachable)
        XCTAssertFalse(fixture.store.folderSnapshotMatchesSource)
        XCTAssertFalse(fixture.store.isRefreshing)
        XCTAssertFalse(fixture.store.isRestoringConnection)
    }

    @MainActor
    func testLogoutProtectsReusedCurrentMainSIDButReleasesUnpublishedFileSID() async throws {
        let fixture = AuthenticationAPIFixture(), client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let main = try await client.login(account: "fixture-account", password: "fixture-password")
        let full = await client.addingFileStationSession(to: main, account: "fixture-account", password: "fixture-password")
        let current = try await client.login(account: "fixture-account", password: "fixture-password")
        XCTAssertNotEqual(main.authenticationGeneration, current.authenticationGeneration)
        XCTAssertEqual(main.sid, current.sid)
        await client.logout(session: full, protectingCurrentSession: { current })
        XCTAssertEqual(fixture.logoutTargets, ["FileStation": "fixture-file"])
    }

    @MainActor
    func testLogoutRechecksCurrentIdentityBeforeSecondRole() async throws {
        let fixture = AuthenticationAPIFixture(), client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let main = try await client.login(account: "fixture-account", password: "fixture-password")
        let full = await client.addingFileStationSession(to: main, account: "fixture-account", password: "fixture-password")
        var reads = 0
        await client.logout(session: full, protectingCurrentSession: {
            reads += 1
            return reads == 1 ? nil : full
        })
        XCTAssertEqual(reads, 2)
        XCTAssertEqual(fixture.logoutTargets, ["Nastart": "fixture-main"])
    }

    @MainActor
    func testLogoutIdentityPolicySeparatesAuthoritiesAndProtectsEitherCurrentRole() {
        let fixture = RestoreOwnershipFixture(), old = fixture.session()
        XCTAssertFalse(DSMClient.mayLogout(sid: old.sid, session: old, current: fixture.session()))
        XCTAssertTrue(DSMClient.mayLogout(sid: "unused", session: old, current: fixture.session()))
        let other = DSMSession(baseURL: URL(string: "https://other.example.test")!, sid: old.sid,
            fileStationSID: nil, account: "other", allowsSelfSignedCertificates: false, deviceID: nil)
        XCTAssertTrue(DSMClient.mayLogout(sid: old.sid, session: old, current: other))
        let current = fixture.session(sid: "new-main").attachingFileStationSession(old)
        XCTAssertFalse(DSMClient.mayLogout(sid: old.sid, session: old, current: current))
    }

    @MainActor
    func testOldConnectionCancellationCannotInvalidateNewAttempt() {
        let connection = NASConnectionStore(), old = connection.beginDSMConnectionAttempt()
        let current = connection.beginDSMConnectionAttempt()
        connection.cancelDSMConnectionAttempt(ownedBy: old)
        XCTAssertTrue(connection.ownsDSMConnectionAttempt(current))
        XCTAssertFalse(connection.ownsDSMConnectionAttempt(old))
        connection.cancelDSMConnectionAttempt(ownedBy: current)
        XCTAssertFalse(connection.ownsDSMConnectionAttempt(current))
    }

    @MainActor
    func testSignOutIntentInvalidatesPendingRestoreBeforeLateLoginReturns() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<DSMLoginResult>()
        var operations = fixture.operations()
        operations.login = { _, _ in try await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        fixture.store.clearConnectionData()
        // This simulator-only fixture has no stored credential or admitted server session.
        await fixture.connection.signOut()
        gate.finish(.success(fixture.result()))
        await task.value
        XCTAssertNil(fixture.connection.dsmSession)
        XCTAssertFalse(fixture.connection.isConnected)
        XCTAssertFalse(fixture.store.isDSMReachable)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        XCTAssertEqual(fixture.fileLoginCalls, 0)
    }

    @MainActor
    func testRestoreCancelledBeforeStartDoesNotAuthenticate() async {
        let fixture = RestoreOwnershipFixture()
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: fixture.operations()) }
        task.cancel()
        await task.value
        XCTAssertEqual(fixture.loginCalls, 0)
        XCTAssertNil(fixture.connection.dsmSession)
    }

    @MainActor
    func testRestoreCancelledLoginCannotActivateOrStartFileLogin() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<DSMLoginResult>()
        var operations = fixture.operations()
        operations.login = { _, _ in try await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        task.cancel()
        gate.finish(.success(fixture.result()))
        await task.value
        XCTAssertNil(fixture.connection.dsmSession)
        XCTAssertFalse(fixture.store.isDSMReachable)
        XCTAssertEqual(fixture.fileLoginCalls, 0)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        XCTAssertNotEqual(fixture.store.lastRefreshSummaryKey, "data.refresh.restore_failed")
    }

    @MainActor
    func testRestoreLateLoginCannotReplaceManualSession() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<DSMLoginResult>()
        var operations = fixture.operations()
        operations.login = { _, _ in try await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let current = fixture.session()
        fixture.store.activateDSMSession(session: current, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: current)
        gate.finish(.success(fixture.result()))
        await task.value
        XCTAssertEqual(fixture.connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertTrue(fixture.store.isDSMReachable)
        XCTAssertEqual(fixture.fileLoginCalls, 0)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testRestoreLateSnapshotWithReusedSIDCannotSaveOrPublishOldLogin() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        var operations = fixture.operations()
        operations.loadSnapshot = { _, _ in try! await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let old = fixture.connection.dsmSession!, current = fixture.session()
        XCTAssertEqual(old.sid, current.sid)
        XCTAssertNotEqual(old.authenticationGeneration, current.authenticationGeneration)
        fixture.store.activateDSMSession(session: current, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: current)
        let sourceID = fixture.store.folderSourceID
        gate.finish(.success(MockAppDataProvider()))
        await task.value
        XCTAssertEqual(fixture.connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        XCTAssertEqual(fixture.store.folderSourceID, sourceID)
        XCTAssertFalse(fixture.store.folderSnapshotMatchesSource)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
    }

    @MainActor
    func testRestoreCancelledSnapshotCannotSaveOrPublishInventory() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<AppDataProviding>()
        var operations = fixture.operations()
        operations.loadSnapshot = { _, _ in try! await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let sourceID = fixture.store.folderSourceID
        task.cancel()
        gate.finish(.success(MockAppDataProvider()))
        await task.value
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        XCTAssertEqual(fixture.store.folderSourceID, sourceID)
        XCTAssertFalse(fixture.store.folderSnapshotMatchesSource)
        XCTAssertNotEqual(fixture.store.lastRefreshSummaryKey, "data.refresh.restore_failed")
    }

    @MainActor
    func testRestoreOldFailureCannotMarkCurrentManualLoginFailed() async {
        let fixture = RestoreOwnershipFixture(), gate = RestoreStageGate<DSMLoginResult>()
        var operations = fixture.operations()
        operations.login = { _, _ in try await gate.load() }
        let task = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: operations) }
        await fulfillment(of: [gate.entered], timeout: 2)
        let current = fixture.session()
        fixture.store.activateDSMSession(session: current, useAgent: false)
        fixture.connection.connect(device: fixture.store.device, session: current)
        let summary = fixture.store.lastRefreshSummaryKey
        gate.finish(.failure(URLError(.networkConnectionLost)))
        await task.value
        XCTAssertTrue(fixture.store.isDSMReachable)
        XCTAssertEqual(fixture.store.lastRefreshSummaryKey, summary)
        XCTAssertEqual(fixture.fallbackCalls, 0)
    }

    @MainActor
    func testRestoreOldCleanupCannotClearNewRestoreFlags() async {
        let fixture = RestoreOwnershipFixture(), oldGate = RestoreStageGate<AppDataProviding>(), newGate = RestoreStageGate<AppDataProviding>()
        var oldOperations = fixture.operations()
        oldOperations.loadSnapshot = { _, _ in try! await oldGate.load() }
        let oldTask = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: oldOperations) }
        await fulfillment(of: [oldGate.entered], timeout: 2)
        fixture.store.clearConnectionData()
        var newOperations = fixture.operations()
        newOperations.login = { _, _ in fixture.result(sid: "new-main") }
        newOperations.loadSnapshot = { _, _ in try! await newGate.load() }
        let newTask = Task { await fixture.store.restoreDSMConnection(using: fixture.connection, operations: newOperations) }
        await fulfillment(of: [newGate.entered], timeout: 2)
        oldGate.finish(.success(MockAppDataProvider()))
        await oldTask.value
        XCTAssertTrue(fixture.store.isRefreshing)
        XCTAssertTrue(fixture.store.isRestoringConnection)
        XCTAssertTrue(fixture.savedCredentials.isEmpty)
        newGate.finish(.success(MockAppDataProvider()))
        await newTask.value
        XCTAssertFalse(fixture.store.isRefreshing)
        XCTAssertFalse(fixture.store.isRestoringConnection)
        XCTAssertEqual(fixture.savedCredentials.count, 1)
        XCTAssertEqual(fixture.connection.dsmSession?.sid, "new-main")
    }

    @MainActor
    func testFolderViewAlreadyCancelledTaskCannotClaimCurrentRequest() async {
        let loader = FolderBrowserLoader(), gate = FolderLoadGate(), sourceID = UUID()
        let current = Task { await loader.load(sourceID: sourceID, isConnected: { true }) { try await gate.load() } }
        await fulfillment(of: [gate.entered], timeout: 2)
        var called = false
        let cancelled = Task {
            await loader.load(sourceID: sourceID, forceRefresh: true, isConnected: { true }) {
                called = true
                return [self.file("cancelled.mkv")]
            }
        }
        cancelled.cancel()
        await cancelled.value
        XCTAssertFalse(called)
        XCTAssertTrue(loader.isLoading)
        gate.finish(.success([file("current.mkv")]))
        await current.value
        XCTAssertEqual(loader.items.first?.name, "current.mkv")
        XCTAssertNil(loader.errorKey)
    }

    @MainActor
    func testFolderViewOldSuccessCannotOverwriteNewSource() async {
        let loader = FolderBrowserLoader(), old = FolderLoadGate()
        let first = Task { await loader.load(sourceID: UUID(), isConnected: { true }) { try await old.load() } }
        await fulfillment(of: [old.entered], timeout: 2)
        await loader.load(sourceID: UUID(), isConnected: { true }) { [self.file("current.mkv")] }
        old.finish(.success([file("old.mkv")]))
        await first.value
        XCTAssertEqual(loader.items.first?.name, "current.mkv")
        XCTAssertNil(loader.errorKey)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func testFolderViewOld119CannotStopNewSourceLoading() async {
        let loader = FolderBrowserLoader(), old = FolderLoadGate(), current = FolderLoadGate()
        let first = Task { await loader.load(sourceID: UUID(), isConnected: { true }) { try await old.load() } }
        await fulfillment(of: [old.entered], timeout: 2)
        let second = Task { await loader.load(sourceID: UUID(), isConnected: { true }) { try await current.load() } }
        await fulfillment(of: [current.entered], timeout: 2)
        old.finish(.failure(DSMClientError.apiFailed(code: 119)))
        await first.value
        XCTAssertTrue(loader.isLoading)
        XCTAssertNil(loader.errorKey)
        XCTAssertTrue(loader.items.isEmpty)
        current.finish(.success([file("current.mkv")]))
        await second.value
        XCTAssertTrue(loader.didLoad)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func testFolderViewTaskCancellationRejectsLateSuccessWithoutError() async {
        let loader = FolderBrowserLoader(), gate = FolderLoadGate(), sourceID = UUID()
        let task = Task { await loader.load(sourceID: sourceID, isConnected: { true }) { try await gate.load() } }
        await fulfillment(of: [gate.entered], timeout: 2)
        task.cancel()
        gate.finish(.success([file("cancelled.mkv")]))
        await task.value
        XCTAssertFalse(loader.didLoad)
        XCTAssertFalse(loader.isLoading)
        XCTAssertTrue(loader.items.isEmpty)
        XCTAssertNil(loader.errorKey)
        XCTAssertTrue(loader.needsRetry)
        await loader.load(sourceID: sourceID, isConnected: { true }) { [self.file("retry.mkv")] }
        XCTAssertEqual(loader.items.first?.name, "retry.mkv")
        XCTAssertFalse(loader.needsRetry)
    }

    @MainActor
    func testFolderViewLeavingAndReopeningRejectsOldFailure() async {
        let loader = FolderBrowserLoader(), gate = FolderLoadGate(), sourceID = UUID()
        let task = Task { await loader.load(sourceID: sourceID, isConnected: { true }) { try await gate.load() } }
        await fulfillment(of: [gate.entered], timeout: 2)
        loader.invalidate()
        await loader.load(sourceID: sourceID, isConnected: { true }) { [self.file("reopened.mkv")] }
        gate.finish(.failure(URLError(.networkConnectionLost)))
        await task.value
        XCTAssertEqual(loader.items.first?.name, "reopened.mkv")
        XCTAssertNil(loader.errorKey)
        XCTAssertFalse(loader.isLoading)
    }

    @MainActor
    func testFolderViewSameSourceOverlappingRefreshKeepsNewestRequest() async {
        let loader = FolderBrowserLoader(), gate = FolderLoadGate(), sourceID = UUID()
        let first = Task { await loader.load(sourceID: sourceID, isConnected: { true }) { try await gate.load() } }
        await fulfillment(of: [gate.entered], timeout: 2)
        await loader.load(sourceID: sourceID, forceRefresh: true, isConnected: { true }) { [self.file("refreshed.mkv")] }
        gate.finish(.success([file("old.mkv")]))
        await first.value
        XCTAssertEqual(loader.items.first?.name, "refreshed.mkv")
        XCTAssertNil(loader.errorKey)
    }

    @MainActor
    func testFolderViewCurrent119ClearsItemsAndRequiresExplicitRetry() async {
        let loader = FolderBrowserLoader(), sourceID = UUID()
        await loader.load(sourceID: sourceID, isConnected: { true }) { [self.file("cached.mkv")] }
        var calls = 0
        await loader.load(sourceID: sourceID, forceRefresh: true, isConnected: { true }) {
            calls += 1
            throw DSMClientError.apiFailed(code: 119)
        }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(loader.items.isEmpty)
        XCTAssertFalse(loader.didLoad)
        XCTAssertEqual(loader.errorKey, "devices.files.folder_load_failed")
        XCTAssertFalse(loader.isLoading)
        await loader.load(sourceID: sourceID, forceRefresh: true, isConnected: { true }) { [self.file("retry.mkv")] }
        XCTAssertEqual(loader.items.first?.name, "retry.mkv")
        XCTAssertNil(loader.errorKey)
    }

    @MainActor
    func testFolderViewEmptyDisconnectedAndCancellationHaveDifferentStates() async {
        let loader = FolderBrowserLoader()
        await loader.load(sourceID: UUID(), isConnected: { false }) { [] }
        XCTAssertEqual(loader.errorKey, "devices.files.dsm_disconnected")
        await loader.load(sourceID: UUID(), isConnected: { true }) { throw CancellationError() }
        XCTAssertNil(loader.errorKey)
        XCTAssertTrue(loader.needsRetry)
        XCTAssertFalse(loader.didLoad)
    }

    @MainActor
    func testFolderSourcePublishesFileSessionBeforeInventorySnapshot() {
        let store = AppDataStore(provider: MockAppDataProvider()), connection = NASConnectionStore()
        let main = folderSession(fileStationSID: nil)
        store.activateDSMSession(session: main, useAgent: false)
        connection.connect(device: store.device, session: main)
        let mainSource = store.folderSourceID
        let full = main.attachingFileStationSession(folderSession(sid: "new-file"))
        XCTAssertTrue(store.publishFolderSession(full, useAgent: false, using: connection))
        XCTAssertNotEqual(store.folderSourceID, mainSource)
        XCTAssertEqual(connection.dsmSession?.fileStationGeneration, full.fileStationGeneration)
        XCTAssertFalse(store.folderSnapshotMatchesSource, "Persisted/previous inventory is not a snapshot from this login")
        let fullSource = store.folderSourceID
        XCTAssertTrue(store.publishFolderSession(full, useAgent: false, using: connection))
        XCTAssertEqual(store.folderSourceID, fullSource, "Same session must not restart directory loading")
    }

    @MainActor
    func testFolderSourceRejectsOldLoginEvenWhenServerSIDIsReused() {
        let store = AppDataStore(provider: MockAppDataProvider()), connection = NASConnectionStore()
        let old = folderSession(fileStationSID: nil), current = folderSession(fileStationSID: nil)
        XCTAssertEqual(old.sid, current.sid)
        store.activateDSMSession(session: current, useAgent: false)
        connection.connect(device: store.device, session: current)
        let sourceID = store.folderSourceID
        XCTAssertFalse(store.publishFolderSession(old.attachingFileStationSession(folderSession()), useAgent: false, using: connection))
        XCTAssertEqual(store.folderSourceID, sourceID)
        XCTAssertEqual(connection.dsmSession?.authenticationGeneration, current.authenticationGeneration)
        // Independently reject a stale data source even if the connection matches.
        connection.connect(device: store.device, session: old)
        XCTAssertFalse(store.publishFolderSession(old, useAgent: false, using: connection))
        XCTAssertEqual(store.folderSourceID, sourceID)
    }


    func testSuccessfulLoginsGetDistinctLocalIdentitiesEvenIfServerReusesSID() async throws {
        let fixture = AuthenticationAPIFixture()
        let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let first = try await client.login(account: "fixture-account", password: "fixture-password")
        let second = try await client.login(account: "fixture-account", password: "fixture-password")
        XCTAssertEqual(first.sid, second.sid)
        XCTAssertNotEqual(first.authenticationGeneration, second.authenticationGeneration)
        XCTAssertNil(first.fileStationGeneration)
        XCTAssertNil(second.fileStationGeneration)
    }

    func testFileStationAttachmentAndLogoutRetainTheirActualLoginIdentities() async throws {
        let fixture = AuthenticationAPIFixture()
        let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let main = try await client.login(account: "fixture-account", password: "fixture-password")
        let file = try await client.login(account: "fixture-account", password: "fixture-password", sessionName: "FileStation")
        let combined = main.attachingFileStationSession(file)
        XCTAssertEqual(combined.authenticationGeneration, main.authenticationGeneration)
        XCTAssertEqual(combined.fileStationGeneration, file.authenticationGeneration)
        XCTAssertEqual(combined.sid, main.sid)
        XCTAssertEqual(combined.fileStationSID, file.sid)
        let fields = DSMFolderDiagnosticContext(origin: .browserFolder, session: combined).fields(attempt: 1)
        XCTAssertEqual(fields["requestAuthenticationGeneration"], file.authenticationGeneration.uuidString)
        XCTAssertEqual(fields["authenticationGeneration"], main.authenticationGeneration.uuidString)
        await client.logout(session: combined)
        XCTAssertEqual(fixture.logoutTargets, ["Nastart": main.sid, "FileStation": file.sid])
    }

    func testFailedOptionalFileStationLoginDoesNotInventAnAuthenticationIdentity() async throws {
        let fixture = AuthenticationAPIFixture(failFileStation: true)
        let client = DSMClient(baseURL: fixture.baseURL, urlSession: fixture.session)
        let main = try await client.login(account: "fixture-account", password: "fixture-password")
        let combined = await client.addingFileStationSession(to: main, account: "fixture-account", password: "fixture-password")
        XCTAssertEqual(combined.authenticationGeneration, main.authenticationGeneration)
        XCTAssertNil(combined.fileStationSID)
        XCTAssertNil(combined.fileStationGeneration)
        let fields = DSMFolderDiagnosticContext(origin: .browserRoot, session: combined).fields(attempt: 1)
        XCTAssertEqual(fields["sessionRole"], "dsmFallback")
        XCTAssertEqual(fields["requestAuthenticationGeneration"], main.authenticationGeneration.uuidString)
    }

    func testEndpointCopiesAndOldRequestContextsKeepTheOriginalLoginIdentity() throws {
        let original = folderSession()
        let oldRequest = DSMFolderDiagnosticContext(origin: .snapshot, session: original)
        let copy = original.replacingConnection(endpoints: original.endpoints)
        XCTAssertEqual(copy.authenticationGeneration, original.authenticationGeneration)
        XCTAssertEqual(copy.fileStationGeneration, original.fileStationGeneration)
        XCTAssertEqual(copy.fileStationOpenURLs(path: "/video/example.mkv"), original.fileStationOpenURLs(path: "/video/example.mkv"))
        let replacement = folderSession(sid: "main", fileStationSID: "file")
        XCTAssertNotEqual(replacement.authenticationGeneration, original.authenticationGeneration)
        XCTAssertNotEqual(replacement.fileStationGeneration, original.fileStationGeneration)
        let oldFields = oldRequest.fields(attempt: 2)
        XCTAssertEqual(oldFields["requestAuthenticationGeneration"], original.fileStationGeneration?.uuidString)
        XCTAssertNotEqual(oldFields["requestAuthenticationGeneration"], replacement.fileStationGeneration?.uuidString)
        XCTAssertEqual(Set(copy.authenticationDiagnosticFields.keys), ["authenticationGeneration", "fileStationGeneration"])
        for value in copy.authenticationDiagnosticFields.values { XCTAssertNotNil(UUID(uuidString: value)) }
    }

    func testDirectory119PreservesTheErrorAndStopsSameSIDFallbacks() async throws {
        for path in ["/", "/video"] {
            let fixture = FolderAPIFixture(codes: [119])
            let session = folderSession()
            let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
            do {
                _ = try await client.listFolder(session: session, folderPath: path)
                XCTFail("An invalid directory session must be surfaced")
            } catch DSMClientError.apiFailed(let code) {
                XCTAssertEqual(code, 119)
            }
            XCTAssertEqual(fixture.listAttempts, 1)
        }
    }

    func testDirectoryVersionFallbackStillSucceedsForCompatibilityErrors() async throws {
        let fixture = FolderAPIFixture(codes: [102, nil])
        let session = folderSession()
        let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
        let items = try await client.listFolder(session: session, folderPath: "/video")
        XCTAssertEqual(items.count, 0)
        XCTAssertEqual(fixture.listAttempts, 2)
    }

    func testDirectoryTransportFailureStopsCompatibilityFallbackAndRetainsItsError() async throws {
        for code in [URLError.Code.timedOut, .cannotFindHost, .cannotConnectToHost,
                     .dnsLookupFailed, .networkConnectionLost, .notConnectedToInternet,
                     .secureConnectionFailed, .cancelled] {
            for path in ["/", "/video"] {
                // A second request would succeed: retrying it would hide the
                // transport failure and silently add another wait/attempt.
                let retryable: Set<URLError.Code> = [.timedOut, .cannotConnectToHost,
                    .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed]
                let transportAttempts = retryable.contains(code) ? 2 : 1
                let fixture = FolderAPIFixture(codes: [nil], firstTransportError: code,
                                              transportErrorAttempts: transportAttempts)
                let session = folderSession()
                let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
                do {
                    _ = try await client.listFolder(session: session, folderPath: path)
                    XCTFail("Transport failure must not negotiate another API variant")
                } catch let error as URLError {
                    XCTAssertEqual(error.code, code)
                }
                XCTAssertEqual(fixture.listAttempts, transportAttempts, "Retain the existing same-request retry, then stop compatibility fallback")
            }
        }
    }

    func testDirectoryTransportFailureDoesNotPreventAnExplicitLaterRetry() async throws {
        let fixture = FolderAPIFixture(codes: [nil], firstTransportError: .timedOut, transportErrorAttempts: 2)
        let session = folderSession()
        let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
        do {
            _ = try await client.listFolder(session: session, folderPath: "/video")
            XCTFail("The first load must retain its timeout")
        } catch let error as URLError { XCTAssertEqual(error.code, .timedOut) }
        let items = try await client.listFolder(session: session, folderPath: "/video")
        XCTAssertTrue(items.isEmpty)
        XCTAssertEqual(fixture.listAttempts, 3, "No cross-request circuit breaker or negative cache")
    }

    func testDirectoryRetainsItsSameRequestTransientRetry() async throws {
        let fixture = FolderAPIFixture(codes: [nil], firstTransportError: .timedOut)
        let session = folderSession()
        let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
        let items = try await client.listFolder(session: session, folderPath: "/video")
        XCTAssertTrue(items.isEmpty)
        XCTAssertEqual(fixture.listAttempts, 2)
    }

    func testDirectoryMalformedJSONStillAllowsCompatibilityFallback() async throws {
        let fixture = FolderAPIFixture(codes: [nil], malformedFirstResponse: true)
        let session = folderSession()
        let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
        let items = try await client.listFolder(session: session, folderPath: "/video")
        XCTAssertTrue(items.isEmpty)
        XCTAssertEqual(fixture.listAttempts, 2)
    }

    func testDirectoryExhaustedFallbackRetainsTheLastAPIError() async throws {
        let fixture = FolderAPIFixture(codes: [103])
        let session = folderSession()
        let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
        do {
            _ = try await client.listFolder(session: session, folderPath: "/video")
            XCTFail("Failure must remain typed")
        } catch DSMClientError.apiFailed(let code) {
            XCTAssertEqual(code, 103)
        }
        XCTAssertEqual(fixture.listAttempts, 4)
    }

    func testDirectoryCancelledCallerDoesNotTryListFallbacks() async throws {
        let fixture = FolderAPIFixture(codes: [nil])
        let session = folderSession()
        let client = DSMClient(baseURL: session.baseURL, urlSession: fixture.session)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.listFolder(session: session, folderPath: "/video")
        }
        do { _ = try await task.value; XCTFail("Cancelled operation must not return a directory") }
        catch is CancellationError {}
        XCTAssertEqual(fixture.listAttempts, 0)
    }

    @MainActor
    func testDirectoryCacheInvalidatesForMainAndFileStationSessionChanges() async throws {
        let cache = DSMFolderCache()
        for session in [folderSession(), folderSession(sid: "new-main"),
                        folderSession(sid: "new-main", fileStationSID: "new-file"),
                        folderSession(sid: "new-main", fileStationSID: nil)] {
            cache.prepare(for: session)
            XCTAssertNil(cache.freshItems(for: "/video"))
            _ = try await cache.load(path: "/video") { [self.file("fresh.mkv")] }
            XCTAssertEqual(cache.freshItems(for: "/video")?.first?.name, "fresh.mkv")
            cache.prepare(for: session)
            XCTAssertNotNil(cache.freshItems(for: "/video"), "Unchanged session must retain its cache")
        }
    }

    @MainActor
    func testDirectoryOldSuccessCannotReachAnyWaiterOrOverwriteNewCache() async throws {
        let cache = DSMFolderCache()
        cache.prepare(for: folderSession())
        let old = FolderLoadGate()
        let first = Task { try await cache.load(path: "/video") { try await old.load() } }
        await fulfillment(of: [old.entered], timeout: 2)
        let sharedEntered = expectation(description: "old waiter entered")
        let shared = Task {
            sharedEntered.fulfill()
            return try await cache.load(path: "/video") { XCTFail("Must share old task"); return [] }
        }
        await fulfillment(of: [sharedEntered], timeout: 2)
        cache.prepare(for: folderSession(sid: "new-main"))
        _ = try await cache.load(path: "/video") { [self.file("new.mkv")] }
        old.finish(.success([file("old.mkv")]))
        for task in [first, shared] {
            do { _ = try await task.value; XCTFail("Old success must be rejected") }
            catch is CancellationError {}
        }
        XCTAssertEqual(cache.freshItems(for: "/video")?.first?.name, "new.mkv")
    }

    @MainActor
    func testDirectoryOldFailureCannotRemoveNewPendingTask() async throws {
        let cache = DSMFolderCache()
        cache.prepare(for: folderSession())
        let old = FolderLoadGate()
        let first = Task { try await cache.load(path: "/video") { try await old.load() } }
        await fulfillment(of: [old.entered], timeout: 2)
        cache.prepare(for: folderSession(fileStationSID: "new-file"))
        let current = FolderLoadGate()
        let second = Task { try await cache.load(path: "/video") { try await current.load() } }
        await fulfillment(of: [current.entered], timeout: 2)
        old.finish(.failure(DSMClientError.apiFailed(code: 119)))
        do { _ = try await first.value; XCTFail("Old failure must be cancellation") }
        catch is CancellationError {}
        let sharedEntered = expectation(description: "new waiter entered")
        let shared = Task {
            sharedEntered.fulfill()
            return try await cache.load(path: "/video") { XCTFail("Old cleanup removed the new task"); return [] }
        }
        await fulfillment(of: [sharedEntered], timeout: 2)
        current.finish(.success([file("new.mkv")]))
        let secondItems = try await second.value
        let sharedItems = try await shared.value
        XCTAssertEqual(secondItems.first?.name, "new.mkv")
        XCTAssertEqual(sharedItems.first?.name, "new.mkv")
    }

    @MainActor
    func testDirectoryExplicitClearRejectsLateResponseFromUnchangedSession() async throws {
        let cache = DSMFolderCache()
        cache.prepare(for: folderSession())
        let gate = FolderLoadGate()
        let task = Task { try await cache.load(path: "/video") { try await gate.load() } }
        await fulfillment(of: [gate.entered], timeout: 2)
        cache.clear()
        cache.prepare(for: folderSession())
        gate.finish(.success([file("old.mkv")]))
        do { _ = try await task.value; XCTFail("Clear must invalidate in-flight work") }
        catch is CancellationError {}
        XCTAssertNil(cache.freshItems(for: "/video"))
    }

    @MainActor
    func testDirectory119DoesNotReturnOrRetainAnOldCacheEntry() async throws {
        let cache = DSMFolderCache()
        cache.prepare(for: folderSession())
        _ = try await cache.load(path: "/video") { [self.file("old.mkv")] }
        do {
            _ = try await cache.load(path: "/video") { throw DSMClientError.apiFailed(code: 119) }
            XCTFail("An invalid session cannot use an old directory as a successful refresh")
        } catch DSMClientError.apiFailed(let code) { XCTAssertEqual(code, 119) }
        XCTAssertNil(cache.freshItems(for: "/video"))
    }

    @MainActor
    func testDirectory119InvalidatesOtherPathsAndPendingWaiters() async throws {
        let cache = DSMFolderCache()
        cache.prepare(for: folderSession())
        _ = try await cache.load(path: "/") { [self.file("video", folder: true)] }
        let gate = FolderLoadGate()
        let pending = Task { try await cache.load(path: "/music") { try await gate.load() } }
        await fulfillment(of: [gate.entered], timeout: 2)
        do {
            _ = try await cache.load(path: "/video") { throw DSMClientError.apiFailed(code: 119) }
            XCTFail("Invalid session must be surfaced")
        } catch DSMClientError.apiFailed(let code) { XCTAssertEqual(code, 119) }
        XCTAssertNil(cache.freshItems(for: "/"))
        gate.finish(.success([file("late.m4a")]))
        do { _ = try await pending.value; XCTFail("Other pending directories share the invalid SID") }
        catch is CancellationError {}
        XCTAssertNil(cache.freshItems(for: "/music"))
    }

    @MainActor
    func testDirectoryTemporaryNetworkFailureKeepsSameSessionCacheFallback() async throws {
        let cache = DSMFolderCache()
        cache.prepare(for: folderSession())
        _ = try await cache.load(path: "/video") { [self.file("cached.mkv")] }
        let items = try await cache.load(path: "/video") { throw URLError(.networkConnectionLost) }
        XCTAssertEqual(items.first?.name, "cached.mkv")
    }

    private func folderSession(sid: String = "main", fileStationSID: String? = "file") -> DSMSession {
        DSMSession(baseURL: URL(string: "https://folder.example.test")!, sid: sid,
                   fileStationSID: fileStationSID, account: "fixture",
                   allowsSelfSignedCertificates: false, deviceID: nil)
    }
    func testFileResponseHTTPFailureIsClassifiedWithoutExportingPrivateContent() throws {
        let url = try XCTUnwrap(URL(string: "https://private.test/folder?sid=secret"))
        let response = try XCTUnwrap(HTTPURLResponse(url: url, statusCode: 502,
            httpVersion: nil, headerFields: ["Content-Type": "text/html", "Set-Cookie": "secret"]))
        var fields: [String: String] = [:]
        XCTAssertThrowsError(try DSMAPIResponseDecoder.decode(Data("secret".utf8), response: response) { fields = $0 }) {
            guard case DSMClientError.invalidResponse = $0 else { return XCTFail("HTTP failure must retain its error") }
        }
        XCTAssertEqual(fields, ["bodyBytes": "6", "contentType": "html", "httpStatus": "502", "responseKind": "httpFailure"])
        XCTAssertFalse(String(describing: fields).contains("secret"))
        XCTAssertFalse(String(describing: fields).contains("private.test"))
    }

    func testFileResponseSeparatesMalformedEnvelopeFromAPIFailure() throws {
        let response = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://example.test")!,
            statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"]))
        var fields: [String: String] = [:]
        for text in ["<html>secret</html>", "{\"data\":{}}", "{\"success\":\"true\"}"] {
            XCTAssertThrowsError(try DSMAPIResponseDecoder.decode(Data(text.utf8), response: response) { fields = $0 }) {
                XCTAssertTrue($0 is DecodingError)
            }
            XCTAssertEqual(fields["responseKind"], "malformedEnvelope")
        }
        XCTAssertThrowsError(try DSMAPIResponseDecoder.decode(Data("{\"success\":false,\"error\":{\"code\":119}}".utf8), response: response) { fields = $0 }) {
            guard case DSMClientError.apiFailed(let code) = $0 else { return XCTFail("API failure must retain its code") }
            XCTAssertEqual(code, 119)
        }
        XCTAssertEqual(fields["responseKind"], "apiFailure")
        XCTAssertEqual(fields["apiErrorCode"], "119")
    }

    func testFileResponseRetainsDataAndMissingDataSuccessSemantics() throws {
        let response = try XCTUnwrap(HTTPURLResponse(url: URL(string: "https://example.test")!,
            statusCode: 200, httpVersion: nil, headerFields: nil))
        var fields: [String: String] = [:]
        let data = try DSMAPIResponseDecoder.decode(Data("{\"success\":true,\"data\":{\"total\":2}}".utf8), response: response) { fields = $0 }
        XCTAssertEqual(data["total"]?.doubleValue, 2)
        XCTAssertEqual(fields["hasData"], "true")
        let empty = try DSMAPIResponseDecoder.decode(Data("{\"success\":true}".utf8), response: response) { fields = $0 }
        XCTAssertEqual(empty.objectValue?.count, 0)
        XCTAssertEqual(fields["hasData"], "false")
        XCTAssertEqual(fields["responseKind"], "success")
    }

    func testFileResponseRejectsNonHTTPWithoutChangingTheError() throws {
        let response = URLResponse(url: URL(string: "https://example.test")!, mimeType: nil,
            expectedContentLength: 0, textEncodingName: nil)
        var fields: [String: String] = [:]
        XCTAssertThrowsError(try DSMAPIResponseDecoder.decode(Data(), response: response) { fields = $0 }) {
            guard case DSMClientError.invalidResponse = $0 else { return XCTFail("Non-HTTP must retain its error") }
        }
        XCTAssertEqual(fields["responseKind"], "nonHTTP")
        XCTAssertNil(fields["httpStatus"])
    }

    func testDockerServiceDiscoveryKeepsLANAddressWhenDSMLoginUsesADomain() throws {
        let container = DockerContainer(id: UUID(), name: "homeassistant", image: "homeassistant/home-assistant",
                                        status: .online, cpu: nil, memoryText: "-", memoryBytes: nil, memoryPercent: nil, ports: ["8123->8123/tcp"])
        let domain = try XCTUnwrap(URL(string: "https://nas.example.test:5001"))
        let candidates = DSMClient.endpointCandidates(for: container, baseURL: domain, lanHosts: ["192.168.1.20"])
        XCTAssertEqual(candidates.first?.host, "192.168.1.20")
        XCTAssertEqual(DSMClient.unverifiedFallbackEndpoint(for: container, candidates: candidates)?.host, "192.168.1.20")
        let publicOnly = DSMClient.endpointCandidates(for: container, baseURL: domain, lanHosts: [])
        XCTAssertNil(DSMClient.unverifiedFallbackEndpoint(for: container, candidates: publicOnly),
                     "An unverified Docker port is not a configured public service endpoint")
    }

    func testLANOnlyServiceRemainsLANOnlyWithDomainLoginAndManualURLsRemainExplicit() throws {
        let lan = try XCTUnwrap(URL(string: "http://192.168.1.20:8123"))
        let domain = try XCTUnwrap(URL(string: "https://nas.example.test:5001"))
        let service = LaunchpadService(id: UUID(), name: "Home Assistant", iconText: "HA", category: .tools,
                                      status: .online, subtitle: "", detail: "", isMedia: false,
                                      cpu: nil, memoryText: nil, endpoint: lan, source: .container)
        XCTAssertEqual(service.preferredEndpoint(for: domain), lan)
        XCTAssertTrue(service.usesLANOnlyEndpoint(for: domain))
        XCTAssertEqual(service.preferredEndpoint(for: URL(string: "http://192.168.1.20:5000")), lan)
        let manual = LaunchpadService(id: UUID(), name: "Custom", iconText: "C", category: .tools,
                                     status: .online, subtitle: "", detail: "", isMedia: false,
                                     cpu: nil, memoryText: nil, endpoint: domain, source: .manual)
        XCTAssertEqual(manual.preferredEndpoint(for: lan), domain)
    }

    func testJellyfinFileLookupRestoresAnAccountStoredUnderALibrarySubpath() throws {
        let raw = try XCTUnwrap(URL(string: "https://media.example.test:8097/"))
        for path in ["/jellyfin", "/emby"] {
            let account = try XCTUnwrap(URL(string: "https://media.example.test:8097" + path))
            let storedAccounts = [account.absoluteString: "existing-session"]
            // Counterexample: the former file lookup misses a session the library restores.
            XCTAssertNil([raw].compactMap { storedAccounts[$0.absoluteString] }.first)
            XCTAssertEqual(JellyfinSessionEndpointPolicy.candidates(from: [raw])
                .compactMap { storedAccounts[$0.absoluteString] }.first, "existing-session")
        }
    }

    func testJellyfinSessionCandidatesNormalizeTheEndpointScopedRootAccount() throws {
        let raw = try XCTUnwrap(URL(string: "https://media.example.test:8097/?ignored=yes#tab"))
        let result = JellyfinSessionEndpointPolicy.candidates(from: [raw])
        XCTAssertEqual(result.first?.absoluteString, "https://media.example.test:8097")
        XCTAssertTrue(result.allSatisfy { $0.query == nil && $0.fragment == nil })
    }

    func testJellyfinSessionCandidatesKeepAnEffectiveCustomPathAheadOfFallbacks() throws {
        let effective = try XCTUnwrap(URL(string: "https://proxy.example.test:443/media/library"))
        let fallback = try XCTUnwrap(URL(string: "http://192.168.1.20:8096"))
        let result = JellyfinSessionEndpointPolicy.candidates(from: [effective, fallback, effective])
        XCTAssertEqual(result.first, effective)
        XCTAssertEqual(result.count, Set(result.map(\.absoluteString)).count)
        XCTAssertEqual(result.firstIndex(of: fallback), 3)
        XCTAssertTrue(result.contains { $0.path == "/emby" && $0.host == effective.host })
    }

    func testJellyfinSessionCandidatesDoNotInventCredentialsOriginsOrPorts() throws {
        let input = try XCTUnwrap(URL(string: "https://media.example.test:5443/custom"))
        let result = JellyfinSessionEndpointPolicy.candidates(from: [input])
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.allSatisfy {
            $0.scheme == input.scheme && $0.host == input.host && $0.port == input.port
                && $0.user == nil && $0.password == nil
        })
        XCTAssertTrue(JellyfinSessionEndpointPolicy.candidates(from: []).isEmpty)
    }

    /// Opt-in device route check; ordinary test runs never contact a NAS.
    func testDeviceEnvironmentPublicEndpoints() async throws {
        guard let configuration = ProcessInfo.processInfo.environment["NASTART_TEST_CONNECTION_PROBE_JSON"] else {
            throw XCTSkip("Device endpoints must be explicitly configured")
        }
        let endpoints = try JSONDecoder().decode([String: URL].self, from: Data(configuration.utf8))
        let metrics = DeviceProbeMetrics()
        let session = URLSession(configuration: .ephemeral, delegate: metrics, delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        for (label, url) in endpoints.sorted(by: { $0.key < $1.key }) {
            guard url.user == nil, url.password == nil else {
                XCTFail("Probe endpoints must be unauthenticated"); continue
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.cachePolicy = .reloadIgnoringLocalCacheData
            do {
                let (data, response) = try await session.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let success = json?["success"] as? Bool ?? true
                let summary = "\(label): HTTP \(status), json=\(json != nil), success=\(success), \(metrics.summary(for: url))"
                let evidence = XCTAttachment(string: summary)
                evidence.lifetime = .keepAlways
                add(evidence)
                XCTAssertTrue((200..<300).contains(status), "\(label) HTTP \(status)")
                XCTAssertNotNil(json, "\(label) must return API JSON")
                XCTAssertNotEqual(json?["success"] as? Bool, false, "\(label) API failed")
            } catch {
                let error = error as NSError
                let evidence = XCTAttachment(string: "\(label): \(error.domain) \(error.code), \(metrics.summary(for: url))")
                evidence.lifetime = .keepAlways
                add(evidence)
                XCTFail("\(label): \(error.domain) \(error.code)")
            }
        }
        XCTAssertFalse(endpoints.isEmpty)
    }

    func testPlaybackPreparationSeparatesTransportFailuresFromMissingStream() {
        let cases: [(Error, String)] = [
            (URLError(.timedOut), "jellyfin.player.prepare_timeout"),
            (URLError(.networkConnectionLost), "jellyfin.player.prepare_connection_failed"),
            (URLError(.notConnectedToInternet), "jellyfin.player.prepare_connection_failed"),
            (URLError(.cannotConnectToHost), "jellyfin.player.prepare_connection_failed"),
            (URLError(.serverCertificateUntrusted), "jellyfin.player.prepare_secure_connection_failed"),
            (JellyfinLibraryError.missingPlaybackURL, "jellyfin.player.prepare_failed_detail"),
            (JellyfinLibraryError.missingSession, "jellyfin.player.prepare_access_denied"),
            (NSError(domain: "fixture", code: NSURLErrorTimedOut), "jellyfin.player.prepare_unknown_failure")
        ]
        for (error, key) in cases {
            XCTAssertEqual(JellyfinPlaybackPreparationErrorPolicy.messageKey(for: error), key)
        }
    }

    func testPlaybackPreparationDoesNotPresentCancelledRequestsAsFailure() {
        let wrapped = NSError(domain: "fixture.wrapper", code: 1,
            userInfo: [NSUnderlyingErrorKey: URLError(.cancelled)])
        for error: Error in [CancellationError(), URLError(.cancelled), wrapped] {
            XCTAssertNil(JellyfinPlaybackPreparationErrorPolicy.messageKey(for: error))
        }
    }

    func testPlaybackPreparationUsesRealHTTPStatusAndWrappedNetworkError() {
        for status in [401, 403] {
            XCTAssertEqual(JellyfinPlaybackPreparationErrorPolicy.messageKey(for: APIError.unacceptableStatusCode(status)),
                "jellyfin.player.prepare_access_denied")
        }
        for status in [429, 500, 503, 599] {
            XCTAssertEqual(JellyfinPlaybackPreparationErrorPolicy.messageKey(for: APIError.unacceptableStatusCode(status)),
                "jellyfin.player.prepare_server_unavailable")
        }
        let wrapped = NSError(domain: "fixture.wrapper", code: 1,
            userInfo: [NSUnderlyingErrorKey: URLError(.timedOut),
                       NSLocalizedDescriptionKey: "https://user:secret@example.invalid/video?api_key=private"])
        XCTAssertEqual(JellyfinPlaybackPreparationErrorPolicy.messageKey(for: wrapped),
            "jellyfin.player.prepare_timeout", "The presentation returns a localization key, never raw server or credential text")
        XCTAssertEqual(JellyfinPlaybackPreparationErrorPolicy.messageKey(for: APIError.unacceptableStatusCode(404)),
            "jellyfin.player.prepare_unknown_failure", "A failed endpoint is not proof that negotiation returned no stream")
    }

    func testJellyfinHTTPStatusUsesActualResponseFailure() {
        for status in [401, 403, 429, 503] {
            XCTAssertEqual(JellyfinHTTPStatus.code(for: APIError.unacceptableStatusCode(status)), status)
        }
        XCTAssertNil(JellyfinHTTPStatus.code(for: APIError.unacceptableStatusCode(999)))
    }

    func testJellyfinHTTPStatusDoesNotInferNumbersFromTransportErrors() {
        let error = NSError(domain: NSURLErrorDomain, code: -1017, userInfo: [
            NSLocalizedDescriptionKey: "Cannot parse response for task 281 at /items/401"
        ])
        XCTAssertNil(JellyfinHTTPStatus.code(for: error))
        XCTAssertNil(JellyfinHTTPStatus.code(for: URLError(.timedOut)))
    }

    func testJellyfinLANProbeRetriesTransientFailuresWithABoundedBudget() {
        var policy = JellyfinLANPlaybackProbePolicy()
        XCTAssertEqual(policy.evaluate(publicID: nil, lanID: nil), .retryAfter(2_000_000_000))
        XCTAssertEqual(policy.evaluate(publicID: "server-a", lanID: nil), .retryAfter(6_000_000_000))
        XCTAssertEqual(policy.evaluate(publicID: nil, lanID: nil), .retriesExhausted)
        XCTAssertEqual(policy.retryCount, 2)
        XCTAssertEqual(policy.evaluate(publicID: "server-a", lanID: "server-a"), .verified)
        XCTAssertEqual(policy.retryCount, 2)
    }

    func testJellyfinLANProbeRequiresTheSameNonemptyServerID() {
        var policy = JellyfinLANPlaybackProbePolicy()
        XCTAssertEqual(policy.evaluate(publicID: "server-a", lanID: "server-b"), .differentServer)
        XCTAssertEqual(policy.retryCount, 0)
        XCTAssertEqual(policy.evaluate(publicID: "server-a", lanID: "server-a"), .verified)
        XCTAssertEqual(policy.retryCount, 0)
        XCTAssertEqual(policy.evaluate(publicID: "", lanID: ""), .retryAfter(2_000_000_000))
    }

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
        let publicAgentServices = AgentSnapshotMerger.merge(
            dsm: Self.emptyDSMSnapshot(), agent: agent,
            agentBaseURL: URL(string: "https://agent.example.test:8787")!,
            health: AgentHealthSnapshot(connection: StoredAgentConnection(
                baseURLString: "https://agent.example.test:8787", agentID: "agent-1", token: "fixture-token",
                hostIdentity: "nas", providerHint: "generic-linux", capabilities: [],
                allowsSelfSignedCertificates: false, pairedAt: Date()), failure: .invalidResponse)
        ).services
        XCTAssertTrue(publicAgentServices.allSatisfy { $0.endpoint == nil },
                      "Agent discovery must not invent externally exposed Docker ports")
    }

    func testServiceCategoryOrderingRestoresMissingCategories() {
        let ordered = ServiceCategory.ordered(from: "tools,tools,media")
        XCTAssertEqual(ordered, [.tools, .media, .favorites, .downloads, .network])
    }

    func testExportPayloadSelectionCombinationsReadOnlySelectedSnapshots() throws {
        for mask in 0..<8 {
            let selection = DataExportPayload.Selection(launchpad: mask & 1 != 0,
                reminders: mask & 2 != 0, settings: mask & 4 != 0)
            var reads = [0, 0, 0, 0]
            let text = DataExportPayload.text(selection: selection, exportedAt: Date(timeIntervalSince1970: 0),
                launchpad: { reads[0] += 1; return [] }, pending: { reads[1] += 1; return [] },
                history: { reads[2] += 1; return [] }, settings: { reads[3] += 1; return .init() })
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            var keys: Set<String> = ["formatVersion", "exportedAt"]
            if mask & 1 != 0 { keys.insert("launchpad") }
            if mask & 2 != 0 { keys.insert("reminders") }
            if mask & 4 != 0 { keys.insert("settings") }
            XCTAssertEqual(Set(object.keys), keys)
            XCTAssertEqual(reads, [mask & 1 == 0 ? 0 : 1, mask & 2 == 0 ? 0 : 1,
                                   mask & 2 == 0 ? 0 : 1, mask & 4 == 0 ? 0 : 1])
            XCTAssertEqual(selection.hasSelection, mask != 0)
            XCTAssertEqual(object["formatVersion"] as? Int, 1)
            XCTAssertEqual(object["exportedAt"] as? String, "1970-01-01T00:00:00Z")
        }
    }

    func testExportPayloadKnownPreferencesPreserveEnumCombinationsAndFalse() throws {
        for theme in LaunchpadTheme.allCases {
            for language in AppLanguage.allCases {
                for mode in AppThemeMode.allCases {
                    let object = try exportPayloadObject(settings: .init(theme: theme.rawValue,
                        language: language.rawValue, displayMode: mode.rawValue,
                        compactMetrics: false, showServiceStatus: false))
                    let values = try XCTUnwrap(object["settings"] as? [String: Any])
                    XCTAssertEqual(Set(values.keys), ["launchpadTheme", "language", "displayMode", "compactMetrics", "showServiceStatus"])
                    XCTAssertEqual(values["launchpadTheme"] as? String, theme.rawValue)
                    XCTAssertEqual(values["language"] as? String, language.rawValue)
                    XCTAssertEqual(values["displayMode"] as? String, mode.rawValue)
                    XCTAssertEqual(values["compactMetrics"] as? Bool, false)
                    XCTAssertEqual(values["showServiceStatus"] as? Bool, false)
                }
            }
        }
    }

    func testExportPayloadInvalidPreferenceTextFallsBackWithoutBeingExported() throws {
        for raw in ["AccessToken=fixture-preference-secret", "https://fixture.invalid/private", "", " en ", "SYSTEM"] {
            let object = try exportPayloadObject(settings: .init(theme: raw, language: raw, displayMode: raw))
            let settings = try XCTUnwrap(object["settings"] as? [String: Any])
            XCTAssertEqual(settings["launchpadTheme"] as? String, "cleanGrid")
            XCTAssertEqual(settings["language"] as? String, "system")
            XCTAssertEqual(settings["displayMode"] as? String, "system")
            let text = String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
            XCTAssertFalse(text.contains("fixture-preference-secret"))
            XCTAssertFalse(text.contains("fixture.invalid"))
        }
    }

    func testExportPayloadMissingPreferencesUseExistingDefaults() throws {
        let object = try exportPayloadObject()
        let values = try XCTUnwrap(object["settings"] as? [String: Any])
        XCTAssertEqual(values["launchpadTheme"] as? String, "cleanGrid")
        XCTAssertEqual(values["language"] as? String, "system")
        XCTAssertEqual(values["displayMode"] as? String, "system")
        XCTAssertEqual(values["compactMetrics"] as? Bool, true)
        XCTAssertEqual(values["showServiceStatus"] as? Bool, true)
    }

    func testExportPayloadKnownReminderKindsKeepIDsDatesAndFields() throws {
        for kind in ReminderKind.allCases {
            let task = exportPayloadTask(kind: kind.rawValue)
            let object = try exportPayloadObject(pending: [task])
            let reminders = try XCTUnwrap(object["reminders"] as? [String: [[String: Any]]])
            let row = try XCTUnwrap(reminders["pending"]?.first)
            XCTAssertEqual(Set(row.keys), ["id", "title", "target", "createdAt", "daysBefore", "muted", "kind"])
            XCTAssertEqual(row["kind"] as? String, kind.rawValue)
            XCTAssertEqual(row["id"] as? String, task.id.uuidString)
            XCTAssertEqual(row["createdAt"] as? String, "1970-01-01T00:01:40Z")
            XCTAssertEqual(row["daysBefore"] as? Int, 14)
            XCTAssertEqual(row["muted"] as? Bool, true)
        }
    }

    func testExportPayloadUnknownReminderKindsAreOmittedWithoutMutatingTask() throws {
        for raw in [nil, "", "future-kind", "AccessToken=fixture-kind-secret"] as [String?] {
            let task = exportPayloadTask(kind: raw)
            let object = try exportPayloadObject(pending: [task])
            let reminders = try XCTUnwrap(object["reminders"] as? [String: [[String: Any]]])
            let row = try XCTUnwrap(reminders["pending"]?.first)
            XCTAssertNil(row["kind"])
            XCTAssertEqual(row["id"] as? String, task.id.uuidString)
            XCTAssertEqual(task.kindRawValue, raw)
            XCTAssertFalse(String(describing: object).contains("fixture-kind-secret"))
        }
    }

    func testExportPayloadOptionalTaskFieldsAndPendingHistoryOrder() throws {
        let first = exportPayloadTask(title: "first")
        let second = exportPayloadTask(title: "second", targetDate: Date(timeIntervalSince1970: 200))
        let completed = exportPayloadTask(title: "completed", completedAt: Date(timeIntervalSince1970: 300))
        let object = try exportPayloadObject(pending: [first, second], history: [completed])
        let reminders = try XCTUnwrap(object["reminders"] as? [String: [[String: Any]]])
        let pending = try XCTUnwrap(reminders["pending"])
        XCTAssertEqual(pending.compactMap { $0["title"] as? String }, ["first", "second"])
        XCTAssertNil(pending[0]["targetDate"])
        XCTAssertNil(pending[0]["completedAt"])
        XCTAssertEqual(pending[1]["targetDate"] as? String, "1970-01-01T00:03:20Z")
        let history = try XCTUnwrap(reminders["history"])
        XCTAssertEqual(history.first?["title"] as? String, "completed")
        XCTAssertEqual(history.first?["completedAt"] as? String, "1970-01-01T00:05:00Z")
        XCTAssertFalse(String(describing: object).contains("fixture-symbol-secret"))
    }

    func testExportPayloadServicesProjectAllowedFieldsAndMaskSecrets() throws {
        let object = try exportPayloadObject(services: [.init(name: "Jellyfin AccessToken=fixture-service-secret", category: .media, visible: false)])
        let rows = try XCTUnwrap(object["launchpad"] as? [[String: Any]])
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(Set(row.keys), ["name", "category", "visible"])
        XCTAssertEqual(row["category"] as? String, "media")
        XCTAssertEqual(row["visible"] as? Bool, false)
        XCTAssertFalse(String(describing: object).contains("fixture-service-secret"))
    }

    func testExportPayloadFixedSnapshotsRetainCorrelationFields() {
        let task = exportPayloadTask(title: "合成人物甲")
        func text() -> String {
            DataExportPayload.text(selection: .init(launchpad: false, reminders: true, settings: false),
                exportedAt: Date(timeIntervalSince1970: 0), launchpad: { [] }, pending: { [task] },
                history: { [] }, settings: { .init() })
        }
        let first = text()
        XCTAssertEqual(text(), first)
        XCTAssertTrue(first.contains(task.id.uuidString))
        XCTAssertTrue(first.contains("合成人物甲"))
        XCTAssertTrue(first.contains("1970-01-01T00:01:40Z"), "This export is not strictly anonymous")
    }

    func testExportPayloadCompleteSchemaDecodesWithTypedFields() throws {
        struct Service: Decodable { let name: String; let category: String; let visible: Bool }
        struct Reminder: Decodable {
            let id: UUID; let title: String; let target: String; let createdAt: Date
            let daysBefore: Int; let muted: Bool; let kind: String?
            let targetDate: Date?; let completedAt: Date?
        }
        struct Reminders: Decodable { let pending: [Reminder]; let history: [Reminder] }
        struct Settings: Decodable {
            let launchpadTheme: String; let language: String; let displayMode: String
            let compactMetrics: Bool; let showServiceStatus: Bool
        }
        struct Envelope: Decodable {
            let formatVersion: Int; let exportedAt: Date; let launchpad: [Service]
            let reminders: Reminders; let settings: Settings
        }
        let object = try exportPayloadObject(services: [.init(name: "媒体", category: .media, visible: true)],
                                             pending: [exportPayloadTask(kind: "service")])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(Envelope.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(result.formatVersion, 1)
        XCTAssertEqual(result.exportedAt, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(result.launchpad.count, 1)
        XCTAssertEqual(result.reminders.pending.first?.kind, "service")
        XCTAssertTrue(result.reminders.history.isEmpty)
        XCTAssertTrue(result.settings.compactMetrics)
        let golden = """
        {"formatVersion":1,"exportedAt":"1970-01-01T00:00:00Z",
         "launchpad":[{"name":"媒体","category":"media","visible":true}],
         "reminders":{"pending":[{"id":"00000000-0000-0000-0000-000000000001",
           "title":"合成提醒","target":"合成目标","createdAt":"1970-01-01T00:01:40Z",
           "daysBefore":14,"muted":true,"kind":"service"}],"history":[]},
         "settings":{"launchpadTheme":"cleanGrid","language":"system","displayMode":"system",
           "compactMetrics":true,"showServiceStatus":true}}
        """
        let expected = try JSONSerialization.jsonObject(with: Data(golden.utf8))
        XCTAssertTrue((object as NSDictionary).isEqual(expected), "Known values must retain the version-one export schema")
    }

    private func exportPayloadObject(services: [DataExportPayload.Service] = [], pending: [TaskItem] = [],
                                     history: [TaskItem] = [], settings: DataExportPayload.Preferences = .init()) throws -> [String: Any] {
        let text = DataExportPayload.text(selection: .init(launchpad: true, reminders: true, settings: true),
            exportedAt: Date(timeIntervalSince1970: 0), launchpad: { services }, pending: { pending },
            history: { history }, settings: { settings })
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
    }

    private func exportPayloadTask(kind: String? = nil, title: String = "合成提醒", subtitle: String = "合成目标", targetDate: Date? = nil,
                                   completedAt: Date? = nil) -> TaskItem {
        TaskItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: title,
                 subtitle: subtitle, symbol: "fixture-symbol-secret", isUrgent: true, isMuted: true,
                 createdAt: Date(timeIntervalSince1970: 100), daysBefore: 14,
                 targetDate: targetDate, kindRawValue: kind, completedAt: completedAt)
    }

    func testExportPayloadPreferencesReadRequestedSuiteWithActualStorageKeys() throws {
        let a = "nastart-export-fixture-\(UUID())"
        let b = "nastart-export-fixture-\(UUID())"
        let first = try XCTUnwrap(UserDefaults(suiteName: a))
        let second = try XCTUnwrap(UserDefaults(suiteName: b))
        defer { first.removePersistentDomain(forName: a); second.removePersistentDomain(forName: b) }
        first.setPersistentDomain([
            LaunchpadTheme.storageKey: "glassDeck", AppLanguage.storageKey: "en",
            AppThemeMode.storageKey: "dark", AppearancePreferenceKeys.compactMetrics: false,
            AppearancePreferenceKeys.showServiceStatus: true
        ], forName: a)
        second.setPersistentDomain([
            LaunchpadTheme.storageKey: "commandCenter", AppLanguage.storageKey: "zhHans",
            AppThemeMode.storageKey: "light", AppearancePreferenceKeys.compactMetrics: true,
            AppearancePreferenceKeys.showServiceStatus: false
        ], forName: b)
        let x = DataExportPayload.Preferences.read(from: first)
        let y = DataExportPayload.Preferences.read(from: second)
        XCTAssertEqual(x.theme, .glassDeck); XCTAssertEqual(x.language, .en); XCTAssertEqual(x.displayMode, .dark)
        XCTAssertFalse(x.compactMetrics); XCTAssertTrue(x.showServiceStatus)
        XCTAssertEqual(y.theme, .commandCenter); XCTAssertEqual(y.language, .zhHans); XCTAssertEqual(y.displayMode, .light)
        XCTAssertTrue(y.compactMetrics); XCTAssertFalse(y.showServiceStatus)
    }

    func testExportPayloadPreferenceFallbackDoesNotRepairOrDeleteStoredValues() throws {
        let name = "nastart-export-fixture-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let original: [String: Any] = [LaunchpadTheme.storageKey: "fixture-invalid-theme",
            AppLanguage.storageKey: "fixture-invalid-language", AppThemeMode.storageKey: "fixture-invalid-mode",
            AppearancePreferenceKeys.compactMetrics: "fixture-not-a-bool", "future.key": "fixture-retained"]
        defaults.setPersistentDomain(original, forName: name)
        let value = DataExportPayload.Preferences.read(from: defaults)
        XCTAssertEqual(value.theme, .cleanGrid); XCTAssertEqual(value.language, .system)
        XCTAssertEqual(value.displayMode, .system); XCTAssertTrue(value.compactMetrics)
        XCTAssertTrue(value.showServiceStatus)
        let after = try XCTUnwrap(defaults.persistentDomain(forName: name))
        XCTAssertTrue((after as NSDictionary).isEqual(original))
    }

    func testExportPayloadOnlyReadsPreferenceSuiteWhenSettingsAreSelected() throws {
        let name = "nastart-export-fixture-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("en", forKey: AppLanguage.storageKey)
        var reads = 0
        let preferences = {
            reads += 1
            return DataExportPayload.Preferences.read(from: defaults)
        }
        for selected in [false, true] {
            let text = DataExportPayload.text(selection: .init(launchpad: false, reminders: false, settings: selected),
                exportedAt: Date(timeIntervalSince1970: 0), launchpad: { [] }, pending: { [] }, history: { [] },
                settings: preferences)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            XCTAssertEqual(reads, selected ? 1 : 0)
            if selected { XCTAssertEqual((object["settings"] as? [String: Any])?["language"] as? String, "en") }
            else { XCTAssertNil(object["settings"]) }
        }
        XCTAssertEqual(defaults.string(forKey: AppLanguage.storageKey), "en")
    }

    func testDataExportMasksStructuredAddressesWithoutScheme() {
        for input in ["nas.example.test:5443/private?custom=fixture-query#fixture-fragment",
                      "fixture-user:fixture-pass@nas.example.test/private",
                      "192.0.2.45:5000/private?custom=fixture-query", "192.0.2.45",
                      "[2001:db8::1]:5443/private?custom=fixture-query", "[2001:db8::1]",
                      "//nas.example.test/private", "nas.local", "localhost:8000/private"] {
            XCTAssertEqual(DiagnosticLogStore.redactedExportText(input), "<redacted-address>", input)
        }
    }

    func testDataExportMasksEmbeddedBareAddressesAndPreservesSurroundingText() {
        let input = "🎬前 nas.example.test:5443/private?custom=fixture-query 中 [2001:db8::1]/private 后"
        let result = DiagnosticLogStore.redactedExportText(input)
        XCTAssertEqual(result, "🎬前 <redacted-address> 中 <redacted-address> 后")
        for (input, expected) in [
            ("server=nas.example.test:5443/private?custom=fixture-query", "server=<redacted-address>"),
            ("目标:[2001:db8::1]/private", "目标:<redacted-address>"),
            ("url=//nas.example.test/private", "url=<redacted-address>")
        ] {
            XCTAssertEqual(DiagnosticLogStore.redactedExportText(input), expected)
        }
        let url = "https://nas.example.test/private?custom=fixture-query"
        XCTAssertEqual(DiagnosticLogStore.redactedExportText("url=" + url),
                       "url=" + DiagnosticLogStore.redactedURL(URL(string: url)!))
    }

    func testDataExportPreservesDottedNamesAndVersionsWithoutAddressStructure() {
        for input in ["Movie.2026.1080p.mkv", "v1.2.3", "字幕.srt", "archive.tar.gz",
                      "1.2.3", "第1.2章", "状态.ready", "version=1.2.3", "nas.example.test"] {
            XCTAssertEqual(DiagnosticLogStore.redactedExportText(input), input)
        }
        // A bare DNS-looking label can also be a filename; no anonymity claim.
    }

    func testDataExportBareAddressProtectionIsIdempotentAndExportOnly() {
        let input = "nas.example.test:5443/private?custom=fixture-query"
        let once = DiagnosticLogStore.redactedExportText(input)
        XCTAssertEqual(once, "<redacted-address>")
        XCTAssertEqual(DiagnosticLogStore.redactedExportText(once), once)
        XCTAssertEqual(DiagnosticLogStore.redactedDetail(input), input,
                       "Export-only address rules must not alter telemetry text")
        let mixed = "https://nas.example.test/private?custom=fixture-query " + input
        let result = DiagnosticLogStore.redactedExportText(mixed)
        XCTAssertFalse(result.contains("private"))
        XCTAssertFalse(result.contains("fixture-query"))
        XCTAssertTrue(result.hasSuffix(" <redacted-address>"))
    }

    func testDataExportPayloadProtectsBareAddressesWithoutMutatingInputOrAddingFields() throws {
        let address = "nas.example.test:5443/private?custom=fixture-query"
        let task = exportPayloadTask(kind: "future-fixture-kind-secret", title: address,
                                     subtitle: "Movie.2026.1080p.mkv")
        let object = try exportPayloadObject(services: [.init(name: address, category: .media, visible: true)],
                                             pending: [task])
        let services = try XCTUnwrap(object["launchpad"] as? [[String: Any]])
        let reminders = try XCTUnwrap(object["reminders"] as? [String: [[String: Any]]])
        let item = try XCTUnwrap(reminders["pending"]?.first)
        XCTAssertEqual(services.first?["name"] as? String, "<redacted-address>")
        XCTAssertEqual(item["title"] as? String, "<redacted-address>")
        XCTAssertEqual(item["target"] as? String, "Movie.2026.1080p.mkv")
        XCTAssertEqual(Set(item.keys), ["id", "title", "target", "createdAt", "daysBefore", "muted"])
        XCTAssertEqual(item["id"] as? String, task.id.uuidString)
        XCTAssertEqual(task.title, address)
        XCTAssertEqual(task.kindRawValue, "future-fixture-kind-secret")
    }

    func testDataExportRedactsEntireQuotedSecretsIncludingEscapesAndLineBreaks() {
        let input = #"{"password":"alpha beta, gamma; delta", "token":"escaped \" phrase", "cookie":"one\ntwo"}"#
        let result = DiagnosticLogStore.redactedExportText(input)
        for secret in ["alpha", "beta", "gamma", "delta", "escaped", "phrase", "one", "two"] {
            XCTAssertFalse(result.contains(secret), result)
        }
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(result.utf8)))
    }

    func testDataExportRedactsSingleQuotedAndUnquotedSecretsBeforeHostHeuristic() {
        for input in ["password='single quoted secret'", "password=synthetic.secret.with.dots",
                      "Authorization: Basic Zml4dHVyZTpvbmx5", "token=unquoted value with spaces",
                      "AccessToken=fixture-access", "refreshToken=fixture-refresh",
                      "clientSecret=fixture-client", "Set-Cookie=fixture-cookie"] {
            let result = DiagnosticLogStore.redactedExportText(input)
            for secret in ["single", "quoted", "secret", "synthetic", "dots", "Zml4dHVyZTpvbmx5", "unquoted", "spaces",
                           "fixture-access", "fixture-refresh", "fixture-client", "fixture-cookie"] {
                XCTAssertFalse(result.contains(secret), result)
            }
            XCTAssertTrue(result.contains("<redacted>"), result)
        }
    }

    func testDataExportRedactsEmbeddedURLsWithoutDiscardingSurroundingText() {
        let input = "before https://fixture-user:fixture-pass@nas.example.test:5443/private-folder?custom=fixture-query#fixture-fragment after"
        let result = DiagnosticLogStore.redactedExportText(input)
        for secret in ["fixture-user", "fixture-pass", "private-folder", "fixture-query", "fixture-fragment"] {
            XCTAssertFalse(result.contains(secret), result)
        }
        XCTAssertTrue(result.hasPrefix("before https://"))
        XCTAssertTrue(result.hasSuffix(" after"))
        XCTAssertTrue(result.contains(":5443"))
    }

    func testDataExportPreservesSafeTextAndDoesNotTreatLongerKeysAsCredentials() {
        let input = "整理电影提醒；notpassword=public-label，tokenization=enabled"
        XCTAssertEqual(DiagnosticLogStore.redactedExportText(input), input)
        XCTAssertEqual(DiagnosticLogStore.redactedExportText("普通提醒"), "普通提醒")
    }

    func testDataExportKeepsURLAndPairingProtectionAndIsIdempotent() {
        let url = "https://fixture-user:fixture-pass@nas.example.test/private?token=fixture-token#fixture-fragment"
        XCTAssertEqual(DiagnosticLogStore.redactedExportText(url),
                       DiagnosticLogStore.redactedURL(URL(string: url)!))
        let once = DiagnosticLogStore.redactedExportText("token=fixture-token, pairingCode=123456")
        XCTAssertFalse(once.contains("fixture-token"))
        XCTAssertFalse(once.contains("123456"))
        XCTAssertEqual(DiagnosticLogStore.redactedExportText(once), once)
    }

    func testDataExportFreeTextIsNotGuaranteedAnonymous() {
        let input = "联系合成人物甲，保存到个人目录甲"
        XCTAssertEqual(DiagnosticLogStore.redactedExportText(input), input,
                       "Recognized secret redaction must not be described as strict anonymization")
    }

    func testDataExportRedactsUnterminatedQuotedSecretsAndActualLineBreaks() {
        for input in ["password=\"first-secret\nsecond-secret", "cookie='unfinished-secret",
                      "password=\"dangling-secret\\", "cookie='dangling-secret\\"] {
            let result = DiagnosticLogStore.redactedExportText(input)
            for secret in ["first-secret", "second-secret", "unfinished-secret", "dangling-secret"] {
                XCTAssertFalse(result.contains(secret), result)
            }
            XCTAssertTrue(result.contains("<redacted>"), result)
        }
    }

    func testDataExportRedactsMultipleUnicodeURLsAndPreservesSafeFields() {
        let input = "🎬前 https://first.example.test/私有甲?key=secret-one 中 ftp://fixture:secret-two@second.example.test/私有乙 后"
        let result = DiagnosticLogStore.redactedExportText(input)
        for secret in ["私有甲", "私有乙", "secret-one", "secret-two", "fixture:"] {
            XCTAssertFalse(result.contains(secret), result)
        }
        XCTAssertTrue(result.hasPrefix("🎬前 https://"))
        XCTAssertTrue(result.contains(" 中 ftp://"))
        XCTAssertTrue(result.hasSuffix(" 后"))
        XCTAssertEqual(DiagnosticLogStore.redactedExportText("visible=true, count=2"), "visible=true, count=2")
        XCTAssertEqual(DiagnosticLogStore.redactedExportText(""), "")
    }

    @MainActor
    func testDiagnosticPrivacySensitiveFieldsAreMaskedBeforeMemoryAndPersistence() async throws {
        let suite = "nastart-diagnostic-privacy-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let store = DiagnosticLogStore(defaults: defaults, persistenceKey: "entries")
        defer { store.clear(); defaults.removePersistentDomain(forName: suite) }
        store.record(.error, categoryKey: "fixture", messageKey: "fixture", details: [
            "password": "fixture secret, with separators", "Authorization": "Basic fixture-authorization",
            "AccessToken": "fixture-access", "refreshToken": "fixture-refresh",
            "clientSecret": "fixture-client", "Set-Cookie": "fixture-cookie",
            "path": "/private/fixture-name", "durationMs": "125.5", "playbackTraceID": "1234abcd"
        ])
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        var saved: [DiagnosticLogEntry] = []
        while ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
            if let data = defaults.data(forKey: "entries"),
               let entries = try? JSONDecoder().decode([DiagnosticLogEntry].self, from: data), !entries.isEmpty {
                saved = entries; break
            }
        }
        let memory = try XCTUnwrap(store.entries.first)
        let persisted = try XCTUnwrap(saved.first)
        for value in [memory.detail, persisted.detail, memory.exportLine] {
            for secret in ["fixture secret", "separators", "fixture-authorization", "fixture-name",
                           "fixture-access", "fixture-refresh", "fixture-client", "fixture-cookie"] {
                XCTAssertFalse(value.contains(secret), value)
            }
            XCTAssertTrue(value.contains("durationMs=125.5"), value)
            XCTAssertTrue(value.contains("playbackTraceID=1234abcd"), value)
        }
    }

    func testDiagnosticPrivacyQuotedSecretsAndEmbeddedURLsAreMasked() {
        let input = #"error={"password":"alpha beta, gamma", "token":"escaped \" phrase"}; url=https://fixture:secret@nas.example.test/private?custom=hidden#fragment"#
        let result = DiagnosticLogStore.redactedDetail(input)
        for secret in ["alpha", "beta", "gamma", "escaped", "phrase", "fixture:", "secret", "private", "hidden", "fragment"] {
            XCTAssertFalse(result.contains(secret), result)
        }
        for input in ["password=\"dangling-secret\\", "cookie='unfinished-secret\nnext-secret"] {
            let value = DiagnosticLogStore.redactedDetail(input)
            for secret in ["dangling-secret", "unfinished-secret", "next-secret"] {
                XCTAssertFalse(value.contains(secret), value)
            }
        }
    }

    func testDiagnosticPrivacyTelemetryValuesAndSortingRemainStable() {
        let input = ["playbackTraceID": "1234abcd", "durationMs": "125.5", "status": "206",
                     "planID": "89abcdef", "pathDepth": "3", "tokenCount": "2", "empty": ""]
        XCTAssertEqual(DiagnosticLogStore.redactedDetails(input),
                       "durationMs=125.5, pathDepth=3, planID=89abcdef, playbackTraceID=1234abcd, status=206, tokenCount=2")
        for input in ["0.0417", "durationMs=125.5", "notpassword=public tokenization=enabled"] {
            XCTAssertEqual(DiagnosticLogStore.redactedDetail(input), input)
        }
        XCTAssertEqual(DiagnosticLogStore.redactedDetails([" PASSWORD ": "fixture-secret"]),
                       " PASSWORD =<redacted>")
    }

    func testDiagnosticPrivacyLegacyDisplayIsSanitizedWithoutMutatingEvidence() {
        let raw = #"{"password":"legacy first second","durationMs":125.5}"#
        let entry = DiagnosticLogEntry(date: Date(timeIntervalSince1970: 0), level: .error,
                                       categoryKey: "fixture", messageKey: "fixture", detail: raw)
        XCTAssertEqual(entry.detail, raw)
        for text in [entry.exportLine, DiagnosticLogStore.redactedDetail(entry.detail)] {
            XCTAssertFalse(text.contains("first"), text)
            XCTAssertFalse(text.contains("second"), text)
            XCTAssertTrue(text.contains("125.5"), text)
        }
    }

    func testDiagnosticPrivacyQuotedJSONRemainsValidAndRedactionIsIdempotent() throws {
        let input = #"{"password":"quoted secret, with separators","status":206}"#
        let once = DiagnosticLogStore.redactedDetail(input)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: Data(once.utf8)))
        XCTAssertFalse(once.contains("secret"), once)
        XCTAssertFalse(once.contains("separators"), once)
        XCTAssertEqual(DiagnosticLogStore.redactedDetail(once), once)
    }

    func testDiagnosticPrivacyOrdinaryNamesAreNotGuaranteedAnonymous() {
        let value = "NAS 合成人物甲；自填事项甲"
        XCTAssertEqual(DiagnosticLogStore.redactedDetail(value), value)
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

    @MainActor
    func testContinuousDiagnosticsPersistBeforeLoggingStops() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "diagnostic-stream-\(UUID())"))
        let store = DiagnosticLogStore(defaults: defaults, persistenceKey: "entries")
        defer { store.clear() }
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        var persistedWhileProducing = false
        while ProcessInfo.processInfo.systemUptime < deadline {
            store.record(.info, categoryKey: "test", messageKey: "continuous")
            try await Task.sleep(nanoseconds: 30_000_000)
            if let data = defaults.data(forKey: "entries"),
               let entries = try? JSONDecoder().decode([DiagnosticLogEntry].self, from: data),
               !entries.isEmpty {
                persistedWhileProducing = true
                break
            }
        }
        XCTAssertTrue(persistedWhileProducing,
                      "Continuous events must be saved without waiting for a quiet period")
    }

    func testPlaybackStageTimingDoesNotTurnMissingOrInvalidStagesIntoFastResults() {
        XCTAssertEqual(PlaybackStageTiming.milliseconds(start: 0, end: 1), "unknown")
        XCTAssertEqual(PlaybackStageTiming.milliseconds(start: 5, end: 0), "unknown")
        XCTAssertEqual(PlaybackStageTiming.milliseconds(start: 5, end: 4), "unknown")
        XCTAssertEqual(PlaybackStageTiming.milliseconds(start: .nan, end: 6), "unknown")
        XCTAssertEqual(PlaybackStageTiming.milliseconds(start: 5, end: .infinity), "unknown")
        XCTAssertEqual(PlaybackStageTiming.milliseconds(start: 5, end: 5.125), "125.0")
    }

    @MainActor
    func testDiagnosticErrorFlushesPendingBatchAndClearDoesNotResurrectIt() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "diagnostic-error-\(UUID())"))
        let store = DiagnosticLogStore(defaults: defaults, persistenceKey: "entries")
        defer { store.clear() }
        store.record(.info, categoryKey: "test", messageKey: "pending")
        try await Task.sleep(nanoseconds: 30_000_000)
        store.record(.error, categoryKey: "test", messageKey: "failure")
        let deadline = ProcessInfo.processInfo.systemUptime + 0.5
        var errorSaved = false
        while ProcessInfo.processInfo.systemUptime < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
            if let data = defaults.data(forKey: "entries"),
               let entries = try? JSONDecoder().decode([DiagnosticLogEntry].self, from: data),
               entries.last?.level == .error {
                errorSaved = true
                break
            }
        }
        XCTAssertTrue(errorSaved, "Errors must save before the normal 750ms batch deadline")
        store.record(.info, categoryKey: "test", messageKey: "pending-clear")
        try await Task.sleep(nanoseconds: 30_000_000)
        store.clear()
        try await Task.sleep(nanoseconds: 900_000_000)
        XCTAssertNil(defaults.data(forKey: "entries"))
        XCTAssertTrue(store.entries.isEmpty)
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

    @MainActor
    func testFailedInventorySurvivesSnapshotRoundTripAndAnotherRefresh() throws {
        let media = Self.inventoryService(source: .container)
        let package = Self.inventoryService(source: .package)
        let container = DockerContainer(id: UUID(), name: "fixture", image: "fixture:latest",
            status: .online, cpu: nil, memoryText: "-", memoryBytes: nil, memoryPercent: nil, ports: [])
        let store = AppDataStore(provider: Self.inventorySnapshot(services: [media, package], containers: [container]))
        let failed = Self.inventorySnapshot(containerAvailable: false, packageAvailable: false)
        store.reload(from: failed, persistSnapshot: false)

        let retained = try XCTUnwrap(store.dsmSnapshotForPersistence())
        let decoded = try JSONDecoder().decode(DSMDataSnapshot.self, from: JSONEncoder().encode(retained))
        XCTAssertEqual(Set(decoded.services.map(\.id)), Set([media.id, package.id]))
        XCTAssertEqual(decoded.containers.map(\.id), [container.id])
        XCTAssertFalse(decoded.containerInventoryAvailable, "retained inventory is not a successful live response")
        XCTAssertFalse(decoded.packageInventoryAvailable)
        let relaunched = AppDataStore(provider: decoded)
        relaunched.reload(from: failed, persistSnapshot: false)
        XCTAssertTrue(relaunched.services.contains { $0.id == media.id && $0.endpoint == media.endpoint })
        XCTAssertTrue(relaunched.services.contains { $0.id == package.id })
        XCTAssertEqual(relaunched.containers.map(\.id), [container.id])
    }

    @MainActor
    func testSuccessfulEmptyInventoryStillRemovesServicesAcrossColdReload() throws {
        let media = Self.inventoryService(source: .container)
        let package = Self.inventoryService(source: .package)
        let store = AppDataStore(provider: Self.inventorySnapshot(services: [media, package]))
        store.reload(from: Self.inventorySnapshot(packageAvailable: false), persistSnapshot: false)
        let partial = try XCTUnwrap(store.dsmSnapshotForPersistence())
        XCTAssertFalse(partial.services.contains { $0.id == media.id }, "successful empty container inventory is authoritative")
        XCTAssertTrue(partial.services.contains { $0.id == package.id }, "independent failed package inventory must survive")
        store.reload(from: Self.inventorySnapshot(), persistSnapshot: false)
        let decoded = try JSONDecoder().decode(DSMDataSnapshot.self,
            from: JSONEncoder().encode(XCTUnwrap(store.dsmSnapshotForPersistence())))
        let relaunched = AppDataStore(provider: decoded)
        XCTAssertFalse(relaunched.services.contains { $0.id == media.id || $0.id == package.id })
        XCTAssertTrue(decoded.containers.isEmpty)
    }

    @MainActor
    func testCachedInventoryKeepsRetainedProxyEndpointAndExcludesManualServices() throws {
        let id = UUID()
        let proxy = Self.inventoryService(id: id, source: .reverseProxy, endpoint: "https://media.example.test")
        let raw = Self.inventoryService(id: id, source: .container, endpoint: "http://container.example.test:8096")
        let manual = Self.inventoryService(source: .manual)
        let store = AppDataStore(provider: Self.inventorySnapshot(services: [proxy]))
        store.reload(from: Self.inventorySnapshot(services: [raw, manual], proxyAvailable: false), persistSnapshot: false)
        XCTAssertTrue(store.services.contains { $0.id == manual.id })
        let decoded = try JSONDecoder().decode(DSMDataSnapshot.self,
            from: JSONEncoder().encode(XCTUnwrap(store.dsmSnapshotForPersistence())))
        XCTAssertEqual(decoded.services.first { $0.id == id }?.endpoint, proxy.endpoint)
        XCTAssertEqual(decoded.services.first { $0.id == id }?.source, .reverseProxy)
        XCTAssertFalse(decoded.reverseProxyInventoryAvailable)
        XCTAssertFalse(decoded.services.contains { $0.source == .manual }, "manual services use their own store")
    }

    private static func inventoryService(id: UUID = UUID(), source: LaunchpadServiceSource,
                                         endpoint: String = "https://inventory.example.test") -> LaunchpadService {
        LaunchpadService(id: id, name: "Fixture", iconText: "F", category: .media, status: .online,
            subtitle: "", detail: "fixture", isMedia: true, cpu: nil, memoryText: nil,
            endpoint: URL(string: endpoint), source: source)
    }

    private static func inventorySnapshot(services: [LaunchpadService] = [], containers: [DockerContainer] = [],
                                          containerAvailable: Bool = true, packageAvailable: Bool = true,
                                          proxyAvailable: Bool = true) -> DSMDataSnapshot {
        let base = emptyDSMSnapshot()
        return DSMDataSnapshot(device: base.device, services: services, containers: containers,
            files: base.files, tasks: base.tasks, videoLibraryItems: base.videoLibraryItems,
            audioLibraryItems: base.audioLibraryItems, discoveredDevices: base.discoveredDevices,
            containerInventoryAvailable: containerAvailable, packageInventoryAvailable: packageAvailable,
            reverseProxyInventoryAvailable: proxyAvailable, agentHealth: base.agentHealth)
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

/// Records transport facts only; no headers, credentials, or response bodies.
private final class DeviceProbeMetrics: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL: String] = [:]

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didFinishCollecting metrics: URLSessionTaskMetrics) {
        guard let url = task.originalRequest?.url else { return }
        let transactions = metrics.transactionMetrics
        let summary = transactions.isEmpty ? "metrics=unavailable" : transactions.map {
            "proxy=\($0.isProxyConnection), protocol=\($0.networkProtocolName ?? "unknown"), reused=\($0.isReusedConnection)"
        }.joined(separator: "; ")
        lock.lock(); defer { lock.unlock() }
        values[url] = summary
    }

    func summary(for url: URL) -> String {
        lock.lock(); defer { lock.unlock() }
        return values[url] ?? "metrics=unavailable"
    }
}

/// Deliberately ignores cancellation to model a late external response.
@MainActor
private final class FolderLoadGate {
    let entered = XCTestExpectation(description: "directory operation entered")
    private var continuation: CheckedContinuation<[FileItem], Error>?
    func load() async throws -> [FileItem] {
        try await withCheckedThrowingContinuation {
            continuation = $0
            entered.fulfill()
        }
    }
    func finish(_ result: Result<[FileItem], Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}

/// Holds an actual URLSession logout response until a newer login has been published.
private final class DeferredLogoutFixture {
    let baseURL = URL(string: "https://logout.example.test")!
    let mainEntered = XCTestExpectation(description: "old DSM logout response held")
    let session: URLSession
    lazy var client = DSMClient(baseURL: baseURL, urlSession: session)
    private let id = UUID().uuidString
    private let lock = NSLock()
    private var targets: [String: String] = [:]
    private var pendingMain: DeferredLogoutProtocol?
    private let mainFails: Bool
    var logoutTargets: [String: String] { lock.lock(); defer { lock.unlock() }; return targets }

    init(mainFails: Bool) {
        self.mainFails = mainFails
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DeferredLogoutProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Logout-Fixture": id]
        session = URLSession(configuration: configuration)
        DeferredLogoutProtocol.install(id: id) { [weak self] proto in self?.respond(to: proto) }
    }
    deinit { session.invalidateAndCancel(); DeferredLogoutProtocol.remove(id: id) }

    private func respond(to proto: DeferredLogoutProtocol) {
        let query = URLComponents(url: proto.request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if query.first(where: { $0.name == "api" })?.value == "SYNO.API.Info" {
            proto.finish(Data(#"{"success":true,"data":{"SYNO.API.Auth":{"path":"auth.cgi","minVersion":6,"maxVersion":6}}}"#.utf8))
            return
        }
        XCTAssertEqual(query.first(where: { $0.name == "method" })?.value, "logout")
        let role = query.first(where: { $0.name == "session" })!.value!
        let sid = query.first(where: { $0.name == "_sid" })!.value!
        lock.lock()
        targets[role] = sid
        if role == "Nastart" { pendingMain = proto }
        lock.unlock()
        if role == "Nastart" { mainEntered.fulfill() }
        else { proto.finish(Data(#"{"success":true,"data":{}}"#.utf8)) }
    }

    func releaseMain() {
        lock.lock(); let proto = pendingMain; pendingMain = nil; lock.unlock()
        proto?.finish(Data((mainFails ? #"{"success":false,"error":{"code":119}}"# : #"{"success":true,"data":{}}"#).utf8))
    }
}

private final class DeferredLogoutProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var handlers: [String: (DeferredLogoutProtocol) -> Void] = [:]
    static func install(id: String, handler: @escaping (DeferredLogoutProtocol) -> Void) {
        lock.lock(); defer { lock.unlock() }; handlers[id] = handler
    }
    static func remove(id: String) { lock.lock(); defer { lock.unlock() }; handlers[id] = nil }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); let handler = Self.handlers[request.value(forHTTPHeaderField: "X-Logout-Fixture") ?? ""]; Self.lock.unlock()
        guard let handler else { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
        handler(self)
    }
    func finish(_ data: Data) {
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// Held metadata uses no sleeps: tests release a response only after both
/// configured GETs are active, so winner/cancellation order is deterministic.
private final class EndpointPreparationFixture {
    enum PostOutcome { case success, timeout, httpError, missingSID, rejected, unsupportedThenSuccess }
    static let validMetadata = #"{"success":true,"data":{"SYNO.API.Auth":{"path":"auth.cgi","maxVersion":6}}}"#
    let external = URL(string: "https://external.example.test:5001/dsm")!
    let lan = URL(string: "http://192.168.42.10:5000/dsm")!
    var endpoints: DSMConnectionEndpoints { .init(primaryDomain: external, lanAddress: lan) }
    let metadataStarted = XCTestExpectation(description: "both configured metadata requests started")
    let metadataStopped = XCTestExpectation(description: "cancelled metadata transport stopped")
    let session: URLSession
    private let id = UUID().uuidString
    private let lock = NSLock()
    private var held: [String: EndpointPreparationProtocol] = [:]
    private var gets: [String] = [], posts: [String] = [], stopped: [String] = [], versions: [Int] = []
    private var metadataClean = true, postClean = true
    private let holdMetadata: Bool
    private let metadataBody: String
    private let postOutcome: PostOutcome
    var getHosts: [String] { lock.lock(); defer { lock.unlock() }; return gets }
    var postHosts: [String] { lock.lock(); defer { lock.unlock() }; return posts }
    var cancelledHosts: [String] { lock.lock(); defer { lock.unlock() }; return stopped }
    var postVersions: [Int] { lock.lock(); defer { lock.unlock() }; return versions }
    var credentialFreeMetadata: Bool { lock.lock(); defer { lock.unlock() }; return metadataClean }
    var credentialsOnlyInPOSTBody: Bool { lock.lock(); defer { lock.unlock() }; return postClean }

    init(holdMetadata: Bool = false, metadataBody: String = validMetadata, postOutcome: PostOutcome = .success) {
        self.holdMetadata = holdMetadata; self.metadataBody = metadataBody; self.postOutcome = postOutcome
        metadataStarted.expectedFulfillmentCount = 2
        metadataStopped.expectedFulfillmentCount = 2
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EndpointPreparationProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Endpoint-Fixture": id]
        session = URLSession(configuration: configuration)
        EndpointPreparationProtocol.install(id: id, start: { [weak self] in self?.start($0) },
                                            stop: { [weak self] in self?.stop($0) })
    }
    deinit { session.invalidateAndCancel(); EndpointPreparationProtocol.remove(id: id) }

    func login(prepare: Bool = true, endpoints: DSMConnectionEndpoints? = nil) async throws -> DSMLoginResult {
        try await DSMClient.login(endpoints: endpoints ?? self.endpoints,
            account: "fixture-account", password: "fixture-password", preferredRoute: .external,
            prepareConfiguredEndpoints: prepare, urlSession: session)
    }

    func finishMetadata(host: String, body: String? = nil, responseURL: URL? = nil) {
        lock.lock(); let pending = held.removeValue(forKey: host); lock.unlock()
        pending?.finish(body ?? metadataBody, responseURL: responseURL)
    }

    private func start(_ pending: EndpointPreparationProtocol) {
        let request = pending.request
        let host = request.url!.host!
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let secretNames = ["account", "passwd", "otp_code", "_sid"]
        if request.httpMethod != "POST" {
            lock.lock()
            gets.append(host)
            metadataClean = metadataClean && request.httpBody == nil && request.httpBodyStream == nil
                && !query.contains { secretNames.contains($0.name) }
                && query.first(where: { $0.name == "api" })?.value == "SYNO.API.Info"
            if holdMetadata { held[host] = pending }
            lock.unlock()
            metadataStarted.fulfill()
            if !holdMetadata { pending.finish(metadataBody) }
            return
        }
        var body = request.httpBody ?? Data()
        if body.isEmpty, let stream = request.httpBodyStream {
            stream.open(); defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count <= 0 { break }
                body.append(contentsOf: buffer.prefix(count))
            }
        }
        let form = URLComponents(string: "https://fixture.test/?" + String(decoding: body, as: UTF8.self))?.queryItems ?? []
        lock.lock()
        posts.append(host)
        versions.append(Int(form.first(where: { $0.name == "version" })?.value ?? "") ?? -1)
        let count = posts.count
        postClean = postClean && !query.contains { secretNames.contains($0.name) }
            && form.first(where: { $0.name == "account" })?.value == "fixture-account"
            && form.first(where: { $0.name == "passwd" })?.value == "fixture-password"
        lock.unlock()
        switch postOutcome {
        case .timeout: pending.fail(URLError(.timedOut))
        case .httpError: pending.finish("bad gateway", status: 502)
        case .missingSID: pending.finish(#"{"success":true,"data":{}}"#)
        case .rejected: pending.finish(#"{"success":false,"error":{"code":400}}"#)
        case .unsupportedThenSuccess where count == 1:
            pending.finish(#"{"success":false,"error":{"code":104}}"#)
        default: pending.finish(#"{"success":true,"data":{"sid":"prepared-session"}}"#)
        }
    }
    private func stop(_ pending: EndpointPreparationProtocol) {
        lock.lock(); defer { lock.unlock() }
        stopped.append(pending.request.url!.host!)
        held[pending.request.url!.host!] = nil
        metadataStopped.fulfill()
    }
}

private final class EndpointPreparationProtocol: URLProtocol {
    private static let registryLock = NSLock()
    private static var handlers: [String: (start: (EndpointPreparationProtocol) -> Void,
                                          stop: (EndpointPreparationProtocol) -> Void)] = [:]
    private let stateLock = NSRecursiveLock()
    private var completed = false
    static func install(id: String, start: @escaping (EndpointPreparationProtocol) -> Void,
                        stop: @escaping (EndpointPreparationProtocol) -> Void) {
        registryLock.lock(); defer { registryLock.unlock() }; handlers[id] = (start, stop)
    }
    static func remove(id: String) { registryLock.lock(); defer { registryLock.unlock() }; handlers[id] = nil }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.registryLock.lock()
        let handler = Self.handlers[request.value(forHTTPHeaderField: "X-Endpoint-Fixture") ?? ""]?.start
        Self.registryLock.unlock()
        guard let handler else { fail(URLError(.badServerResponse)); return }
        handler(self)
    }
    override func stopLoading() {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !completed else { return }; completed = true
        Self.registryLock.lock()
        let handler = Self.handlers[request.value(forHTTPHeaderField: "X-Endpoint-Fixture") ?? ""]?.stop
        Self.registryLock.unlock()
        handler?(self)
    }
    func finish(_ body: String, status: Int = 200, responseURL: URL? = nil) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !completed else { return }; completed = true
        let response = HTTPURLResponse(url: responseURL ?? request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    func fail(_ error: Error) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !completed else { return }; completed = true
        client?.urlProtocol(self, didFailWithError: error)
    }
}

private final class AuthenticationAPIFixture {
    let baseURL = URL(string: "https://authentication.example.test")!
    let session: URLSession
    private let id = UUID().uuidString
    private let lock = NSLock()
    private var targets: [String: String] = [:]
    private var credentialPosts = 0
    var logoutTargets: [String: String] { lock.lock(); defer { lock.unlock() }; return targets }
    var loginAttempts: Int { lock.lock(); defer { lock.unlock() }; return credentialPosts }

    init(failFileStation: Bool = false, loginResponses: [String]? = nil, loginHTTPStatus: Int = 200) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FolderAPIProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Folder-Fixture": id,
                                                "X-Login-Fixture-Status": String(loginHTTPStatus)]
        session = URLSession(configuration: configuration)
        FolderAPIProtocol.install(id: id) { [weak self] request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
            if query.first(where: { $0.name == "api" })?.value == "SYNO.API.Info" {
                return Data(#"{"success":true,"data":{"SYNO.API.Auth":{"path":"auth.cgi","minVersion":6,"maxVersion":6}}}"#.utf8)
            }
            if query.first(where: { $0.name == "method" })?.value == "logout" {
                let role = query.first(where: { $0.name == "session" })!.value!
                let sid = query.first(where: { $0.name == "_sid" })!.value!
                self?.lock.lock(); self?.targets[role] = sid; self?.lock.unlock()
                return Data(#"{"success":true,"data":{}}"#.utf8)
            }
            XCTAssertEqual(request.httpMethod, "POST")
            self?.lock.lock()
            self?.credentialPosts += 1
            let attempt = self?.credentialPosts ?? 1
            self?.lock.unlock()
            XCTAssertFalse(query.contains { ["account", "passwd", "otp_code"].contains($0.name) })
            var body = request.httpBody ?? Data()
            if body.isEmpty, let stream = request.httpBodyStream {
                stream.open(); defer { stream.close() }
                var buffer = [UInt8](repeating: 0, count: 1024)
                while stream.hasBytesAvailable {
                    let count = stream.read(&buffer, maxLength: buffer.count)
                    if count <= 0 { break }
                    body.append(contentsOf: buffer.prefix(count))
                }
            }
            let form = URLComponents(string: "https://fixture.test/?" + String(decoding: body, as: UTF8.self))?.queryItems ?? []
            XCTAssertEqual(form.first(where: { $0.name == "format" })?.value, "sid")
            if let loginResponses, !loginResponses.isEmpty {
                return Data(loginResponses[min(attempt - 1, loginResponses.count - 1)].utf8)
            }
            let isFileStation = form.first(where: { $0.name == "session" })?.value == "FileStation"
            if failFileStation && isFileStation { return Data(#"{"success":false,"error":{"code":400}}"#.utf8) }
            let sid = isFileStation ? "fixture-file" : "fixture-main"
            return Data("{\"success\":true,\"data\":{\"sid\":\"\(sid)\"}}".utf8)
        }
    }
    deinit { session.invalidateAndCancel(); FolderAPIProtocol.remove(id: id) }
}

private final class FolderAPIFixture {
    let session: URLSession
    private let id = UUID().uuidString
    private let lock = NSLock()
    private let codes: [Int?]
    private let firstTransportError: URLError.Code?
    private let malformedFirstResponse: Bool
    private let transportErrorAttempts: Int
    private var attempts = 0
    var listAttempts: Int { lock.lock(); defer { lock.unlock() }; return attempts }

    init(codes: [Int?], firstTransportError: URLError.Code? = nil,
         transportErrorAttempts: Int = 1, malformedFirstResponse: Bool = false) {
        self.codes = codes
        self.firstTransportError = firstTransportError
        self.transportErrorAttempts = transportErrorAttempts
        self.malformedFirstResponse = malformedFirstResponse
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FolderAPIProtocol.self]
        configuration.httpAdditionalHeaders = ["X-Folder-Fixture": id]
        session = URLSession(configuration: configuration)
        FolderAPIProtocol.install(id: id) { [weak self] request in
            try self?.response(for: request) ?? Data()
        }
    }
    deinit {
        session.invalidateAndCancel()
        FolderAPIProtocol.remove(id: id)
    }
    private func response(for request: URLRequest) throws -> Data {
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if query.first(where: { $0.name == "api" })?.value == "SYNO.API.Info" {
            return Data(#"{"success":true,"data":{"SYNO.FileStation.List":{"path":"entry.cgi","minVersion":1,"maxVersion":2}}}"#.utf8)
        }
        lock.lock()
        let code = codes[min(attempts, codes.count - 1)]
        attempts += 1
        let attempt = attempts
        lock.unlock()
        XCTAssertEqual(query.first(where: { $0.name == "_sid" })?.value, "file")
        if attempt <= transportErrorAttempts, let firstTransportError { throw URLError(firstTransportError) }
        if attempt == 1, malformedFirstResponse { return Data("not-json".utf8) }
        if let code { return Data("{\"success\":false,\"error\":{\"code\":\(code)}}".utf8) }
        return Data(#"{"success":true,"data":{"files":[],"total":0}}"#.utf8)
    }
}

private final class FolderAPIProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var handlers: [String: (URLRequest) throws -> Data] = [:]
    static func install(id: String, handler: @escaping (URLRequest) throws -> Data) {
        lock.lock(); defer { lock.unlock() }; handlers[id] = handler
    }
    static func remove(id: String) {
        lock.lock(); defer { lock.unlock() }; handlers[id] = nil
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handlers[request.value(forHTTPHeaderField: "X-Folder-Fixture") ?? ""]
        Self.lock.unlock()
        guard let handler else { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
        let data: Data
        do { data = try handler(request) }
        catch { client?.urlProtocol(self, didFailWithError: error); return }
        let status = request.httpMethod == "POST"
            ? Int(request.value(forHTTPHeaderField: "X-Login-Fixture-Status") ?? "200") ?? 200
            : 200
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor
private final class RestoreStageGate<Value> {
    let entered = XCTestExpectation(description: "controlled restore I/O entered")
    private var continuation: CheckedContinuation<Value, Error>?
    func load() async throws -> Value {
        try await withCheckedThrowingContinuation { continuation = $0; entered.fulfill() }
    }
    func finish(_ result: Result<Value, Error>) { continuation?.resume(with: result); continuation = nil }
}

@MainActor
private final class RestoreOwnershipFixture {
    let store = AppDataStore(provider: MockAppDataProvider())
    let connection = NASConnectionStore()
    var savedCredentials: [StoredNASCredential] = []
    var loginCalls = 0, fileLoginCalls = 0, fallbackCalls = 0
    var logoutSessions: [DSMSession] = []
    let credential = StoredNASCredential(baseURLString: "https://restore.example.test", account: "fixture-account", password: "fixture-password", useAgent: false)
    func session(sid: String = "main") -> DSMSession {
        DSMSession(baseURL: URL(string: credential.baseURLString)!, sid: sid, fileStationSID: nil,
                   account: credential.account, allowsSelfSignedCertificates: false, deviceID: nil)
    }
    func result(sid: String = "main") -> DSMLoginResult {
        let session = session(sid: sid)
        return DSMLoginResult(client: DSMClient(baseURL: session.baseURL), session: session)
    }
    func operations() -> DSMConnectionOperations {
        var operations = DSMConnectionOperations()
        operations.refreshServiceHealth = { _ in }
        operations.loadCredential = { self.credential }
        operations.usesAgent = { false }
        operations.login = { _, _ in self.loginCalls += 1; return self.result() }
        operations.discoverFallback = { self.fallbackCalls += 1; return [] }
        operations.discoverLAN = { _ in nil }
        operations.attachFileStation = { result, _, _ in self.fileLoginCalls += 1; return result.session }
        operations.loadSnapshot = { _, _ in MockAppDataProvider() }
        operations.saveCredential = { self.savedCredentials.append($0) }
        operations.logout = { session, _ in self.logoutSessions.append(session) }
        return operations
    }
}

@MainActor
private final class ForegroundOwnershipFixture {
    let store = AppDataStore(provider: MockAppDataProvider())
    let connection = NASConnectionStore()
    var now = Date().addingTimeInterval(3600)
    var reachabilityCalls = 0, snapshotCalls = 0
    var savedCredentials: [StoredNASCredential] = []
    var logoutSessions: [DSMSession] = []
    let credential = StoredNASCredential(baseURLString: "https://foreground.example.test",
        account: "fixture-account", password: "fixture-password", useAgent: false)
    func session(sid: String = "same-main") -> DSMSession {
        DSMSession(baseURL: URL(string: credential.baseURLString)!, sid: sid, fileStationSID: "same-file",
            account: credential.account, allowsSelfSignedCertificates: false, deviceID: nil)
    }
    @discardableResult func connect() -> DSMSession {
        let current = session()
        connection.connect(device: store.device, session: current)
        store.activateDSMSession(session: current, useAgent: false)
        return current
    }
    func snapshot(_ name: String) -> AppDataProviding { ForegroundTaggedSnapshot(name: name) }
    func operations() -> DSMConnectionOperations {
        var operations = DSMConnectionOperations()
        operations.currentTime = { self.now }
        operations.refreshServiceHealth = { _ in }
        operations.isReachable = { _ in self.reachabilityCalls += 1; return true }
        operations.loadRefreshSnapshot = { _ in self.snapshotCalls += 1; return self.snapshot("current.mkv") }
        operations.loadSnapshot = { _, _ in self.snapshot("current.mkv") }
        operations.loadCredential = { self.credential }
        operations.usesAgent = { false }
        operations.login = { _, _ in
            let session = self.session()
            return DSMLoginResult(client: DSMClient(baseURL: session.baseURL), session: session)
        }
        operations.discoverLAN = { _ in nil }
        operations.discoverFallback = { [] }
        operations.attachFileStation = { result, _, _ in result.session }
        operations.saveCredential = { self.savedCredentials.append($0) }
        operations.logout = { session, _ in self.logoutSessions.append(session) }
        return operations
    }
}

private struct ForegroundTaggedSnapshot: AppDataProviding {
    let device = MockAppDataProvider().device
    let services: [LaunchpadService] = []
    let containers: [DockerContainer] = []
    let files: [FileItem]
    let tasks: [TaskItem] = []
    let videoLibraryItems: [MediaItem] = []
    let audioLibraryItems: [MediaItem] = []
    let discoveredDevices: [DiscoveredNASDevice] = []
    let agentHealth: AgentHealthSnapshot? = nil
    init(name: String) {
        files = [FileItem(id: UUID(), name: name, subtitle: "/" + name, kind: .video, sizeText: "1 MB", children: [])]
    }
}

private final class StalledCredentialProtocol: URLProtocol {
    static var onStart: (() -> Void)?
    static var onStop: (() -> Void)?
    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "deadline.example.test"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.onStart?() }
    override func stopLoading() { Self.onStop?() }
}

private final class DroppingResumeDefaults: UserDefaults {
    override func set(_ value: Any?, forKey defaultName: String) {
        // A controlled same-process readback failure, not simulated disk durability.
    }
}

// MARK: - 第八批：可注入偏好域与缓存清理步骤

final class AppearanceStoreInjectionTests: XCTestCase {
    private func makeSuite() -> UserDefaults {
        let name = "nastart.tests.appearance.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: name)!
        addTeardownBlock { suite.removePersistentDomain(forName: name) }
        return suite
    }

    func testEmptySuiteUsesProductDefaults() {
        let store = AppearanceStore(defaults: makeSuite(), noteChange: {})
        XCTAssertEqual(store.launchpadTheme, .cleanGrid)
        XCTAssertTrue(store.compactMetrics)
        XCTAssertTrue(store.showServiceStatus)
    }

    func testChangesWriteOnlyInjectedSuiteAndNotifyOncePerChange() {
        let suite = makeSuite()
        let standardBefore = UserDefaults.standard.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool
        var notifications = 0
        let store = AppearanceStore(defaults: suite, noteChange: { notifications += 1 })
        let otherTheme = LaunchpadTheme.allCases.first { $0 != .cleanGrid }!

        store.compactMetrics = false
        store.showServiceStatus = false
        store.launchpadTheme = otherTheme

        XCTAssertEqual(suite.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool, false)
        XCTAssertEqual(suite.object(forKey: AppearancePreferenceKeys.showServiceStatus) as? Bool, false)
        XCTAssertEqual(suite.string(forKey: LaunchpadTheme.storageKey), otherTheme.rawValue)
        XCTAssertEqual(notifications, 3)
        XCTAssertEqual(UserDefaults.standard.object(forKey: AppearancePreferenceKeys.compactMetrics) as? Bool,
                       standardBefore)
    }

    func testStoreRestoresSavedValuesFromInjectedSuite() {
        let suite = makeSuite()
        let otherTheme = LaunchpadTheme.allCases.first { $0 != .cleanGrid }!
        suite.set(otherTheme.rawValue, forKey: LaunchpadTheme.storageKey)
        suite.set(false, forKey: AppearancePreferenceKeys.compactMetrics)
        suite.set(false, forKey: AppearancePreferenceKeys.showServiceStatus)

        let store = AppearanceStore(defaults: suite, noteChange: {})

        XCTAssertEqual(store.launchpadTheme, otherTheme)
        XCTAssertFalse(store.compactMetrics)
        XCTAssertFalse(store.showServiceStatus)
    }

    func testUnknownThemeValueFallsBackToDefault() {
        let suite = makeSuite()
        suite.set("not-a-theme", forKey: LaunchpadTheme.storageKey)
        XCTAssertEqual(AppearanceStore(defaults: suite, noteChange: {}).launchpadTheme, .cleanGrid)
    }

    @MainActor
    func testReloadReadsInjectedSuite() {
        let suite = makeSuite()
        let store = AppearanceStore(defaults: suite, noteChange: {})
        suite.set(false, forKey: AppearancePreferenceKeys.compactMetrics)
        store.reloadFromDefaults()
        XCTAssertFalse(store.compactMetrics)
    }
}

final class PrivacyCacheCleanerTests: XCTestCase {
    private final class Recorder { var names: [String] = [] }
    private struct StepFailure: Error {}

    @MainActor
    func testStepsRunOnceInOrderAndReportCleared() async {
        let recorder = Recorder()
        let cleaner = PrivacyCacheCleaner(steps: ["a", "b", "c"].map { name in
            PrivacyCacheCleaner.Step(name: name) { recorder.names.append(name) }
        })
        let outcome = await cleaner.clear()
        XCTAssertEqual(outcome, .cleared)
        XCTAssertEqual(recorder.names, ["a", "b", "c"])
    }

    @MainActor
    func testFailedStepDoesNotSkipLaterStepsAndIsReported() async {
        let recorder = Recorder()
        let cleaner = PrivacyCacheCleaner(steps: [
            .init(name: "a") { recorder.names.append("a") },
            .init(name: "b") { recorder.names.append("b"); throw StepFailure() },
            .init(name: "c") { recorder.names.append("c") }
        ])
        let outcome = await cleaner.clear()
        XCTAssertEqual(outcome, .partial(failedSteps: ["b"]))
        XCTAssertEqual(recorder.names, ["a", "b", "c"])
    }

    func testRemovingTemporaryDirectoriesIgnoresMissingAndRemovesExisting() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("nastart-cache-tests-\(UUID().uuidString)", isDirectory: true)
        let present = base.appendingPathComponent("Present", isDirectory: true)
        try FileManager.default.createDirectory(at: present, withIntermediateDirectories: true)
        try Data([1]).write(to: present.appendingPathComponent("file"))
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }

        XCTAssertNoThrow(try PrivacyCacheCleaner.removeTemporaryDirectories(named: ["Missing", "Present"], in: base))
        XCTAssertFalse(FileManager.default.fileExists(atPath: present.path))
    }

    func testRemovingTemporaryDirectoriesAttemptsAllBeforeThrowing() throws {
        final class FailingFirst: FileManager {
            override func removeItem(at url: URL) throws {
                if url.lastPathComponent == "A" { throw CocoaError(.fileWriteNoPermission) }
                try super.removeItem(at: url)
            }
        }
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("nastart-cache-tests-\(UUID().uuidString)", isDirectory: true)
        let a = base.appendingPathComponent("A", isDirectory: true)
        let b = base.appendingPathComponent("B", isDirectory: true)
        try FileManager.default.createDirectory(at: a, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: b, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: base) }

        XCTAssertThrowsError(try PrivacyCacheCleaner.removeTemporaryDirectories(
            named: ["A", "B"], in: base, fileManager: FailingFirst()))
        XCTAssertTrue(FileManager.default.fileExists(atPath: a.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: b.path))
    }
}

final class NastartShareOutcomeTests: XCTestCase {
    private struct ShareFailure: Error {}

    func testCompletedWithoutErrorIsCompleted() {
        XCTAssertEqual(NastartShareOutcome(completed: true, error: nil), .completed)
    }

    func testNotCompletedWithoutErrorIsCancelled() {
        XCTAssertEqual(NastartShareOutcome(completed: false, error: nil), .cancelled)
    }

    func testAnyErrorIsFailedRegardlessOfCompletedFlag() {
        XCTAssertEqual(NastartShareOutcome(completed: false, error: ShareFailure()), .failed)
        XCTAssertEqual(NastartShareOutcome(completed: true, error: ShareFailure()), .failed)
    }

    func testProductionProbeSimulatesNothing() {
        XCTAssertNil(NastartShareProbe.production.simulated)
    }

}

final class OfflineRootFixtureTests: XCTestCase {
    @MainActor
    func testOfflineRootFixtureWritesOnlyItsEphemeralDomainAndStaysOffline() async throws {
        let suiteName = "nastart.tests.offline-roots"
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let keys = ["tasks.localState.v1", "nastart.launchpadServiceVisibility.v1", "dsm.cachedSnapshot.v1"]
        let before = keys.map { UserDefaults.standard.data(forKey: $0) }

        let store = AppDataStore.offlineFixture(defaults: suite)
        XCTAssertFalse(store.tasks.isEmpty)
        XCTAssertFalse(store.services.isEmpty)
        store.completeTask(store.tasks[0])
        store.setService(store.services[0], visibleOnLaunchpad: !store.services[0].isLaunchpadVisible)
        await store.refreshServiceHealth()
        _ = try await store.loadFolder(path: "/")

        XCTAssertEqual(keys.map { UserDefaults.standard.data(forKey: $0) }, before)
        XCTAssertNotNil(suite.data(forKey: "tasks.localState.v1"))
        XCTAssertNotNil(suite.data(forKey: "nastart.launchpadServiceVisibility.v1"))
        XCTAssertTrue(store.serviceHealth.isEmpty)
        XCTAssertFalse(store.isRefreshing)

        let connection = NASConnectionStore(offlineFixture: store.device)
        XCTAssertTrue(connection.isConnected)
        XCTAssertNil(connection.agentConnection)
        XCTAssertNil(connection.dsmSession)
    }
}

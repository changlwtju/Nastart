import XCTest
@testable import NetworkMedia

final class MediaServiceDiscoveryTests: XCTestCase {
    func testDisplayAddressOmitsCredentialsQueryAndFragmentWithoutChangingOriginal() throws {
        let original = "https://fixture:fixture-only@media.invalid:8920/jellyfin?api_key=fixture-only#fixture"
        let url = try XCTUnwrap(URL(string: original))
        XCTAssertEqual(NetworkConnectionAddress.displayText(for: url), "https://media.invalid:8920/jellyfin")
        XCTAssertEqual(url.absoluteString, original)
        XCTAssertThrowsError(try MediaServiceEndpoint(url), "Display formatting must not make an unsafe endpoint usable")
    }

    func testDisplayAddressPreservesNetworkLocationAndEncodedPath() throws {
        for raw in ["http://nas.invalid:5005/video/%E7%94%B5%E5%BD%B1%20100%25/", "https://[2001:db8::1]:8920/base/", "https://media.invalid:443/subpath"] {
            let url = try XCTUnwrap(URL(string: raw))
            XCTAssertEqual(NetworkConnectionAddress.displayText(for: url), raw)
        }
        let encoded = try XCTUnwrap(URL(string: "https://media.invalid/base%2Fpart%3Fname%23value?token=fixture-only#fixture"))
        XCTAssertEqual(NetworkConnectionAddress.displayText(for: encoded), "https://media.invalid/base%2Fpart%3Fname%23value")
    }

    func candidate(_ product: MediaServiceProduct = .jellyfin, urls: [String] = ["https://example.test/jf"], saved: [String] = []) -> MediaServiceCandidate {
        .init(id: "one", name: product.title, hint: product, running: nil, endpoints: urls.map { URL(string: $0)! }, savedLoginEndpoints: saved.map { URL(string: $0)! })
    }
    func json(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object) }
    func testHintsNeverUsePortsOrBroadSubstringsAsProductProof() {
        XCTAssertEqual(MediaServiceProduct.hint(name: "service", detail: "linuxserver/jellyfin:latest"), .jellyfin)
        XCTAssertEqual(MediaServiceProduct.hint(name: "AudioStation"), .audioStation)
        XCTAssertEqual(MediaServiceProduct.hint(name: "music", detail: "ghcr.io/navidrome/navidrome:0.55"), .navidrome)
        XCTAssertNil(MediaServiceProduct.hint(name: "notjellyfin")); XCTAssertNil(MediaServiceProduct.hint(name: "video:8096"))
        XCTAssertNil(MediaServiceProduct.hint(name: "plexus"))
    }
    func testEndpointsRejectCredentialsQueriesFragmentsAndTraversal() throws {
        for text in ["https://a:b@example.test", "https://example.test/?token=private", "https://example.test/#secret", "ftp://example.test", "https://example.test/a/%252e%252e", "https://*.test/"] {
            XCTAssertThrowsError(try MediaServiceEndpoint(URL(string: text)!))
        }
        XCTAssertTrue(MediaServiceEndpoint.matches(URL(string: "https://EXAMPLE.test:443/jf")!, URL(string: "https://example.test/jf/")!))
        XCTAssertFalse(MediaServiceEndpoint.matches(URL(string: "https://a.test/a")!, URL(string: "https://a.test/b")!))
        XCTAssertEqual(try MediaServiceEndpoint(URL(string: "https://EXAMPLE.test:443/jf")!).url.absoluteString, "https://EXAMPLE.test:443/jf")
        XCTAssertFalse(MediaServiceEndpoint.matches(URL(string: "https://a.test/?token=x")!, URL(string: "https://a.test/?token=x")!))
    }
    func testPublicIdentityRequiresActualProductAndStableVideoServerID() throws {
        for value: [String: Any] in [["Id":"x","Version":"1"], ["Id":"x","Version":"1","ProductName":"Fake Jellyfin"], ["Id":"","Version":"1","ProductName":"Jellyfin Server"]] {
            XCTAssertNil(try MediaServiceIdentityParser.parse(json(value), family: .jellyfin))
        }
        let emby = try MediaServiceIdentityParser.parse(json(["Id":"server","Version":"4.9","ProductName":"Emby Server"]), family: .jellyfin)
        XCTAssertEqual(emby?.product, .emby)
        let jf = try MediaServiceIdentityParser.parse(json(["Id":"server","Version":"10.10","ProductName":"Jellyfin Server"]), family: .jellyfin)
        XCTAssertEqual(jf?.serverID, "server")
        XCTAssertNil(try MediaServiceIdentityParser.parse(Data("<html>login</html>".utf8), family: .jellyfin))
    }
    func testPlexIdentityRejectsEntitiesAndUnrelatedXML() throws {
        let value = try MediaServiceIdentityParser.parse(Data("<MediaContainer machineIdentifier=\"abc\" version=\"1.40\"/>".utf8), family: .plex)
        XCTAssertEqual(value?.product, .plex)
        XCTAssertNil(try MediaServiceIdentityParser.parse(Data("<html machineIdentifier=\"abc\" version=\"1\"/>".utf8), family: .plex))
        XCTAssertThrowsError(try MediaServiceIdentityParser.parse(Data("<!DOCTYPE MediaContainer [<!ENTITY a SYSTEM 'file:///etc/passwd'>]><MediaContainer machineIdentifier='abc' version='1'/>".utf8), family: .plex))
    }
    func testSubsonicProtocolErrorIsNotNavidromeProductProofOrAuthorization() throws {
        let protocolOnly = try MediaServiceIdentityParser.parse(json(["subsonic-response": ["status":"failed","version":"1.16.1","error":["code":10,"message":"required"]]]), family: .navidrome)
        XCTAssertEqual(protocolOnly?.product, .subsonic); XCTAssertNil(protocolOnly?.serverID)
        let navi = try MediaServiceIdentityParser.parse(json(["subsonic-response": ["status":"failed","version":"1.16.1","type":"navidrome","error":["code":40]]]), family: .subsonic)
        XCTAssertEqual(navi?.product, .navidrome)
        XCTAssertTrue(navi?.product.isMusic == true)
    }
    func testSavedSessionIsExactEndpointScopedAndIdentityConflictBlocksNativeEntry() throws {
        let source = candidate(saved: ["https://example.test/other"])
        XCTAssertFalse(source.hasSavedLogin)
        let saved = candidate(saved: ["https://example.test/jf/"])
        let offline = MediaServiceObservation(reachability: .unavailable)
        XCTAssertEqual(offline.nativeEndpoint(for: saved)?.url.absoluteString, "https://example.test/jf")
        let conflict = MediaServiceObservation(reachability: .reachable, identity: .init(product: .emby, serverID: "server"), endpoint: saved.endpoints[0])
        XCTAssertNil(conflict.nativeEndpoint(for: saved))
        XCTAssertNil(offline.nativeEndpoint(for: candidate(.plex, saved: ["https://example.test/jf"])))
        XCTAssertNil(offline.nativeEndpoint(for: candidate()))
    }
    func testCatalogKeepsInstancesPathsAndUnknownAddressesDistinct() {
        let a = candidate(), b = MediaServiceCandidate(id: "two", name: "same", hint: .jellyfin, running: true, endpoints: [URL(string:"https://example.test/other")!])
        XCTAssertEqual(MediaServiceCatalog.coalesced([a,b]).count, 2)
        let duplicate = MediaServiceCandidate(id: "three", name: "alias metadata", hint: .jellyfin, running: true, endpoints: [URL(string:"https://example.test/jf/")!])
        XCTAssertEqual(MediaServiceCatalog.coalesced([a,duplicate]).count, 1)
        let missing = MediaServiceCandidate(id:"missing",name:"same",hint:.audioStation,running:nil,endpoints:[])
        let missing2 = MediaServiceCandidate(id:"missing2",name:"same",hint:.audioStation,running:nil,endpoints:[])
        XCTAssertEqual(MediaServiceCatalog.coalesced([missing,missing2]).count, 2)
        let badID = MediaServiceCandidate(id:"one",name:"wrong",hint:.plex,running:nil,endpoints:[URL(string:"https://other.test")!])
        XCTAssertTrue(MediaServiceCatalog.coalesced([a,badID]).isEmpty)
    }
    func testOldRoundAndStoppedResultsNeverOverwriteNewAccount() {
        var ledger = MediaServiceResults(); let old = ledger.begin(), new = ledger.begin()
        XCTAssertFalse(ledger.accept(.init(reachability:.reachable),id:"old",round:old))
        XCTAssertTrue(ledger.accept(.init(reachability:.unavailable),id:"current",round:new))
        ledger.stop(); XCTAssertFalse(ledger.accept(.init(reachability:.reachable),id:"current",round:new))
        XCTAssertEqual(ledger.values["current"]?.reachability,.unavailable)
    }
    actor Peer: PublicMediaServiceTransport {
        var requests: [URLRequest] = []
        let replies: [PublicMediaServiceResponse]
        init(_ replies: [PublicMediaServiceResponse]) { self.replies = replies }
        func send(_ request: URLRequest) async throws -> PublicMediaServiceResponse {
            let index = requests.count; requests.append(request)
            return replies[min(index,replies.count-1)]
        }
    }
    func testProbeKeepsBasePathAndPublishesActualProductMismatchWithoutLogin() async throws {
        let body = try json(["Id":"server","Version":"4.9","ProductName":"Emby Server"])
        let peer = Peer([.init(statusCode:200,data:body)]), source = candidate(saved:["https://example.test/jf"])
        let result = try await MediaServiceProbe(transport:peer).inspect(source)
        XCTAssertTrue(result.conflicts(with:source)); XCTAssertNil(result.nativeEndpoint(for:source))
        let requests = await peer.requests
        XCTAssertEqual(requests.first?.url?.path,"/jf/System/Info/Public")
        XCTAssertNil(requests.first?.value(forHTTPHeaderField:"Authorization")); XCTAssertNil(requests.first?.value(forHTTPHeaderField:"Cookie"))
    }
    func testUnauthorizedAndHTMLNeverBecomeVerifiedIdentityOrAuthenticatedSession() async throws {
        for reply in [PublicMediaServiceResponse(statusCode:200,data:Data("<html>login</html>".utf8)), .init(statusCode:401,data:Data())] {
            let result = try await MediaServiceProbe(transport:Peer([reply])).inspect(candidate())
            XCTAssertNil(result.identity); XCTAssertNil(result.nativeEndpoint(for:candidate()))
            XCTAssertEqual(result.reachability,.reachable)
            XCTAssertEqual(result.requiresAuthorization,reply.statusCode==401)
        }
    }
    func testAudioStationAndStoppedServiceNeverProbeUnimplementedPaths() async throws {
        let peer = Peer([.init(statusCode:200,data:Data())]), probe = MediaServiceProbe(transport:peer)
        _ = try await probe.inspect(candidate(.audioStation))
        let stopped = MediaServiceCandidate(id:"off",name:"Jellyfin",hint:.jellyfin,running:false,endpoints:[URL(string:"https://example.test")!])
        _ = try await probe.inspect(stopped)
        let requests = await peer.requests; XCTAssertTrue(requests.isEmpty)
    }
    func testMusicPingContainsOnlyPublicProtocolParameters() async throws {
        let peer = Peer([.init(statusCode:401,data:Data())])
        _ = try await MediaServiceProbe(transport:peer).inspect(candidate(.navidrome))
        let request = await peer.requests[0], query = URLComponents(url:request.url!,resolvingAgainstBaseURL:false)!.queryItems!
        XCTAssertEqual(Set(query.map(\.name)),Set(["v","c","f"]))
        XCTAssertNil(request.httpBody)
    }
    func testTransportRejectsAnyCallerSuppliedCredentialsBeforeNetwork() async throws {
        for header in ["Cookie","Authorization","X-Emby-Token","X-Plex-Token"] {
            var request = URLRequest(url:URL(string:"https://example.test/System/Info/Public")!)
            request.httpMethod="GET";request.setValue("private",forHTTPHeaderField:header)
            do { _ = try await PublicMediaServiceHTTP().send(request); XCTFail() } catch { XCTAssertEqual(error as? NetworkMediaError,.invalidAddress) }
        }
    }
}

import XCTest
@testable import NetworkMedia

final class WebDAVConnectionFieldsTests: XCTestCase {
    func testProtocolPortAndLiteralPathRemainSeparate() throws {
        let scope = try WebDAVConnectionFields(scheme: .http, host: "nas.example.invalid", port: "5005", path: "/video/媒体 2026/100% done").scope()
        XCTAssertEqual(scope.baseURL.scheme, "http")
        XCTAssertEqual(scope.baseURL.port, 5005)
        XCTAssertEqual(URLComponents(url: scope.baseURL, resolvingAgainstBaseURL: false)?.percentEncodedPath.removingPercentEncoding, "/video/媒体 2026/100% done/")
        XCTAssertNil(scope.baseURL.query)
        XCTAssertNil(scope.baseURL.user)
    }
    func testHTTPSDefaultAndIPv6() throws {
        XCTAssertEqual(try WebDAVConnectionFields(host: "nas.example.invalid").scope().baseURL.scheme, "https")
        XCTAssertTrue(try WebDAVConnectionFields(host: "::1", port: "5006").scope().baseURL.absoluteString.contains("[::1]:5006"))
    }
    func testInvalidAuthorityPortAndTraversalAreRejected() {
        for host in ["https://nas.example.invalid", "nas.example.invalid:5006", "user@nas.example.invalid", "nas.example.invalid/video", "nas example.invalid"] {
            XCTAssertThrowsError(try WebDAVConnectionFields(host: host).scope())
        }
        for port in ["0", "65536", "-1", "5e3", "5006/video"] {
            XCTAssertThrowsError(try WebDAVConnectionFields(host: "nas.example.invalid", port: port).scope())
        }
        XCTAssertThrowsError(try WebDAVConnectionFields(host: "nas.example.invalid", path: "/video/../outside").scope())
    }
    func testPathStartsEmptyAndToleratesSlashSlips() throws {
        XCTAssertEqual(WebDAVConnectionFields().path, "")
        for typed in ["", "/", "//", "  /  "] {
            XCTAssertEqual(try WebDAVConnectionFields(scheme: .ftp, host: "nas.example", path: typed).scope().baseURL.path, "/", typed)
        }
        for typed in ["video/media", "/video/media", "//video/media", "/video//media", " /video/media "] {
            XCTAssertEqual(try WebDAVConnectionFields(scheme: .ftp, host: "nas.example", path: typed).scope().basePathDisplay, "video/media", typed)
        }
        XCTAssertEqual(try WebDAVConnectionFields(scheme: .ftp, host: "nas.example", path: "//电影 100%//").scope().basePathDisplay, "电影 100%")
    }
    func testFieldsRestoreAnyCaseOfValidScheme() throws {
        let https = try WebDAVConnectionFields(scope: WebDAVScope(address: "HTTPS://nas.example.invalid/dav/"))
        XCTAssertEqual(https.scheme, .https); XCTAssertEqual(https.host, "nas.example.invalid"); XCTAssertEqual(https.port, ""); XCTAssertEqual(https.path, "/dav")
        let http = try WebDAVConnectionFields(scope: WebDAVScope(address: "Http://nas.example.invalid:5005/video/"))
        XCTAssertEqual(http.scheme, .http); XCTAssertEqual(http.port, "5005"); XCTAssertEqual(http.path, "/video")
        let mixed = try WebDAVConnectionFields(scope: WebDAVScope(address: "hTtPs://nas.example.invalid/"))
        XCTAssertEqual(mixed.scheme, .https); XCTAssertEqual(mixed.path, "/")
    }
    func testUppercaseSchemeKeepsIPv6PercentAndChinesePathRoundTrip() throws {
        for address in ["HTTP://example.invalid:5005/video/%E7%94%B5%E5%BD%B1%20100%25/", "HTTPS://[2001:db8::1]:5443/Movies/"] {
            let scope = try WebDAVScope(address: address)
            let fields = try WebDAVConnectionFields(scope: scope)
            XCTAssertTrue(try fields.scope().isSameAddress(as: address), address)
        }
    }
    func testSameAddressIgnoresOnlySchemeCase() throws {
        let scope = try WebDAVScope(address: "https://nas.example.invalid/Video/")
        for saved in ["https://nas.example.invalid/Video/", "HTTPS://nas.example.invalid/Video/", "Https://nas.example.invalid/Video/"] {
            XCTAssertTrue(scope.isSameAddress(as: saved), saved)
        }
        for saved in ["http://nas.example.invalid/Video/",            // different scheme
                      "https://nas.example.invalid:8443/Video/",      // port
                      "https://nas.example.invalid/video/",           // path case
                      "https://other.example.invalid/Video/",         // host
                      "https://NAS.example.invalid/Video/",           // host case stays literal
                      "https://nas.example.invalid/Video",            // trailing slash stays literal
                      "https://nas.example.invalid/%56ideo/",         // encoding difference stays literal
                      "", "not an address", "ftp://nas.example.invalid/Video/", "HTTPS://user@nas.example.invalid/Video/"] {
            XCTAssertFalse(scope.isSameAddress(as: saved), saved)
        }
    }
}

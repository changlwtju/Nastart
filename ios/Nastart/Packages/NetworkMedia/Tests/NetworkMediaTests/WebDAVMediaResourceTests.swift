import XCTest
@testable import NetworkMedia

final class WebDAVMediaResourceTests: XCTestCase {
    func fixture(path: String = "Movies/中文 100%.mkv", size: Int64 = 4096, etag: String? = "\"v1\"",
                 modified: String? = nil) throws -> (NetworkLibrary, RemoteMediaEntry) {
        var library = NetworkLibrary(name: "local", scope: try WebDAVScope(address: "https://example.test/dav/"), root: try DAVPath("Movies"))
        let file = RemoteMediaEntry(path: try DAVPath(path), isDirectory: false, size: size, modified: modified, etag: etag)
        library.files = [file]; return (library, file)
    }
    func testCapabilityRequiresExactIndexedVideoAndSelectedRoot() throws {
        var (library, file) = try fixture()
        _ = try WebDAVMediaResource(library: library, file: file)
        let changed = RemoteMediaEntry(path: file.path, isDirectory: false, size: 8192, etag: file.etag)
        XCTAssertThrowsError(try WebDAVMediaResource(library: library, file: changed))
        library.files = []
        XCTAssertThrowsError(try WebDAVMediaResource(library: library, file: file))
        for path in ["Other/video.mkv", "Movies", "Movies/poster.jpg"] {
            let (other, member) = try fixture(path: path)
            XCTAssertThrowsError(try WebDAVMediaResource(library: other, file: member))
        }
        let nas = NetworkLibrary(name: "nas", scope: try WebDAVScope(address: library.address), root: library.root, fileStationAccount: "account")
        XCTAssertThrowsError(try WebDAVMediaResource(library: nas, file: file)) {
            XCTAssertEqual($0 as? NetworkMediaPlaybackError, .unsupportedSource)
        }
    }
    func testFiniteRangesPreserveLiteralPathAndRejectOverflowAndBudget() throws {
        let (library, file) = try fixture(size: Int64.max)
        let resource = try WebDAVMediaResource(library: library, file: file)
        let first = try resource.request(offset: 0, count: 4)
        XCTAssertEqual(first.httpMethod, "GET"); XCTAssertNil(first.httpBody)
        XCTAssertEqual(first.url?.absoluteString, "https://example.test/dav/Movies/%E4%B8%AD%E6%96%87%20100%25.mkv")
        XCTAssertEqual(first.value(forHTTPHeaderField: "Range"), "bytes=0-3")
        XCTAssertEqual(first.value(forHTTPHeaderField: "If-Match"), "\"v1\"")
        XCTAssertEqual(first.value(forHTTPHeaderField: "Accept-Encoding"), "identity")
        XCTAssertNil(first.value(forHTTPHeaderField: "Authorization"))
        let tail = try resource.request(offset: Int64.max - 1, count: 1)
        XCTAssertEqual(tail.value(forHTTPHeaderField: "Range"), "bytes=9223372036854775806-9223372036854775806")
        for (offset, count) in [(Int64(-1), 1), (0, 0), (0, -1), (0, WebDAVMediaResource.maximumReadBytes + 1), (Int64.max, 1), (Int64.max - 1, 2)] {
            XCTAssertThrowsError(try resource.request(offset: offset, count: count))
        }
    }
    func testVersionMustBeStrongETagOrExactHTTPDate() throws {
        for etag in [nil, "W/\"weak\"", "unquoted", "\"bad\r\ntag\"", "\"internal\"quote\""] as [String?] {
            let (library, file) = try fixture(etag: etag)
            XCTAssertThrowsError(try WebDAVMediaResource(library: library, file: file)) {
                XCTAssertEqual($0 as? NetworkMediaPlaybackError, .versionUnavailable)
            }
        }
        for modified in ["garbage", "1780000000", "Mon, 27 Oct 2026 00:00:00 GMT", "Tue, 27 Oct 2026 00:00:00 GMT\r\nX: y"] {
            let (library, file) = try fixture(etag: nil, modified: modified)
            XCTAssertThrowsError(try WebDAVMediaResource(library: library, file: file))
        }
        let date = "Tue, 27 Oct 2026 00:00:00 GMT"
        let (library, file) = try fixture(etag: "W/\"weak\"", modified: date)
        let resource = try WebDAVMediaResource(library: library, file: file)
        let request = try resource.request(offset: 0, count: 16)
        XCTAssertNil(request.value(forHTTPHeaderField: "If-Match"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "If-Unmodified-Since"), date)
        let response = HTTPURLResponse(url: request.url!, statusCode: 206, httpVersion: "HTTP/1.1", headerFields: ["Content-Range": "bytes 0-15/4096", "Last-Modified": date])!
        XCTAssertNoThrow(try resource.validate(response, offset: 0, count: 16))
    }
    func testResponseMustMatchExactURLRangeSizeVersionAndRepresentation() throws {
        let (library, file) = try fixture(), resource = try WebDAVMediaResource(library: library, file: file)
        let request = try resource.request(offset: 4, count: 4)
        let good = ["Content-Range": "bytes 4-7/4096", "Content-Length": "4", "ETag": "\"v1\"", "Content-Type": "video/x-matroska"]
        func response(_ headers: [String: String], url: URL? = nil, status: Int = 206) -> HTTPURLResponse {
            HTTPURLResponse(url: url ?? request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        }
        XCTAssertNoThrow(try resource.validate(response(good), offset: 4, count: 4))
        for (key, value) in [("Content-Range", "bytes 0-3/4096"), ("Content-Range", "bytes 4-7/*"), ("Content-Range", "bytes 4-7/8192"),
                             ("Content-Length", "5"), ("Content-Length", "4, 4"), ("Content-Encoding", "gzip"),
                             ("Content-Type", "multipart/byteranges"), ("Content-Type", "text/html; charset=utf-8"), ("Content-Type", "application/json"),
                             ("ETag", "\"v2\""), ("ETag", "W/\"v1\"")] {
            var headers = good; headers[key] = value
            XCTAssertThrowsError(try resource.validate(response(headers), offset: 4, count: 4))
        }
        var missing = good; missing.removeValue(forKey: "ETag")
        XCTAssertThrowsError(try resource.validate(response(missing), offset: 4, count: 4))
        XCTAssertThrowsError(try resource.validate(response(good, url: URL(string: "https://other.test/video.mkv")!), offset: 4, count: 4))
        XCTAssertThrowsError(try resource.validate(response(good, status: 200), offset: 4, count: 4))
    }
}

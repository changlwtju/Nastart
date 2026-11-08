#if canImport(Network)
import XCTest
@testable import NetworkMedia

final class MediaLocalHTTPRequestTests: XCTestCase {
    func testSingleRangeSuffixAndOpenRangesHaveSafeExactBoundaries() throws {
        func parse(_ range: String?) throws -> MediaLocalHTTPRequest {
            try MediaLocalHTTPRequest(Data(("GET /owned/video.mkv HTTP/1.1\r\nHost: 127.0.0.1:1234\r\n" + (range.map { "Range: \($0)\r\n" } ?? "") + "\r\n").utf8), target: "/owned/video.mkv", port: 1234, total: Int64.max)
        }
        let all = try parse(nil); XCTAssertEqual(all.start, 0); XCTAssertEqual(all.end, Int64.max - 1); XCTAssertFalse(all.partial)
        let tail = try parse("bytes=-2"); XCTAssertEqual(tail.start, Int64.max - 2); XCTAssertEqual(tail.end, Int64.max - 1)
        let open = try parse("bytes=9223372036854775806-"); XCTAssertEqual(open.start, open.end)
        let clamp = try parse("bytes=10-9223372036854775807"); XCTAssertEqual(clamp.end, Int64.max - 1)
        for value in ["bytes=-0", "bytes=1-0", "bytes=0-1,2-3", "bytes=9223372036854775808-", "bytes=1--2", "bytes=+1-2", "bytes=0-2\r\nRange: bytes=2-3"] {
            XCTAssertThrowsError(try parse(value))
        }
    }
    func testMalformedForeignDuplicateOrBodyBearingRequestsAreRejected() throws {
        for text in [
            "GET /foreign/video.mkv HTTP/1.1\r\nHost: 127.0.0.1:1234\r\n\r\n",
            "GET /owned/video.mkv HTTP/1.1\r\nHost: other:1234\r\n\r\n",
            "GET /owned/video.mkv HTTP/1.1\r\nHost: 127.0.0.1:1234\r\nhost: 127.0.0.1:1234\r\n\r\n",
            "GET /owned/video.mkv HTTP/1.1\r\nHost: 127.0.0.1:1234\r\nTransfer-Encoding: chunked\r\n\r\n",
            "GET /owned/video.mkv HTTP/1.1\r\nHost: 127.0.0.1:1234\r\nContent-Length: 1\r\n\r\nx",
            "GET /owned/video.mkv HTTP/1.1\r\nHost: 127.0.0.1:1234\r\n Folded: bad\r\n\r\n",
            "GET /owned/video.mkv HTTP/1.1\nHost: 127.0.0.1:1234\n\n"
        ] {
            XCTAssertThrowsError(try MediaLocalHTTPRequest(Data(text.utf8), target: "/owned/video.mkv", port: 1234, total: 100))
        }
    }
}
#endif

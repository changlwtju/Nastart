import XCTest
@testable import NetworkMedia

final class FTPPathTests: XCTestCase {
    func testLiteralNamesAreNotDecodedOrTrimmed() throws {
        let text = "/video/中文 空格/100% done/%2F/%2e%2e/a?#;\" / trailing "
        let path = try FTPPath(text)
        XCTAssertEqual(Data(path.commandArgument.utf8), Data(text.utf8))
        XCTAssertEqual(path.components[3], "%2F")
        XCTAssertEqual(path.components[4], "%2e%2e")
        XCTAssertNotEqual(try FTPPath("/video/%2F"), try FTPPath("/video/%252F"))
    }

    func testRootTrailingSlashAndParent() throws {
        let root = try FTPPath()
        XCTAssertEqual(root.commandArgument, "/")
        XCTAssertNil(root.parent)
        let folder = try FTPPath("/video/media/")
        XCTAssertEqual(folder, try FTPPath("/video/media"))
        XCTAssertEqual(folder.parent, try FTPPath("/video"))
        XCTAssertEqual(try FTPPath("/video").parent, root)
    }

    func testScopeUsesWholeCaseSensitiveComponents() throws {
        let root = try FTPPath("/video/media")
        XCTAssertTrue(root.contains(root))
        XCTAssertTrue(root.contains(try root.appending(name: "movie.nfo")))
        for path in ["/video/mediabox/movie.nfo", "/video/Media/movie.nfo", "/video/media%2Fmovie.nfo", "/video", "/other/media/movie.nfo"] {
            XCTAssertFalse(root.contains(try FTPPath(path)), path)
        }
        XCTAssertTrue(try FTPPath().contains(root))
    }

    func testUnicodeByteIdentityDoesNotMergeDifferentServerNames() throws {
        let composed = try FTPPath("/video/\u{e9}.nfo")
        let decomposed = try FTPPath("/video/e\u{301}.nfo")
        XCTAssertNotEqual(composed, decomposed)
        XCTAssertNotEqual(composed.key, decomposed.key)
        XCTAssertEqual(Set([composed, decomposed]).count, 2)
        XCTAssertFalse(composed.contains(decomposed))
        for path in [composed, decomposed] {
            let restored = try JSONDecoder().decode(FTPPath.self, from: JSONEncoder().encode(path))
            XCTAssertEqual(Data(restored.commandArgument.utf8), Data(path.commandArgument.utf8))
        }
    }

    func testTraversalSeparatorsAndCommandInjectionAreRejected() throws {
        for path in ["video", "", "//", "//video", "/video//media", "/video/.", "/video/../other", "/video/a\\b", "/video/a\r\nDELE other", "/video/a\0b", "/video/a\u{7f}b"] {
            XCTAssertThrowsError(try FTPPath(path), path)
        }
        for name in ["", ".", "..", "a/b", "/absolute", "a\\b", "a\r\nRETR other", "a\0b"] {
            XCTAssertThrowsError(try FTPPath("/video").appending(name: name), name)
        }
    }

    func testDepthAndUTF8ByteLimitsApplyToAppendsAndDecoding() throws {
        let deepest = "/" + Array(repeating: "a", count: FTPPath.maximumDepth).joined(separator: "/")
        XCTAssertEqual(try FTPPath(deepest).components.count, FTPPath.maximumDepth)
        XCTAssertThrowsError(try FTPPath(deepest).appending(name: "a"))
        let largest = "/" + String(repeating: "a", count: FTPPath.maximumUTF8Bytes - 1)
        XCTAssertEqual(try FTPPath(largest).commandArgument.utf8.count, FTPPath.maximumUTF8Bytes)
        XCTAssertThrowsError(try FTPPath(largest + "a"))
        XCTAssertThrowsError(try FTPPath("/" + String(repeating: "中", count: FTPPath.maximumUTF8Bytes / 3 + 1)))
        for components in [[".."], ["a/b"], [""], ["a\nQUIT"], Array(repeating: "a", count: FTPPath.maximumDepth + 1), [String(largest.dropFirst()) + "a"]] {
            let bytes = try JSONSerialization.data(withJSONObject: ["components": components])
            XCTAssertThrowsError(try JSONDecoder().decode(FTPPath.self, from: bytes))
        }
    }
}

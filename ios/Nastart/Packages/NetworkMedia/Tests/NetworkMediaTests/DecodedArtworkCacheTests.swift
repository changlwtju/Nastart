import XCTest
@testable import NetworkMedia
#if canImport(CoreGraphics)
import CoreGraphics

final class DecodedArtworkCacheTests: XCTestCase {
    private func image(_ width: Int = 2) throws -> CGImage {
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: 2,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: 2))
        return try XCTUnwrap(context.makeImage())
    }
    func testCurrentVersionRendersSynchronouslyButOtherVersionsAndLibrariesMiss() throws {
        let cache = DecodedArtworkCache(), pixels = try image()
        cache.insert(pixels, for: "library-a-poster-v1")
        XCTAssertTrue(cache.image(for: "library-a-poster-v1") === pixels)
        XCTAssertNil(cache.image(for: "library-a-poster-v2"))
        XCTAssertNil(cache.image(for: "library-b-poster-v1"))
        cache.removeAll(); XCTAssertNil(cache.image(for: "library-a-poster-v1"))
    }
    func testReturningToRecentPosterProtectsItFromLRUEviction() throws {
        let pixels = try image(), cost = pixels.bytesPerRow * pixels.height
        let cache = DecodedArtworkCache(maximumBytes: cost * 2, maximumCount: 3)
        cache.insert(pixels, for: "first"); cache.insert(pixels, for: "second")
        XCTAssertNotNil(cache.image(for: "first"))
        cache.insert(pixels, for: "third")
        XCTAssertNotNil(cache.image(for: "first")); XCTAssertNil(cache.image(for: "second"))
        XCTAssertNotNil(cache.image(for: "third"))
    }
    func testReplacementUpdatesCostAndOversizedImagesAreNotAdmitted() throws {
        let small = try image(), large = try image(4)
        let cost = large.bytesPerRow * large.height
        let cache = DecodedArtworkCache(maximumBytes: cost, maximumCount: 4)
        cache.insert(small, for: "same"); cache.insert(large, for: "same")
        XCTAssertTrue(cache.image(for: "same") === large)
        cache.insert(small, for: "next")
        XCTAssertNil(cache.image(for: "same")); XCTAssertNotNil(cache.image(for: "next"))
        cache.insert(try image(100), for: "oversized")
        XCTAssertNil(cache.image(for: "oversized")); XCTAssertNotNil(cache.image(for: "next"))
    }
    func testEntryLimitBoundsManyTinyThumbnails() throws {
        let pixels = try image(), cache = DecodedArtworkCache(maximumBytes: 1024 * 1024, maximumCount: 2)
        for key in ["one", "two", "three"] { cache.insert(pixels, for: key) }
        XCTAssertNil(cache.image(for: "one")); XCTAssertNotNil(cache.image(for: "two"))
        XCTAssertNotNil(cache.image(for: "three"))
    }
}
#endif

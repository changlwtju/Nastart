import XCTest
@testable import NetworkMedia

final class MediaPosterGridLayoutTests: XCTestCase {
    func testSameTerminalLibraryDensityAndTabletContentCap() {
        XCTAssertEqual(MediaPosterGridLayout.mobile(viewportWidth: 390, compact: true).columns, 3)
        XCTAssertEqual(MediaPosterGridLayout.mobile(viewportWidth: 402, compact: true).columns, 3)
        XCTAssertEqual(MediaPosterGridLayout.mobile(viewportWidth: 1180, compact: false).columns, 5)
        XCTAssertEqual(MediaPosterGridLayout.mobile(viewportWidth: 820, compact: false).columns, 4)
        XCTAssertEqual(MediaPosterGridLayout.mobile(viewportWidth: 1366, compact: false).contentWidth, 960)
        for density in 3...5 { XCTAssertEqual(MediaPosterGridLayout.television(viewportWidth: 1920, density: density).columns, density) }
        XCTAssertEqual(MediaPosterGridLayout.television(viewportWidth: 1920, density: 9).columns, 4)
    }
    func testEveryCompleteRowFitsSplitViewAndLargeTypeWithoutNegativeWidths() {
        for width in [CGFloat(0), 220, 280, 320, 375, 390, 600, 820, 1180, 1920] {
            for compact in [true, false] {
                for accessibility in [true, false] {
                    let layout = MediaPosterGridLayout.mobile(viewportWidth: width, compact: compact, accessibility: accessibility)
                    XCTAssertGreaterThanOrEqual(layout.columns, 1)
                    XCTAssertEqual(CGFloat(layout.columns) * layout.itemWidth + CGFloat(layout.columns - 1) * layout.horizontalSpacing, layout.contentWidth, accuracy: 0.001)
                    if accessibility && width == 390 { XCTAssertEqual(layout.columns, 1) }
                }
            }
        }
        XCTAssertTrue(MediaPosterGridLayout.mobile(viewportWidth: .infinity, compact: true).itemWidth.isFinite)
        XCTAssertTrue(MediaPosterGridLayout.television(viewportWidth: .nan).itemWidth.isFinite)
    }
}

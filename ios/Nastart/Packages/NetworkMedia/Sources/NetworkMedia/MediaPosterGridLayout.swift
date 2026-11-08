import Foundation

/// One grid contract for Jellyfin and indexed network libraries. Width is the
/// actual page viewport (including split view), not the physical device screen.
public struct MediaPosterGridLayout: Equatable, Sendable {
    public static let televisionDensityPreference = "tv.library.posterDensity"
    public static let defaultTelevisionDensity = 4
    public static let posterAspectRatio: CGFloat = 2.0 / 3.0
    public let contentWidth: CGFloat
    public let columns: Int
    public let horizontalSpacing: CGFloat
    public let verticalSpacing: CGFloat
    public var itemWidth: CGFloat { max(1, (contentWidth - CGFloat(columns - 1) * horizontalSpacing) / CGFloat(columns)) }

    public static func mobile(viewportWidth: CGFloat, compact: Bool, accessibility: Bool = false) -> Self {
        let width = viewportWidth.isFinite ? max(0, viewportWidth) : 0
        let gap: CGFloat = compact ? 10 : 14
        let content = max(1, min(960, width - (compact ? 24 : 36)))
        let columns: Int
        if accessibility { columns = max(1, Int((content + gap) / (280 + gap))) }
        else if compact { columns = min(3, max(1, Int((content + gap) / (96 + gap)))) }
        else { columns = max(1, Int((content + gap) / (150 + gap))) }
        return .init(contentWidth: content, columns: columns, horizontalSpacing: gap, verticalSpacing: compact ? 18 : 20)
    }

    public static func television(viewportWidth: CGFloat, density: Int = defaultTelevisionDensity, accessibility: Bool = false) -> Self {
        let width = viewportWidth.isFinite ? max(0, viewportWidth) : 0
        let content = max(1, width - 140), gap: CGFloat = 38
        let requested = (3...5).contains(density) ? density : defaultTelevisionDensity
        let fitting = max(1, Int((content + gap) / ((accessibility ? 420 : 200) + gap)))
        return .init(contentWidth: content, columns: min(requested, fitting), horizontalSpacing: gap, verticalSpacing: 30)
    }
}

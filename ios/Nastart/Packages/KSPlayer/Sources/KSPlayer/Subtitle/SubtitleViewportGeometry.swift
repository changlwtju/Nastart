import CoreGraphics

/// Shared screen/video and authored-canvas geometry. Server-burned subtitles
/// remain part of the video pixels.
public enum SubtitleViewportGeometry {
    public static func videoRect(viewport: CGSize, video: CGSize, fillsScreen: Bool = false) -> CGRect? {
        videoFrame(viewport: viewport, video: video, fillsScreen: fillsScreen)?
            .intersection(CGRect(origin: .zero, size: viewport))
    }

    /// Keep the uncropped frame for authored coordinates when aspect-fill clips
    /// the video. Mapping into only its visible intersection changes the scale.
    public static func videoFrame(viewport: CGSize, video: CGSize, fillsScreen: Bool = false) -> CGRect? {
        guard [viewport.width, viewport.height, video.width, video.height]
            .allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        let scale = fillsScreen ? max(viewport.width / video.width, viewport.height / video.height)
            : min(viewport.width / video.width, viewport.height / video.height)
        let size = CGSize(width: video.width * scale, height: video.height * scale)
        guard size.width.isFinite, size.height.isFinite else { return nil }
        let frame = CGRect(x: (viewport.width - size.width) / 2,
                           y: (viewport.height - size.height) / 2,
                           width: size.width, height: size.height)
        return frame
    }

    public static func imageRect(origin: CGPoint, image: CGSize, canvas: CGSize,
                                 videoFrame: CGRect) -> CGRect? {
        guard [origin.x, origin.y, videoFrame.minX, videoFrame.minY].allSatisfy(\.isFinite),
              [image.width, image.height, canvas.width, canvas.height,
               videoFrame.width, videoFrame.height].allSatisfy({ $0.isFinite && $0 > 0 }) else { return nil }
        let xScale = videoFrame.width / canvas.width
        let yScale = videoFrame.height / canvas.height
        let rect = CGRect(x: videoFrame.minX + origin.x * xScale,
                          y: videoFrame.minY + origin.y * yScale,
                          width: image.width * xScale, height: image.height * yScale)
        return [rect.minX, rect.minY, rect.width, rect.height].allSatisfy(\.isFinite) ? rect : nil
    }

    public static func bottomInset(viewport: CGSize, videoRect: CGRect,
                                   screenBottomInset: CGFloat, minimum: CGFloat = 12) -> CGFloat {
        let inset = screenBottomInset.isFinite ? max(0, screenBottomInset) : 0
        return max(minimum, inset - max(0, viewport.height - videoRect.maxY))
    }

    /// Callers choose display-specific typography; these defaults preserve the
    /// mobile caption scale, rather than imposing phone point sizes on a TV.
    public static func textPointSize(videoRect: CGRect) -> CGFloat {
        guard videoRect.height.isFinite, videoRect.height > 0 else { return 12 }
        return min(20, max(12, videoRect.height * 0.06))
    }
}

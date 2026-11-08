//
//  EmbedDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
import Libavcodec
import Libavutil

/// One already displayed bitmap, retained only for a return to the exact
/// paused position. This never extends a cue to a different timestamp.
final class PausedImageSubtitleDisplayCache {
    private let lock = NSLock()
    private var part: SubtitlePart?
    private var time: TimeInterval?
    private var token: String?
    private var replaying = false

    func remember(_ part: SubtitlePart, at time: TimeInterval, token: String) {
        lock.lock()
        defer { lock.unlock() }
        clearLocked()
        guard time.isFinite, part.image != nil, part == time else { return }
        self.part = part
        self.time = time
        self.token = token
    }

    func restore(at time: TimeInterval, token: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard time.isFinite, self.time == time, self.token == token,
              let part, part == time else {
            clearLocked()
            return false
        }
        replaying = true
        return true
    }

    func restoredPart(at time: TimeInterval) -> SubtitlePart? {
        lock.lock()
        defer { lock.unlock() }
        guard replaying else { return nil }
        guard self.time == time, let part, part == time else {
            clearLocked()
            return nil
        }
        return part
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        clearLocked()
    }

    private func clearLocked() {
        part = nil
        time = nil
        token = nil
        replaying = false
    }
}

extension FFmpegAssetTrack: SubtitleInfo {
    public var subtitleID: String {
        String(trackID)
    }
}

extension FFmpegAssetTrack {
    public func rememberPausedImageSubtitle(_ part: SubtitlePart, at time: TimeInterval, token: String) {
        guard isImageSubtitle else { return }
        pausedImageSubtitleDisplay.remember(part, at: time, token: token)
    }

    public func restorePausedImageSubtitle(at time: TimeInterval, token: String) -> Bool {
        isImageSubtitle && pausedImageSubtitleDisplay.restore(at: time, token: token)
    }

    public func invalidatePausedImageSubtitle() {
        pausedImageSubtitleDisplay.clear()
    }
}

extension SubtitleModel {
    /// Capture before either an embedded track change or an external subtitle
    /// clears the selected provider. The caller must establish paused playback.
    @MainActor
    public func rememberPausedImageSubtitle(currentTime: TimeInterval, token: String) {
        guard let track = selectedSubtitleInfo as? FFmpegAssetTrack, track.isImageSubtitle else { return }
        let time = currentTime - track.delay - subtitleDelay
        if let part = parts.last(where: { $0.image != nil && $0 == time }) {
            track.rememberPausedImageSubtitle(part, at: time, token: token)
        }
    }
}

extension FFmpegAssetTrack: KSSubtitleProtocol {
    public func search(for time: TimeInterval) -> [SubtitlePart] {
        if isImageSubtitle {
            guard let frame = subtitle?.outputRenderQueue.popLatest(where: { $0.part.start <= time }) else {
                return pausedImageSubtitleDisplay.restoredPart(at: time).map { [$0] } ?? []
            }
            // A newly decoded display set, including a clear set, supersedes
            // the retained image immediately.
            pausedImageSubtitleDisplay.clear()
            // An expired display set must clear the previously displayed image,
            // rather than making SubtitleModel keep an old infinite-duration cue.
            return [frame.part == time ? frame.part : SubtitlePart(time, .infinity, attributedString: nil)]
        }
        return subtitle?.outputRenderQueue.search { item -> Bool in
            item.part == time
        }.map(\.part) ?? []
    }
}

extension KSMEPlayer: SubtitleDataSouce {
    public var infos: [any SubtitleInfo] {
        tracks(mediaType: .subtitle).compactMap { $0 as? (any SubtitleInfo) }
    }
}

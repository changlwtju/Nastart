//
//  EmbedDataSouce.swift
//  KSPlayer-7de52535
//
//  Created by kintan on 2018/8/7.
//
import Foundation
import Libavcodec
import Libavutil

extension FFmpegAssetTrack: SubtitleInfo {
    public var subtitleID: String {
        String(trackID)
    }
}

extension FFmpegAssetTrack: KSSubtitleProtocol {
    public func search(for time: TimeInterval) -> [SubtitlePart] {
        if isImageSubtitle {
            guard let frame = subtitle?.outputRenderQueue.popLatest(where: { $0.part.start <= time }) else { return [] }
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

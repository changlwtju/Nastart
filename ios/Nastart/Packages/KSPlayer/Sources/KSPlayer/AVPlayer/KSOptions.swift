//
//  KSOptions.swift
//  KSPlayer-tvOS
//
//  Created by kintan on 2018/3/9.
//

import AVFoundation
#if os(tvOS) || os(xrOS)
import DisplayCriteria
#endif
import OSLog

#if canImport(UIKit)
import UIKit
#endif
/// Facts captured from the same decoded frame before the PiP transform runs.
/// VideoToolbox does not expose AVFrame side data; its absence is not "none".
public struct KSPictureInPictureFrameContext {
    public let isDolbyVision: Bool
    public let dolbyConfiguration: DOVIDecoderConfigurationRecord?
    public let masteringDisplayData: Data?
    public let masteringMaximumNits: Double?
    public let hasStaticEDR: Bool
    public let sideDataInspection: String
    public let sideDataSizes: [String: Int]
    public let compressedFormatDescription: CMFormatDescription?
    public let displayFormatDescription: CMVideoFormatDescription

    public init(isDolbyVision: Bool, dolbyConfiguration: DOVIDecoderConfigurationRecord? = nil,
                masteringDisplayData: Data? = nil, masteringMaximumNits: Double? = nil,
                hasStaticEDR: Bool, sideDataInspection: String,
                sideDataSizes: [String: Int], compressedFormatDescription: CMFormatDescription?,
                displayFormatDescription: CMVideoFormatDescription) {
        self.isDolbyVision = isDolbyVision
        self.dolbyConfiguration = dolbyConfiguration
        self.masteringDisplayData = masteringDisplayData
        self.masteringMaximumNits = masteringMaximumNits
        self.hasStaticEDR = hasStaticEDR
        self.sideDataInspection = sideDataInspection
        self.sideDataSizes = sideDataSizes
        self.compressedFormatDescription = compressedFormatDescription
        self.displayFormatDescription = displayFormatDescription
    }
}

open class KSOptions {
    #if DEBUG
    /// Optional UI interaction trace. No URL, account or media identifiers.
    public var viewInteractionObserved: ((String, [String: String]) -> Void)?
    #endif
    /// Renderer attempt callback; does not by itself prove output API submission.
    public var pictureInPictureFrameTransform: ((CVPixelBuffer, TimeInterval) -> CVPixelBuffer?)?
    /// Preferred contextual transform. A nil result preserves the original frame;
    /// it never falls through to a legacy transform after rejecting a frame.
    public var pictureInPictureFrameTransformWithContext:
        ((CVPixelBuffer, TimeInterval, KSPictureInPictureFrameContext) -> CVPixelBuffer?)?
    /// Observation after a system PiP playback command has reached this player.
    /// Values are captured synchronously; consumers marshal their own UI work.
    public var pictureInPicturePlaybackChanged: ((Bool, Bool, TimeInterval, TimeInterval) -> Void)?
    public var videoFrameSubmitted: ((TimeInterval, Bool) -> Void)?
    /// A forced preview accepted by the output API, rather than only attempted.
    public var pausedSeekPreviewSubmitted: ((TimeInterval) -> Void)?
    public let videoStartupTiming = KSVideoStartupTiming()
    /// Reports the video decoder actually selected, including fallback.
    public var videoDecoderSelected: ((String) -> Void)?
    /// Called after an embedded subtitle display set enters its render queue.
    /// The decoder queue invokes this; consumers must marshal UI work themselves.
    public var embeddedSubtitleFrameDecoded: ((Int32) -> Void)?
    /// 最低缓存视频时间
    @Published
    public var preferredForwardBufferDuration = KSOptions.preferredForwardBufferDuration
    /// 最大缓存视频时间
    public var maxBufferDuration = KSOptions.maxBufferDuration
    /// 是否开启秒开
    public var isSecondOpen = KSOptions.isSecondOpen
    /// 开启精确seek
    public var isAccurateSeek = KSOptions.isAccurateSeek
    /// Seekable disc-image TS proxies support timestamp seeks despite TS_DISCONT.
    public var prefersTimestampSeeking = false
    /// Applies to short videos only
    public var isLoopPlay = KSOptions.isLoopPlay
    /// seek完是否自动播放
    public var isSeekedAutoPlay = KSOptions.isSeekedAutoPlay
    /*
     AVSEEK_FLAG_BACKWARD: 1
     AVSEEK_FLAG_BYTE: 2
     AVSEEK_FLAG_ANY: 4
     AVSEEK_FLAG_FRAME: 8
     */
    public var seekFlags = Int32(1)
    // ffmpeg only cache http
    // 这个开关不能用，因为ff_tempfile: Cannot open temporary file
    public var cache = false
    //  record stream
    public var outputURL: URL?
    public var avOptions = [String: Any]()
    public var formatContextOptions = [String: Any]()
    public var decoderOptions = [String: Any]()
    public var forcedInputFormatName: String?
    public var probesize: Int64?
    public var maxAnalyzeDuration: Int64?
    public var lowres = UInt8(0)
    public var nobuffer = false
    public var codecLowDelay = false
    public var startPlayTime: TimeInterval = 0
    public var startPlayRate: Float = 1.0
    public var registerRemoteControll: Bool = true // 默认支持来自系统控制中心的控制
    public var referer: String? {
        didSet {
            if let referer {
                formatContextOptions["referer"] = "Referer: \(referer)"
            } else {
                formatContextOptions["referer"] = nil
            }
        }
    }

    public var userAgent: String? = "KSPlayer" {
        didSet {
            formatContextOptions["user_agent"] = userAgent
        }
    }

    // audio
    public var audioFilters = [String]()
    public var syncDecodeAudio = false
    // sutile
    public var autoSelectEmbedSubtitle = true
    public var isSeekImageSubtitle = false
    /// Select the requested embedded stream before reading packets, so bitmap
    /// cues near the initial position are not discarded until the UI is ready.
    public var preferredEmbeddedSubtitleTrackID: Int32?
    // video
    public var display = DisplayEnum.plane
    public var videoDelay = 0.0 // s
    public var autoDeInterlace = false
    public var autoRotate = true
    public var destinationDynamicRange: DynamicRange?
    public var videoAdaptable = true
    public var videoFilters = [String]()
    public var syncDecodeVideo = false
    public var hardwareDecode = KSOptions.hardwareDecode
    public var asynchronousDecompression = KSOptions.asynchronousDecompression
    public var videoDisable = false
    public var canStartPictureInPictureAutomaticallyFromInline = KSOptions.canStartPictureInPictureAutomaticallyFromInline
    public var automaticWindowResize = true
    @Published
    public var videoInterlacingType: VideoInterlacingType?
    private var videoClockDelayCount = 0

    public internal(set) var formatName = ""
    public internal(set) var prepareTime = 0.0
    public internal(set) var dnsStartTime = 0.0
    public internal(set) var tcpStartTime = 0.0
    public internal(set) var tcpConnectedTime = 0.0
    public internal(set) var openTime = 0.0
    public internal(set) var findTime = 0.0
    public internal(set) var readyTime = 0.0
    public internal(set) var initialSeekStartTime = 0.0
    public internal(set) var initialSeekEndTime = 0.0
    public internal(set) var initialSeekResult: Int32?
    public internal(set) var readAudioTime = 0.0
    public internal(set) var readVideoTime = 0.0
    public internal(set) var decodeAudioTime = 0.0
    public internal(set) var decodeVideoTime = 0.0
    public init() {
        formatContextOptions["user_agent"] = userAgent
        // 参数的配置可以参考protocols.texi 和 http.c
        // 这个一定要，不然有的流就会判断不准FieldOrder
        formatContextOptions["scan_all_pmts"] = 1
        // ts直播流需要加这个才能一直直播下去，不然播放一小段就会结束了。
        formatContextOptions["reconnect"] = 1
        formatContextOptions["reconnect_streamed"] = 1
        // 这个是用来开启http的链接复用（keep-alive）。vlc默认是打开的，所以这边也默认打开。
        // 开启这个，百度网盘的视频链接无法播放
        // formatContextOptions["multiple_requests"] = 1
        // 下面是用来处理秒开的参数，有需要的自己打开。默认不开，不然在播放某些特殊的ts直播流会频繁卡顿。
//        formatContextOptions["auto_convert"] = 0
//        formatContextOptions["fps_probe_size"] = 3
//        formatContextOptions["rw_timeout"] = 10_000_000
//        formatContextOptions["max_analyze_duration"] = 300 * 1000
        // 默认情况下允许所有协议，只有嵌套协议才需要指定这个协议子集，例如m3u8里面有http。
//        formatContextOptions["protocol_whitelist"] = "file,http,https,tcp,tls,crypto,async,cache,data,httpproxy"
        // 开启这个，纯ipv6地址会无法播放。并且有些视频结束了，但还会一直尝试重连。所以这个值默认不设置
//        formatContextOptions["reconnect_at_eof"] = 1
        // 开启这个，会导致tcp Failed to resolve hostname 还会一直重试
//        formatContextOptions["reconnect_on_network_error"] = 1
        // There is total different meaning for 'listen_timeout' option in rtmp
        // set 'listen_timeout' = -1 for rtmp、rtsp
//        formatContextOptions["listen_timeout"] = 3
        decoderOptions["threads"] = "auto"
        decoderOptions["refcounted_frames"] = "1"
    }

    /**
     you can add http-header or other options which mentions in https://developer.apple.com/reference/avfoundation/avurlasset/initialization_options

     to add http-header init options like this
     ```
     options.appendHeader(["Referer":"https:www.xxx.com"])
     ```
     */
    public func appendHeader(_ header: [String: String]) {
        var oldValue = avOptions["AVURLAssetHTTPHeaderFieldsKey"] as? [String: String] ?? [
            String: String
        ]()
        oldValue.merge(header) { _, new in new }
        avOptions["AVURLAssetHTTPHeaderFieldsKey"] = oldValue
        var str = formatContextOptions["headers"] as? String ?? ""
        for (key, value) in header {
            str.append("\(key):\(value)\r\n")
        }
        formatContextOptions["headers"] = str
    }

    public func setCookie(_ cookies: [HTTPCookie]) {
        avOptions[AVURLAssetHTTPCookiesKey] = cookies
        let cookieStr = cookies.map { cookie in "\(cookie.name)=\(cookie.value)" }.joined(separator: "; ")
        appendHeader(["Cookie": cookieStr])
    }

    // 缓冲算法函数
    open func playable(capacitys: [CapacityProtocol], isFirst: Bool, isSeek: Bool) -> LoadingState {
        let packetCount = capacitys.map(\.packetCount).min() ?? 0
        let frameCount = capacitys.map(\.frameCount).min() ?? 0
        let isEndOfFile = capacitys.allSatisfy(\.isEndOfFile)
        let loadedTime = capacitys.map(\.loadedTime).min() ?? 0
        let progress = preferredForwardBufferDuration == 0 ? 100 : loadedTime * 100.0 / preferredForwardBufferDuration
        let isPlayable = capacitys.allSatisfy { capacity in
            if capacity.isEndOfFile && capacity.packetCount == 0 {
                return true
            }
            guard capacity.frameCount >= 2 else {
                return false
            }
            if capacity.isEndOfFile {
                return true
            }
            if (syncDecodeVideo && capacity.mediaType == .video) || (syncDecodeAudio && capacity.mediaType == .audio) {
                return true
            }
            if isFirst || isSeek {
                // 让纯音频能更快的打开
                if capacity.mediaType == .audio || isSecondOpen {
                    if isFirst {
                        return true
                    } else {
                        return capacity.loadedTime >= self.preferredForwardBufferDuration / 2
                    }
                }
            }
            return capacity.loadedTime >= self.preferredForwardBufferDuration
        }
        return LoadingState(loadedTime: loadedTime, progress: progress, packetCount: packetCount,
                            frameCount: frameCount, isEndOfFile: isEndOfFile, isPlayable: isPlayable,
                            isFirst: isFirst, isSeek: isSeek)
    }

    open func adaptable(state: VideoAdaptationState?) -> (Int64, Int64)? {
        guard let state, let last = state.bitRateStates.last, CACurrentMediaTime() - last.time > maxBufferDuration / 2, let index = state.bitRates.firstIndex(of: last.bitRate) else {
            return nil
        }
        let isUp = state.loadedCount > Int(Double(state.fps) * maxBufferDuration / 2)
        if isUp != state.isPlayable {
            return nil
        }
        if isUp {
            if index < state.bitRates.endIndex - 1 {
                return (last.bitRate, state.bitRates[index + 1])
            }
        } else {
            if index > state.bitRates.startIndex {
                return (last.bitRate, state.bitRates[index - 1])
            }
        }
        return nil
    }

    ///  wanted video stream index, or nil for automatic selection
    /// - Parameter : video track
    /// - Returns: The index of the track
    open func wantedVideo(tracks _: [MediaPlayerTrack]) -> Int? {
        nil
    }

    /// wanted audio stream index, or nil for automatic selection
    /// - Parameter :  audio track
    /// - Returns: The index of the track
    open func wantedAudio(tracks _: [MediaPlayerTrack]) -> Int? {
        nil
    }

    open func videoFrameMaxCount(fps _: Float, naturalSize _: CGSize, isLive: Bool) -> UInt8 {
        isLive ? 4 : 16
    }

    open func audioFrameMaxCount(fps: Float, channelCount: Int) -> UInt8 {
        let count = (Int(fps) * channelCount) >> 2
        if count >= UInt8.max {
            return UInt8.max
        } else {
            return UInt8(count)
        }
    }

    /// customize dar
    /// - Parameters:
    ///   - sar: SAR(Sample Aspect Ratio)
    ///   - dar: PAR(Pixel Aspect Ratio)
    /// - Returns: DAR(Display Aspect Ratio)
    open func customizeDar(sar _: CGSize, par _: CGSize) -> CGSize? {
        nil
    }

    // 虽然只有iOS才支持PIP。但是因为AVSampleBufferDisplayLayer能够支持HDR10+。所以默认还是推荐用AVSampleBufferDisplayLayer
    open func isUseDisplayLayer() -> Bool {
        display == .plane
    }

    open func urlIO(log: String) {
        if log.starts(with: "Original list of addresses"), dnsStartTime == 0 {
            dnsStartTime = CACurrentMediaTime()
        } else if log.starts(with: "Starting connection attempt to"), tcpStartTime == 0 {
            tcpStartTime = CACurrentMediaTime()
        } else if log.starts(with: "Successfully connected to"), tcpConnectedTime == 0 {
            tcpConnectedTime = CACurrentMediaTime()
        }
    }

    private var idetTypeMap = [VideoInterlacingType: UInt]()
    open func filter(log: String) {
        if log.starts(with: "Repeated Field:"), autoDeInterlace {
            for str in log.split(separator: ",") {
                let map = str.split(separator: ":")
                if map.count >= 2 {
                    if String(map[0].trimmingCharacters(in: .whitespaces)) == "Multi frame" {
                        if let type = VideoInterlacingType(rawValue: map[1].trimmingCharacters(in: .whitespacesAndNewlines)) {
                            idetTypeMap[type] = (idetTypeMap[type] ?? 0) + 1
                            let tff = idetTypeMap[.tff] ?? 0
                            let bff = idetTypeMap[.bff] ?? 0
                            let progressive = idetTypeMap[.progressive] ?? 0
                            let undetermined = idetTypeMap[.undetermined] ?? 0
                            if progressive - tff - bff > 100 {
                                videoInterlacingType = .progressive
                                autoDeInterlace = false
                            } else if bff - progressive > 100 {
                                videoInterlacingType = .bff
                                autoDeInterlace = false
                            } else if tff - progressive > 100 {
                                videoInterlacingType = .tff
                                autoDeInterlace = false
                            } else if undetermined - progressive - tff - bff > 100 {
                                videoInterlacingType = .undetermined
                                autoDeInterlace = false
                            }
                        }
                    }
                }
            }
        }
    }

    open func sei(string: String) {
        KSLog("sei \(string)")
    }

    /**
            在创建解码器之前可以对KSOptions和assetTrack做一些处理。例如判断fieldOrder为tt或bb的话，那就自动加videofilters
     */
    open func process(assetTrack: some MediaPlayerTrack) {
        if assetTrack.mediaType == .video {
            if [FFmpegFieldOrder.bb, .bt, .tt, .tb].contains(assetTrack.fieldOrder) {
                // todo 先不要用yadif_videotoolbox，不然会crash。这个后续在看下要怎么解决
                hardwareDecode = false
                asynchronousDecompression = false
                let yadif = hardwareDecode ? "yadif_videotoolbox" : "yadif"
                var yadifMode = KSOptions.yadifMode
//                if let assetTrack = assetTrack as? FFmpegAssetTrack {
//                    if assetTrack.realFrameRate.num == 2 * assetTrack.avgFrameRate.num, assetTrack.realFrameRate.den == assetTrack.avgFrameRate.den {
//                        if yadifMode == 1 {
//                            yadifMode = 0
//                        } else if yadifMode == 3 {
//                            yadifMode = 2
//                        }
//                    }
//                }
                if KSOptions.deInterlaceAddIdet {
                    videoFilters.append("idet")
                }
                videoFilters.append("\(yadif)=mode=\(yadifMode):parity=-1:deint=1")
                if yadifMode == 1 || yadifMode == 3 {
                    assetTrack.nominalFrameRate = assetTrack.nominalFrameRate * 2
                }
            }
        }
    }

    @MainActor
    open func updateVideo(refreshRate: Float, isDovi: Bool, formatDescription: CMFormatDescription?) {
        #if os(tvOS) || os(xrOS)
        /**
         快速更改preferredDisplayCriteria，会导致isDisplayModeSwitchInProgress变成true。
         例如退出一个视频，然后在3s内重新进入的话。所以不判断isDisplayModeSwitchInProgress了
         */
        guard let displayManager = UIApplication.shared.windows.first?.avDisplayManager,
              displayManager.isDisplayCriteriaMatchingEnabled
        else {
            return
        }
        if let dynamicRange = isDovi ? .dolbyVision : formatDescription?.dynamicRange {
            displayManager.preferredDisplayCriteria = AVDisplayCriteria(refreshRate: refreshRate, videoDynamicRange: dynamicRange.rawValue)
        }
        #endif
    }

    open func videoClockSync(main: KSClock, nextVideoTime: TimeInterval, fps: Double, frameCount: Int) -> (Double, ClockProcessType) {
        let desire = main.getTime() - videoDelay
        let diff = nextVideoTime - desire
//        print("[video] video diff \(diff) nextVideoTime \(nextVideoTime) main \(main.time.seconds)")
        if diff >= 1 / fps / 2 {
            videoClockDelayCount = 0
            return (diff, .remain)
        } else {
            if diff < -4 / fps {
                videoClockDelayCount += 1
                let log = "[video] video delay=\(diff), clock=\(desire), delay count=\(videoClockDelayCount), frameCount=\(frameCount)"
                if frameCount == 1 {
                    if diff < -1, videoClockDelayCount % 10 == 0 {
                        KSLog("\(log) drop gop Packet")
                        return (diff, .dropGOPPacket)
                    } else if videoClockDelayCount % 5 == 0 {
                        KSLog("\(log) drop next frame")
                        return (diff, .dropNextFrame)
                    } else {
                        return (diff, .next)
                    }
                } else {
                    if diff < -8, videoClockDelayCount % 100 == 0 {
                        KSLog("\(log) seek video track")
                        return (diff, .seek)
                    }
                    if diff < -1, videoClockDelayCount % 10 == 0 {
                        KSLog("\(log) flush video track")
                        return (diff, .flush)
                    }
                    if videoClockDelayCount % 2 == 0 {
                        KSLog("\(log) drop next frame")
                        return (diff, .dropNextFrame)
                    } else {
                        return (diff, .next)
                    }
                }
            } else {
                videoClockDelayCount = 0
                return (diff, .next)
            }
        }
    }

    open func availableDynamicRange(_ contentRange: DynamicRange?) -> DynamicRange? {
        #if canImport(UIKit)
        let availableHDRModes = AVPlayer.availableHDRModes
        if let preferedDynamicRange = destinationDynamicRange {
            // value of 0 indicates that no HDR modes are supported.
            if availableHDRModes == AVPlayer.HDRMode(rawValue: 0) {
                return .sdr
            } else if availableHDRModes.contains(preferedDynamicRange.hdrMode) {
                return preferedDynamicRange
            } else if let contentRange,
                      availableHDRModes.contains(contentRange.hdrMode)
            {
                return contentRange
            } else if preferedDynamicRange != .sdr { // trying update to HDR mode
                return availableHDRModes.dynamicRange
            }
        }
        return contentRange
        #else
        return destinationDynamicRange ?? contentRange
        #endif
    }

    open func playerLayerDeinit() {
        #if os(tvOS) || os(xrOS)
        runOnMainThread {
            UIApplication.shared.windows.first?.avDisplayManager.preferredDisplayCriteria = nil
        }
        #endif
    }

    open func liveAdaptivePlaybackRate(loadingState _: LoadingState) -> Float? {
        nil
//        if loadingState.isFirst {
//            return nil
//        }
//        if loadingState.loadedTime > preferredForwardBufferDuration + 5 {
//            return 1.2
//        } else if loadingState.loadedTime < preferredForwardBufferDuration / 2 {
//            return 0.8
//        } else {
//            return 1
//        }
    }

    open func process(url _: URL) -> AbstractAVIOContext? {
        nil
    }
}

public enum VideoInterlacingType: String {
    case tff
    case bff
    case progressive
    case undetermined
}

public extension KSOptions {
    static var firstPlayerType: MediaPlayerProtocol.Type = KSAVPlayer.self
    static var secondPlayerType: MediaPlayerProtocol.Type? = KSMEPlayer.self
    /// 最低缓存视频时间
    static var preferredForwardBufferDuration = 3.0
    /// 最大缓存视频时间
    static var maxBufferDuration = 30.0
    /// 是否开启秒开
    static var isSecondOpen = false
    /// 开启精确seek
    static var isAccurateSeek = false
    /// Applies to short videos only
    static var isLoopPlay = false
    /// 是否自动播放，默认true
    static var isAutoPlay = true
    /// seek完是否自动播放
    static var isSeekedAutoPlay = true
    static var hardwareDecode = true
    // 默认不用自研的硬解，因为有些视频的AVPacket的pts顺序是不对的，只有解码后的AVFrame里面的pts是对的。
    static var asynchronousDecompression = false
    static var isPipPopViewController = false
    static var canStartPictureInPictureAutomaticallyFromInline = true
    static var preferredFrame = true
    static var useSystemHTTPProxy = true
    /// 日志级别
    static var logLevel = LogLevel.warning
    static var logger: LogHandler = OSLog(lable: "KSPlayer")
    internal static func deviceCpuCount() -> Int {
        var ncpu = UInt(0)
        var len: size_t = MemoryLayout.size(ofValue: ncpu)
        sysctlbyname("hw.ncpu", &ncpu, &len, nil, 0)
        return Int(ncpu)
    }

    static func setAudioSession() {
        #if os(macOS)
//        try? AVAudioSession.sharedInstance().setRouteSharingPolicy(.longFormAudio)
        #else
        var category = AVAudioSession.sharedInstance().category
        if category != .playAndRecord {
            category = .playback
        }
        #if os(tvOS)
        try? AVAudioSession.sharedInstance().setCategory(category, mode: .moviePlayback, policy: .longFormAudio)
        #else
        try? AVAudioSession.sharedInstance().setCategory(category, mode: .moviePlayback, policy: .longFormVideo)
        #endif
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    #if !os(macOS)
    static func isSpatialAudioEnabled(channelCount _: AVAudioChannelCount) -> Bool {
        if #available(tvOS 15.0, iOS 15.0, *) {
            let isSpatialAudioEnabled = AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.isSpatialAudioEnabled }
            try? AVAudioSession.sharedInstance().setSupportsMultichannelContent(isSpatialAudioEnabled)
            return isSpatialAudioEnabled
        } else {
            return false
        }
    }

    static func outputNumberOfChannels(channelCount: AVAudioChannelCount) -> AVAudioChannelCount {
        let maximumOutputNumberOfChannels = AVAudioChannelCount(AVAudioSession.sharedInstance().maximumOutputNumberOfChannels)
        let preferredOutputNumberOfChannels = AVAudioChannelCount(AVAudioSession.sharedInstance().preferredOutputNumberOfChannels)
        let isSpatialAudioEnabled = isSpatialAudioEnabled(channelCount: channelCount)
        let isUseAudioRenderer = KSOptions.audioPlayerType == AudioRendererPlayer.self
        KSLog("[audio] maximumOutputNumberOfChannels: \(maximumOutputNumberOfChannels), preferredOutputNumberOfChannels: \(preferredOutputNumberOfChannels), isSpatialAudioEnabled: \(isSpatialAudioEnabled), isUseAudioRenderer: \(isUseAudioRenderer) ")
        let maxRouteChannelsCount = AVAudioSession.sharedInstance().currentRoute.outputs.compactMap {
            $0.channels?.count
        }.max() ?? 2
        KSLog("[audio] currentRoute max channels: \(maxRouteChannelsCount)")
        var channelCount = channelCount
        if channelCount > 2 {
            let minChannels = min(maximumOutputNumberOfChannels, channelCount)
            #if os(tvOS) || targetEnvironment(simulator)
            if !(isUseAudioRenderer && isSpatialAudioEnabled) {
                // 不要用maxRouteChannelsCount来判断，有可能会不准。导致多音道设备也返回2（一开始播放一个2声道，就容易出现），也不能用outputNumberOfChannels来判断，有可能会返回2
//                channelCount = AVAudioChannelCount(min(AVAudioSession.sharedInstance().outputNumberOfChannels, maxRouteChannelsCount))
                channelCount = minChannels
            }
            #else
            // iOS 外放是会自动有空间音频功能，但是蓝牙耳机有可能没有空间音频功能或者把空间音频给关了，。所以还是需要处理。
            if !isSpatialAudioEnabled {
                channelCount = minChannels
            }
            #endif
        } else {
            channelCount = 2
        }
        // 不在这里设置setPreferredOutputNumberOfChannels,因为这个方法会在获取音轨信息的时候，进行调用。
        KSLog("[audio] outputNumberOfChannels: \(AVAudioSession.sharedInstance().outputNumberOfChannels) output channelCount: \(channelCount)")
        return channelCount
    }
    #endif
}

public enum LogLevel: Int32, CustomStringConvertible {
    case panic = 0
    case fatal = 8
    case error = 16
    case warning = 24
    case info = 32
    case verbose = 40
    case debug = 48
    case trace = 56

    public var description: String {
        switch self {
        case .panic:
            return "panic"
        case .fatal:
            return "fault"
        case .error:
            return "error"
        case .warning:
            return "warning"
        case .info:
            return "info"
        case .verbose:
            return "verbose"
        case .debug:
            return "debug"
        case .trace:
            return "trace"
        }
    }
}

public extension LogLevel {
    var logType: OSLogType {
        switch self {
        case .panic, .fatal:
            return .fault
        case .error:
            return .error
        case .warning:
            return .debug
        case .info, .verbose, .debug:
            return .info
        case .trace:
            return .default
        }
    }
}

public protocol LogHandler {
    @inlinable
    func log(level: LogLevel, message: CustomStringConvertible, file: String, function: String, line: UInt)
}

public class OSLog: LogHandler {
    public let label: String
    public init(lable: String) {
        label = lable
    }

    @inlinable
    public func log(level: LogLevel, message: CustomStringConvertible, file: String, function: String, line: UInt) {
        os_log(level.logType, "%@ %@: %@:%d %@ | %@", level.description, label, file, line, function, message.description)
    }
}

public class FileLog: LogHandler {
    public let fileHandle: FileHandle
    public let formatter = DateFormatter()
    public init(fileHandle: FileHandle) {
        self.fileHandle = fileHandle
        formatter.dateFormat = "MM-dd HH:mm:ss.SSSSSS"
    }

    @inlinable
    public func log(level: LogLevel, message: CustomStringConvertible, file: String, function: String, line: UInt) {
        let string = String(format: "%@ %@ %@:%d %@ | %@\n", formatter.string(from: Date()), level.description, file, line, function, message.description)
        if let data = string.data(using: .utf8) {
            fileHandle.write(data)
        }
    }
}

@inlinable
public func KSLog(_ error: @autoclosure () -> Error, file: String = #file, function: String = #function, line: UInt = #line) {
    KSLog(level: .error, error().localizedDescription, file: file, function: function, line: line)
}

@inlinable
public func KSLog(level: LogLevel = .warning, _ message: @autoclosure () -> CustomStringConvertible, file: String = #file, function: String = #function, line: UInt = #line) {
    if level.rawValue <= KSOptions.logLevel.rawValue {
        let fileName = (file as NSString).lastPathComponent
        KSOptions.logger.log(level: level, message: message(), file: fileName, function: function, line: line)
    }
}

@inlinable
public func KSLog(level: LogLevel = .warning, dso: UnsafeRawPointer = #dsohandle, _ message: StaticString, _ args: CVarArg...) {
    if level.rawValue <= KSOptions.logLevel.rawValue {
        os_log(level.logType, dso: dso, message, args)
    }
}

public extension Array {
    func toDictionary<Key: Hashable>(with selectKey: (Element) -> Key) -> [Key: Element] {
        var dict = [Key: Element]()
        forEach { element in
            dict[selectKey(element)] = element
        }
        return dict
    }
}

public struct KSClock {
    public private(set) var lastMediaTime = CACurrentMediaTime()
    public internal(set) var position = Int64(0)
    public internal(set) var time = CMTime.zero {
        didSet {
            lastMediaTime = CACurrentMediaTime()
        }
    }

    func getTime() -> TimeInterval {
        time.seconds + CACurrentMediaTime() - lastMediaTime
    }
}

/// One-shot startup diagnostics. Decode callbacks may arrive on other queues;
/// an earlier prepare generation cannot populate a reset session's evidence.
/// Output completion is an API boundary, never compositor/visible-frame proof.
public final class KSVideoStartupTiming {
    public enum Stage: String { case decodeInvocation, decodedCallback, acceptedFrame, outputAttempt, outputSubmitted }
    public struct Sample {
        public let time: TimeInterval
        public let pts: TimeInterval
        public let path: String
    }
    public enum Work: String { case demuxRead, videoDecodeCall, videoPutPacket, audioPutPacket }
    public enum CapacityPhase: String { case firstPlayable, firstOutput }
    public struct WorkSample {
        public var calls = 0
        public var seconds: TimeInterval = 0
        public var maximumSeconds: TimeInterval = 0
        public var clippedCalls = 0
    }
    public struct PacketSample {
        public var count = 0
        public var bytes = 0
        public var firstPTS: TimeInterval?
        public var lastPTS: TimeInterval?
        public var firstKeyPTS: TimeInterval?
    }
    public struct CapacitySample {
        public let media: String
        public let packets: Int
        public let frames: Int
        public let maximumFrames: Int
        public let fps: Float
        public init(media: String, packets: Int, frames: Int, maximumFrames: Int, fps: Float) {
            self.media = media; self.packets = packets; self.frames = frames
            self.maximumFrames = maximumFrames; self.fps = fps
        }
    }
    public struct CapacitySnapshot {
        public let time: TimeInterval
        public let tracks: [CapacitySample]
    }
    public struct Snapshot {
        public let work: [Work: WorkSample]
        public let packets: [String: PacketSample]
        public let capacities: [CapacityPhase: CapacitySnapshot]
        public let generation: UInt64
        public let samples: [Stage: Sample]
        public let discardedBeforeFirstAccepted: Int
    }
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var samples: [Stage: Sample] = [:]
    private var discarded = 0
    private var work: [Work: WorkSample] = [:]
    private var packets: [String: PacketSample] = [:]
    private var capacities: [CapacityPhase: CapacitySnapshot] = [:]

    public init() {}
    public var snapshot: Snapshot {
        lock.lock(); defer { lock.unlock() }
        return Snapshot(work: work, packets: packets, capacities: capacities, generation: generation, samples: samples,
                        discardedBeforeFirstAccepted: discarded)
    }
    public func reset() {
        lock.lock(); defer { lock.unlock() }
        generation &+= 1
        samples.removeAll()
        discarded = 0
        work.removeAll(); packets.removeAll(); capacities.removeAll()
    }
    public func discardedBeforeTarget(generation token: UInt64) {
        lock.lock(); defer { lock.unlock() }
        guard token == generation, samples[.acceptedFrame] == nil else { return }
        discarded += 1
    }
    public func record(_ stage: Stage, time: TimeInterval, pts: TimeInterval,
                       path: String, generation token: UInt64) {
        guard time.isFinite, time > 0, pts.isFinite else { return }
        lock.lock(); defer { lock.unlock() }
        guard token == generation, samples[stage] == nil else { return }
        samples[stage] = Sample(time: time, pts: pts, path: path)
    }
}

public extension KSVideoStartupTiming {
    /// Wall time in independent, possibly overlapping lanes; never additive CPU/network time.
    /// A call completing after acceptance contributes only its pre-acceptance interval.
    func recordWork(_ lane: Work, start: TimeInterval, end: TimeInterval, generation token: UInt64) {
        guard start.isFinite, end.isFinite, start > 0, end >= start else { return }
        lock.lock(); defer { lock.unlock() }
        guard token == generation else { return }
        let boundary = samples[.acceptedFrame]?.time ?? end
        guard start < boundary else { return }
        let duration = min(end, boundary) - start
        var value = work[lane] ?? WorkSample()
        value.calls += 1; value.seconds += duration
        value.maximumSeconds = max(value.maximumSeconds, duration)
        if end > boundary { value.clippedCalls += 1 }
        work[lane] = value
    }
    /// Packet routing before putPacket, not network bytes or proof of queue insertion.
    func recordPacket(media: String, time: TimeInterval, bytes: Int, pts: TimeInterval,
                      keyFrame: Bool, generation token: UInt64) {
        guard time.isFinite, time > 0, bytes > 0, pts.isFinite,
              media == "video" || media == "audio" else { return }
        lock.lock(); defer { lock.unlock() }
        guard token == generation, time <= (samples[.acceptedFrame]?.time ?? time) else { return }
        var value = packets[media] ?? PacketSample()
        value.count += 1; value.bytes += bytes
        if value.firstPTS == nil { value.firstPTS = pts }
        value.lastPTS = pts
        if keyFrame, value.firstKeyPTS == nil { value.firstKeyPTS = pts }
        packets[media] = value
    }
    func recordCapacity(_ phase: CapacityPhase, time: TimeInterval, tracks: [CapacitySample], generation token: UInt64) {
        guard time.isFinite, time > 0, !tracks.isEmpty,
              tracks.allSatisfy({ ($0.media == "video" || $0.media == "audio") && $0.packets >= 0 && $0.frames >= 0 && $0.maximumFrames >= 0 && $0.fps.isFinite && $0.fps > 0 }) else { return }
        lock.lock(); defer { lock.unlock() }
        guard token == generation, capacities[phase] == nil else { return }
        capacities[phase] = CapacitySnapshot(time: time, tracks: tracks)
    }
}

public extension KSVideoStartupTiming.Snapshot {
    /// A snapshot may precede completion of an in-flight call; keep its capture boundary explicit.
    func fields(prepare: TimeInterval) -> [String: String] {
        func ms(_ seconds: TimeInterval) -> String { String(format: "%.3f", seconds * 1000) }
        var result = ["workMeaning": "overlappingWallIntervalsClippedAtAcceptedFrameNotCPUOrNetwork",
                      "workSnapshotAfterAccepted": String(samples[.acceptedFrame] != nil),
                      "workCoverage": "completedCallsOnlyInFlightUnmeasured"]
        for stage in [KSVideoStartupTiming.Stage.decodeInvocation, .decodedCallback] {
            if let value = samples[stage], prepare > 0, value.time >= prepare {
                result[stage.rawValue + "Ms"] = ms(value.time - prepare)
                result[stage.rawValue + "PTS"] = String(value.pts)
            }
        }
        for (lane, value) in work {
            let key = lane.rawValue
            result[key + "Calls"] = String(value.calls)
            result[key + "WallMs"] = ms(value.seconds)
            result[key + "MaxWallMs"] = ms(value.maximumSeconds)
            result[key + "ClippedCalls"] = String(value.clippedCalls)
        }
        for (media, value) in packets {
            result[media + "RoutedPackets"] = String(value.count)
            result[media + "RoutedBytes"] = String(value.bytes)
            result[media + "FirstPacketPTS"] = value.firstPTS.map { String($0) } ?? "missing"
            result[media + "LastPacketPTS"] = value.lastPTS.map { String($0) } ?? "missing"
            result[media + "FirstKeyPacketPTS"] = value.firstKeyPTS.map { String($0) } ?? "missing"
        }
        for (phase, value) in capacities {
            if prepare > 0, value.time >= prepare { result[phase.rawValue + "CapacityMs"] = ms(value.time - prepare) }
            for track in value.tracks {
                let key = phase.rawValue + track.media.capitalized
                result[key + "Packets"] = String(track.packets)
                result[key + "Frames"] = String(track.frames)
                result[key + "MaximumFrames"] = String(track.maximumFrames)
                result[key + "FPS"] = String(track.fps)
            }
        }
        return result
    }
}

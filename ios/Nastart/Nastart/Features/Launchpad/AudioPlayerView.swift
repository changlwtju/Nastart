import SwiftUI
import AVFoundation
import MediaPlayer
#if canImport(MobileVLCKit)
import MobileVLCKit
#endif

struct AudioLyricLine: Identifiable, Equatable {
    let id: Int
    let seconds: Double?
    let text: String
}

enum AudioLyricsParser {
    static func parse(_ data: Data) -> [AudioLyricLine] {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let lyrics = object["Lyrics"] as? [[String: Any]] {
            return lyrics.enumerated().compactMap { index, row in
                guard let text = row["Text"] as? String else { return nil }
                let seconds = (row["Start"] as? NSNumber).map { $0.doubleValue / 10_000_000 }
                return AudioLyricLine(id: index, seconds: seconds, text: text)
            }
        }
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let pattern = try! NSRegularExpression(pattern: #"\[(\d+):(\d{2}(?:\.\d+)?)\]"#)
        let offsetPattern = try! NSRegularExpression(pattern: #"(?i)\[offset:([+-]?\d+)\]"#)
        let ns = text as NSString
        let offsetMatch = offsetPattern.firstMatch(in: text, range: NSRange(location: 0, length: ns.length))
        let offset = offsetMatch.flatMap { Double(ns.substring(with: $0.range(at: 1))) }.map { $0 / 1000 } ?? 0
        var lines: [(Double?, String)] = []
        for raw in text.components(separatedBy: .newlines) {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let ns = value as NSString
            let matches = pattern.matches(in: value, range: NSRange(location: 0, length: ns.length))
            if let last = matches.last {
                let words = ns.substring(from: NSMaxRange(last.range)).trimmingCharacters(in: .whitespaces)
                for match in matches {
                    let minute = Double(ns.substring(with: match.range(at: 1))) ?? 0
                    let second = Double(ns.substring(with: match.range(at: 2))) ?? 0
                    lines.append((max(0, minute * 60 + second + offset), words))
                }
            } else if !value.hasPrefix("[") { lines.append((nil, value)) }
        }
        if lines.contains(where: { $0.0 != nil }) {
            lines = lines.filter { $0.0 != nil }.sorted { $0.0! < $1.0! }
        }
        return lines.enumerated().map { AudioLyricLine(id: $0.offset, seconds: $0.element.0, text: $0.element.1) }
    }
}

struct DedicatedAudioPlayerView: View {
    let request: MediaPlaybackRequest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: AudioPlaybackSession
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false
    @State private var lyrics: [AudioLyricLine] = []
    @State private var showsLyrics = false

    init(request: MediaPlaybackRequest) {
        self.request = request
        _session = StateObject(wrappedValue: AudioPlaybackSession(request: request))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.08, blue: 0.14), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.semibold))
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("action.done"))

                    Spacer()

                    Text("audio.player.now_playing")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Menu {
                        Picker("audio.player.speed", selection: Binding(
                            get: { session.playbackRate },
                            set: { session.setPlaybackRate($0) }
                        )) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                Text("\(rate.formatted())×").tag(rate)
                            }
                        }
                    } label: {
                        Image(systemName: "speedometer")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(Text("audio.player.speed"))
                }

                Spacer(minLength: 28)

                if showsLyrics, !lyrics.isEmpty {
                    lyricsView
                        .frame(maxWidth: 390)
                        .aspectRatio(1, contentMode: .fit)
                } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accent.opacity(0.85), .purple.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "waveform")
                        .font(.system(size: 82, weight: .light))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 390)
                .shadow(color: AppTheme.accent.opacity(0.28), radius: 28, y: 16)
                }
                if !lyrics.isEmpty {
                    Button { showsLyrics.toggle() } label: {
                        Label(showsLyrics ? "audio.player.artwork" : "audio.player.lyrics",
                              systemImage: showsLyrics ? "music.note" : "text.alignleft")
                    }
                    .padding(.top, 12)
                }

                Spacer(minLength: 34)

                VStack(alignment: .leading, spacing: 8) {
                    Text(request.title.isEmpty
                         ? NSLocalizedString("audio.player.unknown_title", comment: "")
                         : request.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    Text(session.formatLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 7) {
                    Slider(
                        value: $scrubPosition,
                        in: 0...1,
                        onEditingChanged: { editing in
                            isScrubbing = editing
                            if !editing { session.seek(to: scrubPosition) }
                        }
                    )
                    .disabled(!session.isSeekable)
                    .tint(AppTheme.accent)

                    HStack {
                        Text(session.currentTimeText)
                        Spacer()
                        Text(session.durationText)
                    }
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                HStack(spacing: 34) {
                    Button { session.jump(by: -15) } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title2)
                            .frame(width: 52, height: 52)
                    }
                    .disabled(!session.isSeekable)
                    .accessibilityLabel(Text("player.seek_backward"))

                    Button { session.togglePlayback() } label: {
                        ZStack {
                            Circle().fill(.white)
                            Image(systemName: session.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title.weight(.bold))
                                .foregroundStyle(.black)
                                .offset(x: session.isPlaying ? 0 : 2)
                        }
                        .frame(width: 74, height: 74)
                    }
                    .accessibilityLabel(Text(session.isPlaying ? "player.pause" : "player.play"))

                    Button { session.jump(by: 15) } label: {
                        Image(systemName: "goforward.15")
                            .font(.title2)
                            .frame(width: 52, height: 52)
                    }
                    .disabled(!session.isSeekable)
                    .accessibilityLabel(Text("player.seek_forward"))
                }
                .padding(.top, 20)

                if let errorMessage = session.errorMessage {
                    Button {
                        session.play()
                    } label: {
                        Label("action.retry", systemImage: "arrow.clockwise")
                    }
                    .padding(.top, 12)
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.top, 16)
                } else if session.isBuffering {
                    ProgressView("audio.player.buffering")
                        .tint(.white)
                        .font(.caption)
                        .padding(.top, 16)
                }

                Spacer(minLength: 18)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)
            .foregroundStyle(.white)
            .frame(maxWidth: 620)
        }
        .preferredColorScheme(.dark)
        .toolbar(.hidden, for: .navigationBar)
        .task { await loadLyrics() }
        .onAppear { session.play() }
        .onDisappear { session.stop() }
        .onChange(of: session.position) { position in
            if !isScrubbing { scrubPosition = position }
        }
    }
    private var currentLyricID: Int? {
        lyrics.last { $0.seconds.map { $0 <= session.elapsedSeconds } == true }?.id
    }

    private var lyricsView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(lyrics) { line in
                        Text(line.text)
                            .font(.title3.weight(line.id == currentLyricID ? .semibold : .regular))
                            .foregroundStyle(line.id == currentLyricID ? .white : .white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 32)
            }
            .onChange(of: currentLyricID) { id in
                if let id { withAnimation { proxy.scrollTo(id, anchor: .center) } }
            }
        }
    }

    private func loadLyrics() async {
        var url = request.audioLyricsURL
        if url == nil, request.url.query == nil,
           AudioFormatPolicy.extensions.contains(request.url.pathExtension.lowercased()) {
            url = request.url.deletingPathExtension().appendingPathExtension("lrc")
        }
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
        let delegate = FilePreviewTrustDelegate(trustedHost: url.host,
            allowsSelfSignedCertificates: request.allowsSelfSignedCertificates
                && url.host == request.networkOriginURL.host)
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForResource = 8
        config.timeoutIntervalForRequest = 5
        let client = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        defer { client.invalidateAndCancel() }
        do {
            let (bytes, response) = try await client.bytes(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return }
            var data = Data()
            for try await byte in bytes {
                guard data.count < 512 * 1024 else { return }
                data.append(byte)
            }
            guard !Task.isCancelled else { return }
            lyrics = AudioLyricsParser.parse(data)
        } catch { /* Lyrics are optional and never block audio playback. */ }
    }

}

#if canImport(MobileVLCKit)
final class AudioPlaybackSession: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = true
    @Published private(set) var isSeekable = false
    @Published private(set) var elapsedSeconds = 0.0
    @Published private(set) var position = 0.0
    @Published private(set) var currentTimeText = "00:00"
    @Published private(set) var durationText = "--:--"
    @Published private(set) var errorMessage: String?

    @Published private(set) var playbackRate = 1.0

    let formatLabel: String
    private let request: MediaPlaybackRequest
    private let player: VLCMediaPlayer
    private var isPausedByUser = false
    private var pausedSeekSeconds: Double?
    private var lastClockSeconds = 0.0
    private var lastClockAdvanceAt: Date?
    private var didApplyInitialPosition = false
    private var didStartTracking = false
    private var didReissueStartupPlay = false
    private var startupWorkItem: DispatchWorkItem?
    private var remoteCommandsInstalled = false

    init(request: MediaPlaybackRequest) {
        self.request = request
        formatLabel = request.fileExtensionHint.isEmpty
            ? NSLocalizedString("audio.player.audio", comment: "")
            : request.fileExtensionHint.uppercased()
        let trustOptions = VLCTrustDirectory.options(for: request)
        player = trustOptions.isEmpty ? VLCMediaPlayer() : VLCMediaPlayer(options: trustOptions)
        super.init()
        player.delegate = self
        player.media = makeMedia()
    }

    private func makeMedia() -> VLCMedia {
        let media = VLCMedia(url: request.url)
        let cache = NetworkHostClassifier.isPrivate(request.networkOriginURL.host) ? 900 : 1_500
        media.addOption(":network-caching=\(cache)")
        media.addOption(":file-caching=\(cache)")
        media.addOption(":http-reconnect")
        media.addOption(":input-fast-seek")
        // File Station/Jellyfin stream URLs are often API endpoints without
        // the original filename extension. Give FFmpeg the container hint so
        // FLAC/ALAC/APE/WMA and remote MP4 audio are demuxed deterministically
        // instead of waiting for VLC's URL/content-type guesser.
        if Self.avFormatAudioExtensions.contains(request.fileExtensionHint) {
            media.addOption(":demux=avformat")
        }
        return media
    }

    private static let avFormatAudioExtensions: Set<String> = [
        "mp3", "m4a", "aac", "wav", "flac", "ogg", "opus", "wma",
        "ape", "alac", "aiff", "aif", "amr", "ac3", "dts", "caf",
        "mp2", "m4b", "wave", "oga", "aifc", "eac3", "wv", "tta", "mka", "au", "snd", "dsf", "dff"
    ]

    func setPlaybackRate(_ rate: Double) {
        guard rate.isFinite else { return }
        playbackRate = min(max(rate, 0.5), 2)
        player.rate = Float(playbackRate)
        updateNowPlaying()
    }

    func play() {
        isPausedByUser = false
        pausedSeekSeconds = nil
        errorMessage = nil
        configureAudioSession()
        installRemoteCommandsIfNeeded()
        didReissueStartupPlay = false
        if !didStartTracking {
            didStartTracking = true
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_started",
                details: MediaPlaybackProbe.baseDetails(for: request).merging([
                    "engine": "MobileVLCKitAudio",
                    "content": "audio",
                    "demux": Self.avFormatAudioExtensions.contains(request.fileExtensionHint)
                        ? "avformat"
                        : "auto",
                    "cacheMs": NetworkHostClassifier.isPrivate(request.networkOriginURL.host)
                        ? "900"
                        : "1500"
                ]) { current, _ in current }
            )
        }
        player.play()
        player.rate = Float(playbackRate)
        scheduleStartupPlayRetry()
        updateNowPlaying()
    }

    func stop() {
        startupWorkItem?.cancel()
        startupWorkItem = nil
        player.stop()
        request.playbackTracker?.progressed(
            positionSeconds: currentSeconds,
            isPaused: true,
            force: true
        )
        request.playbackTracker?.stopped(failed: errorMessage != nil)
        removeRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func setPaused(_ paused: Bool) {
        isPausedByUser = paused
        startupWorkItem?.cancel()
        if paused { player.pause() } else {
            pausedSeekSeconds = nil
            player.play()
            player.rate = Float(playbackRate)
        }
        syncState()
    }

    func togglePlayback() {
        setPaused(!isPausedByUser && player.isPlaying)
    }

    func seek(to normalizedPosition: Double) {
        guard player.isSeekable else { return }
        let target = min(max(normalizedPosition, 0), 1)
        if isPausedByUser { pausedSeekSeconds = target * durationSeconds }
        player.position = Float(target)
        syncState()
    }

    func jump(by seconds: Double) {
        let duration = durationSeconds
        guard player.isSeekable, duration > 0 else { return }
        let target = min(max(currentSeconds + seconds, 0), duration)
        seek(to: target / duration)
    }

    func mediaPlayerStateChanged(_ notification: Notification) { syncState() }
    func mediaPlayerTimeChanged(_ notification: Notification) { syncState() }

    private var currentSeconds: Double {
        pausedSeekSeconds ?? max(Double(player.time.intValue) / 1_000, 0)
    }

    private var durationSeconds: Double {
        request.totalDurationSeconds
            ?? max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
    }

    private func syncState() {
        let state = player.state
        let duration = durationSeconds
        let current = currentSeconds
        elapsedSeconds = current
        if !didApplyInitialPosition,
           player.isSeekable,
           let initialPosition = request.initialPosition,
           initialPosition > 0 {
            didApplyInitialPosition = true
            player.position = Float(initialPosition)
        }
        isPlaying = player.isPlaying && !isPausedByUser
        isSeekable = player.isSeekable && duration > 0
        position = duration > 0 ? min(max(current / duration, 0), 1) : max(Double(player.position), 0)
        currentTimeText = Self.timeText(current)
        durationText = duration > 0 ? Self.timeText(duration) : "--:--"
        if current > lastClockSeconds + 0.01 { lastClockAdvanceAt = Date() }
        lastClockSeconds = current
        let clockIsAdvancing = lastClockAdvanceAt.map { Date().timeIntervalSince($0) < 2 } ?? false
        isBuffering = !isPausedByUser && (state == .opening || state == .buffering)
            && !(player.isPlaying && clockIsAdvancing)
        if state == .error {
            errorMessage = NSLocalizedString("audio.player.load_failed", comment: "")
        }
        if isPlaying {
            startupWorkItem?.cancel()
            startupWorkItem = nil
            errorMessage = nil
            if !didStartTracking {
                didStartTracking = true
            }
            request.playbackTracker?.started(positionSeconds: current)
        }
        request.playbackTracker?.progressed(positionSeconds: current, isPaused: !isPlaying)
        updateNowPlaying()
    }

    private func scheduleStartupPlayRetry() {
        startupWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  !self.didReissueStartupPlay,
                  !self.player.isPlaying,
                  self.player.state == .opening || self.player.state == .buffering else {
                return
            }
            self.didReissueStartupPlay = true
            self.player.play()
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_state",
                details: [
                    "engine": "MobileVLCKitAudio",
                    "state": "startupPlayReissued",
                    "reason": "audioBufferingWithoutClock"
                ]
            )
        }
        startupWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: workItem)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
        try? session.setActive(true)
    }

    private func installRemoteCommandsIfNeeded() {
        guard !remoteCommandsInstalled else { return }
        remoteCommandsInstalled = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in self?.setPaused(false); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.setPaused(true); return .success }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayback(); return .success }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in self?.jump(by: 15); return .success }
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.addTarget { [weak self] _ in self?.jump(by: -15); return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  self.durationSeconds > 0 else { return .commandFailed }
            self.seek(to: event.positionTime / self.durationSeconds)
            return .success
        }
    }

    private func removeRemoteCommands() {
        guard remoteCommandsInstalled else { return }
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.skipForwardCommand.removeTarget(nil)
        center.skipBackwardCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)
        remoteCommandsInstalled = false
    }

    private func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: request.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentSeconds,
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? playbackRate : 0
        ]
        if durationSeconds > 0 { info[MPMediaItemPropertyPlaybackDuration] = durationSeconds }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private static func timeText(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "--:--" }
        let total = Int(seconds.rounded(.down))
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remaining = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remaining)
            : String(format: "%02d:%02d", minutes, remaining)
    }
}
#else
final class AudioPlaybackSession: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = false
    @Published private(set) var isSeekable = false
    @Published private(set) var elapsedSeconds = 0.0
    @Published private(set) var position = 0.0
    @Published private(set) var currentTimeText = "00:00"
    @Published private(set) var durationText = "--:--"
    @Published private(set) var errorMessage: String? = NSLocalizedString("player.compatibility_unavailable", comment: "")
    @Published private(set) var playbackRate = 1.0
    func setPlaybackRate(_ rate: Double) {}
    let formatLabel = "Audio"
    init(request: MediaPlaybackRequest) {}
    func play() {}
    func stop() {}
    func togglePlayback() {}
    func seek(to position: Double) {}
    func jump(by seconds: Double) {}
}
#endif

import SwiftUI
import AVFoundation
import MediaPlayer
#if canImport(MobileVLCKit)
import MobileVLCKit
#endif

struct DedicatedAudioPlayerView: View {
    let request: MediaPlaybackRequest
    @Environment(\.dismiss) private var dismiss
    @StateObject private var session: AudioPlaybackSession
    @State private var scrubPosition = 0.0
    @State private var isScrubbing = false

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

                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer(minLength: 28)

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
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { session.play() }
        .onDisappear { session.stop() }
        .onChange(of: session.position) { position in
            if !isScrubbing { scrubPosition = position }
        }
    }
}

#if canImport(MobileVLCKit)
final class AudioPlaybackSession: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var isBuffering = true
    @Published private(set) var isSeekable = false
    @Published private(set) var position = 0.0
    @Published private(set) var currentTimeText = "00:00"
    @Published private(set) var durationText = "--:--"
    @Published private(set) var errorMessage: String?

    let formatLabel: String
    private let request: MediaPlaybackRequest
    private let player: VLCMediaPlayer
    private var didApplyInitialPosition = false
    private var didStartTracking = false
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
        let cache = NetworkHostClassifier.isPrivate(request.networkOriginURL.host) ? 500 : 1_000
        media.addOption(":network-caching=\(cache)")
        media.addOption(":file-caching=\(cache)")
        media.addOption(":http-reconnect")
        media.addOption(":http-continuous")
        media.addOption(":input-fast-seek")
        media.addOption(":no-video")
        return media
    }

    func play() {
        configureAudioSession()
        installRemoteCommandsIfNeeded()
        if !didStartTracking {
            didStartTracking = true
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.media",
                messageKey: "diagnostics.media.player_started",
                details: MediaPlaybackProbe.baseDetails(for: request).merging([
                    "engine": "MobileVLCKitAudio",
                    "content": "audio"
                ]) { current, _ in current }
            )
        }
        player.play()
        updateNowPlaying()
    }

    func stop() {
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

    func togglePlayback() {
        if player.isPlaying { player.pause() } else { player.play() }
        syncState()
    }

    func seek(to normalizedPosition: Double) {
        guard player.isSeekable else { return }
        player.position = Float(min(max(normalizedPosition, 0), 1))
        syncState()
    }

    func jump(by seconds: Double) {
        let duration = durationSeconds
        guard player.isSeekable, duration > 0 else { return }
        let target = min(max(currentSeconds + seconds, 0), duration)
        player.position = Float(target / duration)
        syncState()
    }

    func mediaPlayerStateChanged(_ notification: Notification) { syncState() }
    func mediaPlayerTimeChanged(_ notification: Notification) { syncState() }

    private var currentSeconds: Double {
        max(Double(player.time.intValue) / 1_000, 0)
    }

    private var durationSeconds: Double {
        request.totalDurationSeconds
            ?? max(Double(player.media?.length.intValue ?? 0) / 1_000, 0)
    }

    private func syncState() {
        let state = player.state
        let duration = durationSeconds
        let current = currentSeconds
        if !didApplyInitialPosition,
           player.isSeekable,
           let initialPosition = request.initialPosition,
           initialPosition > 0 {
            didApplyInitialPosition = true
            player.position = Float(initialPosition)
        }
        isPlaying = player.isPlaying
        isSeekable = player.isSeekable && duration > 0
        position = duration > 0 ? min(max(current / duration, 0), 1) : max(Double(player.position), 0)
        currentTimeText = Self.timeText(current)
        durationText = duration > 0 ? Self.timeText(duration) : "--:--"
        isBuffering = state == .opening || state == .buffering
        if state == .error {
            errorMessage = NSLocalizedString("audio.player.load_failed", comment: "")
        }
        if isPlaying {
            request.playbackTracker?.started(positionSeconds: current)
        }
        request.playbackTracker?.progressed(positionSeconds: current, isPaused: !isPlaying)
        updateNowPlaying()
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
        center.playCommand.addTarget { [weak self] _ in self?.player.play(); return .success }
        center.pauseCommand.addTarget { [weak self] _ in self?.player.pause(); return .success }
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
            MPNowPlayingInfoPropertyPlaybackRate: player.isPlaying ? 1 : 0
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
    @Published private(set) var position = 0.0
    @Published private(set) var currentTimeText = "00:00"
    @Published private(set) var durationText = "--:--"
    @Published private(set) var errorMessage: String? = NSLocalizedString("player.compatibility_unavailable", comment: "")
    let formatLabel = "Audio"
    init(request: MediaPlaybackRequest) {}
    func play() {}
    func stop() {}
    func togglePlayback() {}
    func seek(to position: Double) {}
    func jump(by seconds: Double) {}
}
#endif

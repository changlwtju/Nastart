import Foundation
import AVKit
import Combine
import NetworkMedia

@MainActor
final class TVPlayerControlsModel: ObservableObject, TVPlaybackControlling {
    struct Track: Identifiable { let id: Int; let name: String }
    @Published private(set) var seconds = 0.0
    @Published private(set) var duration = 0.0
    @Published private(set) var playing = false
    @Published private(set) var rate: Float = 1
    @Published private(set) var muted = false
    @Published private(set) var audio: [Track] = []
    @Published private(set) var subtitles: [Track] = []
    @Published private(set) var selectedAudio = -1
    @Published private(set) var selectedSubtitle = -1
    @Published var fillsScreen = false
    private weak var player: AVPlayer?
    private var observer: Any?
    private var audioGroup: AVMediaSelectionGroup?
    private var subtitleGroup: AVMediaSelectionGroup?
    private var observedItem: AVPlayerItem?
    private var seekState = PlaybackSeekState()
    private var pendingSeek: Double? { seekState.pendingTarget }
    var seekGeneration: Int { seekState.generation }
    private(set) var wantsPlayback = false
    private var intentRevision = 0
    var sourceRoute: TVPlaybackRoute? { didSet { updateSourceTracks() } }
    var onSelectSource: ((TVSourceSelection) -> Void)?
    var pendingSourceSelection: TVSourceSelection?
    struct RuntimeSnapshot {
        let seconds: Double
        let wantsPlayback: Bool
        let rate: Float
        let muted: Bool
        let revision: Int
    }
    var runtimeSnapshot: RuntimeSnapshot {
        RuntimeSnapshot(seconds: pendingSeek ?? player?.currentTime().seconds ?? seconds,
            wantsPlayback: wantsPlayback, rate: rate, muted: player?.isMuted ?? muted, revision: intentRevision)
    }
    private func updateSourceTracks() {
        guard let sourceRoute else { return }
        audio = sourceRoute.tracks.filter { $0.kind == "Audio" }.map { Track(id: $0.Index, name: $0.name) }
        subtitles = sourceRoute.tracks.filter { $0.kind == "Subtitle" }.map { Track(id: $0.Index, name: $0.name) }
        selectedAudio = sourceRoute.audioIndex ?? -1
        selectedSubtitle = sourceRoute.subtitleIndex
    }

    func attach(_ player: AVPlayer, restoring snapshot: RuntimeSnapshot? = nil) {
        guard self.player !== player else { return }
        detach(); self.player = player
        rate = snapshot?.rate ?? player.defaultRate
        wantsPlayback = snapshot?.wantsPlayback ?? (player.timeControlStatus != .paused)
        if let snapshot {
            player.defaultRate = snapshot.rate; player.isMuted = snapshot.muted
            if snapshot.wantsPlayback { player.playImmediately(atRate: snapshot.rate) } else { player.pause() }
        }
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        refresh()
    }
    func detach() {
        if let observer { player?.removeTimeObserver(observer) }
        observer = nil; player = nil; observedItem = nil
        seekState.invalidate()
        audioGroup = nil; subtitleGroup = nil
    }
    static func seekTarget(current: Double, delta: Double, duration: Double) -> Double? {
        PlaybackSeekState().target(relative: delta, clock: current, fallback: .nan, duration: duration)
    }
    private func refresh() {
        guard let player else { return }
        let t = player.currentTime().seconds, d = player.currentItem?.duration.seconds ?? 0
        if pendingSeek == nil, t.isFinite { seconds = max(0, t) }
        duration = d.isFinite ? max(0, d) : 0
        playing = wantsPlayback; muted = player.isMuted
        if player.rate > 0 { rate = player.rate }
        if sourceRoute != nil { updateSourceTracks(); return }
        if let item = player.currentItem, item.status == .readyToPlay {
            if observedItem !== item {
                observedItem = item
                audioGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .audible)
                subtitleGroup = item.asset.mediaSelectionGroup(forMediaCharacteristic: .legible)
                audio = audioGroup?.options.enumerated().map { Track(id: $0.offset, name: $0.element.displayName) } ?? []
                subtitles = subtitleGroup?.options.enumerated().map { Track(id: $0.offset, name: $0.element.displayName) } ?? []
            }
            selectedAudio = selectedIndex(item, group: audioGroup)
            selectedSubtitle = selectedIndex(item, group: subtitleGroup)
        }
    }
    private func selectedIndex(_ item: AVPlayerItem, group: AVMediaSelectionGroup?) -> Int {
        guard let group, let selected = item.currentMediaSelection.selectedMediaOption(in: group) else { return -1 }
        return group.options.firstIndex(of: selected) ?? -1
    }
    /// Ready callbacks must apply the latest user intent, including a pause
    /// received while a replacement route was still preparing.
    func setPlaybackIntent(_ play: Bool) { wantsPlayback = play; intentRevision += 1; refresh() }
    func restorePlaybackIntent() {
        guard let player else { return }
        if wantsPlayback { player.playImmediately(atRate: rate) } else { player.pause() }
        refresh()
    }
    func startPlayback() {
        guard let player else { return }
        wantsPlayback = true; intentRevision += 1
        player.playImmediately(atRate: rate); refresh()
    }
    func toggle() {
        guard let player else { return }
        wantsPlayback.toggle(); intentRevision += 1
        if wantsPlayback { player.playImmediately(atRate: rate) } else { player.pause() }; refresh()
    }
    func toggleMute() { player?.isMuted.toggle(); intentRevision += 1; refresh() }
    func seek(delta: Double) {
        guard let player,
              let target = seekState.target(relative: delta, clock: player.currentTime().seconds,
                  fallback: seconds, duration: duration),
              let request = seekState.begin(absolute: target, duration: duration) else { return }
        // A new remote press belongs to the user's pending target, not a stale
        // decoder clock. Older AV seek callbacks must not clear a newer intent.
        seconds = request.target; intentRevision += 1
        let item = player.currentItem
        PlaybackSeekCommandExecutor.submit(target: request.target,
            isCurrent: { [weak self, weak player] in
                guard let self, let player else { return false }
                return self.player === player && player.currentItem === item
                    && self.seekState.owns(generation: request.generation)
            }, seek: { [weak player] target, completion in
                guard let player else { completion(false); return }
                player.seek(to: CMTime(seconds: target, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completion)
            }, willComplete: { [weak self] _ in
                self?.seekState.complete(generation: request.generation)
            }, restoreIntent: { [weak self, weak player] in
                guard let self, let player else { return }
                if self.wantsPlayback { player.playImmediately(atRate: self.rate) } else { player.pause() }
            }, didComplete: { [weak self] _ in self?.refresh() })
    }
    func restart() { seek(delta: -seconds) }
    func setRate(_ rate: Float) {
        guard PlaybackControlDesign.rates.contains(rate), let player else { return }
        self.rate = rate; player.defaultRate = rate; intentRevision += 1
        if wantsPlayback { player.playImmediately(atRate: rate) }
    }
    func selectAudio(_ index: Int) {
        if let route = sourceRoute {
            let choice = TVSourceSelection(sourceID: route.sourceID, audioIndex: index, subtitleIndex: pendingSourceSelection?.subtitleIndex ?? route.subtitleIndex)
            if choice.isValid(in: route) { onSelectSource?(choice) }
        } else { select(index, group: audioGroup); refresh() }
    }
    func selectSubtitle(_ index: Int) {
        if let route = sourceRoute {
            let choice = TVSourceSelection(sourceID: route.sourceID, audioIndex: pendingSourceSelection?.audioIndex ?? route.audioIndex, subtitleIndex: index)
            if choice.isValid(in: route) { onSelectSource?(choice) }
        } else { select(index, group: subtitleGroup); refresh() }
    }
    private func select(_ index: Int, group: AVMediaSelectionGroup?) {
        guard let group, let item = player?.currentItem else { return }
        if index == -1, group.allowsEmptySelection { item.select(nil, in: group) }
        else if group.options.indices.contains(index) { item.select(group.options[index], in: group) }
    }
    var canDisableSubtitles: Bool { sourceRoute != nil || subtitleGroup?.allowsEmptySelection == true }
}

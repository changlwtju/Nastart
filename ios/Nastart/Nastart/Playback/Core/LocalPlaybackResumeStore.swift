import Foundation
import CryptoKit
import Combine

enum JellyfinResumePosition {
    static func serverTicks(position: Int?, duration: Int?, playedFraction: Double?) -> Int? {
        if let position { return max(0, min(position, duration.flatMap { $0 > 0 ? $0 : nil } ?? position)) }
        guard let duration, duration > 0, let fraction = playedFraction, fraction.isFinite else { return nil }
        let ticks = Double(duration) * min(1, max(0, fraction))
        return ticks >= Double(duration) ? duration : Int(ticks.rounded(.down))
    }

    static func prefersLocal(updatedAt: Date, serverPlayedAt: Date?, serverHasPosition: Bool,
                             serverMarkedPlayed: Bool) -> Bool {
        if let serverPlayedAt { return updatedAt > serverPlayedAt }
        return !serverHasPosition && !serverMarkedPlayed
    }
}

struct JellyfinStallRecovery {
    private var samplePosition: Double?
    private var lastMovement: TimeInterval?
    private var steadySince: TimeInterval?
    private var nextAttemptAt: TimeInterval = 0
    private var attempts = 0

    mutating func shouldReconnect(now: TimeInterval, position: Double,
                                  eligible: Bool, canReconnect: Bool) -> Bool {
        guard eligible, now.isFinite, position.isFinite else {
            samplePosition = nil
            lastMovement = nil
            steadySince = nil
            return false
        }
        if let samplePosition, let lastMovement, abs(position - samplePosition) > 0.25 {
            if position < samplePosition || now - lastMovement > 3 { steadySince = nil }
            if steadySince == nil { steadySince = now }
            if let steadySince, now - steadySince >= 30 { attempts = 0 }
            self.samplePosition = position
            self.lastMovement = now
            return false
        }
        if lastMovement == nil {
            samplePosition = position
            lastMovement = now
        }
        guard canReconnect, attempts < 2, now >= nextAttemptAt,
              let lastMovement, now - lastMovement >= 18 else { return false }
        steadySince = nil
        attempts += 1
        nextAttemptAt = now + 24
        return true
    }
}


/// Only file identity hashes and playback preferences are persisted, never URLs
/// carrying DSM sessions. Fixed revisions stay isolated; append-only recordings
/// additionally require matching content checkpoints before restoring progress.
final class LocalPlaybackResumeStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    struct Entry: Codable, Equatable {
        let positionSeconds: Double
        let durationSeconds: Double
        let audioTrackID: Int?
        let subtitleTrackID: Int?
        let subtitlesDisabled: Bool
        let updatedAt: Date
        var recordingWitness: RecordingWitness? = nil

        func restoredTrackSelection(audioIDs: [Int], subtitleIDs: [Int],
                                    defaultAudio: Int?, defaultSubtitle: Int?) -> (audio: Int?, subtitle: Int?) {
            let audio = audioTrackID.flatMap { audioIDs.contains($0) ? $0 : nil } ?? defaultAudio
            let subtitle = subtitlesDisabled ? nil
                : (subtitleTrackID.flatMap { subtitleIDs.contains($0) ? $0 : nil } ?? defaultSubtitle)
            return (audio, subtitle)
        }
    }
    struct RecordingWitness: Codable, Equatable {
        let byteLength: Int64
        let modifiedAt: Date
        let offset: Int64
        let digest: String
    }
    private struct RecordingContext {
        let current: RecordingWitness
        let verifiedPrevious: RecordingWitness?
    }
    private var recordingContexts: [String: RecordingContext] = [:]
    static let recordingSampleBytes = 64 * 1024
    static let shared = LocalPlaybackResumeStore()
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let storageKey = "playback.localResume.v1"
    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    static func key(server: URL, account: String, path: String, byteLength: Int64?, modifiedAt: Date?) -> String {
        var components = URLComponents(url: server, resolvingAgainstBaseURL: false)
        components?.user = nil; components?.password = nil
        components?.query = nil; components?.fragment = nil
        let host = components?.host?.lowercased()
        components?.host = host
        let identity = [components?.string ?? "", account, path,
                        byteLength.map(String.init) ?? "", modifiedAt.map { String($0.timeIntervalSince1970) } ?? ""]
        let data = (try? JSONEncoder().encode(identity)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func entry(for key: String) -> Entry? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries()[key] else { return nil }
        if let witness = entry.recordingWitness {
            guard let context = recordingContexts[key],
                  witness == context.current || witness == context.verifiedPrevious else { return nil }
        }
        return entry
    }

    static func recordingKey(server: URL, account: String, path: String, prefix: Data) -> String? {
        guard prefix.count == recordingSampleBytes else { return nil }
        let fileKey = key(server: server, account: account, path: path, byteLength: nil, modifiedAt: nil)
        let digest = SHA256.hash(data: prefix).map { String(format: "%02x", $0) }.joined()
        return SHA256.hash(data: Data(("recording-v1|" + fileKey + "|" + digest).utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    /// Only hashes and offsets are stored. Before exposing a recording bookmark,
    /// re-read its previous content checkpoint as well as the immutable prefix.
    func prepareRecordingKey(server: URL, account: String, path: String,
                             byteLength: Int64?, modifiedAt: Date?,
                             readRange: (Int64, Int) async -> Data?) async -> String? {
        let count = Self.recordingSampleBytes
        guard let length = byteLength, length >= Int64(count * 2), let modifiedAt,
              let prefix = await readRange(0, count),
              let key = Self.recordingKey(server: server, account: account, path: path, prefix: prefix)
        else { return nil }
        let previous = recordingWitness(for: key)
        var verifiedPrevious: RecordingWitness?
        if let previous, length >= previous.byteLength, modifiedAt >= previous.modifiedAt,
           previous.offset >= 0, previous.offset <= length - Int64(count),
           let bytes = await readRange(previous.offset, count), bytes.count == count,
           Self.recordingDigest(bytes) == previous.digest {
            verifiedPrevious = previous
        }
        let offset = length - Int64(count)
        guard !Task.isCancelled, let bytes = await readRange(offset, count), bytes.count == count,
              !Task.isCancelled else { return nil }
        activateRecording(key: key, current: RecordingWitness(byteLength: length, modifiedAt: modifiedAt,
            offset: offset, digest: Self.recordingDigest(bytes)), verifiedPrevious: verifiedPrevious,
            legacyKey: Self.key(server: server, account: account, path: path,
                                byteLength: length, modifiedAt: modifiedAt))
        return key
    }

    private static func recordingDigest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }

    private func recordingWitness(for key: String) -> RecordingWitness? {
        lock.lock(); defer { lock.unlock() }
        return entries()[key]?.recordingWitness
    }

    private func activateRecording(key: String, current: RecordingWitness,
                                   verifiedPrevious: RecordingWitness?, legacyKey: String) {
        lock.lock()
        recordingContexts[key] = RecordingContext(current: current, verifiedPrevious: verifiedPrevious)
        var values = entries()
        // A matching strict revision is the only safe migration from bookmarks
        // saved before content checkpoints existed. Never guess from path alone.
        var migrated = false
        if values[key] == nil, var legacy = values[legacyKey], legacy.recordingWitness == nil {
            legacy.recordingWitness = current
            values[key] = legacy
            if let data = try? JSONEncoder().encode(values) {
                defaults.set(data, forKey: storageKey)
                migrated = true
            }
        }
        lock.unlock()
        if migrated { DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() } }
    }

    struct SaveObservation {
        enum Status: String { case invalidTimeline, encodingFailed, submitted }
        let status: Status
        /// Same-process defaults readback under the store lock, never a disk acknowledgement.
        let memoryReadbackMatches: Bool?
        let entryUpdatedAt: Date?
    }

    @discardableResult
    func save(key: String, position: Double, duration: Double, audioTrackID: Int?, subtitleTrackID: Int?, subtitlesDisabled: Bool,
              observeMemory: Bool = false) -> SaveObservation {
        guard position.isFinite, position >= 0, duration.isFinite, duration > 0 else {
            return SaveObservation(status: .invalidTimeline, memoryReadbackMatches: nil, entryUpdatedAt: nil)
        }
        lock.lock()
        var values = entries()
        // A verified TS checkpoint identifies content, not its final duration.
        // Its current tail can later grow, so never infer completion from the
        // duration snapshot or discard an observed clock beyond that snapshot.
        let recording = recordingContexts[key]?.current
        let finished = recording == nil && duration - position <= min(30, duration * 0.02)
        let savedPosition = recording == nil ? min(position, duration) : position
        let savedDuration = recording == nil ? duration : max(duration, position)
        var entry = Entry(positionSeconds: finished ? 0 : savedPosition, durationSeconds: savedDuration,
                            audioTrackID: audioTrackID, subtitleTrackID: subtitleTrackID,
                            subtitlesDisabled: subtitlesDisabled, updatedAt: Date())
        entry.recordingWitness = recording
        values[key] = entry
        if values.count > 128 {
            for key in values.sorted(by: { $0.value.updatedAt > $1.value.updatedAt }).dropFirst(128).map(\.key) { values.removeValue(forKey: key) }
        }
        let data = try? JSONEncoder().encode(values)
        if let data { defaults.set(data, forKey: storageKey) }
        let matches = observeMemory && data != nil ? entries()[key] == entry : nil
        lock.unlock()
        guard data != nil else { return SaveObservation(status: .encodingFailed, memoryReadbackMatches: nil, entryUpdatedAt: nil) }
        // Views read the persisted entry on invalidation. Notify after releasing
        // the lock, on the main queue even when a renderer saved off-main.
        DispatchQueue.main.async { [weak self] in self?.objectWillChange.send() }
        return SaveObservation(status: .submitted, memoryReadbackMatches: matches, entryUpdatedAt: entry.updatedAt)
    }

    private func entries() -> [String: Entry] {
        guard let data = defaults.data(forKey: storageKey),
              let values = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return values.filter { $0.value.positionSeconds.isFinite && $0.value.positionSeconds >= 0
            && $0.value.durationSeconds.isFinite && $0.value.durationSeconds > 0 }
    }
}

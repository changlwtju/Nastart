import Foundation
#if canImport(CoreGraphics)
import CoreGraphics

/// Already decoded, immutable pixels for the current indexed artwork revision.
/// Access is synchronous so a recreated card can render its first frame without
/// briefly replacing a known poster with a placeholder. No disk or network IO.
final class DecodedArtworkCache: @unchecked Sendable {
    static let shared = DecodedArtworkCache()
    private struct Entry { let image: CGImage; let bytes: Int }
    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var recency: [String] = []
    private var bytes = 0
    private let maximumBytes: Int
    private let maximumCount: Int
    init(maximumBytes: Int = 32 * 1024 * 1024, maximumCount: Int = 64) {
        self.maximumBytes = max(1, maximumBytes)
        self.maximumCount = max(1, maximumCount)
    }
    func image(for key: String) -> CGImage? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        recency.removeAll { $0 == key }; recency.append(key)
        return entry.image
    }
    func insert(_ image: CGImage, for key: String) {
        let (cost, overflow) = image.bytesPerRow.multipliedReportingOverflow(by: image.height)
        guard !overflow, cost > 0, cost <= maximumBytes else { return }
        lock.lock(); defer { lock.unlock() }
        if let previous = entries.removeValue(forKey: key) { bytes -= previous.bytes }
        recency.removeAll { $0 == key }
        // Evict before insertion; even a small budget never transiently holds
        // both the old cache and a newly admitted large image in its entries.
        while !recency.isEmpty && (bytes > maximumBytes - cost || entries.count >= maximumCount) {
            if let old = entries.removeValue(forKey: recency.removeFirst()) { bytes -= old.bytes }
        }
        entries[key] = Entry(image: image, bytes: cost); bytes += cost; recency.append(key)
    }
    func removeAll() {
        lock.lock(); defer { lock.unlock() }
        entries.removeAll(); recency.removeAll(); bytes = 0
    }
}
#endif

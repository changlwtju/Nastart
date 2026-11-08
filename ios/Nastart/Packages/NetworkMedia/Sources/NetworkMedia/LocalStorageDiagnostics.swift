import Foundation

/// Sanitised local fault evidence. Never records paths, endpoints or credentials.
enum LocalStorageDiagnostics {
    static func record(_ operation: String, error: Error) {
        #if DEBUG && (os(iOS) || os(tvOS))
        let error = error as NSError
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: ["operation": operation, "domain": error.domain, "code": error.code]) else { return }
        try? data.write(to: directory.appendingPathComponent("network-media-storage-diagnostic.json"), options: .atomic)
        #endif
    }
}

/// Debug-only, bounded stage evidence; never stores titles, IDs, URLs or tokens.
enum CreditReadDiagnostics {
    private static let lock = NSLock()
    private static var events: [[String: String]] = []
    static func record(_ stage: String, _ values: [String: String] = [:]) {
        #if DEBUG && (os(iOS) || os(tvOS))
        lock.lock(); defer { lock.unlock() }
        events.append(values.merging(["stage": stage, "time": String(Date().timeIntervalSince1970)]) { _, new in new })
        events = Array(events.suffix(64))
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first,
              let data = try? JSONSerialization.data(withJSONObject: events) else { return }
        try? data.write(to: directory.appendingPathComponent("network-media-credit-diagnostic.json"), options: .atomic)
        #endif
    }
}

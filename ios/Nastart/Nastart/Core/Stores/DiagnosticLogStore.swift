import Foundation
import Combine

enum DiagnosticLogLevel: String, Codable {
    case info
    case warning
    case error

    var titleKey: String {
        switch self {
        case .info: return "diagnostics.level.info"
        case .warning: return "diagnostics.level.warning"
        case .error: return "diagnostics.level.error"
        }
    }
}
struct DiagnosticLogEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let level: DiagnosticLogLevel
    let categoryKey: String
    let messageKey: String
    let detail: String

    init(
        id: UUID = UUID(),
        date: Date,
        level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        detail: String
    ) {
        self.id = id
        self.date = date
        self.level = level
        self.categoryKey = categoryKey
        self.messageKey = messageKey
        self.detail = detail
    }

    var exportLine: String {
        let timestamp = Self.timestampFormatter.string(from: date)
        let localizedCategory = NSLocalizedString(categoryKey, comment: "")
        let localizedMessage = NSLocalizedString(messageKey, comment: "")
        let trimmedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDetail.isEmpty {
            return "[\(timestamp)] \(level.rawValue.uppercased()) \(localizedCategory) - \(localizedMessage)"
        }
        return "[\(timestamp)] \(level.rawValue.uppercased()) \(localizedCategory) - \(localizedMessage) | \(DiagnosticLogStore.redactedDetail(trimmedDetail))"
    }

    var displayTime: String {
        Self.displayFormatter.string(from: date)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let displayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return formatter
    }()
}

final class DiagnosticLogStore: ObservableObject {
    static let shared = DiagnosticLogStore()

    @Published private(set) var entries: [DiagnosticLogEntry] = []

    private let maxEntries = 1000
    private let persistenceKey = "diagnostics.entries.v1"
    private let persistenceQueue = DispatchQueue(
        label: "com.changliwen.nastart.diagnostics-persistence",
        qos: .utility
    )
    private var pendingPersistenceTask: Task<Void, Never>?

    private init() {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let savedEntries = try? JSONDecoder().decode([DiagnosticLogEntry].self, from: data)
        else {
            return
        }
        entries = Array(savedEntries.suffix(maxEntries))
    }

    func record(
        _ level: DiagnosticLogLevel,
        categoryKey: String,
        messageKey: String,
        details: [String: String] = [:]
    ) {
        let detail = details
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\(Self.redactedDetail($0.value))" }
            .joined(separator: ", ")

        Task { @MainActor in
            self.append(DiagnosticLogEntry(
                date: Date(),
                level: level,
                categoryKey: categoryKey,
                messageKey: messageKey,
                detail: detail
            ))
        }
    }

    @MainActor
    func clear() {
        entries.removeAll()
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = nil
        let persistenceKey = self.persistenceKey
        persistenceQueue.async {
            UserDefaults.standard.removeObject(forKey: persistenceKey)
        }
    }

    @MainActor
    func exportText() -> String {
        if entries.isEmpty {
            return NSLocalizedString("diagnostics.empty", comment: "")
        }
        let header = String.localizedStringWithFormat(
            NSLocalizedString("diagnostics.export.header", comment: ""),
            entries.count,
            entries.filter { $0.level == .warning }.count,
            entries.filter { $0.level == .error }.count
        )
        return ([header] + entries.map(\.exportLine)).joined(separator: "\n")
    }

    static func redactedHost(_ host: String?) -> String {
        guard let host, !host.isEmpty else { return "-" }
        let parts = host.split(separator: ".").map(String.init)
        if parts.count == 4, parts.allSatisfy({ Int($0) != nil }) {
            return "\(parts[0]).\(parts[1]).*.*"
        }
        guard host.count > 8 else { return host }
        let prefix = host.prefix(3)
        let suffix = host.suffix(5)
        return "\(prefix)...\(suffix)"
    }

    static func redactedURL(_ url: URL) -> String {
        let host = redactedHost(url.host)
        if let port = url.port {
            return "\(url.scheme ?? "https")://\(host):\(port)"
        }
        return "\(url.scheme ?? "https")://\(host)"
    }

    static func redactedDetail(_ value: String) -> String {
        let patterns: [(String, String)] = [
            (
                #"(?i)(https?://)[^/@\s]+@"#,
                "$1<redacted>@"
            ),
            (#"(?i)(bearer\s+)[a-z0-9._~+/=-]+"#, "$1<redacted>"),
            (
                #"(?i)((?:[\"']?)(?:_sid|api[_-]?key|apikey|token|access_token|authorization|password|passwd|cookie|path|filepath|filename|file_name)(?:[\"']?)\s*[=:]\s*[\"']?)[^\"',;&\s}]+"#,
                "$1<redacted>"
            ),
            (
                #"(?i)((?:pairing[_ -]?code|pairing)\s*[=:]\s*)[0-9]{6}\b"#,
                "$1<redacted>"
            )
        ]
        return patterns.reduce(value) { result, replacement in
            result.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: .regularExpression
            )
        }
    }

    @MainActor
    private func append(_ entry: DiagnosticLogEntry) {
        entries.append(entry)
        NSLog("%@", entry.exportLine)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        schedulePersistence(immediately: entry.level == .error)
    }

    @MainActor
    private func schedulePersistence(immediately: Bool) {
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = Task { @MainActor [weak self] in
            if !immediately {
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            guard !Task.isCancelled, let self else { return }
            let snapshot = self.entries
            let persistenceKey = self.persistenceKey
            self.persistenceQueue.async {
                guard let data = try? JSONEncoder().encode(snapshot) else { return }
                UserDefaults.standard.set(data, forKey: persistenceKey)
            }
        }
    }
}

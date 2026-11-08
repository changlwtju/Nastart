import Foundation
import os
import Combine
import UIKit

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

    static func timestampString(from date: Date) -> String {
        timestampFormatter.string(from: date)
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

struct DiagnosticExportContext {
    let appVersion: String
    let build: String
    let deviceName: String
    let dsmVersion: String?
    let connectionMode: String
    let activeRoute: String
    let cachedSnapshotSavedAt: Date?

    var exportLines: [String] {
        var lines = [
            "App: \(appVersion) (\(build))",
            "iOS: \(UIDevice.current.systemVersion)",
            "Device: \(UIDevice.current.model)",
            "NAS: \(DiagnosticLogStore.redactedDetail(deviceName))",
            "Connection: \(connectionMode)",
            "Route: \(activeRoute)"
        ]
        if let dsmVersion {
            lines.append("DSM: \(DiagnosticLogStore.redactedDetail(dsmVersion))")
        }
        if let cachedSnapshotSavedAt {
            lines.append("Cached snapshot: \(DiagnosticLogEntry.timestampString(from: cachedSnapshotSavedAt))")
        }
        return lines
    }
}

final class DiagnosticLogStore: ObservableObject {
    static let shared = DiagnosticLogStore()

    @Published private(set) var entries: [DiagnosticLogEntry] = []

    #if DEBUG
    private static let debugConsole = Logger(subsystem: "com.changliwen.nastart", category: "diagnostics")
    #endif
    private let maxEntries = 1000
    private let persistenceKey: String
    private let defaults: UserDefaults
    private let persistenceQueue = DispatchQueue(
        label: "com.changliwen.nastart.diagnostics-persistence",
        qos: .utility
    )
    private var pendingPersistenceTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard, persistenceKey: String = "diagnostics.entries.v1") {
        self.defaults = defaults
        self.persistenceKey = persistenceKey
        guard
            let data = defaults.data(forKey: persistenceKey),
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
        let detail = Self.redactedDetails(details)

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
        let defaults = self.defaults
        persistenceQueue.async {
            defaults.removeObject(forKey: persistenceKey)
        }
    }

    @MainActor
    func exportText(context: DiagnosticExportContext? = nil) -> String {
        if entries.isEmpty {
            return NSLocalizedString("diagnostics.empty", comment: "")
        }
        let header = String.localizedStringWithFormat(
            NSLocalizedString("diagnostics.export.header", comment: ""),
            entries.count,
            entries.filter { $0.level == .warning }.count,
            entries.filter { $0.level == .error }.count
        )
        let contextLines = context.map {
            ["", NSLocalizedString("diagnostics.export.context", comment: "")]
                + $0.exportLines
                + [""]
        } ?? []
        return ([header] + contextLines + entries.map(\.exportLine)).joined(separator: "\n")
    }

    /// Format before storing, so a sensitive field does not need to repeat its
    /// key inside its value to be protected. Existing numeric telemetry stays intact.
    static func redactedDetails(_ details: [String: String]) -> String {
        details.filter { !$0.value.isEmpty }.sorted { $0.key < $1.key }.map { field in
            let normalizedKey = field.key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let sensitive = sensitiveFieldExpression?.firstMatch(in: normalizedKey,
                range: NSRange(normalizedKey.startIndex..., in: normalizedKey)) != nil
            let value = sensitive ? "<redacted>" : redactedDetail(field.value)
            return "\(redactedDetail(field.key))=\(value)"
        }.joined(separator: ", ")
    }

    /// Best-effort protection for exported free text, not an anonymity guarantee.
    /// Only data exports mask structurally recognizable scheme-less addresses.
    /// Dotted names without address structure remain ambiguous, not anonymous.
    static func redactedExportText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.contains(where: \.isWhitespace),
           let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return redactedURL(url)
        }

        var result = value
        if let tokens = exportAddressTokens {
            for match in tokens.matches(in: value, range: NSRange(value.startIndex..., in: value)).reversed() {
                guard let range = Range(match.range, in: result),
                      let replacement = redactedBareExportToken(String(result[range])) else { continue }
                result.replaceSubrange(range, with: replacement)
            }
        }
        return redactedSensitiveText(result)
    }

    private static let exportAddressTokens = try? NSRegularExpression(pattern: #"[^\s<>\"']+"#)
    private static let bareExportAddress = try? NSRegularExpression(pattern:
        #"(?i)^(?://)?(?:[^/\s@]+@)?(?:localhost|\[[0-9a-f:.%]+\]|(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z](?:[a-z0-9-]*[a-z0-9])?|(?:[0-9]{1,3}\.){3}[0-9]{1,3})(?::[^/\s?#]+)?(?:[/?#][^\s]*)?$"#)

    private static func redactedBareExportToken(_ token: String) -> String? {
        if isBareExportAddress(token) { return "<redacted-address>" }
        guard let separator = token.firstIndex(where: { $0 == "=" || $0 == ":" }) else { return nil }
        let label = token[..<separator]
        let address = String(token[token.index(after: separator)...])
        guard let first = label.first, first.isLetter || first == "_",
              label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }),
              // Keep explicit URL schemes on the established URL-redaction path.
              !(token[separator] == ":" && address.hasPrefix("//")),
              isBareExportAddress(address) else { return nil }
        return String(token[...separator]) + "<redacted-address>"
    }

    private static func isBareExportAddress(_ token: String) -> Bool {
        guard bareExportAddress?.firstMatch(in: token,
            range: NSRange(token.startIndex..., in: token)) != nil else { return false }
        let authority = token.prefix { !"/?#".contains($0) }.lowercased()
        let octets = authority.split(separator: ".", omittingEmptySubsequences: false)
        let ipv4 = octets.count == 4 && octets.allSatisfy { part in
            guard let value = Int(part) else { return false }
            return (0...255).contains(value)
        }
        return token.contains(where: { "/?#@:".contains($0) }) || ipv4
            || authority.hasPrefix("[") || authority == "localhost" || authority.hasSuffix(".local")
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
        redactedSensitiveText(value)
    }

    private static let sensitiveFieldNames = #"_sid|sid|api[_-]?key|apikey|token|access[_-]?token|refresh[_-]?token|authorization|password|passwd|(?:set[_-]?)?cookie|client[_-]?secret|path|filepath|filename|file_name"#

    private static let sensitiveFieldExpression = try? NSRegularExpression(pattern: "^(?:\(sensitiveFieldNames))$")
    private static let embeddedURLExpression = try? NSRegularExpression(pattern: #"(?i)\b[a-z][a-z0-9+.-]*://[^\s<>\"']+"#)
    private static let sensitiveTextReplacements: [(NSRegularExpression, String)] = {
        let key = #"(?i)((?<![\p{L}\p{N}_])["']?(?:"# + sensitiveFieldNames + #")["']?\s*[=:]\s*)"#
        let patterns: [(String, String)] = [
            (key + #"\"(?:\\.|[^\"\\])*\""#, "$1\"<redacted>\""),
            (key + #"'(?:\\.|[^'\\])*'"#, "$1'<redacted>'"),
            (key + #"\"(?:\\.|[^\"\\])*(?:\\)?$"#, "$1\"<redacted>\""),
            (key + #"'(?:\\.|[^'\\])*(?:\\)?$"#, "$1'<redacted>'"),
            // An unquoted value may contain spaces. Mask conservatively through
            // the next field delimiter instead of exposing the remaining words.
            (key + #"[^\s\"',;&}\]\r\n][^\"',;&}\]\r\n]*"#, "$1<redacted>"),
            (#"(?i)\b(bearer|basic)\s+[a-z0-9._~+/=-]+"#, "$1 <redacted>"),
            (#"(?i)((?:pairing[_ -]?code|pairing)\s*[=:]\s*)[0-9]{6}\b"#, "$1<redacted>")
        ]
        return patterns.compactMap { pattern, replacement in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
            return (expression, replacement)
        }
    }()

    private static func redactedSensitiveText(_ value: String) -> String {
        var result = value
        if let urls = embeddedURLExpression {
            for match in urls.matches(in: result, range: NSRange(result.startIndex..., in: result)).reversed() {
                guard let range = Range(match.range, in: result) else { continue }
                let address = String(result[range])
                let replacement: String
                if let url = URL(string: address), url.host != nil { replacement = redactedURL(url) }
                else { replacement = "<redacted-url>" }
                result.replaceSubrange(range, with: replacement)
            }
        }

        for (expression, replacement) in sensitiveTextReplacements {
            result = expression.stringByReplacingMatches(in: result,
                range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
        }
        return result
    }

    @MainActor
    private func append(_ entry: DiagnosticLogEntry) {
        entries.append(entry)
        #if DEBUG
        // iOS 17+ redacts NSLog arguments in the device console, which hides playback
        // timing during real-device runs. The line has already been sanitized.
        Self.debugConsole.log("\(entry.exportLine, privacy: .public)")
        #else
        NSLog("%@", entry.exportLine)
        #endif
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
        schedulePersistence(immediately: entry.level == .error)
    }

    @MainActor
    private func schedulePersistence(immediately: Bool) {
        // Keep a fixed batch deadline while events continue arriving. A
        // trailing debounce can postpone all on-disk diagnostics indefinitely
        // during playback. Errors still preempt the pending batch.
        if pendingPersistenceTask != nil, !immediately { return }
        pendingPersistenceTask?.cancel()
        pendingPersistenceTask = Task { @MainActor [weak self] in
            if !immediately {
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            guard !Task.isCancelled, let self else { return }
            self.pendingPersistenceTask = nil
            let snapshot = self.entries
            let persistenceKey = self.persistenceKey
            let defaults = self.defaults
            self.persistenceQueue.async {
                guard let data = try? JSONEncoder().encode(snapshot) else { return }
                defaults.set(data, forKey: persistenceKey)
            }
        }
    }
}

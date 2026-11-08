#if DEBUG && os(tvOS)
import Foundation

/// Opted-in offline fixtures only. No observable state or focus mutations.
/// Targets are local numeric tokens; raw IDs, names and source paths never leave the view.
@MainActor enum MediaDetailFocusDiagnostics {
    private static var handle: FileHandle?
    private static var sequence = 0
    private static var tokens: [String: Int] = [:]
    private static let limit = 2048
    private static func token(_ value: String?) -> Any {
        guard let value else { return NSNull() }
        if let token = tokens[value] { return token }
        let token = tokens.count + 1; tokens[value] = token; return token
    }
    static func record(_ event: String, controller: String, render: String?, revision: String,
                       session: MediaDetailFocusSession, target: String?, binding: String?) {
        guard sequence < limit else { return }
        if handle == nil {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Nastart-Offline-Focus.jsonl")
            guard FileManager.default.createFile(atPath: url.path, contents: nil,
                attributes: [.posixPermissions: 0o600]) else { return }
            handle = try? FileHandle(forWritingTo: url)
        }
        guard let handle else { return }
        sequence += 1
        let map = session.map
        let row: [String: Any] = ["schema": 1, "seq": sequence, "uptime": ProcessInfo.processInfo.systemUptime,
            "event": event, "controller": controller, "render": render.map { $0 as Any } ?? NSNull(), "revision": revision,
            "target": token(target), "binding": token(binding), "focused": token(session.focused),
            "requested": token(session.requested), "owner": token(session.owner),
            "actions": map.actions.map { token($0) }, "fileChoices": map.fileChoices.map { token($0) },
            "people": map.people.map { token($0) }, "files": token(map.files),
            "native": session.nativeIDs.sorted().map { token($0) }]
        guard var data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) else { return }
        data.append(0x0a)
        try? handle.write(contentsOf: data)
    }
}
#endif

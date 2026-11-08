#if DEBUG && os(iOS)
import SwiftUI
import UIKit

/// Only the synthetic, early offline form and password probe scenes opt in.
/// Never inspect text, placeholders, lengths or selection offsets.
/// Observation covers every UITextField in the probe window (at most eight) so that controls
/// without a password content type, bare SwiftUI and bare UIKit probes are visible too.
@MainActor enum PasswordInputDiagnostics {
    private static weak var window: UIWindow?
    private static let ids = NSMapTable<UITextField, NSNumber>.weakToStrongObjects()
    private static var nextID = 0
    private static var sequence = 0
    private static var output: FileHandle?
    private static var attemptedOpen = false
    /// Optional pairing label from the validated launch argument; contains no input data.
    private static let cell: String? = OfflineUIConfiguration.requested(
        arguments: ProcessInfo.processInfo.arguments)?.passwordProbe.cell
    private static let roles: Set<String> = ["password", "username", "name", "address", "port", "path"]
    /// Static identifier tail only (never text or placeholder); unknown identifiers become "other".
    private static func role(of field: UITextField) -> String {
        guard let tail = field.accessibilityIdentifier?.split(separator: ".").last.map(String.init),
              roles.contains(tail) else { return "other" }
        return tail
    }
    static func attach(_ value: UIWindow?) {
        if let value { window = value }
        record(value == nil ? "probe.detach" : "probe.attach")
    }
    private static func token(for field: UITextField) -> Int {
        if let existing = ids.object(forKey: field) { return existing.intValue }
        nextID += 1
        ids.setObject(NSNumber(value: nextID), forKey: field)
        return nextID
    }
    static func observes(_ field: UITextField) -> Bool {
        if let window, field.window === window { return true }
        return ids.object(forKey: field) != nil
    }
    static func record(_ event: String, focus: String? = nil, visible: Bool? = nil, source: UITextField? = nil) {
        guard ProcessInfo.processInfo.arguments.contains("--offline-password-trace"),
              ProcessInfo.processInfo.arguments.contains("--offline-ui"), sequence < 1024 else { return }
        if !attemptedOpen {
            attemptedOpen = true
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Nastart-Offline-Password.jsonl")
            if FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) {
                output = try? FileHandle(forWritingTo: url)
            }
        }
        guard let output else { return }
        func fields(_ view: UIView) -> [UITextField] {
            let own = (view as? UITextField).map { [$0] } ?? []
            return own + view.subviews.flatMap(fields)
        }
        let native: [[String: Any]] = (window.map(fields) ?? []).prefix(8).map { field in
            let selection = field.selectedTextRange
            return ["token": token(for: field), "firstResponder": field.isFirstResponder, "secure": field.isSecureTextEntry,
                    "attached": field.window != nil, "clearsOnInsertion": field.clearsOnInsertion,
                    "clearsOnBeginEditing": field.clearsOnBeginEditing,
                    "selectionKnown": selection != nil, "selectionEmpty": selection?.isEmpty ?? false,
                    "markedTextPresent": field.markedTextRange != nil,
                    "role": role(of: field), "contentTypePassword": field.textContentType == .password,
                    "contentTypeUsername": field.textContentType == .username]
        }
        sequence += 1
        var row: [String: Any] = ["sequence": sequence, "uptime": ProcessInfo.processInfo.systemUptime,
                                  "event": event, "native": native]
        if let cell { row["cell"] = cell }
        if let focus { row["focus"] = focus }
        if let visible { row["visible"] = visible }
        if let source, observes(source) { row["sourceToken"] = token(for: source) }
        if let data = try? JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]) {
            try? output.write(contentsOf: data + Data([10]))
        }
    }
}

struct PasswordInputDiagnosticsProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }
    func updateUIView(_ uiView: Probe, context: Context) { PasswordInputDiagnostics.record("probe.update") }
    final class Probe: UIView {
        private var observers: [NSObjectProtocol] = []
        override init(frame: CGRect) {
            super.init(frame: frame)
            for (name, event) in [(UITextField.textDidBeginEditingNotification, "native.begin"),
                                  (UITextField.textDidEndEditingNotification, "native.end"),
                                  (UITextField.textDidChangeNotification, "native.change"),
                                  (UIResponder.keyboardWillShowNotification, "keyboard.willShow"),
                                  (UIResponder.keyboardWillHideNotification, "keyboard.willHide")] {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { note in
                    // Ignore other fields. Keyboard notifications carry no input content here.
                    MainActor.assumeIsolated {
                        let source = note.object as? UITextField
                        if let source, !PasswordInputDiagnostics.observes(source) { return }
                        PasswordInputDiagnostics.record(event, source: source)
                    }
                })
            }
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func didMoveToWindow() { super.didMoveToWindow(); PasswordInputDiagnostics.attach(window) }
        override func layoutSubviews() { super.layoutSubviews(); PasswordInputDiagnostics.record("probe.layout") }
        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
#endif

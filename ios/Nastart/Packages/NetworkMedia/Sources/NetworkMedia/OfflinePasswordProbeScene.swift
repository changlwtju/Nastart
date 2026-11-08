#if DEBUG && os(iOS)
import SwiftUI
import UIKit

/// Attribution fixture for the password first-edit experiment (not form acceptance).
/// Owns only ephemeral synthetic state: no model, store, vault, client or network.
/// The prefilled value is the fixed fixture constant also used by OfflineWebDAVFormScene.
struct OfflinePasswordProbeScene: View {
    let configuration: OfflineUIConfiguration
    let appearance: NetworkMediaAppearance
    @State private var username = "preview-user"
    @State private var password: String
    @FocusState private var focus: Field?
    private enum Field: Hashable { case username, password }

    init(configuration: OfflineUIConfiguration, appearance: NetworkMediaAppearance) {
        self.configuration = configuration; self.appearance = appearance
        _password = State(initialValue: configuration.passwordProbe.isPrefilled ? "preview-only" : "")
    }
    private var options: PasswordProbeOptions { configuration.passwordProbe }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("密码探针").font(.headline)
            TextField("用户名", text: $username)
                .textFieldStyle(.roundedBorder)
                .textContentType(options.contentTypesEnabled ? .username : nil)
                .accessibilityIdentifier("offline.probe.username")
            if configuration.scenario == .passwordProbeUIKit {
                OfflineUIKitPasswordField(options: options).frame(height: 44)
            } else if options.modifiers == .form {
                formLikeSwiftUIControl
            } else {
                bareSwiftUIControl
            }
            Spacer(minLength: 0)
            Text("离线界面测试 · 合成密码探针 · 归因实验，不是表单验收")
                .font(.caption2).dynamicTypeSize(.large).foregroundStyle(.secondary)
        }
        .padding(18)
        .background { appearance.background.ignoresSafeArea() }
        .background {
            if ProcessInfo.processInfo.arguments.contains("--offline-password-trace") { PasswordInputDiagnosticsProbe() }
        }
        .onChange(of: password) { _ in trace("swift.password.changed") }
    }
    /// Event name only; PasswordInputDiagnostics itself requires --offline-ui and --offline-password-trace.
    private func trace(_ event: String) { PasswordInputDiagnostics.record(event, focus: focus.map { String(describing: $0) } ?? "none") }

    /// Only the state binding, the secure/plain choice, and the content type under test.
    @ViewBuilder private var bareSwiftUIControl: some View {
        if options.isSecure {
            SecureField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(options.contentTypesEnabled ? .password : nil)
                .accessibilityIdentifier("offline.probe.password")
        } else {
            TextField("密码", text: $password)
                .textFieldStyle(.roundedBorder)
                .textContentType(options.contentTypesEnabled ? .password : nil)
                .accessibilityIdentifier("offline.probe.password")
        }
    }

    /// The production password row's own modifier chain and FocusState, still without
    /// the page container, input style, busy handling or visibility toggle.
    @ViewBuilder private var formLikeSwiftUIControl: some View {
        Group {
            if options.isSecure { SecureField("密码", text: $password) } else { TextField("密码", text: $password) }
        }
        .textFieldStyle(.roundedBorder)
        .autocorrectionDisabled().textInputAutocapitalization(.never)
        .textContentType(options.contentTypesEnabled ? .password : nil)
        .focused($focus, equals: .password).submitLabel(.next).onSubmit { focus = nil }
        .accessibilityLabel("密码").accessibilityIdentifier("offline.probe.password").privacySensitive()
    }
}

/// A bare UITextField: no delegate, no SwiftUI binding, no text writes after creation.
/// Hosted inside SwiftUI, so this is not a pure UIKit app; it only removes SwiftUI's own field bridge.
private struct OfflineUIKitPasswordField: UIViewRepresentable {
    let options: PasswordProbeOptions
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.borderStyle = .roundedRect
        field.placeholder = "密码"
        field.isSecureTextEntry = options.isSecure
        field.textContentType = options.contentTypesEnabled ? .password : nil
        field.text = options.isPrefilled ? "preview-only" : ""
        field.accessibilityIdentifier = "offline.probe.password"
        return field
    }
    func updateUIView(_ uiView: UITextField, context: Context) {}
}
#endif

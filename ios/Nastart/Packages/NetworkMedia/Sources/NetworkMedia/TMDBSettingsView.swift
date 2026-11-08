#if os(iOS) || os(tvOS)
import SwiftUI
import Security

/// This device only, never synchronised, never in the media index or a log.
enum TMDBCredentialVault {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "Nastart") + ".tmdb",
         kSecAttrAccount as String: "api-credential",
         kSecAttrSynchronizable as String: false]
    }
    static func load() -> TMDBCredential? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(attributes as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let text = String(data: data, encoding: .utf8) else { return nil }
        return TMDBCredential(text)
    }
    static func save(_ credential: TMDBCredential) throws {
        remove()
        var attributes = query
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecValueData as String] = Data(credential.value.utf8)
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else { throw NetworkMediaError.localStore }
    }
    static func remove() { SecItemDelete(query as CFDictionary) }
}

extension TMDBService {
    static let shared = TMDBService(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "Nastart", isDirectory: true)
            .appendingPathComponent("NetworkMediaTMDB", isDirectory: true),
        credential: { TMDBCredentialVault.load() })
}

enum TMDBPreference {
    static let enabledKey = "network.tmdb.enabled"
}

@MainActor struct NetworkTMDBSettingsView: View {
    @ObservedObject var model: NetworkLibrariesModel
    @Environment(\.dismiss) private var dismiss
    @State private var credentialText = ""
    @State private var saved = TMDBCredentialVault.load() != nil
    @State private var verifying = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("补全缺失的海报和资料", isOn: Binding(get: { model.tmdbEnabled && saved }, set: { model.tmdbEnabled = $0 }))
                        .disabled(!saved).accessibilityIdentifier("network.tmdb.enabled")
                } footer: {
                    Text("开启后，缺少海报或资料的作品会把片名和年份发送给 TMDB。NAS 上已有的 NFO 和海报优先，也不会修改 NAS 上的文件。无法确定是哪部作品时不会填充。")
                }
                Section("TMDB 凭据") {
                    if saved {
                        Label("已保存在本机钥匙串", systemImage: "checkmark.circle")
                        Button("删除凭据和本机缓存", role: .destructive) { removeCredential() }
                            .accessibilityIdentifier("network.tmdb.remove")
                    } else {
                        SecureField("API 读访问令牌", text: $credentialText)
                            .autocorrectionDisabled().textInputAutocapitalization(.never).privacySensitive()
                            .accessibilityIdentifier("network.tmdb.credential")
                        Button(verifying ? "正在验证…" : "验证并保存") { verifyAndSave() }
                            .disabled(verifying || credentialText.isEmpty)
                            .accessibilityIdentifier("network.tmdb.save")
                    }
                    if let message { Text(networkText(message)).font(NetworkType.caption).foregroundStyle(.secondary) }
                }
                Section {
                    // TMDB requires this notice as worded.
                    Text(verbatim: "This product uses the TMDB API but is not endorsed or certified by TMDB.")
                        .font(NetworkType.caption).foregroundStyle(.secondary)
                } header: { Text("资料来源") }
            }
            .navigationTitle("TMDB 资料补全")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.accessibilityIdentifier("network.tmdb.done") } }
            #endif
        }
    }
    private func verifyAndSave() {
        guard let credential = TMDBCredential(credentialText) else { message = "凭据格式不正确，请重新复制完整内容。"; return }
        verifying = true; message = nil
        Task {
            defer { verifying = false }
            do {
                try await TMDBService.shared.verify(credential)
                try TMDBCredentialVault.save(credential)
                credentialText = ""; saved = true; message = "验证成功，打开上方开关即可使用。"
            } catch TMDBError.invalidCredential { message = "TMDB 拒绝了这个凭据，请检查是否复制完整。"
            } catch TMDBError.rateLimited { message = "请求过于频繁，请稍后再试。"
            } catch NetworkMediaError.localStore { message = "无法保存到钥匙串，请重试。"
            } catch { message = "暂时连不上 TMDB，请检查当前网络能否访问 themoviedb.org。" }
        }
    }
    private func removeCredential() {
        TMDBCredentialVault.remove()
        model.tmdbEnabled = false; saved = false; message = nil
        DecodedArtworkCache.shared.removeAll()
        Task { await TMDBService.shared.clear() }
    }
}
#endif

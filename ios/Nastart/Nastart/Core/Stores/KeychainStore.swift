import Foundation
import Security

enum KeychainStoreError: LocalizedError {
    case encodingFailed
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        NSLocalizedString("keychain.save_failed", comment: "")
    }
}
final class KeychainStore {
    static let shared = KeychainStore()

    private let service = "com.nastart.app.nas"
    private let jellyfinService = "com.nastart.app.jellyfin"
    private let agentService = "com.nastart.app.agent"
    private let sshHostKeyService = "com.nastart.app.ssh-host-keys"
    private let primaryNASAccount = "primary-nas"

    private init() {}

    func saveNASCredential(_ credential: StoredNASCredential) throws {
        guard let data = try? JSONEncoder().encode(credential) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: baseQuery(account: primaryNASAccount))
    }

    func loadNASCredential() -> StoredNASCredential? {
        var query = baseQuery(account: primaryNASAccount)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredNASCredential.self, from: data)
    }

    func clearNASCredentials() {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ] as CFDictionary)
    }

    func saveJellyfinSession(_ session: StoredJellyfinSession, endpoint: URL) throws {
        guard let data = try? JSONEncoder().encode(session) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: jellyfinQuery(endpoint: endpoint))
    }

    func loadJellyfinSession(endpoint: URL) -> StoredJellyfinSession? {
        var query = jellyfinQuery(endpoint: endpoint)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(StoredJellyfinSession.self, from: data)
    }

    func clearJellyfinSession(endpoint: URL) {
        SecItemDelete(jellyfinQuery(endpoint: endpoint) as CFDictionary)
    }

    func saveAgentConnection(_ connection: StoredAgentConnection) throws {
        guard let data = try? JSONEncoder().encode(connection) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: agentQuery())
    }

    func loadAgentConnection() -> StoredAgentConnection? {
        var query = agentQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return try? JSONDecoder().decode(StoredAgentConnection.self, from: data)
    }

    func clearAgentConnection() {
        SecItemDelete(agentQuery() as CFDictionary)
    }

    func saveSSHHostKey(_ openSSHKey: String, host: String, port: Int) throws {
        guard let data = openSSHKey.data(using: .utf8) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: sshHostKeyQuery(host: host, port: port))
    }

    func loadSSHHostKey(host: String, port: Int) -> String? {
        var query = sshHostKeyQuery(host: host, port: port)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
            let data = result as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func save(data: Data, query: [String: Any]) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainStoreError.unexpectedStatus(updateStatus)
        }

        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainStoreError.unexpectedStatus(addStatus)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private func jellyfinQuery(endpoint: URL) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jellyfinService,
            kSecAttrAccount as String: endpoint.absoluteString
        ]
    }

    private func agentQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: agentService,
            kSecAttrAccount as String: "primary-agent"
        ]
    }

    private func sshHostKeyQuery(host: String, port: Int) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: sshHostKeyService,
            kSecAttrAccount as String: "\(host.lowercased()):\(port)"
        ]
    }
}

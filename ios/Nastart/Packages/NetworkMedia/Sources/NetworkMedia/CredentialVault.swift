#if os(iOS) || os(tvOS)
import Foundation
import Security

/// Credentials belong to this app, this source ID and this exact canonical endpoint.
/// They are never encoded in the media index or synchronised to another device.
enum NetworkCredentialVault {
    static func save(_ credential: WebDAVCredential, connection: NetworkStorageConnection) throws {
        try save(credential, library: connection.credentialLibrary())
    }
    static func load(_ connection: NetworkStorageConnection) throws -> WebDAVCredential { try load(connection.credentialLibrary()) }
    private struct Record: Codable { let address: String; let username: String; let password: String }
    private static func query(_ id: UUID) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "Nastart") + ".network-media",
         kSecAttrAccount as String: id.uuidString,
         kSecAttrSynchronizable as String: false]
    }
    static func save(_ credential: WebDAVCredential, library: NetworkLibrary) throws {
        var attributes = query(library.id)
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        attributes[kSecValueData as String] = try JSONEncoder().encode(Record(address: library.address, username: credential.username, password: credential.password))
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            LocalStorageDiagnostics.record("credential-add", error: NSError(domain: NSOSStatusErrorDomain, code: Int(status)))
            throw NetworkMediaError.localStore
        }
    }
    static func load(_ library: NetworkLibrary) throws -> WebDAVCredential {
        var attributes = query(library.id)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(attributes as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data, let record = try? JSONDecoder().decode(Record.self, from: data),
              record.address == library.address else { throw NetworkMediaError.localStore }
        return WebDAVCredential(username: record.username, password: record.password)
    }
    static func remove(_ id: UUID) { SecItemDelete(query(id) as CFDictionary) }
}
#endif

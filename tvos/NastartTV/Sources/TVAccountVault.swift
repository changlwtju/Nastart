import Foundation
import Security
import CryptoKit

/// The TV has its own login. No credentials are copied from another device.
enum TVAccountVault {
    private static let service = "com.changliwen.nastart.tv.account"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "current"]
    }
    static func load<T: Decodable>(_ type: T.Type = TVAccount.self, nas: Bool = false) -> T? {
        load(type, slot: nas ? "nas" : "current")
    }
    private static func load<T: Decodable>(_ type: T.Type, slot: String) -> T? {
        var request = query
        request[kSecAttrAccount as String] = slot
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func save<T: Encodable>(_ account: T, nas: Bool = false) throws {
        try save(account, slot: nas ? "nas" : "current")
    }
    private static func save<T: Encodable>(_ account: T, slot: String) throws {
        var query = query
        query[kSecAttrAccount as String] = slot
        let data = try JSONEncoder().encode(account)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var request = query
            request[kSecValueData as String] = data
            request[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let added = SecItemAdd(request as CFDictionary, nil)
            guard added == errSecSuccess else { throw TVClientError.keychain(added) }
        } else if status != errSecSuccess { throw TVClientError.keychain(status) }
    }
    static func clear(nas: Bool = false) throws {
        try clear(slot: nas ? "nas" : "current")
    }
    private static func clear(slot: String) throws {
        var query = query
        query[kSecAttrAccount as String] = slot
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TVClientError.keychain(status) }
    }

    private static func passwordSlot(for account: TVAccount) -> String {
        let identity = Data((account.server.absoluteString + "\n" + account.userID).utf8)
        return "jellyfin.password." + SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
    }

    static func savePassword(_ password: String, for account: TVAccount) throws {
        try save(password, slot: passwordSlot(for: account))
    }
    static func password(for account: TVAccount) -> String? {
        load(String.self, slot: passwordSlot(for: account))
    }
    static func clearPassword(for account: TVAccount) throws {
        try clear(slot: passwordSlot(for: account))
    }
}

import Foundation
import Security

/// The TV has its own login. No credentials are copied from another device.
enum TVAccountVault {
    private static let service = "com.changliwen.nastart.tv.account"
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: "current"]
    }
    static func load<T: Decodable>(_ type: T.Type = TVAccount.self, nas: Bool = false) -> T? {
        var request = query
        if nas { request[kSecAttrAccount as String] = "nas" }
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func save<T: Encodable>(_ account: T, nas: Bool = false) throws {
        var query = query
        if nas { query[kSecAttrAccount as String] = "nas" }
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
        var query = query
        if nas { query[kSecAttrAccount as String] = "nas" }
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TVClientError.keychain(status) }
    }
}

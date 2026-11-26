import Foundation
import Security
#if os(iOS)
import UIKit

@MainActor
enum JellyfinDeviceIdentity {
    private(set) static var storageStatus = "unchecked"

    static let persistentDeviceID: String = {
        let vendorID = UIDevice.current.identifierForVendor?.uuidString
        do {
            if let stored = try KeychainStore.shared.loadJellyfinDeviceID(),
               !stored.deviceID.isEmpty, vendorID == nil || stored.vendorID == vendorID {
                storageStatus = "restored"
                return stored.deviceID
            }
            let deviceID = UUID().uuidString
            try KeychainStore.shared.saveJellyfinDeviceID(
                StoredJellyfinDeviceID(deviceID: deviceID, vendorID: vendorID ?? ""))
            UserDefaults.standard.removeObject(forKey: "jellyfin.client.device-id")
            storageStatus = "created"
            return deviceID
        } catch {
            // All clients keep one identifier for this process, even if
            // Keychain is locked. Never replace an unreadable Keychain record.
            storageStatus = "unavailable"
            return UUID().uuidString
        }
    }()
}
#endif

/// Both library and file playback must look up the same endpoint-scoped accounts.
/// Path aliases stay on explicitly configured origins; no new host/port is inferred.
enum JellyfinSessionEndpointPolicy {
    struct SavedCandidate {
        let endpoint: URL
        let session: StoredJellyfinSession
        let modificationDate: Date?

        var hasOwnSession: Bool {
            session.endpointString == endpoint.absoluteString
                && !session.userID.isEmpty && !session.accessToken.isEmpty
        }

        func matchesSession(_ current: StoredJellyfinSession?) -> Bool {
            guard let current else { return false }
            return current.endpointString == session.endpointString && current.userID == session.userID
                && current.accessToken == session.accessToken && current.serverID == session.serverID
                && current.username == session.username
        }
    }

    static func preferredSavedSession(_ candidates: [SavedCandidate]) -> SavedCandidate? {
        var selected: SavedCandidate?
        for candidate in candidates where candidate.hasOwnSession {
            if selected == nil || (candidate.modificationDate ?? .distantPast)
                > (selected?.modificationDate ?? .distantPast) {
                selected = candidate
            }
        }
        return selected
    }

    static func canRecoverRejectedSession(_ candidate: SavedCandidate, from endpoint: URL,
                                          restoredUserID: String, savedAt: Date?,
                                          verifiedLANEndpoint: URL?) -> Bool {
        guard candidate.hasOwnSession, candidate.endpoint != endpoint,
              candidate.endpoint == verifiedLANEndpoint else { return false }
        // A saved date orders initial restores, but it cannot tell whether the
        // endpoint's own token still works. Probe the same account even if its
        // LAN token was saved earlier; the caller verifies it before switching.
        if candidate.session.userID == restoredUserID { return true }
        guard let savedAt, let candidateDate = candidate.modificationDate else { return false }
        return candidateDate > savedAt
    }

    /// Reuse only a login for the public candidate's current server ID. When
    /// replacing a rejected login, restrict the source to the same account's
    /// LAN login with a different token. Both paths still need /Users/Me proof.
    static func crossEndpointSource(for candidate: URL, publicServerID: String,
                                    saved: [SavedCandidate], replacing rejected: SavedCandidate? = nil) -> SavedCandidate? {
        guard candidate.scheme?.lowercased() == "https",
              let host = candidate.host, !NetworkHostClassifier.isPrivate(host),
              !publicServerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let rejected {
            guard rejected.endpoint == candidate, rejected.hasOwnSession,
                  rejected.session.serverID == nil || rejected.session.serverID == publicServerID else { return nil }
        }
        var selected: SavedCandidate?
        for source in saved where source.hasOwnSession && source.endpoint != candidate
            && source.session.serverID == publicServerID {
            if let rejected {
                guard NetworkHostClassifier.isPrivate(source.endpoint.host),
                      source.session.userID == rejected.session.userID,
                      source.session.accessToken != rejected.session.accessToken else { continue }
            }
            if selected == nil || (source.modificationDate ?? .distantPast)
                > (selected?.modificationDate ?? .distantPast) {
                selected = source
            }
        }
        return selected
    }

    static func acceptsCrossEndpointIdentity(_ identity: JellyfinAuthenticatedIdentity?,
                                             source: SavedCandidate) -> Bool {
        guard let identity, let serverID = source.session.serverID, !serverID.isEmpty else { return false }
        return identity.userID == source.session.userID && identity.serverID == serverID
    }

    static func copy(_ session: StoredJellyfinSession, for endpoint: URL) -> StoredJellyfinSession {
        StoredJellyfinSession(endpointString: endpoint.absoluteString, userID: session.userID,
                              username: session.username, accessToken: session.accessToken,
                              serverID: session.serverID)
    }

    static func configuredEndpoints(for service: LaunchpadService, dsmBaseURL: URL?) -> [URL] {
        let effective = ServiceEndpointOverrides.load(service: service, deviceHost: dsmBaseURL?.host)
            ?? service.preferredEndpoint(for: dsmBaseURL)
        return [effective, service.endpoint, service.alternateEndpoint].compactMap { $0 }
    }

    static func candidates(from endpoints: [URL]) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        for endpoint in endpoints {
            for path in [endpoint.path, "/jellyfin", "/emby"] {
                guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
                    continue
                }
                components.path = path == "/" ? "" : path
                components.query = nil
                components.fragment = nil
                guard let candidate = components.url,
                      seen.insert(candidate.absoluteString).inserted else { continue }
                result.append(candidate)
            }
        }
        return result
    }
}

/// A per-device Jellyfin client identifier. It is deliberately not a
/// UserDefaults value: a backup restore copies UserDefaults to another
/// phone, and two phones sharing one DeviceId revoke each other's tokens
/// (Jellyfin keeps one token per DeviceId). The keychain record survives
/// delete + reinstall and, with `ThisDeviceOnly`, never migrates to
/// another device. `vendorID` is the identifierForVendor seen when the
/// record was minted; a different vendor on launch means the backup
/// landed on different hardware, so a fresh DeviceId is minted.
struct StoredJellyfinDeviceID: Codable {
    let deviceID: String
    let vendorID: String
}

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

    func loadJellyfinRestoreCandidate(endpoint: URL) -> JellyfinSessionEndpointPolicy.SavedCandidate? {
        var query = jellyfinQuery(endpoint: endpoint)
        query[kSecReturnData as String] = true
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let item = result as? [String: Any],
              let data = item[kSecValueData as String] as? Data,
              let session = try? JSONDecoder().decode(StoredJellyfinSession.self, from: data) else { return nil }
        return .init(endpoint: endpoint, session: session,
                     modificationDate: item[kSecAttrModificationDate as String] as? Date)
    }

    /// Every saved Jellyfin login, keyed by the endpoint it was saved for.
    func loadAllJellyfinRestoreCandidates() -> [JellyfinSessionEndpointPolicy.SavedCandidate] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jellyfinService,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let account = item[kSecAttrAccount as String] as? String,
                  let endpoint = URL(string: account),
                  let data = item[kSecValueData as String] as? Data,
                  let session = try? JSONDecoder().decode(StoredJellyfinSession.self, from: data) else { return nil }
            return .init(endpoint: endpoint, session: session,
                         modificationDate: item[kSecAttrModificationDate as String] as? Date)
        }
    }

    func clearJellyfinSession(endpoint: URL) {
        SecItemDelete(jellyfinQuery(endpoint: endpoint) as CFDictionary)
    }

    func saveJellyfinDeviceID(_ record: StoredJellyfinDeviceID) throws {
        guard let data = try? JSONEncoder().encode(record) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: jellyfinDeviceIDQuery(),
                 accessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
    }

    func loadJellyfinDeviceID() throws -> StoredJellyfinDeviceID? {
        var query = jellyfinDeviceIDQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainStoreError.unexpectedStatus(status)
        }
        return try? JSONDecoder().decode(StoredJellyfinDeviceID.self, from: data)
    }

    /// The Jellyfin password for one server account, kept only so a revoked
    /// token can be renewed without asking the user again. Never in
    /// UserDefaults, never logged, never synced to another device. The
    /// account is `serverID:userID:password`; the password is dropped on
    /// explicit sign-out and when the server rejects the credentials
    /// themselves (401).
    func saveJellyfinPassword(_ password: String, serverID: String, userID: String) throws {
        guard !serverID.isEmpty, !userID.isEmpty, !password.isEmpty,
              let data = password.data(using: .utf8) else {
            throw KeychainStoreError.encodingFailed
        }
        try save(data: data, query: jellyfinPasswordQuery(serverID: serverID, userID: userID),
                 accessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    }

    func loadJellyfinPassword(serverID: String?, userID: String) -> String? {
        guard let serverID, !serverID.isEmpty, !userID.isEmpty else { return nil }
        var query = jellyfinPasswordQuery(serverID: serverID, userID: userID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func clearJellyfinPassword(serverID: String?, userID: String) {
        guard let serverID, !serverID.isEmpty, !userID.isEmpty else { return }
        SecItemDelete(jellyfinPasswordQuery(serverID: serverID, userID: userID) as CFDictionary)
    }

    /// Drop every stored Jellyfin password for this user, whatever server it
    /// was saved under. Used on explicit sign-out, where the saved session
    /// may not carry the server ID the password was keyed by.
    func clearJellyfinPasswords(userID: String) {
        guard !userID.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jellyfinService,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[String: Any]] else { return }
        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  account.hasSuffix(":\(userID):password") else { continue }
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: jellyfinService,
                kSecAttrAccount as String: account
            ] as CFDictionary)
        }
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

    private func save(data: Data, query: [String: Any],
                      accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible
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

    private func jellyfinDeviceIDQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jellyfinService,
            kSecAttrAccount as String: "device-id",
            kSecAttrSynchronizable as String: false
        ]
    }

    private func jellyfinPasswordQuery(serverID: String, userID: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: jellyfinService,
            kSecAttrAccount as String: "\(serverID):\(userID):password",
            kSecAttrSynchronizable as String: false
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

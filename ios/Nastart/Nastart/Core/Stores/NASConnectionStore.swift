import Foundation
import Combine

final class NASConnectionStore: ObservableObject {
    @Published private(set) var connectedDevice: NASDevice?
    @Published private(set) var isConnected: Bool
    @Published private(set) var dsmSession: DSMSession?
    @Published private(set) var connectionEndpoints: DSMConnectionEndpoints?
    @Published private(set) var actualRoute: DSMConnectionRoute?
    @Published private(set) var agentConnection: StoredAgentConnection?

    private var dsmConnectionAttemptID = UUID()
    /// DEBUG offline UI only: never reads or writes the Keychain and never contacts DSM.
    private var isOfflineFixture = false

    @MainActor
    func beginDSMConnectionAttempt() -> UUID {
        dsmConnectionAttemptID = UUID()
        return dsmConnectionAttemptID
    }

    @MainActor
    func ownsDSMConnectionAttempt(_ id: UUID) -> Bool { dsmConnectionAttemptID == id }

    @MainActor
    func cancelDSMConnectionAttempt(ownedBy id: UUID) {
        guard ownsDSMConnectionAttempt(id) else { return }
        dsmConnectionAttemptID = UUID()
    }

    init(device: NASDevice? = nil) {
        connectedDevice = device
        isConnected = device != nil
        connectionEndpoints = nil
        actualRoute = nil
        agentConnection = KeychainStore.shared.loadAgentConnection()
    }

    #if DEBUG
    init(offlineFixture device: NASDevice) {
        connectedDevice = device
        isConnected = true
        connectionEndpoints = nil
        actualRoute = nil
        agentConnection = nil
        isOfflineFixture = true
    }
    #endif

    var usesAgent: Bool {
        agentConnection != nil
    }

    @MainActor
    func connect(device: NASDevice, session: DSMSession? = nil) {
        connectedDevice = device
        dsmSession = session
        connectionEndpoints = session?.endpoints
        actualRoute = session?.actualRoute
        isConnected = true
        session?.recordAuthenticationStage(.connectionPublished)
    }

    @MainActor
    func connectAgent(_ connection: StoredAgentConnection) throws {
        guard !isOfflineFixture else { return }
        try KeychainStore.shared.saveAgentConnection(connection)
        agentConnection = connection
    }

    @MainActor
    func disconnectAgent() {
        agentConnection = nil
        guard !isOfflineFixture else { return }
        KeychainStore.shared.clearAgentConnection()
    }

    @MainActor
    func signOut(client injectedClient: DSMClient? = nil) async {
        guard !isOfflineFixture else { return }
        _ = beginDSMConnectionAttempt()
        let session = dsmSession
        connectedDevice = nil
        dsmSession = nil
        connectionEndpoints = nil
        actualRoute = nil
        isConnected = false
        KeychainStore.shared.clearNASCredentials()
        disconnectAgent()

        if let session {
            let client = injectedClient ?? DSMClient(
                baseURL: session.baseURL,
                allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
            )
            await client.logout(session: session, protectingCurrentSession: { self.dsmSession })
        }
    }
}

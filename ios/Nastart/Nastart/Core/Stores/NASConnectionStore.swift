import Foundation
import Combine

final class NASConnectionStore: ObservableObject {
    @Published private(set) var connectedDevice: NASDevice?
    @Published private(set) var isConnected: Bool
    @Published private(set) var dsmSession: DSMSession?
    @Published private(set) var connectionEndpoints: DSMConnectionEndpoints?
    @Published private(set) var actualRoute: DSMConnectionRoute?
    @Published private(set) var agentConnection: StoredAgentConnection?

    init(device: NASDevice? = nil) {
        connectedDevice = device
        isConnected = device != nil
        connectionEndpoints = nil
        actualRoute = nil
        agentConnection = KeychainStore.shared.loadAgentConnection()
    }

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
    }

    @MainActor
    func connectAgent(_ connection: StoredAgentConnection) throws {
        try KeychainStore.shared.saveAgentConnection(connection)
        agentConnection = connection
    }

    @MainActor
    func disconnectAgent() {
        agentConnection = nil
        KeychainStore.shared.clearAgentConnection()
    }

    @MainActor
    func signOut() async {
        let session = dsmSession
        connectedDevice = nil
        dsmSession = nil
        connectionEndpoints = nil
        actualRoute = nil
        isConnected = false
        KeychainStore.shared.clearNASCredentials()
        disconnectAgent()

        if let session {
            let client = DSMClient(
                baseURL: session.baseURL,
                allowsSelfSignedCertificates: session.allowsSelfSignedCertificates
            )
            await client.logout(session: session)
        }
    }
}

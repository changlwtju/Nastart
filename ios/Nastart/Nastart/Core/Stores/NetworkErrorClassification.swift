import Foundation

enum NetworkErrorKind: String, Equatable, Sendable {
    case cancelled
    case authentication
    case invalidAddress
    case insecureTransport
    case timeout
    case unreachable
    case invalidResponse
    case apiFailure
    case storage
    case unknown

    static func classify(_ error: Error) -> Self {
        if error is CancellationError {
            return .cancelled
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .cancelled:
                return .cancelled
            case .badURL:
                return .invalidAddress
            case .userAuthenticationRequired:
                return .authentication
            case .timedOut:
                return .timeout
            case .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
                return .unreachable
            case .badServerResponse, .cannotParseResponse:
                return .invalidResponse
            default:
                return .unknown
            }
        }

        if let dsmError = error as? DSMClientError {
            switch dsmError {
            case .invalidAddress:
                return .invalidAddress
            case .insecureHTTP:
                return .insecureTransport
            case .invalidResponse:
                return .invalidResponse
            case .apiFailed:
                return .apiFailure
            case .missingSession:
                return .authentication
            }
        }
        if let agentError = error as? AgentClientError {
            switch agentError {
            case .invalidAddress:
                return .invalidAddress
            case .insecureAddress:
                return .insecureTransport
            case .invalidResponse, .unsupportedAPIVersion:
                return .invalidResponse
            case .pairingRejected, .unauthorized:
                return .authentication
            }
        }
        if error is KeychainStoreError {
            return .storage
        }
        return .unknown
    }

    static func diagnosticMessage(for error: Error) -> String {
        let kind = classify(error).rawValue
        if let dsmError = error as? DSMClientError,
           case .apiFailed(let code) = dsmError {
            return code.map { "\(kind):\($0)" } ?? kind
        }
        if let keychainError = error as? KeychainStoreError,
           case .unexpectedStatus(let status) = keychainError {
            return "\(kind):\(status)"
        }
        return kind
    }
}

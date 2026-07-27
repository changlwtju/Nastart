import Foundation

enum ConnectionMode: String, CaseIterable, Identifiable {
    case dsmOnly
    case dsmWithAgent
    case agentOnly
    case manualOnly

    var id: String { rawValue }
}

enum ServiceCategory: String, CaseIterable, Identifiable {
    case favorites
    case media
    case downloads
    case network
    case tools

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .favorites: return "category.favorites"
        case .media: return "category.media"
        case .downloads: return "category.downloads"
        case .network: return "category.network"
        case .tools: return "category.tools"
        }
    }
}

enum ServiceStatus: String {
    case online
    case warning
    case offline
    case unknown
}

struct NASDevice: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String
    let mode: ConnectionMode
    let cpu: Double
    let memory: Double
    let storageUsed: Double
    let storageFreeText: String
    let uptimeText: String
    let certificateDaysRemaining: Int
}

struct LaunchpadService: Identifiable {
    let id: UUID
    let name: String
    let iconText: String
    let category: ServiceCategory
    let status: ServiceStatus
    let subtitle: String
    let detail: String
    let isMedia: Bool
    let cpu: Double?
    let memoryText: String?
}

struct TaskItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let symbol: String
    let isUrgent: Bool
}

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

enum ServiceDisplayRole {
    case control
    case media
    case download
    case network
    case tool
}

struct ServiceDisplayProfile {
    let role: ServiceDisplayRole
    let prefersFeaturedRow: Bool
    let primaryActionKey: String
}

struct FileItem: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String
    let kind: FileKind
    let sizeText: String?
    let children: [FileItem]

    var isFolder: Bool {
        if case .folder = kind {
            return true
        }
        return false
    }
}

enum FileKind {
    case folder
    case video
    case audio
    case image
    case text
    case archive

    var symbolName: String {
        switch self {
        case .folder: return "folder.fill"
        case .video: return "play.rectangle"
        case .audio: return "music.note"
        case .image: return "photo"
        case .text: return "doc.text"
        case .archive: return "archivebox"
        }
    }
}

struct DockerContainer: Identifiable {
    let id: UUID
    let name: String
    let image: String
    let status: ServiceStatus
    let cpu: Double
    let memoryText: String
    let ports: [String]
}

struct TaskItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let symbol: String
    let isUrgent: Bool
}

enum MediaKind: Equatable {
    case video
    case audio
}

struct MediaItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let meta: String
    let path: String
    let kind: MediaKind

    var symbolName: String {
        switch kind {
        case .video: return "play.rectangle"
        case .audio: return "music.note"
        }
    }
}

struct DiscoveredNASDevice: Identifiable {
    let id: UUID
    let name: String
    let host: String
}

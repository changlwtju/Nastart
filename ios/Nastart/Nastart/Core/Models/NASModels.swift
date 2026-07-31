import Foundation

enum ConnectionMode: String, CaseIterable, Identifiable {
    case dsmOnly
    case dsmWithAgent
    case agentOnly
    case manualOnly

    var id: String { rawValue }
}

enum ServiceCategory: String, CaseIterable, Identifiable, Hashable {
    case favorites
    case media
    case downloads
    case network
    case tools

    var id: String { rawValue }

    static var defaultOrder: [ServiceCategory] {
        allCases
    }

    static var defaultOrderStorageValue: String {
        defaultOrder.map(\.rawValue).joined(separator: ",")
    }

    static func ordered(from storageValue: String) -> [ServiceCategory] {
        let savedCategories = storageValue
            .split(separator: ",")
            .compactMap { ServiceCategory(rawValue: String($0)) }
        let savedSet = Set(savedCategories)
        return savedCategories + defaultOrder.filter { !savedSet.contains($0) }
    }

    static func storageValue(for categories: [ServiceCategory]) -> String {
        categories.map(\.rawValue).joined(separator: ",")
    }

    var titleKey: String {
        switch self {
        case .favorites: return "category.favorites"
        case .media: return "category.media"
        case .downloads: return "category.downloads"
        case .network: return "category.network"
        case .tools: return "category.tools"
        }
    }

    var symbolName: String {
        switch self {
        case .favorites: return "star"
        case .media: return "play.rectangle"
        case .downloads: return "arrow.down.circle"
        case .network: return "network"
        case .tools: return "wrench.and.screwdriver"
        }
    }
}

enum ServiceStatus: String, Equatable {
    case online
    case installed
    case warning
    case offline
    case unknown
}

enum LaunchpadServiceSource: Equatable {
    case dsm
    case container
    case reverseProxy
    case package
    case manual
}

struct NASDevice: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String
    let model: String?
    let dsmVersion: String?
    let mode: ConnectionMode
    let cpu: Double?
    let memory: Double?
    let memoryUsedText: String?
    let memoryTotalText: String?
    let storageUsed: Double?
    let storageUsedText: String?
    let storageTotalText: String?
    let storageFreeText: String
    let uptimeMinutes: Int?
    let temperatureText: String?
    let certificate: NASCertificateInfo?
    let sshStatus: NASSSHStatus

    var memoryDisplayText: String {
        if let memoryUsedText, let memoryTotalText {
            return "\(memoryUsedText) / \(memoryTotalText)"
        }
        return metricPercentText(memory)
    }

    var storageDisplayText: String {
        if let storageUsedText, let storageTotalText {
            return "\(storageUsedText) / \(storageTotalText)"
        }
        return storageFreeText
    }

    var uptimeText: String {
        uptimeMinutes.map { NASUptimeFormatter.string(totalMinutes: $0) } ?? "-"
    }

    var certificateDaysRemaining: Int? {
        certificate?.daysRemaining
    }

    private func metricPercentText(_ value: Double?) -> String {
        guard let value else { return "-" }
        return "\(Int((value * 100).rounded()))%"
    }
}

enum NASUptimeFormatter {
    static func string(totalMinutes: Int) -> String {
        let safeMinutes = max(totalMinutes, 0)
        if safeMinutes >= 1_440 {
            return String(
                format: NSLocalizedString("uptime.days_hours", comment: ""),
                Int64(safeMinutes / 1_440),
                Int64((safeMinutes % 1_440) / 60)
            )
        }
        return String(
            format: NSLocalizedString("uptime.hours_minutes", comment: ""),
            Int64(safeMinutes / 60),
            Int64(safeMinutes % 60)
        )
    }
}

struct NASCertificateInfo {
    let subject: String?
    let issuer: String?
    let validFrom: Date?
    let validUntil: Date?
    let usesCustomTrust: Bool

    var daysRemaining: Int? {
        guard let validUntil else { return nil }
        return Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: validUntil)
        ).day
    }
}

enum NASSSHStatus {
    case enabled
    case disabled
    case unavailable
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
    let memory: Double?
    let ports: [String]
    let iconURL: URL?
    let endpoint: URL?
    let source: LaunchpadServiceSource
    let isLaunchpadVisible: Bool

    init(
        id: UUID,
        name: String,
        iconText: String,
        category: ServiceCategory,
        status: ServiceStatus,
        subtitle: String,
        detail: String,
        isMedia: Bool,
        cpu: Double?,
        memoryText: String?,
        memory: Double? = nil,
        ports: [String] = [],
        iconURL: URL? = nil,
        endpoint: URL? = nil,
        source: LaunchpadServiceSource = .manual,
        isLaunchpadVisible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.iconText = iconText
        self.category = category
        self.status = status
        self.subtitle = subtitle
        self.detail = detail
        self.isMedia = isMedia
        self.cpu = cpu
        self.memoryText = memoryText
        self.memory = memory
        self.ports = ports
        self.iconURL = iconURL
        self.endpoint = endpoint
        self.source = source
        self.isLaunchpadVisible = isLaunchpadVisible
    }

    var launchpadVisibilityKey: String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch source {
        case .dsm:
            return "dsm"
        case .container, .reverseProxy:
            return "container|\(normalizedName)|\(normalizedDetail)"
        case .package:
            return "package|\(normalizedDetail)"
        case .manual:
            return "manual|\(id.uuidString.lowercased())"
        }
    }
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

enum ServiceWebMode: String, CaseIterable, Identifiable {
    case automatic
    case mobile
    case desktop
    case focused

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .automatic:
            return "web.mode.automatic"
        case .mobile:
            return "web.mode.mobile"
        case .desktop:
            return "web.mode.desktop"
        case .focused:
            return "web.mode.focused"
        }
    }
}

struct FileItem: Identifiable {
    let id: UUID
    let name: String
    let subtitle: String
    let path: String
    let kind: FileKind
    let sizeText: String?
    let children: [FileItem]

    init(
        id: UUID,
        name: String,
        subtitle: String,
        path: String? = nil,
        kind: FileKind,
        sizeText: String?,
        children: [FileItem]
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.path = path ?? subtitle
        self.kind = kind
        self.sizeText = sizeText
        self.children = children
    }

    var isFolder: Bool {
        if case .folder = kind {
            return true
        }
        return false
    }
}

enum FileKind: Equatable {
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
    let cpu: Double?
    let memoryText: String
    let memoryBytes: Double?
    let memoryPercent: Double?
    let ports: [String]
}

struct TaskItem: Identifiable, Codable {
    let id: UUID
    let title: String
    let subtitle: String
    let symbol: String
    let isUrgent: Bool
    var isMuted: Bool
    let createdAt: Date
    let daysBefore: Int
    var completedAt: Date?

    init(
        id: UUID,
        title: String,
        subtitle: String,
        symbol: String,
        isUrgent: Bool,
        isMuted: Bool = false,
        createdAt: Date = Date(),
        daysBefore: Int = 14,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.isUrgent = isUrgent
        self.isMuted = isMuted
        self.createdAt = createdAt
        self.daysBefore = daysBefore
        self.completedAt = completedAt
    }

    var nextReminderAt: Date? {
        Calendar.current.date(byAdding: .day, value: daysBefore, to: createdAt)
    }
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

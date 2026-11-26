import Foundation
import NetworkMedia

enum ServiceCategory: String, CaseIterable, Identifiable, Hashable, Codable {
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
        var seen = Set<ServiceCategory>()
        let uniqueSavedCategories = savedCategories.filter { seen.insert($0).inserted }
        return uniqueSavedCategories + defaultOrder.filter { !seen.contains($0) }
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

enum LaunchpadServiceSource: String, Equatable, Codable {
    case dsm
    case container
    case reverseProxy
    case package
    case manual
}

enum LaunchpadDefaultVisibilityReason: Equatable {
    case coreNAS
    case synologyApp
    case recognizedWebUI
    case noReachableEndpoint
    case manual
    case systemOrUnknown

    var titleKey: String {
        switch self {
        case .coreNAS: return "launchpad.visibility.reason.core_nas"
        case .synologyApp: return "launchpad.visibility.reason.synology_app"
        case .recognizedWebUI: return "launchpad.visibility.reason.web_ui"
        case .noReachableEndpoint: return "launchpad.visibility.reason.no_endpoint"
        case .manual: return "launchpad.visibility.reason.manual"
        case .systemOrUnknown: return "launchpad.visibility.reason.system_unknown"
        }
    }
}

struct ServiceIconIdentity {
    let displayName: String?
    let symbolName: String?
    let badgeText: String?
    let category: ServiceCategory?
    let prefersBadge: Bool
    let defaultVisibilityReason: LaunchpadDefaultVisibilityReason?
}

enum ServiceIconRegistry {
    static func identity(
        name: String,
        subtitle: String = "",
        detail: String = "",
        endpointHosts: [String] = []
    ) -> ServiceIconIdentity {
        if compactIdentifier(name) == "dsm" {
            return ServiceIconIdentity(
                displayName: "DSM",
                symbolName: "server.rack",
                badgeText: "DSM",
                category: .favorites,
                prefersBadge: false,
                defaultVisibilityReason: nil
            )
        }

        let fingerprint = compactIdentifier(
            ([name, subtitle, detail] + endpointHosts).joined(separator: " ")
        )
        let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rule = rules.first { rule in
            rule.tokens.contains { fingerprint.contains($0) || lowerName.contains($0) }
        }
        return ServiceIconIdentity(
            displayName: rule?.displayName,
            symbolName: NASServiceCategory.symbolName(name: name, detail: subtitle + " " + detail, aliases: endpointHosts),
            badgeText: rule?.badgeText,
            category: NASServiceCategory.matching(name: name, detail: subtitle + " " + detail, aliases: endpointHosts).flatMap { ServiceCategory(rawValue: $0.rawValue) },
            prefersBadge: rule?.prefersBadge ?? false,
            defaultVisibilityReason: rule?.defaultVisibilityReason
        )
    }

    static func fallbackBadgeText(iconText: String, name: String) -> String {
        let normalizedIcon = iconText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
        if !normalizedIcon.isEmpty {
            return String(normalizedIcon.prefix(2)).uppercased()
        }

        let letters = name
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .compactMap(\.first)
            .prefix(2)
        let fallback = letters.isEmpty ? String(name.prefix(2)) : String(letters)
        return fallback.uppercased()
    }

    private struct Rule {
        let tokens: [String]
        let displayName: String?
        let badgeText: String?
        let prefersBadge: Bool
        let defaultVisibilityReason: LaunchpadDefaultVisibilityReason?

        init(
            _ tokens: [String],
            displayName: String? = nil,
            badgeText: String? = nil,
            prefersBadge: Bool = false,
            defaultVisibilityReason: LaunchpadDefaultVisibilityReason? = nil
        ) {
            self.tokens = tokens.map(Self.compactIdentifier)
            self.displayName = displayName
            self.badgeText = badgeText
            self.prefersBadge = prefersBadge
            self.defaultVisibilityReason = defaultVisibilityReason
        }

        private static func compactIdentifier(_ value: String) -> String {
            value.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .joined()
        }
    }

    private static let rules: [Rule] = [
        Rule(["file station", "filebrowser", "文件"], displayName: "File Station", badgeText: "FS"),
        Rule(["container manager"], displayName: "Container Manager", badgeText: "CT"),
        Rule(["download station"], displayName: "Download Station", badgeText: "DL", defaultVisibilityReason: .synologyApp),
        Rule(["synology photos", "photostation", "photos"], displayName: "Synology Photos", badgeText: "PH", defaultVisibilityReason: .synologyApp),
        Rule(["synology drive", "cloudstation", "cloudstationserver"], displayName: "Synology Drive", badgeText: "DR", defaultVisibilityReason: .synologyApp),
        Rule(["video station"], displayName: "Video Station", badgeText: "VD", defaultVisibilityReason: .synologyApp),
        Rule(["audio station"], displayName: "Audio Station", badgeText: "AU", defaultVisibilityReason: .synologyApp),
        Rule(["surveillance station"], defaultVisibilityReason: .synologyApp),
        Rule(["virtual machine manager"], displayName: "Virtual Machine Manager", badgeText: "VM", defaultVisibilityReason: .synologyApp),
        Rule(["web station"]),
        Rule(["jellyfin"], displayName: "Jellyfin", badgeText: "JF", defaultVisibilityReason: .recognizedWebUI),
        Rule(["emby"], displayName: "Emby", badgeText: "EM", defaultVisibilityReason: .recognizedWebUI),
        Rule(["plex", "plexmediaserver"], displayName: "Plex", badgeText: "PX", defaultVisibilityReason: .recognizedWebUI),
        Rule(["navidrome"], displayName: "Navidrome", badgeText: "NV", defaultVisibilityReason: .recognizedWebUI),
        Rule(["audiobookshelf"], displayName: "Audiobookshelf", badgeText: "AB", defaultVisibilityReason: .recognizedWebUI),
        Rule(["immich"], displayName: "Immich", badgeText: "IM", defaultVisibilityReason: .recognizedWebUI),
        Rule(["photoprism"], displayName: "PhotoPrism", badgeText: "PP", defaultVisibilityReason: .recognizedWebUI),
        Rule(["qbittorrent"], displayName: "qBittorrent", badgeText: "QB", defaultVisibilityReason: .recognizedWebUI),
        Rule(["transmission"], displayName: "Transmission", badgeText: "TR", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["aria2"], displayName: "Aria2", badgeText: "A2", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["prowlarr"], displayName: "Prowlarr", badgeText: "PR", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["radarr"], displayName: "Radarr", badgeText: "RD", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["sonarr"], displayName: "Sonarr", badgeText: "SN", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["lidarr"], displayName: "Lidarr", badgeText: "LD", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["readarr"], displayName: "Readarr", badgeText: "RA", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["bazarr"], displayName: "Bazarr", badgeText: "BZ", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["overseerr"], displayName: "Overseerr", badgeText: "OS", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["tinymediamanager", "tiny media manager"], displayName: "tinyMediaManager", badgeText: "TM", defaultVisibilityReason: .recognizedWebUI),
        Rule(["homeassistant", "home assistant", "home-assistant"], displayName: "Home Assistant", badgeText: "HA", defaultVisibilityReason: .recognizedWebUI),
        Rule(["homebridge"], displayName: "Homebridge", badgeText: "HB", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["portainer"], displayName: "Portainer", badgeText: "PT", defaultVisibilityReason: .recognizedWebUI),
        Rule(["homepage"], displayName: "Homepage", badgeText: "HP", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["codeserver", "code-server", "codexserver", "codex-server"], badgeText: "CD", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["jupyter"], displayName: "Jupyter", badgeText: "JP", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["grafana"], displayName: "Grafana", badgeText: "GF", defaultVisibilityReason: .recognizedWebUI),
        Rule(["gitea"], displayName: "Gitea", badgeText: "GT", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["gitlab"], displayName: "GitLab", badgeText: "GL", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["nginx proxy", "nginxproxymanager", "reverse proxy", "traefik", "caddy"], defaultVisibilityReason: .recognizedWebUI),
        Rule(["mihomo", "clash"], displayName: "Mihomo"),
        Rule(["metacubexd", "metacube"], displayName: "MetaCubeXD", badgeText: "MX", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["tailscale", "zerotier", "vpn"]),
        Rule(["adguard"], displayName: "AdGuard", badgeText: "AG", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["pihole", "pi-hole"], displayName: "Pi-hole", badgeText: "PH", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["vaultwarden"], displayName: "Vaultwarden", badgeText: "VW", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["bitwarden"], displayName: "Bitwarden", badgeText: "BW", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["mariadb", "mysql", "postgres"]),
        Rule(["nextcloud"], displayName: "Nextcloud", badgeText: "NC", defaultVisibilityReason: .recognizedWebUI),
        Rule(["paperlessngx", "paperless"], displayName: "Paperless-ngx", badgeText: "PN", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["calibreweb"], displayName: "Calibre-Web", badgeText: "CW", prefersBadge: true, defaultVisibilityReason: .recognizedWebUI),
        Rule(["mealie"], displayName: "Mealie", badgeText: "ML", defaultVisibilityReason: .recognizedWebUI),
        Rule(["uptimekuma", "healthchecks", "uptime"], defaultVisibilityReason: .recognizedWebUI),
        Rule(["calendar"]),
        Rule(["contacts"]),
        Rule(["note station"])
    ]

    private static func compactIdentifier(_ value: String) -> String {
        value.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }
}

enum LaunchpadVisibilityKey {
    static func value(source: LaunchpadServiceSource, name: String, detail: String, id: UUID) -> String {
        switch source {
        case .dsm: return dsm
        case .container, .reverseProxy: return container(name: name, detail: detail)
        case .package: return package(detail: detail)
        case .manual: return "manual|\(id.uuidString.lowercased())"
        }
    }

    static func container(name: String, detail: String) -> String {
        "container|\(normalize(name))|\(normalize(detail))"
    }

    static func package(detail: String) -> String {
        "package|\(normalize(detail))"
    }

    static let dsm = "dsm"

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum DSMServiceIdentity {
    static let containerNameKeys = ["name", "Name", "container_name", "containerName", "container", "service", "title", "id", "Id", "Names"]
    static let containerImageKeys = ["image", "Image", "image_name", "imageName", "repository", "repo", "tag", "imageTag", "image_tag"]
    static let packageNameKeys = ["display_name", "displayName", "name", "id", "package", "package_name", "pkgname"]
    static let missingImage = "-"

    static func discoveryText(_ value: String?) -> String? {
        let normalized = value?.trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
        return normalized?.isEmpty == false ? normalized : nil
    }

    static func containerDisplayName(name: String, image: String) -> String {
        if isInfrastructureContainer(image: image) { return name }
        return ServiceIconRegistry.identity(name: image).displayName ?? displayName(for: name)
    }

    static func isInfrastructureContainer(image: String) -> Bool {
        let repository = image.lowercased().split(separator: "@").first.map(String.init) ?? image.lowercased()
        return repository.split(separator: "/").last?.split(separator: ":").first == "docker-socket-proxy"
    }

    static func displayName(for rawName: String) -> String {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let displayName = ServiceIconRegistry.identity(name: name).displayName {
            return displayName
        }
        let lower = name.lowercased()
        let compact = name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
        if ["container", "container manager", "docker"].contains(lower) { return "Container Manager" }
        if lower.contains("file station") { return "File Station" }
        if lower.contains("synology photos") || compact.contains("synologyphotos") { return "Synology Photos" }
        if lower.contains("download station") { return "Download Station" }
        if lower.contains("synology drive") || compact.contains("synologydrive")
            || compact.contains("cloudstationserver") {
            return "Synology Drive"
        }
        if lower.contains("video station") { return "Video Station" }
        if lower.contains("audio station") { return "Audio Station" }
        if lower.contains("jellyfin") { return "Jellyfin" }
        if lower.contains("emby") { return "Emby" }
        if lower.contains("plex") { return "Plex" }
        if lower.contains("navidrome") { return "Navidrome" }
        if lower.contains("qbittorrent") { return "qBittorrent" }
        if compact.contains("homeassistant") { return "Home Assistant" }
        if compact.contains("codeserver") { return "code-server" }
        if compact.contains("codexserver") { return "codex-server" }
        if compact.contains("tinymediamanager") { return "tinyMediaManager" }
        if compact.contains("metacubexd") { return "MetaCubeXD" }
        return name.isEmpty ? "Service" : name
    }
}

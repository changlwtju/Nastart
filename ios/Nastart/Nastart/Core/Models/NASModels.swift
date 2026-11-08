import Foundation
import NetworkMedia

enum NetworkHostClassifier {
    static func isLiteralAddress(_ host: String?) -> Bool {
        guard var host = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !host.isEmpty
        else {
            return false
        }

        if host.hasPrefix("[") && host.hasSuffix("]") {
            host.removeFirst()
            host.removeLast()
        }
        host = host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host

        let octets = host.split(separator: ".", omittingEmptySubsequences: false)
        if octets.count == 4 {
            return octets.allSatisfy { part in
                guard let value = Int(part) else { return false }
                return (0...255).contains(value)
            }
        }

        guard host.contains(":"),
              host.split(separator: ":", omittingEmptySubsequences: false).count >= 3
        else {
            return false
        }
        return host.allSatisfy { $0.isHexDigit || $0 == ":" }
    }

    static func isPrivate(_ host: String?) -> Bool {
        guard var host = host?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(),
            !host.isEmpty
        else {
            return false
        }

        if host.hasPrefix("[") && host.hasSuffix("]") {
            host.removeFirst()
            host.removeLast()
        }
        host = host.split(separator: "%", maxSplits: 1).first.map(String.init) ?? host

        if host == "localhost" || host.hasSuffix(".local") || host.hasSuffix(".lan") {
            return true
        }

        let octets = host.split(separator: ".", omittingEmptySubsequences: false).compactMap { Int($0) }
        if octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) {
            return octets[0] == 10
                || octets[0] == 127
                || (octets[0] == 169 && octets[1] == 254)
                || (octets[0] == 172 && (16...31).contains(octets[1]))
                || (octets[0] == 192 && octets[1] == 168)
        }

        guard host.contains(":"), let firstHextet = host.split(separator: ":").first else {
            return false
        }
        if host == "::1" {
            return true
        }
        guard let value = UInt16(firstHextet, radix: 16) else { return false }
        return value & 0xfe00 == 0xfc00 || value & 0xffc0 == 0xfe80
    }
}

enum DSMConnectionRoute: String, CaseIterable, Codable, Identifiable {
    case lan
    case vpn
    case natLoopback
    case external

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .lan: return "connect.route.lan"
        case .vpn: return "connect.route.vpn"
        case .natLoopback: return "connect.route.nat_loopback"
        case .external: return "connect.route.external"
        }
    }
}

struct DSMConnectionEndpoints: Codable, Equatable {
    let primaryDomain: URL?
    let lanAddress: URL?
    let publicAddress: URL?

    init(
        primaryDomain: URL? = nil,
        lanAddress: URL? = nil,
        publicAddress: URL? = nil
    ) {
        self.primaryDomain = primaryDomain
        self.lanAddress = lanAddress
        self.publicAddress = publicAddress
    }

    init(legacyBaseURL: URL) {
        if NetworkHostClassifier.isPrivate(legacyBaseURL.host) {
            primaryDomain = nil
            lanAddress = legacyBaseURL
            publicAddress = nil
        } else {
            primaryDomain = legacyBaseURL
            lanAddress = nil
            publicAddress = nil
        }
    }

    /// Keep each candidate's hostname intact so HTTPS certificate validation
    /// continues to match the host used for the actual request.
    var candidates: [(route: DSMConnectionRoute, url: URL)] {
        candidates(preferredRoute: nil)
    }

    func candidates(preferredRoute: DSMConnectionRoute?) -> [(route: DSMConnectionRoute, url: URL)] {
        var result: [(DSMConnectionRoute, URL)] = []
        if let primaryDomain {
            result.append((.external, primaryDomain))
        }
        if let lanAddress {
            result.append((.lan, lanAddress))
        }
        if let publicAddress {
            result.append((.external, publicAddress))
        }

        var seen = Set<String>()
        let unique = result.filter { seen.insert($0.1.absoluteString).inserted }
        guard let preferredRoute else { return unique }
        return unique.filter { $0.0 == preferredRoute } + unique.filter { $0.0 != preferredRoute }
    }

    var activeFallbackURL: URL? {
        lanAddress ?? publicAddress ?? primaryDomain
    }

    func replacingLANAddress(_ url: URL?) -> DSMConnectionEndpoints {
        DSMConnectionEndpoints(
            primaryDomain: primaryDomain,
            lanAddress: url,
            publicAddress: publicAddress
        )
    }

    func removingLANAddress() -> DSMConnectionEndpoints {
        replacingLANAddress(nil)
    }

    func addingVerifiedLANAddress(_ url: URL?) -> DSMConnectionEndpoints {
        guard let url else { return self }
        return replacingLANAddress(url)
    }
}

enum DSMConnectionRouteResolver {
    static func route(
        for endpoint: URL,
        endpoints: DSMConnectionEndpoints,
        verifiedVPN: Bool = false,
        verifiedNATLoopback: Bool = false
    ) -> DSMConnectionRoute {
        if verifiedVPN {
            return .vpn
        }
        if verifiedNATLoopback {
            return .natLoopback
        }
        if endpoint.absoluteString.caseInsensitiveCompare(endpoints.lanAddress?.absoluteString ?? "") == .orderedSame
            || NetworkHostClassifier.isPrivate(endpoint.host) {
            return .lan
        }
        return .external
    }
}

enum UserConfiguredServiceURLPolicy {
    static func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let value = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard
            let components = URLComponents(string: value),
            let scheme = components.scheme?.lowercased(),
            scheme == "http" || scheme == "https",
            let host = components.host,
            !host.isEmpty,
            components.user == nil,
            components.password == nil,
            scheme == "https" || NetworkHostClassifier.isPrivate(host)
        else {
            return nil
        }
        return components.url
    }

    static func allows(_ url: URL) -> Bool {
        normalizedURL(from: url.absoluteString) != nil
    }
}

enum ConnectionMode: String, CaseIterable, Identifiable, Codable {
    case dsmOnly
    case dsmWithAgent
    case agentOnly
    case manualOnly

    var id: String { rawValue }
}

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

enum ServiceStatus: String, Equatable, Codable, Sendable {
    case online
    case installed
    case warning
    case offline
    case unknown
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

/// Default launchpad visibility is a product curation decision, not a mirror
/// of every package/container returned by DSM. The launchpad should surface
/// destinations that a user can continue working in; the service manager
/// remains the escape hatch for anything intentionally kept out of the default.
enum LaunchpadDefaultVisibilityPolicy {
    static func isInfrastructureContainer(image: String) -> Bool {
        let repository = image.lowercased().split(separator: "@").first.map(String.init) ?? image.lowercased()
        return repository.split(separator: "/").last?.split(separator: ":").first == "docker-socket-proxy"
    }

    static func shouldShowPackage(name: String, hasEndpoint: Bool) -> Bool {
        switch packageReason(name: name, hasEndpoint: hasEndpoint) {
        case .synologyApp, .recognizedWebUI:
            return true
        case .coreNAS, .noReachableEndpoint, .manual, .systemOrUnknown:
            return false
        }
    }

    static func shouldShowContainer(
        name: String,
        image: String,
        hasEndpoint: Bool
    ) -> Bool {
        containerReason(
            name: name,
            image: image,
            hasEndpoint: hasEndpoint
        ) == .recognizedWebUI
    }

    static func reason(for service: LaunchpadService) -> LaunchpadDefaultVisibilityReason {
        switch service.source {
        case .dsm:
            return .coreNAS
        case .manual:
            return .manual
        case .package:
            return packageReason(
                name: service.detail.isEmpty ? service.name : service.detail,
                hasEndpoint: service.endpoint != nil
            )
        case .container, .reverseProxy:
            return containerReason(
                name: service.name,
                image: service.detail,
                hasEndpoint: service.endpoint != nil
            )
        }
    }

    static func packageReason(
        name: String,
        hasEndpoint: Bool
    ) -> LaunchpadDefaultVisibilityReason {
        guard hasEndpoint else { return .noReachableEndpoint }
        if let reason = ServiceIconRegistry.identity(name: name).defaultVisibilityReason {
            return reason
        }
        return .systemOrUnknown
    }

    static func containerReason(
        name: String,
        image: String,
        hasEndpoint: Bool
    ) -> LaunchpadDefaultVisibilityReason {
        guard hasEndpoint else { return .noReachableEndpoint }
        return NASServiceCategory.defaultVisibleContainer(name: name, image: image, hasAddress: hasEndpoint) ? .recognizedWebUI : .systemOrUnknown
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

struct NASDevice: Identifiable, Codable {
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

struct NASCertificateInfo: Codable {
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

enum NASSSHStatus: String, Codable {
    case enabled
    case disabled
    case unavailable
}

struct LaunchpadService: Identifiable, Codable {
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
    let alternateEndpoint: URL?
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
        alternateEndpoint: URL? = nil,
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
        self.alternateEndpoint = alternateEndpoint
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

    /// Stable enough for a refreshed DSM snapshot to keep the user's card
    /// order. Unlike `launchpadVisibilityKey`, this must distinguish services
    /// that share the same source (for example multiple DSM packages).
    var launchpadOrderingKey: String {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedDetail = detail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let endpointValue = endpoint?.absoluteString.lowercased() ?? ""
        let manualIdentity = source == .manual ? id.uuidString.lowercased() : ""
        return [source.rawValue, category.rawValue, normalizedName, normalizedDetail, endpointValue, manualIdentity]
            .joined(separator: "|")
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

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .automatic:
            return "web.mode.automatic"
        case .mobile:
            return "web.mode.mobile"
        case .desktop:
            return "web.mode.desktop"
        }
    }
}

struct FileItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let subtitle: String
    let path: String
    let kind: FileKind
    let sizeText: String?
    let sizeBytes: Int64?
    let modifiedAt: Date?
    let children: [FileItem]

    init(
        id: UUID,
        name: String,
        subtitle: String,
        path: String? = nil,
        kind: FileKind,
        sizeText: String?,
        children: [FileItem],
        sizeBytes: Int64? = nil,
        modifiedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.path = path ?? subtitle
        self.kind = kind
        self.sizeText = sizeText
        self.sizeBytes = sizeBytes
        self.modifiedAt = modifiedAt
        self.children = children
    }

    var isFolder: Bool {
        if case .folder = kind {
            return true
        }
        return false
    }
}

enum FileBrowserSort: String, CaseIterable, Identifiable {
    case name, kind, modified, size

    var id: String { rawValue }
    var titleKey: String { "devices.files.sort.\(rawValue)" }

    func sorted(_ items: [FileItem], ascending: Bool) -> [FileItem] {
        items.sorted { lhs, rhs in
            // Keep folders first in both directions. Missing metadata belongs
            // last within its group; a directory's inode size is not its contents.
            if lhs.isFolder != rhs.isFolder { return lhs.isFolder }
            var order = ComparisonResult.orderedSame
            switch self {
            case .name:
                break
            case .kind:
                let left = lhs.isFolder ? "" : (lhs.name as NSString).pathExtension
                let right = rhs.isFolder ? "" : (rhs.name as NSString).pathExtension
                order = left.localizedStandardCompare(right)
            case .modified:
                if (lhs.modifiedAt == nil) != (rhs.modifiedAt == nil) { return lhs.modifiedAt != nil }
                if let left = lhs.modifiedAt, let right = rhs.modifiedAt {
                    order = left.compare(right)
                }
            case .size:
                if !lhs.isFolder {
                    if (lhs.sizeBytes == nil) != (rhs.sizeBytes == nil) { return lhs.sizeBytes != nil }
                    if let left = lhs.sizeBytes, let right = rhs.sizeBytes {
                        order = left == right ? .orderedSame : (left < right ? .orderedAscending : .orderedDescending)
                    }
                }
            }
            if order == .orderedSame { order = lhs.name.localizedStandardCompare(rhs.name) }
            if order == .orderedSame { order = lhs.path.compare(rhs.path) }
            return ascending ? order == .orderedAscending : order == .orderedDescending
        }
    }
}

enum FileKind: String, Equatable, Codable {
    case folder
    case video
    case audio
    case image
    case text
    case archive
    case discImage

    var symbolName: String {
        switch self {
        case .folder: return "folder.fill"
        case .video: return "play.rectangle"
        case .audio: return "music.note"
        case .image: return "photo"
        case .text: return "doc.text"
        case .archive: return "archivebox"
        case .discImage: return "opticaldisc"
        }
    }
}

struct DockerContainer: Identifiable, Codable {
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
    let targetDate: Date?
    let kindRawValue: String?
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
        targetDate: Date? = nil,
        kindRawValue: String? = nil,
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
        self.targetDate = targetDate
        self.kindRawValue = kindRawValue
        self.completedAt = completedAt
    }

    var nextReminderAt: Date? {
        if let targetDate {
            return Calendar.current.date(byAdding: .day, value: -daysBefore, to: targetDate)
        }
        return Calendar.current.date(byAdding: .day, value: daysBefore, to: createdAt)
    }

    var requiresAttention: Bool {
        guard completedAt == nil else { return false }
        guard let nextReminderAt else { return isUrgent }
        let urgentThreshold = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return isUrgent || nextReminderAt <= urgentThreshold
    }
}

enum MediaKind: String, Equatable, Codable {
    case video
    case audio
}

struct MediaItem: Identifiable, Codable {
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

struct DiscoveredNASDevice: Identifiable, Codable {
    let id: UUID
    let name: String
    let host: String
}

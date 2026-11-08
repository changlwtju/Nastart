import Foundation

/// Shared presentation categories; a name match never grants service authorization.
public enum NASServiceCategory: String, CaseIterable, Sendable {
    case favorites, media, downloads, network, tools

    public static func matching(name: String, detail: String = "", aliases: [String] = []) -> Self? {
        if compact(name) == "dsm" { return .favorites }
        let fingerprint = compact(([name, detail] + aliases).joined(separator: " "))
        return rules.first { tokens, _ in tokens.contains { fingerprint.contains(compact($0)) } }?.1
    }
    /// One vector icon mapping for iPhone, iPad and tvOS service cards.
    public static func symbolName(name: String, detail: String = "", aliases: [String] = []) -> String? {
        if compact(name) == "dsm" { return "server.rack" }
        let fingerprint = compact(([name, detail] + aliases).joined(separator: " "))
        return symbolRules.first { tokens, _ in tokens.contains { fingerprint.contains(compact($0)) } }?.1
    }
    private static let symbolRules: [([String], String)] = [
        (["file station", "filebrowser", "文件"], "folder"),
        (["container manager"], "shippingbox"),
        (["download station"], "arrow.down.circle"),
        (["synology photos", "photostation", "photos"], "photo"),
        (["synology drive", "cloudstation", "cloudstationserver"], "externaldrive"),
        (["video station"], "play.rectangle"),
        (["audio station"], "music.note.list"),
        (["surveillance station"], "video"),
        (["virtual machine manager"], "desktopcomputer"),
        (["web station"], "globe"),
        (["jellyfin"], "play.rectangle"),
        (["emby"], "play.tv"),
        (["plex", "plexmediaserver"], "play.circle"),
        (["navidrome"], "music.note.list"),
        (["audiobookshelf"], "books.vertical"),
        (["immich"], "photo.on.rectangle"),
        (["photoprism"], "camera.aperture"),
        (["qbittorrent"], "arrow.down.circle"),
        (["transmission"], "arrow.down.circle"),
        (["aria2"], "arrow.down.circle"),
        (["prowlarr"], "magnifyingglass.circle"),
        (["radarr"], "film"),
        (["sonarr"], "tv"),
        (["lidarr"], "music.mic"),
        (["readarr"], "book"),
        (["bazarr"], "captions.bubble"),
        (["overseerr"], "person.badge.plus"),
        (["tinymediamanager", "tiny media manager"], "film.stack"),
        (["homeassistant", "home assistant", "home-assistant"], "house"),
        (["homebridge"], "house"),
        (["portainer"], "square.stack.3d.up"),
        (["homepage"], "house"),
        (["codeserver", "code-server", "codexserver", "codex-server"], "terminal"),
        (["jupyter"], "terminal"),
        (["grafana"], "chart.xyaxis.line"),
        (["gitea"], "point.3.connected.trianglepath.dotted"),
        (["gitlab"], "point.3.connected.trianglepath.dotted"),
        (["nginx proxy", "nginxproxymanager", "reverse proxy", "traefik", "caddy"], "lock.rectangle"),
        (["mihomo", "clash"], "network"),
        (["metacubexd", "metacube"], "network"),
        (["tailscale", "zerotier", "vpn"], "lock.shield"),
        (["adguard"], "shield"),
        (["pihole", "pi-hole"], "shield"),
        (["vaultwarden"], "key"),
        (["bitwarden"], "key"),
        (["mariadb", "mysql", "postgres"], "cylinder"),
        (["nextcloud"], "cloud"),
        (["paperlessngx", "paperless"], "doc.text"),
        (["calibreweb"], "books.vertical"),
        (["mealie"], "fork.knife"),
        (["uptimekuma", "healthchecks", "uptime"], "waveform.path.ecg"),
        (["calendar"], "calendar"),
        (["contacts"], "person.crop.circle"),
        (["note station"], "note.text"),
    ]
    public static func defaultVisibleContainer(name: String, image: String, hasAddress: Bool) -> Bool {
        guard hasAddress else { return false }
        let repository = image.lowercased().split(separator: "@").first.map(String.init) ?? image.lowercased()
        if repository.split(separator: "/").last?.split(separator: ":").first == "docker-socket-proxy" { return false }
        let value = matching(name: image) == nil ? name + " " + image : image
        let fingerprint = compact(value)
        return webInterfaceTokens.contains { fingerprint.contains(compact($0)) }
    }
    private static let webInterfaceTokens: [String] = [
        ["jellyfin"],
        ["emby"],
        ["plex", "plexmediaserver"],
        ["navidrome"],
        ["audiobookshelf"],
        ["immich"],
        ["photoprism"],
        ["qbittorrent"],
        ["transmission"],
        ["aria2"],
        ["prowlarr"],
        ["radarr"],
        ["sonarr"],
        ["lidarr"],
        ["readarr"],
        ["bazarr"],
        ["overseerr"],
        ["tinymediamanager", "tiny media manager"],
        ["homeassistant", "home assistant", "home-assistant"],
        ["homebridge"],
        ["portainer"],
        ["homepage"],
        ["codeserver", "code-server", "codexserver", "codex-server"],
        ["jupyter"],
        ["grafana"],
        ["gitea"],
        ["gitlab"],
        ["nginx proxy", "nginxproxymanager", "reverse proxy", "traefik", "caddy"],
        ["metacubexd", "metacube"],
        ["adguard"],
        ["pihole", "pi-hole"],
        ["vaultwarden"],
        ["bitwarden"],
        ["nextcloud"],
        ["paperlessngx", "paperless"],
        ["calibreweb"],
        ["mealie"],
        ["uptimekuma", "healthchecks", "uptime"]
    ].flatMap { $0 }

    private static func compact(_ value: String) -> String {
        value.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
    private static let rules: [([String], Self)] = [
        (["subsonic"], .media),
        (["file station", "filebrowser", "文件"], .favorites),
        (["container manager"], .favorites),
        (["download station"], .downloads),
        (["synology photos", "photostation", "photos"], .media),
        (["synology drive", "cloudstation", "cloudstationserver"], .favorites),
        (["video station"], .media),
        (["audio station"], .media),
        (["surveillance station"], .tools),
        (["virtual machine manager"], .tools),
        (["web station"], .network),
        (["jellyfin"], .media),
        (["emby"], .media),
        (["plex", "plexmediaserver"], .media),
        (["navidrome"], .media),
        (["audiobookshelf"], .media),
        (["immich"], .media),
        (["photoprism"], .media),
        (["qbittorrent"], .downloads),
        (["transmission"], .downloads),
        (["aria2"], .downloads),
        (["prowlarr"], .downloads),
        (["radarr"], .media),
        (["sonarr"], .media),
        (["lidarr"], .media),
        (["readarr"], .media),
        (["bazarr"], .media),
        (["overseerr"], .downloads),
        (["tinymediamanager", "tiny media manager"], .tools),
        (["homeassistant", "home assistant", "home-assistant"], .tools),
        (["homebridge"], .tools),
        (["portainer"], .tools),
        (["homepage"], .favorites),
        (["codeserver", "code-server", "codexserver", "codex-server"], .tools),
        (["jupyter"], .tools),
        (["grafana"], .tools),
        (["gitea"], .tools),
        (["gitlab"], .tools),
        (["nginx proxy", "nginxproxymanager", "reverse proxy", "traefik", "caddy"], .network),
        (["mihomo", "clash"], .network),
        (["metacubexd", "metacube"], .network),
        (["tailscale", "zerotier", "vpn"], .network),
        (["adguard"], .network),
        (["pihole", "pi-hole"], .network),
        (["vaultwarden"], .tools),
        (["bitwarden"], .tools),
        (["mariadb", "mysql", "postgres"], .tools),
        (["nextcloud"], .tools),
        (["paperlessngx", "paperless"], .tools),
        (["calibreweb"], .media),
        (["mealie"], .tools),
        (["uptimekuma", "healthchecks", "uptime"], .tools),
        (["calendar"], .tools),
        (["contacts"], .tools),
        (["note station"], .tools),
    ]
}

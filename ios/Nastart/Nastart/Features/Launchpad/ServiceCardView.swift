import SwiftUI

struct ServiceCardView: View {
    let service: LaunchpadService
    @EnvironmentObject private var dataStore: AppDataStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ServiceIconView(service: service, size: 34)

                Spacer()
                StatusDot(status: service.status)
            }

            Spacer(minLength: 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Text(LocalizedStringKey(service.subtitle))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: service.isMedia ? 126 : 108)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .contextMenu {
            Button(role: .destructive) {
                dataStore.setService(service, visibleOnLaunchpad: false)
            } label: {
                Label("launchpad.service.hide", systemImage: "eye.slash")
            }
        }
    }

    private var cardBackground: some ShapeStyle {
        AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

}

struct ServiceIconView: View {
    let service: LaunchpadService
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: service.symbolName)
            .font(.system(size: size * 0.4, weight: .medium))
            .foregroundStyle(AppTheme.accent)
            .frame(width: size, height: size)
            .background(AppTheme.accent.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .stroke(AppTheme.hairline, lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

extension LaunchpadService {
    var sourceTitleKey: String {
        switch source {
        case .dsm: return "service.source.dsm"
        case .container: return "service.source.container"
        case .reverseProxy: return "service.source.reverse_proxy"
        case .package: return "service.source.package"
        case .manual: return "service.source.manual"
        }
    }

    var displayProfile: ServiceDisplayProfile {
        if name == "DSM" {
            return ServiceDisplayProfile(role: .control, prefersFeaturedRow: true, primaryActionKey: "service.action.device_control")
        }

        if isMedia {
            return ServiceDisplayProfile(role: .media, prefersFeaturedRow: false, primaryActionKey: "service.action.media_library")
        }

        switch category {
        case .downloads:
            return ServiceDisplayProfile(role: .download, prefersFeaturedRow: false, primaryActionKey: "service.action.open_web")
        case .network:
            return ServiceDisplayProfile(role: .network, prefersFeaturedRow: false, primaryActionKey: "service.action.open_web")
        case .tools:
            return ServiceDisplayProfile(role: .tool, prefersFeaturedRow: false, primaryActionKey: "service.action.open_web")
        case .favorites:
            return ServiceDisplayProfile(role: .tool, prefersFeaturedRow: false, primaryActionKey: "service.action.open_web")
        case .media:
            return ServiceDisplayProfile(role: .media, prefersFeaturedRow: false, primaryActionKey: "service.action.media_library")
        }
    }

    var curatedSymbolName: String? {
        let normalizedName = name.lowercased()
        let mappings: [(keywords: [String], symbol: String)] = [
            (["dsm"], "server.rack"),
            (["file station", "file browser", "文件"], "folder"),
            (["synology drive", "cloud station"], "externaldrive"),
            (["synology photos", "photo station", "photos"], "photo"),
            (["audio station", "navidrome", "music"], "music.note.list"),
            (["video station", "jellyfin"], "play.rectangle"),
            (["emby"], "play.tv"),
            (["plex"], "play.circle"),
            (["download station", "qbittorrent", "transmission", "aria2"], "arrow.down.circle"),
            (["webdav"], "folder"),
            (["vpn", "tailscale", "zerotier"], "lock.shield"),
            (["virtual machine", "vm manager"], "desktopcomputer"),
            (["mariadb", "mysql", "postgres"], "cylinder"),
            (["nginx proxy", "reverse proxy", "traefik", "caddy"], "lock.rectangle"),
            (["adguard", "pihole", "pi-hole"], "shield"),
            (["home assistant", "homeassistant", "home-assistant", "homebridge"], "house"),
            (["portainer"], "square.stack.3d.up"),
            (["code-server", "codex-server", "jupyter", "terminal"], "terminal"),
            (["tinymediamanager", "tiny media manager"], "film.stack"),
            (["metacubexd", "metacube", "mihomo", "clash"], "network"),
            (["gitea", "gitlab", "github"], "point.3.connected.trianglepath.dotted"),
            (["uptime", "healthchecks"], "waveform.path.ecg"),
            (["vaultwarden", "bitwarden"], "key"),
            (["synology mail", "mail server"], "envelope"),
            (["calendar"], "calendar"),
            (["contacts"], "person.crop.circle"),
            (["note station"], "note.text"),
            (["surveillance station"], "video"),
            (["web station"], "globe"),
            (["container manager", "docker", "container"], "shippingbox")
        ]

        return mappings.first { mapping in
            mapping.keywords.contains { normalizedName.contains($0) }
        }?.symbol
    }

    var symbolName: String {
        curatedSymbolName ?? category.symbolName
    }

    var isDeveloperConsole: Bool {
        let normalizedName = name.lowercased()
        return normalizedName.contains("code-server") || normalizedName.contains("codex-server")
    }

    var isJellyfin: Bool {
        name.lowercased().contains("jellyfin")
    }

    var isMetaCubeXD: Bool {
        let normalizedName = name.lowercased()
        return normalizedName.contains("metacubexd") || normalizedName.contains("metacube xd")
    }

    var prefersEnhancedWebMode: Bool {
        let normalizedName = name.lowercased()
        let enhancedNames = [
            "code-server",
            "codex-server",
            "jupyter",
            "jupyterlab",
            "portainer",
            "nginx proxy manager",
            "npm",
            "gitea",
            "gitlab",
            "home assistant",
            "metacubexd",
            "metacube xd"
        ]
        return enhancedNames.contains { normalizedName.contains($0) }
    }

    var suggestedEndpoint: URL? {
        endpoint ?? alternateEndpoint
    }

    func preferredEndpoint(for dsmBaseURL: URL?) -> URL? {
        guard Self.isPrivateNetworkHost(dsmBaseURL?.host) else {
            return endpoint ?? alternateEndpoint
        }
        return alternateEndpoint ?? endpoint
    }

    func usesLANOnlyEndpoint(for dsmBaseURL: URL?) -> Bool {
        guard
            !Self.isPrivateNetworkHost(dsmBaseURL?.host),
            let selectedEndpoint = preferredEndpoint(for: dsmBaseURL)
        else {
            return false
        }
        return Self.isPrivateNetworkHost(selectedEndpoint.host)
    }

    var endpointText: String {
        suggestedEndpoint?.absoluteString
            ?? NSLocalizedString("service.detail.endpoint_unavailable", comment: "")
    }

    var resolvedIconURL: URL? {
        iconURL
    }

    private static func isPrivateNetworkHost(_ host: String?) -> Bool {
        NetworkHostClassifier.isPrivate(host)
    }
}

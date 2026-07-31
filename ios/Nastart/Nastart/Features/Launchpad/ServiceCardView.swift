import SwiftUI

struct ServiceCardView: View {
    let service: LaunchpadService
    @EnvironmentObject private var dataStore: AppDataStore
    @State private var actionMessageKey = "service.context.open_hint"
    @State private var showActionHint = false

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
            Button("action.open") {
                showAction("service.context.open_hint")
            }
            Button("action.open_external") {
                showAction("service.context.external_hint")
            }
            Button("action.details") {
                showAction("service.context.details_hint")
            }
            Button("action.edit") {
                showAction("service.context.edit_hint")
            }
            Button(role: .destructive) {
                dataStore.setService(service, visibleOnLaunchpad: false)
            } label: {
                Label("launchpad.service.hide", systemImage: "eye.slash")
            }
        }
        .alert(LocalizedStringKey(actionMessageKey), isPresented: $showActionHint) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private var cardBackground: some ShapeStyle {
        AnyShapeStyle(Color(.secondarySystemGroupedBackground))
    }

    private func showAction(_ key: String) {
        actionMessageKey = key
        showActionHint = true
    }
}

struct ServiceIconView: View {
    let service: LaunchpadService
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            if let iconURL = service.resolvedIconURL {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.18)
                    case .empty:
                        fallbackIcon
                            .opacity(0.55)
                    case .failure:
                        fallbackIcon
                    @unknown default:
                        fallbackIcon
                    }
                }
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.secondarySurface)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var fallbackIcon: some View {
        if let symbolName = service.curatedSymbolName {
            Image(systemName: symbolName)
                .font(.system(size: size * 0.44, weight: .medium))
                .foregroundStyle(.primary)
        } else {
            Text(service.iconText)
                .font(.system(size: size * 0.28, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .padding(.horizontal, size * 0.1)
        }
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
            "home assistant"
        ]
        return enhancedNames.contains { normalizedName.contains($0) }
    }

    var suggestedEndpoint: URL? {
        endpoint
    }

    var endpointText: String {
        endpoint?.absoluteString ?? NSLocalizedString("service.detail.endpoint_unavailable", comment: "")
    }

    var resolvedIconURL: URL? {
        iconURL
    }
}

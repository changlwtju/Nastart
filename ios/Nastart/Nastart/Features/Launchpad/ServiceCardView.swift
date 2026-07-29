import SwiftUI

struct ServiceCardView: View {
    let service: LaunchpadService
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
        .frame(minHeight: service.isMedia ? 126 : 108)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppTheme.hairline, lineWidth: 1)
        }
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

    private var fallbackIcon: some View {
        Image(systemName: service.symbolName)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(.primary)
    }
}

extension LaunchpadService {
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

    var symbolName: String {
        switch name.lowercased() {
        case "dsm":
            return "server.rack"
        case "jellyfin":
            return "play.rectangle"
        case "emby":
            return "play.tv"
        case "plex":
            return "play.circle"
        case "navidrome":
            return "music.note.list"
        case "qbittorrent":
            return "arrow.down.circle"
        case "container":
            return "shippingbox"
        case "nginx proxy":
            return "lock.rectangle"
        case "code-server", "codex-server":
            return "terminal"
        default:
            switch category {
            case .favorites:
                return "star"
            case .media:
                return "play.rectangle"
            case .downloads:
                return "arrow.down.circle"
            case .network:
                return "network"
            case .tools:
                return "wrench.and.screwdriver"
            }
        }
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

    var suggestedEndpoint: URL {
        if let endpoint {
            return endpoint
        }
        let slug = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return URL(string: "https://nas.example.com/\(slug)")!
    }

    var resolvedIconURL: URL? {
        if let iconURL {
            return iconURL
        }

        guard let endpoint else {
            return nil
        }

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)
        components?.path = "/favicon.ico"
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
}

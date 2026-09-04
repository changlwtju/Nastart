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
        ZStack(alignment: .bottomTrailing) {
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

            if let badgeText = service.iconBadgeText {
                Text(badgeText)
                    .font(.system(size: max(size * 0.21, 8), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                    .frame(width: size * 0.42, height: size * 0.32)
                    .background(AppTheme.accentDeep)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                            .stroke(Color(.systemBackground), lineWidth: 1)
                    }
                    .offset(x: size * 0.08, y: size * 0.08)
            }
        }
        .frame(width: size, height: size)
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
        iconIdentity.symbolName
    }

    var symbolName: String {
        curatedSymbolName ?? category.symbolName
    }

    var iconBadgeText: String? {
        let badge = iconIdentity.badgeText
            ?? ServiceIconRegistry.fallbackBadgeText(iconText: iconText, name: name)
        guard !badge.isEmpty, name != "DSM" else { return nil }
        if curatedSymbolName == nil { return badge }
        switch source {
        case .container, .reverseProxy, .manual:
            return badge
        case .dsm, .package:
            return iconIdentity.prefersBadge ? badge : nil
        }
    }

    private var iconIdentity: ServiceIconIdentity {
        ServiceIconRegistry.identity(
            name: name,
            subtitle: subtitle,
            detail: detail,
            endpointHosts: [
                endpoint?.host ?? "",
                alternateEndpoint?.host ?? ""
            ]
        )
    }

    var isDeveloperConsole: Bool {
        let normalizedName = name.lowercased()
        return normalizedName.contains("code-server") || normalizedName.contains("codex-server")
    }

    var isJellyfin: Bool {
        let fingerprint = [
            name,
            subtitle,
            detail,
            endpoint?.absoluteString ?? "",
            alternateEndpoint?.absoluteString ?? "",
            ports.joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()
        if fingerprint.contains("jellyfin") { return true }

        let jellyfinPorts: Set<Int> = [8096, 8097, 8920, 18444]
        if [endpoint?.port, alternateEndpoint?.port].compactMap({ $0 }).contains(where: jellyfinPorts.contains) {
            return true
        }
        return ports.contains { port in
            jellyfinPorts.contains { jellyfinPort in
                port.contains("\(jellyfinPort)")
            }
        }
    }

    var webProfileName: String {
        if isJellyfin { return "jellyfin" }
        if isDeveloperConsole { return "developer" }
        if isMetaCubeXD { return "metacube" }
        if isMedia { return "media" }
        return "default"
    }

    var forcesMobileWebMode: Bool {
        (isJellyfin || isMedia) && !isDeveloperConsole
    }

    var usesSystemInAppBrowser: Bool {
        isJellyfin
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

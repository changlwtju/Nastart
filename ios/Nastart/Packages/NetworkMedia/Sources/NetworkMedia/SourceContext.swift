import Foundation

/// Display only. Never use the result to connect, persist or identify a server.
public enum NetworkConnectionAddress {
    public static func displayText(for url: URL) -> String? {
        guard var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.user = nil; parts.password = nil; parts.query = nil; parts.fragment = nil
        return parts.url?.absoluteString
    }
}

#if os(iOS) || os(tvOS)
import SwiftUI

@MainActor public struct NetworkMediaDestinations {
    let files: AnyView
    let media: AnyView
    let playback: ((NetworkMediaPlaybackSource, @escaping () -> Void) -> AnyView)?
    let credits: NetworkMediaCreditsContext?
    /// Saved position for a source's `stableID`. A host without one offers a single Play action.
    let resumeSeconds: ((String) -> Double?)?
    public init(files: AnyView, media: AnyView,
                playback: ((NetworkMediaPlaybackSource, @escaping () -> Void) -> AnyView)? = nil, credits: NetworkMediaCreditsContext? = nil,
                resumeSeconds: ((String) -> Double?)? = nil) {
        self.files = files; self.media = media; self.playback = playback; self.credits = credits
        self.resumeSeconds = resumeSeconds
    }
}

/// A logged-in host session owns this adapter; a rotated login cannot publish
/// results or use an old token for an image request.
@MainActor public struct NetworkMediaCreditsContext {
    public let source: JellyfinCreditsSource
    let isCurrent: @MainActor () -> Bool
    public init(source: JellyfinCreditsSource, isCurrent: @escaping @MainActor () -> Bool) {
        self.source = source; self.isCurrent = isCurrent
    }
    func people(for metadata: LocalMediaMetadata) async throws -> [MediaCredit] {
        guard isCurrent() else { CreditReadDiagnostics.record("staleContext"); throw CancellationError() }
        let people = try await source.people(for: metadata)
        guard isCurrent(), !Task.isCancelled else { throw CancellationError() }
        return people
    }
    func artwork(for person: MediaCredit) async throws -> Data? {
        guard isCurrent() else { throw CancellationError() }
        let data = try await source.artwork(for: person)
        guard isCurrent(), !Task.isCancelled else { throw CancellationError() }
        return data
    }
}

/// Host-owned identity and transport factory. Authentication stays in the host session.
@MainActor public struct NetworkNASContext {
    public let name: String
    public let address: String
    public let account: String
    public let makeSource: @MainActor () throws -> any ReadOnlyDirectorySource
    public init(name: String, address: String, account: String,
                makeSource: @escaping @MainActor () throws -> any ReadOnlyDirectorySource) {
        self.name = name; self.address = address; self.account = account; self.makeSource = makeSource
    }
    func source(for library: NetworkLibrary) throws -> any ReadOnlyDirectorySource {
        guard library.fileStationAccount == account,
              try WebDAVScope(address: address).baseURL.absoluteString == library.address else { throw NetworkMediaError.fileStationUnavailable }
        return try makeSource()
    }
}

/// Actual app surfaces are supplied by the host, including entitled theme selection.
public struct NetworkMediaAppearance {
    let accent: Color
    let background: AnyView
    let surface: AnyView
    let commandStyle: Bool
    public init(accent: Color, background: AnyView, surface: AnyView, commandStyle: Bool = false) {
        self.accent = accent; self.background = background; self.surface = surface; self.commandStyle = commandStyle
    }
    static var standard: Self { Self(accent: .accentColor, background: AnyView(Color.clear), surface: AnyView(Color.clear)) }
}
private struct NetworkAppearanceKey: EnvironmentKey {
    static var defaultValue: NetworkMediaAppearance { .standard }
}
extension EnvironmentValues {
    var networkAppearance: NetworkMediaAppearance {
        get { self[NetworkAppearanceKey.self] }
        set { self[NetworkAppearanceKey.self] = newValue }
    }
}
struct NetworkPageStyle: ViewModifier {
    @Environment(\.networkAppearance) private var appearance
    func body(content: Content) -> some View {
        #if os(iOS)
        content.scrollContentBackground(.hidden).background { appearance.background }
            .tint(appearance.accent).labelStyle(NetworkIconLabelStyle())
        #else
        content.background { appearance.background }.tint(appearance.accent)
            .labelStyle(NetworkIconLabelStyle()).buttonStyle(.plain)
        #endif
    }
}
private struct NetworkIconLabelStyle: LabelStyle {
    @Environment(\.networkAppearance) private var appearance
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.icon.foregroundStyle(appearance.accent)
            configuration.title
        }
    }
}
struct NetworkSectionStyle: ViewModifier {
    @Environment(\.networkAppearance) private var appearance
    func body(content: Content) -> some View {
        content.listRowBackground(appearance.surface.overlay(alignment: .leading) {
            if appearance.commandStyle { Rectangle().fill(appearance.accent.opacity(0.4)).frame(width: 2) }
        })
    }
}

/// Keep one information hierarchy while allowing the television to use the
/// host's card surfaces and remote focus instead of a full-width system list.
struct NetworkContentPage<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    var headerActionTitle: String? = nil
    var headerActionIdentifier: String = "network.page.action"
    var headerAction: (() -> Void)? = nil
    var backAction: (() -> Void)? = nil
    var usesNativeBack = false
    @ViewBuilder let content: Content
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        #if os(tvOS)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 32) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(networkText(title)).font(.system(size: 40, weight: .semibold)).accessibilityAddTraits(.isHeader)
                        if let subtitle { Text(networkText(subtitle)).font(NetworkType.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 24)
                    if let headerActionTitle, let headerAction {
                        Button(action: headerAction) { Label(networkText(headerActionTitle), systemImage: "plus") }
                            .buttonStyle(NetworkTVCompactStyle()).accessibilityIdentifier(headerActionIdentifier)
                    }
                }
                content
            }.frame(maxWidth: 1500, alignment: .leading)
                .padding(.horizontal, 70).padding(.top, 24).padding(.bottom, 60)
                .frame(maxWidth: .infinity)
        }.font(.system(size: 28)).buttonStyle(NetworkTVActionStyle())
            .modifier(NetworkPageStyle()).navigationTitle("")
            .onExitCommand(perform: usesNativeBack ? nil : (backAction ?? { dismiss() }))
        #else
        List { content }.modifier(NetworkReadableWidth()).modifier(NetworkPageStyle()).navigationTitle(networkText(title))
        #endif
    }
}

#if os(iOS)
/// Matches the app's iPad readable column (about 720pt, centred) so package
/// list pages line up with host pages; compact width and iOS 16 are unchanged.
private struct NetworkReadableWidth: ViewModifier {
    static let maxWidth: CGFloat = 720
    @Environment(\.horizontalSizeClass) private var widthClass
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 17.0, *), widthClass == .regular {
            GeometryReader { proxy in
                content.contentMargins(.horizontal, max(0, (proxy.size.width - Self.maxWidth) / 2), for: .scrollContent)
            }
            // A large title would stay at the screen edge, away from the centred column.
            .navigationBarTitleDisplayMode(.inline)
        } else { content }
    }
}
#endif

struct NetworkContentSection<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        #if os(tvOS)
        LazyVStack(alignment: .leading, spacing: 16) {
            if let title {
                Text(networkText(title)).font(.system(size: 32, weight: .semibold)).accessibilityAddTraits(.isHeader)
            }
            content
        }.frame(maxWidth: .infinity, alignment: .leading).focusSection()
        #else
        Group {
            if let title { Section { content } header: { Text(networkText(title)) } }
            else { Section { content } }
        }.modifier(NetworkSectionStyle())
        #endif
    }
}

enum NetworkType {
    static var caption: Font {
        #if os(tvOS)
        .system(size: 24)
        #else
        .caption
        #endif
    }
}

struct NetworkGroupedRows<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.networkAppearance) private var appearance
    var body: some View {
        #if os(tvOS)
        VStack(spacing: 4) { content }.padding(8)
            .background { appearance.surface }.clipShape(RoundedRectangle(cornerRadius: 22))
            .buttonStyle(NetworkTVActionStyle(inset: true))
        #else
        content
        #endif
    }
}

struct NetworkInputStyle: ViewModifier {
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.isFocused) private var focused
    func body(content: Content) -> some View {
        #if os(tvOS)
        content.padding(20).background { appearance.surface }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(focused ? appearance.accent : Color.primary.opacity(0.08), lineWidth: focused ? 3 : 1) }
        #else
        content
        #endif
    }
}

#if os(tvOS)
struct NetworkTVActionStyle: ButtonStyle {
    var inset = false
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.isFocused) private var focused
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.primary.opacity(enabled ? 1 : 0.4))
            .padding(24).frame(maxWidth: .infinity, minHeight: appearance.commandStyle ? 90 : 106, alignment: .leading)
            .background {
                if !inset { appearance.surface }
                if focused { appearance.accent.opacity(0.18) }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .leading) {
                if appearance.commandStyle && !inset {
                    RoundedRectangle(cornerRadius: 2).fill(appearance.accent.opacity(focused ? 1 : 0.4))
                        .frame(width: 3).padding(.vertical, 20)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(focused ? appearance.accent : (inset ? Color.clear : Color.primary.opacity(0.08)), lineWidth: focused ? 3 : 1)
            }
            .scaleEffect(focused && !reduceMotion && !inset ? 1.03 : 1)
            .shadow(color: .black.opacity(focused && !inset ? 0.3 : 0), radius: 18, y: 10)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
    }
}
struct NetworkTVCompactStyle: ButtonStyle {
    @Environment(\.networkAppearance) private var appearance
    @Environment(\.isFocused) private var focused
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 24, weight: .medium)).foregroundStyle(.primary)
            .padding(.horizontal, 22).padding(.vertical, 16)
            .background { appearance.surface.overlay(focused ? appearance.accent.opacity(0.18) : Color.clear) }
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(focused ? appearance.accent : Color.primary.opacity(0.08), lineWidth: focused ? 3 : 1) }
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
#endif
#endif

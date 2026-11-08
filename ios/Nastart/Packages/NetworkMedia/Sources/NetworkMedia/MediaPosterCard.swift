#if os(iOS) || os(tvOS)
import SwiftUI

/// One terminal-specific poster presentation for server libraries and read-only
/// folder libraries. Callers supply artwork/data, never a second card design.
public struct MediaPosterCard<Artwork: View>: View {
    let title: String
    let subtitle: String
    let aspect: CGFloat
    let progress: Double?
    let canvas: Color
    let accent: Color
    let artwork: Artwork
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(title: String, subtitle: String, aspect: CGFloat = 2.0 / 3.0,
                progress: Double? = nil, canvas: Color = .clear, accent: Color = .accentColor,
                @ViewBuilder artwork: () -> Artwork) {
        self.title = title; self.subtitle = subtitle; self.aspect = aspect
        self.progress = progress; self.canvas = canvas; self.accent = accent; self.artwork = artwork()
    }
    private var spacing: CGFloat {
        #if os(tvOS)
        12
        #else
        7
        #endif
    }
    private var captionSpacing: CGFloat {
        #if os(tvOS)
        5
        #else
        7
        #endif
    }
    private var radius: CGFloat {
        #if os(tvOS)
        13
        #else
        7
        #endif
    }
    private var titleFont: Font {
        #if os(tvOS)
        .system(size: 28, weight: .medium)
        #else
        widthClass == .compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold)
        #endif
    }
    private var captionFont: Font {
        #if os(tvOS)
        .system(size: 24)
        #else
        widthClass == .compact ? .caption2 : .caption
        #endif
    }
    /// 无障碍字号下的 iPhone 窄屏：一列全宽海报一屏只放得下一部作品，改为“小海报 + 右侧文字”的列表行。
    private var listRow: Bool {
        #if os(tvOS)
        false
        #else
        typeSize.isAccessibilitySize && widthClass == .compact
        #endif
    }
    public var body: some View {
        if listRow {
            HStack(alignment: .top, spacing: 14) {
                poster.frame(width: 88)
                caption
            }.frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            VStack(alignment: .leading, spacing: spacing) {
                poster
                caption
            }.frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
    private var poster: some View {
        Rectangle().fill(canvas).aspectRatio(aspect, contentMode: .fit)
            .overlay { GeometryReader { proxy in artwork.frame(width: proxy.size.width, height: proxy.size.height).clipped() } }
            .overlay(alignment: .bottomLeading) {
                if let progress, progress.isFinite, progress > 0 {
                    GeometryReader { proxy in
                        VStack { Spacer(minLength: 0); Rectangle().fill(accent).frame(width: proxy.size.width * min(1, progress), height: 4) }
                    }.accessibilityHidden(true)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
    private var caption: some View {
        VStack(alignment: .leading, spacing: captionSpacing) {
            Group {
                #if os(tvOS)
                Text(title).lineLimit(2, reservesSpace: true)
                #else
                // The grid aligns rows by their tallest card, so the subtitle can sit right under the title.
                if typeSize.isAccessibilitySize { Text(title).lineLimit(nil) }
                else { Text(title).lineLimit(2) }
                #endif
            }.font(titleFont).foregroundStyle(.primary)
                .truncationMode(.tail).frame(maxWidth: .infinity, alignment: .leading)
            Text(subtitle.isEmpty ? " " : subtitle).font(captionFont).foregroundStyle(.secondary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 1).truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading).accessibilityHidden(subtitle.isEmpty)
        }
    }
}

/// Matches the existing Jellyfin television poster focus frame.
public struct MediaPosterFocusStyle: ButtonStyle {
    let accent: Color
    public init(accent: Color) { self.accent = accent }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(MediaPosterFocusFrame(accent: accent, pressed: configuration.isPressed))
    }
}
private struct MediaPosterFocusFrame: ViewModifier {
    let accent: Color
    let pressed: Bool
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.foregroundStyle(.primary).padding(10)
            .background(focused ? accent.opacity(0.20) : .clear, in: RoundedRectangle(cornerRadius: 19))
            .overlay(RoundedRectangle(cornerRadius: 19).stroke(focused ? accent : .clear, lineWidth: 3))
            .scaleEffect(focused && !reduceMotion ? 1.06 : 1)
            .shadow(color: .black.opacity(focused ? 0.3 : 0), radius: 18, y: 10)
            .opacity(pressed ? 0.8 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focused)
    }
}

/// Presentation only. Source adapters retain state, localization and actions.
public struct MediaLibraryEmptyState<Actions: View>: View {
    let systemImage: String
    let title: Text
    let detail: Text?
    let accent: Color
    let actions: Actions
    public init(systemImage: String, title: Text, detail: Text? = nil, accent: Color = .accentColor,
                @ViewBuilder actions: () -> Actions) {
        self.systemImage = systemImage; self.title = title; self.detail = detail
        self.accent = accent; self.actions = actions()
    }
    public var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 34))
                .foregroundStyle(accent).accessibilityHidden(true)
            title.foregroundStyle(Color.primary)
                #if os(tvOS)
                .font(.system(size: 28, weight: .semibold))
                #else
                .font(.headline)
                #endif
                .accessibilityAddTraits(.isHeader)
            if let detail {
                detail.foregroundStyle(Color.secondary)
                    #if os(tvOS)
                    .font(.system(size: 24))
                    #else
                    .font(.subheadline)
                    #endif
            }
            actions
                #if os(tvOS)
                .font(.system(size: 28))
                #else
                .font(.body)
                #endif
        }.multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24).padding(.vertical, 32).frame(maxWidth: .infinity)
    }
}
extension MediaLibraryEmptyState where Actions == EmptyView {
    public init(systemImage: String, title: Text, detail: Text? = nil, accent: Color = .accentColor) {
        self.init(systemImage: systemImage, title: title, detail: detail, accent: accent) { EmptyView() }
    }
}

/// A compact notice keeps retained content visible; the caller owns recovery.
public struct MediaLibraryNotice<Actions: View>: View {
    let title: Text
    let message: Text
    let detail: Text?
    let accent: Color
    let messageIdentifier: String
    let actions: Actions
    public init(title: Text, message: Text, detail: Text? = nil, accent: Color = .accentColor,
                messageIdentifier: String = "media.library.notice.message", @ViewBuilder actions: () -> Actions) {
        self.title = title; self.message = message; self.detail = detail; self.accent = accent
        self.messageIdentifier = messageIdentifier; self.actions = actions()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            title.foregroundStyle(Color.primary)
                #if os(tvOS)
                .font(.system(size: 28, weight: .semibold))
                #else
                .font(.headline)
                #endif
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.circle").foregroundStyle(accent).accessibilityHidden(true)
                message.foregroundStyle(Color.primary).fixedSize(horizontal: false, vertical: true)
            }.accessibilityElement(children: .combine).accessibilityIdentifier(messageIdentifier)
            if let detail {
                detail.foregroundStyle(Color.secondary).fixedSize(horizontal: false, vertical: true)
                    #if os(tvOS)
                    .font(.system(size: 24))
                    #else
                    .font(.caption)
                    #endif
            }
            actions
        }.frame(maxWidth: .infinity, alignment: .leading)
        #if os(tvOS)
        .font(.system(size: 28))
        #else
        .font(.body)
        #endif
    }
}
extension MediaLibraryNotice where Actions == EmptyView {
    public init(title: Text, message: Text, detail: Text? = nil, accent: Color = .accentColor,
                messageIdentifier: String = "media.library.notice.message") {
        self.init(title: title, message: message, detail: detail, accent: accent,
            messageIdentifier: messageIdentifier) { EmptyView() }
    }
}

/// Selects presentation from visible content; fetching and recovery stay with the caller.
public struct MediaLibraryLoadFailure<Actions: View>: View {
    let hasContent: Bool
    let title: Text
    let message: Text
    let accent: Color
    let messageIdentifier: String
    let actions: Actions
    public init(hasContent: Bool, title: Text, message: Text, accent: Color = .accentColor,
                messageIdentifier: String = "media.library.loadFailure.message", @ViewBuilder actions: () -> Actions) {
        self.hasContent = hasContent; self.title = title; self.message = message; self.accent = accent
        self.messageIdentifier = messageIdentifier; self.actions = actions()
    }
    public var body: some View {
        if hasContent {
            MediaLibraryNotice(title: title, message: message, accent: accent,
                messageIdentifier: messageIdentifier) { actions }
        } else {
            MediaLibraryEmptyState(systemImage: "exclamationmark.triangle", title: title,
                detail: message, accent: accent) { actions }
                .accessibilityIdentifier(messageIdentifier)
        }
    }
}

/// Renders status alongside cached content, without owning loading or recovery.
public struct MediaLibraryContent<Content: View, Recovery: View>: View {
    let isLoading: Bool
    let hasContent: Bool
    let failure: Text?
    let failureTitle: Text
    let accent: Color
    let messageIdentifier: String
    let content: Content
    let recovery: Recovery
    public init(isLoading: Bool, hasContent: Bool, failure: Text?, failureTitle: Text,
                accent: Color = .accentColor, messageIdentifier: String = "media.library.content.error",
                @ViewBuilder content: () -> Content, @ViewBuilder recovery: () -> Recovery) {
        self.isLoading = isLoading; self.hasContent = hasContent; self.failure = failure
        self.failureTitle = failureTitle; self.accent = accent; self.messageIdentifier = messageIdentifier
        self.content = content(); self.recovery = recovery()
    }
    public var body: some View {
        LazyVStack(alignment: .leading, spacing: 16) {
            if isLoading {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 24)
            }
            if let failure {
                MediaLibraryLoadFailure(hasContent: hasContent, title: failureTitle, message: failure,
                    accent: accent, messageIdentifier: messageIdentifier) { recovery }
            }
            if hasContent || (!isLoading && failure == nil) { content }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

public struct MediaLibraryHeading: View {
    let title: String
    let subtitle: String
    let detail: String?
    public init(title: String, subtitle: String, detail: String? = nil) {
        self.title = title; self.subtitle = subtitle; self.detail = detail
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                #if os(tvOS)
                    .font(.system(size: 40, weight: .semibold))
                #else
                    .font(.headline)
                #endif
            }
            if !subtitle.isEmpty { Text(subtitle).font(captionFont).foregroundStyle(.secondary) }
            if let detail { Text(detail).font(captionFont).foregroundStyle(.secondary) }
        }
    }
    private var captionFont: Font {
        #if os(tvOS)
        .system(size: 24)
        #else
        .subheadline
        #endif
    }
}
/// Selection and remote focus remain separate, without framing the category
/// as a second poster or a statistics card.
public struct MediaLibraryCategoryStyle: ButtonStyle {
    let selected: Bool
    let accent: Color
    public init(selected: Bool, accent: Color) { self.selected = selected; self.accent = accent }
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.modifier(MediaLibraryCategoryFrame(selected: selected, accent: accent, pressed: configuration.isPressed))
    }
}
private struct MediaLibraryCategoryFrame: ViewModifier {
    let selected: Bool
    let accent: Color
    let pressed: Bool
    @Environment(\.isFocused) private var focused
    func body(content: Content) -> some View {
        content
            #if os(tvOS)
            .font(.system(size: 28, weight: selected ? .semibold : .regular))
            #else
            .font(.subheadline.weight(selected ? .semibold : .regular))
            #endif
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(focused ? Color.primary.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .bottom) {
                Rectangle().fill(selected ? accent : .clear).frame(height: 2).padding(.horizontal, 16)
            }
            .opacity(pressed ? 0.7 : 1)
    }
}
/// Shared placement and affordance for library actions across source adapters.
public struct MediaLibraryMenu<Content: View>: View {
    let content: Content
    @State private var presented = false
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        #if os(tvOS)
        Button { presented = true } label: { Label("更多", systemImage: "ellipsis.circle") }
            .confirmationDialog("媒体库", isPresented: $presented, titleVisibility: .hidden) { content }
        #else
        Menu { content } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("更多")
        #endif
    }
}
public struct MediaLibraryToolbar<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        HStack(spacing: 20) { content }.font(actionFont).labelStyle(.titleAndIcon)
    }
    private var actionFont: Font {
        #if os(tvOS)
        .system(size: 28)
        #else
        .subheadline.weight(.medium)
        #endif
    }
}
public struct MediaPosterGrid<Content: View>: View {
    let layout: MediaPosterGridLayout
    let content: Content
    public init(layout: MediaPosterGridLayout, @ViewBuilder content: () -> Content) {
        self.layout = layout; self.content = content()
    }
    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: layout.horizontalSpacing, alignment: .top), count: layout.columns), alignment: .leading, spacing: layout.verticalSpacing) { content }
    }
}
#endif

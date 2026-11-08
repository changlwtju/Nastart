#if os(iOS) || os(tvOS)
  import SwiftUI

  /// Shared Jellyfin detail presentation. A source supplies artwork, facts and
  /// actions; unavailable metadata stays absent rather than being invented.
  public struct MediaDetailHero<Backdrop: View, Poster: View, Content: View>: View {
    let backdrop: Backdrop
    let poster: Poster
    let content: Content
    let showsPoster: Bool
    @Environment(\.horizontalSizeClass) private var widthClass
    @Environment(\.verticalSizeClass) private var heightClass
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(
      showsPoster: Bool = true, @ViewBuilder backdrop: () -> Backdrop,
      @ViewBuilder poster: () -> Poster, @ViewBuilder content: () -> Content
    ) {
      self.showsPoster = showsPoster
      self.backdrop = backdrop()
      self.poster = poster()
      self.content = content()
    }
    public var body: some View {
      #if os(tvOS)
        ZStack(alignment: .bottomLeading) {
          GeometryReader { proxy in
            backdrop.frame(width: proxy.size.width, height: proxy.size.height).clipped()
          }
          scrim
          HStack(alignment: .bottom, spacing: 36) {
            if showsPoster { artwork.frame(width: 200, height: 300) }
            content.frame(maxWidth: .infinity, alignment: .leading)
          }.padding(36).foregroundStyle(.white).environment(\.colorScheme, .dark)
        }.frame(minHeight: 580).clipShape(RoundedRectangle(cornerRadius: 20))
      #else
        Group {
          if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 16) {
              if showsPoster { artwork.frame(width: posterWidth, height: posterHeight) }
              content.frame(maxWidth: .infinity, alignment: .leading)
            }
          } else {
            HStack(alignment: .bottom, spacing: 14) {
              if showsPoster { artwork.frame(width: posterWidth, height: posterHeight) }
              content.frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        // Same 820pt column as the detail body below, so poster and title line up on iPad.
        .frame(maxWidth: 820, alignment: .leading)
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: minimumHeight, alignment: .bottom)
        .background {
          ZStack {
            GeometryReader { proxy in
              backdrop.frame(width: proxy.size.width, height: proxy.size.height).clipped()
            }
            scrim
          }
        }
        .foregroundStyle(.white).environment(\.colorScheme, .dark).clipped()
      #endif
    }
    private var posterWidth: CGFloat { widthClass == .regular ? 118 : 92 }
    private var posterHeight: CGFloat { posterWidth * 1.5 }
    private var minimumHeight: CGFloat {
      heightClass == .compact ? 220 : (widthClass == .regular ? 390 : 310)
    }
    private var scrim: some View {
      LinearGradient(
        colors: [.black.opacity(0.08), .black.opacity(0.22), .black.opacity(0.94)],
        startPoint: .top, endPoint: .bottom)
    }
    private var artwork: some View {
      Rectangle().fill(.black.opacity(0.24)).overlay {
        GeometryReader { proxy in
          poster.frame(width: proxy.size.width, height: proxy.size.height).clipped()
        }
      }
      .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(
          .white.opacity(0.28), lineWidth: 0.5)
      )
      .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
    }
  }

  public struct MediaDetailHeading: View {
    let title: String
    let subtitle: String
    let originalTitle: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(title: String, subtitle: String = "", originalTitle: String? = nil) {
      self.title = title
      self.subtitle = subtitle
      self.originalTitle = originalTitle
    }
    public var body: some View {
      VStack(alignment: .leading, spacing: 8) {
        Text(title)
          #if os(tvOS)
            .font(.system(size: 44, weight: .bold)).lineLimit(2)
          #else
            .font(.title.weight(.bold)).lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            .minimumScaleFactor(typeSize.isAccessibilitySize ? 1 : 0.85)
          #endif
          .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
        if !subtitle.isEmpty {
          Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.86))
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
        }
        if let originalTitle, !originalTitle.isEmpty,
          originalTitle.caseInsensitiveCompare(title) != .orderedSame
        {
          Text(originalTitle).font(.caption).foregroundStyle(.white.opacity(0.7))
            .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
        }
      }
    }
  }

  public struct MediaDetailSection<Content: View>: View {
    let title: Text
    let content: Content
    public init(title: Text, @ViewBuilder content: () -> Content) {
      self.title = title
      self.content = content()
    }
    public var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        title
        #if os(tvOS)
          .font(.system(size: 32, weight: .semibold))
        #else
          .font(.title3.weight(.bold))
        #endif
        .accessibilityAddTraits(.isHeader)
        content
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Providers supply the available content; the order and spacing belong to
  /// the detail page rather than to a particular library's entry point.
  public struct MediaDetailInformation<Credits: View, Related: View, Supplement: View>: View {
    let studios: [String]
    let credits: Credits
    let related: Related
    let supplement: Supplement
    public init(studios: [String], @ViewBuilder credits: () -> Credits,
                @ViewBuilder related: () -> Related, @ViewBuilder supplement: () -> Supplement) {
      self.studios = studios
      self.credits = credits()
      self.related = related()
      self.supplement = supplement()
    }
    public var body: some View {
      VStack(alignment: .leading, spacing: spacing) {
        credits
        if !studios.isEmpty {
          Text(networkL("制作：") + studios.joined(separator: " · "))
            #if os(tvOS)
              .font(.system(size: 24))
            #else
              .font(.caption)
            #endif
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("media.detail.production")
        }
        related
        supplement
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var spacing: CGFloat {
      #if os(tvOS)
        38
      #else
        22
      #endif
    }
  }

  /// Secondary technical/source information uses the same disclosure in
  /// server and folder libraries, leaving the film in the foreground.
  public struct MediaDetailDisclosure<Content: View>: View {
    let title: Text
    let identifier: String
    let content: Content
    @State private var expanded: Bool
    let focus: FocusState<String?>.Binding?
    let focusID: String?
    public init(title: Text, identifier: String, initiallyExpanded: Bool = false,
                focus: FocusState<String?>.Binding? = nil, focusID: String? = nil,
                @ViewBuilder content: () -> Content) {
      self.title = title; self.identifier = identifier; self.content = content()
      self.focus = focus; self.focusID = focusID; _expanded = State(initialValue: initiallyExpanded)
    }
    public var body: some View {
      VStack(alignment: .leading, spacing: 12) {
        toggle
        if expanded { content }
      }.frame(maxWidth: .infinity, alignment: .leading)
    }
    @ViewBuilder private var toggle: some View {
      let button = Button { expanded.toggle() } label: {
          HStack {
            title
            Spacer(minLength: 16)
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
          }.contentShape(Rectangle())
        }
        .buttonStyle(MediaDetailDisclosureStyle())
        .accessibilityIdentifier(identifier)
        .accessibilityValue(expanded ? "已展开" : "已折叠")
      if let focus, let focusID { button.focused(focus, equals: focusID) }
      else { button }
    }
  }
  private struct MediaDetailDisclosureStyle: ButtonStyle {
    @Environment(\.isFocused) private var focused
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        #if os(tvOS)
        .font(.system(size: 28, weight: .medium)).frame(minHeight: 54)
        #else
        .font(.subheadline.weight(.semibold)).frame(minHeight: 40)
        #endif
        .foregroundStyle(.secondary).padding(.horizontal, 14)
        .background(Color.primary.opacity(focused ? 0.10 : 0.035), in: RoundedRectangle(cornerRadius: 12))
        .opacity(configuration.isPressed ? 0.7 : 1)
    }
  }

  /// One field surface and reading order for server and folder details.
  public struct MediaDetailMetadataRows<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
      VStack(alignment: .leading, spacing: 0) { content }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
    }
  }
  public struct MediaDetailMetadataRow: View {
    let title: Text
    let value: String
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(title: Text, value: String) { self.title = title; self.value = value }
    public var body: some View {
      if let value = MediaDetailSummary.normalized(value) {
        Group {
          if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 5) {
              title.foregroundStyle(.secondary)
              Text(value).font(valueFont).foregroundStyle(.primary)
            }
          } else {
            HStack(alignment: .top, spacing: 16) {
              title.foregroundStyle(.secondary).frame(width: labelWidth, alignment: .leading)
              Text(value).font(valueFont).foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }.font(labelFont).fixedSize(horizontal: false, vertical: true)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 14).padding(.vertical, 12)
          .accessibilityElement(children: .combine)
      }
    }
    private var labelWidth: CGFloat {
      #if os(tvOS)
      160
      #else
      88
      #endif
    }
    private var labelFont: Font {
      #if os(tvOS)
      .system(size: 24)
      #else
      .subheadline
      #endif
    }
    private var valueFont: Font {
      #if os(tvOS)
      .system(size: 28, weight: .medium)
      #else
      .subheadline.weight(.medium)
      #endif
    }
  }
  /// Only supplied file properties are rendered. No media probe or playback
  /// negotiation is performed to fill a missing value.
  public struct MediaDetailFileProperties: View {
    let name: String?
    let container: String?
    let size: String?
    let bitrate: String?
    let nameLabel: Text
    let containerLabel: Text
    let sizeLabel: Text
    let bitrateLabel: Text
    public init(path: String? = nil, container: String? = nil, size: Int64? = nil, bitrate: Int64? = nil,
                nameLabel: Text = Text("文件"), containerLabel: Text = Text("封装"),
                sizeLabel: Text = Text("大小"), bitrateLabel: Text = Text("码率")) {
      self.name = MediaDetailSummary.normalized(path).flatMap { MediaDetailSummary.normalized(URL(fileURLWithPath: $0).lastPathComponent) }
      self.container = MediaDetailSummary.normalized(container)?.uppercased()
      self.size = size.flatMap { $0 > 0 ? ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) : nil }
      self.bitrate = bitrate.flatMap { $0 > 0 ? String(format: "%.1f Mbps", Double($0) / 1_000_000) : nil }
      self.nameLabel = nameLabel; self.containerLabel = containerLabel; self.sizeLabel = sizeLabel; self.bitrateLabel = bitrateLabel
    }
    public var hasValues: Bool { name != nil || container != nil || size != nil || bitrate != nil }
    public var body: some View {
      Group {
        if let name { MediaDetailMetadataRow(title: nameLabel, value: name) }
        if let container { MediaDetailMetadataRow(title: containerLabel, value: container) }
        if let size { MediaDetailMetadataRow(title: sizeLabel, value: size) }
        if let bitrate { MediaDetailMetadataRow(title: bitrateLabel, value: bitrate) }
      }
    }
  }

  /// A visible file chooser for a presentation group, separate from technical
  /// disclosure. It never chooses a main feature or starts the next segment.
  public struct MediaDetailFileSelection<Content: View>: View {
    public enum Kind { case segments, disc }
    let kind: Kind
    let count: Int
    let content: Content
    public init(kind: Kind, count: Int, @ViewBuilder content: () -> Content) {
      self.kind = kind; self.count = count; self.content = content()
    }
    public var body: some View {
      MediaDetailSection(title: Text(kind == .segments ? "选择分段" : "选择原盘文件")) {
        Text(kind == .segments
          ? "共 \(count) 个文件，按顺序选择播放；暂不自动连播。"
          : "共 \(count) 个内部文件，尚未识别主影片，请按文件选择。")
          #if os(tvOS)
          .font(.system(size: 24))
          #else
          .font(.caption)
          #endif
          .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        VStack(alignment: .leading, spacing: 8) { content }
      }
    }
  }

  /// Explains an existing source limitation without presenting a disabled play
  /// action or changing which files the source can play.
  public struct MediaDetailPlaybackNotice: View {
    public enum Reason {
      case discImage, sourceUnavailable, unsupportedFile
      var title: String {
        switch self {
        case .discImage: return networkL("ISO 原盘镜像")
        case .sourceUnavailable: return networkL("此来源暂不能播放")
        case .unsupportedFile: return networkL("此文件暂不能播放")
        }
      }
      var message: String {
        switch self {
        case .discImage: return networkL("当前入口暂不支持直接播放 ISO，影片资料仍可浏览。")
        case .sourceUnavailable: return networkL("当前连接可浏览影片资料，暂未提供播放入口。")
        case .unsupportedFile: return networkL("可以继续查看影片资料与文件信息。")
        }
      }
      var inlineMessage: String {
        switch self {
        case .discImage: return networkL("当前入口暂不支持播放 ISO")
        case .sourceUnavailable: return networkL("此来源暂不提供播放")
        case .unsupportedFile: return networkL("当前入口暂不支持播放")
        }
      }
    }
    let reason: Reason
    let accent: Color
    public init(reason: Reason, accent: Color = .accentColor) { self.reason = reason; self.accent = accent }
    public var body: some View {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "info.circle").foregroundStyle(accent).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 6) {
          Text(reason.title).font(titleFont).foregroundStyle(.primary)
          Text(reason.message).foregroundStyle(.secondary)
        }.fixedSize(horizontal: false, vertical: true)
      }.font(messageFont).frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("media.detail.playback.notice")
    }
    private var titleFont: Font {
      #if os(tvOS)
      .system(size: 28, weight: .medium)
      #else
      .subheadline.weight(.medium)
      #endif
    }
    private var messageFont: Font {
      #if os(tvOS)
      .system(size: 24)
      #else
      .subheadline
      #endif
    }
  }

  /// Providers supply the original name, known format/size, and an optional
  /// existing selection action. A missing action stays readable, not tappable.
  public struct MediaDetailFileRow: View {
    let name: String
    let subtitle: String
    let accent: Color
    let select: (() -> Void)?
    let unavailability: MediaDetailPlaybackNotice.Reason
    let focus: FocusState<String?>.Binding?
    let focusID: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(name: String, subtitle: String, accent: Color = .accentColor, select: (() -> Void)? = nil,
                unavailability: MediaDetailPlaybackNotice.Reason = .unsupportedFile,
                focus: FocusState<String?>.Binding? = nil, focusID: String? = nil) {
      self.focus = focus; self.focusID = focusID
      self.name = name; self.subtitle = subtitle; self.accent = accent; self.select = select; self.unavailability = unavailability
    }
    public var body: some View {
      Group {
        if let select {
          selectable(select)
        } else {
          label.padding(14)
            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        }
      }
    }
    @ViewBuilder private func selectable(_ action: @escaping () -> Void) -> some View {
      let button = Button(action: action) { label }.buttonStyle(MediaDetailFileChoiceStyle(accent: accent))
      #if os(tvOS)
      if let focus, let focusID { button.focused(focus, equals: focusID) }
      else { button }
      #else
      button
      #endif
    }
    private var label: some View {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: select == nil ? "doc" : "play.circle")
          .foregroundStyle(accent).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(name).font(nameFont).foregroundStyle(.primary)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2).truncationMode(.middle)
          if !subtitle.isEmpty { Text(subtitle).foregroundStyle(.secondary) }
          if select == nil { Text(unavailability.inlineMessage).foregroundStyle(.secondary) }
        }.fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }.font(detailFont).frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
    private var nameFont: Font {
      #if os(tvOS)
      .system(size: 28, weight: .medium)
      #else
      .subheadline.weight(.medium)
      #endif
    }
    private var detailFont: Font {
      #if os(tvOS)
      .system(size: 24)
      #else
      .caption
      #endif
    }
  }
  private struct MediaDetailFileChoiceStyle: ButtonStyle {
    let accent: Color
    func makeBody(configuration: Configuration) -> some View {
      configuration.label.modifier(MediaDetailFileChoiceFrame(accent: accent, pressed: configuration.isPressed))
    }
  }
  private struct MediaDetailFileChoiceFrame: ViewModifier {
    let accent: Color
    let pressed: Bool
    @Environment(\.isFocused) private var focused
    func body(content: Content) -> some View {
      content.padding(14)
        .background(focused ? accent.opacity(0.14) : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? accent : .clear, lineWidth: 2))
        .opacity(pressed ? 0.7 : 1)
    }
  }

  /// One touch-row presentation for server and folder episodes. Providers keep
  /// their artwork URLs and resume values; this view owns only layout.
  public struct MediaEpisodeRow<Artwork: View>: View {
    let title: String
    let subtitle: String
    let progress: Double?
    let accent: Color
    let artwork: Artwork
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(title: String, subtitle: String = "", progress: Double? = nil,
                accent: Color = .accentColor, @ViewBuilder artwork: () -> Artwork) {
      self.title = title; self.subtitle = subtitle; self.progress = progress
      self.accent = accent; self.artwork = artwork()
    }
    public var body: some View {
      HStack(alignment: .top, spacing: 14) {
        artwork.frame(width: artworkWidth, height: artworkWidth * 9 / 16).clipped()
          .overlay(alignment: .bottomLeading) {
            if let progress, progress.isFinite, progress > 0 {
              Rectangle().fill(accent).frame(width: artworkWidth * min(1, progress), height: 3)
            }
          }
          .clipShape(RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 5) {
          Text(title).font(titleFont).foregroundStyle(.primary)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
          if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(subtitle).font(subtitleFont).foregroundStyle(.secondary)
              .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
              .fixedSize(horizontal: false, vertical: true)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
          .foregroundStyle(.secondary).accessibilityHidden(true)
      }.contentShape(Rectangle()).accessibilityElement(children: .combine)
    }
    private var artworkWidth: CGFloat {
      #if os(tvOS)
      224
      #else
      typeSize.isAccessibilitySize ? 96 : 132
      #endif
    }
    private var titleFont: Font {
      #if os(tvOS)
      .system(size: 28, weight: .semibold)
      #else
      .body.weight(.semibold)
      #endif
    }
    private var subtitleFont: Font {
      #if os(tvOS)
      .system(size: 24)
      #else
      .caption
      #endif
    }
  }

  public struct MediaDetailSummary: View {
    let text: String
    let lines: Int?
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(_ text: String, lines: Int? = nil) {
      self.text = text
      self.lines = lines
    }
    /// Preserve paragraphs inside real copy, but never manufacture an empty synopsis.
    public static func normalized(_ value: String?) -> String? {
      guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
      return value
    }
    public var body: some View {
      Group {
        if let text = Self.normalized(text) {
          Text(text)
            #if os(tvOS)
              .font(.system(size: 28)).foregroundStyle(Color.primary.opacity(0.85)).lineLimit(lines)
            #else
              .font(.body).foregroundStyle(.primary).lineSpacing(5)
              .lineLimit(typeSize.isAccessibilitySize ? nil : lines)
            #endif
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }

  public struct MediaDetailFact: View {
    let value: String
    let symbol: String
    let accent: Color
    public init(value: String, symbol: String, accent: Color = .secondary) {
      self.value = value
      self.symbol = symbol
      self.accent = accent
    }
    @ViewBuilder private var content: some View {
      #if os(tvOS)
        // tvOS Label keeps a wide icon column; facts read as one compact chip.
        HStack(spacing: 8) {
          Image(systemName: symbol).foregroundStyle(accent)
          Text(value).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        }.accessibilityElement(children: .combine)
      #else
        Label {
          Text(value).lineLimit(2).fixedSize(horizontal: false, vertical: true)
        } icon: {
          Image(systemName: symbol).foregroundStyle(accent)
        }
      #endif
    }
    public var body: some View {
      content
      #if os(tvOS)
        .font(.system(size: 26, weight: .medium))
      #else
        .font(.subheadline.weight(.medium))
      #endif
      .padding(.horizontal, 10).padding(.vertical, 7)
      .background(
        Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
  }

  public struct MediaDetailFactsModel: Sendable {
    public var rating: Double?
    public var officialRating: String?
    public var duration: String?
    public var video: String?
    public var audio: String?
    public var date: String?
    public var genres: [String]
    public init(rating: Double? = nil, officialRating: String? = nil, duration: String? = nil,
                video: String? = nil, audio: String? = nil, date: String? = nil, genres: [String] = []) {
      self.rating = rating; self.officialRating = officialRating; self.duration = duration
      self.video = video; self.audio = audio; self.date = date; self.genres = genres
    }
  }
  public struct MediaDetailFacts: View {
    let model: MediaDetailFactsModel
    public init(_ model: MediaDetailFactsModel) { self.model = model }
    public var body: some View {
      if hasFacts {
        VStack(alignment: .leading, spacing: 12) {
          MediaDetailFactFlow(spacing: 12) {
            if let value = model.rating, value.isFinite { MediaDetailFact(value: String(format: "%.1f", value), symbol: "star.fill", accent: .yellow) }
            if let value = nonempty(model.officialRating) { MediaDetailFact(value: value, symbol: "person.crop.rectangle") }
            if let value = nonempty(model.duration) { MediaDetailFact(value: value, symbol: "clock") }
            if let value = nonempty(model.video) { MediaDetailFact(value: value, symbol: "film") }
            if let value = nonempty(model.audio) { MediaDetailFact(value: value, symbol: "speaker.wave.2") }
            if let value = nonempty(model.date) { MediaDetailFact(value: value, symbol: "calendar") }
          }
          if !model.genres.isEmpty {
            Label(model.genres.joined(separator: " · "), systemImage: "tag")
              #if os(tvOS)
                .font(.system(size: 24))
              #else
                .font(.subheadline.weight(.medium))
              #endif
              .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
    private func nonempty(_ value: String?) -> String? { value.flatMap { $0.isEmpty ? nil : $0 } }
    private var hasFacts: Bool {
      model.rating != nil || !model.genres.isEmpty || [model.officialRating, model.duration, model.video, model.audio, model.date].contains { nonempty($0) != nil }
    }
  }

  public struct MediaDetailActionRow<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
      HStack(spacing: spacing) { content }
    }
    private var spacing: CGFloat {
      #if os(tvOS)
      28
      #else
      10
      #endif
    }
  }

  public struct MediaDetailActionStyle: ButtonStyle {
    let accent: Color
    public init(accent: Color) { self.accent = accent }
    public func makeBody(configuration: Configuration) -> some View {
      configuration.label.modifier(
        MediaDetailActionFrame(accent: accent, pressed: configuration.isPressed))
    }
  }
  private struct MediaDetailActionFrame: ViewModifier {
    let accent: Color
    let pressed: Bool
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    func body(content: Content) -> some View {
      content.labelStyle(.titleAndIcon).font(.headline.weight(.semibold))
        #if os(tvOS)
          .frame(minWidth: 220, minHeight: 56).padding(.horizontal, 18)
        #else
          .frame(maxWidth: .infinity, minHeight: 48)
        #endif
        .foregroundStyle(enabled ? (focused ? Color.black : Color.white) : Color.secondary)
        .background(enabled ? accent : disabledFill)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(focused ? .white : .clear, lineWidth: 3))
        .opacity(pressed ? 0.8 : 1)
    }
    /// 禁用态用灰底和次要文字色，与 App 的主按钮一致；不再用降低透明度的强调色。
    private var disabledFill: Color {
      #if os(tvOS)
        Color.gray.opacity(0.3)
      #else
        Color(.systemGray4)
      #endif
    }
  }

  /// The host keeps its own item identities and eager/lazy row, while all
  /// providers share clipping and space for remote focus outlines.
  public struct MediaDetailPeopleScroller<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
      #if os(tvOS)
        unclipped.focusSection()
      #else
        scroll
      #endif
    }
    private var scroll: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        content
          #if os(tvOS)
          .padding(12)
          #endif
      }
    }
    #if os(tvOS)
      @ViewBuilder private var unclipped: some View {
        if #available(tvOS 17.0, *) { scroll.scrollClipDisabled() }
        else { scroll }
      }
    #endif
  }

  /// A read-only focus target, with no empty biography action or new screen.
  public struct MediaFocusablePerson<Content: View>: View {
    let accent: Color
    let content: Content
    let detailFocus: FocusState<String?>.Binding?
    let focusID: String?
    #if os(tvOS)
      @FocusState private var focused: Bool
    #endif
    public init(accent: Color, focus: FocusState<String?>.Binding? = nil, focusID: String? = nil,
                @ViewBuilder content: () -> Content) {
      self.accent = accent; self.detailFocus = focus; self.focusID = focusID; self.content = content()
    }
    public var body: some View {
      #if os(tvOS)
        if let detailFocus, let focusID {
          MediaPersonFocusFrame(focused: detailFocus.wrappedValue == focusID, accent: accent) { content }
            .focusable().focused(detailFocus, equals: focusID)
        } else {
          MediaPersonFocusFrame(focused: focused, accent: accent) { content }
            .focusable().focused($focused)
        }
      #else
        content
      #endif
    }
  }

  /// Explicit focus lets existing detail navigation keep its FocusState IDs.
  public struct MediaPersonFocusFrame<Content: View>: View {
    let focused: Bool
    let accent: Color
    let content: Content
    public init(focused: Bool, accent: Color, @ViewBuilder content: () -> Content) {
      self.focused = focused; self.accent = accent; self.content = content()
    }
    public var body: some View {
      content.padding(10)
        .background(focused ? accent.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 19))
        .overlay(RoundedRectangle(cornerRadius: 19).stroke(focused ? accent : .clear, lineWidth: 3))
    }
  }

  /// No empty portrait boxes, and no absence claim while reads are pending.
  public struct MediaDetailCreditsNotice: View {
    let availability: MediaCreditsAvailability
    let loading: Text
    let missing: Text
    let unavailable: Text
    public init(availability: MediaCreditsAvailability,
                loading: Text = Text("正在读取演职资料…"),
                missing: Text = Text("现有资料未提供演职人员信息。"),
                unavailable: Text = Text("演职资料暂未读取，现有信息已保留。")) {
      self.availability = availability
      self.loading = loading; self.missing = missing; self.unavailable = unavailable
    }
    public var body: some View {
      HStack(alignment: .top, spacing: 8) {
        if availability == .loading { ProgressView().controlSize(.small).accessibilityHidden(true) }
        message.fixedSize(horizontal: false, vertical: true)
      }
      #if os(tvOS)
      .font(.system(size: 24))
      #else
      .font(.caption)
      #endif
      .foregroundStyle(.secondary)
      .accessibilityElement(children: .combine)
      .accessibilityIdentifier("media.detail.credits.notice")
    }
    private var message: Text {
      switch availability {
      case .loading: return loading
      case .missing: return missing
      case .unavailable: return unavailable
      }
    }
  }

  /// Neutral artwork for a person; it does not infer a loading/failure state.
  public struct MediaPersonPlaceholder: View {
    public init() {}
    public var body: some View {
      ZStack {
        Color.primary.opacity(0.06)
        Image(systemName: "person.fill").font(.largeTitle).foregroundStyle(.secondary)
      }.accessibilityHidden(true)
    }
  }

  public struct MediaDetailPersonCard<Artwork: View>: View {
    let name: String
    let role: String
    let artwork: Artwork
    @Environment(\.dynamicTypeSize) private var typeSize
    public init(name: String, role: String, @ViewBuilder artwork: () -> Artwork) {
      self.name = name
      self.role = role
      self.artwork = artwork()
    }
    public var body: some View {
      #if os(tvOS)
        VStack(alignment: .leading, spacing: 10) {
          artwork.frame(width: 160, height: 160).clipped().clipShape(Circle())
          Text(name).font(.system(size: 28, weight: .semibold)).lineLimit(2, reservesSpace: true)
          if !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(networkRoleText(role)).font(.system(size: 24)).foregroundStyle(.secondary).lineLimit(2)
          }
        }.frame(width: 160, alignment: .leading).accessibilityElement(children: .combine)
      #else
        VStack(alignment: .leading, spacing: 7) {
          artwork.frame(width: cardWidth, height: typeSize.isAccessibilitySize ? 200 : 132).clipShape(
            RoundedRectangle(cornerRadius: 7, style: .continuous))
          Text(name).font(.caption.weight(.semibold)).foregroundStyle(.primary)
            .lineLimit(typeSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true)
          if !role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(networkRoleText(role)).font(.caption2).foregroundStyle(typeSize.isAccessibilitySize ? Color.primary : .secondary)
              .lineLimit(typeSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true)
          }
        }.frame(width: cardWidth, alignment: .leading).accessibilityElement(children: .combine)
      #endif
    }
    private var cardWidth: CGFloat { typeSize.isAccessibilitySize ? 160 : 104 }
  }
public struct MediaDetailFactFlow: Layout {
    public var spacing: CGFloat
    public init(spacing: CGFloat = 12) { self.spacing = spacing }
    private func positions(width: CGFloat, subviews: Subviews) -> [(CGPoint, CGSize)] {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        return subviews.map { view in
            let ideal = view.sizeThatFits(.unspecified)
            let itemWidth = min(width, ceil(ideal.width))
            let size = view.sizeThatFits(ProposedViewSize(width: itemWidth, height: nil))
            if x > 0 && x + itemWidth > width {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            let point = CGPoint(x: x, y: y)
            x += itemWidth + spacing; rowHeight = max(rowHeight, size.height)
            return (point, CGSize(width: itemWidth, height: size.height))
        }
    }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let natural = subviews.reduce(CGFloat(0)) { $0 + $1.sizeThatFits(.unspecified).width + spacing }
        let width = max(1, proposal.width ?? natural)
        let rows = positions(width: width, subviews: subviews)
        return CGSize(width: width, height: rows.map { $0.0.y + $0.1.height }.max() ?? 0)
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, placement) in zip(subviews, positions(width: max(1, bounds.width), subviews: subviews)) {
            view.place(at: CGPoint(x: bounds.minX + placement.0.x, y: bounds.minY + placement.0.y),
                anchor: .topLeading, proposal: ProposedViewSize(placement.1))
        }
    }
}

#endif

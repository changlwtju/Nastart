//
//  File.swift
//  KSPlayer
//
//  Created by kintan on 2022/1/29.
//
import AVFoundation
import MediaPlayer
import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, *)
@MainActor
public struct KSVideoPlayerView: View {
    private let subtitleDataSouce: SubtitleDataSouce?
    @State
    private var title: String
    @StateObject
    private var playerCoordinator: KSVideoPlayer.Coordinator
    @Environment(\.dismiss)
    private var dismiss
    @FocusState
    private var focusableField: FocusableField? {
        willSet {
            isDropdownShow = newValue == .info
        }
    }

    public let options: KSOptions
    @State
    private var isDropdownShow = false
    @State
    private var showVideoSetting = false
    @State
    public var url: URL {
        didSet {
            #if os(macOS)
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
            #endif
        }
    }

    public init(url: URL, options: KSOptions, title: String? = nil) {
        self.init(coordinator: KSVideoPlayer.Coordinator(), url: url, options: options, title: title, subtitleDataSouce: nil)
    }

    public init(coordinator: KSVideoPlayer.Coordinator, url: URL, options: KSOptions, title: String? = nil, subtitleDataSouce: SubtitleDataSouce? = nil) {
        self.init(coordinator: coordinator, url: .init(wrappedValue: url), options: options, title: .init(wrappedValue: title ?? url.lastPathComponent), subtitleDataSouce: subtitleDataSouce)
    }

    public init(coordinator: KSVideoPlayer.Coordinator, url: State<URL>, options: KSOptions, title: State<String>, subtitleDataSouce: SubtitleDataSouce?) {
        _url = url
        _playerCoordinator = .init(wrappedValue: coordinator)
        _title = title
        #if os(macOS)
        NSDocumentController.shared.noteNewRecentDocumentURL(url.wrappedValue)
        #endif
        self.options = options
        self.subtitleDataSouce = subtitleDataSouce
    }

    public var body: some View {
        ZStack {
            GeometryReader { proxy in
                playView
                VideoSubtitleViewport(coordinator: playerCoordinator,
                    timeModel: playerCoordinator.timemodel)
                controllerView(playerWidth: proxy.size.width)
                #if os(tvOS)
                    .ignoresSafeArea()
                #endif
                #if os(tvOS)
                if isDropdownShow {
                    VideoSettingView(config: playerCoordinator, subtitleModel: playerCoordinator.subtitleModel, subtitleTitle: title)
                        .focused($focusableField, equals: .info)
                }
                #endif
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .automatic)
        #if os(tvOS)
            .onPlayPauseCommand {
                if playerCoordinator.state.isPlaying {
                    playerCoordinator.playerLayer?.pause()
                } else {
                    playerCoordinator.playerLayer?.play()
                }
            }
            .onExitCommand {
                handleTVExit(receiver: "container")
            }
            .onChange(of: focusableField) { field in
                #if DEBUG
                options.viewInteractionObserved?("focus", ["value": String(describing: field)])
                #endif
            }
        #endif
    }

    #if os(tvOS)
    private func handleTVExit(receiver: String) {
        #if DEBUG
        options.viewInteractionObserved?("exit", [
            "receiver": receiver,
            "focus": String(describing: focusableField),
            "mask": String(playerCoordinator.isMaskShow),
            "dropdown": String(isDropdownShow),
        ])
        #endif
        if playerCoordinator.isMaskShow {
            playerCoordinator.isMaskShow = false
        } else {
            switch focusableField {
            case .play: dismiss()
            default: focusableField = .play
            }
        }
    }
    #endif

    private var playView: some View {
        KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
            .onStateChanged { playerLayer, state in
                if state == .readyToPlay {
                    if let movieTitle = playerLayer.player.dynamicInfo?.metadata["title"] {
                        title = movieTitle
                    }
                }
            }
            .onBufferChanged { bufferedCount, consumeTime in
                print("bufferedCount \(bufferedCount), consumeTime \(consumeTime)")
            }
        #if canImport(UIKit)
            .onSwipe { _ in
                playerCoordinator.isMaskShow = true
            }
        #endif
            .ignoresSafeArea()
            .onAppear {
                focusableField = .play
                if let subtitleDataSouce {
                    playerCoordinator.subtitleModel.addSubtitle(dataSouce: subtitleDataSouce)
                }
                // 不要加这个，不然playerCoordinator无法释放，也可以在onDisappear调用removeMonitor释放
                //                    #if os(macOS)
                //                    NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) {
                //                        isMaskShow = overView
                //                        return $0
                //                    }
                //                    #endif
            }

        #if os(iOS) || os(xrOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        #if !os(iOS)
            .focusable(!playerCoordinator.isMaskShow)
        .focused($focusableField, equals: .play)
        #endif
        #if os(tvOS)
        // Keep Menu on the actual video focus surface as well as the container.
        .onExitCommand { handleTVExit(receiver: "surface") }
        #endif
        #if !os(xrOS)
            .onKeyPressLeftArrow {
            playerCoordinator.skip(interval: -15)
        }
        .onKeyPressRightArrow {
            playerCoordinator.skip(interval: 15)
        }
        .onKeyPressSapce {
            if playerCoordinator.state.isPlaying {
                playerCoordinator.playerLayer?.pause()
            } else {
                playerCoordinator.playerLayer?.play()
            }
        }
        #endif
        #if os(macOS)
            .onTapGesture(count: 2) {
                guard let view = playerCoordinator.playerLayer?.player.view else {
                    return
                }
                view.window?.toggleFullScreen(nil)
                view.needsLayout = true
                view.layoutSubtreeIfNeeded()
        }
        .onExitCommand {
            playerCoordinator.playerLayer?.player.view?.exitFullScreenMode()
        }
        .onMoveCommand { direction in
            switch direction {
            case .left:
                playerCoordinator.skip(interval: -15)
            case .right:
                playerCoordinator.skip(interval: 15)
            case .up:
                playerCoordinator.playerLayer?.player.playbackVolume += 0.2
            case .down:
                playerCoordinator.playerLayer?.player.playbackVolume -= 0.2
            @unknown default:
                break
            }
        }
        #else
        .onTapGesture {
                playerCoordinator.isMaskShow.toggle()
            }
        #endif
        #if os(tvOS)
            .onMoveCommand { direction in
            switch direction {
            case .left:
                playerCoordinator.skip(interval: -15)
            case .right:
                playerCoordinator.skip(interval: 15)
            case .up:
                playerCoordinator.mask(show: true, autoHide: false)
            case .down:
                focusableField = .info
            @unknown default:
                break
            }
        }
        #else
        .onHover { _ in
                playerCoordinator.isMaskShow = true
            }
            .onDrop(of: ["public.file-url"], isTargeted: nil) { providers -> Bool in
                providers.first?.loadDataRepresentation(forTypeIdentifier: "public.file-url") { data, _ in
                    if let data, let path = NSString(data: data, encoding: 4), let url = URL(string: path as String) {
                        openURL(url)
                    }
                }
                return true
            }
        #endif
    }

    private func controllerView(playerWidth: Double) -> some View {
        VStack {
            VideoControllerView(config: playerCoordinator, subtitleModel: playerCoordinator.subtitleModel, title: $title, volumeSliderSize: playerWidth / 4)
            #if !os(xrOS)
            // 设置opacity为0，还是会去更新View。所以只能这样了
            if playerCoordinator.isMaskShow {
                VideoTimeShowView(config: playerCoordinator, model: playerCoordinator.timemodel)
                    .onAppear {
                        focusableField = .controller
                    }
                    .onDisappear {
                        focusableField = .play
                    }
            }
            #endif
        }
        #if os(xrOS)
        .ornament(visibility: playerCoordinator.isMaskShow ? .visible : .hidden, attachmentAnchor: .scene(.bottom)) {
            ornamentView(playerWidth: playerWidth)
        }
        .sheet(isPresented: $showVideoSetting) {
            NavigationStack {
                VideoSettingView(config: playerCoordinator, subtitleModel: playerCoordinator.subtitleModel, subtitleTitle: title)
            }
            .buttonStyle(.plain)
        }
        #elseif os(tvOS)
        .padding(.horizontal, 80)
        .padding(.bottom, 80)
        .background(overlayGradient)
        #endif
        .focused($focusableField, equals: .controller)
        .opacity(playerCoordinator.isMaskShow ? 1 : 0)
        .padding()
    }

    private let overlayGradient = LinearGradient(
        stops: [
            Gradient.Stop(color: .black.opacity(0), location: 0.22),
            Gradient.Stop(color: .black.opacity(0.7), location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    private func ornamentView(playerWidth: Double) -> some View {
        VStack(alignment: .leading) {
            KSVideoPlayerViewBuilder.titleView(title: title, config: playerCoordinator)
            ornamentControlsView(playerWidth: playerWidth)
        }
        .frame(width: playerWidth / 1.5)
        .buttonStyle(.plain)
        .padding(.vertical, 24)
        .padding(.horizontal, 36)
        #if os(xrOS)
            .glassBackgroundEffect()
        #endif
    }

    private func ornamentControlsView(playerWidth _: Double) -> some View {
        HStack {
            KSVideoPlayerViewBuilder.playbackControlView(config: playerCoordinator, spacing: 16)
            Spacer()
            VideoTimeShowView(config: playerCoordinator, model: playerCoordinator.timemodel, timeFont: .title3.monospacedDigit())
            Spacer()
            Group {
                KSVideoPlayerViewBuilder.contentModeButton(config: playerCoordinator)
                KSVideoPlayerViewBuilder.subtitleButton(config: playerCoordinator)
                KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $playerCoordinator.playbackRate)
                KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $showVideoSetting)
            }
            .font(.largeTitle)
        }
    }

    fileprivate enum FocusableField {
        case play, controller, info
    }

    public func openURL(_ url: URL) {
        runOnMainThread {
            if url.isSubtitle {
                let info = URLSubtitleInfo(url: url)
                playerCoordinator.subtitleModel.selectedSubtitleInfo = info
            } else if url.isAudio || url.isMovie {
                self.url = url
                title = url.lastPathComponent
            }
        }
    }
}

extension View {
    func onKeyPressLeftArrow(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.leftArrow) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    func onKeyPressRightArrow(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.rightArrow) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }

    func onKeyPressSapce(action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, *) {
            return onKeyPress(.space) {
                action()
                return .handled
            }
        } else {
            return self
        }
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
struct VideoControllerView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject
    fileprivate var subtitleModel: SubtitleModel
    @Binding
    fileprivate var title: String
    fileprivate var volumeSliderSize: Double?
    @State
    private var showVideoSetting = false
    @Environment(\.dismiss)
    private var dismiss
    public var body: some View {
        VStack {
            #if os(tvOS)
            Spacer()
            HStack {
                Text(title)
                    .lineLimit(2)
                    .layoutPriority(3)
                ProgressView()
                    .opacity(config.state == .buffering ? 1 : 0)
                Spacer()
                    .layoutPriority(2)
                HStack {
                    Button {
                        if config.state.isPlaying {
                            config.playerLayer?.pause()
                        } else {
                            config.playerLayer?.play()
                        }
                    } label: {
                        Image(systemName: config.state == .error ? "play.slash.fill" : (config.state.isPlaying ? "pause.circle.fill" : "play.circle.fill"))
                    }
                    .frame(width: 56)
                    if let audioTracks = config.playerLayer?.player.tracks(mediaType: .audio), !audioTracks.isEmpty {
                        audioButton(audioTracks: audioTracks)
                    }
                    muteButton
                        .frame(width: 56)
                    contentModeButton
                        .frame(width: 56)
                    subtitleButton
                    playbackRateButton
                    pipButton
                        .frame(width: 56)
                    infoButton
                        .frame(width: 56)
                }
                .font(.caption)
            }
            #else
            HStack {
                #if !os(xrOS)
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "x.circle.fill")
                }
                #if !os(tvOS)
                if config.playerLayer?.player.allowsExternalPlayback == true {
                    AirPlayView().fixedSize()
                }
                #endif
                #endif
                Spacer()
                if let audioTracks = config.playerLayer?.player.tracks(mediaType: .audio), !audioTracks.isEmpty {
                    audioButton(audioTracks: audioTracks)
                    #if os(xrOS)
                        .aspectRatio(1, contentMode: .fit)
                        .glassBackgroundEffect()
                    #endif
                }
                muteButton
                #if !os(xrOS)
                contentModeButton
                subtitleButton
                #endif
            }
            Spacer()
            #if !os(xrOS)
            KSVideoPlayerViewBuilder.playbackControlView(config: config)
            Spacer()
            HStack {
                KSVideoPlayerViewBuilder.titleView(title: title, config: config)
                Spacer()
                playbackRateButton
                pipButton
                infoButton
            }
            #endif
            #endif
        }
        #if !os(tvOS)
        .font(.title)
        .buttonStyle(.borderless)
        #endif
        .sheet(isPresented: $showVideoSetting) {
            VideoSettingView(config: config, subtitleModel: config.subtitleModel, subtitleTitle: title)
        }
    }

    private var muteButton: some View {
        #if os(xrOS)
        HStack {
            Slider(value: $config.playbackVolume, in: 0 ... 1)
                .onChange(of: config.playbackVolume) { _, newValue in
                    config.isMuted = newValue == 0
                }
                .frame(width: volumeSliderSize ?? 100)
                .tint(.white.opacity(0.8))
                .padding(.leading, 16)
            KSVideoPlayerViewBuilder.muteButton(config: config)
        }
        .padding(16)
        .glassBackgroundEffect()
        #else
        KSVideoPlayerViewBuilder.muteButton(config: config)
        #endif
    }

    private var contentModeButton: some View {
        KSVideoPlayerViewBuilder.contentModeButton(config: config)
    }

    private func audioButton(audioTracks: [MediaPlayerTrack]) -> some View {
        // Track IDs remain the selection identity. The ordinal also distinguishes
        // streams whose language/title/codec metadata are identical or absent.
        let labels = audioTracks.enumerated().map { index, track in
            audioTrackLabel(track, index: index)
        }
        return MenuView(selection: Binding {
            audioTracks.first { $0.isEnabled }?.trackID
        } set: { value in
            if let track = audioTracks.first(where: { $0.trackID == value }) {
                config.playerLayer?.player.select(track: track)
            }
        }) {
            ForEach(Array(audioTracks.enumerated()), id: \.element.trackID) { index, track in
                Text(labels[index]).tag(track.trackID as Int32?)
            }
        } label: {
            Image(systemName: "waveform.circle.fill")
            #if os(xrOS)
                .padding()
                .clipShape(Circle())
            #endif
        }
        .accessibilityLabel("音轨")
        .accessibilityValue(audioTracks.firstIndex { $0.isEnabled }.map { labels[$0] } ?? "未选择")
        .accessibilityIdentifier("ks.player.audioMenu")
    }

    private func audioTrackLabel(_ track: MediaPlayerTrack, index: Int) -> String {
        let name = track.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = track.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = track.language?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title: String?
        if name.isEmpty || name == track.languageCode ||
            description.lowercased().hasPrefix(name.lowercased() + ",") {
            title = language
        } else {
            title = name
        }
        let heading = ["音轨 \(index + 1)", title].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return description.isEmpty ? heading : heading + "\n" + description
    }

    private var subtitleButton: some View {
        KSVideoPlayerViewBuilder.subtitleButton(config: config)
    }

    private var playbackRateButton: some View {
        KSVideoPlayerViewBuilder.playbackRateButton(playbackRate: $config.playbackRate)
    }

    private var pipButton: some View {
        Button {
            config.playerLayer?.isPipActive.toggle()
        } label: {
            Image(systemName: "rectangle.on.rectangle.circle.fill")
        }
    }

    private var infoButton: some View {
        KSVideoPlayerViewBuilder.infoButton(showVideoSetting: $showVideoSetting)
    }
}

@available(iOS 15, tvOS 16, macOS 12, *)
public struct MenuView<Label, SelectionValue, Content>: View where Label: View, SelectionValue: Hashable, Content: View {
    public let selection: Binding<SelectionValue>
    @ViewBuilder
    public let content: () -> Content
    @ViewBuilder
    public let label: () -> Label
    @State
    private var showMenu = false
    public var body: some View {
        if #available(tvOS 17, *) {
            Menu {
                Picker(selection: selection) {
                    content()
                } label: {
                    EmptyView()
                }
                .pickerStyle(.inline)
            } label: {
                label()
            }
            .menuIndicator(.hidden)
        } else {
            Picker(selection: selection, content: content, label: label)
            #if !os(macOS)
                .pickerStyle(.navigationLink)
            #endif
                .frame(height: 50)
            #if os(tvOS)
                .frame(width: 110)
            #endif
        }
    }
}

@available(iOS 15, tvOS 15, macOS 12, *)
struct VideoTimeShowView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject
    fileprivate var model: ControllerTimeModel
    fileprivate var timeFont: Font?
    public var body: some View {
        if config.playerLayer?.player.seekable ?? false {
            HStack {
                Text(model.currentTime.toString(for: .minOrHour)).font(timeFont ?? .caption2.monospacedDigit())
                Slider(value: Binding {
                    Float(model.currentTime)
                } set: { newValue, _ in
                    model.currentTime = Int(newValue)
                }, in: 0 ... Float(model.totalTime)) { onEditingChanged in
                    if onEditingChanged {
                        config.playerLayer?.pause()
                    } else {
                        config.seek(time: TimeInterval(model.currentTime))
                    }
                }
                .frame(maxHeight: 20)
                #if os(xrOS)
                    .tint(.white.opacity(0.8))
                #endif
                Text((model.totalTime).toString(for: .minOrHour)).font(timeFont ?? .caption2.monospacedDigit())
            }
            .font(.system(.title2))
        } else {
            Text("Live Streaming")
        }
    }
}

extension EventModifiers {
    static let none = Self()
}

/// Rendering and the existing subtitle viewport without a second control UI.
/// Hosts can supply their terminal's common playback presentation.
@available(iOS 16, tvOS 16, macOS 13, *)
@MainActor
public struct KSVideoPlayerSurface: View {
    @ObservedObject private var coordinator: KSVideoPlayer.Coordinator
    private let url: URL
    private let options: KSOptions
    public init(coordinator: KSVideoPlayer.Coordinator, url: URL, options: KSOptions) {
        self.coordinator = coordinator; self.url = url; self.options = options
    }
    public var body: some View {
        ZStack {
            KSVideoPlayer(coordinator: coordinator, url: url, options: options)
            VideoSubtitleViewport(coordinator: coordinator, timeModel: coordinator.timemodel)
        }
    }
}

/// Observe geometry in the caption subtree so time/size updates do not rebuild
/// the focused native playback surface or replace its remote-command receiver.
@available(iOS 16, tvOS 16, macOS 13, *)
@MainActor
private struct VideoSubtitleViewport: View {
    @ObservedObject var coordinator: KSVideoPlayer.Coordinator
    @ObservedObject var timeModel: ControllerTimeModel

    var body: some View {
        ZStack {
            SubtitleBitmapLayer(model: coordinator.subtitleModel,
                videoSize: coordinator.playerLayer?.player.naturalSize ?? .zero,
                fillsScreen: coordinator.isScaleAspectFill)
            GeometryReader { proxy in
                if let rect = SubtitleViewportGeometry.videoRect(viewport: proxy.size,
                    video: coordinator.playerLayer?.player.naturalSize ?? .zero,
                    fillsScreen: coordinator.isScaleAspectFill) {
                    HStack {
                        Spacer()
                        VideoSubtitleView(model: coordinator.subtitleModel, excludesPositionedImages: true)
                        Spacer()
                    }
                    .padding()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Authored image cues share the video's transform, not the dialogue bottom
/// inset. Clip the composed layer after placement, including aspect-fill crops.
@available(iOS 16, tvOS 16, macOS 13, *)
@MainActor
public struct SubtitleBitmapLayer: View {
    @ObservedObject private var model: SubtitleModel
    public let videoSize: CGSize
    public let fillsScreen: Bool

    public init(model: SubtitleModel, videoSize: CGSize, fillsScreen: Bool = false) {
        self.model = model; self.videoSize = videoSize; self.fillsScreen = fillsScreen
    }

    public var body: some View {
        GeometryReader { proxy in
            if let frame = SubtitleViewportGeometry.videoFrame(viewport: proxy.size,
                video: videoSize, fillsScreen: fillsScreen) {
                ForEach(model.parts) { part in
                    if let image = part.image,
                       let rect = part.imageDisplayFrame(videoFrame: frame, videoSize: videoSize) {
                        Image(uiImage: image).resizable()
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
public struct VideoSubtitleView: View {
    @ObservedObject
    fileprivate var model: SubtitleModel
    private let excludesPositionedImages: Bool
    public init(model: SubtitleModel, excludesPositionedImages: Bool = false) {
        self.model = model
        self.excludesPositionedImages = excludesPositionedImages
    }
    public var body: some View {
        ZStack {
            ForEach(model.parts.filter { !excludesPositionedImages || !$0.imageUsesCanvasCoordinates }) { part in
                part.subtitleView
            }
        }
    }

    fileprivate static func imageView(_ image: UIImage) -> some View {
        #if enableFeatureLiveText && canImport(VisionKit) && !targetEnvironment(simulator)
        if #available(macCatalyst 17.0, *) {
            return LiveTextImage(uiImage: image)
        } else {
            return Image(uiImage: image)
                .resizable()
        }
        #else
        return Image(uiImage: image)
            .resizable()
        #endif
    }
}

private extension SubtitlePart {
    @available(iOS 16, tvOS 16, macOS 13, *)
    @MainActor
    var subtitleView: some View {
        VStack {
            if let image {
                Spacer()
                GeometryReader { geometry in
                    let fitRect = image.fitRect(geometry.size)
                    VideoSubtitleView.imageView(image)
                        .offset(CGSize(width: fitRect.origin.x, height: fitRect.origin.y))
                        .frame(width: fitRect.size.width, height: fitRect.size.height)
                }
                // 不能加scaledToFit。不然的话图片的缩放比率会有问题。
//                .scaledToFit()
                .padding()
            } else if let text {
                let textPosition = textPosition ?? SubtitleModel.textPosition
                if textPosition.verticalAlign == .bottom || textPosition.verticalAlign == .center {
                    Spacer()
                }
                Text(AttributedString(text))
                    .font(Font(SubtitleModel.textFont))
                    .shadow(color: .black.opacity(0.9), radius: 1, x: 1, y: 1)
                    .foregroundColor(SubtitleModel.textColor)
                    .italic(SubtitleModel.textItalic)
                    .background(SubtitleModel.textBackgroundColor)
                    .multilineTextAlignment(.center)
                    .alignmentGuide(textPosition.horizontalAlign) {
                        $0[.leading]
                    }
                    .padding(textPosition.edgeInsets)
                #if !os(tvOS)
                    .textSelection(.enabled)
                #endif
                if textPosition.verticalAlign == .top || textPosition.verticalAlign == .center {
                    Spacer()
                }
            } else {
                // 需要加这个，不然图片无法清空。感觉是 swiftUI的bug。
                Text("")
            }
        }
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
struct VideoSettingView: View {
    @ObservedObject
    fileprivate var config: KSVideoPlayer.Coordinator
    @ObservedObject
    fileprivate var subtitleModel: SubtitleModel
    @State
    fileprivate var subtitleTitle: String
    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        PlatformView {
            let videoTracks = config.playerLayer?.player.tracks(mediaType: .video)
            if let videoTracks, !videoTracks.isEmpty {
                Picker(selection: Binding {
                    videoTracks.first { $0.isEnabled }?.trackID
                } set: { value in
                    if let track = videoTracks.first(where: { $0.trackID == value }) {
                        config.playerLayer?.player.select(track: track)
                    }
                }) {
                    ForEach(videoTracks, id: \.trackID) { track in
                        Text(track.description).tag(track.trackID as Int32?)
                    }
                } label: {
                    Label("Video Track", systemImage: "video.fill")
                }
                LabeledContent("Video Type", value: (videoTracks.first { $0.isEnabled }?.dynamicRange ?? .sdr).description)
            }
            TextField("Sutitle delay", value: $subtitleModel.subtitleDelay, format: .number)
            TextField("Title", text: $subtitleTitle)
            Button("Search Sutitle") {
                subtitleModel.searchSubtitle(query: subtitleTitle, languages: ["zh-cn"])
            }
            LabeledContent("Stream Type", value: (videoTracks?.first { $0.isEnabled }?.fieldOrder ?? .progressive).description)
            if let dynamicInfo = config.playerLayer?.player.dynamicInfo {
                DynamicInfoView(dynamicInfo: dynamicInfo)
            }
            if let fileSize = config.playerLayer?.player.fileSize, fileSize > 0 {
                LabeledContent("File Size", value: fileSize.kmFormatted + "B")
            }
        }
        #if os(macOS) || targetEnvironment(macCatalyst) || os(xrOS)
        .toolbar {
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        #endif
    }
}

@available(iOS 16, tvOS 16, macOS 13, *)
public struct DynamicInfoView: View {
    @ObservedObject
    fileprivate var dynamicInfo: DynamicInfo
    public var body: some View {
        LabeledContent("Display FPS", value: dynamicInfo.displayFPS, format: .number)
        LabeledContent("Audio Video sync", value: dynamicInfo.audioVideoSyncDiff, format: .number)
        LabeledContent("Dropped Frames", value: dynamicInfo.droppedVideoFrameCount + dynamicInfo.droppedVideoPacketCount, format: .number)
        LabeledContent("Bytes Read", value: dynamicInfo.bytesRead.kmFormatted + "B")
        LabeledContent("Audio bitrate", value: dynamicInfo.audioBitrate.kmFormatted + "bps")
        LabeledContent("Video bitrate", value: dynamicInfo.videoBitrate.kmFormatted + "bps")
    }
}

@available(iOS 15, tvOS 16, macOS 12, *)
public struct PlatformView<Content: View>: View {
    private let content: () -> Content
    public var body: some View {
        #if os(tvOS)
        ScrollView {
            content()
                .padding()
        }
        .pickerStyle(.navigationLink)
        #else
        Form {
            content()
        }
        #if os(macOS)
        .padding()
        #endif
        #endif
    }

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
}

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct KSVideoPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let url = URL(string: "http://clips.vorwaerts-gmbh.de/big_buck_bunny.mp4")!
        KSVideoPlayerView(coordinator: KSVideoPlayer.Coordinator(), url: url, options: KSOptions())
    }
}

// struct AVContentView: View {
//    var body: some View {
//        StructAVPlayerView().frame(width: UIScene.main.bounds.width, height: 400, alignment: .center)
//    }
// }
//
// struct StructAVPlayerView: UIViewRepresentable {
//    let playerVC = AVPlayerViewController()
//    typealias UIViewType = UIView
//    func makeUIView(context _: Context) -> UIView {
//        playerVC.view
//    }
//
//    func updateUIView(_: UIView, context _: Context) {
//        playerVC.player = AVPlayer(url: URL(string: "https://bitmovin-a.akamaihd.net/content/dataset/multi-codec/hevc/stream_fmp4.m3u8")!)
//    }
// }

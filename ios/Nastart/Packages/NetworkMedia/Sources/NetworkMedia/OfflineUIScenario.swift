#if DEBUG
import Foundation

/// Explicit, ephemeral UI data. No server URLs, accounts or persistence APIs.
public struct OfflineUIConfiguration: Equatable, Sendable {
    public enum Scenario: String, CaseIterable, Sendable {
        case library, detail, missing, empty, disconnected, error, invalid
        case episodes, overview, emptyOverview = "overview-empty"
        case segmentFiles = "files-segments", discFiles = "files-disc"
        case fileInformation = "file-info", emptyFileInformation = "file-info-empty"
        case playbackISO = "playback-iso", playbackSource = "playback-source", playbackUnsupported = "playback-unsupported"
        case missingDetail = "detail-missing"
        case longDetail = "detail-long"
        case credits, missingCredits = "credits-missing"
        case creditsLoading = "credits-loading", creditsEmpty = "credits-empty", creditsError = "credits-error"
        case correctionMovie = "correction-movie", correctionEpisode = "correction-episode"
        case correctionError = "correction-error", correctionBusy = "correction-busy"
        case connections, connectionsEmpty = "connections-empty", connectionsStorage = "connections-storage"
        case sourceAdd = "source-add", sourceAddEmpty = "source-add-empty", sourceAddConnection = "source-add-connection"
        case existingPreparing = "existing-preparing", existingError = "existing-error", existingUnavailable = "existing-unavailable"
        case connectionDetail = "connection-detail", connectionDetailEmpty = "connection-detail-empty", connectionDetailLong = "connection-detail-long"
        case libraryScanning = "library-scanning", libraryUpdating = "library-updating", libraryNotice = "library-notice"
        case wallScanning = "wall-scanning", wallUpdating = "wall-updating", wallNotice = "wall-notice"
        case readLoading = "read-loading", readError = "read-error", readMissing = "read-missing", readIdle = "read-idle"
        case homeReadError = "home-read-error", homeReadLoading = "home-read-loading", homeReadIdle = "home-read-idle"
        case homeReadCombined = "home-read-combined", homeReadReady = "home-read-ready"
        case wallReadError = "wall-read-error", wallReadLoading = "wall-read-loading", wallReadIdle = "wall-read-idle"
        case wallReadCombined = "wall-read-combined", wallReadReady = "wall-read-ready", wallReadScanning = "wall-read-scanning"
        case wallCategoryFallback = "wall-category-fallback", wallSearchEmpty = "wall-search-empty"
        case wallIndexEmpty = "wall-index-empty", wallExtrasHidden = "wall-extras-hidden"
        case mediaEmptyLibrary = "media-empty-library", mediaEmptySearch = "media-empty-search"
        case mediaEmptyError = "media-empty-error", mediaEmptyLong = "media-empty-long"
        case mediaFailureInitial = "media-failure-initial", mediaFailureRetained = "media-failure-retained"
        case mediaFailureLong = "media-failure-long"
        case homeLoadEmpty = "home-load-empty", homeLoadRetained = "home-load-retained"
        case homeLoadShelf = "home-load-shelf"
        case contentLoading = "content-loading", contentLoadingRetained = "content-loading-retained"
        case contentError = "content-error", contentErrorRetained = "content-error-retained"
        case contentErrorSearch = "content-error-search", contentEmpty = "content-empty"
        case searchRetry = "search-retry", detailNotice = "detail-notice"
        case relatedNotice = "related-notice"
        case detailFocusRetry = "detail-focus-retry", detailFocusRetryEmpty = "detail-focus-retry-empty"
        case networkFocusPresentation = "network-focus-presentation"
        case networkFocusDynamic = "network-focus-dynamic", networkFocusLong = "network-focus-long"
        case networkFocusFiles = "network-focus-files", networkFocusReadOnly = "network-focus-read-only"
        case detailFocusRetryOnly = "detail-focus-retry-only", detailFocusActions = "detail-focus-actions"
        case folderPicker = "folder-picker", folderPickerEmpty = "folder-picker-empty"
        case folderPickerRoot = "folder-picker-root", folderPickerLoading = "folder-picker-loading"
        case folderPickerError = "folder-picker-error", folderPickerSelectionError = "folder-picker-selection-error"
        case folderPickerBusy = "folder-picker-busy"
        case folderEdit = "folder-edit", folderEditChanged = "folder-edit-changed"
        case folderEditError = "folder-edit-error", folderEditBusy = "folder-edit-busy"
        case settings, playerSettings = "player-settings", syncSettings = "sync-settings", help, helpDetail = "help-detail"
        case mineInfo = "mine-info", diagnostics
        case themeGallery = "theme-gallery"
        case accountConnections = "account-connections"
        case privacy, privacyReset = "privacy-reset", privacyCache = "privacy-cache", privacyExport = "privacy-export"
        case plus, plusActive = "plus-active", plusExpired = "plus-expired", plusFeatures = "plus-features"
        case connection, connectionHTTP = "connection-http", connectionEdit = "connection-edit"
        case connectionError = "connection-error", connectionBusy = "connection-busy", connectionActions = "connection-actions"
        /// Password-input attribution probes (DEBUG, iOS only). Not form acceptance scenes.
        case passwordProbeSwiftUI = "password-probe-swiftui", passwordProbeUIKit = "password-probe-uikit"
        /// iOS only. Hosts the real "存储与媒体" page without a NAS context for a loopback
        /// synthetic WebDAV fixture the tester adds by hand. Unlike every other scene it uses the
        /// production library store of this install; it never restores a NAS session or scans the LAN.
        case localLibrary = "local-library"
        /// The production launchpad, devices and tasks roots on isolated stores:
        /// sample data, an ephemeral preference domain, no Keychain, network, notifications or sync.
        /// tvOS hosts its own roots in the disconnected state (`TVOfflineRootScene`).
        case launchpadRoot = "launchpad-root", devicesRoot = "devices-root", tasksRoot = "tasks-root"
    }
    public enum Theme: String, Sendable { case cleanGrid, commandCenter, glassDeck }
    public enum Appearance: String, Sendable { case light, dark }
    public enum TextSize: String, Sendable { case standard, large }
    public let scenario: Scenario
    public let theme: Theme
    public let appearance: Appearance
    public let textSize: TextSize
    public let passwordProbe: PasswordProbeOptions
    public init(scenario: Scenario, theme: Theme, appearance: Appearance, textSize: TextSize = .standard,
                passwordProbe: PasswordProbeOptions = .production) {
        self.scenario = scenario; self.theme = theme; self.appearance = appearance; self.textSize = textSize
        self.passwordProbe = passwordProbe
    }

    /// A malformed explicit request stays isolated; it must never fall through
    /// to the ordinary root, which could restore a saved NAS session.
    public static func requested(arguments: [String]) -> Self? {
        let malformedMode = arguments.contains { $0.hasPrefix("--offline-ui=") }
        guard arguments.contains("--offline-ui") || malformedMode else { return nil }
        if malformedMode { return Self(scenario: .invalid, theme: .cleanGrid, appearance: .light) }
        func value(_ flag: String, fallback: String) -> String? {
            let indices = arguments.indices.filter { arguments[$0] == flag }
            if indices.isEmpty { return fallback }
            guard indices.count == 1, let index = indices.first,
                  arguments.indices.contains(index + 1),
                  !arguments[index + 1].hasPrefix("--") else { return nil }
            return arguments[index + 1]
        }
        guard let rawScene = value("--offline-ui", fallback: "library"),
              let scene = Scenario(rawValue: rawScene), scene != .invalid,
              let rawTheme = value("--offline-ui-theme", fallback: "cleanGrid"),
              let theme = Theme(rawValue: rawTheme),
              let rawAppearance = value("--offline-ui-appearance", fallback: "light"),
              let appearance = Appearance(rawValue: rawAppearance),
              let rawTextSize = value("--offline-ui-text-size", fallback: "standard"),
              let textSize = TextSize(rawValue: rawTextSize) else {
            return Self(scenario: .invalid, theme: .cleanGrid, appearance: .light)
        }
        guard let probe = PasswordProbeOptions.parse(arguments: arguments, scenario: scene) else {
            return Self(scenario: .invalid, theme: .cleanGrid, appearance: .light)
        }
        return Self(scenario: scene, theme: theme, appearance: appearance, textSize: textSize, passwordProbe: probe)
    }
}

/// Controls for the password first-edit attribution experiment. The defaults are the
/// production form: prefilled synthetic value, secure entry, content types on, hidden.
/// Nothing here carries or reads text; the synthetic value is a fixed fixture constant.
public struct PasswordProbeOptions: Equatable, Sendable {
    public enum Initial: String, Sendable { case prefilled, empty }
    public enum Secure: String, Sendable { case secure, plain }
    public enum ContentTypes: String, Sendable { case on, off }
    public enum Visibility: String, Sendable { case hidden, visible }
    public enum Modifiers: String, Sendable { case bare, form }
    public var initial: Initial
    public var secure: Secure
    public var contentTypes: ContentTypes
    public var visibility: Visibility
    public var modifiers: Modifiers
    /// Pairing label for anonymous trace rows only: 1...16 of A-Z a-z 0-9 -.
    public var cell: String?
    public init(initial: Initial = .prefilled, secure: Secure = .secure, contentTypes: ContentTypes = .on,
                visibility: Visibility = .hidden, modifiers: Modifiers = .bare, cell: String? = nil) {
        self.initial = initial; self.secure = secure; self.contentTypes = contentTypes
        self.visibility = visibility; self.modifiers = modifiers; self.cell = cell
    }
    public static let production = Self()
    public var isPrefilled: Bool { initial == .prefilled }
    public var isSecure: Bool { secure == .secure }
    public var contentTypesEnabled: Bool { contentTypes == .on }
    public var startsVisible: Bool { visibility == .visible }

    private static let formScenes: Set<OfflineUIConfiguration.Scenario> =
        [.connection, .connectionHTTP, .connectionEdit, .connectionError, .connectionBusy]
    private static let probeScenes: Set<OfflineUIConfiguration.Scenario> = [.passwordProbeSwiftUI, .passwordProbeUIKit]
    private static let flags = ["--offline-password-initial", "--offline-password-secure", "--offline-password-content-type",
                                "--offline-password-start-visible", "--offline-password-modifiers", "--offline-password-cell"]

    private enum Lookup { case absent, value(String), malformed }
    private static func lookup(_ flag: String, in arguments: [String]) -> Lookup {
        let indices = arguments.indices.filter { arguments[$0] == flag }
        if indices.isEmpty { return .absent }
        guard indices.count == 1, let index = indices.first, arguments.indices.contains(index + 1),
              !arguments[index + 1].hasPrefix("--") else { return .malformed }
        return .value(arguments[index + 1])
    }

    /// nil means malformed or used on a scene that does not honor it. The caller then stays on
    /// the isolated invalid scene; it never falls through to the ordinary root.
    static func parse(arguments: [String], scenario: OfflineUIConfiguration.Scenario) -> Self? {
        // Any other --offline-password-* token (including --flag=value) is malformed.
        let known = Set(flags + ["--offline-password-trace"])
        if arguments.contains(where: { $0.hasPrefix("--offline-password-") && !known.contains($0) }) { return nil }
        let isForm = formScenes.contains(scenario), isProbe = probeScenes.contains(scenario)
        var result = Self.production
        func read<T: RawRepresentable>(_ flag: String, allowed: Bool, _ type: T.Type, set: (T) -> Void) -> Bool where T.RawValue == String {
            switch lookup(flag, in: arguments) {
            case .absent: return true
            case .malformed: return false
            case .value(let raw):
                guard allowed, let parsed = T(rawValue: raw) else { return false }
                set(parsed); return true
            }
        }
        guard read("--offline-password-initial", allowed: isForm || isProbe, Initial.self, set: { result.initial = $0 }),
              read("--offline-password-secure", allowed: isProbe, Secure.self, set: { result.secure = $0 }),
              read("--offline-password-content-type", allowed: isForm || isProbe, ContentTypes.self, set: { result.contentTypes = $0 }),
              read("--offline-password-start-visible", allowed: isForm, Visibility.self, set: { result.visibility = $0 }),
              read("--offline-password-modifiers", allowed: isProbe, Modifiers.self, set: { result.modifiers = $0 }) else { return nil }
        switch lookup("--offline-password-cell", in: arguments) {
        case .absent: break
        case .malformed: return nil
        case .value(let raw):
            let valid = (1...16).contains(raw.count) && raw.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
            guard (isForm || isProbe), valid else { return nil }
            result.cell = raw
        }
        return result
    }
}

public struct OfflineMediaFixture: Identifiable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let year: String
    public let hasArtwork: Bool
    public static let items: [Self] = [
        .init(id: 1, title: "山海之间", year: "2024", hasArtwork: true),
        .init(id: 2, title: "星河漫游：一段很长的中文标题与 The Journey Beyond the Stars", year: "2023", hasArtwork: true),
        .init(id: 3, title: "未完成的夏天", year: "2022", hasArtwork: false),
        .init(id: 4, title: "城市来信", year: "2021", hasArtwork: true),
        .init(id: 5, title: "雾中的灯塔", year: "", hasArtwork: true),
        .init(id: 6, title: "远方 · 第一季", year: "2024", hasArtwork: true),
        .init(id: 7, title: "星光小队", year: "2025", hasArtwork: true)
    ]
}
#endif

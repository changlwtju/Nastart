import Foundation
import Combine

protocol AppDataProviding {
    var device: NASDevice { get }
    var services: [LaunchpadService] { get }
    var containers: [DockerContainer] { get }
    var files: [FileItem] { get }
    var tasks: [TaskItem] { get }
    var videoLibraryItems: [MediaItem] { get }
    var audioLibraryItems: [MediaItem] { get }
    var discoveredDevices: [DiscoveredNASDevice] { get }
}

protocol NASDeviceProviding {
    func loadDevice() -> NASDevice
    func discoverDevices() -> [DiscoveredNASDevice]
}

protocol LaunchpadServiceProviding {
    func loadServices() -> [LaunchpadService]
}

protocol DockerProviding {
    func loadContainers() -> [DockerContainer]
}

protocol FileSystemProviding {
    func loadFiles() -> [FileItem]
}

protocol MediaLibraryProviding {
    func loadVideoLibraryItems() -> [MediaItem]
    func loadAudioLibraryItems() -> [MediaItem]
}

protocol ReminderProviding {
    func loadTasks() -> [TaskItem]
}

struct MockAppDataProvider: AppDataProviding, NASDeviceProviding, LaunchpadServiceProviding, DockerProviding, FileSystemProviding, MediaLibraryProviding, ReminderProviding {
    let device = SampleData.device
    let services = SampleData.services
    let containers = SampleData.containers
    let files = SampleData.files
    let tasks = SampleData.tasks
    let videoLibraryItems = SampleData.videoLibraryItems
    let audioLibraryItems = SampleData.audioLibraryItems
    let discoveredDevices = SampleData.discoveredDevices

    func loadDevice() -> NASDevice { device }
    func discoverDevices() -> [DiscoveredNASDevice] { discoveredDevices }
    func loadServices() -> [LaunchpadService] { services }
    func loadContainers() -> [DockerContainer] { containers }
    func loadFiles() -> [FileItem] { files }
    func loadVideoLibraryItems() -> [MediaItem] { videoLibraryItems }
    func loadAudioLibraryItems() -> [MediaItem] { audioLibraryItems }
    func loadTasks() -> [TaskItem] { tasks }
}

final class AppDataStore: ObservableObject {
    @Published private(set) var device: NASDevice
    @Published private(set) var services: [LaunchpadService]
    @Published private(set) var containers: [DockerContainer]
    @Published private(set) var files: [FileItem]
    @Published private(set) var tasks: [TaskItem]
    @Published private(set) var videoLibraryItems: [MediaItem]
    @Published private(set) var audioLibraryItems: [MediaItem]
    @Published private(set) var discoveredDevices: [DiscoveredNASDevice]
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastRefreshSummaryKey = "data.refresh.ready"

    private var provider: AppDataProviding

    init(provider: AppDataProviding = MockAppDataProvider()) {
        self.provider = provider
        device = provider.device
        services = provider.services
        containers = provider.containers
        files = provider.files
        tasks = provider.tasks
        videoLibraryItems = provider.videoLibraryItems
        audioLibraryItems = provider.audioLibraryItems
        discoveredDevices = provider.discoveredDevices
    }

    func reload(from provider: AppDataProviding) {
        self.provider = provider
        device = provider.device
        services = provider.services
        containers = provider.containers
        files = provider.files
        tasks = provider.tasks
        videoLibraryItems = provider.videoLibraryItems
        audioLibraryItems = provider.audioLibraryItems
        discoveredDevices = provider.discoveredDevices
        lastRefreshSummaryKey = "data.refresh.mock_done"
    }

    func refreshAll() {
        isRefreshing = true
        reload(from: provider)
        isRefreshing = false
    }

    func services(in category: ServiceCategory) -> [LaunchpadService] {
        services.filter { $0.category == category }
    }

    func mediaItems(for service: LaunchpadService) -> [MediaItem] {
        service.name == "Navidrome" ? audioLibraryItems : videoLibraryItems
    }

    func selectDiscoveredDevice(_ discoveredDevice: DiscoveredNASDevice) -> NASDevice {
        NASDevice(
            id: device.id,
            name: discoveredDevice.name,
            subtitle: device.subtitle,
            mode: device.mode,
            cpu: device.cpu,
            memory: device.memory,
            storageUsed: device.storageUsed,
            storageFreeText: device.storageFreeText,
            uptimeText: device.uptimeText,
            certificateDaysRemaining: device.certificateDaysRemaining
        )
    }
}

enum PlusStatus {
    case free
    case active
    case expired

    var titleKey: String {
        switch self {
        case .free: return "plus.status.free"
        case .active: return "plus.status.active"
        case .expired: return "plus.status.expired"
        }
    }
}

enum PlusFeature: String {
    case unlimitedCards
    case multipleDevices
    case iCloudSync
    case advancedThemes
    case moreReminders
}

final class ProfileStore: ObservableObject {
    @Published var nickname: String {
        didSet {
            UserDefaults.standard.set(nickname, forKey: Self.nicknameKey)
        }
    }

    @Published var avatarInitial: String {
        didSet {
            UserDefaults.standard.set(avatarInitial, forKey: Self.avatarInitialKey)
        }
    }

    init() {
        nickname = UserDefaults.standard.string(forKey: Self.nicknameKey) ?? NSLocalizedString("mine.profile.name", comment: "")
        avatarInitial = UserDefaults.standard.string(forKey: Self.avatarInitialKey) ?? "N"
    }

    private static let nicknameKey = "profile.nickname"
    private static let avatarInitialKey = "profile.avatarInitial"
}

final class NASConnectionStore: ObservableObject {
    @Published private(set) var connectedDevice: NASDevice?
    @Published private(set) var isConnected: Bool

    init(device: NASDevice? = MockAppDataProvider().device) {
        connectedDevice = device
        isConnected = device != nil
    }

    var profileSubtitleKey: String {
        isConnected ? "mine.profile.connected" : "mine.profile.not_connected"
    }

    func connect(device: NASDevice) {
        connectedDevice = device
        isConnected = true
    }

    func signOut() {
        connectedDevice = nil
        isConnected = false
        KeychainStore.shared.clearNASCredentials()
    }
}

final class EntitlementStore: ObservableObject {
    @Published private(set) var plusStatus: PlusStatus
    @Published private(set) var isRestoring = false

    init(plusStatus: PlusStatus = .free) {
        self.plusStatus = plusStatus
    }

    var hasPlus: Bool {
        plusStatus == .active
    }

    func canUse(_ feature: PlusFeature) -> Bool {
        switch feature {
        case .unlimitedCards, .multipleDevices, .iCloudSync, .advancedThemes, .moreReminders:
            return hasPlus
        }
    }

    func activatePreviewPlus() {
        plusStatus = .active
    }

    func restorePurchases() {
        isRestoring = true
        plusStatus = .active
        isRestoring = false
    }

    func refreshEntitlements() {
        // StoreKit 2 transaction refresh will update this state in the real purchase layer.
    }
}

final class KeychainStore {
    static let shared = KeychainStore()

    private init() {}

    func clearNASCredentials() {
        // Real DSM tokens, Agent tokens, and service API keys will be deleted from Keychain here.
    }
}

import CloudKit
import Foundation

enum CloudSyncAvailability: Equatable {
    case disabled
    case checking
    case available
    case syncing
    case noAccount
    case restricted
    case failed(String)

    var titleKey: String {
        switch self {
        case .disabled: return "mine.sync.status.disabled"
        case .checking: return "mine.sync.status.checking"
        case .available: return "mine.sync.status.available"
        case .syncing: return "mine.sync.status.syncing"
        case .noAccount: return "mine.sync.status.no_account"
        case .restricted: return "mine.sync.status.restricted"
        case .failed: return "mine.sync.status.failed"
        }
    }
}

struct CloudSyncSnapshot: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let updatedAt: Date
    let manualServices: [StoredManualLaunchpadService]
    let serviceVisibilityOverrides: [String: Bool]
    let pendingTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let stringPreferences: [String: String]
    let booleanPreferences: [String: Bool]

    init(
        updatedAt: Date,
        manualServices: [StoredManualLaunchpadService],
        serviceVisibilityOverrides: [String: Bool],
        pendingTasks: [TaskItem],
        completedTasks: [TaskItem],
        stringPreferences: [String: String],
        booleanPreferences: [String: Bool]
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.updatedAt = updatedAt
        self.manualServices = manualServices
        self.serviceVisibilityOverrides = serviceVisibilityOverrides
        self.pendingTasks = pendingTasks
        self.completedTasks = completedTasks
        self.stringPreferences = stringPreferences
        self.booleanPreferences = booleanPreferences
    }
}

@MainActor
final class CloudSyncStore: ObservableObject {
    static let shared = CloudSyncStore()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Self.enabledKey)
            if !isEnabled {
                status = .disabled
            }
        }
    }
    @Published private(set) var status: CloudSyncAvailability
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var lastErrorDetail: String?

    private static let enabledKey = "sync.icloud.enabled.v1"
    private static let localChangeKey = "sync.icloud.localChangeAt.v1"
    private static let lastSuccessKey = "sync.icloud.lastSuccessAt.v1"
    private static let recordType = "NastartSnapshot"
    private static let recordName = "primary-workspace"
    private static let payloadField = "payload"
    private static let updatedAtField = "updatedAt"

    private let defaults: UserDefaults
    private var container: CKContainer?
    private var database: CKDatabase?
    private var synchronizationTask: Task<Void, Never>?
    private var isApplyingRemoteSnapshot = false

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        container = nil
        database = nil
#if NASTART_NO_ICLOUD
        // Free personal development teams cannot sign the CloudKit entitlement.
        // Keep physical-device regression builds usable without touching CKContainer,
        // whose designated initializer raises an exception when the entitlement is absent.
        defaults.set(false, forKey: Self.enabledKey)
        let enabled = false
#else
        let enabled = defaults.bool(forKey: Self.enabledKey)
#endif
        isEnabled = enabled
        lastSuccessfulSyncAt = defaults.object(forKey: Self.lastSuccessKey) as? Date
        status = enabled ? .checking : .disabled
    }

    private func prepareCloudKitIfNeeded() -> Bool {
#if NASTART_NO_ICLOUD
        return false
#else
        if container == nil {
            let cloudContainer = CKContainer(identifier: "iCloud.com.changliwen.nastart")
            container = cloudContainer
            database = cloudContainer.privateCloudDatabase
        }
        return true
#endif
    }

    func setEnabled(
        _ enabled: Bool,
        dataStore: AppDataStore,
        appearanceStore: AppearanceStore
    ) {
        isEnabled = enabled
        guard enabled else {
            synchronizationTask?.cancel()
            synchronizationTask = nil
            return
        }
        scheduleSync(dataStore: dataStore, appearanceStore: appearanceStore, immediate: true)
    }

    func refreshAccountStatus() async {
        guard isEnabled else {
            status = .disabled
            return
        }
        guard prepareCloudKitIfNeeded(), let container else {
            lastErrorDetail = "missing-icloud-entitlement"
            status = .failed("missing-icloud-entitlement")
            return
        }
        status = .checking
        do {
            switch try await container.accountStatus() {
            case .available:
                status = .available
                lastErrorDetail = nil
            case .noAccount:
                status = .noAccount
            case .restricted:
                status = .restricted
            case .couldNotDetermine, .temporarilyUnavailable:
                status = .failed("account-status-unavailable")
            @unknown default:
                status = .failed("account-status-unknown")
            }
        } catch {
            recordFailure(error)
        }
    }

    func markLocalChange() {
        guard !isApplyingRemoteSnapshot else { return }
        Self.noteLocalChange()
    }

    nonisolated static func noteLocalChange() {
        UserDefaults.standard.set(Date(), forKey: "sync.icloud.localChangeAt.v1")
    }

    func scheduleSync(
        dataStore: AppDataStore,
        appearanceStore: AppearanceStore,
        immediate: Bool = false
    ) {
        guard isEnabled else { return }
        synchronizationTask?.cancel()
        synchronizationTask = Task { @MainActor [weak self, weak dataStore, weak appearanceStore] in
            if !immediate {
                try? await Task.sleep(nanoseconds: 900_000_000)
            }
            guard
                !Task.isCancelled,
                let self,
                let dataStore,
                let appearanceStore
            else {
                return
            }
            await self.syncNow(dataStore: dataStore, appearanceStore: appearanceStore)
        }
    }

    func syncNow(dataStore: AppDataStore, appearanceStore: AppearanceStore) async {
        guard isEnabled else {
            status = .disabled
            return
        }
        await refreshAccountStatus()
        guard status == .available else { return }

        status = .syncing
        do {
            guard let database else {
                throw CloudSyncError.missingEntitlement
            }
            let recordID = CKRecord.ID(recordName: Self.recordName)
            let remoteRecord: CKRecord?
            do {
                remoteRecord = try await database.record(for: recordID)
            } catch let error as CKError where error.code == .unknownItem {
                remoteRecord = nil
            }

            let localChangedAt = defaults.object(forKey: Self.localChangeKey) as? Date ?? .distantPast
            if let remoteRecord,
               let remoteData = remoteRecord[Self.payloadField] as? Data,
               let remoteSnapshot = try? JSONDecoder().decode(CloudSyncSnapshot.self, from: remoteData),
               remoteSnapshot.schemaVersion <= CloudSyncSnapshot.currentSchemaVersion,
               remoteSnapshot.updatedAt > localChangedAt {
                isApplyingRemoteSnapshot = true
                dataStore.applyCloudSyncSnapshot(remoteSnapshot)
                appearanceStore.reloadFromDefaults()
                isApplyingRemoteSnapshot = false
                completeSync(at: remoteSnapshot.updatedAt)
                return
            }

            let uploadDate = max(Date(), localChangedAt)
            let snapshot = dataStore.makeCloudSyncSnapshot(updatedAt: uploadDate)
            let payload = try JSONEncoder().encode(snapshot)
            guard payload.count <= 900_000 else {
                throw CloudSyncError.payloadTooLarge
            }
            let record = remoteRecord ?? CKRecord(recordType: Self.recordType, recordID: recordID)
            record[Self.payloadField] = payload as CKRecordValue
            record[Self.updatedAtField] = uploadDate as CKRecordValue
            _ = try await database.save(record)
            completeSync(at: uploadDate)
        } catch {
            isApplyingRemoteSnapshot = false
            recordFailure(error)
        }
    }

    private func completeSync(at date: Date) {
        defaults.set(date, forKey: Self.localChangeKey)
        defaults.set(Date(), forKey: Self.lastSuccessKey)
        lastSuccessfulSyncAt = Date()
        lastErrorDetail = nil
        status = .available
        DiagnosticLogStore.shared.record(
            .info,
            categoryKey: "diagnostics.category.sync",
            messageKey: "diagnostics.sync.completed"
        )
    }

    private func recordFailure(_ error: Error) {
        let detail: String
        if let cloudError = error as? CKError {
            detail = "CloudKit(\(cloudError.code.rawValue))"
        } else {
            detail = String(describing: error)
        }
        lastErrorDetail = detail
        status = .failed(detail)
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.sync",
            messageKey: "diagnostics.sync.failed",
            details: ["error": detail]
        )
    }
}

private enum CloudSyncError: LocalizedError {
    case payloadTooLarge
    case missingEntitlement

    var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            return NSLocalizedString("mine.sync.error.payload_too_large", comment: "")
        case .missingEntitlement:
            return NSLocalizedString("mine.sync.error.missing_entitlement", comment: "")
        }
    }
}

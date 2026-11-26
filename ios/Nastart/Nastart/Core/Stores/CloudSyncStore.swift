import CloudKit
import CryptoKit
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

enum CloudSyncDomain: String, CaseIterable {
    case services, tasks, preferences

    var record: CloudSyncRecord {
        switch self {
        case .services: return .services
        case .tasks: return CloudSyncRecord(recordType: "NastartTasks", recordName: "tasks-workspace")
        case .preferences: return CloudSyncRecord(recordType: "NastartPreferences", recordName: "preferences-workspace")
        }
    }

    var recordType: CKRecord.RecordType { record.recordType }
    var recordID: CKRecord.ID { record.recordID }
    var storagePrefix: String { "sync.icloud.\(rawValue).v2" }
    var changeKey: String { "\(storagePrefix).localChangeAt" }
    var observationKey: String { "\(storagePrefix).observation" }
    var successKey: String { "\(storagePrefix).lastSuccessAt" }
}

struct CloudSyncTasks: Codable {
    let pendingTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let deletedTasks: [DeletedTask]

    init(pendingTasks: [TaskItem], completedTasks: [TaskItem], deletedTasks: [DeletedTask] = []) {
        self.pendingTasks = pendingTasks
        self.completedTasks = completedTasks
        self.deletedTasks = deletedTasks
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        pendingTasks = try values.decode([TaskItem].self, forKey: .pendingTasks)
        completedTasks = try values.decode([TaskItem].self, forKey: .completedTasks)
        deletedTasks = try values.decodeIfPresent([DeletedTask].self, forKey: .deletedTasks) ?? []
    }

    func mergingDeletions(from other: Self) -> Self {
        let deletions = CloudSyncStore.retainedTaskDeletions(deletedTasks + other.deletedTasks)
        let deletedIDs = Set(deletions.map(\.id))
        return Self(
            pendingTasks: pendingTasks.filter { !deletedIDs.contains($0.id) },
            completedTasks: completedTasks.filter { !deletedIDs.contains($0.id) },
            deletedTasks: deletions
        )
    }
}

struct CloudSyncPreferences: Codable {
    let stringPreferences: [String: String]
    let booleanPreferences: [String: Bool]

    static func read(from defaults: UserDefaults) -> Self {
        let stringKeys = [
            LaunchpadTheme.storageKey,
            AppLanguage.storageKey,
            AppThemeMode.storageKey,
            AppearancePreferenceKeys.groupOrder
        ]
        let booleanKeys = [
            AppearancePreferenceKeys.compactMetrics,
            AppearancePreferenceKeys.showServiceStatus,
            AppearancePreferenceKeys.showCardSubtitle,
            AppearancePreferenceKeys.groupFavoritesExpanded,
            AppearancePreferenceKeys.groupMediaExpanded,
            AppearancePreferenceKeys.groupDownloadsExpanded,
            AppearancePreferenceKeys.groupNetworkExpanded,
            AppearancePreferenceKeys.groupToolsExpanded
        ]
        return Self(
            stringPreferences: Dictionary(uniqueKeysWithValues: stringKeys.compactMap { key in
                defaults.string(forKey: key).map { (key, $0) }
            }),
            booleanPreferences: Dictionary(uniqueKeysWithValues: booleanKeys.compactMap { key in
                defaults.object(forKey: key).map { _ in (key, defaults.bool(forKey: key)) }
            })
        )
    }

    func apply(to defaults: UserDefaults) {
        stringPreferences.forEach { defaults.set($0.value, forKey: $0.key) }
        booleanPreferences.forEach { defaults.set($0.value, forKey: $0.key) }
    }
}

private struct CloudSyncSnapshot: Decodable {
    let schemaVersion: Int
    let updatedAt: Date
    let manualServices: [StoredManualLaunchpadService]
    let serviceVisibilityOverrides: [String: Bool]
    let pendingTasks: [TaskItem]
    let completedTasks: [TaskItem]
    let stringPreferences: [String: String]
    let booleanPreferences: [String: Bool]

    var services: CloudSyncServices {
        CloudSyncServices(manualServices: manualServices, serviceVisibilityOverrides: serviceVisibilityOverrides)
    }

    var tasks: CloudSyncTasks {
        CloudSyncTasks(pendingTasks: pendingTasks, completedTasks: completedTasks)
    }

    var preferences: CloudSyncPreferences {
        CloudSyncPreferences(stringPreferences: stringPreferences, booleanPreferences: booleanPreferences)
    }
}

@MainActor
final class CloudSyncStore: ObservableObject {
    static let shared = CloudSyncStore()
    nonisolated static let tombstoneRetentionDays = 30

    nonisolated static func retainedTaskDeletions(_ deletions: [DeletedTask], now: Date = Date()) -> [DeletedTask] {
        let cutoff = now.addingTimeInterval(-TimeInterval(tombstoneRetentionDays * 24 * 60 * 60))
        return Dictionary(deletions.map { ($0.id, $0) }, uniquingKeysWith: { first, second in
            first.deletedAt <= second.deletedAt ? first : second
        }).values
            .filter { $0.deletedAt >= cutoff }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

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
    @Published private(set) var hasPendingChanges = false
    @Published private(set) var lastErrorDetail: String?

    private static let enabledKey = "sync.icloud.enabled.v1"
    private static let legacyChangeKey = "sync.icloud.localChangeAt.v1"
    private static let legacyLastSuccessKey = "sync.icloud.lastSuccessAt.v1"
    private static let migrationCheckedKey = "sync.icloud.legacyMigrationChecked.v2"
    private static let migrationField = "migratedToSchemaVersion"
    private static let legacyRecordID = CKRecord.ID(recordName: "primary-workspace")

    private struct LegacyMigration {
        let record: CKRecord
        let snapshot: CloudSyncSnapshot
    }

    private struct LocalObservation: Codable {
        let fingerprint: Data
        let updatedAt: Date
        let observedAt: Date
        let syncedRemoteFingerprint: Data?
    }

    private let defaults: UserDefaults
    private var container: CKContainer?
    private var database: (any CloudSyncDatabase)?
    private let hasInjectedDatabase: Bool
    private var synchronizationTask: Task<Void, Never>?
    private var isSyncInFlight = false

    private static let maxSyncAttempts = 3

    init(defaults: UserDefaults = .standard, database: (any CloudSyncDatabase)? = nil) {
        self.defaults = defaults
        self.database = database
        hasInjectedDatabase = database != nil
#if NASTART_NO_ICLOUD
        // Free personal development teams cannot sign the CloudKit entitlement.
        // CKContainer must stay untouched unless the build has the entitlement.
        if database == nil {
            defaults.set(false, forKey: Self.enabledKey)
        }
#endif
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        lastSuccessfulSyncAt = CloudSyncDomain.allCases
            .compactMap { defaults.object(forKey: $0.successKey) as? Date }
            .max() ?? (defaults.object(forKey: Self.legacyLastSuccessKey) as? Date)
        status = enabled ? .checking : .disabled
        observePreferencesChange()
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
        if hasInjectedDatabase {
            status = .available
            lastErrorDetail = nil
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

    nonisolated static func noteLocalChange(in domain: CloudSyncDomain) {
        UserDefaults.standard.set(Date(), forKey: domain.changeKey)
    }

    func observePreferencesChange() {
        defer { refreshPendingChanges() }
        guard let payload = try? CloudSyncRecord.encode(CloudSyncPreferences.read(from: defaults)) else { return }
        _ = observeLocalPayload(payload, in: .preferences)
    }

    func observeDataStoreChange(in domain: CloudSyncDomain) {
        // Observe the existing edit clock without rebasing the snapshot used for merging.
        defaults.set(Date(), forKey: domain.changeKey)
        refreshPendingChanges()
    }

    func invalidateMigrationCheck() {
        defaults.removeObject(forKey: Self.migrationCheckedKey)
    }

    func lastSuccessfulSyncAt(for domain: CloudSyncDomain) -> Date? {
        defaults.object(forKey: domain.successKey) as? Date
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
        guard !isSyncInFlight else { return }
        isSyncInFlight = true
        defer { isSyncInFlight = false }

        await refreshAccountStatus()
        guard status == .available else { return }

        guard isEnabled, !Task.isCancelled, let database else { return }
        status = .syncing
        let migration: Result<LegacyMigration?, Error>
        do {
            migration = .success(try await loadLegacyMigration(database: database))
        } catch {
            migration = .failure(error)
        }

        async let servicesError = syncDomain(
            .services, database: database, migration: migration, legacyPayload: { $0.services },
            readLocal: dataStore.makeCloudSyncServices, applyRemote: dataStore.applyCloudSyncServices
        )
        async let tasksError = syncDomain(
            .tasks, database: database, migration: migration, legacyPayload: { $0.tasks },
            merge: { preferred, other in preferred.mergingDeletions(from: other) },
            readLocal: dataStore.makeCloudSyncTasks, applyRemote: dataStore.applyCloudSyncTasks
        )
        async let preferencesError = syncDomain(
            .preferences, database: database, migration: migration, legacyPayload: { $0.preferences },
            readLocal: { CloudSyncPreferences.read(from: self.defaults) },
            applyRemote: { preferences in
                preferences.apply(to: self.defaults)
                appearanceStore.reloadFromDefaults()
            }
        )
        let failures = await [servicesError, tasksError, preferencesError].compactMap { $0 }
        guard isEnabled, !Task.isCancelled else {
            if isEnabled { status = .available }
            return
        }

        do {
            if let failure = failures.first { throw failure }
            if let legacy = try migration.get() {
                legacy.record[Self.migrationField] = CloudSyncRecord.schemaVersion as CKRecordValue
                try await database.store(legacy.record)
                defaults.set(true, forKey: Self.migrationCheckedKey)
            }
            lastErrorDetail = nil
            status = .available
            DiagnosticLogStore.shared.record(
                .info,
                categoryKey: "diagnostics.category.sync",
                messageKey: "diagnostics.sync.completed"
            )
        } catch {
            if isEnabled, !Task.isCancelled { recordFailure(error) }
        }
    }

    private func loadLegacyMigration(database: any CloudSyncDatabase) async throws -> LegacyMigration? {
        guard !defaults.bool(forKey: Self.migrationCheckedKey) else { return nil }
        let record = try await fetchWithRetry(Self.legacyRecordID, database: database)
        try checkSynchronization()
        guard let record, (record[Self.migrationField] as? Int ?? 0) < CloudSyncRecord.schemaVersion else {
            defaults.set(true, forKey: Self.migrationCheckedKey)
            return nil
        }
        guard record.recordType == "NastartSnapshot",
              let payload = record[CloudSyncRecord.payloadField] as? Data,
              let snapshot = try? JSONDecoder().decode(CloudSyncSnapshot.self, from: payload),
              snapshot.schemaVersion == 1 else {
            throw CloudSyncError.incompatibleRemoteSnapshot
        }
        return LegacyMigration(record: record, snapshot: snapshot)
    }

    private func syncDomain<Payload: Codable>(
        _ domain: CloudSyncDomain,
        database: any CloudSyncDatabase,
        migration: Result<LegacyMigration?, Error>,
        legacyPayload: @MainActor (CloudSyncSnapshot) -> Payload,
        merge: (@MainActor (Payload, Payload) -> Payload)? = nil,
        readLocal: @MainActor () -> Payload,
        applyRemote: @MainActor (Payload) -> Void
    ) async -> Error? {
        defer { refreshPendingChanges() }
        do {
            try await syncRecord(
                domain, database: database, migration: migration,
                legacyPayload: legacyPayload, merge: merge, readLocal: readLocal, applyRemote: applyRemote
            )
            try checkSynchronization()
            let now = Date()
            defaults.set(now, forKey: domain.successKey)
            lastSuccessfulSyncAt = now
            return nil
        } catch {
            return error
        }
    }

    private func syncRecord<Payload: Codable>(
        _ domain: CloudSyncDomain,
        database: any CloudSyncDatabase,
        migration: Result<LegacyMigration?, Error>,
        legacyPayload: @MainActor (CloudSyncSnapshot) -> Payload,
        merge: (@MainActor (Payload, Payload) -> Payload)?,
        readLocal: @MainActor () -> Payload,
        applyRemote: @MainActor (Payload) -> Void
    ) async throws {
        for attempt in 0..<Self.maxSyncAttempts {
            try checkSynchronization()
            var remote = try await fetchWithRetry(domain.recordID, database: database)
            try checkSynchronization()

            do {
                // Seed only missing records. Successful seeds remain usable if
                // another domain fails or a different device completes migration.
                if remote == nil, let legacy = try migration.get() {
                    let payload = try CloudSyncRecord.encode(legacyPayload(legacy.snapshot))
                    try await domain.record.write(payload, at: legacy.snapshot.updatedAt,
                                    replacing: nil, database: database)
                    remote = try await fetchWithRetry(domain.recordID, database: database)
                    try checkSynchronization()
                    guard remote != nil else { throw CloudSyncError.incompatibleRemoteSnapshot }
                }

                let localValue = readLocal()
                var uploadPayload = try CloudSyncRecord.encode(localValue)
                let local = observeLocalPayload(uploadPayload, in: domain)
                var uploadFingerprint = local.fingerprint
                var uploadDate = local.updatedAt
                if let remote {
                    let (remoteValue, remoteUpdatedAt): (Payload, Date) = try domain.record.decode(remote)
                    let remotePayload = try CloudSyncRecord.encode(remoteValue)
                    let remoteFingerprint = Self.fingerprint(remotePayload)
                    if local.fingerprint == remoteFingerprint || local.syncedRemoteFingerprint == remoteFingerprint {
                        acknowledge(local.fingerprint, remoteFingerprint: remoteFingerprint,
                                    at: remoteUpdatedAt, in: domain)
                        return
                    }
                    let preferRemote = CloudSyncMergePolicy.decision(
                        remoteUpdatedAt: remoteUpdatedAt, localChangedAt: local.updatedAt
                    ) == .applyRemote
                    let merged = merge.map {
                        preferRemote ? $0(remoteValue, localValue) : $0(localValue, remoteValue)
                    }
                    let mergedPayload = try merged.map { try CloudSyncRecord.encode($0) }
                    if preferRemote, mergedPayload == nil || mergedPayload == remotePayload {
                        applyRemote(remoteValue)
                        acknowledge(Self.fingerprint(try CloudSyncRecord.encode(readLocal())), remoteFingerprint: remoteFingerprint,
                                    at: remoteUpdatedAt, in: domain)
                        return
                    }
                    if preferRemote { uploadDate = remoteUpdatedAt }
                    if let merged, mergedPayload != uploadPayload {
                        // Persist incoming deletions even when the repaired record cannot be written yet.
                        applyRemote(merged)
                        uploadPayload = try CloudSyncRecord.encode(readLocal())
                        uploadFingerprint = Self.fingerprint(uploadPayload)
                        saveObservation(LocalObservation(
                            fingerprint: uploadFingerprint, updatedAt: uploadDate,
                            observedAt: Date(), syncedRemoteFingerprint: nil
                        ), in: domain)
                    }
                }

                if uploadDate == .distantPast { uploadDate = Date() }
                try await domain.record.write(uploadPayload, at: uploadDate, replacing: remote, database: database)
                try checkSynchronization()
                if Self.fingerprint(try CloudSyncRecord.encode(readLocal())) != uploadFingerprint { continue }
                acknowledge(uploadFingerprint, remoteFingerprint: uploadFingerprint, at: uploadDate, in: domain)
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                guard attempt + 1 < Self.maxSyncAttempts else { throw CloudSyncError.conflictRetryLimit }
            } catch let error as CKError where Self.isRetryable(error) {
                guard attempt + 1 < Self.maxSyncAttempts else { throw error }
                try await backOff(after: attempt)
            }
        }
        throw CloudSyncError.localChangesDuringSync
    }

    private func fetchWithRetry(_ id: CKRecord.ID, database: any CloudSyncDatabase) async throws -> CKRecord? {
        for attempt in 0..<Self.maxSyncAttempts {
            try checkSynchronization()
            do {
                return try await database.fetch(id)
            } catch let error as CKError where Self.isRetryable(error) && attempt + 1 < Self.maxSyncAttempts {
                try await backOff(after: attempt)
            }
        }
        throw CloudSyncError.conflictRetryLimit
    }

    private func backOff(after attempt: Int) async throws {
        try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 500_000_000)
    }

    private func checkSynchronization() throws {
        guard isEnabled else { throw CancellationError() }
        try Task.checkCancellation()
    }

    private static func fingerprint(_ payload: Data) -> Data {
        Data(SHA256.hash(data: payload))
    }

    private func observeLocalPayload(_ payload: Data, in domain: CloudSyncDomain) -> LocalObservation {
        let fingerprint = Self.fingerprint(payload)
        let previous = savedObservation(in: domain)
        if let previous, previous.fingerprint == fingerprint { return previous }

        let now = Date()
        let explicitChange = defaults.object(forKey: domain.changeKey) as? Date
        let updatedAt: Date
        if let previous {
            if let explicitChange, explicitChange > previous.observedAt {
                updatedAt = explicitChange
            } else {
                updatedAt = now
            }
        } else {
            // v1 stored a single clock. Use it only to bootstrap each domain.
            updatedAt = explicitChange ?? (defaults.object(forKey: Self.legacyChangeKey) as? Date) ?? .distantPast
        }
        let observation = LocalObservation(
            fingerprint: fingerprint, updatedAt: updatedAt, observedAt: now, syncedRemoteFingerprint: nil
        )
        saveObservation(observation, in: domain)
        return observation
    }

    private func acknowledge(_ fingerprint: Data, remoteFingerprint: Data, at date: Date, in domain: CloudSyncDomain) {
        saveObservation(
            LocalObservation(fingerprint: fingerprint, updatedAt: date,
                             observedAt: Date(), syncedRemoteFingerprint: remoteFingerprint),
            in: domain
        )
    }

    private func saveObservation(_ observation: LocalObservation, in domain: CloudSyncDomain) {
        defaults.set(try? JSONEncoder().encode(observation), forKey: domain.observationKey)
    }

    private func savedObservation(in domain: CloudSyncDomain) -> LocalObservation? {
        defaults.data(forKey: domain.observationKey)
            .flatMap { try? JSONDecoder().decode(LocalObservation.self, from: $0) }
    }

    private func refreshPendingChanges() {
        let legacySuccess = defaults.object(forKey: Self.legacyLastSuccessKey) as? Date
        let pending = CloudSyncDomain.allCases.contains { domain in
            let lastSuccess = lastSuccessfulSyncAt(for: domain) ?? legacySuccess ?? .distantPast
            if let editedAt = defaults.object(forKey: domain.changeKey) as? Date, editedAt > lastSuccess {
                return true
            }
            guard let observation = savedObservation(in: domain), observation.syncedRemoteFingerprint == nil else {
                return false
            }
            return observation.updatedAt > lastSuccess
        }
        if pending != hasPendingChanges { hasPendingChanges = pending }
    }

    private static func isRetryable(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return true
        default:
            return false
        }
    }

    private func recordFailure(_ error: Error) {
        let detail = Self.diagnosticDetail(for: error)
        lastErrorDetail = detail
        status = .failed(detail)
        DiagnosticLogStore.shared.record(
            .warning,
            categoryKey: "diagnostics.category.sync",
            messageKey: "diagnostics.sync.failed",
            details: ["error": detail]
        )
    }

    private static func diagnosticDetail(for error: Error) -> String {
        if let cloudError = error as? CKError {
            return "cloudkit:\(cloudError.code.rawValue)"
        }
        if let syncError = error as? CloudSyncError {
            return syncError.diagnosticCode
        }
        return NetworkErrorKind.diagnosticMessage(for: error)
    }
}

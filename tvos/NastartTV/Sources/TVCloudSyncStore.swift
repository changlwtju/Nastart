import CloudKit
import Combine
import Foundation

@MainActor
final class TVCloudSyncStore: ObservableObject {
    static let visibilityKey = "tv.service.visibility.v1"
    private static let migrationKey = "tv.service.visibility.iosKeysMigrated.v1"
    private static let pendingKey = "tv.service.visibility.pending.v1"

    private struct PendingVisibility: Codable, Equatable {
        var edits: [String: Bool]
        var updatedAt: Date
    }

    @Published private(set) var overrides: [String: Bool]
    private let defaults: UserDefaults
    private let database: (any CloudSyncDatabase)?
    private let now: () -> Date
    private var pending: PendingVisibility?
    private var synchronization: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard, database: (any CloudSyncDatabase)? = nil, now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.database = database
        self.now = now
        let decoder = JSONDecoder()
        let saved = defaults.data(forKey: Self.visibilityKey)
            .flatMap { try? decoder.decode([String: Bool].self, from: $0) } ?? [:]
        let edits = defaults.data(forKey: Self.pendingKey)
            .flatMap { try? decoder.decode(PendingVisibility.self, from: $0) }
        pending = edits
        overrides = saved.merging(edits?.edits ?? [:]) { _, edited in edited }
    }

    static func forCurrentInstallation() -> TVCloudSyncStore {
        #if NASTART_TV_ICLOUD
        return TVCloudSyncStore(database: CKContainer.default().privateCloudDatabase)
        #else
        return TVCloudSyncStore()
        #endif
    }

    func isVisible(_ service: TVDiscoveredService) -> Bool {
        service.launchpadVisibilityKey.flatMap { overrides[$0] } ?? service.defaultLaunchpadVisible
    }

    func visibleContainers(in services: [TVDiscoveredService]) -> [TVDiscoveredService] {
        services.filter { $0.kind == "容器" && isVisible($0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func migrateLegacyVisibility(using discovery: TVServiceDiscovery) {
        guard !defaults.bool(forKey: Self.migrationKey) else { return }
        var migrated = overrides
        var unresolved = false
        for oldKey in overrides.keys.sorted() where Self.isLegacyKey(oldKey) {
            let inventoryAvailable = oldKey.hasPrefix("container:")
                ? discovery.containerInventoryAvailable : discovery.packageInventoryAvailable
            guard inventoryAvailable else {
                unresolved = true
                continue
            }
            guard let value = migrated.removeValue(forKey: oldKey),
                  let service = discovery.services.first(where: { $0.id == oldKey }),
                  let key = service.launchpadVisibilityKey,
                  migrated[key] == nil else { continue }
            migrated[key] = value
        }
        saveVisibility(migrated)
        if !unresolved { defaults.set(true, forKey: Self.migrationKey) }
    }

    func applicationBecameActive() async {
        await synchronize()
    }

    func toggle(_ service: TVDiscoveredService) async {
        guard let key = service.launchpadVisibilityKey else { return }
        let value = !isVisible(service)
        var changes = pending?.edits ?? [:]
        changes[key] = value
        let edit = PendingVisibility(edits: changes, updatedAt: now())
        pending = edit
        defaults.set(try? JSONEncoder().encode(edit), forKey: Self.pendingKey)
        var updated = overrides
        // The two platforms have different defaults. Send the explicit choice.
        updated[key] = value
        saveVisibility(updated)
        await synchronize()
    }

    private func synchronize() async {
        guard let database else { return }
        if let synchronization {
            await synchronization.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.synchronization = nil }
            await self.syncRecord(in: database)
        }
        synchronization = task
        await task.value
    }

    private func syncRecord(in database: any CloudSyncDatabase) async {
        let workspace = CloudSyncRecord.services
        for _ in 0..<3 {
            do {
                // iOS owns record creation so its v1 service payload can seed v2.
                guard let record = try await database.fetch(workspace.recordID) else { return }
                let (remote, remoteDate): (CloudSyncServices, Date) = try workspace.decode(record)
                var visibility = remote.serviceVisibilityOverrides
                if let edit = pending,
                   CloudSyncMergePolicy.decision(remoteUpdatedAt: remoteDate, localChangedAt: edit.updatedAt) == .uploadLocal {
                    visibility.merge(edit.edits) { _, edited in edited }
                    if visibility != remote.serviceVisibilityOverrides {
                        let data = try CloudSyncServices.updatingVisibility(visibility, in: record)
                        try await workspace.write(data, at: edit.updatedAt, replacing: record, database: database)
                        if pending != edit { continue }
                    }
                }
                let legacy = overrides.filter { Self.isLegacyKey($0.key) }
                saveVisibility(visibility.merging(legacy) { current, _ in current })
                pending = nil
                defaults.removeObject(forKey: Self.pendingKey)
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            } catch {
                // A later activation or toggle retries using a fresh record.
                return
            }
        }
    }

    private static func isLegacyKey(_ key: String) -> Bool {
        key.hasPrefix("container:") || key.hasPrefix("package:")
    }

    private func saveVisibility(_ visibility: [String: Bool]) {
        defaults.set(try? JSONEncoder().encode(visibility), forKey: Self.visibilityKey)
        if visibility != overrides { overrides = visibility }
    }
}

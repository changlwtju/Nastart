import CloudKit
import XCTest

#if os(tvOS)
@testable import NastartTV
#else
@testable import Nastart
#endif

private enum ServiceVisibilityFixture {
    // The names and images are from a saved iPhone DSM discovery snapshot.
    // IDs are fixture-only. Keys reflect the corresponding saved iOS card fields.
    static let containers = [
        ["id": "web", "name": "homepage", "image": "ghcr.io/gethomepage/homepage:latest", "status": "running"],
        ["id": "proxy", "name": "homepage-dockerproxy", "image": "ghcr.io/tecnativa/docker-socket-proxy:latest", "status": "exited"],
        ["id": "media", "name": "jellyfin", "image": "jellyfin/jellyfin:latest", "status": "running"]
    ]
    static let containerKeys = [
        "container|homepage|ghcr.io/gethomepage/homepage:latest",
        "container|homepage-dockerproxy|ghcr.io/tecnativa/docker-socket-proxy:latest",
        "container|jellyfin|jellyfin/jellyfin:latest"
    ]
    static let package = ["id": "DownloadStation", "display_name": "Download Station", "version": "4.1.0"]
    static let packageKey = "package|download station"
    static let date = Date(timeIntervalSince1970: 20_000)
    static let manual = StoredManualLaunchpadService(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Manual service", endpointString: "https://manual.example.test", categoryRawValue: "tools",
        iconText: "M", createdAt: date
    )
}

@MainActor
private final class ServiceVisibilityDatabase: CloudSyncDatabase {
    private var records: [String: CKRecord] = [:]
    var record: CKRecord? { records[CloudSyncRecord.services.recordName] }
    private(set) var reads: [String] = []
    private(set) var writes: [String] = []
    var failRead = false
    var beforeStore: (() throws -> Void)?

    func fetch(_ id: CKRecord.ID) async throws -> CKRecord? {
        reads.append(id.recordName)
        if failRead { throw URLError(.notConnectedToInternet) }
        return records[id.recordName]?.copy() as? CKRecord
    }

    func store(_ record: CKRecord) async throws {
        try beforeStore?()
        writes.append(record.recordID.recordName)
        records[record.recordID.recordName] = record.copy() as? CKRecord
    }

    func publish(visibility: [String: Bool], date: Date, withManualField value: String? = nil) throws {
        let payload = CloudSyncServices(manualServices: [ServiceVisibilityFixture.manual],
                                        serviceVisibilityOverrides: visibility)
        var data = try CloudSyncRecord.encode(payload)
        if let value {
            var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            var services = try XCTUnwrap(fields["manualServices"] as? [[String: Any]])
            services[0]["futureField"] = ["value": value]
            fields["manualServices"] = services
            data = try JSONSerialization.data(withJSONObject: fields)
        }
        let services = CloudSyncRecord.services
        let record = CKRecord(recordType: services.recordType, recordID: services.recordID)
        record["updatedAt"] = date as CKRecordValue
        record["schemaVersion"] = CloudSyncRecord.schemaVersion as CKRecordValue
        record[CloudSyncRecord.payloadField] = data as CKRecordValue
        records[services.recordName] = record
    }

    func payload() throws -> CloudSyncServices {
        let (services, _): (CloudSyncServices, Date) = try CloudSyncRecord.services.decode(XCTUnwrap(record))
        return services
    }

    func rawManualServices() throws -> Data {
        let data = try XCTUnwrap(XCTUnwrap(record)[CloudSyncRecord.payloadField] as? Data)
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try JSONSerialization.data(withJSONObject: XCTUnwrap(fields["manualServices"]), options: .sortedKeys)
    }
}

@MainActor
final class ServiceVisibilityIdentityTests: XCTestCase {
    private typealias Fixture = ServiceVisibilityFixture

    #if os(tvOS)
    func testIOSAndTVServicesRecordRoundTrip() async throws {
        let suite = "service-sync.round-trip.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let database = ServiceVisibilityDatabase()
        let tv = TVCloudSyncStore(defaults: defaults, database: database, now: { Fixture.date + 1 })
        let containers = TVDSMClient.containerServices(Fixture.containers)
        let jellyfin = try XCTUnwrap(containers.first { $0.id == "container:media" })
        let jellyfinKey = Fixture.containerKeys[2]
        let homepageKey = Fixture.containerKeys[0]
        let record = CloudSyncRecord.services
        let iOSPayload = CloudSyncServices(
            manualServices: [Fixture.manual], serviceVisibilityOverrides: [jellyfinKey: false, homepageKey: false]
        )
        try await record.write(CloudSyncRecord.encode(iOSPayload), at: Fixture.date, replacing: nil, database: database)
        let originalManual = try database.rawManualServices()

        await tv.applicationBecameActive()
        XCTAssertEqual(jellyfin.launchpadVisibilityKey, jellyfinKey)
        XCTAssertFalse(tv.visibleContainers(in: containers).contains { $0.id == jellyfin.id })
        XCTAssertEqual(tv.overrides, iOSPayload.serviceVisibilityOverrides)
        XCTAssertEqual(database.writes, ["services-workspace"])

        await tv.toggle(jellyfin)
        XCTAssertTrue(tv.visibleContainers(in: containers).contains { $0.id == jellyfin.id })
        let returned = try await database.fetch(record.recordID)
        let (iOSReadback, updatedAt): (CloudSyncServices, Date) = try record.decode(XCTUnwrap(returned))
        XCTAssertEqual(updatedAt, Fixture.date + 1)
        XCTAssertEqual(iOSReadback.serviceVisibilityOverrides, [jellyfinKey: true, homepageKey: false])
        XCTAssertEqual(try CloudSyncRecord.encode(iOSReadback.manualServices), try CloudSyncRecord.encode(iOSPayload.manualServices))
        XCTAssertEqual(try database.rawManualServices(), originalManual)
        XCTAssertEqual(database.reads, ["services-workspace", "services-workspace", "services-workspace"])
        XCTAssertEqual(database.writes, ["services-workspace", "services-workspace"])
    }

    func testDiscoveredContainerKeysMatchSavedIOSKeys() async throws {
        let services = TVDSMClient.containerServices(Fixture.containers)
        XCTAssertEqual(services.map(\.name), ["homepage", "homepage-dockerproxy", "jellyfin"])
        XCTAssertEqual(services.compactMap(\.launchpadVisibilityKey), Fixture.containerKeys)
        XCTAssertEqual(TVDSMClient.packageServices([Fixture.package]).first?.launchpadVisibilityKey, Fixture.packageKey)
        let aliases = TVDSMClient.containerServices([
            ["Names": [" /arbitrary-name "], "repository": " JELLYFIN/JELLYFIN:LATEST "],
            ["image": "jellyfin/jellyfin:latest"]
        ])
        XCTAssertEqual(aliases[0].launchpadVisibilityKey, Fixture.containerKeys[2])
        XCTAssertNil(aliases[1].launchpadVisibilityKey)
    }

    func testLaunchAndForegroundReadIOSOverridesAndHideLaunchpadContainers() async throws {
        let name = "service-sync.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let database = ServiceVisibilityDatabase()
        let store = TVCloudSyncStore(defaults: defaults, database: database)
        let services = TVDSMClient.containerServices(Fixture.containers)
        let key = Fixture.containerKeys[2]
        try database.publish(visibility: [key: false], date: Fixture.date)

        await store.applicationBecameActive()
        XCTAssertFalse(store.isVisible(services[2]))
        XCTAssertFalse(store.visibleContainers(in: services).contains { $0.id == "container:media" })
        let saved = try XCTUnwrap(defaults.data(forKey: TVCloudSyncStore.visibilityKey))
        XCTAssertEqual(try JSONDecoder().decode([String: Bool].self, from: saved), [key: false])

        try database.publish(visibility: [key: true], date: Fixture.date + 1)
        await store.applicationBecameActive()
        XCTAssertTrue(store.isVisible(services[2]))
        XCTAssertEqual(database.reads, ["services-workspace", "services-workspace"])
        XCTAssertTrue(database.writes.isEmpty)
    }

    func testTVToggleWritesOnlyServicesAndPreservesManualPayloadAndOtherKeys() async throws {
        let name = "service-sync.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let database = ServiceVisibilityDatabase()
        let store = TVCloudSyncStore(defaults: defaults, database: database, now: { Fixture.date + 1 })
        let service = TVDSMClient.containerServices(Fixture.containers)[2]
        let key = Fixture.containerKeys[2]
        let otherKey = "manual|\(Fixture.manual.id.uuidString)"
        try database.publish(visibility: [key: false, otherKey: true], date: Fixture.date, withManualField: "keep this field")
        let originalManual = try database.rawManualServices()

        await store.applicationBecameActive()
        await store.toggle(service)
        XCTAssertEqual(try database.payload().serviceVisibilityOverrides, [key: true, otherKey: true])
        XCTAssertEqual(try database.rawManualServices(), originalManual)
        XCTAssertEqual(database.reads, ["services-workspace", "services-workspace"])
        XCTAssertEqual(database.writes, ["services-workspace"])
        XCTAssertTrue(store.isVisible(service))
    }

    func testMigrationWaitsForDiscoveryAndRekeysOnlyMatchingLegacyRows() async throws {
        let name = "service-sync.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let originals = ["container:media": false, "container:removed": true, "package:DownloadStation": false,
                         Fixture.containerKeys[0]: true]
        defaults.set(try JSONEncoder().encode(originals), forKey: TVCloudSyncStore.visibilityKey)
        let store = TVCloudSyncStore(defaults: defaults)
        store.migrateLegacyVisibility(using: TVServiceDiscovery())
        XCTAssertEqual(store.overrides, originals)

        let services = TVDSMClient.containerServices(Fixture.containers) + TVDSMClient.packageServices([Fixture.package])
        let discovery = TVServiceDiscovery(services: services, containerInventoryAvailable: true, packageInventoryAvailable: true)
        store.migrateLegacyVisibility(using: discovery)
        let expected = [Fixture.containerKeys[2]: false, Fixture.packageKey: false, Fixture.containerKeys[0]: true]
        XCTAssertEqual(store.overrides, expected)
        let reopened = TVCloudSyncStore(defaults: defaults)
        XCTAssertEqual(reopened.overrides, expected)
        XCTAssertFalse(reopened.isVisible(services[2]))
        XCTAssertTrue(defaults.bool(forKey: "tv.service.visibility.iosKeysMigrated.v1"))
    }

    func testFailedPullKeepsOverridesAndNewerRemoteWinsAfterRestart() async throws {
        let name = "service-sync.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let database = ServiceVisibilityDatabase()
        let key = Fixture.containerKeys[2]
        let service = TVDSMClient.containerServices(Fixture.containers)[2]
        let store = TVCloudSyncStore(defaults: defaults, database: database, now: { Fixture.date })
        database.failRead = true
        await store.toggle(service)
        await store.applicationBecameActive()
        XCTAssertEqual(store.overrides, [key: false])

        database.failRead = false
        try database.publish(visibility: [key: true], date: Fixture.date + 1)
        let reopened = TVCloudSyncStore(defaults: defaults, database: database)
        XCTAssertEqual(reopened.overrides, [key: false])
        await reopened.applicationBecameActive()
        XCTAssertEqual(reopened.overrides, [key: true])
        XCTAssertTrue(database.writes.isEmpty)
    }

    func testMissingRecordLeavesMigrationToIOSAndConflictRefetchesManualData() async throws {
        let name = "service-sync.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let database = ServiceVisibilityDatabase()
        let service = TVDSMClient.containerServices(Fixture.containers)[2]
        let store = TVCloudSyncStore(defaults: defaults, database: database, now: { Fixture.date + 2 })

        await store.toggle(service)
        XCTAssertTrue(database.writes.isEmpty)
        XCTAssertFalse(store.isVisible(service))
        defaults.removeObject(forKey: TVCloudSyncStore.visibilityKey)
        let recovered = TVCloudSyncStore(defaults: defaults, database: database, now: { Fixture.date + 2 })
        try database.publish(visibility: [:], date: Fixture.date, withManualField: "before conflict")
        var expectedManual: Data?
        database.beforeStore = {
            database.beforeStore = nil
            try database.publish(visibility: [:], date: Fixture.date + 1, withManualField: "after conflict")
            expectedManual = try database.rawManualServices()
            throw CKError(.serverRecordChanged)
        }
        await recovered.applicationBecameActive()
        XCTAssertEqual(database.reads, Array(repeating: "services-workspace", count: 3))
        XCTAssertEqual(database.writes, ["services-workspace"])
        XCTAssertEqual(try database.rawManualServices(), try XCTUnwrap(expectedManual))
        XCTAssertEqual(try database.payload().serviceVisibilityOverrides, [Fixture.containerKeys[2]: false])
        XCTAssertFalse(TVCloudSyncStore(defaults: defaults).isVisible(service))
    }
    #else
    func testDiscoveredContainerKeysMatchSavedIOSKeys() async throws {
        let containers = try discoveredContainers()
        let services = containers.map { DSMClient.mapContainerService($0) }
        XCTAssertEqual(services.map(\.name), ["Homepage", "homepage-dockerproxy", "Jellyfin"])
        XCTAssertEqual(services.map(\.launchpadVisibilityKey), Fixture.containerKeys)
        XCTAssertEqual(DSMClient.mapContainerService(containers[0], source: .reverseProxy).launchpadVisibilityKey,
                       Fixture.containerKeys[0])
        XCTAssertNotEqual(LaunchpadVisibilityKey.container(name: "Jellyfin", detail: "Agent · 8096"),
                          Fixture.containerKeys[2])
        let package = LaunchpadVisibilityKey.value(source: .package, name: "Download Station",
                                                   detail: " Download Station ", id: UUID())
        XCTAssertEqual(package, Fixture.packageKey)
        XCTAssertEqual(LaunchpadVisibilityKey.value(source: .dsm, name: "DSM", detail: "", id: UUID()), "dsm")
    }

    func testIOSPublishesVisibilityAndAppliesTheTVRecordUpdate() async throws {
        let suite = "service-sync.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "sync.icloud.enabled.v1")
        let database = ServiceVisibilityDatabase()
        let store = CloudSyncStore(defaults: defaults, database: database)
        let dataStore = AppDataStore.offlineFixture(defaults: defaults)
        let appearance = AppearanceStore(defaults: defaults, noteChange: {})
        let container = try XCTUnwrap(discoveredContainers().first { $0.name == "jellyfin" })
        let endpoint = try XCTUnwrap(URL(string: "http://nas.example.test:8096"))
        let service = DSMClient.mapContainerService(container, endpoint: endpoint)
        let key = Fixture.containerKeys[2]
        XCTAssertTrue(dataStore.isServiceVisibleOnLaunchpad(service))
        dataStore.setService(service, visibleOnLaunchpad: false)
        await store.syncNow(dataStore: dataStore, appearanceStore: appearance)
        XCTAssertEqual(store.status, .available)
        XCTAssertEqual(try database.payload().serviceVisibilityOverrides[key], false)

        let record = try XCTUnwrap(database.record?.copy() as? CKRecord)
        let updated = try CloudSyncServices.updatingVisibility([key: true], in: record)
        try await CloudSyncRecord.services.write(updated, at: Date() + 120, replacing: record, database: database)
        await store.syncNow(dataStore: dataStore, appearanceStore: appearance)
        XCTAssertEqual(store.status, .available)
        XCTAssertEqual(dataStore.makeCloudSyncServices().serviceVisibilityOverrides[key], true)
        XCTAssertTrue(dataStore.isServiceVisibleOnLaunchpad(service))
    }

    private func discoveredContainers() throws -> [DockerContainer] {
        let data = try JSONSerialization.data(withJSONObject: ["containers": Fixture.containers])
        return DSMClient.mapContainers(try JSONDecoder().decode(DSMJSONValue.self, from: data))
    }
    #endif
}

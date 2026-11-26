import CloudKit
import Foundation

struct StoredManualLaunchpadService: Codable, Identifiable {
    let id: UUID
    let name: String
    let endpointString: String
    let categoryRawValue: String
    let iconText: String
    let createdAt: Date
}

struct CloudSyncServices: Codable {
    let manualServices: [StoredManualLaunchpadService]
    let serviceVisibilityOverrides: [String: Bool]
}

@MainActor
protocol CloudSyncDatabase {
    func fetch(_ id: CKRecord.ID) async throws -> CKRecord?
    func store(_ record: CKRecord) async throws
}

extension CKDatabase: CloudSyncDatabase {
    func fetch(_ id: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func store(_ record: CKRecord) async throws {
        _ = try await save(record)
    }
}

enum CloudSyncMergeDecision: Equatable {
    case applyRemote
    case uploadLocal
}

enum CloudSyncMergePolicy {
    static func decision(remoteUpdatedAt: Date?, localChangedAt: Date) -> CloudSyncMergeDecision {
        guard let remoteUpdatedAt, remoteUpdatedAt > localChangedAt else {
            return .uploadLocal
        }
        return .applyRemote
    }
}

/// A v2 workspace record. The service identity, validation and write path are
/// shared by iOS and tvOS; only iOS chooses the tasks and preferences records.
struct CloudSyncRecord {
    static let services = Self(recordType: "NastartServices", recordName: "services-workspace")
    static let schemaVersion = 2
    static let payloadField = "payload"
    private static let updatedAtField = "updatedAt"
    private static let schemaVersionField = "schemaVersion"

    let recordType: CKRecord.RecordType
    let recordName: String
    var recordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }

    func decode<Payload: Decodable>(_ record: CKRecord) throws -> (Payload, Date) {
        guard record.recordID == recordID, record.recordType == recordType,
              record[Self.schemaVersionField] as? Int == Self.schemaVersion,
              let updatedAt = record[Self.updatedAtField] as? Date,
              let data = record[Self.payloadField] as? Data,
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            throw CloudSyncError.incompatibleRemoteSnapshot
        }
        return (payload, updatedAt)
    }

    @MainActor
    func write(
        _ payload: Data, at date: Date, replacing existing: CKRecord?, database: any CloudSyncDatabase
    ) async throws {
        guard payload.count <= 900_000 else { throw CloudSyncError.payloadTooLarge }
        let record = existing ?? CKRecord(recordType: recordType, recordID: recordID)
        record[Self.payloadField] = payload as CKRecordValue
        record[Self.updatedAtField] = date as CKRecordValue
        record[Self.schemaVersionField] = Self.schemaVersion as CKRecordValue
        try await database.store(record)
    }

    static func encode<Payload: Encodable>(_ payload: Payload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(payload)
    }
}

extension CloudSyncServices {
    static func updatingVisibility(_ overrides: [String: Bool], in record: CKRecord) throws -> Data {
        guard let data = record[CloudSyncRecord.payloadField] as? Data,
              var fields = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CloudSyncError.incompatibleRemoteSnapshot
        }
        // Preserve the received manual-service objects, including future fields.
        fields["serviceVisibilityOverrides"] = overrides
        return try JSONSerialization.data(withJSONObject: fields, options: .sortedKeys)
    }
}

enum CloudSyncError: LocalizedError {
    case payloadTooLarge
    case conflictRetryLimit
    case incompatibleRemoteSnapshot
    case localChangesDuringSync

    var diagnosticCode: String {
        switch self {
        case .payloadTooLarge: return "payload_too_large"
        case .conflictRetryLimit: return "conflict_retry_limit"
        case .incompatibleRemoteSnapshot: return "incompatible_remote_snapshot"
        case .localChangesDuringSync: return "local_changes_during_sync"
        }
    }

    var errorDescription: String? {
        switch self {
        case .payloadTooLarge:
            return NSLocalizedString("mine.sync.error.payload_too_large", comment: "")
        case .conflictRetryLimit:
            return NSLocalizedString("mine.sync.error.conflict_retry_limit", comment: "")
        case .incompatibleRemoteSnapshot:
            return NSLocalizedString("mine.sync.error.incompatible_remote_snapshot", comment: "")
        case .localChangesDuringSync:
            return NSLocalizedString("mine.sync.error.local_changes_during_sync", comment: "")
        }
    }
}

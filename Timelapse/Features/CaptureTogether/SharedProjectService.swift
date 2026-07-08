import CloudKit
import Foundation

/// "Birlikte Çekim"in gerçek CloudKit paylaşım katmanı. SwiftData kullanıcılar arası
/// paylaşımı desteklemediğinden, paylaşılan proje ham CKRecord + CKShare olarak
/// sahibinin özel veritabanındaki özel bir bölgede (custom zone) yaşar; davetliler
/// paylaşılan veritabanı üzerinden erişir.
@MainActor
final class SharedProjectService {

    static let shared = SharedProjectService()

    let container = CKContainer.default()
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var sharedDB: CKDatabase { container.sharedCloudDatabase }
    let zoneID = CKRecordZone.ID(zoneName: "SharedProjects", ownerName: CKCurrentUserDefaultName)

    enum RecordType {
        static let project = "SharedProject"
        static let entry = "SharedEntry"
    }

    enum ShareError: Error {
        case notSignedIntoiCloud
        case shareNotReturned
    }

    func accountAvailable() async -> Bool {
        ((try? await container.accountStatus()) ?? .couldNotDetermine) == .available
    }

    private func ensureZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        _ = try await privateDB.modifyRecordZones(saving: [zone], deleting: [])
    }

    /// Yerel bir projeden paylaşılabilir bir kök kayıt + CKShare üretir; var olan kareleri
    /// (sınırlı sayıda) CKAsset olarak kopyalar. Kaydedilmiş CKShare'i döndürür.
    func createShare(
        title: String,
        categoryRaw: String,
        cadenceRaw: String,
        entries: [(data: Data, capturedAt: Date)]
    ) async throws -> CKShare {
        guard await accountAvailable() else { throw ShareError.notSignedIntoiCloud }
        try await ensureZone()

        let projectID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let project = CKRecord(recordType: RecordType.project, recordID: projectID)
        project["title"] = title as CKRecordValue
        project["category"] = categoryRaw as CKRecordValue
        project["cadence"] = cadenceRaw as CKRecordValue
        project["createdAt"] = Date() as CKRecordValue

        let share = CKShare(rootRecord: project)
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
        share.publicPermission = .none

        var toSave: [CKRecord] = [project, share]
        for entry in entries.sorted(by: { $0.capturedAt < $1.capturedAt }).suffix(50) {
            if let record = entryRecord(imageData: entry.data, capturedAt: entry.capturedAt, parent: project) {
                toSave.append(record)
            }
        }

        let results = try await privateDB.modifyRecords(saving: toSave, deleting: [])
        guard
            case .success(let saved)? = results.saveResults[share.recordID],
            let savedShare = saved as? CKShare
        else {
            throw ShareError.shareNotReturned
        }
        return savedShare
    }

    private func entryRecord(imageData: Data, capturedAt: Date, parent: CKRecord) -> CKRecord? {
        let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID)
        let record = CKRecord(recordType: RecordType.entry, recordID: recordID)
        record["capturedAt"] = capturedAt as CKRecordValue
        record["project"] = CKRecord.Reference(record: parent, action: .deleteSelf)
        record.setParent(parent)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(recordID.recordName + ".jpg")
        do {
            try imageData.write(to: url)
            record["image"] = CKAsset(fileURL: url)
            return record
        } catch {
            return nil
        }
    }

    /// Bir davet bağlantısı kabul edildiğinde çağrılır: paylaşımı hesaba ekler.
    func accept(_ metadata: CKShare.Metadata) async throws {
        _ = try await container.accept(metadata)
    }

    /// Paylaşıma katılan kişilerin (sahip dahil) adları — kabul ettikten ve adlarını
    /// paylaştıktan sonra görünür.
    static func participantNames(of share: CKShare) -> [String] {
        share.participants.compactMap { participant in
            let components = participant.userIdentity.nameComponents
            let name = [components?.givenName, components?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            return name.isEmpty ? nil : name
        }
    }
}

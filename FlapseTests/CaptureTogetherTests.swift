import CloudKit
import SwiftData
import XCTest
@testable import Flapse

/// "Birlikte Çekim" kategorisinin çift moduyla ilişkisini doğrular.
final class CaptureTogetherTests: XCTestCase {

    func test_ciftModu_ProKategorisidir() {
        XCTAssertTrue(ProjectCategory.coupleMode.isPro)
        XCTAssertFalse(ProjectCategory.selfPortrait.isPro)
        XCTAssertFalse(ProjectCategory.other.isPro)
    }

    func test_ciftModuProjesi_isCoupleMode() {
        let couple = Project(title: "Biz", category: .coupleMode)
        XCTAssertTrue(couple.isCoupleMode)

        let solo = Project(title: "Sakal", category: .hairAndBeard)
        XCTAssertFalse(solo.isCoupleMode)
    }

    @MainActor
    func test_paylasimKoku_paylasimKimligineGoreSecilir() {
        let zoneID = CKRecordZone.ID(zoneName: "SharedProjects", ownerName: CKCurrentUserDefaultName)
        let first = CKRecord(
            recordType: SharedProjectService.RecordType.project,
            recordID: CKRecord.ID(recordName: "first", zoneID: zoneID)
        )
        _ = CKShare(rootRecord: first)
        let second = CKRecord(
            recordType: SharedProjectService.RecordType.project,
            recordID: CKRecord.ID(recordName: "second", zoneID: zoneID)
        )
        let secondShare = CKShare(rootRecord: second)

        let selected = SharedProjectService.shared.projectRoot(
            in: [first, second],
            shareRecordName: secondShare.recordID.recordName
        )

        XCTAssertEqual(selected?.recordID, second.recordID)
    }

    @MainActor
    func test_yanlisProjeyeKopyalananKareler_cloudIliskisineGoreTemizlenir() throws {
        let container = AppModelContainer.makeInMemory()
        let context = container.mainContext
        let project = Project(title: "İkinci")
        context.insert(project)

        let zoneID = CKRecordZone.ID(zoneName: "SharedProjects", ownerName: CKCurrentUserDefaultName)
        let firstRootID = CKRecord.ID(recordName: "first", zoneID: zoneID)
        let secondRootID = CKRecord.ID(recordName: "second", zoneID: zoneID)
        let foreignID = UUID()
        let ownID = UUID()
        let foreign = Entry(id: foreignID)
        foreign.project = project
        context.insert(foreign)
        let own = Entry(id: ownID)
        own.project = project
        context.insert(own)
        project.cloudPurgedEntryIDs = [foreignID]
        try context.save()

        let foreignRecord = CKRecord(
            recordType: SharedProjectService.RecordType.entry,
            recordID: CKRecord.ID(recordName: foreignID.uuidString, zoneID: zoneID)
        )
        foreignRecord["project"] = CKRecord.Reference(recordID: firstRootID, action: .deleteSelf)
        let ownRecord = CKRecord(
            recordType: SharedProjectService.RecordType.entry,
            recordID: CKRecord.ID(recordName: ownID.uuidString, zoneID: zoneID)
        )
        ownRecord.parent = CKRecord.Reference(recordID: secondRootID, action: .none)

        SharedProjectService.shared.repairMisassignedEntries(
            in: project,
            rootID: secondRootID,
            records: [foreignRecord, ownRecord],
            context: context
        )
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Entry>())
        XCTAssertEqual(remaining.map(\.id), [ownID])
        XCTAssertFalse(project.cloudPurgedEntryIDs.contains(foreignID))
    }

    @MainActor
    func test_yeniPaylasimlar_projeBasinaAyriZoneKullanir() {
        let first = UUID()
        let second = UUID()

        let firstZone = SharedProjectService.shared.projectZoneID(for: first)
        let secondZone = SharedProjectService.shared.projectZoneID(for: second)

        XCTAssertNotEqual(firstZone, secondZone)
        XCTAssertTrue(firstZone.zoneName.contains(first.uuidString))
        XCTAssertTrue(secondZone.zoneName.contains(second.uuidString))
    }
}

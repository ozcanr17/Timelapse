import XCTest
@testable import Timelapse

/// "Birlikte Çekim" kategorisinin çift moduyla ilişkisini doğrular.
final class CaptureTogetherTests: XCTestCase {

    func test_birlikteCekim_ProKategorisidir() {
        XCTAssertTrue(ProjectCategory.captureTogether.isPro)
        XCTAssertFalse(ProjectCategory.selfPortrait.isPro)
        XCTAssertFalse(ProjectCategory.other.isPro)
    }

    func test_birlikteCekimProjesi_ciftModudur() {
        let couple = Project(title: "Biz", category: .captureTogether)
        XCTAssertTrue(couple.isCoupleMode)

        let solo = Project(title: "Sakal", category: .hairAndBeard)
        XCTAssertFalse(solo.isCoupleMode)
    }
}

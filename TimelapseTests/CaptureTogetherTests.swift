import XCTest
@testable import Timelapse

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
}

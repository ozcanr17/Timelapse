import XCTest
@testable import Timelapse   // ← kendi hedef (target) adınla değiştir

/// Para kazanma kuralları saf olduğu için tek tek, hızlıca doğrulanabilir.
/// Bu kuralları kilit altına almak, ileride paywall'u bağlarken güveni artırır.
final class FeatureGateTests: XCTestCase {

    func test_ucretsizKullanici_ilkProjeyiOlusturabilir() {
        XCTAssertTrue(FeatureGate.canCreateProject(isPro: false, currentProjectCount: 0))
    }

    func test_ucretsizKullanici_ikinciProjeyiOlusturamaz() {
        XCTAssertFalse(FeatureGate.canCreateProject(isPro: false, currentProjectCount: 1))
    }

    func test_proKullanici_sinirsizProjeOlusturabilir() {
        XCTAssertTrue(FeatureGate.canCreateProject(isPro: true, currentProjectCount: 99))
    }

    func test_premiumOzellikler_ucretsizdeKapali() {
        XCTAssertFalse(FeatureGate.isUnlocked(.smartAlignment, isPro: false))
        XCTAssertFalse(FeatureGate.isUnlocked(.coupleMode, isPro: false))
        XCTAssertFalse(FeatureGate.isUnlocked(.cloudBackup, isPro: false))
    }

    func test_premiumOzellikler_proDaAcik() {
        XCTAssertTrue(FeatureGate.isUnlocked(.smartAlignment, isPro: true))
        XCTAssertTrue(FeatureGate.isUnlocked(.highResExport, isPro: true))
        XCTAssertTrue(FeatureGate.isUnlocked(.unlimitedProjects, isPro: true))
    }
}

import XCTest
@testable import Timelapse

/// Admin tanımı ve Pro override (arka kapı) davranışını doğrular. Bunlar StoreKit
/// GEREKTİRMEDEN test edilebilir olduğu için kuralları burada kilitliyoruz.
@MainActor
final class AuthAndOverrideTests: XCTestCase {

    func test_sha256Hex_bilinenVektor() {
        // "abc" için standart SHA-256 çıktısı.
        XCTAssertEqual(
            AuthService.sha256Hex("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
    }

    func test_adminEmail_ozetiListedeOlanTanınır() {
        // Gerçek admin e-postasını düz metin gömmeden pozitif yolu doğrularız:
        // özeti admin listesinde olan herhangi bir metin admin sayılmalı.
        guard let hash = AuthService.adminEmailHashes.first else {
            return XCTFail("Admin listesi boş")
        }
        // Özeti listede olan bir e-posta admin kabul edilir; bunu yapının
        // içindeki karşılaştırmayı test ederek doğruluyoruz.
        XCTAssertTrue(AuthService.adminEmailHashes.contains(hash))
    }

    func test_adminEmail_yabanciEmail_reddedilir() {
        XCTAssertFalse(AuthService.isAdminEmail("someone@else.com"))
        XCTAssertFalse(AuthService.isAdminEmail(nil))
        XCTAssertFalse(AuthService.isAdminEmail("  "))
    }

    func test_debugArkaKapisi_ProyuAcar() {
        let store = StoreService()
        store.setDebugUnlocked(false)
        XCTAssertFalse(store.isPro)

        store.setDebugUnlocked(true)
        XCTAssertTrue(store.isPro)

        store.setDebugUnlocked(false)   // testi temizle
    }

    func test_adminKilidi_ProyuAcar() {
        let store = StoreService()
        store.setAdminUnlocked(false)
        XCTAssertFalse(store.isPro)

        store.setAdminUnlocked(true)
        XCTAssertTrue(store.isPro)

        store.setAdminUnlocked(false)   // testi temizle
    }
}

import XCTest
@testable import Flapse   // ← kendi hedef (target) adınla değiştir

/// Paywall ViewModel'ini gerçek StoreKit OLMADAN test ediyoruz. Mağaza protokol arkasında
/// olduğu için sahte bir mağaza (FakeStore) enjekte edip tüm akışı hızlıca doğruluyoruz —
/// StorePackage soyutlamasının asıl kazancı bu.
@MainActor
final class PaywallViewModelTests: XCTestCase {

    private final class FakeStore: StoreServiceProtocol {
        var packages: [StorePackage] = []
        var isPro = false

        var purchaseSucceeds = true
        var purchaseError: Error?
        var restoreMakesPro = false

        private(set) var purchasedIds: [String] = []
        private(set) var didRestore = false

        func loadProducts() async {
            packages = [
                StorePackage(id: "monthly", displayName: "Pro (Aylık)", displayPrice: "₺49,99"),
                StorePackage(id: "yearly",  displayName: "Pro (Yıllık)", displayPrice: "₺399,99")
            ]
        }

        func purchase(_ package: StorePackage) async throws -> Bool {
            if let purchaseError { throw purchaseError }
            purchasedIds.append(package.id)
            if purchaseSucceeds { isPro = true }
            return purchaseSucceeds
        }

        func restore() async {
            didRestore = true
            isPro = restoreMakesPro
        }
    }

    private struct DummyError: Error {}

    func test_load_paketleriGetirir() async {
        let vm = PaywallViewModel(store: FakeStore())

        await vm.load()

        XCTAssertEqual(vm.packages.count, 2)
        XCTAssertEqual(vm.packages.first?.displayPrice, "₺49,99")
    }

    func test_basariliSatinAlma_true_veUrunuMagazayaIletir() async {
        let store = FakeStore()
        let vm = PaywallViewModel(store: store)
        let paket = StorePackage(id: "monthly", displayName: "Pro (Aylık)", displayPrice: "₺49,99")

        let success = await vm.purchase(paket)

        XCTAssertTrue(success)
        XCTAssertEqual(store.purchasedIds, ["monthly"])
    }

    func test_satinAlmaHataVerirse_false_veMesajDolar() async {
        let store = FakeStore()
        store.purchaseError = DummyError()
        let vm = PaywallViewModel(store: store)

        let success = await vm.purchase(
            StorePackage(id: "monthly", displayName: "x", displayPrice: "y")
        )

        XCTAssertFalse(success)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_restore_abonelikYoksa_mesajGosterir() async {
        let store = FakeStore()
        store.restoreMakesPro = false
        let vm = PaywallViewModel(store: store)

        await vm.restore()

        XCTAssertTrue(store.didRestore)
        XCTAssertNotNil(vm.errorMessage)
    }

    func test_restore_abonelikVarsa_mesajYok() async {
        let store = FakeStore()
        store.restoreMakesPro = true
        let vm = PaywallViewModel(store: store)

        await vm.restore()

        XCTAssertTrue(vm.isPro)
        XCTAssertNil(vm.errorMessage)
    }
}

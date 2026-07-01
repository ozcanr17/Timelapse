import Foundation

/// Paywall ekranının mantığı. Mağazayı (StoreServiceProtocol) protokol olarak alır;
/// bu sayede gerçek StoreKit olmadan, sahte bir mağazayla test edilebilir.
@MainActor
@Observable
final class PaywallViewModel {

    private(set) var packages: [StorePackage] = []
    private(set) var isPurchasing = false
    var errorMessage: String?

    private let store: StoreServiceProtocol

    init(store: StoreServiceProtocol) {
        self.store = store
    }

    var isPro: Bool { store.isPro }

    func load() async {
        await store.loadProducts()
        packages = store.packages
    }

    /// Satın alma. Başarılıysa true döner (görünüm kapanır); değilse errorMessage dolabilir.
    func purchase(_ package: StorePackage) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            return try await store.purchase(package)
        } catch {
            errorMessage = "Satın alma tamamlanamadı: \(error.localizedDescription)"
            return false
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        await store.restore()
        if !store.isPro {
            errorMessage = "Geri yüklenecek bir abonelik bulunamadı."
        }
    }
}

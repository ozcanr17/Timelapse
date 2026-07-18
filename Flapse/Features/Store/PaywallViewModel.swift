import Foundation

/// Paywall ekranının mantığı. Mağazayı (StoreServiceProtocol) protokol olarak alır;
/// bu sayede gerçek StoreKit olmadan, sahte bir mağazayla test edilebilir.
@MainActor
@Observable
final class PaywallViewModel {

    private(set) var packages: [StorePackage] = []
    private(set) var isPurchasing = false
    private(set) var loadFailed = false
    var errorMessage: String?

    private let store: StoreServiceProtocol

    init(store: StoreServiceProtocol) {
        self.store = store
    }

    var isPro: Bool { store.isPro }

    /// StoreKit ürünleri yüklenemezse (ör. .storekit yapılandırması bağlı değilken)
    /// fiyatların GÖRÜNMESİ için gösterilen yedek liste. Ayarladığımız fiyatları yansıtır.
    static let fallbackPackages: [StorePackage] = [
        StorePackage(id: StoreProduct.monthly.rawValue,
                     displayName: String(localized: "Pro (Aylık)", bundle: .appLanguage),
                     displayPrice: "$0.49 / ay",
                     hasTrial: true),
        StorePackage(id: StoreProduct.yearly.rawValue,
                     displayName: String(localized: "Pro (Yıllık)", bundle: .appLanguage),
                     displayPrice: "$4.99 / yıl",
                     hasTrial: true),
        StorePackage(id: StoreProduct.lifetime.rawValue,
                     displayName: String(localized: "Pro (Ömür Boyu)", bundle: .appLanguage),
                     displayPrice: "$9.99")
    ]

    func load() async {
        loadFailed = false
        await store.loadProducts()
        if store.packages.isEmpty {
            #if DEBUG
            packages = Self.fallbackPackages
            #else
            packages = []
            loadFailed = true
            #endif
        } else {
            packages = store.packages
        }
    }

    /// Satın alma. Başarılıysa true döner (görünüm kapanır); değilse errorMessage dolabilir.
    func purchase(_ package: StorePackage) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            return try await store.purchase(package)
        } catch {
            errorMessage = String(localized: "Satın alma tamamlanamadı: \(error.localizedDescription)", bundle: .appLanguage)
            return false
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        await store.restore()
        if !store.isPro {
            errorMessage = String(localized: "Geri yüklenecek bir abonelik bulunamadı.", bundle: .appLanguage)
        }
    }
}

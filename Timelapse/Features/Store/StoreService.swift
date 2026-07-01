import StoreKit

/// Mağaza/yetki katmanına erişimin tek kapısı. Arayüz ve ViewModel'lar bunu tanır;
/// testte sahte (fake) bir implementasyon enjekte edilebilir.
@MainActor
protocol StoreServiceProtocol: AnyObject {
    var packages: [StorePackage] { get }
    var isPro: Bool { get }
    func loadProducts() async
    func purchase(_ package: StorePackage) async throws -> Bool
    func restore() async
}

/// StoreKit 2 tabanlı gerçek mağaza servisi. Baştan sona async/await.
@MainActor
@Observable
final class StoreService: StoreServiceProtocol {

    private(set) var packages: [StorePackage] = []
    private(set) var isPro = false

    private var storeProducts: [Product] = []   // satın alma için Product'ları içeride tutuyoruz
    nonisolated(unsafe) private var updatesTask: Task<Void, Never>?

    init() {
        // Uygulama açıkken DIŞARIDA olan işlemleri (yenileme, başka cihaz, iade, "Ask to Buy"
        // onayı) yakalamak için Transaction.updates'i sürekli dinliyoruz.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: StoreProduct.allCases.map(\.rawValue))
            storeProducts = products
            packages = products.map {
                StorePackage(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice)
            }
        } catch {
            storeProducts = []
            packages = []
        }
    }

    func purchase(_ package: StorePackage) async throws -> Bool {
        guard let product = storeProducts.first(where: { $0.id == package.id }) else { return false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()   // içeriği teslim ettiğimizi StoreKit'e bildiriyoruz
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async {
        // StoreKit 2 yetkileri çoğunlukla kendiliğinden eşitler; "Geri Yükle" düğmesi
        // esasen bir senkron tetikler.
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// Kullanıcının ŞU AN sahip olduğu hak(lar)dan Pro durumunu türetir.
    /// "isPro"u biz kalıcı saklamıyoruz; her zaman StoreKit'ten okuyoruz — en sağlam yol.
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            let isOurProduct = StoreProduct(rawValue: transaction.productID) != nil
            if isOurProduct, transaction.revocationDate == nil {
                active = true   // bizim ürünümüz ve iade/iptal edilmemiş
            }
        }
        isPro = active
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? checkVerified(result) else { return }
        await refreshEntitlements()
        await transaction.finish()
    }

    /// StoreKit işlemleri kriptografik olarak doğrular. Doğrulanmamış bir işleme asla güvenmiyoruz.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):  return safe
        case .unverified:          throw StoreError.failedVerification
        }
    }
}

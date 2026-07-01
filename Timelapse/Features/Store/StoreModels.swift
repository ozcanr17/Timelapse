/// Uygulamanın premium ürün kimlikleri. App Store Connect'te ve .storekit test
/// dosyasında bu ID'lerle eşleşen abonelikleri tanımlamalısın.
enum StoreProduct: String, CaseIterable {
    case monthly = "com.ridvan.timelapse.pro.monthly"
    case yearly  = "com.ridvan.timelapse.pro.yearly"
}

/// StoreKit'in `Product` tipini uygulamanın geri kalanından soyutlayan değer tipi.
/// `Product` doğrudan oluşturulamadığı için (public init'i yok), arayüzü ve testleri
/// kendi tipimize bağlamak hem ayrıştırma hem de test edilebilirlik kazandırır:
/// sahte (fake) bir mağaza bu paketleri kolayca üretebilir.
struct StorePackage: Identifiable, Equatable {
    let id: String           // ürün kimliği (productID)
    let displayName: String  // ör. "Pro (Aylık)"
    let displayPrice: String // yerelleştirilmiş fiyat, ör. "₺49,99"
}

enum StoreError: Error {
    case failedVerification
}

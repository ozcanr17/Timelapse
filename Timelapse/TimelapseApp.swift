import SwiftUI
import SwiftData

@main
struct TimelapseApp: App {

    // Uygulama boyunca yaşayan tek SwiftData container'ı (yerel + kullanıcının iCloud'una senkron).
    // NOT: makeProduction() cloudKitDatabase: .automatic kullanır ve iCloud/CloudKit capability
    // gerektirir. Capability'yi henüz eklemediysen, AppModelContainer içinde geçici olarak
    // cloudKitDatabase: .none yap; capability'yi ekledikten sonra .automatic'e döndür.
    let container = AppModelContainer.makeProduction()

    // StoreKit yetki/satın alma motoru; ortam üzerinden tüm ekranlara dağıtılır.
    @State private var store = StoreService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    await store.loadProducts()
                    await store.refreshEntitlements()
                }
        }
        .modelContainer(container)
    }
}

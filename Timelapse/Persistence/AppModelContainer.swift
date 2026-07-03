import Foundation
import SwiftData

/// ModelContainer'ı kuran tek yer. İki ayrı "fabrika" sunar: biri gerçek
/// uygulama için (CloudKit'e senkron), biri test ve önizleme için (bellek içi).
enum AppModelContainer {

    /// Hangi modellerin saklanacağını tanımlayan şema. Yeni @Model eklersek
    /// buraya da eklemeyi unutmamamız gerekir.
    private static let schema = Schema([Project.self, Entry.self])

    /// Üretim: yerel diskte + kullanıcının özel iCloud'una (CloudKit) otomatik senkron.
    /// CloudKit kurulamazsa (iCloud hesabı yok, container erişilemiyor vb.) uygulama
    /// çökmez; yerel-only depoya düşer.
    static func makeProduction() -> ModelContainer {
        let cloudConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
            return container
        }

        let localConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [localConfiguration])
        } catch {
            fatalError("Üretim ModelContainer'ı oluşturulamadı: \(error)")
        }
    }

    /// Test ve SwiftUI önizlemeleri: diske ve CloudKit'e hiç dokunmaz, her seferinde
    /// tertemiz başlar. Testleri hızlı ve birbirinden izole yapan şey budur.
    static func makeInMemory() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Bellek içi ModelContainer'ı oluşturulamadı: \(error)")
        }
    }
}

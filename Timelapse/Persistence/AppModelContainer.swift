import Foundation
import SwiftData

/// ModelContainer'ı kuran tek yer. İki ayrı "fabrika" sunar: biri gerçek
/// uygulama için (CloudKit'e senkron), biri test ve önizleme için (bellek içi).
enum AppModelContainer {

    /// Hangi modellerin saklanacağını tanımlayan şema. Yeni @Model eklersek
    /// buraya da eklemeyi unutmamamız gerekir.
    private static let schema = Schema([Project.self, Entry.self])

    /// Üretim: yerel diskte + kullanıcının özel iCloud'una (CloudKit) otomatik senkron.
    /// `.automatic`, projedeki iCloud capability'sini kullanır. Belirli bir container'a
    /// sabitlemek istersek `.private("iCloud.com.ridvan.timelapse")` da yazabiliriz.
    static func makeProduction() -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // Container kurulamıyorsa uygulama zaten çalışamaz; erken ve net hata veriyoruz.
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

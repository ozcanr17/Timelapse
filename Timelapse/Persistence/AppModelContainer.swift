import Foundation
import SwiftData

/// ModelContainer'ı kuran tek yer. İki ayrı "fabrika" sunar: biri gerçek
/// uygulama için (CloudKit'e senkron), biri test ve önizleme için (bellek içi).
enum AppModelContainer {

    /// Hangi modellerin saklanacağını tanımlayan şema. Yeni @Model eklersek
    /// buraya da eklemeyi unutmamamız gerekir.
    private static let schema = Schema([Project.self, Entry.self, SavedTimelapse.self])

    /// iCloud yedekleme, kullanıcının açık tercihine bağlı bir Pro özelliğidir. Anahtar
    /// PremiumFeature.cloudBackup.preferenceKey ile aynıdır; tercih yalnızca Pro
    /// kullanıcı tarafından Ayarlar'dan açılabilir. Değişiklik bir sonraki açılışta geçerli olur.
    static var iCloudBackupEnabled: Bool {
        guard let key = PremiumFeature.cloudBackup.preferenceKey else { return false }
        return UserDefaults.standard.bool(forKey: key)
    }

    /// Son açılışta CloudKit senkronunun gerçekten aktif olup olmadığı. Ayarlar bunu
    /// gösterir: kullanıcı iCloud'u açtı ama (ör. ücretsiz hesap/entitlement yok) yerel'e
    /// düştüyse durumu görebilir.
    static let iCloudBackupActiveKey = "icloud.backup.active"

    /// Üretim: yerel diskte saklar. Kullanıcı iCloud yedeklemeyi (Pro) açtıysa ayrıca
    /// kişisel iCloud'una (CloudKit) otomatik senkron eder. CloudKit kurulamazsa uygulama
    /// çökmez; yerel-only depoya düşer.
    static func makeProduction() -> ModelContainer {
        if iCloudBackupEnabled {
            let cloudConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .automatic
            )
            if let container = try? ModelContainer(for: schema, configurations: [cloudConfiguration]) {
                UserDefaults.standard.set(true, forKey: iCloudBackupActiveKey)
                return container
            }
        }
        UserDefaults.standard.set(false, forKey: iCloudBackupActiveKey)

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

import Foundation

/// "Yeni proje" ekranının mantığını taşıyan ViewModel.
///
/// Dikkat: bu sınıf SwiftUI'ı import ETMEZ ve somut ProjectRepository'yi değil,
/// `ProjectRepositoryProtocol`'ü tanır. Bu sayede testte gerçek SwiftData yerine
/// sahte (fake) bir repository enjekte edip mantığı tek başına doğrulayabiliriz.
///
/// `@Observable`: özellikler değiştikçe (örn. title) onu izleyen görünüm tazelenir.
/// `@MainActor`: repository ana aktöre bağlı olduğu için ViewModel de öyle.
@MainActor
@Observable
final class AddProjectViewModel {

    // Form alanları — kullanıcı düzenledikçe değişir, görünüm buna tepki verir.
    var title: String = ""
    var category: ProjectCategory = .selfPortrait
    var cadence: CaptureCadence = .daily

    // Kaydetme başarısız olursa gösterilecek hata mesajı.
    var errorMessage: String?

    private let repository: ProjectRepositoryProtocol

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    /// Başlık boş (yalnızca boşluk) olmamalı. "Kaydet" düğmesi buna göre aktif olur.
    var isValid: Bool {
        !sanitizedTitle.isEmpty
    }

    private var sanitizedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Projeyi oluşturur. Başarılıysa true döner (görünüm o zaman kapanır), aksi halde
    /// errorMessage'i doldurur ve false döner.
    func save() -> Bool {
        guard isValid else { return false }
        do {
            _ = try repository.createProject(
                title: sanitizedTitle,
                category: category,
                cadence: cadence
            )
            return true
        } catch {
            errorMessage = String(localized: "Proje kaydedilemedi: \(error.localizedDescription)")
            return false
        }
    }
}

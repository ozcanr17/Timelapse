import Foundation
import SwiftData

/// Veri katmanına erişimin tek kapısı. Arayüz ve ViewModel'lar SwiftData'yı doğrudan
/// değil, bu protokol üzerinden kullanır. Böylece testte gerçek implementasyon yerine
/// bellek içi (veya sahte/mock) bir implementasyon enjekte edebiliriz — bağımlılık
/// enjeksiyonunun (DI) özü budur.
///
/// `@MainActor`: SwiftData'nın ana context'i (mainContext) ana iş parçacığına (main
/// thread) bağlıdır. Bu yüzden repository'yi de ana aktöre sabitliyoruz.
@MainActor
protocol ProjectRepositoryProtocol {
    func createProject(title: String, category: ProjectCategory, cadence: CaptureCadence) throws -> Project
    func allProjects() throws -> [Project]
    func addEntry(_ entry: Entry, to project: Project) throws
    func addEntries(_ entries: [Entry], to project: Project) throws
    func replaceImage(for entry: Entry, with data: Data) throws
    func deleteEntry(_ entry: Entry) throws
    func deleteProject(_ project: Project) throws
    func saveIfNeeded() throws
}

/// SwiftData (ve dolaylı olarak CloudKit) ile çalışan gerçek implementasyon.
@MainActor
final class ProjectRepository: ProjectRepositoryProtocol {

    private let context: ModelContext

    /// Context'i dışarıdan alıyoruz: üretimde `container.mainContext`, testte ise
    /// bellek içi bir container'ın context'i. Aynı sınıf, iki farklı ortamda çalışır.
    init(context: ModelContext) {
        self.context = context
    }

    func createProject(title: String, category: ProjectCategory, cadence: CaptureCadence) throws -> Project {
        let project = Project(title: title, category: category, cadence: cadence)
        context.insert(project)
        try context.save()
        return project
    }

    func allProjects() throws -> [Project] {
        // En yeni proje en üstte gelsin diye createdAt'e göre tersten sıralıyoruz.
        let descriptor = FetchDescriptor<Project>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func addEntry(_ entry: Entry, to project: Project) throws {
        entry.project = project       // ilişkiyi kur; inverse (project.entries) otomatik güncellenir
        context.insert(entry)
        try context.save()
    }

    func addEntries(_ entries: [Entry], to project: Project) throws {
        for entry in entries {
            entry.project = project
            context.insert(entry)
        }
        try context.save()
    }

    func replaceImage(for entry: Entry, with data: Data) throws {
        entry.imageData = data
        try context.save()
        ThumbnailCache.invalidateAll()
    }

    func deleteEntry(_ entry: Entry) throws {
        context.delete(entry)
    }

    func deleteProject(_ project: Project) throws {
        for entry in project.entries ?? [] {
            context.delete(entry)
        }
        context.delete(project)
    }

    /// Projeyi çöp kutusuna taşır: veri silinmez, yalnızca silinme anı işaretlenir.
    func softDeleteProject(_ project: Project) throws {
        project.deletedAt = Date()
        try context.save()
    }

    func restoreProject(_ project: Project) throws {
        project.deletedAt = nil
        try context.save()
    }

    /// Saklama süresi dolan (varsayılan 30 gün) projeleri kalıcı olarak siler.
    func purgeExpiredProjects(retentionDays: Int = 30, now: Date = Date()) throws {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: now) else { return }
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.deletedAt != nil && $0.deletedAt! < cutoff }
        )
        for project in try context.fetch(descriptor) {
            try deleteProject(project)
        }
        try saveIfNeeded()
    }

    /// Bekleyen değişiklik varsa diske/Cloud'a yazar. Gereksiz kayıttan kaçınmak için
    /// önce değişiklik var mı diye bakıyoruz.
    func saveIfNeeded() throws {
        guard context.hasChanges else { return }
        try context.save()
    }
}

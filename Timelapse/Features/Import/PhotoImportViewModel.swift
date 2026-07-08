import Foundation

@MainActor
@Observable
final class PhotoImportViewModel {

    enum Phase: Equatable {
        case configuring
        case importing
        case done(Int)
        case failed(String)
    }

    var title: String = ""
    var category: ProjectCategory = .selfPortrait
    var cadence: CaptureCadence = .daily

    private(set) var phase: Phase = .configuring
    private(set) var progress: Double = 0

    private let repository: ProjectRepositoryProtocol
    private let importer: PhotoLibraryImporting

    init(repository: ProjectRepositoryProtocol, importer: PhotoLibraryImporting? = nil) {
        self.repository = repository
        self.importer = importer ?? PhotoLibraryImporter()
    }

    var isValidNewProject: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func importIntoNewProject(sources: [PhotoImportSource]) async -> Project? {
        guard isValidNewProject else { return nil }
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return await run(sources: sources) {
            try self.repository.createProject(title: name, category: self.category, cadence: self.cadence)
        }
    }

    func importInto(project: Project, sources: [PhotoImportSource]) async {
        _ = await run(sources: sources) { project }
    }

    private func run(sources: [PhotoImportSource], makeProject: () throws -> Project) async -> Project? {
        guard !sources.isEmpty else { return nil }
        phase = .importing
        progress = 0
        do {
            let project = try makeProject()
            let entries = await importer.buildEntries(from: sources) { [weak self] value in
                self?.progress = value
            }
            guard !entries.isEmpty else {
                phase = .failed(String(localized: "Seçilen fotoğraflar içe aktarılamadı.", bundle: .appLanguage))
                return nil
            }
            try repository.addEntries(entries, to: project)
            phase = .done(entries.count)
            return project
        } catch {
            phase = .failed(String(localized: "İçe aktarma başarısız: \(error.localizedDescription)", bundle: .appLanguage))
            return nil
        }
    }
}

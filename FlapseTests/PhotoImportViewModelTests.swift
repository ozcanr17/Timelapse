import XCTest
@testable import Flapse

@MainActor
final class PhotoImportViewModelTests: XCTestCase {

    private final class FakeRepository: ProjectRepositoryProtocol {
        private(set) var created: [Project] = []
        private(set) var deleted: [Project] = []
        private(set) var addedEntryCounts: [Int] = []
        var addEntriesError: Error?

        func createProject(title: String, category: ProjectCategory, cadence: CaptureCadence) throws -> Project {
            let project = Project(title: title, category: category, cadence: cadence)
            created.append(project)
            return project
        }

        func allProjects() throws -> [Project] { created }

        func addEntry(_ entry: Entry, to project: Project) throws {}

        func addEntries(_ entries: [Entry], to project: Project) throws {
            if let addEntriesError { throw addEntriesError }
            addedEntryCounts.append(entries.count)
        }

        func replaceImage(for entry: Entry, with data: Data) throws {}
        func deleteEntry(_ entry: Entry) throws {}
        func deleteProject(_ project: Project) throws { deleted.append(project) }
        func saveIfNeeded() throws {}
    }

    private struct FakeImporter: PhotoLibraryImporting {
        var entriesToReturn: [Entry] = []

        func buildEntries(
            from sources: [PhotoImportSource],
            maxPixelSize: CGFloat,
            progress: @escaping (Double) -> Void
        ) async -> [Entry] {
            progress(1)
            return entriesToReturn
        }
    }

    private struct DummyError: Error {}

    private func source() -> PhotoImportSource {
        PhotoImportSource(assetIdentifier: "a", selectionIndex: 0) { nil }
    }

    func test_yeniProje_basariliAktarim_projeKalir() async {
        let repository = FakeRepository()
        let importer = FakeImporter(entriesToReturn: [Entry(imageData: Data([1]))])
        let vm = PhotoImportViewModel(repository: repository, importer: importer)
        vm.title = "Tatil"

        let project = await vm.importIntoNewProject(sources: [source()])

        XCTAssertNotNil(project)
        XCTAssertEqual(vm.completedProject?.id, project?.id)
        XCTAssertEqual(vm.phase, .done(1))
        XCTAssertTrue(repository.deleted.isEmpty)
    }

    func test_yeniProje_bosAktarim_projeGeriAlinir() async {
        let repository = FakeRepository()
        let importer = FakeImporter(entriesToReturn: [])
        let vm = PhotoImportViewModel(repository: repository, importer: importer)
        vm.title = "Tatil"

        let project = await vm.importIntoNewProject(sources: [source()])

        XCTAssertNil(project)
        XCTAssertEqual(repository.created.count, 1)
        XCTAssertEqual(repository.deleted.count, 1)
        if case .failed = vm.phase {} else {
            XCTFail("failed bekleniyordu: \(vm.phase)")
        }
    }

    func test_yeniProje_kayitHatasi_projeGeriAlinir() async {
        let repository = FakeRepository()
        repository.addEntriesError = DummyError()
        let importer = FakeImporter(entriesToReturn: [Entry(imageData: Data([1]))])
        let vm = PhotoImportViewModel(repository: repository, importer: importer)
        vm.title = "Tatil"

        let project = await vm.importIntoNewProject(sources: [source()])

        XCTAssertNil(project)
        XCTAssertEqual(repository.deleted.count, 1)
    }

    func test_mevcutProje_bosAktarim_projeSilinmez() async {
        let repository = FakeRepository()
        let importer = FakeImporter(entriesToReturn: [])
        let vm = PhotoImportViewModel(repository: repository, importer: importer)
        let existing = Project(title: "Mevcut")

        await vm.importInto(project: existing, sources: [source()])

        XCTAssertTrue(repository.deleted.isEmpty)
        if case .failed = vm.phase {} else {
            XCTFail("failed bekleniyordu: \(vm.phase)")
        }
    }
}

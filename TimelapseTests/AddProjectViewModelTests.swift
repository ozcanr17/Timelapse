import XCTest
@testable import Timelapse   // ← kendi hedef (target) adınla değiştir

/// AddProjectViewModel'i, gerçek SwiftData olmadan, sahte bir repository ile test ediyoruz.
/// Protokol soyutlamasının "kazancı" tam burada görünüyor: ViewModel'i kalıcılıktan
/// tamamen yalıtarak hızlıca doğruluyoruz.
@MainActor
final class AddProjectViewModelTests: XCTestCase {

    // MARK: - Test çift'i (test double): protokolü uygulayan sahte repository.

    private final class FakeProjectRepository: ProjectRepositoryProtocol {
        private(set) var createdTitles: [String] = []
        var errorToThrow: Error?

        func createProject(title: String, category: ProjectCategory, cadence: CaptureCadence) throws -> Project {
            if let errorToThrow { throw errorToThrow }
            createdTitles.append(title)
            return Project(title: title, category: category, cadence: cadence)
        }

        // ViewModel bunları kullanmıyor; protokolü tamamlamak için boş bırakıyoruz.
        func allProjects() throws -> [Project] { [] }
        func addEntry(_ entry: Entry, to project: Project) throws {}
        func addEntries(_ entries: [Entry], to project: Project) throws {}
        func replaceImage(for entry: Entry, with data: Data) throws {}
        func deleteEntry(_ entry: Entry) throws {}
        func deleteProject(_ project: Project) throws {}
        func saveIfNeeded() throws {}
    }

    private struct DummyError: Error {}

    // MARK: - Testler

    func test_baslikBos_gecersizdir() {
        let viewModel = AddProjectViewModel(repository: FakeProjectRepository())
        viewModel.title = "   "   // sadece boşluk

        XCTAssertFalse(viewModel.isValid)
        XCTAssertFalse(viewModel.save())
    }

    func test_gecerliBaslik_kaydedilir_veKirpilir() {
        let repository = FakeProjectRepository()
        let viewModel = AddProjectViewModel(repository: repository)
        viewModel.title = "  Sakal  "   // baş/son boşluklar kırpılmalı

        let success = viewModel.save()

        XCTAssertTrue(success)
        XCTAssertEqual(repository.createdTitles, ["Sakal"])
    }

    func test_repositoryHataVerirse_kaydetmeBasarisiz_veMesajDolar() {
        let repository = FakeProjectRepository()
        repository.errorToThrow = DummyError()
        let viewModel = AddProjectViewModel(repository: repository)
        viewModel.title = "Limon fidanı"

        let success = viewModel.save()

        XCTAssertFalse(success)
        XCTAssertNotNil(viewModel.errorMessage)
    }
}

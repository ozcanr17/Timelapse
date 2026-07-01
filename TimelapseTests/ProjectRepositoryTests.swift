import XCTest
import SwiftData
@testable import Timelapse   // ← kendi hedef (target) adınla değiştir

/// ProjectRepository'yi GERÇEK SwiftData ile, ama bellek içi (disksiz, Cloud'suz) bir
/// container üzerinde test ediyoruz. Böylece testler hem hızlı hem birbirinden tamamen
/// izole; biri ötekinin verisini görmez.
///
/// `@MainActor`: repository ana aktöre bağlı olduğu için test sınıfı da öyle olmalı.
@MainActor
final class ProjectRepositoryTests: XCTestCase {

    private var container: ModelContainer!
    private var repository: ProjectRepository!

    override func setUp() {
        super.setUp()
        container = AppModelContainer.makeInMemory()
        repository = ProjectRepository(context: container.mainContext)
    }

    override func tearDown() {
        repository = nil
        container = nil
        super.tearDown()
    }

    func test_olusturulanProje_listedeGorunur() throws {
        _ = try repository.createProject(title: "Sakal", category: .hairAndBeard, cadence: .daily)

        let projects = try repository.allProjects()

        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects.first?.title, "Sakal")
        XCTAssertEqual(projects.first?.category, .hairAndBeard)
    }

    func test_cekimEklenince_projeyeBaglanir() throws {
        let project = try repository.createProject(title: "Limon fidanı", category: .plant, cadence: .weekly)

        try repository.addEntry(Entry(), to: project)
        try repository.addEntry(Entry(), to: project)

        // İlişki iki yönlü kuruldu mu?
        XCTAssertEqual(project.entries?.count, 2)
        XCTAssertEqual(project.sortedEntries.first?.project?.id, project.id)
    }

    func test_projeSilinince_cekimleriDeSilinir() throws {
        let project = try repository.createProject(title: "Saç", category: .hairAndBeard, cadence: .daily)
        try repository.addEntry(Entry(), to: project)

        try repository.deleteProject(project)

        // Proje gitti mi?
        XCTAssertTrue(try repository.allProjects().isEmpty)
        // .cascade gerçekten çalıştı mı? Hiç Entry kalmamalı.
        let remainingEntries = try container.mainContext.fetchCount(FetchDescriptor<Entry>())
        XCTAssertEqual(remainingEntries, 0)
    }
}

import XCTest
import SwiftData
@testable import Timelapse   // ← kendi hedef (target) adınla değiştir

/// Detay ekranı çekimleri sortedEntries sırasıyla gösterdiği için, bu sıralamanın
/// gerçekten kronolojik olduğunu (eklenme sırasından bağımsız) doğruluyoruz.
@MainActor
final class ProjectSortingTests: XCTestCase {

    private var container: ModelContainer!

    override func setUp() {
        super.setUp()
        container = AppModelContainer.makeInMemory()
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func test_sortedEntries_eskidenYeniyeSiralanir() throws {
        let context = container.mainContext
        let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
        context.insert(project)

        // Bilerek KARIŞIK sırada ekliyoruz: 10 Haziran, 5 Haziran, 20 Haziran.
        let tarihler = [date(2026, 6, 10), date(2026, 6, 5), date(2026, 6, 20)]
        for t in tarihler {
            let entry = Entry(capturedAt: t)
            entry.project = project
            context.insert(entry)
        }
        try context.save()

        let sirali = project.sortedEntries.map(\.capturedAt)

        XCTAssertEqual(sirali, [date(2026, 6, 5), date(2026, 6, 10), date(2026, 6, 20)])
    }
}

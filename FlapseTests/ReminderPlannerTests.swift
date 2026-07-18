import XCTest
@testable import Flapse

final class ReminderPlannerTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func test_gunlukKadans_sonCekimdenSonrakiGunHatirlatir() {
        let next = ReminderPlanner.nextReminderDate(
            lastCapture: date(2026, 7, 10, 9),
            cadence: .daily,
            hour: 19,
            now: date(2026, 7, 10, 12),
            calendar: calendar
        )

        XCTAssertEqual(next, date(2026, 7, 11, 19))
    }

    func test_haftalikKadans_yediGunSonraHatirlatir() {
        let next = ReminderPlanner.nextReminderDate(
            lastCapture: date(2026, 7, 1, 9),
            cadence: .weekly,
            hour: 8,
            now: date(2026, 7, 2, 12),
            calendar: calendar
        )

        XCTAssertEqual(next, date(2026, 7, 8, 8))
    }

    func test_hicCekimYoksa_bugunSaatGelmedenHatirlatir() {
        let next = ReminderPlanner.nextReminderDate(
            lastCapture: nil,
            cadence: .daily,
            hour: 19,
            now: date(2026, 7, 10, 12),
            calendar: calendar
        )

        XCTAssertEqual(next, date(2026, 7, 10, 19))
    }

    func test_saatGecmisse_ertesiGuneKayar() {
        let next = ReminderPlanner.nextReminderDate(
            lastCapture: nil,
            cadence: .daily,
            hour: 19,
            now: date(2026, 7, 10, 21),
            calendar: calendar
        )

        XCTAssertEqual(next, date(2026, 7, 11, 19))
    }

    func test_gecmisteKalanVadeler_hepGelecekteBirZamanaOturur() {
        let next = ReminderPlanner.nextReminderDate(
            lastCapture: date(2026, 6, 1, 9),
            cadence: .daily,
            hour: 19,
            now: date(2026, 7, 10, 21),
            calendar: calendar
        )

        XCTAssertEqual(next, date(2026, 7, 11, 19))
    }
}

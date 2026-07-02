import XCTest
@testable import Timelapse

final class ActivitySummaryTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func test_gunlukSayilar_bugunSonSiradadir() {
        let now = date(2026, 7, 10)
        let captures = [date(2026, 7, 10), date(2026, 7, 10), date(2026, 7, 8)]

        let counts = ActivitySummary.dailyCounts(capturedDates: captures, days: 7, now: now, calendar: calendar)

        XCTAssertEqual(counts, [0, 0, 0, 0, 1, 0, 2])
    }

    func test_gunlukSayilar_pencereDisindakileriSaymaz() {
        let now = date(2026, 7, 10)
        let captures = [date(2026, 7, 1), date(2026, 7, 11)]

        let counts = ActivitySummary.dailyCounts(capturedDates: captures, days: 7, now: now, calendar: calendar)

        XCTAssertEqual(counts.reduce(0, +), 0)
    }

    func test_seri_ardisikGunleriSayar() {
        let now = date(2026, 7, 10)
        let captures = [date(2026, 7, 10), date(2026, 7, 9), date(2026, 7, 8), date(2026, 7, 5)]

        XCTAssertEqual(ActivitySummary.streak(capturedDates: captures, now: now, calendar: calendar), 3)
    }

    func test_seri_bugunCekimYoksaDundenBaslar() {
        let now = date(2026, 7, 10)
        let captures = [date(2026, 7, 9), date(2026, 7, 8)]

        XCTAssertEqual(ActivitySummary.streak(capturedDates: captures, now: now, calendar: calendar), 2)
    }

    func test_seri_eskiCekimlerleSifirdir() {
        let now = date(2026, 7, 10)
        let captures = [date(2026, 7, 6)]

        XCTAssertEqual(ActivitySummary.streak(capturedDates: captures, now: now, calendar: calendar), 0)
    }

    func test_gunSayisi_ilkCekimdenBugunedir() {
        let now = date(2026, 7, 10)

        XCTAssertEqual(ActivitySummary.daysRunning(firstCapture: date(2026, 7, 1), now: now, calendar: calendar), 10)
        XCTAssertEqual(ActivitySummary.daysRunning(firstCapture: nil, now: now, calendar: calendar), 0)
    }
}

import Foundation

enum ActivitySummary {

    static func dailyCounts(
        capturedDates: [Date],
        days: Int = 7,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [Int] {
        let today = calendar.startOfDay(for: now)
        var counts = Array(repeating: 0, count: days)
        for date in capturedDates {
            let day = calendar.startOfDay(for: date)
            guard
                let offset = calendar.dateComponents([.day], from: day, to: today).day,
                offset >= 0, offset < days
            else { continue }
            counts[days - 1 - offset] += 1
        }
        return counts
    }

    static func streak(
        capturedDates: [Date],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        let capturedDays = Set(capturedDates.map { calendar.startOfDay(for: $0) })
        let today = calendar.startOfDay(for: now)
        var cursor = capturedDays.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today
        var streak = 0
        while capturedDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    static func daysRunning(
        firstCapture: Date?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard let firstCapture else { return 0 }
        let start = calendar.startOfDay(for: firstCapture)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return max(days + 1, 1)
    }
}

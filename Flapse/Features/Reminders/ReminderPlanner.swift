import Foundation

enum ReminderPlanner {

    static func nextReminderDate(
        lastCapture: Date?,
        cadence: CaptureCadence,
        hour: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        let dueDay: Date
        if let lastCapture {
            dueDay = cadence.nextDueDate(after: lastCapture, calendar: calendar)
        } else {
            dueDay = now
        }

        guard var candidate = calendar.date(
            bySettingHour: min(max(hour, 0), 23),
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: dueDay)
        ) else { return nil }

        while candidate <= now {
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { return nil }
            candidate = next
        }
        return candidate
    }
}

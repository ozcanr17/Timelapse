import Foundation
import SwiftData
import UserNotifications

@MainActor
final class ReminderScheduler {

    static let shared = ReminderScheduler()
    static let enabledKey = "remindersEnabled"
    static let hourKey = "reminderHour"

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func sync(projects: [Project]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        let hour = UserDefaults.standard.object(forKey: Self.hourKey) as? Int ?? 19

        for project in projects where !project.isDeleted {
            guard let date = ReminderPlanner.nextReminderDate(
                lastCapture: project.lastCaptureDate,
                cadence: project.cadence,
                hour: hour
            ) else { continue }

            let content = UNMutableNotificationContent()
            content.title = String(localized: "Çekim zamanı")
            content.body = String(localized: "\(project.title) için bugünkü kareni ekle.")
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: date
            )
            let request = UNNotificationRequest(
                identifier: "project-reminder-\(project.id.uuidString)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            center.add(request)
        }
    }
}

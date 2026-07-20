import Foundation
import SwiftData
import UserNotifications
import UIKit

@MainActor
final class ReminderScheduler {

    static let shared = ReminderScheduler()
    static let enabledKey = "remindersEnabled"
    static let hourKey = "reminderHour"
    private var schedulingTask: Task<Void, Never>?

    private struct ProjectSnapshot: Sendable {
        let id: UUID
        let cadence: CaptureCadence
        let lastCapture: Date?
        let notificationTitle: String
        let notificationBody: String
        let imageData: Data?
    }

    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func sync(projects: [Project]) {
        schedulingTask?.cancel()
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { return }
        let hour = UserDefaults.standard.object(forKey: Self.hourKey) as? Int ?? 19
        let snapshots = projects.compactMap { project -> ProjectSnapshot? in
            guard !project.isDeleted, project.deletedAt == nil, !project.isHidden else { return nil }
            var last: Entry?
            var count = 0
            for entry in project.entries ?? [] where !entry.isDeleted && entry.deletedAt == nil {
                count += 1
                if last == nil || entry.capturedAt > (last?.capturedAt ?? .distantPast) {
                    last = entry
                }
            }
            return ProjectSnapshot(
                id: project.id,
                cadence: project.cadence,
                lastCapture: last?.capturedAt,
                notificationTitle: count > 0
                    ? String(localized: "Gün \(count + 1) — devam et", bundle: .appLanguage)
                    : String(localized: "Çekim zamanı", bundle: .appLanguage),
                notificationBody: String(localized: "\(project.title) için bugünkü kareni ekle.", bundle: .appLanguage),
                imageData: last?.imageData
            )
        }

        schedulingTask = Task.detached(priority: .utility) {
            for project in snapshots {
                guard !Task.isCancelled else { return }
                guard let date = ReminderPlanner.nextReminderDate(
                    lastCapture: project.lastCapture,
                    cadence: project.cadence,
                    hour: hour
                ) else { continue }

                let content = UNMutableNotificationContent()
                content.title = project.notificationTitle
                content.body = project.notificationBody
                content.sound = .default
                if let imageData = project.imageData,
                   let attachment = Self.makeAttachment(imageData: imageData, id: project.id) {
                    content.attachments = [attachment]
                }

                let components = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                let request = UNNotificationRequest(
                    identifier: "project-reminder-\(project.id.uuidString)",
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                )
                try? await center.add(request)
            }
        }
    }

    private nonisolated static func makeAttachment(imageData: Data, id: UUID) -> UNNotificationAttachment? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("reminder-thumbs", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(id.uuidString).jpg")
        guard
            let image = ImageDownsampler.image(from: imageData, maxPixelSize: 900),
            let jpeg = image.jpegData(compressionQuality: 0.85)
        else { return nil }
        do {
            try jpeg.write(to: url, options: .atomic)
            return try UNNotificationAttachment(identifier: id.uuidString, url: url, options: nil)
        } catch {
            return nil
        }
    }
}

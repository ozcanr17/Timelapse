import Foundation
import SwiftData
import UIKit
import WidgetKit

/// Ana ekran widget'larının okuduğu ortak durum: gün serisi, bugünün çekim durumu,
/// aktivite ızgarası ve proje kapakları App Group deposuna yazılır.
enum WidgetStateWriter {

    static let suiteName = "group.rozcan.Flapse"

    static func update(projects: [Project]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let live = projects.filter { !$0.isDeleted && $0.deletedAt == nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dates = live.flatMap { ($0.entries ?? []).filter { !$0.isDeleted && $0.deletedAt == nil }.map(\.capturedAt) }
        defaults.set(ActivitySummary.streak(capturedDates: dates), forKey: "widget.streak")
        defaults.set(dates.contains { calendar.startOfDay(for: $0) == today }, forKey: "widget.capturedToday")
        defaults.set(live.filter { $0.isCaptureDue() }.count, forKey: "widget.dueCount")

        writeThumbnails(live: live, defaults: defaults, calendar: calendar, today: today)
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("widget", isDirectory: true)
    }

    private static func writeThumbnails(live: [Project], defaults: UserDefaults, calendar: Calendar, today: Date) {
        guard let dir = containerURL else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var latestByDay: [Int: Data] = [:]
        for project in live {
            for entry in (project.entries ?? []) where !entry.isDeleted && entry.deletedAt == nil {
                let day = calendar.startOfDay(for: entry.capturedAt)
                guard let offset = calendar.dateComponents([.day], from: day, to: today).day,
                      offset >= 0, offset < 35 else { continue }
                if latestByDay[offset] == nil, let data = entry.imageData {
                    latestByDay[offset] = data
                }
            }
        }

        let covers: [(title: String, data: Data?)] = live
            .sorted { ($0.lastCaptureDate ?? .distantPast) > ($1.lastCaptureDate ?? .distantPast) }
            .prefix(4)
            .map { ($0.title, $0.sortedEntries.last(where: { !$0.isDeleted })?.imageData) }

        Task.detached(priority: .utility) {
            for (offset, data) in latestByDay {
                if let thumb = await ImageDownsampler.image(from: data, maxPixelSize: 96),
                   let jpeg = thumb.jpegData(compressionQuality: 0.7) {
                    try? jpeg.write(to: dir.appendingPathComponent("grid-\(offset).jpg"), options: .atomic)
                }
            }
            for offset in 0..<35 where latestByDay[offset] == nil {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("grid-\(offset).jpg"))
            }
            var titles: [String] = []
            for (index, cover) in covers.enumerated() {
                titles.append(cover.title)
                let url = dir.appendingPathComponent("project-\(index).jpg")
                if let data = cover.data,
                   let thumb = await ImageDownsampler.image(from: data, maxPixelSize: 400),
                   let jpeg = thumb.jpegData(compressionQuality: 0.75) {
                    try? jpeg.write(to: url, options: .atomic)
                } else {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            for index in covers.count..<4 {
                try? FileManager.default.removeItem(at: dir.appendingPathComponent("project-\(index).jpg"))
            }
            defaults.set(titles, forKey: "widget.projectTitles")
            await MainActor.run { WidgetCenter.shared.reloadAllTimelines() }
        }
    }
}

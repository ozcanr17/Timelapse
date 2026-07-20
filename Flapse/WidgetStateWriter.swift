import Foundation
import SwiftData
import UIKit
import WidgetKit

enum WidgetStateWriter {
    static let suiteName = "group.rozcan.Flapse"

    @MainActor
    static func update(projects: [Project]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let liveProjects = projects.filter { !$0.isDeleted && $0.deletedAt == nil && !$0.isHidden }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var capturedDates: [Date] = []
        var projectCovers: [(project: Project, entry: Entry?)] = []

        for project in liveProjects {
            let entries = (project.entries ?? []).filter { !$0.isDeleted && $0.deletedAt == nil }
            capturedDates.append(contentsOf: entries.map(\.capturedAt))
            projectCovers.append((project, entries.max { $0.capturedAt < $1.capturedAt }))
        }

        let recentDayCounts = (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return capturedDates.reduce(into: 0) { count, date in
                if calendar.isDate(date, inSameDayAs: day) { count += 1 }
            }
        }
        defaults.set(ActivitySummary.streak(capturedDates: capturedDates), forKey: "widget.streak")
        defaults.set(recentDayCounts.first.map { $0 > 0 } ?? false, forKey: "widget.capturedToday")
        defaults.set(liveProjects.filter { $0.isCaptureDue() }.count, forKey: "widget.dueCount")
        defaults.set(capturedDates.count, forKey: "widget.totalCaptures")
        defaults.set(liveProjects.count, forKey: "widget.activeProjectCount")
        defaults.set(recentDayCounts, forKey: "widget.recentDayCounts")

        let covers = projectCovers
            .sorted { ($0.entry?.capturedAt ?? $0.project.createdAt) > ($1.entry?.capturedAt ?? $1.project.createdAt) }
            .prefix(4)
            .map { WidgetCover(title: $0.project.title, data: $0.entry?.imageData) }

        Task {
            await WidgetThumbnailWriter.shared.write(covers: covers)
        }
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)?
            .appendingPathComponent("widget", isDirectory: true)
    }
}

private struct WidgetCover: Sendable {
    let title: String
    let data: Data?
}

private actor WidgetThumbnailWriter {
    static let shared = WidgetThumbnailWriter()

    func write(covers: [WidgetCover]) async {
        guard let defaults = UserDefaults(suiteName: WidgetStateWriter.suiteName) else { return }
        guard let directory = WidgetStateWriter.containerURL else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let oldFiles = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in oldFiles where name.hasPrefix("grid-") {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }

        var titles: [String] = []
        for (index, cover) in covers.enumerated() {
            titles.append(cover.title)
            let url = directory.appendingPathComponent("project-\(index).jpg")
            if let image = await ImageDownsampler.image(from: cover.data, maxPixelSize: 480),
               let jpeg = image.jpegData(compressionQuality: 0.76) {
                try? jpeg.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
        for index in covers.count..<4 {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent("project-\(index).jpg"))
        }
        defaults.set(titles, forKey: "widget.projectTitles")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

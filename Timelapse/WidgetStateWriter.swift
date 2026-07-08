import Foundation
import SwiftData
import WidgetKit

/// Ana ekran widget'ının okuduğu ortak durum: gün serisi ve bugünün çekim durumu,
/// App Group UserDefaults'ına yazılır.
enum WidgetStateWriter {

    static let suiteName = "group.rozcan.Flapse"

    static func update(projects: [Project]) {
        guard let defaults = UserDefaults(suiteName: suiteName) else { return }
        let live = projects.filter { !$0.isDeleted && $0.deletedAt == nil }
        let dates = live.flatMap { ($0.entries ?? []).filter { !$0.isDeleted }.map(\.capturedAt) }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        defaults.set(ActivitySummary.streak(capturedDates: dates), forKey: "widget.streak")
        defaults.set(dates.contains { calendar.startOfDay(for: $0) == today }, forKey: "widget.capturedToday")
        defaults.set(live.filter { $0.isCaptureDue() }.count, forKey: "widget.dueCount")
        WidgetCenter.shared.reloadAllTimelines()
    }
}

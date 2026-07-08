import WidgetKit
import SwiftUI

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let capturedToday: Bool
    let dueCount: Int
}

struct StreakProvider: TimelineProvider {
    private var shared: UserDefaults? { UserDefaults(suiteName: "group.rozcan.Flapse") }

    private func currentEntry() -> StreakEntry {
        let defaults = shared
        return StreakEntry(
            date: Date(),
            streak: defaults?.integer(forKey: "widget.streak") ?? 0,
            capturedToday: defaults?.bool(forKey: "widget.capturedToday") ?? false,
            dueCount: defaults?.integer(forKey: "widget.dueCount") ?? 0
        )
    }

    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), streak: 5, capturedToday: false, dueCount: 1)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = currentEntry()
        let nextMidnight = Calendar.current.nextDate(
            after: Date(), matching: DateComponents(hour: 0, minute: 5), matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextMidnight)))
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(entry.streak > 0 ? .orange : .secondary)
                Text("\(entry.streak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
            }
            Text("gün serisi")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if entry.capturedToday {
                Label("Bugün çekildi", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            } else if entry.dueCount > 0 {
                Label("Bugün \(entry.dueCount) çekim", systemImage: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.orange)
            } else {
                Label("Bugün için tamam", systemImage: "checkmark.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(2)
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.07, blue: 0.09)
        }
    }
}

struct FlapseStreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseStreakWidget", provider: StreakProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Flapse")
        .description("Gün serin ve bugünün çekim durumu.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct FlapseWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlapseStreakWidget()
    }
}

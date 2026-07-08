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

struct WidgetStore {
    static let suite = UserDefaults(suiteName: "group.rozcan.Flapse")
    static var dir: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.rozcan.Flapse")?
            .appendingPathComponent("widget", isDirectory: true)
    }
    static func image(_ name: String) -> UIImage? {
        guard let dir else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(name).path)
    }
}

struct GridEntry: TimelineEntry {
    let date: Date
    let images: [Int: UIImage]
    let streak: Int
}

struct GridProvider: TimelineProvider {
    private func current() -> GridEntry {
        var images: [Int: UIImage] = [:]
        for offset in 0..<35 {
            if let image = WidgetStore.image("grid-\(offset).jpg") { images[offset] = image }
        }
        return GridEntry(date: Date(), images: images, streak: WidgetStore.suite?.integer(forKey: "widget.streak") ?? 0)
    }
    func placeholder(in context: Context) -> GridEntry { GridEntry(date: Date(), images: [:], streak: 3) }
    func getSnapshot(in context: Context, completion: @escaping (GridEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<GridEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct PhotoGridWidgetView: View {
    let entry: GridEntry

    var body: some View {
        GeometryReader { geo in
            let columns = 7
            let rows = 5
            let gap: CGFloat = 3
            let cell = min(
                (geo.size.width - gap * CGFloat(columns - 1)) / CGFloat(columns),
                (geo.size.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
            )
            VStack(spacing: gap) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: gap) {
                        ForEach(0..<columns, id: \.self) { column in
                            let offset = 34 - (row * columns + column)
                            cellView(offset: offset, size: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.07, blue: 0.09)
        }
    }

    @ViewBuilder
    private func cellView(offset: Int, size: CGFloat) -> some View {
        if offset >= 0, let image = entry.images[offset] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .frame(width: size, height: size)
        }
    }
}

struct FlapseGridWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseGridWidget", provider: GridProvider()) { entry in
            PhotoGridWidgetView(entry: entry)
        }
        .configurationDisplayName("Aktivite")
        .description("Son 5 haftanın kareleri.")
        .supportedFamilies([.systemMedium])
    }
}

struct ProjectsEntry: TimelineEntry {
    let date: Date
    let tiles: [(title: String, image: UIImage?)]
    let streak: Int
    let dueCount: Int
    let capturedToday: Bool
}

struct ProjectsProvider: TimelineProvider {
    private func current() -> ProjectsEntry {
        let titles = WidgetStore.suite?.stringArray(forKey: "widget.projectTitles") ?? []
        let tiles = titles.enumerated().map { index, title in
            (title: title, image: WidgetStore.image("project-\(index).jpg"))
        }
        return ProjectsEntry(
            date: Date(),
            tiles: tiles,
            streak: WidgetStore.suite?.integer(forKey: "widget.streak") ?? 0,
            dueCount: WidgetStore.suite?.integer(forKey: "widget.dueCount") ?? 0,
            capturedToday: WidgetStore.suite?.bool(forKey: "widget.capturedToday") ?? false
        )
    }
    func placeholder(in context: Context) -> ProjectsEntry {
        ProjectsEntry(date: Date(), tiles: [], streak: 3, dueCount: 1, capturedToday: false)
    }
    func getSnapshot(in context: Context, completion: @escaping (ProjectsEntry) -> Void) { completion(current()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ProjectsEntry>) -> Void) {
        completion(Timeline(entries: [current()], policy: .after(Date().addingTimeInterval(1800))))
    }
}

struct ProjectsWidgetView: View {
    let entry: ProjectsEntry

    var body: some View {
        GeometryReader { geo in
            let gap: CGFloat = 6
            let cellW = (geo.size.width - gap) / 2
            let cellH = (geo.size.height - gap) / 2
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    tile(0, width: cellW, height: cellH)
                    tile(1, width: cellW, height: cellH)
                }
                HStack(spacing: gap) {
                    tile(2, width: cellW, height: cellH)
                    tile(3, width: cellW, height: cellH)
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.06, green: 0.07, blue: 0.09)
        }
    }

    @ViewBuilder
    private func tile(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        if index < entry.tiles.count {
            ZStack(alignment: .bottomLeading) {
                if let image = entry.tiles[index].image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.white.opacity(0.08)
                }
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
                Text(entry.tiles[index].title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(7)
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            infoTile(index, width: width, height: height)
        }
    }

    @ViewBuilder
    private func infoTile(_ index: Int, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 4) {
            switch index {
            case entry.tiles.count:
                Image(systemName: "flame.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(entry.streak > 0 ? .orange : .secondary)
                Text("\(entry.streak)")
                    .font(.system(size: 22, weight: .bold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white)
                Text("gün serisi")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            default:
                if entry.capturedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.green)
                    Text("Bugün çekildi")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(entry.dueCount > 0 ? .orange : .secondary)
                    Text(entry.dueCount > 0 ? "Bugün \(entry.dueCount) çekim" : "Bugün için tamam")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: width, height: height)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct FlapseProjectsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseProjectsWidget", provider: ProjectsProvider()) { entry in
            ProjectsWidgetView(entry: entry)
        }
        .configurationDisplayName("Projeler")
        .description("Projelerinin son kareleri.")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct FlapseWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlapseStreakWidget()
        FlapseGridWidget()
        FlapseProjectsWidget()
    }
}

import WidgetKit
import SwiftUI

private let flapseAccent = Color(red: 0.22, green: 0.67, blue: 0.38)
private let captureURL = URL(string: "flapse://capture")

struct FlapseWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let capturedToday: Bool
    let dueCount: Int
    let projects: [(title: String, image: UIImage?)]
    let activityImages: [Int: UIImage]
}

struct FlapseProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlapseWidgetEntry {
        FlapseWidgetEntry(
            date: .now,
            streak: 12,
            capturedToday: false,
            dueCount: 1,
            projects: [(String(localized: "Flapse"), nil)],
            activityImages: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FlapseWidgetEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlapseWidgetEntry>) -> Void) {
        let refresh = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 5),
            matchingPolicy: .nextTime
        ) ?? Date.now.addingTimeInterval(1800)
        completion(Timeline(entries: [currentEntry()], policy: .after(refresh)))
    }

    private func currentEntry() -> FlapseWidgetEntry {
        let defaults = WidgetStore.suite
        let titles = defaults?.stringArray(forKey: "widget.projectTitles") ?? []
        var activityImages: [Int: UIImage] = [:]
        for offset in 0..<35 {
            activityImages[offset] = WidgetStore.image("grid-\(offset).jpg")
        }
        return FlapseWidgetEntry(
            date: .now,
            streak: defaults?.integer(forKey: "widget.streak") ?? 0,
            capturedToday: defaults?.bool(forKey: "widget.capturedToday") ?? false,
            dueCount: defaults?.integer(forKey: "widget.dueCount") ?? 0,
            projects: titles.enumerated().map { index, title in
                (title, WidgetStore.image("project-\(index).jpg"))
            },
            activityImages: activityImages
        )
    }
}

enum WidgetStore {
    static let suite = UserDefaults(suiteName: "group.rozcan.Flapse")

    private static var directory: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.rozcan.Flapse")?
            .appendingPathComponent("widget", isDirectory: true)
    }

    static func image(_ name: String) -> UIImage? {
        guard let directory else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(name).path)
    }
}

private struct WidgetCanvas: View {
    var body: some View {
        Color(uiColor: .secondarySystemBackground)
    }
}

private struct FlapseWordmark: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.inset.filled")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(flapseAccent)
            Text("Flapse")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }
}

private struct ProjectPhoto: View {
    let project: (title: String, image: UIImage?)?
    let cornerRadius: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = project?.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color(uiColor: .tertiarySystemFill)
                Image(systemName: "photo")
                    .font(.title2.weight(.regular))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let title = project?.title {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.62)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(10)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct TodayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FlapseWidgetEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                mediumLayout
            } else {
                smallLayout
            }
        }
        .widgetURL(captureURL)
        .containerBackground(for: .widget) { WidgetCanvas() }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                FlapseWordmark()
                Spacer()
                statusSymbol
            }
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(entry.streak)")
                    .font(.system(.largeTitle, design: .default, weight: .bold))
                    .monospacedDigit()
                Text("gün serisi")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            statusLabel
        }
    }

    private var mediumLayout: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                FlapseWordmark()
                Spacer()
                Text(entry.capturedToday ? "Bugün için tamam" : "Flapse")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(entry.streak)")
                        .font(.system(.title, design: .default, weight: .bold))
                        .monospacedDigit()
                    Text("gün serisi")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                statusLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            ProjectPhoto(project: entry.projects.first, cornerRadius: 16)
                .frame(width: 132)
        }
    }

    private var statusSymbol: some View {
        Image(systemName: entry.capturedToday ? "checkmark.circle.fill" : "camera.circle.fill")
            .font(.title3)
            .foregroundStyle(entry.capturedToday ? flapseAccent : .orange)
            .accessibilityHidden(true)
    }

    private var statusLabel: some View {
        Label(statusText, systemImage: entry.capturedToday ? "checkmark" : "camera.fill")
            .font(.caption.weight(.semibold))
            .foregroundStyle(entry.capturedToday ? flapseAccent : .primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var statusText: String {
        if entry.capturedToday {
            return String(localized: "Bugün çekildi")
        }
        if entry.dueCount > 0 {
            return String(localized: "Bugün \(entry.dueCount) çekim")
        }
        return String(localized: "Bugün için tamam")
    }
}

struct FlapseTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseStreakWidget", provider: FlapseProvider()) { entry in
            TodayWidgetView(entry: entry)
        }
        .configurationDisplayName("Flapse")
        .description("Gün serin ve bugünün çekim durumu.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct ActivityWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FlapseWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aktivite")
                        .font(family == .systemSmall ? .caption.weight(.semibold) : .headline)
                    if family != .systemSmall {
                        Text("Son 5 haftanın kareleri.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Label("\(entry.streak)", systemImage: "flame.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            ActivityGrid(
                images: entry.activityImages,
                columns: family == .systemSmall ? 5 : 7,
                rows: family == .systemLarge ? 5 : family == .systemMedium ? 5 : 5
            )
            if family == .systemLarge {
                Divider()
                HStack(spacing: 12) {
                    statusSummary
                    Spacer()
                    Text(entry.date, format: .dateTime.month(.wide).year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .widgetURL(captureURL)
        .containerBackground(for: .widget) { WidgetCanvas() }
    }

    private var statusSummary: some View {
        Label(
            statusText,
            systemImage: entry.capturedToday ? "checkmark.circle.fill" : "camera.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(entry.capturedToday ? flapseAccent : .primary)
    }

    private var statusText: String {
        if entry.capturedToday {
            return String(localized: "Bugün çekildi")
        }
        if entry.dueCount > 0 {
            return String(localized: "Bugün \(entry.dueCount) çekim")
        }
        return String(localized: "Bugün için tamam")
    }
}

private struct ActivityGrid: View {
    let images: [Int: UIImage]
    let columns: Int
    let rows: Int

    var body: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 4
            let cell = min(
                (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns),
                (geometry.size.height - spacing * CGFloat(rows - 1)) / CGFloat(rows)
            )
            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<columns, id: \.self) { column in
                            let index = row * columns + column
                            let offset = columns * rows - index - 1
                            activityCell(offset: offset, size: cell)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func activityCell(offset: Int, size: CGFloat) -> some View {
        if let image = images[offset] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemFill))
                .frame(width: size, height: size)
        }
    }
}

struct FlapseActivityWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseGridWidget", provider: FlapseProvider()) { entry in
            ActivityWidgetView(entry: entry)
        }
        .configurationDisplayName("Aktivite")
        .description("Son 5 haftanın kareleri.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ProjectsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FlapseWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Projeler")
                        .font(.headline)
                    Text(projectSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(flapseAccent)
            }
            if family == .systemLarge {
                largeGrid
            } else {
                mediumGrid
            }
        }
        .widgetURL(captureURL)
        .containerBackground(for: .widget) { WidgetCanvas() }
    }

    private var mediumGrid: some View {
        HStack(spacing: 8) {
            ProjectPhoto(project: project(at: 0), cornerRadius: 14)
                .frame(maxWidth: .infinity)
            VStack(spacing: 8) {
                ProjectPhoto(project: project(at: 1), cornerRadius: 12)
                ProjectPhoto(project: project(at: 2), cornerRadius: 12)
            }
            .frame(width: 104)
        }
    }

    private var largeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                ProjectPhoto(project: project(at: index), cornerRadius: 16)
                    .frame(height: 108)
            }
        }
    }

    private var projectSubtitle: String {
        if entry.projects.isEmpty {
            return String(localized: "Projeler")
        }
        if entry.dueCount > 0 {
            return String(localized: "Bugün \(entry.dueCount) çekim")
        }
        return String(localized: "Bugün için tamam")
    }

    private func project(at index: Int) -> (title: String, image: UIImage?)? {
        guard entry.projects.indices.contains(index) else { return nil }
        return entry.projects[index]
    }
}

struct FlapseProjectsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseProjectsWidget", provider: FlapseProvider()) { entry in
            ProjectsWidgetView(entry: entry)
        }
        .configurationDisplayName("Projeler")
        .description("Projelerinin son kareleri.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct LockScreenWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: FlapseWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                inline
            case .accessoryCircular:
                circular
            default:
                rectangular
            }
        }
        .widgetURL(captureURL)
    }

    private var inline: some View {
        Label {
            HStack(spacing: 3) {
                Text("Flapse")
                Text("·")
                Text(rectangularStatus)
            }
        } icon: {
            Image(systemName: entry.capturedToday ? "checkmark.circle.fill" : "camera.fill")
        }
    }

    private var circular: some View {
        Gauge(value: min(Double(entry.streak), 30), in: 0...30) {
            Image(systemName: "flame.fill")
        } currentValueLabel: {
            Text("\(entry.streak)")
                .font(.headline)
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .accessibilityLabel(Text("\(entry.streak)") + Text(" ") + Text("gün serisi"))
    }

    private var rectangular: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Flapse")
                    .font(.caption.weight(.semibold))
                HStack(spacing: 4) {
                    Text("\(entry.streak)")
                        .monospacedDigit()
                    Text("gün serisi")
                }
                .font(.headline)
                Text(rectangularStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Image(systemName: entry.capturedToday ? "checkmark.circle.fill" : "camera.circle.fill")
                .font(.title2)
                .widgetAccentable()
        }
    }

    private var rectangularStatus: String {
        if entry.capturedToday {
            return String(localized: "Bugün çekildi")
        }
        if entry.dueCount > 0 {
            return String(localized: "Bugün \(entry.dueCount) çekim")
        }
        return String(localized: "Bugün için tamam")
    }
}

struct FlapseLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FlapseLockScreenWidget", provider: FlapseProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Flapse")
        .description("Gün serin ve bugünün çekim durumu.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .accessoryCircular])
    }
}

@main
struct FlapseWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlapseTodayWidget()
        FlapseActivityWidget()
        FlapseProjectsWidget()
        FlapseLockScreenWidget()
        FlapseRenderLiveActivity()
    }
}

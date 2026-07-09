import SwiftUI
import SwiftData
import UIKit

struct HomeView: View {

    @Query(filter: #Predicate<Project> { $0.deletedAt == nil }, sort: \Project.createdAt, order: .reverse)
    private var projects: [Project]
    @Environment(\.theme) private var theme

    private var liveProjects: [Project] {
        projects.filter { !$0.isDeleted && $0.deletedAt == nil }
    }

    private var liveEntries: [Entry] {
        liveProjects.flatMap { ($0.entries ?? []).filter { !$0.isDeleted } }
    }

    private var dueProjects: [Project] {
        liveProjects.filter { $0.isCaptureDue() }
    }

    private var longestStreak: Int {
        liveProjects.map { ActivitySummary.streak(capturedDates: $0.sortedEntries.map(\.capturedAt)) }.max() ?? 0
    }

    private var weekCount: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return liveEntries.filter { $0.capturedAt >= cutoff }.count
    }

    private var recentEntries: [Entry] {
        liveEntries.sorted { $0.capturedAt > $1.capturedAt }.prefix(10).map { $0 }
    }

    private var greeting: LocalizedStringKey {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  "Günaydın"
        case 12..<18: "İyi günler"
        default:      "İyi akşamlar"
        }
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ActivityHeroCard(projects: projects)
                    if !dueProjects.isEmpty {
                        dueSection
                    }
                    flashcardDeck
                    if !recentEntries.isEmpty {
                        recentSection
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Flapse")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 28, weight: .bold, design: .default))
                .foregroundStyle(theme.ink)
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLanguage.currentLocale)))
                .font(Theme.caption(14))
                .foregroundStyle(theme.inkMuted)
        }
    }

    private var flashcardDeck: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                Flashcard(
                    icon: "square.grid.2x2.fill",
                    value: "\(liveProjects.count)",
                    label: "Aktif proje",
                    tint: Color(light: "4F46E5", dark: "8B85F4"),
                    tilt: -2.5
                )
                Flashcard(
                    icon: "photo.stack.fill",
                    value: "\(liveEntries.count)",
                    label: "Toplam kare",
                    tint: Color(light: "2E8B57", dark: "5FD98A"),
                    tilt: 2
                )
                Flashcard(
                    icon: "flame.fill",
                    value: "\(longestStreak)",
                    label: "En uzun seri",
                    tint: Color(light: "C2560B", dark: "F09A4E"),
                    tilt: -1.5
                )
                Flashcard(
                    icon: "calendar",
                    value: "\(weekCount)",
                    label: "Bu hafta",
                    tint: Color(light: "3E8E9E", dark: "7FC3D1"),
                    tilt: 2.5
                )
                Flashcard(
                    icon: "sun.max.fill",
                    message: "Her gün aynı ışıkta çekersen geçişler daha pürüzsüz olur.",
                    tint: Color(light: "B0722E", dark: "E0A468"),
                    tilt: -2
                )
                Flashcard(
                    icon: "person.crop.rectangle",
                    message: "Hayalet hizalamayla özneyi hep aynı yerde tut.",
                    tint: Color(light: "9A5BA6", dark: "C99BD6"),
                    tilt: 1.5
                )
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 12)
        }
        .scrollClipDisabled()
    }

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bugün çekim zamanı")
                .font(Theme.caption(13))
                .foregroundStyle(theme.inkMuted)
            ForEach(dueProjects) { project in
                NavigationLink {
                    ProjectDetailView(project: project)
                } label: {
                    dueRow(project)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func dueRow(_ project: Project) -> some View {
        let accent = Theme.accent(for: project.category)
        return HStack(spacing: 12) {
            Image(systemName: Theme.icon(for: project.category))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 38, height: 38)
                .background(accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text("\(project.sortedEntries.count) kare · \(project.cadence.displayName)")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(12)
        .liquidGlassStyle()
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Son kareler")
                .font(Theme.caption(13))
                .foregroundStyle(theme.inkMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentEntries) { entry in
                        RecentEntryThumb(entry: entry)
                    }
                }
            }
        }
    }
}

private struct Flashcard: View {
    let icon: String
    var value: String? = nil
    var label: LocalizedStringKey? = nil
    var message: LocalizedStringKey? = nil
    let tint: Color
    let tilt: Double

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 10)

            if let value, let label {
                Text(value)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
                Text(label)
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
                    .padding(.top, 2)
            } else if let message {
                Text(message)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 138, height: 158, alignment: .leading)
        .liquidGlassStyle(cornerRadius: 22)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(tint.opacity(0.35), lineWidth: 1)
        )
        .rotationEffect(.degrees(tilt))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

private struct RecentEntryThumb: View {
    let entry: Entry

    @Environment(\.theme) private var theme
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(theme.surface)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: 84, height: 112)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task {
            image = await ImageDownsampler.cachedImage(key: "home-\(entry.id)", maxPixelSize: 300) { entry.imageData }
        }
    }
}

struct ActivityHeroCard: View {
    let projects: [Project]

    @Environment(\.theme) private var theme

    private var liveProjects: [Project] {
        projects.filter { !$0.isDeleted && $0.deletedAt == nil }
    }

    private var liveEntries: [Entry] {
        liveProjects.flatMap { ($0.entries ?? []).filter { !$0.isDeleted } }
    }

    private var totalCaptures: Int { liveEntries.count }

    private var dueCount: Int {
        liveProjects.filter { $0.isCaptureDue() }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("AKTİVİTE")
                    .font(Theme.caption(11))
                    .foregroundStyle(theme.inkMuted)
                    .tracking(1.2)
                Spacer()
                (
                    Text("\(totalCaptures)")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
                    +
                    Text(" kare")
                        .font(Theme.caption(13))
                        .foregroundStyle(theme.inkMuted)
                )
            }

            ContributionGrid(entries: liveEntries, accent: theme.accent)

            if dueCount > 0 {
                Label("Bugün \(dueCount) projede çekim zamanı", systemImage: "bell.fill")
                    .font(Theme.caption(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accent, in: Capsule())
            } else {
                Label("Bugün için her şey tamam", systemImage: "checkmark.circle.fill")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private struct ContributionGrid: View {
    let entries: [Entry]
    let accent: Color

    @Environment(\.theme) private var theme
    @Environment(\.displayScale) private var displayScale
    @State private var thumbnails: [Date: UIImage] = [:]

    private let weeks = 15
    private let cell: CGFloat = 11
    private let gap: CGFloat = 3

    private var countsByDay: [Date: Int] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        for entry in entries {
            counts[calendar.startOfDay(for: entry.capturedAt), default: 0] += 1
        }
        return counts
    }

    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekdayIndex = (calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7
        let counts = countsByDay
        HStack(spacing: gap) {
            ForEach(0..<weeks, id: \.self) { column in
                VStack(spacing: gap) {
                    ForEach(0..<7, id: \.self) { row in
                        let offset = (weeks - 1 - column) * 7 + (weekdayIndex - row)
                        square(offset: offset, today: today, calendar: calendar, counts: counts)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: entries.count) { await loadThumbnails() }
    }

    @ViewBuilder
    private func square(offset: Int, today: Date, calendar: Calendar, counts: [Date: Int]) -> some View {
        if offset < 0 {
            Color.clear.frame(width: cell, height: cell)
        } else {
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            if let thumbnail = thumbnails[date] {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cell, height: cell)
                    .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(fill(for: counts[date] ?? 0))
                    .frame(width: cell, height: cell)
            }
        }
    }

    private func fill(for count: Int) -> Color {
        switch count {
        case 0:  theme.inkMuted.opacity(0.12)
        case 1:  accent.opacity(0.4)
        case 2:  accent.opacity(0.7)
        default: accent
        }
    }

    private func loadThumbnails() async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let earliest = calendar.date(byAdding: .day, value: -(weeks * 7), to: today) else { return }

        var latestByDay: [Date: Entry] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.capturedAt)
            guard day >= earliest else { continue }
            if let current = latestByDay[day], current.capturedAt >= entry.capturedAt { continue }
            latestByDay[day] = entry
        }

        var thumbs: [Date: UIImage] = [:]
        for (day, entry) in latestByDay {
            thumbs[day] = await ImageDownsampler.cachedImage(
                key: "grid-\(entry.id)",
                maxPixelSize: cell * displayScale * 2
            ) { entry.imageData }
        }
        thumbnails = thumbs
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .modelContainer(AppModelContainer.makeInMemory())
    .environment(StoreService())
}

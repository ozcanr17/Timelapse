import SwiftUI
import SwiftData

/// Projeleri listeleyen ana ekran.
struct ProjectListView: View {

    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Environment(\.theme) private var theme

    @State private var activeSheet: ActiveSheet?
    @State private var isShowingSettings = false

    private enum ActiveSheet: Identifiable {
        case addProject
        case paywall
        var id: Int { hashValue }
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            if projects.isEmpty {
                EmptyProjectsView()
            } else {
                List {
                    ActivityHeroCard(projects: projects)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))

                    ForEach(projects) { project in
                        if !project.isDeleted {
                            ProjectCard(project: project)
                                .background(
                                    NavigationLink("") {
                                        ProjectDetailView(project: project)
                                    }
                                    .opacity(0)
                                )
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                    }
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Projeler")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(theme.inkMuted)
                }
                .accessibilityIdentifier("settingsButton")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addProjectTapped()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.accent)
                }
                .accessibilityIdentifier("addProjectButton")
            }
        }
        .navigationDestination(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addProject:
                AddProjectSheet(repository: ProjectRepository(context: modelContext))
            case .paywall:
                PaywallView(store: store)
            }
        }
    }

    private func addProjectTapped() {
        if FeatureGate.canCreateProject(isPro: store.isPro, currentProjectCount: projects.count) {
            activeSheet = .addProject
        } else {
            activeSheet = .paywall
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        let repository = ProjectRepository(context: modelContext)
        let toDelete = offsets.compactMap { index in
            projects.indices.contains(index) ? projects[index] : nil
        }
        withAnimation {
            for project in toDelete {
                try? repository.deleteProject(project)
            }
        }
    }
}

private struct ActivityHeroCard: View {
    let projects: [Project]

    @Environment(\.theme) private var theme

    private var liveProjects: [Project] {
        projects.filter { !$0.isDeleted }
    }

    private var capturedDates: [Date] {
        liveProjects.flatMap { ($0.entries ?? []).map(\.capturedAt) }
    }

    private var counts: [Int] {
        ActivitySummary.dailyCounts(capturedDates: capturedDates)
    }

    private var weekTotal: Int {
        counts.reduce(0, +)
    }

    private var dueCount: Int {
        liveProjects.filter { $0.isCaptureDue() }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BU HAFTA")
                        .font(Theme.caption(11))
                        .foregroundStyle(theme.inkMuted)
                        .tracking(1.2)
                    (
                        Text("\(weekTotal)")
                            .font(Theme.stamp(32, weight: .bold))
                            .foregroundStyle(theme.ink)
                        +
                        Text(" çekim")
                            .font(Theme.headline(15))
                            .foregroundStyle(theme.inkMuted)
                    )
                }
                Spacer()
                WeeklyBars(counts: counts)
            }

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

private struct WeeklyBars: View {
    let counts: [Int]

    @Environment(\.theme) private var theme

    var body: some View {
        let maxCount = max(counts.max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(Array(counts.enumerated()), id: \.offset) { _, count in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(count > 0 ? AnyShapeStyle(theme.accent) : AnyShapeStyle(theme.inkMuted.opacity(0.18)))
                    .frame(width: 10, height: max(8, 52 * CGFloat(count) / CGFloat(maxCount)))
            }
        }
        .frame(height: 56, alignment: .bottom)
    }
}

/// Liste satırı: kategori renkli ikon rozeti + başlık + damga fontuyla çekim sayısı.
private struct ProjectCard: View {
    let project: Project

    @Environment(\.theme) private var theme

    private var accent: Color { Theme.accent(for: project.category) }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(accent.opacity(0.15)).frame(width: 52, height: 52)
                Image(systemName: Theme.icon(for: project.category))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(Theme.headline(17))
                    .foregroundStyle(theme.ink)

                HStack(spacing: 6) {
                    Text("\(project.sortedEntries.count)")
                        .font(Theme.stamp(13))
                    Text("çekim · \(project.cadence.displayName)")
                }
                .font(Theme.caption())
                .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            if project.isCaptureDue() {
                Text("Bugün")
                    .font(Theme.caption(12))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent)
                    .clipShape(Capsule())
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.inkMuted.opacity(0.4))
            }
        }
        .padding(16)
        .cardStyle()
    }
}

private struct EmptyProjectsView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(theme.accent.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(theme.accent)
            }
            VStack(spacing: 6) {
                Text("İlk hikayeni başlat")
                    .font(Theme.headline(22))
                    .foregroundStyle(theme.ink)
                Text("Sağ üstteki + ile bir proje oluştur,\nzamanla değişimi kaydetmeye başla.")
                    .font(Theme.body(15))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 90)
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
    }
    .modelContainer(AppModelContainer.makeInMemory())
    .environment(StoreService())
}

import SwiftUI
import SwiftData

/// Projeleri listeleyen ana ekran.
struct ProjectListView: View {

    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store

    @State private var activeSheet: ActiveSheet?

    private enum ActiveSheet: Identifiable {
        case addProject
        case paywall
        var id: Int { hashValue }
    }

    var body: some View {
        ZStack {
            Theme.canvas.ignoresSafeArea()

            if projects.isEmpty {
                EmptyProjectsView()
            } else {
                List {
                    ForEach(projects) { project in
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
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Projeler")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addProjectTapped()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Theme.rust)
                }
            }
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
        for index in offsets {
            try? repository.deleteProject(projects[index])
        }
    }
}

/// Liste satırı: kategori renkli ikon rozeti + başlık + damga fontuyla çekim sayısı.
private struct ProjectCard: View {
    let project: Project
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
                    .foregroundStyle(Theme.ink)

                HStack(spacing: 6) {
                    Text("\(project.sortedEntries.count)")
                        .font(Theme.stamp(13))
                    Text("çekim · \(project.cadence.displayName)")
                }
                .font(Theme.caption())
                .foregroundStyle(Theme.inkMuted)
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
                    .foregroundStyle(Theme.inkMuted.opacity(0.4))
            }
        }
        .padding(16)
        .cardStyle()
    }
}

private struct EmptyProjectsView: View {
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(Theme.rust.opacity(0.12)).frame(width: 96, height: 96)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Theme.rust)
            }
            VStack(spacing: 6) {
                Text("İlk hikayeni başlat")
                    .font(Theme.headline(22))
                    .foregroundStyle(Theme.ink)
                Text("Sağ üstteki + ile bir proje oluştur,\nzamanla değişimi kaydetmeye başla.")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkMuted)
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

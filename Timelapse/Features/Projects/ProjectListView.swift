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
    @State private var pendingDeletion: [Project] = []
    @State private var showQuickPick = false
    @State private var captureTarget: Project?

    private enum ActiveSheet: Identifiable {
        case addProject
        case paywall
        var id: Int { hashValue }
    }

    private var liveProjects: [Project] {
        projects.filter { !$0.isDeleted }
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
        .safeAreaInset(edge: .bottom) {
            if !liveProjects.isEmpty {
                homeCaptureButton
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
        .sheet(isPresented: $showQuickPick) {
            QuickCaptureSheet(projects: liveProjects) { project in
                beginCapture(project)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $captureTarget) { project in
            CameraCaptureView(project: project)
        }
        .confirmationDialog(
            "Proje ve içindeki tüm çekimler kalıcı olarak silinsin mi?",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) { confirmDeletion() }
            Button("Vazgeç", role: .cancel) { pendingDeletion = [] }
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(
            get: { !pendingDeletion.isEmpty },
            set: { if !$0 { pendingDeletion = [] } }
        )
    }

    private func confirmDeletion() {
        let repository = ProjectRepository(context: modelContext)
        let toDelete = pendingDeletion
        pendingDeletion = []
        withAnimation {
            for project in toDelete where !project.isDeleted {
                try? repository.deleteProject(project)
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            try? repository.saveIfNeeded()
        }
    }

    private func addProjectTapped() {
        if FeatureGate.canCreateProject(isPro: store.isPro, currentProjectCount: projects.count) {
            activeSheet = .addProject
        } else {
            activeSheet = .paywall
        }
    }

    /// Ana ekranda öne çıkan çekim düğmesi: uygulamanın asıl amacı. Tek proje varsa
    /// doğrudan kameraya gider; birden fazlaysa alttan hızlı seçim açılır.
    private var homeCaptureButton: some View {
        Button {
            if liveProjects.count == 1 {
                beginCapture(liveProjects[0])
            } else {
                showQuickPick = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill").font(.system(size: 18, weight: .bold))
                Text("Kare Çek").font(Theme.headline(17))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .background(Capsule().fill(theme.accent))
            .shadow(color: theme.accent.opacity(0.45), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
        .accessibilityIdentifier("homeCaptureButton")
    }

    private func beginCapture(_ project: Project) {
        let count = project.sortedEntries.filter { !$0.isDeleted }.count
        guard FeatureGate.canAddEntry(isPro: store.isPro, currentEntryCount: count) else {
            showQuickPick = false
            activeSheet = .paywall
            return
        }
        if showQuickPick {
            // Hızlı seçim sayfasını kapatıp kamerayı sun; iki modalin çakışmaması için
            // kısa bir gecikme veriyoruz.
            showQuickPick = false
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(380))
                captureTarget = project
            }
        } else {
            captureTarget = project
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        pendingDeletion = offsets.compactMap { index in
            projects.indices.contains(index) ? projects[index] : nil
        }
    }
}

/// Ana ekrandan "Kare Çek" ile açılan, alt yarıdan gelen hızlı proje seçici.
private struct QuickCaptureSheet: View {
    let projects: [Project]
    let onSelect: (Project) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    let accent = Theme.accent(for: project.category)
                    Button {
                        onSelect(project)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(accent.opacity(0.15)).frame(width: 44, height: 44)
                                Image(systemName: Theme.icon(for: project.category))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title).font(Theme.headline(16)).foregroundStyle(theme.ink)
                                Text("\(project.sortedEntries.count) kare")
                                    .font(Theme.caption(12)).foregroundStyle(theme.inkMuted)
                            }
                            Spacer()
                            if project.isCaptureDue() {
                                Text("Bugün")
                                    .font(Theme.caption(11)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(accent, in: Capsule())
                            }
                            Image(systemName: "camera.fill").foregroundStyle(accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.surface)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("Hangi projeye?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
}

private struct ActivityHeroCard: View {
    let projects: [Project]

    @Environment(\.theme) private var theme
    @State private var isBreathing = false

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
                    .shadow(color: theme.accent.opacity(isBreathing ? 0.55 : 0.15), radius: isBreathing ? 10 : 3)
                    .scaleEffect(isBreathing ? 1.03 : 1)
                    .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true), value: isBreathing)
                    .onAppear { isBreathing = true }
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

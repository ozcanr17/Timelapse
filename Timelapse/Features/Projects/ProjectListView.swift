import SwiftUI
import SwiftData
import UIKit

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
    @State private var captureRoute: CaptureRoute?
    @State private var pendingCapture: Project?

    private enum ActiveSheet: Identifiable {
        case addProject
        case importNew
        case paywall
        var id: Int { hashValue }
    }

    private enum CaptureRoute: Identifiable {
        case project(Project)
        case auto
        var id: String {
            switch self {
            case .project(let project): project.id.uuidString
            case .auto: "auto"
            }
        }
    }

    private var liveProjects: [Project] {
        projects.filter { !$0.isDeleted }
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            if projects.isEmpty {
                EmptyProjectsView(onCreate: addProjectTapped)
            } else {
                List {
                    ActivityHeroCard(projects: projects)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 10, trailing: 16))

                    ForEach(projects) { project in
                        if !project.isDeleted {
                            ProjectCard(project: project)
                                .overlay {
                                    NavigationLink {
                                        ProjectDetailView(project: project)
                                    } label: {
                                        Color.clear
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("projectCard-\(project.title)")
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
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
                    importTapped()
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18))
                        .foregroundStyle(theme.accent)
                }
                .accessibilityIdentifier("importProjectButton")
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
            case .importNew:
                PhotoImportSheet(mode: .newProject, repository: ProjectRepository(context: modelContext))
            case .paywall:
                PaywallView(store: store)
            }
        }
        .sheet(isPresented: $showQuickPick, onDismiss: presentPendingCapture) {
            QuickCaptureSheet(projects: liveProjects) { project in
                pendingCapture = project
                showQuickPick = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $captureRoute) { route in
            switch route {
            case .project(let project):
                CameraCaptureView(project: project)
            case .auto:
                AutoCaptureFlow(projects: liveProjects)
            }
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

    private func importTapped() {
        activeSheet = store.isPro ? .importNew : .paywall
    }

    /// Ana ekranda öne çıkan çekim düğmesi: uygulamanın asıl amacı. Tek proje varsa
    /// doğrudan kameraya gider; birden fazlaysa alttan hızlı seçim açılır.
    private var homeCaptureButton: some View {
        Button {
            if store.isPro { captureRoute = .auto } else { showQuickPick = true }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "camera.fill").font(.system(size: 16, weight: .semibold))
                Text("Kare Çek").font(Theme.headline(17))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 28)
            .padding(.vertical, 15)
            .background(theme.accent, in: Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 6)
        .accessibilityIdentifier("homeCaptureButton")
    }

    /// Hızlı seçim sayfası KAPANDIKTAN sonra çağrılır (onDismiss). Böylece kamera, sayfa
    /// tamamen kapandığı anda gecikmesiz açılır — iki modal çakışmaz.
    private func presentPendingCapture() {
        guard let project = pendingCapture else { return }
        pendingCapture = nil
        let count = project.sortedEntries.filter { !$0.isDeleted }.count
        if FeatureGate.canAddEntry(isPro: store.isPro, currentEntryCount: count) {
            captureRoute = .project(project)
        } else {
            activeSheet = .paywall
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
                            .font(.system(size: 32, weight: .bold, design: .default))
                            .monospacedDigit()
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

/// Büyük foto-kahraman kartı: projenin son karesi arka plan olur; üstüne okunabilirlik
/// için koyu geçiş, başlık ve ilerleme biner. Fotoğraf yoksa kategori rengine düşer.
private struct ProjectCard: View {
    let project: Project

    @Environment(\.theme) private var theme
    @State private var photo: UIImage?

    private var accent: Color { Theme.accent(for: project.category) }
    private var count: Int { project.sortedEntries.filter { !$0.isDeleted }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: Theme.icon(for: project.category))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.28), in: Circle())
                Spacer()
                if project.isCaptureDue() {
                    Text("Bugün")
                        .font(Theme.caption(12))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
            }

            Spacer(minLength: 12)

            Text(project.title)
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundStyle(.white)
            HStack(spacing: 6) {
                Text("\(count)")
                    .monospacedDigit()
                    .fontWeight(.semibold)
                Text("kare · \(project.cadence.displayName)")
            }
            .font(Theme.caption(13))
            .foregroundStyle(.white.opacity(0.92))
            .padding(.top, 3)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 188)
        .background {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [accent, accent.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                LinearGradient(
                    colors: [.black.opacity(0.25), .clear, .black.opacity(0.55)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .task(id: project.sortedEntries.last?.imageData?.count) {
            photo = await ImageDownsampler.image(from: project.sortedEntries.last?.imageData, maxPixelSize: 800)
        }
    }
}

private struct EmptyProjectsView: View {
    let onCreate: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.accent.opacity(0.12))
                .frame(width: 108, height: 108)
                .overlay(
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 46, weight: .regular))
                        .foregroundStyle(theme.accent)
                )

            VStack(spacing: 8) {
                Text("İlk hikayeni başlat")
                    .font(.system(size: 26, weight: .bold, design: .default))
                    .foregroundStyle(theme.ink)
                Text("Günde bir kare çek; zamanla değişimin\nkendiliğinden bir timelapse'e dönüşsün.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onCreate) {
                Label("Yeni Proje", systemImage: "plus")
                    .font(Theme.headline(17))
            }
            .buttonStyle(.timelapsePrimary)
            .frame(maxWidth: 260)
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
    }
    .modelContainer(AppModelContainer.makeInMemory())
    .environment(StoreService())
}

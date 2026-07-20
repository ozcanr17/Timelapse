import SwiftUI
import SwiftData
import UIKit

/// Projeleri listeleyen ana ekran.
struct ProjectListView: View {

    @Query(filter: #Predicate<Project> { $0.deletedAt == nil }, sort: \Project.createdAt, order: .reverse)
    private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Environment(\.theme) private var theme

    @State private var activeSheet: ActiveSheet?
    @State private var pendingAfterSignIn: ActiveSheet?
    @AppStorage("auth.gateSkipped") private var signInGateSkipped = false
    @State private var pendingDeletion: [Project] = []
    @State private var resumeExportProject: Project?
    @State private var checkedJobID: UUID?

    private var renderService: TimelapseRenderService { TimelapseRenderService.shared }

    private enum ActiveSheet: Identifiable {
        case addProject
        case importNew
        case paywall
        case signIn
        var id: Int { hashValue }
    }

    private var activeProjects: [Project] {
        projects
            .filter { !$0.isDeleted && $0.deletedAt == nil }
            .map { (project: $0, activity: $0.lastActivityDate) }
            .sorted {
                if $0.activity == $1.activity {
                    return $0.project.createdAt > $1.project.createdAt
                }
                return $0.activity > $1.activity
            }
            .map(\.project)
    }

    private var liveProjects: [Project] {
        activeProjects.filter { !$0.isHidden }
    }

    private var unlockedProjectID: UUID? {
        FeatureGate.unlockedProjectID(
            isPro: store.isPro,
            projects: activeProjects.map { (id: $0.id, createdAt: $0.createdAt) }
        )
    }

    private func isLocked(_ project: Project) -> Bool {
        guard !store.isPro else { return false }
        return project.id != unlockedProjectID
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            if liveProjects.isEmpty && visibleJobs.isEmpty {
                EmptyProjectsView(onCreate: addProjectTapped, onImport: importTapped)
            } else {
                List {
                    ForEach(visibleJobs) { job in
                        Button {
                            openJob(job)
                        } label: {
                            exportJobRow(job)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    ForEach(liveProjects) { project in
                        ProjectCard(project: project, isFeatured: project.id == liveProjects.first?.id)
                                .overlay {
                                    if isLocked(project) {
                                        Button {
                                            activeSheet = .paywall
                                        } label: {
                                            ZStack {
                                                Color.black.opacity(0.45)
                                                VStack(spacing: 8) {
                                                    Image(systemName: "lock.fill")
                                                        .font(.system(size: 26, weight: .semibold))
                                                    Text("Pro ile aç")
                                                        .font(Theme.headline(15))
                                                }
                                                .foregroundStyle(.white)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    } else {
                                        NavigationLink {
                                            ProjectDetailView(project: project)
                                        } label: {
                                            Color.clear
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .opacity(0)
                                    }
                                }
                                .contextMenu {
                                    Button {
                                        DeferredMenuAction.perform {
                                            try? ProjectRepository(context: modelContext).setHidden(true, for: project)
                                        }
                                    } label: {
                                        Label("Gizle", systemImage: "eye.slash")
                                    }
                                    Button(role: .destructive) {
                                        DeferredMenuAction.perform { pendingDeletion = [project] }
                                    } label: {
                                        Label("Sil", systemImage: "trash")
                                    }
                                }
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("projectCard-\(project.title)")
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("Projeler")
        .toolbar {
            ToolbarItem(placement: .primaryAction) { importButton }
            ToolbarItem(placement: .primaryAction) { addButton }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addProject:
                AddProjectSheet(repository: ProjectRepository(context: modelContext))
            case .importNew:
                PhotoImportSheet(
                    mode: .newProject,
                    repository: ProjectRepository(context: modelContext),
                    maxSelection: store.isPro ? nil : FeatureGate.freeEntryLimit,
                    onFinished: { _ in activeSheet = nil }
                )
            case .paywall:
                PaywallView(store: store)
            case .signIn:
                SignInGateSheet {
                    continuePendingAction()
                } onSkip: {
                    signInGateSkipped = true
                    continuePendingAction()
                }
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
        .sheet(item: $resumeExportProject, onDismiss: discardCheckedJob) { project in
            TimelapseExportSheet(project: project)
        }
    }

    private var importButton: some View {
        Button {
            importTapped()
        } label: {
            toolbarIcon("photo.on.rectangle.angled")
        }
        .accessibilityIdentifier("importProjectButton")
        .accessibilityLabel(Text("Fotoğraflardan proje oluştur"))
    }

    private var addButton: some View {
        Button {
            addProjectTapped()
        } label: {
            toolbarIcon("plus")
        }
        .accessibilityIdentifier("addProjectButton")
        .accessibilityLabel(Text("Yeni proje"))
    }

    private func toolbarIcon(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .fontWeight(.medium)
            .foregroundStyle(theme.accent)
            .frame(width: 21, height: 21)
            .frame(width: 30, height: 30, alignment: .center)
    }

    private var visibleJobs: [TimelapseRenderService.Job] {
        (renderService.activeJobs + renderService.finishedJobs)
            .filter { job in liveProjects.contains { $0.id == job.id } }
    }

    private func openJob(_ job: TimelapseRenderService.Job) {
        guard let project = projects.first(where: { $0.id == job.id }) else { return }
        checkedJobID = job.id
        resumeExportProject = project
    }

    private func discardCheckedJob() {
        guard let id = checkedJobID else { return }
        checkedJobID = nil
        let isFinished = renderService.finishedJobs.contains { $0.id == id }
        if isFinished {
            renderService.discard(projectID: id)
        }
    }

    private func exportJobRow(_ job: TimelapseRenderService.Job) -> some View {
        HStack(spacing: 12) {
            if job.viewModel.phase == .rendering {
                ProgressView().tint(theme.accent)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text(job.viewModel.phase == .rendering ? "Timelapse oluşturuluyor…" : "Timelapse hazır, dokun")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .padding(14)
        .liquidGlassStyle(cornerRadius: 18)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityIdentifier("resumeExportBanner-\(job.title)")
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
                try? repository.softDeleteProject(project)
            }
        }
    }

    private func continuePendingAction() {
        let next = pendingAfterSignIn
        pendingAfterSignIn = nil
        guard let next else { return }
        Task {
            try? await Task.sleep(for: .seconds(0.45))
            switch next {
            case .addProject: addProjectTapped()
            case .importNew: importTapped()
            default: break
            }
        }
    }

    private func addProjectTapped() {
        guard AuthService.isSignedInNow || signInGateSkipped else {
            pendingAfterSignIn = .addProject
            activeSheet = .signIn
            return
        }
        if FeatureGate.canCreateProject(isPro: store.isPro, currentProjectCount: activeProjects.count) {
            activeSheet = .addProject
        } else {
            activeSheet = .paywall
        }
    }

    private func importTapped() {
        guard AuthService.isSignedInNow || signInGateSkipped else {
            pendingAfterSignIn = .importNew
            activeSheet = .signIn
            return
        }
        if store.isPro || FeatureGate.canCreateProject(isPro: false, currentProjectCount: activeProjects.count) {
            activeSheet = .importNew
        } else {
            activeSheet = .paywall
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        pendingDeletion = offsets.compactMap { index in
            liveProjects.indices.contains(index) ? liveProjects[index] : nil
        }
    }
}

/// Büyük foto-kahraman kartı: projenin son karesi arka plan olur; üstüne okunabilirlik
/// için koyu geçiş, başlık ve ilerleme biner. Fotoğraf yoksa kategori rengine düşer.
private struct ProjectCard: View {
    let project: Project
    let isFeatured: Bool

    @Environment(\.theme) private var theme
    @State private var photo: UIImage?

    private var accent: Color { Theme.accent(for: project.category) }

    var body: some View {
        let entries = (project.entries ?? []).filter { !$0.isDeleted && $0.deletedAt == nil }
        let last = entries.max { $0.capturedAt < $1.capturedAt }
        let count = entries.count
        let streak = ActivitySummary.streak(capturedDates: entries.map(\.capturedAt))
        let isDue = project.cadence.isCaptureDue(lastCapture: last?.capturedAt)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Image(systemName: Theme.icon(for: project.category))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.28), in: Circle())
                Spacer()
                if streak > 0 {
                    streakBadge(streak)
                }
                if isDue {
                    Text("Bugün")
                        .font(Theme.caption(12))
                        .fontWeight(.semibold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(.white, in: Capsule())
                }
            }

            Spacer(minLength: 12)

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(Theme.headline(isFeatured ? 28 : 24))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text("\(count)")
                            .monospacedDigit()
                            .fontWeight(.semibold)
                        Text("kare · \(project.cadence.displayName)")
                    }
                    .font(Theme.caption(13))
                    .foregroundStyle(.white.opacity(0.88))
                }
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.78))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.9), in: Circle())
            }
        }
        .padding(isFeatured ? 20 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isFeatured ? 260 : 198)
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
        .shadow(color: .black.opacity(isFeatured ? 0.16 : 0.11), radius: isFeatured ? 18 : 12, x: 0, y: isFeatured ? 9 : 6)
        .overlay {
            if streak > 0 {
                FireStreakBorder(cornerRadius: 24)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .task(id: last?.imageCacheKey) {
            guard let last else { return }
            photo = await ImageDownsampler.cachedImage(key: "card-\(last.imageCacheKey)", maxPixelSize: 800) { last.imageData }
        }
    }

    private func streakBadge(_ streak: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill").font(.system(size: 11, weight: .semibold))
            Text("\(streak)").font(.system(size: 13, weight: .bold)).monospacedDigit()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.black.opacity(0.28), in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
    }
}

private struct FireStreakBorder: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isMoving = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color.orange.opacity(0.55),
                        Color.orange,
                        Color.yellow.opacity(0.78),
                        Color.orange.opacity(0.55)
                    ],
                    center: .center,
                    startAngle: .degrees(isMoving && !reduceMotion ? 360 : 0),
                    endAngle: .degrees(isMoving && !reduceMotion ? 720 : 360)
                ),
                lineWidth: 2
            )
            .animation(reduceMotion ? nil : .linear(duration: 7).repeatForever(autoreverses: false), value: isMoving)
            .allowsHitTesting(false)
            .onAppear { isMoving = true }
            .onDisappear { isMoving = false }
    }
}

private struct EmptyProjectsView: View {
    let onCreate: () -> Void
    let onImport: () -> Void

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
                    .font(Theme.headline(26))
                    .foregroundStyle(theme.ink)
                Text("Günde bir kare çek; zamanla değişimin\nkendiliğinden bir timelapse'e dönüşsün.")
                    .font(Theme.body(16))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onCreate) {
                Label("Yeni Proje", systemImage: "plus")
                    .font(Theme.headline(17))
            }
            .buttonStyle(.flapsePrimary)
            .frame(maxWidth: 260)
            .padding(.top, 4)

            Button(action: onImport) {
                Label("Fotoğraflardan proje oluştur", systemImage: "photo.on.rectangle.angled")
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(theme.accent)
            .frame(minHeight: 44)

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

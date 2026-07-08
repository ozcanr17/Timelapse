import SwiftUI
import SwiftData

struct RecentlyDeletedView: View {

    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var pendingErase: Project?

    private var deletedProjects: [Project] {
        projects
            .filter { !$0.isDeleted && $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var body: some View {
        List {
            if deletedProjects.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 30))
                            .foregroundStyle(theme.inkMuted)
                        Text("Silinen proje yok")
                            .font(Theme.headline(15))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                }
            } else {
                Section {
                    ForEach(deletedProjects) { project in
                        row(project)
                    }
                } footer: {
                    Text("Silinen projeler 30 gün saklanır, sonra kalıcı olarak silinir. iCloud yedekleme açıksa bu süre boyunca iCloud'da da saklanırlar.")
                }
            }
        }
        .navigationTitle("Son Silinenler")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Proje ve içindeki tüm çekimler kalıcı olarak silinsin mi?",
            isPresented: eraseBinding,
            titleVisibility: .visible
        ) {
            Button("Kalıcı Olarak Sil", role: .destructive) { confirmErase() }
            Button("Vazgeç", role: .cancel) { pendingErase = nil }
        }
    }

    private func row(_ project: Project) -> some View {
        HStack(spacing: 12) {
            Image(systemName: Theme.icon(for: project.category))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent(for: project.category))
                .frame(width: 38, height: 38)
                .background(Theme.accent(for: project.category).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text("\(daysRemaining(for: project)) gün sonra kalıcı olarak silinecek")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Button("Geri Al") { restore(project) }
                .font(Theme.caption(13))
                .buttonStyle(.bordered)
                .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingErase = project
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button { restore(project) } label: {
                Label("Geri Al", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                pendingErase = project
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
    }

    private func daysRemaining(for project: Project) -> Int {
        guard let deletedAt = project.deletedAt else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day ?? 0
        return max(0, 30 - elapsed)
    }

    private var eraseBinding: Binding<Bool> {
        Binding(
            get: { pendingErase != nil },
            set: { if !$0 { pendingErase = nil } }
        )
    }

    private func restore(_ project: Project) {
        let repository = ProjectRepository(context: modelContext)
        withAnimation { try? repository.restoreProject(project) }
    }

    private func confirmErase() {
        guard let project = pendingErase else { return }
        pendingErase = nil
        let repository = ProjectRepository(context: modelContext)
        withAnimation {
            try? repository.deleteProject(project)
            try? repository.saveIfNeeded()
        }
    }
}

#Preview {
    NavigationStack { RecentlyDeletedView() }
        .modelContainer(AppModelContainer.makeInMemory())
}

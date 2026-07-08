import SwiftUI
import SwiftData

/// Silinen projeler canlı SwiftData modelleri yerine değer kopyaları (snapshot) üzerinden
/// listelenir; böylece kalıcı silme sırasında görünüm, bağlamdan kopmuş bir modele
/// dokunup çökmez.
struct RecentlyDeletedView: View {

    private struct DeletedItem: Identifiable, Equatable {
        let id: UUID
        let title: String
        let category: ProjectCategory
        let daysRemaining: Int
    }

    @Query private var projects: [Project]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var pendingEraseID: UUID?

    private var deletedItems: [DeletedItem] {
        projects
            .filter { !$0.isDeleted && $0.deletedAt != nil }
            .sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
            .map { project in
                let elapsed = Calendar.current.dateComponents(
                    [.day], from: project.deletedAt ?? Date(), to: Date()
                ).day ?? 0
                return DeletedItem(
                    id: project.id,
                    title: project.title,
                    category: project.category,
                    daysRemaining: max(0, 30 - elapsed)
                )
            }
    }

    var body: some View {
        List {
            if deletedItems.isEmpty {
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
                    ForEach(deletedItems) { item in
                        row(item)
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
            Button("Vazgeç", role: .cancel) { pendingEraseID = nil }
        }
    }

    private func row(_ item: DeletedItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: Theme.icon(for: item.category))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.accent(for: item.category))
                .frame(width: 38, height: 38)
                .background(Theme.accent(for: item.category).opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text("\(item.daysRemaining) gün sonra kalıcı olarak silinecek")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Button("Geri Al") { restore(item.id) }
                .font(Theme.caption(13))
                .buttonStyle(.bordered)
                .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingEraseID = item.id
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button { restore(item.id) } label: {
                Label("Geri Al", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                pendingEraseID = item.id
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
    }

    private var eraseBinding: Binding<Bool> {
        Binding(
            get: { pendingEraseID != nil },
            set: { if !$0 { pendingEraseID = nil } }
        )
    }

    private func fetchProject(_ id: UUID) -> Project? {
        let descriptor = FetchDescriptor<Project>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func restore(_ id: UUID) {
        guard let project = fetchProject(id) else { return }
        let repository = ProjectRepository(context: modelContext)
        try? repository.restoreProject(project)
    }

    private func confirmErase() {
        guard let id = pendingEraseID else { return }
        pendingEraseID = nil
        guard let project = fetchProject(id) else { return }
        let repository = ProjectRepository(context: modelContext)
        try? repository.deleteProject(project)
        try? repository.saveIfNeeded()
    }
}

#Preview {
    NavigationStack { RecentlyDeletedView() }
        .modelContainer(AppModelContainer.makeInMemory())
}

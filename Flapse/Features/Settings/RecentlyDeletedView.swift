import SwiftUI
import SwiftData
import UIKit

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

    private struct DeletedPhotoItem: Identifiable, Equatable {
        let id: UUID
        let projectTitle: String
        let capturedAt: Date
        let daysRemaining: Int
    }

    @Query(filter: #Predicate<Project> { $0.deletedAt != nil }) private var projects: [Project]
    @Query(filter: #Predicate<Entry> { $0.deletedAt != nil }, sort: \Entry.deletedAt, order: .reverse)
    private var deletedPhotos: [Entry]
    @Query(filter: #Predicate<SavedTimelapse> { $0.deletedAt != nil }, sort: \SavedTimelapse.deletedAt, order: .reverse)
    private var deletedTimelapses: [SavedTimelapse]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var pendingEraseID: UUID?
    @State private var pendingPhotoEraseID: UUID?
    @State private var pendingTimelapseEraseID: UUID?

    private var deletedItems: [DeletedItem] {
        projects
            .filter { !$0.isDeleted }
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

    private var deletedPhotoItems: [DeletedPhotoItem] {
        deletedPhotos
            .filter { !$0.isDeleted && $0.project?.deletedAt == nil }
            .map { entry in
                let elapsed = Calendar.current.dateComponents(
                    [.day], from: entry.deletedAt ?? Date(), to: Date()
                ).day ?? 0
                return DeletedPhotoItem(
                    id: entry.id,
                    projectTitle: entry.project?.title ?? String(localized: "Proje", bundle: .appLanguage),
                    capturedAt: entry.capturedAt,
                    daysRemaining: max(0, 30 - elapsed)
                )
            }
    }

    var body: some View {
        List {
            if deletedItems.isEmpty && deletedPhotoItems.isEmpty && deletedTimelapses.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "trash")
                            .font(.system(size: 30))
                            .foregroundStyle(theme.inkMuted)
                        Text("Silinen öğe yok")
                            .font(Theme.headline(15))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .listRowBackground(Color.clear)
                }
            }
            if !deletedItems.isEmpty {
                Section {
                    ForEach(deletedItems) { item in
                        row(item)
                    }
                } header: {
                    Text("Projeler")
                } footer: {
                    Text("Silinen projeler 30 gün saklanır, sonra kalıcı olarak silinir. iCloud yedekleme açıksa bu süre boyunca iCloud'da da saklanırlar.")
                }
            }
            if !deletedPhotoItems.isEmpty {
                Section {
                    ForEach(deletedPhotoItems) { item in
                        photoRow(item)
                    }
                } header: {
                    Text("Fotoğraflar")
                } footer: {
                    Text("Silinen fotoğraflar 30 gün saklanır, sonra kalıcı olarak silinir.")
                }
            }
            if !deletedTimelapses.isEmpty {
                Section {
                    ForEach(deletedTimelapses) { item in
                        timelapseRow(item)
                    }
                } header: {
                    Text("Timelapse'ler")
                } footer: {
                    Text("Silinen timelapse'ler 7 gün saklanır, sonra kalıcı olarak silinir.")
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
        .confirmationDialog(
            "Bu çekim kalıcı olarak silinsin mi?",
            isPresented: photoEraseBinding,
            titleVisibility: .visible
        ) {
            Button("Kalıcı Olarak Sil", role: .destructive) { confirmPhotoErase() }
            Button("Vazgeç", role: .cancel) { pendingPhotoEraseID = nil }
        }
        .confirmationDialog(
            "Bu timelapse kalıcı olarak silinsin mi?",
            isPresented: timelapseEraseBinding,
            titleVisibility: .visible
        ) {
            Button("Kalıcı Olarak Sil", role: .destructive) { confirmTimelapseErase() }
            Button("Vazgeç", role: .cancel) { pendingTimelapseEraseID = nil }
        }
    }

    private func timelapseRow(_ item: SavedTimelapse) -> some View {
        let elapsed = Calendar.current.dateComponents(
            [.day], from: item.deletedAt ?? Date(), to: Date()
        ).day ?? 0
        let daysRemaining = max(0, TimelapseLibrary.retentionDays - elapsed)
        return HStack(spacing: 12) {
            Image(systemName: "film.stack")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 38, height: 38)
                .background(theme.accent.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text("\(daysRemaining) gün sonra kalıcı olarak silinecek")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Button("Geri Al") { TimelapseLibrary.restore(item, context: modelContext) }
                .font(Theme.caption(13))
                .buttonStyle(.bordered)
                .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingTimelapseEraseID = item.id
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
    }

    private func photoRow(_ item: DeletedPhotoItem) -> some View {
        HStack(spacing: 12) {
            DeletedPhotoThumbnail(entryID: item.id)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.projectTitle)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                Text(item.capturedAt, format: .dateTime.day().month().year())
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
                Text("\(item.daysRemaining) gün sonra kalıcı olarak silinecek")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Button("Geri Al") { restorePhoto(item.id) }
                .font(Theme.caption(13))
                .buttonStyle(.bordered)
                .tint(theme.accent)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                pendingPhotoEraseID = item.id
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
        .contextMenu {
            Button { restorePhoto(item.id) } label: {
                Label("Geri Al", systemImage: "arrow.uturn.backward")
            }
            Button(role: .destructive) {
                pendingPhotoEraseID = item.id
            } label: {
                Label("Kalıcı Olarak Sil", systemImage: "trash.fill")
            }
        }
    }

    private var photoEraseBinding: Binding<Bool> {
        Binding(
            get: { pendingPhotoEraseID != nil },
            set: { if !$0 { pendingPhotoEraseID = nil } }
        )
    }

    private func fetchEntry(_ id: UUID) -> Entry? {
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == id })
        return try? modelContext.fetch(descriptor).first
    }

    private func restorePhoto(_ id: UUID) {
        guard let entry = fetchEntry(id) else { return }
        try? ProjectRepository(context: modelContext).restoreEntry(entry)
    }

    private func confirmPhotoErase() {
        guard let id = pendingPhotoEraseID else { return }
        pendingPhotoEraseID = nil
        guard let entry = fetchEntry(id) else { return }
        try? ProjectRepository(context: modelContext).permanentlyDeleteEntry(entry)
    }

    private var timelapseEraseBinding: Binding<Bool> {
        Binding(
            get: { pendingTimelapseEraseID != nil },
            set: { if !$0 { pendingTimelapseEraseID = nil } }
        )
    }

    private func confirmTimelapseErase() {
        guard let id = pendingTimelapseEraseID else { return }
        pendingTimelapseEraseID = nil
        guard let item = deletedTimelapses.first(where: { $0.id == id }) else { return }
        TimelapseLibrary.delete(item, context: modelContext)
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

private struct DeletedPhotoThumbnail: View {
    let entryID: UUID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
        }
        .frame(width: 52, height: 52)
        .background(theme.accent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .task(id: entryID) {
            let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.id == entryID })
            guard let entry = try? modelContext.fetch(descriptor).first else { return }
            image = await ImageDownsampler.cachedImage(
                key: "deleted-\(entry.imageCacheKey)",
                maxPixelSize: 160,
                load: { entry.imageData }
            )
        }
    }
}

#Preview {
    NavigationStack { RecentlyDeletedView() }
        .modelContainer(AppModelContainer.makeInMemory())
}

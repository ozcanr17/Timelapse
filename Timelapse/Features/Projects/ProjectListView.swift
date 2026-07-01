import SwiftUI
import SwiftData

/// Projeleri listeleyen ana ekran.
struct ProjectListView: View {

    // Reaktif okuma: SwiftData değiştikçe (yerel ekleme VEYA CloudKit senkronu) liste
    // kendiliğinden güncellenir. Sıralamayı doğrudan sorgunun içinde belirtiyoruz.
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    // Container'ın enjekte ettiği paylaşılan context. Yazma işlemlerinde bunu kullanıyoruz
    // ki @Query yaptığımız değişikliği görebilsin.
    @Environment(\.modelContext) private var modelContext

    // App tarafından .environment(store) ile enjekte edilen mağaza; Pro durumunu buradan okuyoruz.
    @Environment(StoreService.self) private var store

    @State private var activeSheet: ActiveSheet?

    // Tek anda tek sheet gösterebildiğimiz için, hangisinin açılacağını bir enum belirler.
    private enum ActiveSheet: Identifiable {
        case addProject
        case paywall
        var id: Int { hashValue }
    }

    var body: some View {
        List {
            if projects.isEmpty {
                ContentUnavailableView(
                    "Henüz proje yok",
                    systemImage: "camera.on.rectangle",
                    description: Text("Sağ üstteki + ile ilk takip projeni oluştur.")
                )
            } else {
                ForEach(projects) { project in
                    NavigationLink {
                        ProjectDetailView(project: project)
                    } label: {
                        ProjectRow(project: project)
                    }
                }
                .onDelete(perform: deleteProjects)
            }
        }
        .navigationTitle("Projeler")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addProjectTapped()
                } label: {
                    Label("Yeni proje", systemImage: "plus")
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

    // Kapı mantığı: kurallar FeatureGate'te, karar burada. Ücretsiz limiti aşıyorsa paywall.
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

/// Listedeki tek bir satır. Görünümleri küçük parçalara bölmek SwiftUI'da iyi alışkanlıktır.
private struct ProjectRow: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(project.title)
                .font(.headline)

            HStack(spacing: 6) {
                Text(project.category.displayName)
                Text("·")
                Text("\(project.sortedEntries.count) çekim")
                if project.isCaptureDue() {
                    Text("· bugün çekim zamanı")
                        .foregroundStyle(.tint)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ProjectListView()
    }
    .modelContainer(AppModelContainer.makeInMemory())
    .environment(StoreService())
}

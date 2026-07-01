import SwiftUI
import SwiftData

/// Uygulamanın kök görünümü. Tek görevi, ana ekranı (proje listesi) bir
/// NavigationStack içine koymak — böylece başlık çubuğu ve gezinme çalışır.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            ProjectListView()
        }
    }
}

#Preview {
    // Önizleme de tıpkı testler gibi bellek içi (disksiz, Cloud'suz) container kullanır.
    ContentView()
        .modelContainer(AppModelContainer.makeInMemory())
        .environment(StoreService())
}

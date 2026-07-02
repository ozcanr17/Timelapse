import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ProjectListView()
        }
        .tint(Theme.rust)
    }
}

#Preview {
    ContentView()
        .modelContainer(AppModelContainer.makeInMemory())
        .environment(StoreService())
}

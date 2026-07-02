import SwiftUI
import SwiftData

struct ContentView: View {

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        NavigationStack {
            ProjectListView()
        }
        .tint(Theme.rust)
        .fullScreenCover(isPresented: needsWelcome) {
            WelcomeView { hasSeenWelcome = true }
        }
    }

    private var needsWelcome: Binding<Bool> {
        Binding(
            get: { !hasSeenWelcome },
            set: { hasSeenWelcome = !$0 }
        )
    }
}

#Preview {
    ContentView()
        .modelContainer(AppModelContainer.makeInMemory())
        .environment(StoreService())
}

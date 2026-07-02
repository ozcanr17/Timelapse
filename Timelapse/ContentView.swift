import SwiftUI
import SwiftData

struct ContentView: View {

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.filmNegative.rawValue

    private var appTheme: AppTheme {
        AppTheme(rawValue: themeID) ?? .filmNegative
    }

    var body: some View {
        NavigationStack {
            ProjectListView()
        }
        .fullScreenCover(isPresented: needsWelcome) {
            WelcomeView { hasSeenWelcome = true }
        }
        .tint(appTheme.palette.accent)
        .environment(\.theme, appTheme.palette)
        .preferredColorScheme(appTheme.preferredColorScheme)
        .animation(.easeInOut(duration: 0.25), value: themeID)
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

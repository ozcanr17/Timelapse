import SwiftUI
import SwiftData

struct ContentView: View {

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.filmNegative.rawValue

    @State private var isShowingSplash = true

    private var appTheme: AppTheme {
        AppTheme(rawValue: themeID) ?? .filmNegative
    }

    var body: some View {
        ZStack {
            NavigationStack {
                ProjectListView()
            }

            if isShowingSplash && hasSeenWelcome {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .fullScreenCover(isPresented: needsWelcome) {
            WelcomeView { hasSeenWelcome = true }
        }
        .tint(appTheme.palette.accent)
        .environment(\.theme, appTheme.palette)
        .preferredColorScheme(appTheme.preferredColorScheme)
        .animation(.easeInOut(duration: 0.25), value: themeID)
        .task {
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.4)) { isShowingSplash = false }
        }
    }

    private var needsWelcome: Binding<Bool> {
        Binding(
            get: { !hasSeenWelcome },
            set: { hasSeenWelcome = !$0 }
        )
    }
}

private struct LaunchSplashView: View {

    @Environment(\.theme) private var theme
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            VStack(spacing: 20) {
                LogoMark(size: 108)
                    .rotationEffect(.degrees(isAnimating ? 0 : -120))
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .opacity(isAnimating ? 1 : 0)

                Text("Timelapse")
                    .font(Theme.headline(24))
                    .foregroundStyle(theme.ink)
                    .opacity(isAnimating ? 1 : 0)
            }
            .animation(.spring(response: 0.8, dampingFraction: 0.7), value: isAnimating)
        }
        .onAppear { isAnimating = true }
    }
}

#Preview {
    ContentView()
        .modelContainer(AppModelContainer.makeInMemory())
        .environment(StoreService())
}

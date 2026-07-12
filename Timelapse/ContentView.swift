import SwiftUI
import SwiftData
import CloudKit

struct ContentView: View {

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage(AppTheme.storageKey) private var themeID = AppTheme.filmNegative.rawValue
    @AppStorage(AppLanguage.storageKey) private var languageID = AppLanguage.system.rawValue

    @Environment(\.modelContext) private var modelContext
    @State private var isShowingSplash = true
    @State private var milestoneMessage: String?

    private var appTheme: AppTheme {
        AppTheme(rawValue: themeID) ?? .filmNegative
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: languageID) ?? .system
    }

    var body: some View {
        ZStack {
            MainTabView()

            if isShowingSplash && hasSeenWelcome {
                LaunchSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }

            if let milestoneMessage {
                VStack {
                    Text(milestoneMessage)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.orange.gradient, in: Capsule())
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .fullScreenCover(isPresented: needsWelcome) {
            WelcomeView { hasSeenWelcome = true }
        }
        .tint(appTheme.palette.accent)
        .environment(\.theme, appTheme.palette)
        .preferredColorScheme(appTheme.preferredColorScheme)
        .animation(.easeInOut(duration: 0.25), value: themeID)
        .environment(\.locale, appLanguage.localeIdentifier.map(Locale.init(identifier:)) ?? .autoupdatingCurrent)
        .environment(\.layoutDirection, appLanguage.isRightToLeft ? .rightToLeft : (appLanguage == .system ? (Locale.Language(identifier: Locale.preferredLanguages.first ?? "en").characterDirection == .rightToLeft ? .rightToLeft : .leftToRight) : .leftToRight))
        .id(languageID)
        .onChange(of: languageID) {
            LanguageOverrideBundle.apply(appLanguage)
        }
        .task {
            try? ProjectRepository(context: modelContext).purgeExpiredProjects(retentionDays: 30, now: Date())
            TimelapseLibrary.purgeExpired(context: modelContext)
            WidgetStateWriter.update(projects: (try? modelContext.fetch(FetchDescriptor<Project>())) ?? [])
            try? await Task.sleep(for: .seconds(1.3))
            withAnimation(.easeOut(duration: 0.4)) { isShowingSplash = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flapseMilestone)) { notification in
            guard let message = notification.object as? String else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { milestoneMessage = message }
            Task {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut(duration: 0.3)) { milestoneMessage = nil }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .flapseDidAcceptShare)) { notification in
            guard let metadata = notification.object as? CKShare.Metadata else { return }
            Task { await importSharedProject(metadata) }
        }
    }

    /// Davet kabul edilince paylaşılan projeyi (önceki kareleriyle birlikte) yerel
    /// kütüphaneye indirir. Aynı paylaşım daha önce indirildiyse yinelenmez.
    private func importSharedProject(_ metadata: CKShare.Metadata) async {
        guard let snapshot = try? await SharedProjectService.shared.fetchSharedProject(metadata) else { return }

        let shareName = snapshot.shareRecordName
        let descriptor = FetchDescriptor<Project>(
            predicate: #Predicate { $0.cloudShareRecordName == shareName }
        )
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty { return }

        let repository = ProjectRepository(context: modelContext)
        guard let project = try? repository.createProject(
            title: snapshot.title,
            category: ProjectCategory(rawValue: snapshot.categoryRaw) ?? .other,
            cadence: CaptureCadence(rawValue: snapshot.cadenceRaw) ?? .daily
        ) else { return }
        project.isCollaborative = true
        project.cloudShareRecordName = snapshot.shareRecordName

        let entries = snapshot.entries.map { Entry(capturedAt: $0.capturedAt, imageData: $0.data) }
        try? repository.addEntries(entries, to: project)
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
            AnimatedAccentBackground(base: theme.accent)
                .opacity(isAnimating ? 0.16 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                LogoMark(size: 108)
                    .rotationEffect(.degrees(isAnimating ? 0 : -120))
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .opacity(isAnimating ? 1 : 0)

                Text("Flapse")
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

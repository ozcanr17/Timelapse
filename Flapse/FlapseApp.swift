import SwiftUI
import SwiftData

@main
struct FlapseApp: App {

    @UIApplicationDelegateAdaptor(FlapseAppDelegate.self) private var appDelegate

    let container: ModelContainer

    init() {
        LanguageOverrideBundle.activate()
        CloudBackupPreference.prepareForLaunch()
        let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitests")
            || ProcessInfo.processInfo.environment["FLAPSE_UI_TESTS"] == "1"
        container = isUITesting
            ? AppModelContainer.makeInMemory()
            : AppModelContainer.makeProduction()
    }

    @State private var store = StoreService()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task {
                    await store.loadProducts()
                    await store.refreshEntitlements()
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                let projects = (try? container.mainContext.fetch(FetchDescriptor<Project>())) ?? []
                ReminderScheduler.shared.sync(projects: projects)
                WidgetStateWriter.update(projects: projects)
            } else if phase == .active {
                NotificationCenter.default.post(name: .flapseCloudKitChanged, object: nil)
            }
        }
    }

}

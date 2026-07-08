import SwiftUI
import SwiftData

@main
struct TimelapseApp: App {

    @UIApplicationDelegateAdaptor(FlapseAppDelegate.self) private var appDelegate

    let container = AppModelContainer.makeProduction()

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
            }
        }
    }
}

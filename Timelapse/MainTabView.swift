import SwiftUI
import SwiftData

struct MainTabView: View {

    enum Tab: Hashable {
        case home, projects, saved, settings
    }

    @State private var tab: Tab = .home
    @Environment(StoreService.self) private var store
    @Environment(\.theme) private var theme
    @Query(filter: #Predicate<Project> { $0.deletedAt == nil }, sort: \Project.createdAt, order: .reverse)
    private var projects: [Project]

    @State private var showQuickPick = false
    @State private var pendingCapture: Project?
    @State private var captureRoute: CaptureRoute?
    @State private var showPaywall = false
    @State private var previewIndex: Int?
    @State private var itemFrames: [Int: CGRect] = [:]
    @State private var highlightX: CGFloat = 0
    @State private var highlightWidth: CGFloat = 0
    @State private var isDraggingBar = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let barTint = Color(light: "F5F5F7", dark: "0B0B0D").opacity(0.32)
    private static let highlightTint = Color(light: "3C3C43", dark: "FFFFFF").opacity(0.13)
    private static let activeIconColor = Color(light: "1C1C1E", dark: "FFFFFF")
    private static let idleIconColor = Color(light: "1C1C1E", dark: "FFFFFF").opacity(0.55)

    private enum CaptureRoute: Identifiable {
        case project(Project)
        case auto
        var id: String {
            switch self {
            case .project(let project): project.id.uuidString
            case .auto: "auto"
            }
        }
    }

    private var liveProjects: [Project] {
        projects.filter { !$0.isDeleted && $0.deletedAt == nil }
    }

    private var unlockedProjectID: UUID? {
        FeatureGate.unlockedProjectID(
            isPro: store.isPro,
            projects: liveProjects.map { (id: $0.id, createdAt: $0.createdAt) }
        )
    }

    private var capturableProjects: [Project] {
        guard !store.isPro else { return liveProjects }
        return liveProjects.filter { $0.id == unlockedProjectID }
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            pane(.home) { HomeView() }
            pane(.projects) { ProjectListView() }
            pane(.saved) { SavedTimelapsesView() }
            pane(.settings) { SettingsView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            tabBar
        }
        .sheet(isPresented: $showQuickPick, onDismiss: presentPendingCapture) {
            QuickCaptureSheet(projects: capturableProjects) { project in
                pendingCapture = project
                showQuickPick = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $captureRoute) { route in
            switch route {
            case .project(let project):
                CameraCaptureView(project: project)
            case .auto:
                AutoCaptureFlow(projects: capturableProjects)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
    }

    private func pane<Content: View>(_ target: Tab, @ViewBuilder content: () -> Content) -> some View {
        NavigationStack {
            content()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .contentMargins(.bottom, 40, for: .scrollContent)
        .opacity(tab == target ? 1 : 0)
        .allowsHitTesting(tab == target)
        .accessibilityHidden(tab != target)
    }

    private struct BarItem {
        let tab: Tab?
        let icon: String
        let activeIcon: String
        let label: LocalizedStringKey
        let identifier: String
    }

    private var barItems: [BarItem] {
        [
            BarItem(tab: .home, icon: "house", activeIcon: "house.fill", label: "Ana Sayfa", identifier: "homeTab"),
            BarItem(tab: .projects, icon: "square.grid.2x2", activeIcon: "square.grid.2x2.fill", label: "Projeler", identifier: "projectsTab"),
            BarItem(tab: nil, icon: "camera.fill", activeIcon: "camera.fill", label: "Kare çek", identifier: "homeCaptureButton"),
            BarItem(tab: .saved, icon: "film.stack", activeIcon: "film.stack.fill", label: "Kaydedilenler", identifier: "savedTab"),
            BarItem(tab: .settings, icon: "gearshape", activeIcon: "gearshape.fill", label: "Ayarlar", identifier: "settingsButton")
        ]
    }

    private struct ItemFramePreference: PreferenceKey {
        static let defaultValue: [Int: CGRect] = [:]
        static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
            value.merge(nextValue()) { _, new in new }
        }
    }

    @ViewBuilder
    private var tabBar: some View {
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 18) { tabBarContent }
            } else {
                tabBarContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .offset(y: 12)
    }

    private var tabBarContent: some View {
        ZStack(alignment: .topLeading) {
            if highlightWidth > 0 {
                Capsule()
                    .fill(.clear)
                    .frame(width: highlightWidth, height: 46)
                    .liquidGlassCapsule(tint: Self.highlightTint, interactive: true)
                    .offset(x: highlightX, y: 6)
                    .animation(
                        reduceMotion ? nil :
                            isDraggingBar
                            ? .spring(response: 0.24, dampingFraction: 0.82)
                            : .spring(response: 0.4, dampingFraction: 0.62),
                        value: highlightX
                    )
            }

            HStack(spacing: 0) {
                ForEach(Array(barItems.enumerated()), id: \.element.identifier) { index, item in
                    barItemView(item, index: index)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .coordinateSpace(name: "tabBarSpace")
        .liquidGlassCapsule(tint: Self.barTint)
        .contentShape(Capsule())
        .onPreferenceChange(ItemFramePreference.self) { frames in
            itemFrames = frames
            if !isDraggingBar, let frame = frames[currentIndex] {
                highlightX = frame.minX
                highlightWidth = frame.width
            }
        }
        .gesture(slideToSelect)
        .sensoryFeedback(.selection, trigger: previewIndex)
        .sensoryFeedback(.impact(weight: .light), trigger: tab)
        .animation(reduceMotion ? nil : .smooth(duration: 0.2), value: previewIndex)
        .accessibilityElement(children: .contain)
    }

    private var currentIndex: Int {
        barItems.firstIndex { $0.tab == tab } ?? 0
    }

    private var slideToSelect: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("tabBarSpace"))
            .onChanged { value in
                isDraggingBar = true
                let index = itemIndex(at: value.location.x)
                previewIndex = index
                if let frame = itemFrames[index] {
                    highlightWidth = frame.width
                    highlightX = frame.minX
                }
            }
            .onEnded { value in
                let index = itemIndex(at: value.location.x)
                previewIndex = nil
                isDraggingBar = false
                let item = barItems[index]
                let restingIndex = item.tab == nil ? currentIndex : index
                if let frame = itemFrames[restingIndex] {
                    highlightX = frame.minX
                    highlightWidth = frame.width
                }
                activate(item)
            }
    }

    private func itemIndex(at x: CGFloat) -> Int {
        guard !itemFrames.isEmpty else { return 0 }
        let nearest = itemFrames.min { lhs, rhs in
            abs(lhs.value.midX - x) < abs(rhs.value.midX - x)
        }
        return nearest?.key ?? 0
    }

    private func activate(_ item: BarItem) {
        if let target = item.tab {
            tab = target
            if let index = barItems.firstIndex(where: { $0.identifier == item.identifier }),
               let frame = itemFrames[index] {
                highlightX = frame.minX
                highlightWidth = frame.width
            }
        } else {
            captureTapped()
        }
    }

    private func barItemView(_ item: BarItem, index: Int) -> some View {
        let isCamera = item.tab == nil
        let isActive = item.tab != nil && item.tab == tab
        let isPreviewed = previewIndex == index

        return Image(systemName: isActive || isCamera ? item.activeIcon : item.icon)
            .font(.system(size: isCamera ? 23 : 21, weight: isCamera ? .semibold : .medium))
            .foregroundStyle(isCamera || isActive ? Self.activeIconColor : Self.idleIconColor)
            .shadow(color: .black.opacity(0.35), radius: 1, x: 0, y: 0.5)
            .frame(maxWidth: .infinity, minHeight: 46)
            .scaleEffect(isPreviewed && !reduceMotion ? 1.08 : 1)
            .background {
                ZStack {
                    if isCamera {
                        Circle()
                            .fill(.clear)
                            .frame(width: 44, height: 44)
                            .liquidGlassCircle(tint: Self.highlightTint, interactive: true)
                    }
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: ItemFramePreference.self,
                            value: [index: proxy.frame(in: .named("tabBarSpace"))]
                        )
                    }
                }
            }
            .accessibilityIdentifier(item.identifier)
            .accessibilityLabel(Text(item.label))
            .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
            .accessibilityAction { activate(item) }
    }

    private func captureTapped() {
        guard !liveProjects.isEmpty else {
            tab = .projects
            return
        }
        if store.isPro {
            captureRoute = .auto
        } else {
            showQuickPick = true
        }
    }

    private func presentPendingCapture() {
        guard let project = pendingCapture else { return }
        pendingCapture = nil
        let count = project.sortedEntries.filter { !$0.isDeleted }.count
        if FeatureGate.canAddEntry(isPro: store.isPro, currentEntryCount: count) {
            captureRoute = .project(project)
        } else {
            showPaywall = true
        }
    }
}

struct QuickCaptureSheet: View {
    let projects: [Project]
    let onSelect: (Project) -> Void

    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(projects) { project in
                    let accent = Theme.accent(for: project.category)
                    Button {
                        onSelect(project)
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle().fill(accent.opacity(0.15)).frame(width: 44, height: 44)
                                Image(systemName: Theme.icon(for: project.category))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(accent)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title).font(Theme.headline(16)).foregroundStyle(theme.ink)
                                Text("\(project.sortedEntries.count) kare")
                                    .font(Theme.caption(12)).foregroundStyle(theme.inkMuted)
                            }
                            Spacer()
                            if project.isCaptureDue() {
                                Text("Bugün")
                                    .font(Theme.caption(11)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(accent, in: Capsule())
                            }
                            Image(systemName: "camera.fill").foregroundStyle(accent)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(theme.surface)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .navigationTitle("Hangi projeye?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(AppModelContainer.makeInMemory())
        .environment(StoreService())
}

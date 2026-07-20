import SwiftData
import SwiftUI
import UIKit

struct HiddenItemsView: View {
    @Query(
        filter: #Predicate<Project> { $0.deletedAt == nil && $0.isHidden == true },
        sort: \Project.createdAt,
        order: .reverse
    ) private var projects: [Project]
    @Query(
        filter: #Predicate<SavedTimelapse> { $0.deletedAt == nil && $0.isHidden == true },
        sort: \SavedTimelapse.createdAt,
        order: .reverse
    ) private var timelapses: [SavedTimelapse]

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme
    @State private var isUnlocked = false
    @State private var isAuthenticating = false
    @State private var selectedProject: Project?
    @State private var playingTimelapse: SavedTimelapse?

    var body: some View {
        Group {
            if isUnlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("Gizlenenler")
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .task {
            if !isUnlocked { await unlock() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            isUnlocked = false
            selectedProject = nil
            playingTimelapse = nil
        }
        .sheet(item: $selectedProject) { project in
            HiddenProjectSheet(project: project)
        }
        .sheet(item: $playingTimelapse) { item in
            SavedPlayerSheet(item: item)
        }
    }

    private var unlockedContent: some View {
        List {
            if projects.isEmpty && timelapses.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 30, weight: .regular))
                            .foregroundStyle(theme.inkMuted)
                        Text("Gizli öğe yok")
                            .font(.headline)
                            .foregroundStyle(theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .listRowBackground(Color.clear)
                }
            }

            if !projects.isEmpty {
                Section("Projeler") {
                    ForEach(projects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            hiddenProjectRow(project)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            unhideProjectButton(project)
                        }
                        .contextMenu {
                            unhideProjectButton(project)
                        }
                    }
                }
            }

            if !timelapses.isEmpty {
                Section("Kaydedilenler") {
                    ForEach(timelapses) { item in
                        Button {
                            playingTimelapse = item
                        } label: {
                            hiddenTimelapseRow(item)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            unhideTimelapseButton(item)
                        }
                        .contextMenu {
                            unhideTimelapseButton(item)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var lockedContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(theme.accent)
                .frame(width: 88, height: 88)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(spacing: 8) {
                Text("Gizlenenler")
                    .font(.title2.bold())
                    .foregroundStyle(theme.ink)
                Text("Face ID veya cihaz parolanla aç.")
                    .font(.body)
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await unlock() }
            } label: {
                if isAuthenticating {
                    ProgressView()
                        .frame(minWidth: 110)
                } else {
                    Label("Kilidi Aç", systemImage: "lock.open")
                        .frame(minWidth: 110)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hiddenProjectRow(_ project: Project) -> some View {
        HStack(spacing: 12) {
            Image(systemName: Theme.icon(for: project.category))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent(for: project.category))
                .frame(width: 44, height: 44)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(project.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text("\(project.sortedEntries.count) kare")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .contentShape(Rectangle())
    }

    private func hiddenTimelapseRow(_ item: SavedTimelapse) -> some View {
        HStack(spacing: 12) {
            HiddenTimelapseThumbnail(item: item)
            .frame(width: 64, height: 44)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text(item.createdAt.formatted(.dateTime.day().month(.abbreviated).year().locale(AppLanguage.currentLocale)))
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Image(systemName: "play.circle")
                .font(.title3)
                .foregroundStyle(theme.inkMuted)
        }
        .contentShape(Rectangle())
    }

    private func unhideProjectButton(_ project: Project) -> some View {
        Button {
            DeferredMenuAction.perform {
                try? ProjectRepository(context: modelContext).setHidden(false, for: project)
            }
        } label: {
            Label("Göster", systemImage: "eye")
        }
        .tint(theme.accent)
    }

    private func unhideTimelapseButton(_ item: SavedTimelapse) -> some View {
        Button {
            DeferredMenuAction.perform {
                TimelapseLibrary.setHidden(false, for: item, context: modelContext)
            }
        } label: {
            Label("Göster", systemImage: "eye")
        }
        .tint(theme.accent)
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        let didAuthenticate = await DeviceOwnerAuthentication.authenticate()
        isAuthenticating = false
        if didAuthenticate {
            isUnlocked = true
        }
    }
}

private struct HiddenTimelapseThumbnail: View {
    let item: SavedTimelapse

    @Environment(\.theme) private var theme
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            theme.surface
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "film")
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .task(id: item.id) {
            image = await ImageDownsampler.cachedImage(
                key: "hidden-video-\(item.id.uuidString)",
                maxPixelSize: 240,
                load: { item.posterData }
            )
        }
    }
}

private struct HiddenProjectSheet: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ProjectDetailView(project: project)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Kapat") { dismiss() }
                    }
                }
        }
    }
}

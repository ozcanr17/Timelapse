import SwiftUI
import SwiftData
import UIKit

struct ProjectDetailView: View {

    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme

    @State private var isCapturing = false
    @State private var isExporting = false
    @State private var viewerEntry: Entry?
    @State private var shareCardURL: URL?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]
    private var accent: Color { Theme.accent(for: project.category) }

    private var liveEntries: [Entry] {
        project.sortedEntries.filter { !$0.isDeleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !project.sortedEntries.isEmpty {
                    statsRow
                }

                if project.sortedEntries.count >= 2 {
                    Button {
                        isExporting = true
                    } label: {
                        Label("Timelapse'i Oluştur", systemImage: "film.stack")
                    }
                    .buttonStyle(.timelapsePrimary)
                }

                if project.sortedEntries.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(liveEntries.enumerated()), id: \.element.id) { index, entry in
                            Button {
                                viewerEntry = entry
                            } label: {
                                EntryThumbnail(entry: entry, dayNumber: index + 1, accent: accent)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    viewerEntry = entry
                                } label: {
                                    Label("Görüntüle", systemImage: "eye")
                                }
                                Button(role: .destructive) {
                                    deleteEntry(entry)
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle(project.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let shareCardURL {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(
                        item: shareCardURL,
                        preview: SharePreview(
                            "\(project.title) — Timelapse",
                            image: Image(systemName: "camera.aperture")
                        )
                    ) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(accent)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isCapturing = true
                } label: {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(accent)
                }
                .accessibilityIdentifier("captureButton")
            }
        }
        .fullScreenCover(isPresented: $isCapturing) {
            CameraCaptureView(project: project)
        }
        .fullScreenCover(item: $viewerEntry) { entry in
            EntryViewerView(project: project, initialEntry: entry)
        }
        .sheet(isPresented: $isExporting) {
            TimelapseExportSheet(project: project)
        }
        .task(id: liveEntries.count) {
            shareCardURL = renderShareCard()
        }
    }

    private func renderShareCard() -> URL? {
        guard !liveEntries.isEmpty else { return nil }
        let renderer = ImageRenderer(content: StreakShareCard(project: project, theme: theme))
        renderer.scale = 1
        guard let uiImage = renderer.uiImage, let data = uiImage.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("timelapse-share-\(project.id.uuidString)")
            .appendingPathExtension("png")
        try? data.write(to: url)
        return url
    }

    private var statsRow: some View {
        let dates = project.sortedEntries.map(\.capturedAt)
        let streak = ActivitySummary.streak(capturedDates: dates)
        return HStack(spacing: 12) {
            StatTile(
                icon: "flame.fill",
                value: "\(streak)",
                label: "Gün serisi",
                isAlive: streak > 0
            )
            StatTile(
                icon: "photo.stack",
                value: "\(dates.count)",
                label: "Toplam kare"
            )
            StatTile(
                icon: "calendar",
                value: "\(ActivitySummary.daysRunning(firstCapture: dates.first))",
                label: "Gündür sürüyor"
            )
        }
    }

    private func deleteEntry(_ entry: Entry) {
        let repository = ProjectRepository(context: modelContext)
        withAnimation {
            try? repository.deleteEntry(entry)
        }
        Task {
            try? await Task.sleep(for: .seconds(0.6))
            try? repository.saveIfNeeded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.category.displayName.uppercased())
                        .font(Theme.caption(12))
                        .foregroundStyle(.white.opacity(0.8))
                        .tracking(1.2)

                    (
                        Text("\(project.sortedEntries.count)")
                            .font(Theme.stamp(40, weight: .bold))
                            .foregroundStyle(.white)
                        +
                        Text(" çekim")
                            .font(Theme.headline(17))
                            .foregroundStyle(.white.opacity(0.85))
                    )
                }
                Spacer()
                ZStack {
                    Circle().fill(.white.opacity(0.18)).frame(width: 54, height: 54)
                    Image(systemName: Theme.icon(for: project.category))
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 14) {
                Label(project.cadence.displayName, systemImage: "calendar")
                if project.isCaptureDue() {
                    Label("Bugün zamanı geldi", systemImage: "bell.fill")
                }
            }
            .font(Theme.caption(12))
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [accent, accent.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera")
                .font(.system(size: 30))
                .foregroundStyle(theme.inkMuted)
            Text("Henüz çekim yok")
                .font(Theme.headline(16))
                .foregroundStyle(theme.ink)
            Text("Sağ üstteki kamera düğmesiyle ilk çekimini ekle.")
                .font(Theme.body(14))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }
}

private struct StatTile: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey
    var isAlive: Bool = false

    @Environment(\.theme) private var theme
    @State private var isBreathing = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.accent)
                .scaleEffect(isAlive && isBreathing ? 1.18 : 1)
                .shadow(color: isAlive ? theme.accent.opacity(isBreathing ? 0.55 : 0.15) : .clear, radius: 6)
                .animation(
                    isAlive
                        ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
                        : .default,
                    value: isBreathing
                )
                .onAppear { if isAlive { isBreathing = true } }
            Text(value)
                .font(Theme.stamp(20, weight: .bold))
                .foregroundStyle(theme.ink)
            Text(label)
                .font(Theme.caption(11))
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .cardStyle()
    }
}

private struct EntryThumbnail: View {
    let entry: Entry
    let dayNumber: Int
    let accent: Color

    @Environment(\.theme) private var theme
    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(theme.surface)
                    Image(systemName: "camera")
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.ink.opacity(0.06), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Text(String(format: "No. %02d", dayNumber))
                    .font(Theme.stamp(9.5, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.88))
                    .clipShape(Capsule())
                    .padding(6)
            }
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)

            Text(entry.capturedAt, format: .dateTime.day().month())
                .font(Theme.stamp(11, weight: .regular))
                .foregroundStyle(theme.inkMuted)
        }
        .task(id: entry.imageData?.count) {
            thumbnail = await ImageDownsampler.image(from: entry.imageData, maxPixelSize: 400)
        }
    }
}

#Preview {
    let container = AppModelContainer.makeInMemory()
    let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
    container.mainContext.insert(project)
    for dayOffset in 0..<5 {
        let entry = Entry(capturedAt: .now.addingTimeInterval(Double(-dayOffset) * 86_400))
        entry.project = project
        container.mainContext.insert(entry)
    }
    return NavigationStack {
        ProjectDetailView(project: project)
    }
    .modelContainer(container)
}

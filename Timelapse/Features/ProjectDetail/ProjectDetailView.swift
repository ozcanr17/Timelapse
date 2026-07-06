import SwiftUI
import SwiftData
import UIKit

struct ProjectDetailView: View {

    let project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(StoreService.self) private var store
    @Environment(\.theme) private var theme

    @State private var isCapturing = false
    @State private var isExporting = false
    @State private var viewerEntry: Entry?
    @State private var shareCardURL: URL?
    @State private var showPaywall = false
    @State private var showInvite = false

    private var canAddEntry: Bool {
        FeatureGate.canAddEntry(isPro: store.isPro, currentEntryCount: liveEntries.count)
    }

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

                if !store.isPro {
                    freeQuotaBadge
                }

                captureCTA

                if project.sortedEntries.count >= 2 {
                    Button {
                        isExporting = true
                    } label: {
                        Label("Timelapse'i Oluştur", systemImage: "film.stack")
                            .font(Theme.headline(17))
                            .foregroundStyle(accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
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
                    inviteTapped()
                } label: {
                    Image(systemName: project.isCollaborative ? "person.2.fill" : "person.badge.plus")
                        .foregroundStyle(accent)
                }
                .accessibilityIdentifier("inviteButton")
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
        .sheet(isPresented: $showPaywall) {
            PaywallView(store: store)
        }
        .sheet(isPresented: $showInvite) {
            ActivityView(activityItems: [inviteText])
        }
        .task(id: liveEntries.count) {
            shareCardURL = renderShareCard()
        }
    }

    /// Bugünün karesini çekmek için ana çağrı — kamerayı prim konumda, büyük bir
    /// düğmeyle açar. Uygulamanın asıl amacı bu olduğundan öne çıkarıyoruz.
    private var captureCTA: some View {
        let due = project.isCaptureDue()
        return Button {
            if canAddEntry { isCapturing = true } else { showPaywall = true }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(.white.opacity(0.22)).frame(width: 46, height: 46)
                    Image(systemName: "camera.fill").font(.system(size: 20, weight: .bold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(due ? "Bugünün karesini çek" : "Yeni kare ekle")
                        .font(Theme.headline(18))
                    Text(canAddEntry ? "Sıradaki: No. \(liveEntries.count + 1)" : "Ücretsiz sınır doldu — Pro")
                        .font(Theme.caption(12)).opacity(0.9)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 15, weight: .bold)).opacity(0.75)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(accent, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
            .overlay(alignment: .topTrailing) {
                if due {
                    Circle().fill(.white).frame(width: 10, height: 10).padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("captureButton")
    }

    private var inviteText: String {
        String(localized: "Timelapse'te \"\(project.title)\" projesinde birlikte çekim yapalım! Uygulamayı indirip aynı hikâyeyi birlikte biriktirelim. 📸")
    }

    /// Birlikte Çekim: arkadaşları davet edip aynı projeye birlikte katkı yapmak için
    /// sistem paylaşım sayfasını açar (Pro). Ücretsiz kullanıcı paywall görür.
    private func inviteTapped() {
        guard store.isPro else {
            showPaywall = true
            return
        }
        if !project.isCollaborative {
            project.isCollaborative = true
            try? modelContext.save()
        }
        showInvite = true
    }

    private var freeQuotaBadge: some View {
        let count = liveEntries.count
        let atLimit = count >= FeatureGate.freeEntryLimit
        return HStack(spacing: 8) {
            Image(systemName: atLimit ? "lock.fill" : "camera.badge.clock")
                .font(.system(size: 13, weight: .semibold))
            Text(atLimit
                 ? "Ücretsiz sınır doldu — devam için Pro"
                 : "Ücretsiz: \(count)/\(FeatureGate.freeEntryLimit) kare")
                .font(Theme.caption(12))
            Spacer()
            if atLimit {
                Text("Pro'ya Geç")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.accent)
            }
        }
        .foregroundStyle(atLimit ? theme.accent : theme.inkMuted)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { if atLimit { showPaywall = true } }
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
                accent: accent,
                isAlive: streak > 0
            )
            StatTile(
                icon: "photo.stack",
                value: "\(dates.count)",
                label: "Toplam kare",
                accent: accent
            )
            StatTile(
                icon: "calendar",
                value: "\(ActivitySummary.daysRunning(firstCapture: dates.first))",
                label: "Gündür sürüyor",
                accent: accent
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle().fill(accent.opacity(0.15)).frame(width: 56, height: 56)
                    Image(systemName: Theme.icon(for: project.category))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(project.category.displayName)
                        .font(Theme.caption(13))
                        .foregroundStyle(theme.inkMuted)
                    (
                        Text("\(project.sortedEntries.count)")
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .monospacedDigit()
                        +
                        Text(" çekim")
                            .font(Theme.headline(16))
                            .foregroundStyle(theme.inkMuted)
                    )
                    .foregroundStyle(theme.ink)
                }
                Spacer()
            }

            HStack(spacing: 14) {
                Label(project.cadence.displayName, systemImage: "calendar")
                    .foregroundStyle(theme.inkMuted)
                if project.isCaptureDue() {
                    Label("Bugün zamanı geldi", systemImage: "bell.fill")
                        .foregroundStyle(accent)
                }
                if project.isCoupleMode {
                    Label("Çift modu", systemImage: "person.2.fill")
                        .foregroundStyle(theme.inkMuted)
                }
                if project.isCollaborative {
                    Label("Birlikte", systemImage: "person.3.fill")
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .font(Theme.caption(12))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
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

/// Sistem paylaşım sayfasını (UIActivityViewController) SwiftUI'da sunar — çift modu
/// davetini paylaşmak için.
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct StatTile: View {
    let icon: String
    let value: String
    let label: LocalizedStringKey
    var accent: Color
    var isAlive: Bool = false

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isAlive ? accent : theme.inkMuted)
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .default))
                .monospacedDigit()
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
                .font(Theme.caption(11))
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
    .environment(StoreService())
}

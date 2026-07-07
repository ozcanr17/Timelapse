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
    @State private var showImport = false
    @State private var heroImage: UIImage?

    private var canAddEntry: Bool {
        FeatureGate.canAddEntry(isPro: store.isPro, currentEntryCount: liveEntries.count)
    }

    private var accent: Color { Theme.accent(for: project.category) }

    private var liveEntries: [Entry] {
        project.sortedEntries.filter { !$0.isDeleted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroCard

                if !project.sortedEntries.isEmpty {
                    statsRow
                }

                if !store.isPro {
                    freeQuotaBadge
                }

                captureCTA

                if project.sortedEntries.count >= 2 {
                    exportButton
                }

                if project.sortedEntries.isEmpty {
                    emptyState
                } else {
                    timeline
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
                            "\(project.title) — Flapse",
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
                    importTapped()
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .foregroundStyle(accent)
                }
                .accessibilityIdentifier("importButton")
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
        .sheet(isPresented: $showImport) {
            PhotoImportSheet(mode: .existing(project), repository: ProjectRepository(context: modelContext))
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
        String(localized: "Flapse'te \"\(project.title)\" projesinde birlikte çekim yapalım! Uygulamayı indirip aynı hikâyeyi birlikte biriktirelim. 📸")
    }

    /// Birlikte Çekim: arkadaşları davet edip aynı projeye birlikte katkı yapmak için
    /// sistem paylaşım sayfasını açar (Pro). Ücretsiz kullanıcı paywall görür.
    private func importTapped() {
        if store.isPro { showImport = true } else { showPaywall = true }
    }

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

    private var heroCard: some View {
        ZStack(alignment: .bottomLeading) {
            ZStack {
                if let heroImage {
                    Image(uiImage: heroImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [accent, accent.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                }
                LinearGradient(
                    colors: [.black.opacity(0.05), .clear, .black.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(project.title)
                    .font(.system(size: 30, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Text("\(liveEntries.count)")
                        .monospacedDigit().fontWeight(.semibold)
                    Text("kare · \(project.cadence.displayName)")
                }
                .font(Theme.caption(13))
                .foregroundStyle(.white.opacity(0.92))
            }
            .padding(20)
        }
        .frame(height: 340)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topLeading) {
            Label(project.category.displayName, systemImage: Theme.icon(for: project.category))
                .font(Theme.caption(12))
                .foregroundStyle(.white)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(16)
        }
        .overlay(alignment: .topTrailing) {
            if project.isCaptureDue() {
                Text("Bugün")
                    .font(Theme.caption(12))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(.white, in: Capsule())
                    .padding(16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .task(id: liveEntries.last?.imageData?.count) {
            heroImage = await ImageDownsampler.image(from: liveEntries.last?.imageData, maxPixelSize: 1000)
        }
    }

    private var exportButton: some View {
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

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Zaman Çizelgesi")
                .font(Theme.headline(18))
                .foregroundStyle(theme.ink)
                .padding(.bottom, 16)

            ForEach(Array(liveEntries.enumerated()), id: \.element.id) { index, entry in
                TimelineEntryRow(
                    entry: entry,
                    accent: accent,
                    isFirst: index == 0,
                    isLast: index == liveEntries.count - 1
                ) {
                    viewerEntry = entry
                }
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
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct TimelineEntryRow: View {
    let entry: Entry
    let accent: Color
    let isFirst: Bool
    let isLast: Bool
    let onTap: () -> Void

    @Environment(\.theme) private var theme
    @State private var photo: UIImage?

    private let tileWidth: CGFloat = 58

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            rail
            card
        }
    }

    private var lineColor: Color { theme.inkMuted.opacity(0.18) }

    private var rail: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(lineColor)
                .frame(width: 2, height: 10)
                .opacity(isFirst ? 0 : 1)
            calendarTile
            Rectangle()
                .fill(lineColor)
                .frame(width: 2)
                .frame(maxHeight: .infinity)
                .opacity(isLast ? 0 : 1)
        }
        .frame(width: tileWidth)
    }

    private var calendarTile: some View {
        VStack(spacing: 1) {
            Text(entry.capturedAt, format: .dateTime.weekday(.abbreviated))
                .font(Theme.caption(11))
                .fontWeight(.semibold)
                .foregroundStyle(accent)
            Text(entry.capturedAt, format: .dateTime.day())
                .font(.system(size: 24, weight: .bold, design: .default))
                .foregroundStyle(theme.ink)
            Text(entry.capturedAt, format: .dateTime.month(.abbreviated))
                .font(Theme.caption(10))
                .foregroundStyle(theme.inkMuted)
        }
        .frame(width: tileWidth, height: 66)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(theme.ink.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private var card: some View {
        Button(action: onTap) {
            ZStack {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(theme.surface)
                    Image(systemName: "camera").foregroundStyle(theme.inkMuted)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(theme.ink.opacity(0.06), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 22)
        .task(id: entry.imageData?.count) {
            photo = await ImageDownsampler.image(from: entry.imageData, maxPixelSize: 700)
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

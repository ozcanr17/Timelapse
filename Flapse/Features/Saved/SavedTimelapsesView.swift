import AVKit
import Photos
import SwiftUI
import SwiftData

struct SavedTimelapsesView: View {

    @Query(filter: #Predicate<SavedTimelapse> { $0.deletedAt == nil && $0.isHidden == false }, sort: \SavedTimelapse.createdAt, order: .reverse)
    private var items: [SavedTimelapse]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var playing: SavedTimelapse?
    @State private var pendingDeletion: SavedTimelapse?
    @State private var showPhotosDenied = false

    var body: some View {
        ZStack {
            FlapseScreenBackdrop()
            if items.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        librarySection
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Kaydedilenler")
        .sheet(item: $playing) { item in
            SavedPlayerSheet(item: item)
        }
        .confirmationDialog(
            "Bu timelapse Son Silinenler'e taşınsın mı? 7 gün sonra kalıcı olarak silinir.",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let pendingDeletion {
                    TimelapseLibrary.softDelete(pendingDeletion, context: modelContext)
                }
                pendingDeletion = nil
            }
            Button("Vazgeç", role: .cancel) { pendingDeletion = nil }
        }
        .photosDeniedAlert(isPresented: $showPhotosDenied)
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(theme.accent.opacity(0.12))
                .frame(width: 108, height: 108)
                .overlay(
                    Image(systemName: "film.stack")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(theme.accent)
                )
            VStack(spacing: 8) {
                Text("Henüz kayıtlı timelapse yok")
                    .font(Theme.headline(22))
                    .foregroundStyle(theme.ink)
                Text("Bir projeden timelapse oluşturup \"Uygulamada sakla\" dediğinde burada birikir.")
                    .font(Theme.body(15))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 40)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kitaplık")
                        .font(Theme.headline(22))
                        .foregroundStyle(theme.ink)
                    Text("\(items.count) timelapse")
                        .font(Theme.caption(12))
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Image(systemName: "play.rectangle.on.rectangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .liquidGlassStyle(cornerRadius: 15, tint: theme.accent.opacity(0.08))
            }

            if let featured = items.first {
                libraryCard(featured, isFeatured: true)
            }

            if items.count > 1 {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(Array(items.dropFirst())) { item in
                        libraryCard(item, isFeatured: false)
                    }
                }
            }
        }
    }

    private func libraryCard(_ item: SavedTimelapse, isFeatured: Bool) -> some View {
        Button {
            playing = item
        } label: {
            VStack(alignment: .leading, spacing: isFeatured ? 10 : 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: isFeatured ? 24 : 16, style: .continuous)
                        .fill(theme.inkMuted.opacity(0.12))
                    SavedTimelapseThumbnail(item: item, maxPixelSize: isFeatured ? 900 : 500)
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: isFeatured ? 54 : 34))
                        .foregroundStyle(.white.opacity(0.94))
                        .shadow(color: .black.opacity(0.32), radius: 9)
                }
                .frame(height: isFeatured ? 250 : 150)
                .clipShape(RoundedRectangle(cornerRadius: isFeatured ? 24 : 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: isFeatured ? 24 : 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 0.8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(Duration.seconds(item.duration).formatted(.time(pattern: .minuteSecond)))
                        .font(Theme.caption(11)).monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(Theme.headline(isFeatured ? 20 : 14))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text(item.createdAt.formatted(.dateTime.day().month(.abbreviated).year().locale(AppLanguage.currentLocale)))
                        .font(Theme.caption(11))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .padding(isFeatured ? 10 : 0)
            .background(
                isFeatured ? theme.surface.opacity(0.76) : .clear,
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .overlay {
                if isFeatured {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(theme.ink.opacity(0.055), lineWidth: 0.7)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: isFeatured ? 28 : 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            ShareLink(item: item.fileURL) {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }
            Button {
                DeferredMenuAction.perform { saveToPhotos(item) }
            } label: {
                Label("Fotoğraflara kaydet", systemImage: "square.and.arrow.down")
            }
            Button {
                DeferredMenuAction.perform {
                    TimelapseLibrary.setHidden(true, for: item, context: modelContext)
                }
            } label: {
                Label("Gizle", systemImage: "eye.slash")
            }
            Button(role: .destructive) {
                DeferredMenuAction.perform { pendingDeletion = item }
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    private func saveToPhotos(_ item: SavedTimelapse) {
        Task {
            let outcome = await PhotoLibrarySaver.saveVideo(at: item.fileURL)
            if outcome == .denied {
                showPhotosDenied = true
            }
            UINotificationFeedbackGenerator().notificationOccurred(outcome == .saved ? .success : .error)
        }
    }
}

struct SavedPlayerSheet: View {
    let item: SavedTimelapse

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var player: AVPlayer

    init(item: SavedTimelapse) {
        self.item = item
        _player = State(initialValue: AVPlayer(url: item.fileURL))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.canvas.ignoresSafeArea()
                InlineVideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .padding(20)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: item.fileURL) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .onAppear { player.play() }
            .onDisappear { player.pause() }
        }
    }
}

import AVKit
import Photos
import SwiftUI
import SwiftData

struct SavedTimelapsesView: View {

    @Query(filter: #Predicate<SavedTimelapse> { $0.deletedAt == nil }, sort: \SavedTimelapse.createdAt, order: .reverse)
    private var items: [SavedTimelapse]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.theme) private var theme
    @State private var playing: SavedTimelapse?
    @State private var pendingDeletion: SavedTimelapse?

    private var service: TimelapseRenderService { TimelapseRenderService.shared }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            if items.isEmpty && service.activeJobs.isEmpty && service.finishedJobs.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if !service.activeJobs.isEmpty {
                            jobSection(title: "Oluşturuluyor", jobs: service.activeJobs)
                        }
                        if !service.finishedJobs.isEmpty {
                            jobSection(title: "Hazır — kaydetmeyi unutma", jobs: service.finishedJobs)
                        }
                        if !items.isEmpty {
                            librarySection
                        }
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
                    .font(.system(size: 22, weight: .bold, design: .default))
                    .foregroundStyle(theme.ink)
                Text("Bir projeden timelapse oluşturup \"Uygulamada sakla\" dediğinde burada birikir.")
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
        }
        .padding(.horizontal, 40)
    }

    private func jobSection(title: LocalizedStringKey, jobs: [TimelapseRenderService.Job]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(Theme.caption(13))
                .foregroundStyle(theme.inkMuted)
            ForEach(jobs) { job in
                jobRow(job)
            }
        }
    }

    private func jobRow(_ job: TimelapseRenderService.Job) -> some View {
        HStack(spacing: 12) {
            if job.viewModel.phase == .rendering {
                SpinningLogo(size: 34)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(theme.accent)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(job.title)
                    .font(Theme.headline(15))
                    .foregroundStyle(theme.ink)
                if job.viewModel.phase == .rendering {
                    ProgressView(value: job.viewModel.progress)
                        .tint(theme.accent)
                } else {
                    Text("Video hazır")
                        .font(Theme.caption(12))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            Spacer()
            if job.viewModel.phase == .rendering {
                Button {
                    service.discard(projectID: job.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(theme.inkMuted)
                }
                .accessibilityLabel(Text("İptal et"))
            } else {
                Button("Kaydet") {
                    Task {
                        if await service.saveToLibrary(projectID: job.id, context: modelContext) != nil {
                            service.discard(projectID: job.id)
                        }
                    }
                }
                .font(Theme.caption(13))
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            }
        }
        .padding(14)
        .liquidGlassStyle()
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kitaplık")
                .font(Theme.caption(13))
                .foregroundStyle(theme.inkMuted)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(items) { item in
                    libraryCard(item)
                }
            }
        }
    }

    private func libraryCard(_ item: SavedTimelapse) -> some View {
        Button {
            playing = item
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(theme.inkMuted.opacity(0.12))
                    if let posterData = item.posterData, let poster = UIImage(data: posterData) {
                        Image(uiImage: poster)
                            .resizable()
                            .scaledToFill()
                    }
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 6)
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                        .font(Theme.headline(14))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    Text(item.createdAt.formatted(.dateTime.day().month(.abbreviated).year().locale(AppLanguage.currentLocale)))
                        .font(Theme.caption(11))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            ShareLink(item: item.fileURL) {
                Label("Paylaş", systemImage: "square.and.arrow.up")
            }
            Button {
                saveToPhotos(item)
            } label: {
                Label("Fotoğraflara kaydet", systemImage: "square.and.arrow.down")
            }
            Button(role: .destructive) {
                pendingDeletion = item
            } label: {
                Label("Sil", systemImage: "trash")
            }
        }
    }

    private func saveToPhotos(_ item: SavedTimelapse) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: item.fileURL)
        } completionHandler: { success, _ in
            Task { @MainActor in
                UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
            }
        }
    }
}

private struct SavedPlayerSheet: View {
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

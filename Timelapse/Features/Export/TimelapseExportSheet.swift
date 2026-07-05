import SwiftUI
import SwiftData
import AVKit

struct TimelapseExportSheet: View {

    let project: Project

    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var viewModel = TimelapseExportViewModel()
    @State private var showPaywall = false
    @State private var speed: TimelapseSpeed = .normal
    @State private var overlay = TimelapseOverlayOptions()
    @State private var noteDraft = ""

    private var frames: [TimelapseFrame] {
        project.sortedEntries.compactMap { entry in
            entry.imageData.map { TimelapseFrame(imageData: $0, capturedAt: entry.capturedAt) }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.canvas.ignoresSafeArea()
                content
            }
            .navigationTitle("Timelapse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task { await export() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .rendering:
            renderingView
        case .finished(let url):
            finishedView(url)
        case .failed(let message):
            failedView(message)
        }
    }

    private var renderingView: some View {
        VStack(spacing: 24) {
            LogoMark(size: 72)
            VStack(spacing: 8) {
                Text("Kareler birleştiriliyor…")
                    .font(Theme.headline(17))
                    .foregroundStyle(theme.ink)
                Text(viewModel.progress, format: .percent.precision(.fractionLength(0)))
                    .font(Theme.stamp(15))
                    .foregroundStyle(theme.inkMuted)
            }
            ProgressView(value: viewModel.progress)
                .tint(theme.accent)
                .padding(.horizontal, 48)
        }
    }

    private func finishedView(_ url: URL) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                ExportedVideoPlayer(url: url)
                    .id(url)
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                    .frame(maxHeight: 380)

                speedControl
                overlayControls

                ShareLink(item: url) {
                    Label("Videoyu Paylaş", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.timelapsePrimary)

                if !store.isPro {
                    Button {
                        showPaywall = true
                    } label: {
                        Text("Filigranı kaldır, 4K'ya geç — Pro")
                            .font(Theme.caption(13))
                            .foregroundStyle(theme.secondary)
                    }
                }
            }
            .padding(20)
        }
        .onChange(of: overlay) { Task { await export() } }
    }

    private var speedControl: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Hız", systemImage: "gauge.with.needle")
                    .font(Theme.caption(13))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
            }
            Picker("Hız", selection: $speed) {
                ForEach(TimelapseSpeed.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.phase == .rendering)
            .onChange(of: speed) {
                Task { await export() }
            }
        }
    }

    private var overlayControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bindirmeler")
                .font(Theme.caption(13))
                .foregroundStyle(theme.inkMuted)

            Toggle(isOn: $overlay.showDate) {
                Label("Tarih damgası", systemImage: "calendar")
                    .font(Theme.body(15))
                    .foregroundStyle(theme.ink)
            }
            .tint(theme.accent)
            if overlay.showDate {
                cornerPicker("Tarih konumu", selection: $overlay.datePosition)
            }

            Divider().overlay(theme.inkMuted.opacity(0.2))

            HStack(spacing: 10) {
                Image(systemName: "text.bubble")
                    .foregroundStyle(theme.accent)
                TextField("Not ekle…", text: $noteDraft)
                    .font(Theme.body(15))
                    .foregroundStyle(theme.ink)
                    .submitLabel(.done)
                    .onSubmit { overlay.note = noteDraft }
            }
            if !noteDraft.isEmpty {
                cornerPicker("Not konumu", selection: $overlay.notePosition)
                if overlay.note != noteDraft {
                    Button("Notu uygula") { overlay.note = noteDraft }
                        .font(Theme.caption(12))
                        .foregroundStyle(theme.accent)
                }
            }

            Divider().overlay(theme.inkMuted.opacity(0.2))

            Toggle(isOn: $overlay.showAppMark) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Uygulama etiketi").font(Theme.body(15)).foregroundStyle(theme.ink)
                        if !store.isPro {
                            Text("Ücretsiz sürümde kaldırılamaz").font(Theme.caption(11)).foregroundStyle(theme.inkMuted)
                        }
                    }
                } icon: {
                    Image(systemName: "signature").foregroundStyle(theme.accent)
                }
            }
            .tint(theme.accent)
            .disabled(!store.isPro)
            cornerPicker("Etiket konumu", selection: $overlay.appMarkPosition)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private func cornerPicker(_ title: LocalizedStringKey, selection: Binding<OverlayCorner>) -> some View {
        HStack {
            Text(title)
                .font(Theme.caption(12))
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(OverlayCorner.allCases) { corner in
                    Text(corner.displayName).tag(corner)
                }
            }
            .pickerStyle(.menu)
            .tint(theme.accent)
        }
    }

    private func failedView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(theme.accent)
            Text(message)
                .font(Theme.body(15))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Button("Tekrar dene") {
                Task { await export() }
            }
            .buttonStyle(.timelapsePrimary)
            .frame(width: 200)
        }
        .padding(24)
    }

    private func export() async {
        // Ücretsiz kullanıcı etiketi kaldıramaz; her ihtimale karşı burada da zorluyoruz.
        var effectiveOverlay = overlay
        if !store.isPro { effectiveOverlay.showAppMark = true }
        await viewModel.export(
            frames: frames,
            isPro: store.isPro,
            speed: speed,
            overlay: effectiveOverlay
        )
    }
}

/// Oynatıcıyı bir kez oluşturup tutar; her SwiftUI güncellemesinde yeni bir AVPlayer
/// üretmeyi (ve sızıntıyı) önler. `.id(url)` ile URL değişince görünüm yeniden kurulur.
private struct ExportedVideoPlayer: View {
    @State private var player: AVPlayer

    init(url: URL) {
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onDisappear { player.pause() }
    }
}

#Preview {
    let container = AppModelContainer.makeInMemory()
    let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
    container.mainContext.insert(project)
    return TimelapseExportSheet(project: project)
        .modelContainer(container)
        .environment(StoreService())
}

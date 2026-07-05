import SwiftUI
import SwiftData
import AVKit

struct TimelapseExportSheet: View {

    let project: Project

    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @AppStorage(PremiumFeature.smartAlignment.preferenceKey!) private var smartAlignmentEnabled = false
    @State private var viewModel = TimelapseExportViewModel()
    @State private var showPaywall = false
    @State private var speed: TimelapseSpeed = .normal
    @State private var overlay = TimelapseOverlayOptions()
    @State private var noteDraft = ""
    @State private var lastRenderedURL: URL?
    @State private var alignMode: AlignMode = .off
    @State private var manual = ManualAlignment(center: CGPoint(x: 0.5, y: 0.5), zoom: 1)
    @State private var transition: TimelapseTransition = .cut
    @State private var showManualAlign = false
    @State private var didInitAlign = false

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
            .task {
                if !didInitAlign {
                    didInitAlign = true
                    if store.isPro && smartAlignmentEnabled { alignMode = .smart }
                }
                await export()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
            .sheet(isPresented: $showManualAlign) {
                if let data = frames.first?.imageData {
                    ManualAlignView(imageData: data, manual: $manual) {
                        Task { await export() }
                    }
                }
            }
        }
    }

    private var isLoading: Bool {
        switch viewModel.phase {
        case .idle, .rendering: return true
        default: return false
        }
    }

    private var content: some View {
        ZStack {
            // Arka planı boş bırakmak yerine bulunduğumuz sayfayı bulanıklaştırıp
            // gösteriyoruz; üstünde dönen objektif animasyonu belirir.
            contentBehind
                .blur(radius: isLoading ? 18 : 0)
                .allowsHitTesting(!isLoading)

            if isLoading {
                loadingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isLoading)
        .onChange(of: viewModel.phase) {
            if case .finished(let url) = viewModel.phase { lastRenderedURL = url }
        }
    }

    @ViewBuilder
    private var contentBehind: some View {
        switch viewModel.phase {
        case .finished(let url):
            finishedView(url)
        case .failed(let message):
            failedView(message)
        case .idle, .rendering:
            if let lastRenderedURL {
                finishedView(lastRenderedURL)
            } else {
                Color.clear
            }
        }
    }

    private var loadingOverlay: some View {
        VStack(spacing: 16) {
            SpinningLogo(size: 96)
            Text("Timelapse hazırlanıyor…")
                .font(Theme.headline(16))
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                transitionControl
                alignmentControl
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

    private var transitionControl: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Geçiş", systemImage: "square.on.square.dashed")
                    .font(Theme.caption(13))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
            }
            Picker("Geçiş", selection: $transition) {
                ForEach(TimelapseTransition.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.phase == .rendering)
            .onChange(of: transition) { Task { await export() } }
        }
    }

    private var alignmentControl: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Hizalama", systemImage: "wand.and.stars")
                    .font(Theme.caption(13))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                if !store.isPro {
                    Text("PRO").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(theme.accent, in: Capsule())
                }
            }
            Picker("Hizalama", selection: $alignMode) {
                ForEach(AlignMode.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.phase == .rendering)
            .onChange(of: alignMode) { _, mode in
                if !store.isPro {
                    alignMode = .off
                    showPaywall = true
                    return
                }
                if mode == .manual { showManualAlign = true } else { Task { await export() } }
            }
            if alignMode == .manual {
                Button {
                    showManualAlign = true
                } label: {
                    Label("Hizalamayı Ayarla", systemImage: "scope")
                        .font(Theme.caption(13))
                        .foregroundStyle(theme.accent)
                }
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
                cornerPicker("Tarih konumu", selection: $overlay.datePosition, exclude: [overlay.notePosition])
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
                cornerPicker("Not konumu", selection: $overlay.notePosition, exclude: [overlay.datePosition])
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
                        Text("Uygulama etiketi (sağ alt)").font(Theme.body(15)).foregroundStyle(theme.ink)
                        Text(store.isPro ? "Konum sabit; gizleyebilirsin" : "Ücretsiz sürümde kaldırılamaz")
                            .font(Theme.caption(11)).foregroundStyle(theme.inkMuted)
                    }
                } icon: {
                    Image(systemName: "signature").foregroundStyle(theme.accent)
                }
            }
            .tint(theme.accent)
            .disabled(!store.isPro)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    /// Köşe seçici. Sağ alt (uygulama etiketi) ve `exclude`'daki köşeler seçenek dışıdır;
    /// böylece tarih ile not asla aynı köşeye düşmez.
    private func cornerPicker(_ title: LocalizedStringKey, selection: Binding<OverlayCorner>, exclude: Set<OverlayCorner>) -> some View {
        let reserved = exclude.union([TimelapseOverlayOptions.appMarkCorner])
        let options = OverlayCorner.allCases.filter { $0 == selection.wrappedValue || !reserved.contains($0) }
        return HStack {
            Text(title)
                .font(Theme.caption(12))
                .foregroundStyle(theme.inkMuted)
            Spacer()
            Picker(title, selection: selection) {
                ForEach(options) { corner in
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
        let proAlign = store.isPro
        await viewModel.export(
            frames: frames,
            isPro: store.isPro,
            speed: speed,
            overlay: effectiveOverlay,
            smartAlignment: proAlign && alignMode == .smart,
            manualAnchor: (proAlign && alignMode == .manual) ? manual : nil,
            transition: transition
        )
    }
}

private enum AlignMode: String, CaseIterable, Identifiable {
    case off, smart, manual
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .off:    "Kapalı"
        case .smart:  "Akıllı"
        case .manual: "Manuel"
        }
    }
}

/// Manuel hizalama ekranı: kullanıcı ilk kare üzerinde özneyi işaretler (sürükle) ve
/// yakınlaştırmayı ayarlar. Seçilen nokta tüm karelerde ortaya getirilir.
private struct ManualAlignView: View {
    let imageData: Data
    @Binding var manual: ManualAlignment
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var uiImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Özneyi işaretlemek için dokun ve sürükle")
                    .font(Theme.caption(13))
                    .foregroundStyle(theme.inkMuted)

                GeometryReader { geo in
                    let fit = fitRect(imageSize: uiImage?.size ?? CGSize(width: 3, height: 4), in: geo.size)
                    ZStack(alignment: .topLeading) {
                        Color.black
                        if let uiImage {
                            Image(uiImage: uiImage).resizable().scaledToFit()
                        }
                        Crosshair()
                            .position(
                                x: fit.minX + manual.center.x * fit.width,
                                y: fit.minY + manual.center.y * fit.height
                            )
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            let x = (value.location.x - fit.minX) / max(fit.width, 1)
                            let y = (value.location.y - fit.minY) / max(fit.height, 1)
                            manual.center = CGPoint(x: min(max(x, 0), 1), y: min(max(y, 0), 1))
                        }
                    )
                }
                .frame(maxHeight: 440)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                HStack(spacing: 12) {
                    Image(systemName: "minus.magnifyingglass").foregroundStyle(theme.inkMuted)
                    Slider(value: Binding(get: { Double(manual.zoom) }, set: { manual.zoom = CGFloat($0) }), in: 0.5...3)
                        .tint(theme.accent)
                    Image(systemName: "plus.magnifyingglass").foregroundStyle(theme.inkMuted)
                }
            }
            .padding(20)
            .background(theme.canvas)
            .navigationTitle("Manuel Hizalama")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Uygula") { dismiss(); onDone() }.fontWeight(.bold)
                }
            }
        }
        .task { uiImage = await ImageDownsampler.image(from: imageData, maxPixelSize: 1400) }
    }

    private func fitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        let imgAspect = imageSize.width / max(imageSize.height, 1)
        let contAspect = container.width / max(container.height, 1)
        var w = container.width
        var h = container.height
        if imgAspect > contAspect { h = w / imgAspect } else { w = h * imgAspect }
        return CGRect(x: (container.width - w) / 2, y: (container.height - h) / 2, width: w, height: h)
    }
}

private struct Crosshair: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(.white, lineWidth: 2).frame(width: 44, height: 44)
            Circle().fill(.white).frame(width: 5, height: 5)
            Rectangle().fill(.white).frame(width: 1, height: 16)
            Rectangle().fill(.white).frame(width: 16, height: 1)
        }
        .shadow(color: .black.opacity(0.6), radius: 3)
        .allowsHitTesting(false)
    }
}

/// Video render edilirken gösterilen sevimli, sürekli dönen logo animasyonu
/// (uygulama açılışındaki dönüşle aynı ruhta). Sıkıcı ilerleme çubuğunun yerini alır.
private struct SpinningLogo: View {
    let size: CGFloat
    @State private var spinning = false

    var body: some View {
        // Dıştaki yuvarlatılmış kare sabit; yalnızca içteki objektif sürekli döner.
        LogoMark(size: size, innerRotation: .degrees(spinning ? 360 : 0))
            .animation(.linear(duration: 1.8).repeatForever(autoreverses: false), value: spinning)
            .onAppear { spinning = true }
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

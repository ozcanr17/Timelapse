import SwiftUI
import SwiftData
import AVKit
import Photos

struct TimelapseExportSheet: View {

    let project: Project

    @Environment(StoreService.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @AppStorage(PremiumFeature.smartAlignment.preferenceKey!) private var smartAlignmentEnabled = false
    @State private var viewModel = TimelapseExportViewModel()
    @State private var showPaywall = false
    @State private var speed: TimelapseSpeed = .normal
    @State private var aspect: TimelapseAspect = .threeFour
    @State private var overlay = TimelapseOverlayOptions()
    @State private var noteDraft = ""
    @State private var lastRenderedURL: URL?
    @State private var alignMode: AlignMode = .off
    @State private var manual = ManualAlignment(center: CGPoint(x: 0.5, y: 0.5), zoom: 1)
    @State private var transition: TimelapseTransition = .cut
    @State private var showManualAlign = false
    @State private var didInitAlign = false
    @State private var isStale = true
    @State private var poster: UIImage?
    @State private var savedToPhotos = false

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
            }
            .onDisappear { viewModel.cancel() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(store: store)
            }
            .sheet(isPresented: $showManualAlign) {
                if let data = frames.first?.imageData {
                    ManualAlignView(imageData: data, manual: $manual) {
                        isStale = true
                    }
                }
            }
        }
    }

    private var isRendering: Bool { viewModel.phase == .rendering }

    private var content: some View {
        ScrollView {
            VStack(spacing: 18) {
                previewArea

                VStack(spacing: 18) {
                    speedControl
                    aspectControl
                    transitionControl
                    alignmentControl
                    overlayControls
                }
                .disabled(isRendering)

                actionArea

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
        .onChange(of: overlay) { isStale = true }
        .onChange(of: viewModel.phase) {
            if case .finished(let url) = viewModel.phase {
                lastRenderedURL = url
                isStale = false
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .fill(theme.surface)

            switch viewModel.phase {
            case .rendering:
                VStack(spacing: 14) {
                    SpinningLogo(size: 88)
                    Text("Timelapse hazırlanıyor… %\(Int(viewModel.progress * 100))")
                        .font(Theme.caption(13))
                        .foregroundStyle(theme.inkMuted)
                }
            case .finished(let url):
                ExportedVideoPlayer(url: url)
                    .id(url)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            case .failed(let message):
                failedView(message)
            case .idle:
                posterPreview
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxHeight: 380)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var posterPreview: some View {
        ZStack {
            if let poster {
                Image(uiImage: poster).resizable().scaledToFill()
            }
            LinearGradient(colors: [.black.opacity(0.05), .black.opacity(0.45)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                Image(systemName: "film.stack")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Ayarları seç, sonra oluştur")
                    .font(Theme.caption(13))
                    .foregroundStyle(.white.opacity(0.92))
            }
        }
        .allowsHitTesting(false)
        .task(id: frames.last?.imageData.count) {
            poster = await ImageDownsampler.image(from: frames.last?.imageData, maxPixelSize: 800)
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        if isRendering {
            Button {} label: {
                HStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("Oluşturuluyor…")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.timelapsePrimary)
            .disabled(true)
        } else if case .finished(let url) = viewModel.phase, !isStale {
            VStack(spacing: 10) {
                ShareLink(item: url) {
                    Label("Videoyu Paylaş", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.timelapsePrimary)
                Button {
                    saveVideoToPhotos(url)
                } label: {
                    Label(savedToPhotos ? "Fotoğraflara kaydedildi" : "Fotoğraflara kaydet",
                          systemImage: savedToPhotos ? "checkmark.circle.fill" : "square.and.arrow.down")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(theme.accent)
                        .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(savedToPhotos)
                Button {
                    export()
                } label: {
                    Label("Yeniden Oluştur", systemImage: "arrow.clockwise")
                        .font(Theme.caption(13))
                        .foregroundStyle(theme.inkMuted)
                }
            }
        } else {
            VStack(spacing: 6) {
                Button {
                    export()
                } label: {
                    Label(createTitle, systemImage: "film.stack")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.timelapsePrimary)
                .disabled(frames.count < 2)
                if frames.count < 2 {
                    Text("Timelapse için en az 2 kare gerekli.")
                        .font(Theme.caption(12))
                        .foregroundStyle(theme.inkMuted)
                }
            }
        }
    }

    private var createTitle: LocalizedStringKey {
        if case .failed = viewModel.phase { return "Tekrar Dene" }
        return lastRenderedURL == nil ? "Timelapse Oluştur" : "Yeniden Oluştur"
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
                isStale = true
            }
        }
    }

    private var aspectControl: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Oran", systemImage: "aspectratio")
                    .font(Theme.caption(13))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
            }
            Picker("Oran", selection: $aspect) {
                ForEach(TimelapseAspect.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.phase == .rendering)
            .onChange(of: aspect) {
                isStale = true
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
            .onChange(of: transition) { isStale = true }
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
                if mode == .manual { showManualAlign = true } else { isStale = true }
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
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(theme.accent)
            Text(message)
                .font(Theme.body(14))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var alignmentSubject: AlignmentSubject {
        if project.isCoupleMode { return .group }
        switch project.category {
        case .fitness:   return .body
        case .pregnancy: return .belly
        default:         return .auto
        }
    }

    private func saveVideoToPhotos(_ url: URL) {
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        } completionHandler: { success, _ in
            Task { @MainActor in
                savedToPhotos = success
                UINotificationFeedbackGenerator().notificationOccurred(success ? .success : .error)
            }
        }
    }

    private func export() {
        savedToPhotos = false
        var effectiveOverlay = overlay
        if !store.isPro { effectiveOverlay.showAppMark = true }
        let proAlign = store.isPro
        viewModel.export(
            frames: frames,
            isPro: store.isPro,
            speed: speed,
            aspect: aspect,
            overlay: effectiveOverlay,
            smartAlignment: proAlign && alignMode == .smart,
            manualAnchor: (proAlign && alignMode == .manual) ? manual : nil,
            transition: transition,
            alignmentSubject: alignmentSubject
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

/// Manuel hizalama ekranı — WYSIWYG. Kutu, videonun çıktısıyla aynı (3:4) orandadır;
/// kullanıcı fotoğrafı SÜRÜKLEYEREK özneyi ortalar ve yakınlaştırmayı ayarlar. Kutuda
/// ne görüyorsa videoda o olur. Bu seçim tüm karelere uygulanır.
private struct ManualAlignView: View {
    let imageData: Data
    @Binding var manual: ManualAlignment
    let onDone: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @State private var uiImage: UIImage?
    @State private var dragStart: CGPoint?

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("Fotoğrafı sürükleyerek özneyi ortala")
                    .font(Theme.caption(13))
                    .foregroundStyle(theme.inkMuted)

                GeometryReader { geo in
                    ZStack {
                        Color.black
                        if let uiImage {
                            let disp = displaySize(image: uiImage.size, container: geo.size)
                            let point = CGPoint(x: manual.center.x * disp.width, y: manual.center.y * disp.height)
                            Image(uiImage: uiImage)
                                .resizable()
                                .frame(width: disp.width, height: disp.height)
                                .position(
                                    x: geo.size.width / 2 + disp.width / 2 - point.x,
                                    y: geo.size.height / 2 + disp.height / 2 - point.y
                                )
                        }
                        ThirdsReticle()
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard let uiImage else { return }
                                let disp = displaySize(image: uiImage.size, container: geo.size)
                                if dragStart == nil { dragStart = manual.center }
                                let start = dragStart ?? manual.center
                                let nx = start.x - value.translation.width / max(disp.width, 1)
                                let ny = start.y - value.translation.height / max(disp.height, 1)
                                manual.center = CGPoint(x: min(max(nx, 0), 1), y: min(max(ny, 0), 1))
                            }
                            .onEnded { _ in dragStart = nil }
                    )
                    .clipped()
                }
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                        .strokeBorder(theme.inkMuted.opacity(0.3), lineWidth: 1)
                )

                HStack(spacing: 12) {
                    Image(systemName: "minus.magnifyingglass").foregroundStyle(theme.inkMuted)
                    Slider(value: Binding(get: { Double(manual.zoom) }, set: { manual.zoom = CGFloat($0) }), in: 1...3)
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

    /// Görselin kutu içindeki gösterim boyutu: doldur (aspect-fill) × zoom. Composer'daki
    /// manualRect ile aynı mantık, böylece önizleme birebir çıktıyı gösterir.
    private func displaySize(image: CGSize, container: CGSize) -> CGSize {
        let fill = max(container.width / max(image.width, 1), container.height / max(image.height, 1))
        let scale = fill * max(manual.zoom, 0.2)
        return CGSize(width: image.width * scale, height: image.height * scale)
    }
}

/// Ortalamaya yardımcı hafif üçler kuralı + merkez nişangâhı.
private struct ThirdsReticle: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    for f in [1.0 / 3.0, 2.0 / 3.0] {
                        path.move(to: CGPoint(x: geo.size.width * f, y: 0))
                        path.addLine(to: CGPoint(x: geo.size.width * f, y: geo.size.height))
                        path.move(to: CGPoint(x: 0, y: geo.size.height * f))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * f))
                    }
                }
                .stroke(.white.opacity(0.28), lineWidth: 1)

                Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2).frame(width: 22, height: 22)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
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

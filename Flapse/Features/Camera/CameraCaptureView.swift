import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct CameraCaptureView: View {

    var project: Project? = nil
    var retakeEntry: Entry? = nil
    var onAutoCaptured: ((Data) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CameraCaptureViewModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let viewModel {
                CameraSessionView(viewModel: viewModel, isAuto: onAutoCaptured != nil)
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            guard viewModel == nil else { return }
            let model = CameraCaptureViewModel(
                camera: CameraService.shared,
                repository: ProjectRepository(context: modelContext),
                project: project,
                retakeEntry: retakeEntry,
                onCaptured: onAutoCaptured
            )
            viewModel = model
            await model.start()
        }
        .onDisappear { viewModel?.stop() }
    }
}

private struct CameraSessionView: View {

    let viewModel: CameraCaptureViewModel
    var isAuto: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(StoreService.self) private var store

    @State private var flashOpacity: Double = 0
    @State private var zoomGestureBase: CGFloat?

    /// Çift modu projeye bağlıdır (Birlikte Çekim kategorisi). Akıllı hizalama artık
    /// kamerada değil, dışa aktarımda yüz tespitiyle uygulanır.
    private var coupleMode: Bool { store.isPro && viewModel.isCoupleMode }

    private var isReady: Bool {
        viewModel.state == .ready || viewModel.state == .capturing
    }

    private var canInteract: Bool {
        viewModel.state == .ready && !viewModel.isSwitching
    }

    private var hasFailed: Bool {
        if case .failed = viewModel.state { return true }
        return false
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    Color.black

                    CameraPreview(session: viewModel.session, position: viewModel.position)
                        .gesture(zoomGesture)

                    if !hasFailed {
                        AlignmentGuideOverlay()
                    }

                    if !hasFailed, coupleMode {
                        CoupleSplitOverlay()
                    }
                }
            }
            .ignoresSafeArea()

            Color.white
                .opacity(flashOpacity)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if viewModel.state == .starting {
                ProgressView()
                    .tint(.white)
                    .controlSize(.large)
            }

            if case .failed(let message) = viewModel.state {
                errorOverlay(message)
            }

            VStack(spacing: 0) {
                topBar

                if !hasFailed, coupleMode {
                    activeModeChips
                        .padding(.top, 8)
                }

                Spacer()

                if !hasFailed {
                    zoomControls
                        .padding(.bottom, 12)
                    bottomBar
                }
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            ForEach(zoomPresets, id: \.self) { factor in
                Button {
                    viewModel.setZoomFactor(factor)
                } label: {
                    Text(zoomLabel(factor))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(abs(viewModel.zoomFactor - factor) < 0.05 ? .yellow : .white)
                        .frame(width: 42, height: 34)
                        .background(.black.opacity(0.42), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!canInteract)
            }
        }
    }

    private var zoomPresets: [CGFloat] {
        [viewModel.zoomRange.lowerBound, 1, 2, 5]
            .filter { viewModel.zoomRange.contains($0) }
            .reduce(into: []) { result, value in
                if !result.contains(where: { abs($0 - value) < 0.05 }) { result.append(value) }
            }
    }

    private func zoomLabel(_ factor: CGFloat) -> String {
        if abs(factor - factor.rounded()) < 0.01 {
            return "\(Int(factor.rounded()))×"
        }
        return String(format: "%.1f×", Double(factor))
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if zoomGestureBase == nil { zoomGestureBase = viewModel.zoomFactor }
                viewModel.setZoomFactor((zoomGestureBase ?? 1) * value)
            }
            .onEnded { _ in zoomGestureBase = nil }
    }

    private var topBar: some View {
        HStack {
            CameraControlButton(icon: "xmark", label: "Kapat") { dismiss() }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var bottomBar: some View {
        ZStack {
            shutterButton

            HStack {
                Color.clear.frame(width: 48, height: 48)
                Spacer()
                CameraControlButton(icon: "arrow.triangle.2.circlepath.camera", size: 48, label: "Kamerayı çevir") {
                    Task { await viewModel.flipCamera() }
                }
                .disabled(!canInteract)
                .opacity(canInteract ? 1 : 0.35)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background {
            if #available(iOS 26.0, *) {
                Rectangle().fill(.clear)
                    .glassEffect(.regular.tint(.black.opacity(0.35)), in: Rectangle())
                    .ignoresSafeArea(edges: .bottom)
            } else {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(.black.opacity(0.3))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    private var activeModeChips: some View {
        HStack(spacing: 8) {
            if coupleMode {
                modeChip("Çift modu", systemImage: "person.2.fill")
            }
        }
    }

    private func modeChip(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .liquidGlassBarCapsule()
            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
    }

    private var shutterButton: some View {
        Button {
            Task { await captureTapped() }
        } label: {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
                .frame(width: 74, height: 74)
                .overlay(Circle().fill(.white).frame(width: 60, height: 60))
        }
        .disabled(!canInteract)
        .opacity(canInteract ? 1 : 0.5)
    }

    private func captureTapped() async {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeIn(duration: 0.08)) { flashOpacity = 0.75 }
        let saved = await viewModel.capture()
        withAnimation(.easeOut(duration: 0.25)) { flashOpacity = 0 }
        if saved {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            if !isAuto { dismiss() }
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text(message)
                .multilineTextAlignment(.center)
            if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
                Button("Ayarları Aç") { PhotoLibrarySaver.openSettings() }
                    .buttonStyle(.flapsePrimary)
                    .frame(width: 200)
            }
            Button("Kapat") { dismiss() }
                .font(Theme.body(15))
                .foregroundStyle(.white.opacity(0.8))
        }
        .foregroundStyle(.white)
        .padding(24)
    }
}

private struct AlignmentGuideOverlay: View {
    var body: some View {
        ZStack {
            ThirdsGridShape()
                .stroke(.white.opacity(0.28), lineWidth: 1)
            CenterCrossShape()
                .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}

/// Çift modu (couple mode) kılavuzu: kareyi ikiye bölen dikey çizgi ve her yarı için
/// "kişi" etiketi. İki kişinin zamanla aynı çerçevede hizalanmasını kolaylaştırır.
private struct CoupleSplitOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 1.5)
                    .frame(maxHeight: .infinity)

                HStack(spacing: 0) {
                    coupleLabel("1")
                    coupleLabel("2")
                }
                .frame(width: geo.size.width)
                .padding(.top, 12)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .allowsHitTesting(false)
    }

    private func coupleLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(.black.opacity(0.35), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            .frame(maxWidth: .infinity)
    }
}

private struct ThirdsGridShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for fraction in [1.0 / 3.0, 2.0 / 3.0] {
            path.move(to: CGPoint(x: rect.width * fraction, y: 0))
            path.addLine(to: CGPoint(x: rect.width * fraction, y: rect.height))
            path.move(to: CGPoint(x: 0, y: rect.height * fraction))
            path.addLine(to: CGPoint(x: rect.width, y: rect.height * fraction))
        }
        return path
    }
}

private struct CenterCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let arm: CGFloat = 22
        var path = Path()
        path.move(to: CGPoint(x: center.x - arm, y: center.y))
        path.addLine(to: CGPoint(x: center.x + arm, y: center.y))
        path.move(to: CGPoint(x: center.x, y: center.y - arm))
        path.addLine(to: CGPoint(x: center.x, y: center.y + arm))
        return path
    }
}

struct CameraControlButton: View {
    let icon: String
    var size: CGFloat = 42
    var label: LocalizedStringKey = "Düğme"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .liquidGlassBarCircle()
        }
        .accessibilityLabel(Text(label))
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let position: AVCaptureDevice.Position

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        updateMirroring(for: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        updateMirroring(for: uiView)
    }

    private func updateMirroring(for view: PreviewView) {
        guard let connection = view.videoPreviewLayer.connection,
              connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = position == .front
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

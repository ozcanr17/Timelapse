import SwiftUI
import SwiftData
import AVFoundation
import UIKit

struct CameraCaptureView: View {

    let project: Project
    var retakeEntry: Entry? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CameraCaptureViewModel?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let viewModel {
                CameraSessionView(viewModel: viewModel)
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            guard viewModel == nil else { return }
            let model = CameraCaptureViewModel(
                camera: CameraService(),
                repository: ProjectRepository(context: modelContext),
                project: project,
                retakeEntry: retakeEntry
            )
            viewModel = model
            await model.start()
        }
        .onDisappear { viewModel?.stop() }
    }
}

private struct CameraSessionView: View {

    let viewModel: CameraCaptureViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @Environment(StoreService.self) private var store

    @AppStorage(PremiumFeature.smartAlignment.preferenceKey!) private var smartAlignmentPref = false
    @AppStorage(PremiumFeature.coupleMode.preferenceKey!) private var coupleModePref = false

    @State private var showGhost = false
    @State private var ghostImage: UIImage?
    @State private var ghostOpacity: Double = 0.35
    @State private var flashOpacity: Double = 0

    /// Pro özellikleri yalnızca gerçekten Pro isek ve tercih açıksa devreye girsin.
    private var smartAlignment: Bool { store.isPro && smartAlignmentPref }
    private var coupleMode: Bool { store.isPro && coupleModePref }

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

                    CameraPreview(session: viewModel.session)

                    if isReady, showGhost, let ghostImage {
                        Image(uiImage: ghostImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .saturation(0)
                            .opacity(ghostOpacity)
                            .allowsHitTesting(false)
                    }

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

                Spacer()

                if !hasFailed {
                    if showGhost, ghostImage != nil {
                        ghostOpacitySlider
                            .padding(.bottom, 14)
                    }
                    bottomBar
                }
            }
        }
        .task {
            ghostImage = await ImageDownsampler.image(from: viewModel.ghostImageData, maxPixelSize: 1400)
            if smartAlignment, viewModel.ghostImageData != nil {
                showGhost = true
            }
        }
    }

    private var topBar: some View {
        HStack {
            CameraControlButton(icon: "xmark") { dismiss() }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var ghostOpacitySlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.dashed")
            Slider(value: $ghostOpacity, in: 0.1...0.8)
            Image(systemName: "circle.fill")
        }
        .foregroundStyle(.white)
        .tint(theme.accent)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.horizontal, 36)
    }

    private var bottomBar: some View {
        ZStack {
            shutterButton

            HStack {
                thumbnailButton
                Spacer()
                CameraControlButton(icon: "arrow.triangle.2.circlepath.camera", size: 48) {
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
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var thumbnailButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                showGhost.toggle()
            }
        } label: {
            ZStack {
                if let ghostImage {
                    Image(uiImage: ghostImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white.opacity(0.1))
                    Image(systemName: "photo")
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        showGhost ? theme.accent : .white.opacity(0.3),
                        lineWidth: showGhost ? 2 : 1
                    )
            )
        }
        .disabled(ghostImage == nil)
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
            dismiss()
        }
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Kapat") { dismiss() }
                .buttonStyle(.timelapsePrimary)
                .frame(width: 160)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

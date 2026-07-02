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

private enum CameraOverlayMode: String, CaseIterable, Identifiable {
    case ghost
    case guide
    case off

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .ghost: "photo.on.rectangle"
        case .guide: "grid"
        case .off:   "circle.slash"
        }
    }

    var label: String {
        switch self {
        case .ghost: "Ghost"
        case .guide: "Kılavuz"
        case .off:   "Kapalı"
        }
    }
}

private struct CameraSessionView: View {

    let viewModel: CameraCaptureViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var overlayMode: CameraOverlayMode = .guide
    @State private var ghostImage: UIImage?
    @State private var ghostOpacity: Double = 0.35
    @State private var flashOpacity: Double = 0

    private var isReady: Bool {
        viewModel.state == .ready || viewModel.state == .capturing
    }

    private var canInteract: Bool {
        viewModel.state == .ready && !viewModel.isSwitching
    }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                ZStack {
                    Color.black

                    CameraPreview(session: viewModel.session)

                    if isReady, overlayMode == .ghost, let ghostImage {
                        Image(uiImage: ghostImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .saturation(0)
                            .opacity(ghostOpacity)
                            .allowsHitTesting(false)
                    }

                    if isReady, overlayMode == .guide {
                        AlignmentGuideOverlay(category: viewModel.projectCategory)
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
                if isReady {
                    controls
                }
            }
        }
        .task {
            ghostImage = await ImageDownsampler.image(from: viewModel.ghostImageData, maxPixelSize: 1400)
            if ghostImage != nil { overlayMode = .ghost }
        }
    }

    private var topBar: some View {
        HStack {
            CameraControlButton(icon: "xmark") { dismiss() }
            Spacer()
            CameraControlButton(icon: "arrow.triangle.2.circlepath.camera") {
                Task { await viewModel.flipCamera() }
            }
            .disabled(!canInteract)
            .opacity(canInteract ? 1 : 0.35)
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            overlayModePicker

            if overlayMode == .ghost, ghostImage != nil {
                ghostOpacitySlider
            }

            shutterButton
        }
        .padding(.bottom, 24)
    }

    private var overlayModePicker: some View {
        HStack(spacing: 8) {
            ForEach(availableModes) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { overlayMode = mode }
                } label: {
                    Label(mode.label, systemImage: mode.icon)
                        .font(Theme.caption(12))
                        .foregroundStyle(overlayMode == mode ? .black : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            overlayMode == mode ? AnyShapeStyle(.white) : AnyShapeStyle(.black.opacity(0.35)),
                            in: Capsule()
                        )
                }
            }
        }
    }

    private var availableModes: [CameraOverlayMode] {
        ghostImage == nil
            ? [.guide, .off]
            : CameraOverlayMode.allCases
    }

    private var ghostOpacitySlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.dashed")
            Slider(value: $ghostOpacity, in: 0.1...0.8)
            Image(systemName: "circle.fill")
        }
        .foregroundStyle(.white)
        .tint(theme.accent)
        .padding(.horizontal, 48)
    }

    private var shutterButton: some View {
        Button {
            Task { await captureTapped() }
        } label: {
            Circle()
                .strokeBorder(.white, lineWidth: 4)
                .frame(width: 76, height: 76)
                .overlay(Circle().fill(.white).frame(width: 62, height: 62))
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
    let category: ProjectCategory

    private var showsSilhouette: Bool {
        switch category {
        case .selfPortrait, .hairAndBeard, .child: true
        default: false
        }
    }

    var body: some View {
        ZStack {
            ThirdsGridShape()
                .stroke(.white.opacity(0.28), lineWidth: 1)

            if showsSilhouette {
                HeadGuideShape()
                    .stroke(
                        .white.opacity(0.6),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                HeadGuideDashesShape()
                    .stroke(
                        .white.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [6, 6])
                    )
            } else {
                CenterCrossShape()
                    .stroke(.white.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }
}

private func headGuideBox(in rect: CGRect) -> CGRect {
    let width = rect.width * 0.58
    let height = width * 1.3
    return CGRect(
        x: rect.midX - width / 2,
        y: rect.height * 0.40 - height / 2,
        width: width,
        height: height
    )
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

private struct HeadGuideShape: Shape {
    func path(in rect: CGRect) -> Path {
        let box = headGuideBox(in: rect)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height)
        }

        var path = Path()
        path.move(to: pt(0.5, 0.76))
        path.addCurve(to: pt(0.77, 0.42), control1: pt(0.67, 0.73), control2: pt(0.74, 0.58))
        path.addCurve(to: pt(0.5, 0.03), control1: pt(0.82, 0.19), control2: pt(0.70, 0.03))
        path.addCurve(to: pt(0.23, 0.42), control1: pt(0.30, 0.03), control2: pt(0.18, 0.19))
        path.addCurve(to: pt(0.5, 0.76), control1: pt(0.26, 0.58), control2: pt(0.33, 0.73))

        path.move(to: pt(0.78, 0.40))
        path.addCurve(to: pt(0.77, 0.57), control1: pt(0.89, 0.37), control2: pt(0.87, 0.58))
        path.move(to: pt(0.22, 0.40))
        path.addCurve(to: pt(0.23, 0.57), control1: pt(0.11, 0.37), control2: pt(0.13, 0.58))

        path.move(to: pt(0.61, 0.72))
        path.addCurve(to: pt(0.64, 1.0), control1: pt(0.61, 0.83), control2: pt(0.62, 0.93))
        path.move(to: pt(0.39, 0.72))
        path.addCurve(to: pt(0.36, 1.0), control1: pt(0.39, 0.83), control2: pt(0.38, 0.93))

        return path
    }
}

private struct HeadGuideDashesShape: Shape {
    func path(in rect: CGRect) -> Path {
        let box = headGuideBox(in: rect)
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height)
        }

        var path = Path()
        path.move(to: pt(0.5, -0.06))
        path.addLine(to: pt(0.5, 1.04))

        path.move(to: pt(0.18, 0.46))
        path.addQuadCurve(to: pt(0.82, 0.46), control: pt(0.5, 0.38))

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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(.black.opacity(0.35), in: Circle())
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

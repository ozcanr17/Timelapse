import SwiftUI
import AVFoundation
import UIKit   // UIImage için

/// Tam ekran kamera çekim ekranı: canlı önizleme + ghost + hizalama nişangahı.
struct CameraCaptureView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CameraCaptureViewModel
    @State private var ghostOpacity: Double = 0.4

    init(camera: CameraServiceProtocol, repository: ProjectRepositoryProtocol, project: Project) {
        _viewModel = State(initialValue: CameraCaptureViewModel(
            camera: camera, repository: repository, project: project
        ))
    }

    var body: some View {
        // GeometryReader bize alanın boyutunu verir; referans noktasını bu boyuta göre
        // hem yerleştiriyor hem de dokunmadan normalize ediyoruz.
        GeometryReader { geo in
            ZStack {
                Color.black

                // 1) Canlı kamera önizlemesi.
                CameraPreview(session: viewModel.session)

                // 2) Ghost bindirmesi (varsa).
                if let data = viewModel.ghostImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .opacity(ghostOpacity)
                        .allowsHitTesting(false)
                }

                // 3) Dokunma katmanı: boş alana dokununca referans noktasını taşır.
                //    Kontrollerin ALTINDA, önizlemenin ÜSTÜNDE.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { location in
                        viewModel.setAnchor(NormalizedPoint.from(location, in: geo.size))
                    }

                // 4) Hizalama nişangahı (referans noktası) — yalnızca görsel.
                ReticleView()
                    .position(viewModel.referenceAnchor.cgPoint(in: geo.size))
                    .allowsHitTesting(false)

                // 5) Duruma göre kontroller (en üstte; dokunuşları o alır).
                switch viewModel.state {
                case .starting:
                    ProgressView().tint(.white)
                case .failed(let message):
                    errorOverlay(message)
                case .ready, .capturing:
                    controls
                }
            }
        }
        .ignoresSafeArea()
        .task { await viewModel.start() }
        .onDisappear { viewModel.stop() }
    }

    private var controls: some View {
        VStack {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding()
                }
                Spacer()
            }

            Text("Hizalamak için bir referans noktasına dokun")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            // Ghost saydamlık ayarı — yalnızca ghost varken.
            if viewModel.ghostImageData != nil {
                ghostOpacitySlider
            }

            // Deklanşör.
            Button {
                Task { if await viewModel.capture() { dismiss() } }
            } label: {
                Circle()
                    .strokeBorder(.white, lineWidth: 4)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().fill(.white).frame(width: 62, height: 62))
            }
            .disabled(viewModel.state == .capturing)
            .padding(.bottom, 40)
        }
    }

    private var ghostOpacitySlider: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.dashed")   // az ghost
            Slider(value: $ghostOpacity, in: 0...1)
            Image(systemName: "circle.fill")     // çok ghost
        }
        .foregroundStyle(.white)
        .tint(.white)
        .padding(.horizontal, 32)
        .padding(.bottom, 12)
    }

    private func errorOverlay(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Kapat") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding()
    }
}

/// Referans noktasını gösteren sarı nişangah.
private struct ReticleView: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(.yellow, lineWidth: 2).frame(width: 46, height: 46)
            Rectangle().fill(.yellow).frame(width: 2, height: 14)
            Rectangle().fill(.yellow).frame(width: 14, height: 2)
        }
        .shadow(color: .black.opacity(0.5), radius: 2)
    }
}

/// AVFoundation'ın canlı önizleme katmanını (UIKit) SwiftUI'a köprüleyen sarmalayıcı.
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

import SwiftUI
import UIKit

struct PhotoCropView: View {

    let imageData: Data?
    let onCropped: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var image: UIImage?
    @State private var zoom: CGFloat = 1
    @State private var pinchBase: CGFloat?
    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize?
    @State private var cropDisplaySize = CGSize(width: 1, height: 1)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { proxy in
                if let image {
                    let frame = cropFrame(in: proxy.size, aspect: image.size.width / image.size.height)
                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: frame.width, height: frame.height)
                            .scaleEffect(zoom)
                            .offset(offset)
                            .frame(width: frame.width, height: frame.height)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .contentShape(Rectangle())
                            .gesture(zoomGesture(frame: frame))
                            .simultaneousGesture(panGesture(frame: frame))
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                            .frame(width: frame.width, height: frame.height)
                            .allowsHitTesting(false)
                        gridLines
                            .frame(width: frame.width, height: frame.height)
                            .allowsHitTesting(false)
                    }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .onAppear { cropDisplaySize = frame }
                    .onChange(of: proxy.size) { cropDisplaySize = frame }
                } else {
                    ProgressView()
                        .tint(.white)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 90)

            VStack {
                HStack {
                    Button("Vazgeç") { dismiss() }
                        .font(Theme.body(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Kırp")
                        .font(Theme.headline(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Sıfırla") { reset() }
                        .font(Theme.body(16))
                        .foregroundStyle(.white.opacity(zoom > 1 || offset != .zero ? 1 : 0.4))
                        .disabled(zoom <= 1 && offset == .zero)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
                Button {
                    confirm()
                } label: {
                    Label("Kaydet", systemImage: "checkmark")
                        .font(Theme.headline(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(theme.accent, in: Capsule())
                }
                .disabled(image == nil)
                .padding(.bottom, 20)
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            image = await ImageDownsampler.image(from: imageData, maxPixelSize: 4000)
        }
    }

    private var gridLines: some View {
        ZStack {
            HStack {
                Spacer()
                Rectangle().fill(.white.opacity(0.18)).frame(width: 0.5)
                Spacer()
                Rectangle().fill(.white.opacity(0.18)).frame(width: 0.5)
                Spacer()
            }
            VStack {
                Spacer()
                Rectangle().fill(.white.opacity(0.18)).frame(height: 0.5)
                Spacer()
                Rectangle().fill(.white.opacity(0.18)).frame(height: 0.5)
                Spacer()
            }
        }
    }

    private func cropFrame(in container: CGSize, aspect: CGFloat) -> CGSize {
        guard container.width > 0, container.height > 0, aspect > 0 else { return .zero }
        let width = min(container.width, container.height * aspect)
        return CGSize(width: width, height: width / aspect)
    }

    private func maxOffset(frame: CGSize) -> CGSize {
        CGSize(
            width: frame.width * (zoom - 1) / 2,
            height: frame.height * (zoom - 1) / 2
        )
    }

    private func clampOffset(_ proposed: CGSize, frame: CGSize) -> CGSize {
        let limit = maxOffset(frame: frame)
        return CGSize(
            width: min(max(proposed.width, -limit.width), limit.width),
            height: min(max(proposed.height, -limit.height), limit.height)
        )
    }

    private func zoomGesture(frame: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchBase == nil { pinchBase = zoom }
                zoom = min(max((pinchBase ?? 1) * value, 1), 6)
                offset = clampOffset(offset, frame: frame)
            }
            .onEnded { _ in
                pinchBase = nil
                if zoom <= 1.02 {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                        zoom = 1
                        offset = .zero
                    }
                }
            }
    }

    private func panGesture(frame: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil { dragBase = offset }
                let base = dragBase ?? .zero
                let proposed = CGSize(
                    width: base.width + value.translation.width,
                    height: base.height + value.translation.height
                )
                offset = clampOffset(proposed, frame: frame)
            }
            .onEnded { _ in dragBase = nil }
    }

    private func reset() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            zoom = 1
            offset = .zero
        }
    }

    private func confirm() {
        guard let image, let cropped = croppedData(from: image) else {
            dismiss()
            return
        }
        onCropped(cropped)
        dismiss()
    }

    private func croppedData(from image: UIImage) -> Data? {
        guard zoom > 1.001 || offset != .zero else { return nil }
        guard let cgImage = image.cgImage else { return nil }
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let visibleWidth = width / zoom
        let visibleHeight = height / zoom
        let centerX = width / 2 - offset.width / zoom * (width / max(cropDisplaySize.width, 1))
        let centerY = height / 2 - offset.height / zoom * (height / max(cropDisplaySize.height, 1))
        var rect = CGRect(
            x: centerX - visibleWidth / 2,
            y: centerY - visibleHeight / 2,
            width: visibleWidth,
            height: visibleHeight
        )
        rect.origin.x = min(max(rect.origin.x, 0), width - rect.width)
        rect.origin.y = min(max(rect.origin.y, 0), height - rect.height)
        guard let croppedCG = cgImage.cropping(to: rect.integral) else { return nil }
        return UIImage(cgImage: croppedCG, scale: 1, orientation: .up).jpegData(compressionQuality: 0.9)
    }
}

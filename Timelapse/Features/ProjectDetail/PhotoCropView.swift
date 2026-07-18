import SwiftUI
import UIKit
import CoreImage

struct PhotoEditView: View {

    let imageData: Data?
    let onEdited: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    @State private var originalImage: UIImage?
    @State private var image: UIImage?
    @State private var zoom: CGFloat = 1
    @State private var pinchBase: CGFloat?
    @State private var offset: CGSize = .zero
    @State private var dragBase: CGSize?
    @State private var cropDisplaySize = CGSize(width: 1, height: 1)
    @State private var hasTransformChanges = false
    @State private var isProcessing = false

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
                            .allowsHitTesting(!isProcessing)
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
                    Text("Düzenle")
                        .font(Theme.headline(16))
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Sıfırla") { reset() }
                        .font(Theme.body(16))
                        .foregroundStyle(.white.opacity(hasChanges ? 1 : 0.4))
                        .disabled(!hasChanges || isProcessing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                Spacer()
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        editControl("Yatay Çevir", icon: "arrow.left.and.right") {
                            apply(.horizontalFlip)
                        }
                        editControl("Dikey Çevir", icon: "arrow.up.and.down") {
                            apply(.verticalFlip)
                        }
                        editControl("90° Döndür", icon: "rotate.right") {
                            apply(.rotateClockwise)
                        }
                    }
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
                    .disabled(image == nil || isProcessing)
                }
                .padding(.bottom, 20)
            }
        }
        .environment(\.colorScheme, .dark)
        .task {
            let loaded = await ImageDownsampler.image(from: imageData, maxPixelSize: 4000)
            originalImage = loaded
            image = loaded
        }
    }

    private var hasChanges: Bool {
        hasTransformChanges || zoom > 1.001 || offset != .zero
    }

    private func editControl(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(image == nil || isProcessing)
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
            image = originalImage
            zoom = 1
            offset = .zero
            hasTransformChanges = false
        }
    }

    private func apply(_ operation: PhotoEditOperation) {
        guard let image, !isProcessing else { return }
        isProcessing = true
        Task {
            let edited = await Task.detached(priority: .userInitiated) {
                PhotoImageEditor.apply(operation, to: image)
            }.value
            self.image = edited
            zoom = 1
            offset = .zero
            hasTransformChanges = true
            isProcessing = false
        }
    }

    private func confirm() {
        guard let image else {
            dismiss()
            return
        }
        guard hasChanges else {
            dismiss()
            return
        }
        guard let edited = editedData(from: image) else { return }
        onEdited(edited)
        dismiss()
    }

    private func editedData(from image: UIImage) -> Data? {
        guard zoom > 1.001 || offset != .zero else {
            return image.jpegData(compressionQuality: 0.9)
        }
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

enum PhotoEditOperation: Equatable, Sendable {
    case horizontalFlip
    case verticalFlip
    case rotateClockwise
}

enum PhotoImageEditor {
    static func apply(_ operation: PhotoEditOperation, to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        if operation == .horizontalFlip {
            let source = CIImage(cgImage: cgImage)
            let transformed = source.transformed(by: CGAffineTransform(scaleX: -1, y: 1))
            let normalized = transformed.transformed(
                by: CGAffineTransform(translationX: -transformed.extent.minX, y: 0)
            )
            let bounds = CGRect(origin: .zero, size: transformed.extent.size)
            guard let output = context.createCGImage(normalized, from: bounds) else { return image }
            return UIImage(cgImage: output)
        }
        let orientation: UIImage.Orientation
        switch operation {
        case .horizontalFlip:
            return image
        case .verticalFlip:
            orientation = .downMirrored
        case .rotateClockwise:
            orientation = .right
        }
        let oriented = UIImage(cgImage: cgImage, scale: 1, orientation: orientation)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: oriented.size, format: format).image { _ in
            oriented.draw(in: CGRect(origin: .zero, size: oriented.size))
        }
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])
}

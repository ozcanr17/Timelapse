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
    @State private var cropAspect: PhotoCropAspect = .free
    @State private var freeAspect: CGFloat?
    @State private var freeAspectBase: CGFloat?
    @State private var operations: [PhotoEditOperation] = []
    @State private var isProcessing = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { proxy in
                if let image {
                    let frame = cropFrame(
                        in: proxy.size,
                        aspect: cropAspect.ratio(for: image.size, freeAspect: freeAspect)
                    )
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
                            .gesture(zoomGesture(frame: frame, imageSize: image.size))
                            .simultaneousGesture(panGesture(frame: frame, imageSize: image.size))
                            .allowsHitTesting(!isProcessing)
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                            .frame(width: frame.width, height: frame.height)
                            .allowsHitTesting(false)
                        gridLines
                            .frame(width: frame.width, height: frame.height)
                            .allowsHitTesting(false)
                    }
                    .frame(width: frame.width, height: frame.height)
                    .overlay(alignment: .bottomTrailing) {
                        if cropAspect == .free {
                            freeCropHandle(imageSize: image.size)
                                .offset(x: 10, y: 10)
                        }
                    }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    .onAppear { cropDisplaySize = frame }
                    .onChange(of: frame) { _, newFrame in cropDisplaySize = newFrame }
                } else {
                    ProgressView()
                        .tint(.white)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 70)
            .padding(.bottom, 20)

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
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { editorControls }
        .environment(\.colorScheme, .dark)
        .task {
            let loaded = await ImageDownsampler.image(from: imageData, maxPixelSize: 4000)
            originalImage = loaded
            image = loaded
        }
    }

    private var hasChanges: Bool {
        !operations.isEmpty || cropAspect != .free || hasFreeCropChange || zoom > 1.001 || offset != .zero
    }

    private var hasFreeCropChange: Bool {
        guard cropAspect == .free, let image, let freeAspect else { return false }
        let original = image.size.width / max(image.size.height, 1)
        return abs(freeAspect - original) > 0.001
    }

    private var editorControls: some View {
        VStack(spacing: 12) {
            aspectControl
            HStack(spacing: 10) {
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
                    .font(Theme.headline(16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(image == nil || isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private var aspectControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Oran", systemImage: "aspectratio")
                .font(Theme.caption(12))
                .foregroundStyle(.white.opacity(0.7))
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(PhotoCropAspect.allCases) { option in
                        Button {
                            selectAspect(option)
                        } label: {
                            Text(option.title)
                                .font(Theme.caption(13))
                                .foregroundStyle(cropAspect == option ? .white : .white.opacity(0.72))
                                .padding(.horizontal, 13)
                                .frame(height: 34)
                                .background(
                                    cropAspect == option ? theme.accent : .white.opacity(0.1),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(image == nil || isProcessing)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
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
            .frame(minHeight: 54)
            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(image == nil || isProcessing)
    }

    private func freeCropHandle(imageSize: CGSize) -> some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(theme.accent, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.8), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
            .contentShape(Circle())
            .gesture(freeCropGesture(imageSize: imageSize))
            .accessibilityLabel(Text("Serbest"))
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

    private func maxOffset(frame: CGSize, imageSize: CGSize) -> CGSize {
        PhotoCropGeometry.maxOffset(
            imageSize: imageSize,
            displaySize: frame,
            zoom: zoom
        )
    }

    private func clampOffset(_ proposed: CGSize, frame: CGSize, imageSize: CGSize) -> CGSize {
        let limit = maxOffset(frame: frame, imageSize: imageSize)
        return CGSize(
            width: min(max(proposed.width, -limit.width), limit.width),
            height: min(max(proposed.height, -limit.height), limit.height)
        )
    }

    private func zoomGesture(frame: CGSize, imageSize: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchBase == nil { pinchBase = zoom }
                zoom = min(max((pinchBase ?? 1) * value, 1), 6)
                offset = clampOffset(offset, frame: frame, imageSize: imageSize)
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

    private func panGesture(frame: CGSize, imageSize: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBase == nil { dragBase = offset }
                let base = dragBase ?? .zero
                let proposed = CGSize(
                    width: base.width + value.translation.width,
                    height: base.height + value.translation.height
                )
                offset = clampOffset(proposed, frame: frame, imageSize: imageSize)
            }
            .onEnded { _ in dragBase = nil }
    }

    private func reset() {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
            image = originalImage
            zoom = 1
            offset = .zero
            cropAspect = .free
            freeAspect = nil
            freeAspectBase = nil
            operations = []
        }
    }

    private func selectAspect(_ aspect: PhotoCropAspect) {
        withAnimation(.easeInOut(duration: 0.22)) {
            cropAspect = aspect
            freeAspect = nil
            zoom = 1
            offset = .zero
        }
    }

    private func freeCropGesture(imageSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if freeAspectBase == nil {
                    freeAspectBase = cropAspect.ratio(for: imageSize, freeAspect: freeAspect)
                }
                freeAspect = PhotoCropGeometry.adjustedFreeAspect(
                    base: freeAspectBase ?? 1,
                    translation: value.translation
                )
                zoom = 1
                offset = .zero
            }
            .onEnded { _ in freeAspectBase = nil }
    }

    private func apply(_ operation: PhotoEditOperation) {
        guard let image, !isProcessing else { return }
        isProcessing = true
        Task {
            let edited = await Task.detached(priority: .userInitiated) {
                PhotoImageEditor.apply(operation, to: image)
            }.value
            self.image = edited
            operations.append(operation)
            zoom = 1
            offset = .zero
            isProcessing = false
        }
    }

    private func confirm() {
        guard let image, let imageData else {
            dismiss()
            return
        }
        guard hasChanges else {
            dismiss()
            return
        }
        isProcessing = true
        let operations = operations
        let aspect = cropAspect.ratio(for: image.size, freeAspect: freeAspect)
        let shouldCrop = cropAspect != .free || hasFreeCropChange || zoom > 1.001 || offset != .zero
        let zoom = zoom
        let offset = offset
        let displaySize = cropDisplaySize
        Task {
            let edited = await Task.detached(priority: .userInitiated) {
                PhotoImageEditor.render(
                    data: imageData,
                    operations: operations,
                    cropAspect: aspect,
                    zoom: zoom,
                    offset: offset,
                    displaySize: displaySize,
                    shouldCrop: shouldCrop
                )
            }.value
            isProcessing = false
            guard let edited else { return }
            onEdited(edited)
            dismiss()
        }
    }
}

enum PhotoCropAspect: String, CaseIterable, Identifiable {
    case free
    case nineSixteen
    case fourThree
    case threeFour
    case sixteenNine

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .free: "Serbest"
        case .nineSixteen: "9:16"
        case .fourThree: "4:3"
        case .threeFour: "3:4"
        case .sixteenNine: "16:9"
        }
    }

    func ratio(for imageSize: CGSize, freeAspect: CGFloat? = nil) -> CGFloat {
        switch self {
        case .free: freeAspect ?? imageSize.width / max(imageSize.height, 1)
        case .nineSixteen: 9.0 / 16.0
        case .fourThree: 4.0 / 3.0
        case .threeFour: 3.0 / 4.0
        case .sixteenNine: 16.0 / 9.0
        }
    }
}

enum PhotoCropGeometry {
    static func adjustedFreeAspect(base: CGFloat, translation: CGSize) -> CGFloat {
        let horizontal = max(0.2, 1 + translation.width / 180)
        let vertical = max(0.2, 1 + translation.height / 180)
        return min(max(base * horizontal / vertical, 0.4), 2.5)
    }

    static func maxOffset(imageSize: CGSize, displaySize: CGSize, zoom: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0,
              displaySize.width > 0, displaySize.height > 0 else { return .zero }
        let scale = max(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        return CGSize(
            width: max(0, imageSize.width * scale * zoom - displaySize.width) / 2,
            height: max(0, imageSize.height * scale * zoom - displaySize.height) / 2
        )
    }

    static func cropRect(
        imageSize: CGSize,
        cropAspect: CGFloat,
        zoom: CGFloat,
        offset: CGSize,
        displaySize: CGSize
    ) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              cropAspect > 0, displaySize.width > 0, displaySize.height > 0 else { return .zero }
        let scale = max(displaySize.width / imageSize.width, displaySize.height / imageSize.height)
        let effectiveScale = scale * max(zoom, 1)
        let visibleWidth = min(imageSize.width, displaySize.width / effectiveScale)
        let visibleHeight = min(imageSize.height, visibleWidth / cropAspect)
        let centerX = imageSize.width / 2 - offset.width / effectiveScale
        let centerY = imageSize.height / 2 - offset.height / effectiveScale
        let originX = min(max(centerX - visibleWidth / 2, 0), imageSize.width - visibleWidth)
        let originY = min(max(centerY - visibleHeight / 2, 0), imageSize.height - visibleHeight)
        return CGRect(x: originX, y: originY, width: visibleWidth, height: visibleHeight)
    }
}

enum PhotoEditOperation: Equatable, Sendable {
    case horizontalFlip
    case verticalFlip
    case rotateClockwise
}

enum PhotoImageEditor {
    static func render(
        data: Data,
        operations: [PhotoEditOperation],
        cropAspect: CGFloat,
        zoom: CGFloat,
        offset: CGSize,
        displaySize: CGSize,
        shouldCrop: Bool
    ) -> Data? {
        autoreleasepool {
            guard let source = UIImage(data: data) else { return nil }
            var image = normalized(source)
            for operation in operations {
                image = apply(operation, to: image)
            }
            if shouldCrop {
                guard let cgImage = image.cgImage else { return nil }
                let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
                let rect = PhotoCropGeometry.cropRect(
                    imageSize: imageSize,
                    cropAspect: cropAspect,
                    zoom: zoom,
                    offset: offset,
                    displaySize: displaySize
                )
                guard let cropped = cgImage.cropping(to: rect.integral) else { return nil }
                image = UIImage(cgImage: cropped, scale: 1, orientation: .up)
            }
            return image.jpegData(compressionQuality: 0.95)
        }
    }

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

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private static let context = CIContext(options: [.cacheIntermediates: false])
}

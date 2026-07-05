import AVFoundation
import UIKit

/// Timelapse oynatma hızı. Kare hızını (fps) belirler; daha yüksek fps daha hızlı,
/// akıcı bir video demek. Herkese açık bir özellik — Pro gerektirmez.
enum TimelapseSpeed: String, CaseIterable, Identifiable {
    case quarter
    case slow
    case normal
    case fast
    case turbo

    var id: String { rawValue }

    /// Saniyedeki kare sayısı. `normal` mevcut varsayılanı (8 fps) korur.
    var framesPerSecond: Int32 {
        switch self {
        case .quarter: 2
        case .slow:    4
        case .normal:  8
        case .fast:    16
        case .turbo:   24
        }
    }

    /// Segmentli seçicide gösterilen çarpan etiketi.
    var displayName: String {
        switch self {
        case .quarter: "0.25×"
        case .slow:    "0.5×"
        case .normal:  "1×"
        case .fast:    "2×"
        case .turbo:   "3×"
        }
    }
}

/// Bir bindirmenin (tarih/not/uygulama etiketi) videonun hangi köşesine yerleşeceği.
enum OverlayCorner: String, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft:     String(localized: "Sol üst")
        case .topRight:    String(localized: "Sağ üst")
        case .bottomLeft:  String(localized: "Sol alt")
        case .bottomRight: String(localized: "Sağ alt")
        }
    }

    /// Metni köşeye hizalayan sol-üst çizim noktası (UIKit koordinatları).
    func origin(textSize: CGSize, canvas: CGSize, margin: CGFloat) -> CGPoint {
        let x: CGFloat
        switch self {
        case .topLeft, .bottomLeft:   x = margin
        case .topRight, .bottomRight: x = canvas.width - textSize.width - margin
        }
        let y: CGFloat
        switch self {
        case .topLeft, .topRight:       y = margin
        case .bottomLeft, .bottomRight: y = canvas.height - textSize.height - margin
        }
        return CGPoint(x: x, y: y)
    }
}

/// Kullanıcının videoya eklediği metin bindirmeleri. Tarih ve not konumu seçilebilir
/// (ve asla aynı köşeye düşmez). Uygulama etiketi her zaman SAĞ ALT köşededir; konumu
/// değiştirilemez, yalnızca Pro kullanıcı gizleyebilir.
struct TimelapseOverlayOptions: Equatable {
    var showDate: Bool = false
    var datePosition: OverlayCorner = .topLeft
    var note: String = ""
    var notePosition: OverlayCorner = .topRight
    var showAppMark: Bool = true

    /// Uygulama etiketinin sabit konumu.
    static let appMarkCorner: OverlayCorner = .bottomRight
}

/// Videoya girecek tek kare: görsel veri + çekildiği tarih (tarih bindirmesi için).
struct TimelapseFrame: Equatable {
    let imageData: Data
    let capturedAt: Date
}

struct TimelapseExportSettings: Equatable {
    let renderSize: CGSize
    let framesPerSecond: Int32
    let includesWatermark: Bool          // ücretsiz katmanda uygulama etiketi zorunlu
    var overlay: TimelapseOverlayOptions = TimelapseOverlayOptions()
    /// Akıllı Hizalama (Pro): dışa aktarımda özneyi yüz tespitiyle karelere sabitler.
    var smartAlignment: Bool = false

    static func current(
        isPro: Bool,
        speed: TimelapseSpeed = .normal,
        overlay: TimelapseOverlayOptions = TimelapseOverlayOptions(),
        smartAlignment: Bool = false
    ) -> TimelapseExportSettings {
        if FeatureGate.isUnlocked(.highResExport, isPro: isPro) {
            TimelapseExportSettings(
                renderSize: CGSize(width: 2160, height: 2880),
                framesPerSecond: speed.framesPerSecond,
                includesWatermark: false,
                overlay: overlay,
                smartAlignment: smartAlignment
            )
        } else {
            TimelapseExportSettings(
                renderSize: CGSize(width: 720, height: 960),
                framesPerSecond: speed.framesPerSecond,
                includesWatermark: true,
                overlay: overlay,
                smartAlignment: smartAlignment
            )
        }
    }
}

enum TimelapseComposerError: Error, Equatable {
    case notEnoughFrames
    case frameDecodingFailed
    case writerFailed
}

protocol TimelapseComposing {
    func makeVideo(
        from frames: [TimelapseFrame],
        settings: TimelapseExportSettings,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

struct TimelapseComposer: TimelapseComposing {

    func makeVideo(
        from frames: [TimelapseFrame],
        settings: TimelapseExportSettings,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard frames.count >= 2 else { throw TimelapseComposerError.notEnoughFrames }
        return try await Task.detached(priority: .userInitiated) {
            try Self.render(frames: frames, settings: settings, onProgress: onProgress)
        }.value
    }

    private static func render(
        frames: [TimelapseFrame],
        settings: TimelapseExportSettings,
        onProgress: @Sendable (Double) -> Void
    ) throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timelapse-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        let width = Int(settings.renderSize.width)
        let height = Int(settings.renderSize.height)

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(input)

        guard writer.startWriting() else { throw TimelapseComposerError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        // Akıllı Hizalama: her karedeki yüz çıpasını bul; ilk bulunan referans olur.
        let anchors: [FrameAnchor?] = settings.smartAlignment
            ? frames.map { FrameAligner.anchor(in: $0.imageData) }
            : Array(repeating: nil, count: frames.count)
        let reference = anchors.compactMap { $0 }.first

        for (index, frame) in frames.enumerated() {
            guard
                let image = UIImage(data: frame.imageData),
                let composed = composeFrame(
                    image,
                    date: frame.capturedAt,
                    anchor: anchors[index],
                    reference: reference,
                    settings: settings
                )
            else { throw TimelapseComposerError.frameDecodingFailed }

            while !input.isReadyForMoreMediaData { usleep(3000) }

            let buffer = try pixelBuffer(for: composed, adaptor: adaptor, width: width, height: height)
            let time = CMTime(value: CMTimeValue(index), timescale: settings.framesPerSecond)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw TimelapseComposerError.writerFailed
            }
            onProgress(Double(index + 1) / Double(frames.count))
        }

        input.markAsFinished()
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        finished.wait()

        guard writer.status == .completed else { throw TimelapseComposerError.writerFailed }
        return outputURL
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    // Akıllı Hizalama hedefi: yüz karenin yatayda ortasına, dikeyde biraz yukarısına ve
    // sabit bir yüksekliğe oturtulur; böylece özne tüm karelerde aynı yerde durur.
    private static let alignTargetCenter = CGPoint(x: 0.5, y: 0.42)
    private static let alignTargetFaceHeight: CGFloat = 0.34

    private static func composeFrame(
        _ image: UIImage,
        date: Date,
        anchor: FrameAnchor?,
        reference: FrameAnchor?,
        settings: TimelapseExportSettings
    ) -> CGImage? {
        let size = settings.renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let rect: CGRect
            if settings.smartAlignment, let anchor, reference != nil {
                rect = alignedRect(for: image, anchor: anchor, canvas: size)
            } else {
                rect = aspectFillRect(for: image, canvas: size)
            }
            image.draw(in: rect)

            drawOverlays(size: size, date: date, settings: settings)
        }
        return rendered.cgImage
    }

    /// Görseli tuvali dolduracak şekilde ortalar (hizalama kapalıyken varsayılan).
    private static func aspectFillRect(for image: UIImage, canvas: CGSize) -> CGRect {
        let scale = max(canvas.width / max(image.size.width, 1), canvas.height / max(image.size.height, 1))
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: (canvas.width - drawSize.width) / 2,
            y: (canvas.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    /// Yüzü hedef konum ve boyuta getirecek şekilde görseli ölçekleyip kaydırır.
    private static func alignedRect(for image: UIImage, anchor: FrameAnchor, canvas: CGSize) -> CGRect {
        let faceHeightPoints = max(anchor.height * image.size.height, 1)
        let scale = (alignTargetFaceHeight * canvas.height) / faceHeightPoints
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let faceInScaled = CGPoint(x: anchor.center.x * drawSize.width, y: anchor.center.y * drawSize.height)
        let target = CGPoint(x: alignTargetCenter.x * canvas.width, y: alignTargetCenter.y * canvas.height)
        return CGRect(
            x: target.x - faceInScaled.x,
            y: target.y - faceInScaled.y,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    /// Tarih / not / uygulama etiketini seçilen köşelere çizer. Ücretsiz katmanda
    /// uygulama etiketi (filigran) her zaman görünür; Pro kullanıcı gizleyebilir.
    private static func drawOverlays(size: CGSize, date: Date, settings: TimelapseExportSettings) {
        let overlay = settings.overlay
        let margin = size.width * 0.03
        let fontSize = size.height * 0.022

        func draw(_ string: String, at corner: OverlayCorner, kern: CGFloat = 0) {
            guard !string.isEmpty else { return }
            let text = string as NSString
            let shadow = NSShadow()
            shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
            shadow.shadowBlurRadius = 4
            shadow.shadowOffset = CGSize(width: 0, height: 1)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.9),
                .kern: kern,
                .shadow: shadow
            ]
            let textSize = text.size(withAttributes: attributes)
            let point = corner.origin(textSize: textSize, canvas: size, margin: margin)
            text.draw(at: point, withAttributes: attributes)
        }

        if overlay.showDate {
            draw(dateFormatter.string(from: date), at: overlay.datePosition)
        }
        draw(overlay.note, at: overlay.notePosition)
        // Uygulama etiketi her zaman sağ altta; ücretsiz katmanda zorunlu, Pro'da gizlenebilir.
        if settings.includesWatermark || overlay.showAppMark {
            draw("TIMELAPSE", at: TimelapseOverlayOptions.appMarkCorner, kern: 2)
        }
    }

    private static func pixelBuffer(
        for image: CGImage,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        width: Int,
        height: Int
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        if let pool = adaptor.pixelBufferPool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        }
        if buffer == nil {
            let attributes = [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attributes, &buffer)
        }
        guard let buffer else { throw TimelapseComposerError.writerFailed }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { throw TimelapseComposerError.writerFailed }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return buffer
    }
}

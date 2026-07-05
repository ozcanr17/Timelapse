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

/// Kareler arası geçiş efekti.
enum TimelapseTransition: String, CaseIterable, Identifiable {
    case cut        // sert kesme (varsayılan, mevcut davranış)
    case dissolve   // çapraz geçiş (crossfade)
    case fade       // karartarak geçiş (fade through black)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cut:      "Kesme"
        case .dissolve: "Çözülme"
        case .fade:     "Karartma"
        }
    }
}

/// Manuel hizalama: kullanıcının seçtiği normalize (0…1) özne noktası tüm karelerde
/// tuvalin ortasına getirilir; `zoom` yakınlaştırma çarpanıdır.
struct ManualAlignment: Equatable {
    var center: CGPoint
    var zoom: CGFloat
}

struct TimelapseExportSettings: Equatable {
    let renderSize: CGSize
    let framesPerSecond: Int32
    let includesWatermark: Bool          // ücretsiz katmanda uygulama etiketi zorunlu
    var overlay: TimelapseOverlayOptions = TimelapseOverlayOptions()
    /// Akıllı Hizalama (Pro): dışa aktarımda özneyi yüz/belirginlik tespitiyle sabitler.
    var smartAlignment: Bool = false
    /// Manuel hizalama (Pro): ayarlıysa Akıllı Hizalama'nın yerine geçer.
    var manualAnchor: ManualAlignment? = nil
    /// Kareler arası geçiş.
    var transition: TimelapseTransition = .cut

    static func current(
        isPro: Bool,
        speed: TimelapseSpeed = .normal,
        overlay: TimelapseOverlayOptions = TimelapseOverlayOptions(),
        smartAlignment: Bool = false,
        manualAnchor: ManualAlignment? = nil,
        transition: TimelapseTransition = .cut
    ) -> TimelapseExportSettings {
        if FeatureGate.isUnlocked(.highResExport, isPro: isPro) {
            TimelapseExportSettings(
                renderSize: CGSize(width: 2160, height: 2880),
                framesPerSecond: speed.framesPerSecond,
                includesWatermark: false,
                overlay: overlay,
                smartAlignment: smartAlignment,
                manualAnchor: manualAnchor,
                transition: transition
            )
        } else {
            TimelapseExportSettings(
                renderSize: CGSize(width: 720, height: 960),
                framesPerSecond: speed.framesPerSecond,
                includesWatermark: true,
                overlay: overlay,
                smartAlignment: smartAlignment,
                manualAnchor: manualAnchor,
                transition: transition
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

        // Akıllı Hizalama: her karedeki çıpayı bul; ilk bulunan referans olur. Manuel
        // hizalama ayarlıysa Vision'a gerek yok (tüm karelerde sabit çıpa kullanılır).
        let anchors: [FrameAnchor?] = (settings.smartAlignment && settings.manualAnchor == nil)
            ? frames.map { FrameAligner.anchor(in: $0.imageData) }
            : Array(repeating: nil, count: frames.count)
        let reference = anchors.compactMap { $0 }.first

        // Kesme'de kare başına 1 kare (mevcut davranış). Geçişlerde araya harmanlanmış
        // kareler eklenir.
        let transitionSteps = settings.transition == .cut ? 0 : max(2, Int(settings.framesPerSecond) / 3)
        var presentationIndex: Int64 = 0

        func append(_ cgImage: CGImage) throws {
            while !input.isReadyForMoreMediaData { usleep(3000) }
            let buffer = try pixelBuffer(for: cgImage, adaptor: adaptor, width: width, height: height)
            let time = CMTime(value: presentationIndex, timescale: settings.framesPerSecond)
            guard adaptor.append(buffer, withPresentationTime: time) else {
                throw TimelapseComposerError.writerFailed
            }
            presentationIndex += 1
        }

        func keyframe(_ index: Int) throws -> CGImage {
            guard
                let image = UIImage(data: frames[index].imageData),
                let composed = composeFrame(
                    image,
                    date: frames[index].capturedAt,
                    anchor: anchors[index],
                    reference: reference,
                    settings: settings
                )
            else { throw TimelapseComposerError.frameDecodingFailed }
            return composed
        }

        var current = try keyframe(0)
        for index in frames.indices {
            let next = index + 1 < frames.count ? try keyframe(index + 1) : nil
            try append(current)

            if transitionSteps > 0, let next {
                for step in 1...transitionSteps {
                    let progress = CGFloat(step) / CGFloat(transitionSteps + 1)
                    if let blended = blend(current, next, progress: progress,
                                           transition: settings.transition, size: settings.renderSize) {
                        try append(blended)
                    }
                }
            }
            onProgress(Double(index + 1) / Double(frames.count))
            if let next { current = next }
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

    // Akıllı Hizalama hedefi: özne karenin yatayda ortasına, dikeyde biraz yukarısına ve
    // sabit bir yüksekliğe oturtulur; böylece tüm karelerde aynı yerde ve boyutta durur.
    private static let alignTargetCenter = CGPoint(x: 0.5, y: 0.42)
    private static let alignTargetHeight: CGFloat = 0.34

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
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            if let manual = settings.manualAnchor {
                image.draw(in: manualRect(for: image, manual: manual, canvas: size))
            } else if settings.smartAlignment, let anchor, let reference {
                drawAligned(image, anchor: anchor, reference: reference, canvas: size, context: context.cgContext)
            } else {
                image.draw(in: aspectFillRect(for: image, canvas: size))
            }

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

    /// Manuel hizalama: seçilen özne noktasını tuval ortasına getirip zoom uygular.
    private static func manualRect(for image: UIImage, manual: ManualAlignment, canvas: CGSize) -> CGRect {
        let base = max(canvas.width / max(image.size.width, 1), canvas.height / max(image.size.height, 1))
        let scale = base * max(manual.zoom, 0.2)
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let point = CGPoint(x: manual.center.x * drawSize.width, y: manual.center.y * drawSize.height)
        return CGRect(
            x: canvas.width * 0.5 - point.x,
            y: canvas.height * 0.5 - point.y,
            width: drawSize.width,
            height: drawSize.height
        )
    }

    /// İki tam kareyi geçiş türüne göre harmanlar (çözülme: çapraz geçiş; karartma:
    /// önce siyaha, sonra bir sonraki kareye).
    private static func blend(_ first: CGImage, _ second: CGImage, progress: CGFloat,
                              transition: TimelapseTransition, size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let rect = CGRect(origin: .zero, size: size)
            let a = UIImage(cgImage: first)
            let b = UIImage(cgImage: second)
            switch transition {
            case .dissolve:
                a.draw(in: rect, blendMode: .normal, alpha: 1)
                b.draw(in: rect, blendMode: .normal, alpha: Double(progress))
            case .fade:
                if progress < 0.5 {
                    a.draw(in: rect, blendMode: .normal, alpha: Double(1 - progress * 2))
                } else {
                    b.draw(in: rect, blendMode: .normal, alpha: Double(progress * 2 - 1))
                }
            case .cut:
                b.draw(in: rect)
            }
        }
        return rendered.cgImage
    }

    /// Özneyi hedef konum, boyut VE açıya getirir: ölçekler, döndürür (yüz roll'ü) ve
    /// kaydırır. Yüzsüz kareler için roll 0'dır (yalnızca konum + boyut hizalanır).
    private static func drawAligned(
        _ image: UIImage,
        anchor: FrameAnchor,
        reference: FrameAnchor,
        canvas: CGSize,
        context: CGContext
    ) {
        let subjectHeightPoints = max(anchor.height * image.size.height, 1)
        let scale = (alignTargetHeight * canvas.height) / subjectHeightPoints
        let target = CGPoint(x: alignTargetCenter.x * canvas.width, y: alignTargetCenter.y * canvas.height)
        let subjectInImage = CGPoint(x: anchor.center.x * image.size.width, y: anchor.center.y * image.size.height)

        context.saveGState()
        context.translateBy(x: target.x, y: target.y)          // öznenin geleceği yer
        context.rotate(by: reference.roll - anchor.roll)        // referansa göre düzelt
        context.scaleBy(x: scale, y: scale)                     // özneyi sabit boyuta getir
        image.draw(at: CGPoint(x: -subjectInImage.x, y: -subjectInImage.y))
        context.restoreGState()
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

import AVFoundation
import Foundation
import UIKit
import SwiftUI

private final class CancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }
}

/// Timelapse oynatma hızı. Kare hızını (fps) belirler; daha yüksek fps daha hızlı,
/// akıcı bir video demek. Herkese açık bir özellik — Pro gerektirmez.
enum TimelapseSpeed: String, CaseIterable, Identifiable {
    case quarter
    case slow
    case normal
    case fast
    case turbo

    var id: String { rawValue }

    /// Saniyedeki kare sayısı. `normal` = 4 fps (eski 0.5×); diğerleri buna göre ölçeklenir.
    var framesPerSecond: Int32 {
        switch self {
        case .quarter: 1
        case .slow:    2
        case .normal:  4
        case .fast:    8
        case .turbo:   12
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

/// Videonun en-boy oranı. Dikey oranlar hikaye/paylaşım, yataylar YouTube tarzı için.
enum TimelapseAspect: String, CaseIterable, Identifiable {
    case threeFour
    case nineSixteen
    case nineEighteen
    case square
    case fourThree
    case sixteenNine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .threeFour:    "3:4"
        case .nineSixteen:  "9:16"
        case .nineEighteen: "9:18"
        case .square:       "1:1"
        case .fourThree:    "4:3"
        case .sixteenNine:  "16:9"
        }
    }

    /// Genişlik / yükseklik oranı.
    var ratio: CGFloat {
        switch self {
        case .threeFour:    3.0 / 4.0
        case .nineSixteen:  9.0 / 16.0
        case .nineEighteen: 9.0 / 18.0
        case .square:       1
        case .fourThree:    4.0 / 3.0
        case .sixteenNine:  16.0 / 9.0
        }
    }

    /// Uzun kenar sabit tutulur (Pro 2880, ücretsiz 960); kısa kenar orandan türetilir
    /// ve encoder uyumu için 16'nın katına yuvarlanır.
    func renderSize(isPro: Bool) -> CGSize {
        let long: CGFloat = isPro ? 2880 : 960
        func snap(_ value: CGFloat) -> CGFloat { (value / 16).rounded() * 16 }
        if ratio <= 1 {
            return CGSize(width: snap(long * ratio), height: long)
        }
        return CGSize(width: long, height: snap(long / ratio))
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
        case .topLeft:     String(localized: "Sol üst", bundle: .appLanguage)
        case .topRight:    String(localized: "Sağ üst", bundle: .appLanguage)
        case .bottomLeft:  String(localized: "Sol alt", bundle: .appLanguage)
        case .bottomRight: String(localized: "Sağ alt", bundle: .appLanguage)
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

/// Kareler arası geçiş: efekt yok ya da kısa, yumuşak bir çapraz geçiş.
enum TimelapseTransition: String, CaseIterable, Identifiable {
    case cut        // efekt yok (sert kesme)
    case smooth     // kısa çapraz geçiş (crossfade)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cut:    "Efekt yok"
        case .smooth: "Yumuşak"
        }
    }
}

/// Manuel hizalama: kullanıcının seçtiği normalize (0…1) özne noktası tüm karelerde
/// tuvalin ortasına getirilir; `zoom` yakınlaştırma çarpanıdır.
struct ManualAlignment: Equatable {
    var center: CGPoint
    var zoom: CGFloat
    var rotation: Double = 0
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
    /// Akıllı Hizalama'nın hangi özneyi kilitleyeceği (yüz / gövde / karın / grup).
    var alignmentSubject: AlignmentSubject = .auto
    /// Kare ölçeği: 1 = doğal doldurma; <1 uzaklaşır (kenar boşluğu siyah), >1 yakınlaşır.
    var zoom: CGFloat = 1

    static func current(
        isPro: Bool,
        speed: TimelapseSpeed = .normal,
        speedMultiplier: Double? = nil,
        aspect: TimelapseAspect = .threeFour,
        zoom: Double = 1,
        overlay: TimelapseOverlayOptions = TimelapseOverlayOptions(),
        smartAlignment: Bool = false,
        manualAnchor: ManualAlignment? = nil,
        transition: TimelapseTransition = .cut,
        alignmentSubject: AlignmentSubject = .auto
    ) -> TimelapseExportSettings {
        let unlocked = FeatureGate.isUnlocked(.highResExport, isPro: isPro)
        let fps = speedMultiplier.map { Int32(min(12, max(1, ($0 * 4).rounded()))) } ?? speed.framesPerSecond
        return TimelapseExportSettings(
            renderSize: aspect.renderSize(isPro: unlocked),
            framesPerSecond: fps,
            includesWatermark: !unlocked,
            overlay: overlay,
            smartAlignment: smartAlignment,
            manualAnchor: manualAnchor,
            transition: transition,
            alignmentSubject: alignmentSubject,
            zoom: CGFloat(min(2, max(0.5, zoom)))
        )
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
        let token = CancellationToken()
        let outroAssets = await Self.outroAssets()
        return try await withTaskCancellationHandler {
            try await Task.detached(priority: .userInitiated) {
                try Self.render(frames: frames, settings: settings, outroAssets: outroAssets,
                                isCancelled: { token.isCancelled }, onProgress: onProgress)
            }.value
        } onCancel: {
            token.cancel()
        }
    }

    struct OutroAssets: @unchecked Sendable {
        let logo: CGImage?
        let canvas: UIColor
        let ink: UIColor
    }

    /// Kapanış kartı, uygulama açılışıyla birebir aynı görünsün: gerçek LogoMark ve
    /// kullanıcının temasındaki zemin/metin renkleri bir kez hazırlanır.
    @MainActor
    private static func outroAssets() -> OutroAssets {
        let renderer = ImageRenderer(content: LogoMark(size: 512))
        renderer.scale = 1
        renderer.isOpaque = false
        let theme = AppTheme(rawValue: UserDefaults.standard.string(forKey: AppTheme.storageKey) ?? "") ?? .filmNegative
        let traits = UITraitCollection.current
        return OutroAssets(
            logo: renderer.cgImage,
            canvas: UIColor(theme.palette.canvas).resolvedColor(with: traits),
            ink: UIColor(theme.palette.ink).resolvedColor(with: traits)
        )
    }

    private static func render(
        frames: [TimelapseFrame],
        settings: TimelapseExportSettings,
        outroAssets: OutroAssets,
        isCancelled: @Sendable () -> Bool,
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

        let useSmart = settings.smartAlignment && settings.manualAnchor == nil
        let anchors: [FrameAnchor?] = useSmart
            ? frames.map { FrameAligner.anchor(in: $0.imageData, subject: settings.alignmentSubject) }
            : Array(repeating: nil, count: frames.count)
        let reference = anchors.compactMap { $0 }.first

        let offsets: [CGSize?]
        if useSmart, reference == nil, let referenceData = frames.first?.imageData {
            offsets = frames.enumerated().map { index, frame in
                index == 0 ? .zero : FrameAligner.translationOffset(targetData: frame.imageData, referenceData: referenceData)
            }
        } else {
            offsets = Array(repeating: nil, count: frames.count)
        }

        // Sabit 30 fps çıktı; her fotoğraf `holdFrames` kadar tutulur (hız bunu belirler).
        // Yumuşak geçiş, fotoğrafın SON birkaç karesini bir sonrakine kısa bir çapraz
        // geçişle bindirir — böylece video da geçiş de akıcı olur, süre uzamaz ve geçiş
        // her zaman kısa kalır (hızlı hızlarda otomatik daha da kısalır).
        let outputFPS: Int32 = 30
        let holdFrames = max(1, Int((Double(outputFPS) / Double(settings.framesPerSecond)).rounded()))
        let transitionFrames = settings.transition == .smooth
            ? min(holdFrames - 1, max(1, Int((0.14 * Double(outputFPS)).rounded())))
            : 0
        let solidFrames = holdFrames - transitionFrames
        var presentationIndex: Int64 = 0

        func append(_ cgImage: CGImage) throws {
            while !input.isReadyForMoreMediaData { usleep(3000) }
            let buffer = try pixelBuffer(for: cgImage, adaptor: adaptor, width: width, height: height)
            let time = CMTime(value: presentationIndex, timescale: outputFPS)
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
                    offset: offsets[index],
                    settings: settings
                )
            else { throw TimelapseComposerError.frameDecodingFailed }
            return composed
        }

        func abortIfCancelled() throws {
            guard isCancelled() else { return }
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: outputURL)
            throw CancellationError()
        }

        var current = try keyframe(0)

        for index in frames.indices {
            try abortIfCancelled()
            let next = try index + 1 < frames.count ? autoreleasepool { try keyframe(index + 1) } : nil

            for _ in 0..<solidFrames {
                try autoreleasepool { try append(current) }
            }

            if transitionFrames > 0, let next {
                for step in 1...transitionFrames {
                    try autoreleasepool {
                        let progress = CGFloat(step) / CGFloat(transitionFrames)
                        if let blended = blend(current, next, progress: progress, size: settings.renderSize) {
                            try append(blended)
                        }
                    }
                }
            } else {
                for _ in 0..<transitionFrames {
                    try autoreleasepool { try append(current) }
                }
            }

            onProgress(Double(index + 1) / Double(frames.count))
            if let next { current = next }
        }

        let outroFrames = Int(Double(outputFPS) * 3.0)
        let lastComposed = UIImage(cgImage: current)
        var finalOutro: CGImage?
        for step in 0..<outroFrames {
            try abortIfCancelled()
            let t = CGFloat(step) / CGFloat(outroFrames - 1)
            if t >= 0.65, let cached = finalOutro {
                try autoreleasepool { try append(cached) }
                continue
            }
            try autoreleasepool {
                if let frame = outroFrame(base: lastComposed, t: t, assets: outroAssets, size: settings.renderSize) {
                    if t >= 0.65 { finalOutro = frame }
                    try append(frame)
                }
            }
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
        formatter.locale = AppLanguage.currentLocale
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
        offset: CGSize?,
        settings: TimelapseExportSettings
    ) -> CGImage? {
        let size = settings.renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            if let backdrop = blurredBackdrop(image) {
                context.cgContext.interpolationQuality = .high
                let fill = aspectFillRect(for: backdrop, canvas: size)
                backdrop.draw(in: fill.insetBy(dx: -fill.width * 0.08, dy: -fill.height * 0.08))
                UIColor.black.withAlphaComponent(0.22).setFill()
                UIRectFillUsingBlendMode(CGRect(origin: .zero, size: size), .normal)
            }

            let zoom = settings.zoom
            if zoom != 1 {
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: size.width / 2, y: size.height / 2)
                context.cgContext.scaleBy(x: zoom, y: zoom)
                context.cgContext.translateBy(x: -size.width / 2, y: -size.height / 2)
            }

            if let manual = settings.manualAnchor {
                let ctx = context.cgContext
                ctx.saveGState()
                if manual.rotation != 0 {
                    ctx.translateBy(x: size.width / 2, y: size.height / 2)
                    ctx.rotate(by: CGFloat(manual.rotation) * .pi / 180)
                    ctx.translateBy(x: -size.width / 2, y: -size.height / 2)
                }
                image.draw(in: manualRect(for: image, manual: manual, canvas: size))
                ctx.restoreGState()
            } else if settings.smartAlignment, let anchor, let reference {
                drawAligned(image, anchor: anchor, reference: reference, canvas: size, context: context.cgContext)
            } else if settings.smartAlignment, let offset {
                image.draw(in: aspectFillRect(for: image, canvas: size, offset: offset))
            } else {
                image.draw(in: aspectFillRect(for: image, canvas: size))
            }

            if zoom != 1 {
                context.cgContext.restoreGState()
            }

            drawOverlays(size: size, date: date, settings: settings)
        }
        return rendered.cgImage
    }

    /// Siyah bantları önlemek için fotoğrafın aşırı küçültülmüş hâli zemin olarak serilir;
    /// büyütülürken yumuşayan pikseller ucuz ve her ortamda çalışan bir "blur" verir.
    /// `tinyLongSide` küçüldükçe bulanıklık artar.
    private static func blurredBackdrop(_ image: UIImage, tinyLongSide: CGFloat = 12) -> UIImage? {
        let long = max(image.size.width, image.size.height, 1)
        let scale = max(tinyLongSide, 2) / long
        let tinySize = CGSize(
            width: max(image.size.width * scale, 2),
            height: max(image.size.height * scale, 2)
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let tiny = UIGraphicsImageRenderer(size: tinySize, format: format).image { context in
            context.cgContext.interpolationQuality = .medium
            image.draw(in: CGRect(origin: .zero, size: tinySize))
        }
        let midSize = CGSize(width: tinySize.width * 12, height: tinySize.height * 12)
        return UIGraphicsImageRenderer(size: midSize, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            tiny.draw(in: CGRect(origin: .zero, size: midSize))
        }
    }

    /// Görseli tuvali dolduracak şekilde ortalar (hizalama kapalıyken varsayılan).
    private static func aspectFillRect(for image: UIImage, canvas: CGSize, offset: CGSize = .zero) -> CGRect {
        let scale = max(canvas.width / max(image.size.width, 1), canvas.height / max(image.size.height, 1))
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(
            x: (canvas.width - drawSize.width) / 2 + offset.width * drawSize.width,
            y: (canvas.height - drawSize.height) / 2 - offset.height * drawSize.height,
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

    /// İki tam kareyi yumuşak çapraz geçişle harmanlar (crossfade).
    /// Video kapanışı: son kare tema zeminine yumuşakça karışır, ardından logo uygulama
    /// açılışındaki gibi dönerek ve yaylanarak belirir; "Flapse" yazısı altına gelir.
    /// Toplam süre ~3 sn; logo ekranın en fazla dörtte biri kadar yer kaplar.
    private static func outroFrame(base: UIImage, t: CGFloat, assets: OutroAssets, size: CGSize) -> CGImage? {
        let fadeP = min(1, max(0, t / 0.2))
        let animP = min(1, max(0, (t - 0.16) / 0.34))
        let textP = min(1, max(0, (t - 0.4) / 0.18))

        func easeOut(_ x: CGFloat) -> CGFloat { 1 - pow(1 - x, 3) }
        func easeOutBack(_ x: CGFloat) -> CGFloat {
            let c1: CGFloat = 1.70158
            let c3 = c1 + 1
            return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            let ctx = context.cgContext

            assets.canvas.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            if fadeP < 1 {
                base.draw(in: CGRect(origin: .zero, size: size), blendMode: .normal, alpha: 1 - fadeP)
            }

            guard animP > 0 else { return }

            let shortSide = min(size.width, size.height)
            let logoSize = shortSide * 0.20
            let text = "Flapse" as NSString
            let fontSize = logoSize * 0.22
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
                .foregroundColor: assets.ink.withAlphaComponent(textP)
            ]
            let textSize = text.size(withAttributes: attributes)
            let spacing = logoSize * 0.2
            let contentHeight = logoSize + spacing + textSize.height
            let logoCenter = CGPoint(
                x: size.width / 2,
                y: (size.height - contentHeight) / 2 + logoSize / 2
            )

            let rotation = CGFloat(-120) * (1 - easeOut(animP)) * .pi / 180
            let scale = 0.6 + 0.4 * easeOutBack(animP)
            ctx.saveGState()
            ctx.translateBy(x: logoCenter.x, y: logoCenter.y)
            ctx.rotate(by: rotation)
            ctx.scaleBy(x: scale, y: scale)
            ctx.setAlpha(min(1, animP * 1.6))
            let logoRect = CGRect(x: -logoSize / 2, y: -logoSize / 2, width: logoSize, height: logoSize)
            if let logo = assets.logo {
                UIImage(cgImage: logo).draw(in: logoRect)
            } else {
                drawLogoMark(in: logoRect, alpha: 1)
            }
            ctx.restoreGState()

            if textP > 0 {
                text.draw(
                    at: CGPoint(
                        x: (size.width - textSize.width) / 2,
                        y: logoCenter.y + logoSize / 2 + spacing
                    ),
                    withAttributes: attributes
                )
            }
        }
        return image.cgImage
    }

    private static func blend(_ first: CGImage, _ second: CGImage, progress: CGFloat, size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let rect = CGRect(origin: .zero, size: size)
            UIColor.black.setFill()
            UIRectFill(rect)
            UIImage(cgImage: first).draw(in: rect, blendMode: .normal, alpha: 1)
            UIImage(cgImage: second).draw(in: rect, blendMode: .normal, alpha: Double(progress))
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
            drawAppMark(canvas: size, margin: margin, fontSize: fontSize)
        }
    }

    private static func drawAppMark(canvas: CGSize, margin: CGFloat, fontSize: CGFloat) {
        let text = "FLAPSE" as NSString
        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
        shadow.shadowBlurRadius = 4
        shadow.shadowOffset = CGSize(width: 0, height: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white.withAlphaComponent(0.9),
            .kern: 2,
            .shadow: shadow
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: CGPoint(x: canvas.width - margin - textSize.width, y: canvas.height - margin - textSize.height),
            withAttributes: attributes
        )
    }

    private static func drawLogoMark(in rect: CGRect, alpha: CGFloat = 0.5) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        context.setAlpha(alpha)
        UIColor(red: 0.18, green: 0.545, blue: 0.341, alpha: 1).setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: rect.width * 0.24).fill()
        let aperture = rect.insetBy(dx: rect.width * 0.26, dy: rect.width * 0.26)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(rect.width * 0.06)
        context.strokeEllipse(in: aperture)
        context.restoreGState()
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

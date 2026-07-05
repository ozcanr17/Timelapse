import AVFoundation
import UIKit

/// Timelapse oynatma hızı. Kare hızını (fps) belirler; daha yüksek fps daha hızlı,
/// akıcı bir video demek. Herkese açık bir özellik — Pro gerektirmez.
enum TimelapseSpeed: String, CaseIterable, Identifiable {
    case slow
    case normal
    case fast
    case turbo

    var id: String { rawValue }

    /// Saniyedeki kare sayısı. `normal` mevcut varsayılanı (8 fps) korur.
    var framesPerSecond: Int32 {
        switch self {
        case .slow:   4
        case .normal: 8
        case .fast:   16
        case .turbo:  24
        }
    }

    /// Segmentli seçicide gösterilen çarpan etiketi.
    var displayName: String {
        switch self {
        case .slow:   "0.5×"
        case .normal: "1×"
        case .fast:   "2×"
        case .turbo:  "3×"
        }
    }
}

struct TimelapseExportSettings: Equatable {
    let renderSize: CGSize
    let framesPerSecond: Int32
    let includesWatermark: Bool

    static func current(isPro: Bool, speed: TimelapseSpeed = .normal) -> TimelapseExportSettings {
        if FeatureGate.isUnlocked(.highResExport, isPro: isPro) {
            TimelapseExportSettings(
                renderSize: CGSize(width: 2160, height: 2880),
                framesPerSecond: speed.framesPerSecond,
                includesWatermark: false
            )
        } else {
            TimelapseExportSettings(
                renderSize: CGSize(width: 720, height: 960),
                framesPerSecond: speed.framesPerSecond,
                includesWatermark: true
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
        from frames: [Data],
        settings: TimelapseExportSettings,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL
}

struct TimelapseComposer: TimelapseComposing {

    func makeVideo(
        from frames: [Data],
        settings: TimelapseExportSettings,
        onProgress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard frames.count >= 2 else { throw TimelapseComposerError.notEnoughFrames }
        return try await Task.detached(priority: .userInitiated) {
            try Self.render(frames: frames, settings: settings, onProgress: onProgress)
        }.value
    }

    private static func render(
        frames: [Data],
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

        for (index, data) in frames.enumerated() {
            guard
                let image = UIImage(data: data),
                let frame = composeFrame(image, settings: settings)
            else { throw TimelapseComposerError.frameDecodingFailed }

            while !input.isReadyForMoreMediaData { usleep(3000) }

            let buffer = try pixelBuffer(for: frame, adaptor: adaptor, width: width, height: height)
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

    private static func composeFrame(_ image: UIImage, settings: TimelapseExportSettings) -> CGImage? {
        let size = settings.renderSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))

            let scale = max(
                size.width / max(image.size.width, 1),
                size.height / max(image.size.height, 1)
            )
            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                x: (size.width - drawSize.width) / 2,
                y: (size.height - drawSize.height) / 2
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))

            if settings.includesWatermark {
                let text = "TIMELAPSE" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: size.height * 0.022, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.65),
                    .kern: 2
                ]
                let textSize = text.size(withAttributes: attributes)
                text.draw(
                    at: CGPoint(
                        x: size.width - textSize.width - 20,
                        y: size.height - textSize.height - 16
                    ),
                    withAttributes: attributes
                )
            }
        }
        return rendered.cgImage
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

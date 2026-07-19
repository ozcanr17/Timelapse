import Vision
import UIKit
import CoreVideo

/// Optik akış tabanlı kare morfu: iki kare arasındaki piksel hareketi Vision ile
/// çıkarılır, ara kareler her iki görüntünün akış boyunca bükülmesi (warp) ve
/// karıştırılmasıyla sentezlenir. Yüz geometrisi dahil tüm sahne akışkan biçimde
/// dönüşür — çapraz geçişteki "hayalet" ikizlenme kaybolur.
enum FlowMorpher {

    nonisolated(unsafe) static var lastError: String?

    struct FlowField {
        let width: Int
        let height: Int
        let dx: [Float]
        let dy: [Float]
    }

    /// İki tuval karesi arasında `steps` adet ara kare üretir. Akış küçültülmüş boyutta
    /// hesaplanıp uygulanır; sonuç tuval boyutuna büyütülür (geçiş anlık olduğundan
    /// yumuşaklık algıyı bozmaz, hızı 10 kat artırır).
    static func morphFrames(from source: CGImage, to target: CGImage, steps: Int, canvas: CGSize) -> [CGImage]? {
        var results: [CGImage] = []
        results.reserveCapacity(steps)
        let rendered = try? renderMorphFrames(from: source, to: target, steps: steps, canvas: canvas) {
            results.append($0)
        }
        return rendered == true ? results : nil
    }

    static func renderMorphFrames(
        from source: CGImage,
        to target: CGImage,
        steps: Int,
        canvas: CGSize,
        consume: (CGImage) throws -> Void
    ) throws -> Bool {
        guard steps > 0 else { return true }
        let workingLong = 384
        let aspect = CGFloat(source.width) / CGFloat(max(source.height, 1))
        let workSize = aspect >= 1
            ? CGSize(width: workingLong, height: max(2, Int(CGFloat(workingLong) / aspect)))
            : CGSize(width: max(2, Int(CGFloat(workingLong) * aspect)), height: workingLong)

        guard
            let smallSource = resized(source, to: workSize),
            let smallTarget = resized(target, to: workSize)
        else { return false }

        if let rawFlow = opticalFlow(from: smallSource, to: smallTarget),
           let sourcePixels = rgbaPixels(of: smallSource),
           let targetPixels = rgbaPixels(of: smallTarget) {
            let width = smallSource.width
            let height = smallSource.height
            let flow = resampleFlow(rawFlow, toWidth: width, height: height)
            for step in 1...steps {
                let t = Float(step) / Float(steps + 1)
                guard let morphed = morphPixel(
                    source: sourcePixels, target: targetPixels,
                    flow: flow, width: width, height: height, t: t
                ), let upscaled = upscale(morphed, from: CGSize(width: width, height: height), to: canvas) else {
                    return false
                }
                try autoreleasepool { try consume(upscaled) }
            }
            return true
        }

        return try registrationMorph(
            source: source,
            target: target,
            small: (smallSource, smallTarget),
            steps: steps,
            canvas: canvas,
            consume: consume
        )
    }

    /// Optik akış motoru yoksa (ör. simülatör) hareket-dengelemeli geçiş: iki kare
    /// arasındaki global kayma bulunur, kareler bu kayma boyunca kaydırılarak
    /// karıştırılır. Hizasızlıktan doğan "hayalet" ikizlenme büyük ölçüde kaybolur.
    private static func registrationMorph(
        source: CGImage, target: CGImage,
        small: (CGImage, CGImage), steps: Int, canvas: CGSize,
        consume: (CGImage) throws -> Void
    ) throws -> Bool {
        var shift = CGSize.zero
        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: small.1)
        if (try? VNImageRequestHandler(cgImage: small.0, options: [:]).perform([request])) != nil,
           let observation = request.results?.first as? VNImageTranslationAlignmentObservation {
            let transform = observation.alignmentTransform
            let scaleX = canvas.width / CGFloat(small.0.width)
            let scaleY = canvas.height / CGFloat(small.0.height)
            shift = CGSize(width: -transform.tx * scaleX, height: -transform.ty * scaleY)
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        for step in 1...steps {
            let t = CGFloat(step) / CGFloat(steps + 1)
            let frame = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
                context.cgContext.interpolationQuality = .medium
                UIImage(cgImage: source).draw(
                    in: CGRect(x: shift.width * t, y: shift.height * t, width: canvas.width, height: canvas.height)
                )
                UIImage(cgImage: target).draw(
                    in: CGRect(x: -shift.width * (1 - t), y: -shift.height * (1 - t), width: canvas.width, height: canvas.height),
                    blendMode: .normal,
                    alpha: t
                )
            }
            guard let cg = frame.cgImage else { return false }
            try autoreleasepool { try consume(cg) }
        }
        return true
    }

    static func opticalFlow(from source: CGImage, to target: CGImage) -> FlowField? {
        let request = VNGenerateOpticalFlowRequest(targetedCGImage: target, options: [:])
        request.computationAccuracy = .medium
        request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
        let handler = VNImageRequestHandler(cgImage: source, options: [:])
        do {
            try handler.perform([request])
        } catch {
            lastError = "\(error)"
            return nil
        }
        guard let observation = request.results?.first as? VNPixelBufferObservation else {
            lastError = "no observation (results: \(request.results?.count ?? -1))"
            return nil
        }

        let buffer = observation.pixelBuffer
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let stride = CVPixelBufferGetBytesPerRow(buffer) / MemoryLayout<Float>.size
        let floats = base.assumingMemoryBound(to: Float.self)

        var dx = [Float](repeating: 0, count: width * height)
        var dy = [Float](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let index = y * stride + x * 2
                dx[y * width + x] = floats[index]
                dy[y * width + x] = floats[index + 1]
            }
        }
        return FlowField(width: width, height: height, dx: dx, dy: dy)
    }

    /// Vision akışı çalışma boyutundan farklı çözünürlükte dönebilir; en yakın komşu
    /// örnekleme ile hedef boyuta uyarlanır (vektörler ölçeklenir).
    private static func resampleFlow(_ flow: FlowField, toWidth width: Int, height: Int) -> FlowField {
        guard flow.width != width || flow.height != height else { return flow }
        var dx = [Float](repeating: 0, count: width * height)
        var dy = [Float](repeating: 0, count: width * height)
        let sx = Float(flow.width) / Float(width)
        let sy = Float(flow.height) / Float(height)
        for y in 0..<height {
            let fy = min(Int(Float(y) * sy), flow.height - 1)
            for x in 0..<width {
                let fx = min(Int(Float(x) * sx), flow.width - 1)
                let i = fy * flow.width + fx
                dx[y * width + x] = flow.dx[i] / sx
                dy[y * width + x] = flow.dy[i] / sy
            }
        }
        return FlowField(width: width, height: height, dx: dx, dy: dy)
    }

    /// Ara kare: kaynağı akış boyunca ileri, hedefi geri bükerek (backward sampling)
    /// ikisini t oranında karıştırır.
    private static func morphPixel(
        source: [UInt8], target: [UInt8],
        flow: FlowField, width: Int, height: Int, t: Float
    ) -> [UInt8]? {
        guard flow.width == width, flow.height == height else { return nil }
        var output = [UInt8](repeating: 0, count: width * height * 4)

        source.withUnsafeBufferPointer { src in
            target.withUnsafeBufferPointer { dst in
                flow.dx.withUnsafeBufferPointer { fdx in
                    flow.dy.withUnsafeBufferPointer { fdy in
                        output.withUnsafeMutableBufferPointer { out in
                            for y in 0..<height {
                                for x in 0..<width {
                                    let i = y * width + x
                                    let fx = fdx[i]
                                    let fy = fdy[i]

                                    let sr = sample(src.baseAddress!, width, height,
                                                    Float(x) - t * fx, Float(y) - t * fy)
                                    let tr = sample(dst.baseAddress!, width, height,
                                                    Float(x) + (1 - t) * fx, Float(y) + (1 - t) * fy)

                                    let o = i * 4
                                    out[o]     = UInt8(Float(sr.0) * (1 - t) + Float(tr.0) * t)
                                    out[o + 1] = UInt8(Float(sr.1) * (1 - t) + Float(tr.1) * t)
                                    out[o + 2] = UInt8(Float(sr.2) * (1 - t) + Float(tr.2) * t)
                                    out[o + 3] = 255
                                }
                            }
                        }
                    }
                }
            }
        }
        return output
    }

    @inline(__always)
    private static func sample(_ pixels: UnsafePointer<UInt8>, _ width: Int, _ height: Int, _ fx: Float, _ fy: Float) -> (UInt8, UInt8, UInt8) {
        let x = min(max(fx, 0), Float(width - 1))
        let y = min(max(fy, 0), Float(height - 1))
        let x0 = Int(x), y0 = Int(y)
        let x1 = min(x0 + 1, width - 1), y1 = min(y0 + 1, height - 1)
        let wx = x - Float(x0), wy = y - Float(y0)

        @inline(__always) func px(_ px: Int, _ py: Int, _ c: Int) -> Float {
            Float(pixels[(py * width + px) * 4 + c])
        }
        var rgb = (UInt8(0), UInt8(0), UInt8(0))
        for c in 0..<3 {
            let top = px(x0, y0, c) * (1 - wx) + px(x1, y0, c) * wx
            let bottom = px(x0, y1, c) * (1 - wx) + px(x1, y1, c) * wx
            let value = UInt8(min(max(top * (1 - wy) + bottom * wy, 0), 255))
            switch c {
            case 0: rgb.0 = value
            case 1: rgb.1 = value
            default: rgb.2 = value
            }
        }
        return rgb
    }

    private static func rgbaPixels(of image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }

    private static func resized(_ image: CGImage, to size: CGSize) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.interpolationQuality = .medium
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    private static func upscale(_ pixels: [UInt8], from small: CGSize, to canvas: CGSize) -> CGImage? {
        let width = Int(small.width), height = Int(small.height)
        var mutable = pixels
        let space = CGColorSpaceCreateDeviceRGB()
        guard
            let ctx = CGContext(
                data: &mutable, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            let smallImage = ctx.makeImage()
        else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            context.cgContext.interpolationQuality = .high
            UIImage(cgImage: smallImage).draw(in: CGRect(origin: .zero, size: canvas))
        }.cgImage
    }
}

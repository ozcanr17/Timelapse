import Vision
import UIKit

/// Bir karedeki hizalama çıpası: öznenin normalize (0…1, origin sol-üst) merkezi,
/// yüksekliği ve dönüş açısı (roll, radyan). Roll yalnızca yüzlerde ölçülür.
struct FrameAnchor: Equatable {
    let center: CGPoint
    let height: CGFloat
    let roll: CGFloat
}

/// Akıllı Hizalama'nın beyni. Önce yüz arar (VNDetectFaceRectangles — konum, boyut ve
/// eğim/roll verir). Yüz yoksa dikkat-temelli belirginlik (saliency) ile ana özneyi
/// bulur — böylece evcil hayvan, bitki veya nesne projeleri de hizalanır. Bu çıpalar
/// dışa aktarımda özneyi tüm karelerde aynı konum, boyut ve açıya sabitler.
enum FrameAligner {

    static func anchor(in imageData: Data) -> FrameAnchor? {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        if let face = faceAnchor(handler) { return face }
        return saliencyAnchor(handler)
    }

    /// En büyük yüz: konum + boyut + roll (eğim). Roll sayesinde dışa aktarımda kareyi
    /// biraz döndürüp özneyi düz tutabiliyoruz.
    private static func faceAnchor(_ handler: VNImageRequestHandler) -> FrameAnchor? {
        let request = VNDetectFaceRectanglesRequest()
        request.revision = VNDetectFaceRectanglesRequestRevision3   // roll/yaw sağlar
        try? handler.perform([request])
        guard
            let face = request.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height })
        else { return nil }

        let box = face.boundingBox
        return FrameAnchor(
            center: CGPoint(x: box.midX, y: 1 - box.midY),   // Vision origin sol-alt → sol-üst
            height: box.height,
            roll: CGFloat(truncating: face.roll ?? 0)
        )
    }

    /// Yüz yoksa: en belirgin nesnenin kutusu (evcil hayvan/bitki/nesne). Roll ölçülmez.
    private static func saliencyAnchor(_ handler: VNImageRequestHandler) -> FrameAnchor? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([request])
        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            let salient = observation.salientObjects?.max(by: { $0.boundingBox.height < $1.boundingBox.height })
        else { return nil }

        let box = salient.boundingBox
        return FrameAnchor(
            center: CGPoint(x: box.midX, y: 1 - box.midY),
            height: box.height,
            roll: 0
        )
    }

    private static func cgOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up:            .up
        case .upMirrored:    .upMirrored
        case .down:          .down
        case .downMirrored:  .downMirrored
        case .left:          .left
        case .leftMirrored:  .leftMirrored
        case .right:         .right
        case .rightMirrored: .rightMirrored
        @unknown default:    .up
        }
    }
}

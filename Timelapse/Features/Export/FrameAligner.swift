import Vision
import UIKit

/// Bir karedeki hizalama çıpası: öznenin normalize (0…1, origin sol-üst) merkezi,
/// karakteristik yüksekliği ve dönüş açısı (roll, radyan).
struct FrameAnchor: Equatable {
    let center: CGPoint
    let height: CGFloat
    let roll: CGFloat
}

/// Akıllı Hizalama'nın beyni. En doğru sonuç için önce yüz KİLİT NOKTALARINI (gözler)
/// kullanır: göz orta noktası merkezi, göz çizgisi açısı roll'ü, yüz kutusu da boyutu
/// verir. Bu, kaba yüz kutusundan çok daha kararlı bir hizalama sağlar. Kilit nokta
/// yoksa yüz kutusuna, o da yoksa dikkat-temelli belirginliğe (saliency) düşer — böylece
/// evcil hayvan, bitki ve nesneler de hizalanır.
enum FrameAligner {

    static func anchor(in imageData: Data) -> FrameAnchor? {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        if let landmarks = landmarkAnchor(handler) { return landmarks }
        return saliencyAnchor(handler)
    }

    /// Göz kilit noktalarıyla hizalama (birincil ve en iyi yol). Gözler bulunamazsa
    /// yüz kutusu + roll'e düşer.
    private static func landmarkAnchor(_ handler: VNImageRequestHandler) -> FrameAnchor? {
        let request = VNDetectFaceLandmarksRequest()
        try? handler.perform([request])
        guard let face = request.results?.max(by: { $0.boundingBox.height < $1.boundingBox.height }) else {
            return nil
        }
        let box = face.boundingBox

        if
            let left = eyeCenter(face.landmarks?.leftEye, box: box),
            let right = eyeCenter(face.landmarks?.rightEye, box: box)
        {
            return FrameAnchor(
                center: CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2),
                height: box.height,
                roll: atan2(right.y - left.y, right.x - left.x)   // göz çizgisi eğimi
            )
        }

        // Kilit nokta yok: yüz kutusu + gözlemin roll'ü.
        return FrameAnchor(
            center: CGPoint(x: box.midX, y: 1 - box.midY),
            height: box.height,
            roll: CGFloat(truncating: face.roll ?? 0)
        )
    }

    /// Yüz yoksa: en belirgin nesnenin kutusu. Roll ölçülmez.
    private static func saliencyAnchor(_ handler: VNImageRequestHandler) -> FrameAnchor? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([request])
        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            let salient = observation.salientObjects?.max(by: { $0.boundingBox.height < $1.boundingBox.height })
        else { return nil }

        let box = salient.boundingBox
        return FrameAnchor(center: CGPoint(x: box.midX, y: 1 - box.midY), height: box.height, roll: 0)
    }

    /// Bir göz bölgesinin merkezini görsel-normalize (sol-üst origin) koordinata çevirir.
    /// Kilit noktalar yüz kutusuna göre (sol-alt origin) normalize gelir.
    private static func eyeCenter(_ region: VNFaceLandmarkRegion2D?, box: CGRect) -> CGPoint? {
        guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let count = CGFloat(points.count)
        let inBox = CGPoint(x: sum.x / count, y: sum.y / count)          // kutuya göre, sol-alt
        let imageBottomLeft = CGPoint(x: box.minX + inBox.x * box.width, y: box.minY + inBox.y * box.height)
        return CGPoint(x: imageBottomLeft.x, y: 1 - imageBottomLeft.y)   // sol-üst
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

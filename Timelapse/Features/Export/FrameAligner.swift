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

        let request = VNDetectFaceLandmarksRequest()
        try? handler.perform([request])
        guard let faces = request.results, !faces.isEmpty else { return nil }

        if faces.count == 1 { return faceAnchor(faces[0]) }
        return groupAnchor(faces)
    }

    static func translationOffset(targetData: Data, referenceData: Data) -> CGSize? {
        let working = CGSize(width: 480, height: 640)
        guard
            let target = normalized(targetData, size: working),
            let reference = normalized(referenceData, size: working)
        else { return nil }

        let request = VNTranslationalImageRegistrationRequest(targetedCGImage: target)
        do {
            try VNImageRequestHandler(cgImage: reference, options: [:]).perform([request])
        } catch { return nil }

        guard let observation = request.results?.first as? VNImageTranslationAlignmentObservation else {
            return nil
        }
        let transform = observation.alignmentTransform
        return CGSize(width: transform.tx / working.width, height: transform.ty / working.height)
    }

    private static func faceAnchor(_ face: VNFaceObservation) -> FrameAnchor {
        let box = face.boundingBox
        if
            let left = eyeCenter(face.landmarks?.leftEye, box: box),
            let right = eyeCenter(face.landmarks?.rightEye, box: box)
        {
            return FrameAnchor(
                center: CGPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2),
                height: box.height,
                roll: atan2(right.y - left.y, right.x - left.x)
            )
        }
        return FrameAnchor(
            center: CGPoint(x: box.midX, y: 1 - box.midY),
            height: box.height,
            roll: CGFloat(truncating: face.roll ?? 0)
        )
    }

    private static func groupAnchor(_ faces: [VNFaceObservation]) -> FrameAnchor {
        let centers = faces.map { CGPoint(x: $0.boundingBox.midX, y: 1 - $0.boundingBox.midY) }
        let cx = centers.map(\.x).reduce(0, +) / CGFloat(centers.count)
        let cy = centers.map(\.y).reduce(0, +) / CGFloat(centers.count)
        let tops = faces.map { 1 - $0.boundingBox.maxY }
        let bottoms = faces.map { 1 - $0.boundingBox.minY }
        let span = (bottoms.max() ?? 1) - (tops.min() ?? 0)
        return FrameAnchor(center: CGPoint(x: cx, y: cy), height: max(span, 0.1), roll: 0)
    }

    private static func normalized(_ data: Data, size: CGSize) -> CGImage? {
        guard let image = UIImage(data: data) else { return nil }
        let scale = max(size.width / max(image.size.width, 1), size.height / max(image.size.height, 1))
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(x: (size.width - drawSize.width) / 2, y: (size.height - drawSize.height) / 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
        return rendered.cgImage
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

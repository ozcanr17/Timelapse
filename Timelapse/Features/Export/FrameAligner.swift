import Vision
import UIKit

/// Bir karedeki hizalama çıpası: öznenin normalize (0…1, origin sol-üst) merkezi,
/// karakteristik yüksekliği ve dönüş açısı (roll, radyan).
struct FrameAnchor: Equatable {
    let center: CGPoint
    let height: CGFloat
    let roll: CGFloat
}

/// Hizalamanın hangi özneyi kilitleyeceği. Proje türünden türetilir:
/// çift modu → tüm yüzlerin ortası; fitness → gövde; hamilelik → karın; diğer → öne
/// çıkan tek yüz (yoksa belirginlik).
enum AlignmentSubject: String, Equatable {
    case auto
    case group
    case body
    case belly
}

enum FrameAligner {

    static func anchor(in imageData: Data, subject: AlignmentSubject = .auto) -> FrameAnchor? {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        switch subject {
        case .group:
            return faceBasedAnchor(handler: handler, group: true)
        case .auto:
            return faceBasedAnchor(handler: handler, group: false) ?? saliencyAnchor(handler: handler)
        case .body, .belly:
            return bodyAnchor(handler: handler, mode: subject)
                ?? faceBasedAnchor(handler: handler, group: false)
                ?? saliencyAnchor(handler: handler)
        }
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

    /// Yüz temelli çıpa. `group` ise (çift modu) tüm yüzlerin ortası; değilse en öne
    /// çıkan (en büyük kutulu) yüz kilitlenir — böylece karede iki kişi olsa da odaktaki
    /// kişi sabit kalır.
    private static func faceBasedAnchor(handler: VNImageRequestHandler, group: Bool) -> FrameAnchor? {
        let request = VNDetectFaceLandmarksRequest()
        try? handler.perform([request])
        guard let faces = request.results, !faces.isEmpty else { return nil }

        if group { return groupAnchor(faces) }
        if faces.count == 1 { return faceAnchor(faces[0]) }
        let prominent = faces.max { lhs, rhs in
            lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
        }
        return prominent.map(faceAnchor)
    }

    /// Gövde/karın çıpası: insan pozu kilit noktalarından (omuz, kalça, boyun, kök)
    /// gövdeyi bulur. Fitness → gövde ortası; hamilelik → karın (kalçadan omuza doğru
    /// %30). Ölçek referansı gövde boyu olduğundan karın büyürken bile çerçevede kalır.
    private static func bodyAnchor(handler: VNImageRequestHandler, mode: AlignmentSubject) -> FrameAnchor? {
        let request = VNDetectHumanBodyPoseRequest()
        try? handler.perform([request])
        guard let observation = request.results?.first else { return nil }

        func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
            guard let recognized = try? observation.recognizedPoint(joint), recognized.confidence > 0.2 else { return nil }
            return CGPoint(x: recognized.location.x, y: 1 - recognized.location.y)
        }

        let leftShoulder = point(.leftShoulder)
        let rightShoulder = point(.rightShoulder)
        let leftHip = point(.leftHip)
        let rightHip = point(.rightHip)

        guard
            let top = midpoint(leftShoulder, rightShoulder) ?? point(.neck),
            let bottom = midpoint(leftHip, rightHip) ?? point(.root)
        else { return nil }

        let torsoHeight = max(hypot(bottom.x - top.x, bottom.y - top.y), 0.05)
        let roll: CGFloat = {
            if let leftShoulder, let rightShoulder {
                return atan2(rightShoulder.y - leftShoulder.y, rightShoulder.x - leftShoulder.x)
            }
            return 0
        }()

        let center: CGPoint
        switch mode {
        case .belly:
            center = CGPoint(x: bottom.x + 0.30 * (top.x - bottom.x), y: bottom.y + 0.30 * (top.y - bottom.y))
        default:
            center = CGPoint(x: (top.x + bottom.x) / 2, y: (top.y + bottom.y) / 2)
        }
        return FrameAnchor(center: center, height: torsoHeight, roll: roll)
    }

    /// Yüz/gövde bulunamayınca son çare: dikkat-temelli belirginlik (saliency) ile
    /// karedeki en dikkat çeken bölgeyi kilitler.
    private static func saliencyAnchor(handler: VNImageRequestHandler) -> FrameAnchor? {
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        try? handler.perform([request])
        guard
            let observation = request.results?.first as? VNSaliencyImageObservation,
            let salient = observation.salientObjects?.max(by: { $0.confidence < $1.confidence })
        else { return nil }
        let box = salient.boundingBox
        return FrameAnchor(center: CGPoint(x: box.midX, y: 1 - box.midY), height: max(box.height, 0.05), roll: 0)
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

    private static func midpoint(_ a: CGPoint?, _ b: CGPoint?) -> CGPoint? {
        switch (a, b) {
        case let (a?, b?): CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        case let (a?, nil): a
        case let (nil, b?): b
        default: nil
        }
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

    private static func eyeCenter(_ region: VNFaceLandmarkRegion2D?, box: CGRect) -> CGPoint? {
        guard let points = region?.normalizedPoints, !points.isEmpty else { return nil }
        let sum = points.reduce(CGPoint.zero) { CGPoint(x: $0.x + $1.x, y: $0.y + $1.y) }
        let count = CGFloat(points.count)
        let inBox = CGPoint(x: sum.x / count, y: sum.y / count)
        let imageBottomLeft = CGPoint(x: box.minX + inBox.x * box.width, y: box.minY + inBox.y * box.height)
        return CGPoint(x: imageBottomLeft.x, y: 1 - imageBottomLeft.y)
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

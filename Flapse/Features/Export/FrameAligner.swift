import Vision
import UIKit

/// Bir karedeki hizalama çıpası: öznenin normalize (0…1, origin sol-üst) merkezi,
/// karakteristik yüksekliği ve dönüş açısı (roll, radyan).
struct FrameAnchor: Equatable {
    let center: CGPoint
    let height: CGFloat
    let roll: CGFloat
}

enum AlignmentSubject: String, Equatable {
    case auto
    case group
    case body
    case belly
}

enum FrameAligner {

    private struct CoupleFacePair {
        let left: VNFeaturePrintObservation
        let right: VNFeaturePrintObservation
    }

    static func coupleMirrorFlags(for frames: [Data]) -> [Bool] {
        let pairs = frames.map(coupleFacePair)
        guard let reference = pairs.compactMap({ $0 }).first else {
            return Array(repeating: false, count: frames.count)
        }
        return pairs.map { pair in
            guard let pair,
                  let leftToLeft = featureDistance(reference.left, pair.left),
                  let rightToRight = featureDistance(reference.right, pair.right),
                  let leftToRight = featureDistance(reference.left, pair.right),
                  let rightToLeft = featureDistance(reference.right, pair.left)
            else { return false }
            return shouldMirror(
                sameDistance: leftToLeft + rightToRight,
                mirroredDistance: leftToRight + rightToLeft
            )
        }
    }

    static func shouldMirror(sameDistance: Float, mirroredDistance: Float) -> Bool {
        mirroredDistance + 0.02 < sameDistance
    }

    static func anchor(in imageData: Data, subject: AlignmentSubject = .auto) -> FrameAnchor? {
        guard let image = UIImage(data: imageData), let cgImage = image.cgImage else { return nil }
        let orientation = cgOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        switch subject {
        case .group:
            return nil
        case .auto:
            return faceBasedAnchor(handler: handler) ?? saliencyAnchor(handler: handler)
        case .body, .belly:
            return bodyAnchor(handler: handler, mode: subject)
                ?? faceBasedAnchor(handler: handler)
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

    private static func faceBasedAnchor(handler: VNImageRequestHandler) -> FrameAnchor? {
        let request = VNDetectFaceLandmarksRequest()
        try? handler.perform([request])
        guard let faces = request.results, !faces.isEmpty else { return nil }

        if faces.count == 1 { return faceAnchor(faces[0]) }
        let prominent = faces.max { lhs, rhs in
            lhs.boundingBox.width * lhs.boundingBox.height < rhs.boundingBox.width * rhs.boundingBox.height
        }
        return prominent.map(faceAnchor)
    }

    private static func coupleFacePair(_ imageData: Data) -> CoupleFacePair? {
        guard let image = ImageDownsampler.image(from: imageData, maxPixelSize: 1280),
              let cgImage = image.cgImage else { return nil }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        try? handler.perform([request])
        guard let faces = request.results, faces.count >= 2 else { return nil }
        let primaryFaces = faces
            .sorted { lhs, rhs in
                lhs.boundingBox.width * lhs.boundingBox.height > rhs.boundingBox.width * rhs.boundingBox.height
            }
            .prefix(2)
            .sorted { $0.boundingBox.midX < $1.boundingBox.midX }
        guard primaryFaces.count == 2,
              let leftImage = faceCrop(cgImage, box: primaryFaces[0].boundingBox),
              let rightImage = faceCrop(cgImage, box: primaryFaces[1].boundingBox),
              let left = featurePrint(leftImage),
              let right = featurePrint(rightImage)
        else { return nil }
        return CoupleFacePair(left: left, right: right)
    }

    private static func faceCrop(_ image: CGImage, box: CGRect) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        var rect = CGRect(
            x: box.minX * width,
            y: (1 - box.maxY) * height,
            width: box.width * width,
            height: box.height * height
        )
        rect = rect.insetBy(dx: -rect.width * 0.35, dy: -rect.height * 0.35)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard rect.width >= 32, rect.height >= 32 else { return nil }
        return image.cropping(to: rect.integral)
    }

    private static func featurePrint(_ image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        try? VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
        return request.results?.first as? VNFeaturePrintObservation
    }

    private static func featureDistance(
        _ reference: VNFeaturePrintObservation,
        _ candidate: VNFeaturePrintObservation
    ) -> Float? {
        var distance: Float = 0
        guard (try? reference.computeDistance(&distance, to: candidate)) != nil else { return nil }
        return distance
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

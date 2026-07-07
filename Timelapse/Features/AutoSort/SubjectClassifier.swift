import Vision
import UIKit

protocol SubjectClassifying: Sendable {
    func signature(for imageData: Data) async -> SubjectSignature
}

struct SubjectClassifier: SubjectClassifying {

    func signature(for imageData: Data) async -> SubjectSignature {
        await Task.detached(priority: .userInitiated) {
            Self.compute(imageData)
        }.value
    }

    static func compute(_ data: Data) -> SubjectSignature {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else { return .empty }
        let orientation = cgOrientation(from: image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        let faceRequest = VNDetectFaceRectanglesRequest()
        let animalRequest = VNRecognizeAnimalsRequest()
        let classifyRequest = VNClassifyImageRequest()
        try? handler.perform([faceRequest, animalRequest, classifyRequest])

        var kind: SubjectKind = .unknown
        var labels: [String] = []

        if let faces = faceRequest.results, !faces.isEmpty {
            kind = .person
        } else if let animals = animalRequest.results, !animals.isEmpty {
            kind = .animal
            labels = animals.compactMap { $0.labels.first?.identifier }
        } else if let classifications = classifyRequest.results {
            let top = classifications.filter { $0.confidence > 0.1 }.prefix(6)
            labels = top.map(\.identifier)
            kind = kindFromLabels(labels)
        }

        let vector = featurePrint(cgImage, orientation: orientation)
        return SubjectSignature(kind: kind, vector: FeatureVector.normalized(vector), labels: labels)
    }

    private static func featurePrint(_ cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else { return [] }
        let data = observation.data
        let count = observation.elementCount
        return data.withUnsafeBytes { raw in
            let base = raw.bindMemory(to: Float.self)
            return Array(UnsafeBufferPointer(start: base.baseAddress, count: min(count, base.count)))
        }
    }

    private static func kindFromLabels(_ labels: [String]) -> SubjectKind {
        let plantKeywords = ["plant", "flower", "tree", "leaf", "succulent", "cactus", "houseplant", "fern", "bonsai", "garden", "seedling", "fruit", "vegetable"]
        for label in labels {
            let lower = label.lowercased()
            if plantKeywords.contains(where: { lower.contains($0) }) {
                return .plant
            }
        }
        return labels.isEmpty ? .unknown : .object
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

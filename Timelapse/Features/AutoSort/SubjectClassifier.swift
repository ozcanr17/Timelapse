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
        guard
            let image = ImageDownsampler.image(from: data, maxPixelSize: 1024),
            let cgImage = image.cgImage
        else { return .empty }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])

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

        var focus = cgImage
        if kind == .person,
           let box = largestFaceBox(faceRequest.results),
           let crop = faceCrop(cgImage, normalizedBox: box) {
            focus = crop
        }

        let vector = featurePrint(focus)
        return SubjectSignature(kind: kind, vector: FeatureVector.normalized(vector), labels: labels)
    }

    /// Kişi fotoğraflarında imza tüm sahneden değil YÜZ bölgesinden çıkarılır; böylece
    /// arka plan ve kıyafet değişse de aynı kişi aynı projeye eşleşir.
    private static func largestFaceBox(_ faces: [VNFaceObservation]?) -> CGRect? {
        faces?.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })?.boundingBox
    }

    private static func faceCrop(_ cgImage: CGImage, normalizedBox box: CGRect) -> CGImage? {
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        var rect = CGRect(
            x: box.minX * width,
            y: (1 - box.maxY) * height,
            width: box.width * width,
            height: box.height * height
        )
        rect = rect.insetBy(dx: -rect.width * 0.45, dy: -rect.height * 0.45)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        guard rect.width >= 32, rect.height >= 32 else { return nil }
        return cgImage.cropping(to: rect.integral)
    }

    private static func featurePrint(_ cgImage: CGImage) -> [Float] {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
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

}

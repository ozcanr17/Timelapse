import Foundation

enum SubjectKind: String, Codable, CaseIterable {
    case person
    case animal
    case plant
    case object
    case unknown

    var suggestedCategory: ProjectCategory {
        switch self {
        case .person: .selfPortrait
        case .animal: .pet
        case .plant: .plant
        case .object, .unknown: .other
        }
    }
}

struct SubjectSignature: Equatable {
    let kind: SubjectKind
    let vector: [Float]
    let labels: [String]

    var isEmpty: Bool { vector.isEmpty }

    static let empty = SubjectSignature(kind: .unknown, vector: [], labels: [])
}

enum FeatureVector {

    static func data(from vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    static func vector(from data: Data) -> [Float] {
        guard !data.isEmpty else { return [] }
        let count = data.count / MemoryLayout<Float>.stride
        return data.withUnsafeBytes { raw in
            let base = raw.bindMemory(to: Float.self)
            return Array(UnsafeBufferPointer(start: base.baseAddress, count: count))
        }
    }

    static func normalized(_ vector: [Float]) -> [Float] {
        let magnitude = vector.reduce(Float(0)) { $0 + $1 * $1 }.squareRoot()
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    static func distance(_ a: [Float], _ b: [Float]) -> Float {
        guard !a.isEmpty, a.count == b.count else { return .greatestFiniteMagnitude }
        var sum: Float = 0
        for index in a.indices {
            let delta = a[index] - b[index]
            sum += delta * delta
        }
        return sum.squareRoot()
    }
}

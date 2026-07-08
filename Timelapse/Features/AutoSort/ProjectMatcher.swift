import Foundation

struct ProjectSignatureSet: Equatable {
    let projectID: UUID
    let kind: SubjectKind
    let vectors: [[Float]]
}

struct ProjectMatch: Equatable {
    let projectID: UUID
    let distance: Float
}

enum ProjectMatcher {

    static let autoAssignDistance: Float = 0.65
    static let suggestDistance: Float = 0.95

    enum Decision: Equatable {
        case autoAssign(UUID)
        case suggest(UUID)
        case chooseManually
    }

    static func nearest(for signature: SubjectSignature, among sets: [ProjectSignatureSet]) -> ProjectMatch? {
        guard !signature.isEmpty else { return nil }
        var best: ProjectMatch?
        for set in sets {
            guard kindCompatible(signature.kind, set.kind) else { continue }
            for vector in set.vectors {
                let distance = FeatureVector.distance(signature.vector, vector)
                if best == nil || distance < best!.distance {
                    best = ProjectMatch(projectID: set.projectID, distance: distance)
                }
            }
        }
        return best
    }

    static func decide(for signature: SubjectSignature, among sets: [ProjectSignatureSet]) -> Decision {
        guard let match = nearest(for: signature, among: sets) else { return .chooseManually }
        if match.distance <= autoAssignDistance { return .autoAssign(match.projectID) }
        if match.distance <= suggestDistance { return .suggest(match.projectID) }
        return .chooseManually
    }

    static func kindCompatible(_ a: SubjectKind, _ b: SubjectKind) -> Bool {
        if a == .unknown || b == .unknown { return true }
        return a == b
    }
}

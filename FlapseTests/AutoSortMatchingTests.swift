import XCTest
@testable import Flapse

final class AutoSortMatchingTests: XCTestCase {

    func test_featureVector_dataRoundTrip() {
        let vector: [Float] = [0.1, -0.5, 2.0, 3.25]
        let restored = FeatureVector.vector(from: FeatureVector.data(from: vector))
        XCTAssertEqual(restored, vector)
    }

    func test_normalized_hasUnitMagnitude() {
        let normalized = FeatureVector.normalized([3, 4])
        let magnitude = (normalized[0] * normalized[0] + normalized[1] * normalized[1]).squareRoot()
        XCTAssertEqual(magnitude, 1, accuracy: 0.0001)
    }

    func test_distance_mismatchedCounts_isMaximal() {
        XCTAssertEqual(FeatureVector.distance([1, 2], [1]), .greatestFiniteMagnitude)
    }

    func test_decide_autoAssign_whenVeryClose() {
        let id = UUID()
        let signature = SubjectSignature(kind: .person, vector: [1, 0], labels: [])
        let sets = [ProjectSignatureSet(projectID: id, kind: .person, vectors: [[1, 0]])]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .autoAssign(id))
    }

    func test_decide_suggest_whenModeratelyClose() {
        let id = UUID()
        let signature = SubjectSignature(kind: .person, vector: [1, 0], labels: [])
        let sets = [ProjectSignatureSet(projectID: id, kind: .person, vectors: [[1, 0.7]])]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .suggest(id))
    }

    func test_decide_chooseManually_whenFar() {
        let id = UUID()
        let signature = SubjectSignature(kind: .person, vector: [1, 0], labels: [])
        let sets = [ProjectSignatureSet(projectID: id, kind: .person, vectors: [[1, 1.4]])]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .chooseManually)
    }

    func test_decide_incompatibleKind_isSkipped() {
        let id = UUID()
        let signature = SubjectSignature(kind: .person, vector: [1, 0], labels: [])
        let sets = [ProjectSignatureSet(projectID: id, kind: .plant, vectors: [[1, 0]])]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .chooseManually)
    }

    func test_decide_emptySignature_choosesManually() {
        let sets = [ProjectSignatureSet(projectID: UUID(), kind: .person, vectors: [[1, 0]])]
        XCTAssertEqual(ProjectMatcher.decide(for: .empty, among: sets), .chooseManually)
    }

    func test_decide_unknownKind_neverAutoAssigns() {
        let id = UUID()
        let signature = SubjectSignature(kind: .unknown, vector: [1, 0], labels: [])
        let sets = [ProjectSignatureSet(projectID: id, kind: .person, vectors: [[1, 0]])]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .suggest(id))
    }

    func test_decide_ambiguousProjects_downgradesToSuggest() {
        let first = UUID()
        let second = UUID()
        let signature = SubjectSignature(kind: .person, vector: [1, 0], labels: [])
        let sets = [
            ProjectSignatureSet(projectID: first, kind: .person, vectors: [[1, 0.3]]),
            ProjectSignatureSet(projectID: second, kind: .person, vectors: [[1, 0.33]])
        ]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .suggest(first))
    }

    func test_decide_clearWinner_stillAutoAssigns() {
        let near = UUID()
        let far = UUID()
        let signature = SubjectSignature(kind: .person, vector: [1, 0], labels: [])
        let sets = [
            ProjectSignatureSet(projectID: near, kind: .person, vectors: [[1, 0.1]]),
            ProjectSignatureSet(projectID: far, kind: .person, vectors: [[1, 0.9]])
        ]
        XCTAssertEqual(ProjectMatcher.decide(for: signature, among: sets), .autoAssign(near))
    }

    func test_nearest_picksClosestAcrossProjects() {
        let near = UUID()
        let far = UUID()
        let signature = SubjectSignature(kind: .object, vector: [0, 0], labels: [])
        let sets = [
            ProjectSignatureSet(projectID: far, kind: .object, vectors: [[5, 5]]),
            ProjectSignatureSet(projectID: near, kind: .object, vectors: [[0.1, 0]])
        ]
        XCTAssertEqual(ProjectMatcher.nearest(for: signature, among: sets)?.projectID, near)
    }
}

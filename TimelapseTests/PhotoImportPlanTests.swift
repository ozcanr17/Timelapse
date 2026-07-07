import XCTest
@testable import Timelapse

final class PhotoImportPlanTests: XCTestCase {

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(Double(offset) * 86_400)
    }

    func test_allDated_sortedAscendingRegardlessOfSelectionOrder() {
        let items = [
            PhotoImportItem(assetIdentifier: "b", creationDate: day(2), selectionIndex: 0),
            PhotoImportItem(assetIdentifier: "a", creationDate: day(0), selectionIndex: 1),
            PhotoImportItem(assetIdentifier: "c", creationDate: day(4), selectionIndex: 2)
        ]
        let resolved = PhotoImportPlan.resolvedOrder(items)
        XCTAssertEqual(resolved.map(\.assetIdentifier), ["a", "b", "c"])
    }

    func test_undatedMiddle_interpolatedBetweenNeighbors() {
        let items = [
            PhotoImportItem(assetIdentifier: "a", creationDate: day(0), selectionIndex: 0),
            PhotoImportItem(assetIdentifier: "b", creationDate: nil, selectionIndex: 1),
            PhotoImportItem(assetIdentifier: "c", creationDate: day(2), selectionIndex: 2)
        ]
        let resolved = PhotoImportPlan.resolvedOrder(items)
        XCTAssertEqual(resolved.map(\.assetIdentifier), ["a", "b", "c"])
        let b = resolved.first { $0.assetIdentifier == "b" }!
        XCTAssertEqual(b.date.timeIntervalSince1970, day(1).timeIntervalSince1970, accuracy: 1)
    }

    func test_noneDated_spreadBackwardFromNowInSelectionOrder() {
        let now = day(10)
        let items = [
            PhotoImportItem(assetIdentifier: "a", creationDate: nil, selectionIndex: 0),
            PhotoImportItem(assetIdentifier: "b", creationDate: nil, selectionIndex: 1)
        ]
        let resolved = PhotoImportPlan.resolvedOrder(items, now: now)
        XCTAssertEqual(resolved.map(\.assetIdentifier), ["a", "b"])
        XCTAssertEqual(resolved[1].date.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 1)
        XCTAssertLessThan(resolved[0].date, resolved[1].date)
    }

    func test_leadingUndated_placedBeforeFirstDated() {
        let items = [
            PhotoImportItem(assetIdentifier: "x", creationDate: nil, selectionIndex: 0),
            PhotoImportItem(assetIdentifier: "y", creationDate: day(5), selectionIndex: 1)
        ]
        let resolved = PhotoImportPlan.resolvedOrder(items)
        XCTAssertEqual(resolved.map(\.assetIdentifier), ["x", "y"])
        XCTAssertLessThan(resolved[0].date, day(5))
    }

    func test_empty_returnsEmpty() {
        XCTAssertTrue(PhotoImportPlan.resolvedOrder([]).isEmpty)
    }
}

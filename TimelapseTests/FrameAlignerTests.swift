import XCTest
import UIKit
@testable import Timelapse

final class FrameAlignerTests: XCTestCase {

    private func pattern(offsetX: CGFloat, offsetY: CGFloat) -> Data {
        let size = CGSize(width: 480, height: 640)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let c = ctx.cgContext
            UIColor.white.setFill()
            c.fill(CGRect(x: 210 + offsetX, y: 210 + offsetY, width: 60, height: 60))
            UIColor(white: 0.55, alpha: 1).setFill()
            c.fillEllipse(in: CGRect(x: 140 + offsetX, y: 330 + offsetY, width: 60, height: 60))
            UIColor.white.setFill()
            c.fill(CGRect(x: 300 + offsetX, y: 380 + offsetY, width: 34, height: 110))
        }
        return image.jpegData(compressionQuality: 0.95)!
    }

    func test_translationOffset_detectsKnownShift_withConsistentSign() {
        let reference = pattern(offsetX: 0, offsetY: 0)
        let target = pattern(offsetX: 48, offsetY: 64)

        guard let offset = FrameAligner.translationOffset(targetData: target, referenceData: reference) else {
            return XCTFail("Kayıt (registration) bir öteleme döndürmeliydi")
        }

        XCTAssertEqual(offset.width, -0.1, accuracy: 0.035)
        XCTAssertEqual(offset.height, 0.1, accuracy: 0.035)
    }

    func test_translationOffset_identicalFrames_isNearZero() {
        let reference = pattern(offsetX: 0, offsetY: 0)

        guard let offset = FrameAligner.translationOffset(targetData: reference, referenceData: reference) else {
            return XCTFail("Aynı kare için öteleme sıfıra yakın olmalı")
        }

        XCTAssertEqual(offset.width, 0, accuracy: 0.02)
        XCTAssertEqual(offset.height, 0, accuracy: 0.02)
    }
}

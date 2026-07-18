import XCTest
import UIKit
@testable import Flapse

final class PhotoImageEditorTests: XCTestCase {

    func testHorizontalFlipReversesEdgeColors() {
        let image = horizontalPattern()

        let flipped = PhotoImageEditor.apply(.horizontalFlip, to: image)

        XCTAssertEqual(pixel(in: flipped, x: 0, y: 0), [0, 0, 255, 255])
        XCTAssertEqual(pixel(in: flipped, x: 1, y: 0), [255, 0, 0, 255])
    }

    func testVerticalFlipReversesEdgeColors() {
        let image = verticalPattern()

        let flipped = PhotoImageEditor.apply(.verticalFlip, to: image)

        XCTAssertEqual(pixel(in: flipped, x: 0, y: 0), [0, 0, 255, 255])
        XCTAssertEqual(pixel(in: flipped, x: 0, y: 1), [255, 0, 0, 255])
    }

    func testRotateClockwiseSwapsDimensions() {
        let image = horizontalPattern()

        let rotated = PhotoImageEditor.apply(.rotateClockwise, to: image)

        XCTAssertEqual(rotated.size.width, 1)
        XCTAssertEqual(rotated.size.height, 2)
    }

    func testNineSixteenCropUsesCenteredPortraitRect() {
        let rect = PhotoCropGeometry.cropRect(
            imageSize: CGSize(width: 400, height: 300),
            cropAspect: 9.0 / 16.0,
            zoom: 1,
            offset: .zero,
            displaySize: CGSize(width: 180, height: 320)
        )

        XCTAssertEqual(rect.width, 168.75, accuracy: 0.001)
        XCTAssertEqual(rect.height, 300, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 200, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 150, accuracy: 0.001)
    }

    func testSixteenNineCropUsesCenteredLandscapeRect() {
        let rect = PhotoCropGeometry.cropRect(
            imageSize: CGSize(width: 300, height: 400),
            cropAspect: 16.0 / 9.0,
            zoom: 1,
            offset: .zero,
            displaySize: CGSize(width: 320, height: 180)
        )

        XCTAssertEqual(rect.width, 300, accuracy: 0.001)
        XCTAssertEqual(rect.height, 168.75, accuracy: 0.001)
        XCTAssertEqual(rect.midX, 150, accuracy: 0.001)
        XCTAssertEqual(rect.midY, 200, accuracy: 0.001)
    }

    func testCropOffsetMovesVisibleRectWithoutLeavingImage() {
        let imageSize = CGSize(width: 400, height: 300)
        let displaySize = CGSize(width: 180, height: 320)
        let limit = PhotoCropGeometry.maxOffset(
            imageSize: imageSize,
            displaySize: displaySize,
            zoom: 1
        )
        let rect = PhotoCropGeometry.cropRect(
            imageSize: imageSize,
            cropAspect: 9.0 / 16.0,
            zoom: 1,
            offset: CGSize(width: limit.width, height: 0),
            displaySize: displaySize
        )

        XCTAssertEqual(rect.minX, 0, accuracy: 0.001)
        XCTAssertEqual(rect.maxX, 168.75, accuracy: 0.001)
    }

    private func horizontalPattern() -> UIImage {
        image(width: 2, height: 1) { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: 1, y: 0, width: 1, height: 1))
        }
    }

    private func verticalPattern() -> UIImage {
        image(width: 1, height: 2) { context in
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
            context.setFillColor(UIColor.blue.cgColor)
            context.fill(CGRect(x: 0, y: 1, width: 1, height: 1))
        }
    }

    private func image(width: Int, height: Int, draw: (CGContext) -> Void) -> UIImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        draw(context)
        return UIImage(cgImage: context.makeImage()!)
    }

    private func pixel(in image: UIImage, x: Int, y: Int) -> [UInt8] {
        guard let cgImage = image.cgImage,
              let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return [] }
        let offset = y * cgImage.bytesPerRow + x * 4
        return Array(UnsafeBufferPointer(start: bytes + offset, count: 4))
    }
}

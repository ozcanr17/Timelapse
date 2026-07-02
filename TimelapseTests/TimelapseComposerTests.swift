import XCTest
import AVFoundation
import UIKit
@testable import Timelapse

final class TimelapseComposerTests: XCTestCase {

    private func frameData(_ index: Int) -> Data {
        let size = CGSize(width: 120, height: 160)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIColor(hue: CGFloat(index % 10) / 10, saturation: 0.8, brightness: 0.9, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    func test_videoDosyasiOlusur_veSuresiKareSayisinaUyar() async throws {
        let frames = (0..<8).map(frameData)
        let settings = TimelapseExportSettings(
            renderSize: CGSize(width: 240, height: 320),
            framesPerSecond: 8,
            includesWatermark: true
        )

        let url = try await TimelapseComposer().makeVideo(from: frames, settings: settings, onProgress: { _ in })
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let duration = try await AVURLAsset(url: url).load(.duration)
        XCTAssertEqual(duration.seconds, 1.0, accuracy: 0.3)
    }

    func test_ikidenAzKare_hataVerir() async {
        do {
            _ = try await TimelapseComposer().makeVideo(
                from: [frameData(0)],
                settings: .current(isPro: false),
                onProgress: { _ in }
            )
            XCTFail("notEnoughFrames hatası bekleniyordu")
        } catch {
            XCTAssertEqual(error as? TimelapseComposerError, .notEnoughFrames)
        }
    }

    func test_bozukKareVerisi_hataVerir() async {
        do {
            _ = try await TimelapseComposer().makeVideo(
                from: [Data([0x00]), Data([0x01])],
                settings: .current(isPro: false),
                onProgress: { _ in }
            )
            XCTFail("frameDecodingFailed hatası bekleniyordu")
        } catch {
            XCTAssertEqual(error as? TimelapseComposerError, .frameDecodingFailed)
        }
    }
}

final class TimelapseExportSettingsTests: XCTestCase {

    func test_proAyarlari_yuksekCozunurlukVeFiligransiz() {
        let settings = TimelapseExportSettings.current(isPro: true)

        XCTAssertEqual(settings.renderSize, CGSize(width: 2160, height: 2880))
        XCTAssertFalse(settings.includesWatermark)
    }

    func test_ucretsizAyarlar_dusukCozunurlukVeFiligranli() {
        let settings = TimelapseExportSettings.current(isPro: false)

        XCTAssertEqual(settings.renderSize, CGSize(width: 720, height: 960))
        XCTAssertTrue(settings.includesWatermark)
    }
}

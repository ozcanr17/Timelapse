import XCTest
import UIKit
@testable import Flapse

@MainActor
final class TimelapseExportViewModelTests: XCTestCase {

    private final class FakeComposer: TimelapseComposing {
        var result: Result<URL, Error> = .success(URL(fileURLWithPath: "/tmp/fake.mp4"))
        private(set) var receivedFrames: [TimelapseFrame] = []
        private(set) var receivedSettings: TimelapseExportSettings?

        func makeVideo(
            from frames: [TimelapseFrame],
            settings: TimelapseExportSettings,
            onProgress: @escaping @Sendable (Double) -> Void
        ) async throws -> URL {
            receivedFrames = frames
            receivedSettings = settings
            onProgress(1)
            return try result.get()
        }
    }

    private struct DummyError: Error {}

    private func frames(_ count: Int) -> [TimelapseFrame] {
        (0..<count).map {
            TimelapseFrame(imageData: Data([UInt8($0 + 1)]), capturedAt: Date(timeIntervalSince1970: Double($0)))
        }
    }

    func test_basariliExport_finishedOlur() async {
        let composer = FakeComposer()
        let viewModel = TimelapseExportViewModel(composer: composer)

        viewModel.export(frames: frames(2), isPro: false)
        await viewModel.waitForRender()

        XCTAssertEqual(viewModel.phase, .finished(URL(fileURLWithPath: "/tmp/fake.mp4")))
        XCTAssertEqual(composer.receivedFrames.count, 2)
        XCTAssertEqual(composer.receivedSettings, .current(isPro: false))
    }

    func test_proKullanici_proAyarlariylaExportEder() async {
        let composer = FakeComposer()
        let viewModel = TimelapseExportViewModel(composer: composer)

        viewModel.export(frames: frames(2), isPro: true)
        await viewModel.waitForRender()

        XCTAssertEqual(composer.receivedSettings, .current(isPro: true))
    }

    func test_ikidenAzKare_failedOlur() async {
        let composer = FakeComposer()
        let viewModel = TimelapseExportViewModel(composer: composer)

        viewModel.export(frames: frames(1), isPro: false)
        await viewModel.waitForRender()

        guard case .failed = viewModel.phase else {
            return XCTFail("Durum .failed olmalıydı, ama \(viewModel.phase) bulundu")
        }
        XCTAssertTrue(composer.receivedFrames.isEmpty)
    }

    func test_composerHatasi_failedOlur() async {
        let composer = FakeComposer()
        composer.result = .failure(DummyError())
        let viewModel = TimelapseExportViewModel(composer: composer)

        viewModel.export(frames: frames(2), isPro: false)
        await viewModel.waitForRender()

        guard case .failed = viewModel.phase else {
            return XCTFail("Durum .failed olmalıydı, ama \(viewModel.phase) bulundu")
        }
    }

    func test_loopedCutTimes_herKesimBirVurusaDenkGelir() {
        let beats = [0.5, 1.0, 1.5, 2.0]
        let cuts = TimelapseExportViewModel.loopedCutTimes(beats: beats, frameCount: 3, audioDuration: 10)
        XCTAssertEqual(cuts, [0.5, 1.0, 1.5])
    }

    func test_loopedCutTimes_sarkiBitinceIzgaraDonguyleKayar() {
        let beats = [0.5, 1.5]
        let cuts = TimelapseExportViewModel.loopedCutTimes(beats: beats, frameCount: 5, audioDuration: 2.0)
        XCTAssertEqual(cuts, [0.5, 1.5, 2.5, 3.5, 4.5])
    }

    func test_loopedCutTimes_sureBilinmiyorsaAralikTekrarlanir() {
        let beats = [1.0, 2.0]
        let cuts = TimelapseExportViewModel.loopedCutTimes(beats: beats, frameCount: 4, audioDuration: 0)
        XCTAssertEqual(cuts, [1.0, 2.0, 3.0, 4.0])
    }

    func test_adaptiveCutTimes_yavasVideodaVuruslariZamanaYayar() {
        let beats = stride(from: 0.5, through: 5.0, by: 0.5).map { $0 }
        let cuts = AdaptiveEditEngine.cutTimes(
            beats: beats,
            frameCount: 4,
            audioDuration: 6,
            targetDuration: 4
        )

        XCTAssertEqual(cuts.count, 4)
        XCTAssertEqual(cuts.first, 0.5)
        XCTAssertGreaterThanOrEqual(cuts.last ?? 0, 4)
        XCTAssertTrue(zip(cuts, cuts.dropFirst()).allSatisfy(<))
    }

    func test_adaptiveTransition_benzerKarelerdeAkiskanGecisSecer() throws {
        let image = try XCTUnwrap(solidImage(.systemBlue))
        XCTAssertEqual(AdaptiveEditEngine.transition(from: image, to: image), .morph)
    }

    func test_adaptiveTransition_cokFarkliKarelerdeKesmeSecer() throws {
        let dark = try XCTUnwrap(solidImage(.black))
        let light = try XCTUnwrap(solidImage(.white))
        XCTAssertEqual(AdaptiveEditEngine.transition(from: dark, to: light), .cut)
    }

    private func solidImage(_ color: UIColor) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32))
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }.pngData()
    }
}

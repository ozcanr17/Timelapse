import XCTest
@testable import Timelapse

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

        await viewModel.export(frames: frames(2), isPro: false)

        XCTAssertEqual(viewModel.phase, .finished(URL(fileURLWithPath: "/tmp/fake.mp4")))
        XCTAssertEqual(composer.receivedFrames.count, 2)
        XCTAssertEqual(composer.receivedSettings, .current(isPro: false))
    }

    func test_proKullanici_proAyarlariylaExportEder() async {
        let composer = FakeComposer()
        let viewModel = TimelapseExportViewModel(composer: composer)

        await viewModel.export(frames: frames(2), isPro: true)

        XCTAssertEqual(composer.receivedSettings, .current(isPro: true))
    }

    func test_ikidenAzKare_failedOlur() async {
        let composer = FakeComposer()
        let viewModel = TimelapseExportViewModel(composer: composer)

        await viewModel.export(frames: frames(1), isPro: false)

        guard case .failed = viewModel.phase else {
            return XCTFail("Durum .failed olmalıydı, ama \(viewModel.phase) bulundu")
        }
        XCTAssertTrue(composer.receivedFrames.isEmpty)
    }

    func test_composerHatasi_failedOlur() async {
        let composer = FakeComposer()
        composer.result = .failure(DummyError())
        let viewModel = TimelapseExportViewModel(composer: composer)

        await viewModel.export(frames: frames(2), isPro: false)

        guard case .failed = viewModel.phase else {
            return XCTFail("Durum .failed olmalıydı, ama \(viewModel.phase) bulundu")
        }
    }
}

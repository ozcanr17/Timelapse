import XCTest
import SwiftData
import AVFoundation
@testable import Timelapse   // ← kendi hedef (target) adınla değiştir

/// Kamera akışını GERÇEK DONANIM OLMADAN test ediyoruz: donanım protokol arkasında
/// olduğu için, sahte bir kamera "çektiği" sabit veriyi döndürür ve akışı saniyenin
/// altında doğrularız. Ghost ve referans noktası mantığını da burada test ediyoruz.
@MainActor
final class CameraCaptureViewModelTests: XCTestCase {

    private final class FakeCamera: CameraServiceProtocol {
        let session = AVCaptureSession()
        var photoToReturn = Data([0x01])
        var startError: Error?
        var captureError: Error?

        func start() async throws { if let startError { throw startError } }
        func stop() {}
        func capturePhoto() async throws -> Data {
            if let captureError { throw captureError }
            return photoToReturn
        }
    }

    private final class FakeRepository: ProjectRepositoryProtocol {
        private(set) var addedEntries: [Entry] = []
        func createProject(title: String, category: ProjectCategory, cadence: CaptureCadence) throws -> Project {
            Project(title: title, category: category, cadence: cadence)
        }
        func allProjects() throws -> [Project] { [] }
        func addEntry(_ entry: Entry, to project: Project) throws { addedEntries.append(entry) }
        func deleteProject(_ project: Project) throws {}
        func saveIfNeeded() throws {}
    }

    private struct DummyError: Error {}

    private func makeViewModel(
        camera: FakeCamera,
        repository: FakeRepository,
        project: Project? = nil
    ) -> CameraCaptureViewModel {
        CameraCaptureViewModel(
            camera: camera,
            repository: repository,
            project: project ?? Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
        )
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar.date(from: DateComponents(year: y, month: m, day: d))!
    }

    // MARK: - Çekim akışı

    func test_basariliCekim_veriyiEntryOlarakKaydeder() async {
        let camera = FakeCamera()
        camera.photoToReturn = Data([0xAA, 0xBB])
        let repository = FakeRepository()
        let viewModel = makeViewModel(camera: camera, repository: repository)

        await viewModel.start()                 // .ready
        let success = await viewModel.capture()

        XCTAssertTrue(success)
        XCTAssertEqual(repository.addedEntries.count, 1)
        XCTAssertEqual(repository.addedEntries.first?.imageData, Data([0xAA, 0xBB]))
    }

    func test_baslatmaHataVerirse_durumFailedOlur() async {
        let camera = FakeCamera()
        camera.startError = DummyError()
        let viewModel = makeViewModel(camera: camera, repository: FakeRepository())

        await viewModel.start()

        let success = await viewModel.capture()
        XCTAssertFalse(success)
        if case .failed = viewModel.state {
            // beklenen sonuç
        } else {
            XCTFail("Durum .failed olmalıydı, ama \(viewModel.state) bulundu")
        }
    }

    // MARK: - Referans noktası (hizalama)

    func test_cekim_referansNoktasiniDaKaydeder() async throws {
        let repository = FakeRepository()
        let viewModel = makeViewModel(camera: FakeCamera(), repository: repository)
        viewModel.setAnchor(NormalizedPoint(x: 0.2, y: 0.7))

        await viewModel.start()
        let success = await viewModel.capture()

        XCTAssertTrue(success)
        let saved = try XCTUnwrap(repository.addedEntries.first)
        XCTAssertEqual(try XCTUnwrap(saved.anchorX), 0.2, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(saved.anchorY), 0.7, accuracy: 0.001)
    }

    func test_baslangicReferansi_oncekiCekimdenGelir() throws {
        // Önceki çekimin anchor'ı, yeni oturumun başlangıç referansı olmalı.
        let context = AppModelContainer.makeInMemory().mainContext
        let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
        context.insert(project)

        let onceki = Entry(capturedAt: date(2026, 6, 1), imageData: Data([0x01]),
                           anchorX: 0.3, anchorY: 0.6)
        onceki.project = project
        context.insert(onceki)
        try context.save()

        let viewModel = makeViewModel(camera: FakeCamera(), repository: FakeRepository(), project: project)

        XCTAssertEqual(viewModel.referenceAnchor, NormalizedPoint(x: 0.3, y: 0.6))
    }

    // MARK: - Ghost mantığı

    func test_ghostImageData_enYeniCekiminFotografidir() throws {
        let context = AppModelContainer.makeInMemory().mainContext
        let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
        context.insert(project)

        let eski = Entry(capturedAt: date(2026, 6, 1), imageData: Data([0x01]))
        eski.project = project
        context.insert(eski)

        let yeni = Entry(capturedAt: date(2026, 6, 10), imageData: Data([0x02]))
        yeni.project = project
        context.insert(yeni)
        try context.save()

        let viewModel = makeViewModel(camera: FakeCamera(), repository: FakeRepository(), project: project)

        XCTAssertEqual(viewModel.ghostImageData, Data([0x02]))   // en yeni çekim
    }

    func test_hicCekimYoksa_ghostYoktur() {
        let viewModel = makeViewModel(camera: FakeCamera(), repository: FakeRepository())
        XCTAssertNil(viewModel.ghostImageData)
    }
}

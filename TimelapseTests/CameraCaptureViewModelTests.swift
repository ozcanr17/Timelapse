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
        var switchError: Error?
        private(set) var startedPositions: [AVCaptureDevice.Position] = []
        private(set) var switchedPositions: [AVCaptureDevice.Position] = []

        func start(position: AVCaptureDevice.Position) async throws {
            startedPositions.append(position)
            if let startError { throw startError }
        }
        func stop() {}
        func switchCamera(to position: AVCaptureDevice.Position) async throws {
            if let switchError { throw switchError }
            switchedPositions.append(position)
        }
        func capturePhoto() async throws -> Data {
            if let captureError { throw captureError }
            return photoToReturn
        }
    }

    private struct FakeClassifier: SubjectClassifying {
        func signature(for imageData: Data) async -> SubjectSignature { .empty }
    }

    private struct FakeLocation: LocationProviding {
        func currentLocation() async -> ResolvedLocation? { nil }
    }

    private final class FakeRepository: ProjectRepositoryProtocol {
        private(set) var addedEntries: [Entry] = []
        private(set) var replacedEntryIDs: [UUID] = []
        private(set) var lastReplacedData: Data?
        func createProject(title: String, category: ProjectCategory, cadence: CaptureCadence) throws -> Project {
            Project(title: title, category: category, cadence: cadence)
        }
        func allProjects() throws -> [Project] { [] }
        func addEntry(_ entry: Entry, to project: Project) throws { addedEntries.append(entry) }
        func addEntries(_ entries: [Entry], to project: Project) throws { addedEntries.append(contentsOf: entries) }
        func replaceImage(for entry: Entry, with data: Data) throws {
            replacedEntryIDs.append(entry.id)
            lastReplacedData = data
        }
        func deleteEntry(_ entry: Entry) throws {}
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
            project: project ?? Project(title: "Sakal", category: .hairAndBeard, cadence: .daily),
            classifier: FakeClassifier(),
            location: FakeLocation()
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

    // MARK: - Yeniden çekim

    func test_yenidenCekim_yeniEntryEklemez_fotografiDegistirir() async {
        let camera = FakeCamera()
        camera.photoToReturn = Data([0xCC])
        let repository = FakeRepository()
        let entry = Entry(imageData: Data([0x01]))
        let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
        let viewModel = CameraCaptureViewModel(
            camera: camera, repository: repository, project: project, retakeEntry: entry
        )

        await viewModel.start()
        let success = await viewModel.capture()

        XCTAssertTrue(success)
        XCTAssertTrue(repository.addedEntries.isEmpty)
        XCTAssertEqual(repository.replacedEntryIDs, [entry.id])
        XCTAssertEqual(repository.lastReplacedData, Data([0xCC]))
    }

    func test_yenidenCekim_ghostOlarakKendiFotografiniGosterir() {
        let entry = Entry(imageData: Data([0x07]))
        let project = Project(title: "Sakal", category: .hairAndBeard, cadence: .daily)
        let viewModel = CameraCaptureViewModel(
            camera: FakeCamera(), repository: FakeRepository(), project: project, retakeEntry: entry
        )

        XCTAssertEqual(viewModel.ghostImageData, Data([0x07]))
    }

    // MARK: - Kamera pozisyonu

    func test_sacSakalProjesi_onKameraylaBaslar() async {
        let camera = FakeCamera()
        let viewModel = makeViewModel(camera: camera, repository: FakeRepository())

        await viewModel.start()

        XCTAssertEqual(viewModel.position, .front)
        XCTAssertEqual(camera.startedPositions, [.front])
    }

    func test_bitkiProjesi_arkaKameraylaBaslar() {
        let project = Project(title: "Limon fidanı", category: .plant, cadence: .weekly)
        let viewModel = makeViewModel(camera: FakeCamera(), repository: FakeRepository(), project: project)

        XCTAssertEqual(viewModel.position, .back)
    }

    func test_flipCamera_pozisyonuDegistirir() async {
        let camera = FakeCamera()
        let viewModel = makeViewModel(camera: camera, repository: FakeRepository())

        await viewModel.start()
        await viewModel.flipCamera()

        XCTAssertEqual(viewModel.position, .back)
        XCTAssertEqual(camera.switchedPositions, [.back])
    }

    func test_flipCamera_hazirDegilkenCalismaz() async {
        let camera = FakeCamera()
        camera.startError = DummyError()
        let viewModel = makeViewModel(camera: camera, repository: FakeRepository())

        await viewModel.start()
        await viewModel.flipCamera()

        XCTAssertEqual(viewModel.position, .front)
        XCTAssertTrue(camera.switchedPositions.isEmpty)
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

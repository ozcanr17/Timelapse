import Foundation
import AVFoundation

/// Kamera ekranının mantığı. Donanımı (CameraServiceProtocol) ve kalıcılığı
/// (ProjectRepositoryProtocol) protokol olarak alır; bu sayede gerçek kamera olmadan,
/// sahte servislerle test edilebilir.
@MainActor
@Observable
final class CameraCaptureViewModel {

    enum State: Equatable {
        case starting
        case ready
        case capturing
        case failed(String)
    }

    private(set) var state: State = .starting

    /// Hizalama referans noktası (0...1 normalize). Bir önceki çekimden başlar,
    /// kullanıcı önizlemeye dokununca güncellenir, çekimde Entry'ye kaydedilir.
    private(set) var referenceAnchor: NormalizedPoint

    private(set) var position: AVCaptureDevice.Position

    private let camera: CameraServiceProtocol
    private let repository: ProjectRepositoryProtocol
    private let project: Project

    init(camera: CameraServiceProtocol, repository: ProjectRepositoryProtocol, project: Project) {
        self.camera = camera
        self.repository = repository
        self.project = project
        self.referenceAnchor = Self.initialAnchor(for: project)
        self.position = Self.initialPosition(for: project.category)
    }

    /// Önizleme katmanının bağlanacağı oturum.
    var session: AVCaptureSession { camera.session }

    /// "Ghost" bindirmesi için bir önceki (en yeni) çekimin fotoğrafı.
    var ghostImageData: Data? { project.sortedEntries.last?.imageData }

    /// Kullanıcı önizlemeye dokununca referans noktasını oraya taşır.
    func setAnchor(_ point: NormalizedPoint) {
        referenceAnchor = point
    }

    func start() async {
        state = .starting
        do {
            try await camera.start(position: position)
            state = .ready
        } catch {
            state = .failed(message(for: error))
        }
    }

    func stop() {
        camera.stop()
    }

    func flipCamera() async {
        guard state == .ready else { return }
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        do {
            try await camera.switchCamera(to: newPosition)
            position = newPosition
        } catch {
            state = .failed(message(for: error))
        }
    }

    /// Fotoğrafı çeker ve referans noktasıyla birlikte Entry olarak kaydeder.
    func capture() async -> Bool {
        guard state == .ready else { return false }
        state = .capturing
        do {
            let data = try await camera.capturePhoto()
            let entry = Entry(
                imageData: data,
                anchorX: referenceAnchor.x,
                anchorY: referenceAnchor.y
            )
            try repository.addEntry(entry, to: project)
            state = .ready
            return true
        } catch {
            state = .failed(message(for: error))
            return false
        }
    }

    private static func initialPosition(for category: ProjectCategory) -> AVCaptureDevice.Position {
        switch category {
        case .selfPortrait, .hairAndBeard: .front
        default: .back
        }
    }

    // Referans noktası: önceki çekimde tanımlıysa onu sürdür, yoksa ortadan başla.
    private static func initialAnchor(for project: Project) -> NormalizedPoint {
        if let last = project.sortedEntries.last, let x = last.anchorX, let y = last.anchorY {
            return NormalizedPoint(x: x, y: y)
        }
        return NormalizedPoint(x: 0.5, y: 0.5)
    }

    private func message(for error: Error) -> String {
        guard let cameraError = error as? CameraError else {
            return "Beklenmeyen bir hata oluştu: \(error.localizedDescription)"
        }
        switch cameraError {
        case .notAuthorized:        return "Kamera izni verilmedi. Ayarlar’dan açabilirsin."
        case .configurationFailed:  return "Kamera başlatılamadı."
        case .imageDataUnavailable: return "Fotoğraf verisi alınamadı."
        }
    }
}

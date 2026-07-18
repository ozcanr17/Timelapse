import Foundation
import SwiftData
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
    private(set) var isSwitching = false
    private(set) var zoomFactor: CGFloat = 1
    private(set) var zoomRange: ClosedRange<CGFloat> = 1...1

    private let camera: CameraServiceProtocol
    private let repository: ProjectRepositoryProtocol
    private let project: Project?
    private let retakeEntry: Entry?
    private let classifier: SubjectClassifying
    private let location: LocationProviding
    private let onCaptured: ((Data) -> Void)?

    init(
        camera: CameraServiceProtocol,
        repository: ProjectRepositoryProtocol,
        project: Project? = nil,
        retakeEntry: Entry? = nil,
        classifier: SubjectClassifying = SubjectClassifier(),
        location: LocationProviding? = nil,
        onCaptured: ((Data) -> Void)? = nil
    ) {
        self.camera = camera
        self.repository = repository
        self.project = project
        self.retakeEntry = retakeEntry
        self.classifier = classifier
        self.location = location ?? LocationService()
        self.onCaptured = onCaptured
        self.referenceAnchor = Self.initialAnchor(for: project)
        self.position = Self.initialPosition(for: project?.category ?? .other)
    }

    /// Önizleme katmanının bağlanacağı oturum.
    var session: AVCaptureSession { camera.session }

    /// "Ghost" bindirmesi için referans fotoğraf: yeniden çekimde karenin kendisi,
    /// normal çekimde bir önceki (en yeni) çekim.
    var ghostImageData: Data? {
        retakeEntry?.imageData ?? project?.sortedEntries.last?.imageData
    }

    /// Bu proje çift modu (birlikte çekim) için mi? Kamerada bölme kılavuzunu belirler.
    var isCoupleMode: Bool { project?.isCoupleMode ?? false }

    /// Kullanıcı önizlemeye dokununca referans noktasını oraya taşır.
    func setAnchor(_ point: NormalizedPoint) {
        referenceAnchor = point
    }

    func start() async {
        state = .starting
        do {
            try await camera.start(position: position)
            await refreshZoom()
            state = .ready
        } catch {
            state = .failed(message(for: error))
        }
    }

    func stop() {
        camera.stop()
    }

    func flipCamera() async {
        guard state == .ready, !isSwitching else { return }
        isSwitching = true
        defer { isSwitching = false }
        let newPosition: AVCaptureDevice.Position = position == .back ? .front : .back
        do {
            try await camera.switchCamera(to: newPosition)
            position = newPosition
            await refreshZoom()
        } catch {
            state = .failed(message(for: error))
        }
    }

    func setZoomFactor(_ factor: CGFloat) {
        guard state == .ready else { return }
        zoomFactor = min(max(factor, zoomRange.lowerBound), zoomRange.upperBound)
        camera.setZoomFactor(zoomFactor)
    }

    /// Fotoğrafı çeker; yeniden çekimde mevcut karenin fotoğrafını değiştirir,
    /// normal çekimde yeni bir Entry kaydeder.
    func capture() async -> Bool {
        guard state == .ready, !isSwitching else { return false }
        state = .capturing
        do {
            let data = try await camera.capturePhoto()
            if let onCaptured {
                onCaptured(data)
            } else if let retakeEntry {
                try repository.replaceImage(for: retakeEntry, with: data)
            } else if let project {
                let signature = await classifier.signature(for: data)
                let entry = Entry(
                    imageData: data,
                    anchorX: referenceAnchor.x,
                    anchorY: referenceAnchor.y,
                    subjectKindRaw: signature.kind == .unknown ? nil : signature.kind.rawValue,
                    featurePrintData: signature.isEmpty ? nil : FeatureVector.data(from: signature.vector)
                )
                try repository.addEntry(entry, to: project)
                captureLocation(for: entry)
                let live = project.sortedEntries.filter { !$0.isDeleted }
                if let message = ActivitySummary.milestone(
                    count: live.count,
                    streak: ActivitySummary.streak(capturedDates: live.map(\.capturedAt))
                ) {
                    NotificationCenter.default.post(name: .flapseMilestone, object: message)
                }
            } else {
                state = .ready
                return false
            }
            state = .ready
            return true
        } catch {
            state = .failed(message(for: error))
            return false
        }
    }

    private func captureLocation(for entry: Entry) {
        Task {
            guard let resolved = await location.currentLocation() else { return }
            entry.latitude = resolved.latitude
            entry.longitude = resolved.longitude
            entry.placeName = resolved.placeName
            try? repository.saveIfNeeded()
        }
    }

    private func refreshZoom() async {
        let capabilities = await camera.zoomCapabilities()
        zoomRange = capabilities.range
        zoomFactor = capabilities.factor
    }

    private static func initialPosition(for category: ProjectCategory) -> AVCaptureDevice.Position {
        switch category {
        case .selfPortrait, .hairAndBeard: .front
        default: .back
        }
    }

    // Referans noktası: önceki çekimde tanımlıysa onu sürdür, yoksa ortadan başla.
    private static func initialAnchor(for project: Project?) -> NormalizedPoint {
        if let last = project?.sortedEntries.last, let x = last.anchorX, let y = last.anchorY {
            return NormalizedPoint(x: x, y: y)
        }
        return NormalizedPoint(x: 0.5, y: 0.5)
    }

    private func message(for error: Error) -> String {
        guard let cameraError = error as? CameraError else {
            return String(localized: "Beklenmeyen bir hata oluştu: \(error.localizedDescription)", bundle: .appLanguage)
        }
        switch cameraError {
        case .notAuthorized:        return String(localized: "Kamera izni verilmedi. Ayarlar’dan açabilirsin.", bundle: .appLanguage)
        case .configurationFailed:  return String(localized: "Kamera başlatılamadı.", bundle: .appLanguage)
        case .imageDataUnavailable: return String(localized: "Fotoğraf verisi alınamadı.", bundle: .appLanguage)
        case .captureInterrupted:   return String(localized: "Çekim yarıda kesildi. Tekrar dene.", bundle: .appLanguage)
        }
    }
}

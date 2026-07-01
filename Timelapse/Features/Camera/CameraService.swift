import AVFoundation

enum CameraError: Error {
    case notAuthorized
    case configurationFailed
    case imageDataUnavailable
}

/// Kamera donanımının arkasındaki sözleşme. Görünüm ve ViewModel yalnızca bunu tanır;
/// böylece testte gerçek AVFoundation yerine sahte bir implementasyon enjekte edilebilir.
protocol CameraServiceProtocol: AnyObject {
    /// Canlı önizleme katmanının bağlanacağı oturum.
    var session: AVCaptureSession { get }
    /// İzin ister, oturumu yapılandırır ve başlatır.
    func start() async throws
    /// Oturumu durdurur (ekrandan çıkarken pil/ısı için).
    func stop()
    /// Bir fotoğraf çeker ve kodlanmış görsel verisini (HEIC/JPEG) döndürür.
    func capturePhoto() async throws -> Data
}

/// AVFoundation tabanlı gerçek kamera servisi.
///
/// Oturuma erişimi tek bir seri kuyruktan (sessionQueue) geçiriyoruz ve aynı anda yalnızca
/// tek bir çekim yapılıyor; bu yüzden pratikte güvenli. Derleyici bunu kanıtlayamadığı için
/// sınıfı `@unchecked Sendable` ile işaretliyoruz: "eşzamanlılık güvenliğini ben garanti
/// ediyorum" demenin bilinçli yolu.
final class CameraService: NSObject, CameraServiceProtocol, @unchecked Sendable {

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var isConfigured = false

    // Devam eden tek çekimin "continuation"ı. Çekimler sıralı olduğu için tek slot yeterli.
    private var captureContinuation: CheckedContinuation<Data, Error>?

    func start() async throws {
        // 1) İzin. AVFoundation'ın async requestAccess'i sayesinde delegate'siz, tek satır.
        guard await Self.isAuthorized() else { throw CameraError.notAuthorized }

        // 2) Yapılandır + başlat. startRunning() bloklayabildiği için arka plan kuyruğunda
        //    yapıyoruz; kuyruktaki işin bitmesini de bir continuation ile await ediyoruz.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async {
                do {
                    try self.configureIfNeeded()
                    if !self.session.isRunning { self.session.startRunning() }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capturePhoto() async throws -> Data {
        // İŞTE ASIL DERS: delegate-tabanlı bir API'yi async/await'e dönüştürüyoruz.
        // capturePhoto(with:delegate:) sonucu bir delegate metodu üzerinden bildirir;
        // biz continuation'ı saklayıp o metot içinde "resume" ederek await'i tamamlıyoruz.
        try await withCheckedThrowingContinuation { continuation in
            self.captureContinuation = continuation
            self.photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
        }
    }

    // MARK: - Yardımcılar

    private static func isAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default:             return false   // reddedildi / kısıtlı
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else { throw CameraError.configurationFailed }
        session.addInput(input)

        guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
        session.addOutput(photoOutput)

        isConfigured = true
    }
}

// MARK: - Fotoğraf çekim delegesi

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        // Bu metot AVFoundation'ın kendi kuyruğunda çağrılır. continuation'ı "resume" etmek
        // iş parçacığı-güvenlidir; sonrasında await eden kod kaldığı yerden devam eder.
        if let error {
            captureContinuation?.resume(throwing: error)
        } else if let data = photo.fileDataRepresentation() {
            captureContinuation?.resume(returning: data)
        } else {
            captureContinuation?.resume(throwing: CameraError.imageDataUnavailable)
        }
        captureContinuation = nil
    }
}

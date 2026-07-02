import AVFoundation

enum CameraError: Error {
    case notAuthorized
    case configurationFailed
    case imageDataUnavailable
    case captureInterrupted
}

protocol CameraServiceProtocol: AnyObject {
    var session: AVCaptureSession { get }
    func start(position: AVCaptureDevice.Position) async throws
    func stop()
    func switchCamera(to position: AVCaptureDevice.Position) async throws
    func capturePhoto() async throws -> Data
}

final class CameraService: NSObject, CameraServiceProtocol, @unchecked Sendable {

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var currentInput: AVCaptureDeviceInput?
    private var captureContinuation: CheckedContinuation<Data, Error>?

    func start(position: AVCaptureDevice.Position) async throws {
        guard await Self.isAuthorized() else { throw CameraError.notAuthorized }
        try await onSessionQueue {
            try self.configure(position: position)
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func switchCamera(to position: AVCaptureDevice.Position) async throws {
        try await onSessionQueue {
            try self.configure(position: position)
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.sessionQueue.async {
                if let pending = self.captureContinuation {
                    self.captureContinuation = nil
                    pending.resume(throwing: CameraError.captureInterrupted)
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .speed
                self.captureContinuation = continuation
                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func onSessionQueue(_ work: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.sessionQueue.async {
                do {
                    try work()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func isAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .video)
        default:             return false
        }
    }

    private func configure(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.outputs.isEmpty {
            session.sessionPreset = .photo
            guard session.canAddOutput(photoOutput) else { throw CameraError.configurationFailed }
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .balanced
        }

        if let currentInput {
            session.removeInput(currentInput)
            self.currentInput = nil
        }

        guard
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else { throw CameraError.configurationFailed }

        session.addInput(input)
        currentInput = input
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
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

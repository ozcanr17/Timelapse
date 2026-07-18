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
    func zoomCapabilities() async -> CameraZoomCapabilities
    func setZoomFactor(_ factor: CGFloat, smoothly: Bool)
    func capturePhoto() async throws -> Data
}

struct CameraZoomCapabilities: Equatable, Sendable {
    let factor: CGFloat
    let range: ClosedRange<CGFloat>
}

final class CameraService: NSObject, CameraServiceProtocol, @unchecked Sendable {

    static let shared = CameraService()

    let session = AVCaptureSession()

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var currentInput: AVCaptureDeviceInput?
    private var captureContinuation: CheckedContinuation<Data, Error>?

    func prewarm(position: AVCaptureDevice.Position = .back) {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        sessionQueue.async {
            try? self.configure(position: position)
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

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

    func zoomCapabilities() async -> CameraZoomCapabilities {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard let device = self.currentInput?.device else {
                    continuation.resume(returning: CameraZoomCapabilities(factor: 1, range: 1...1))
                    return
                }
                let multiplier = self.zoomDisplayMultiplier(for: device)
                let lower = device.minAvailableVideoZoomFactor * multiplier
                let upper = max(lower, min(device.maxAvailableVideoZoomFactor * multiplier, 10))
                continuation.resume(returning: CameraZoomCapabilities(
                    factor: min(max(device.videoZoomFactor * multiplier, lower), upper),
                    range: lower...upper
                ))
            }
        }
    }

    func setZoomFactor(_ factor: CGFloat, smoothly: Bool) {
        sessionQueue.async {
            guard let device = self.currentInput?.device else { return }
            let multiplier = self.zoomDisplayMultiplier(for: device)
            let rawFactor = factor / max(multiplier, 0.01)
            let clamped = min(max(rawFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
            do {
                try device.lockForConfiguration()
                if smoothly {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 4)
                } else {
                    device.cancelVideoZoomRamp()
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
            } catch {}
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            self.sessionQueue.async {
                if let pending = self.captureContinuation {
                    self.captureContinuation = nil
                    pending.resume(throwing: CameraError.captureInterrupted)
                }
                if let connection = self.photoOutput.connection(with: .video), connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.currentInput?.device.position == .front
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .balanced
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
        if let currentInput, currentInput.device.position == position, !session.outputs.isEmpty {
            return
        }
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
            let camera = preferredCamera(position: position),
            let input = try? AVCaptureDeviceInput(device: camera),
            session.canAddInput(input)
        else { throw CameraError.configurationFailed }

        session.addInput(input)
        currentInput = input
    }

    private func preferredCamera(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = position == .back
            ? [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
            : [.builtInTrueDepthCamera, .builtInWideAngleCamera]
        for type in types {
            if let device = AVCaptureDevice.default(type, for: .video, position: position) {
                return device
            }
        }
        return AVCaptureDevice.default(for: .video)
    }

    private func zoomDisplayMultiplier(for device: AVCaptureDevice) -> CGFloat {
        if #available(iOS 18.0, *) {
            return device.displayVideoZoomFactorMultiplier
        }
        return 1
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let data = photo.fileDataRepresentation()
        sessionQueue.async {
            guard let continuation = self.captureContinuation else { return }
            self.captureContinuation = nil
            if let error {
                continuation.resume(throwing: error)
            } else if let data {
                continuation.resume(returning: data)
            } else {
                continuation.resume(throwing: CameraError.imageDataUnavailable)
            }
        }
    }
}

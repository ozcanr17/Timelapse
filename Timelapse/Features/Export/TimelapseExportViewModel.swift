import Foundation

@MainActor
@Observable
final class TimelapseExportViewModel {

    enum Phase: Equatable {
        case idle
        case rendering
        case finished(URL)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0

    private let composer: any TimelapseComposing

    init(composer: any TimelapseComposing = TimelapseComposer()) {
        self.composer = composer
    }

    func export(
        frames: [TimelapseFrame],
        isPro: Bool,
        speed: TimelapseSpeed = .normal,
        overlay: TimelapseOverlayOptions = TimelapseOverlayOptions(),
        smartAlignment: Bool = false
    ) async {
        guard phase != .rendering else { return }
        guard frames.count >= 2 else {
            phase = .failed(String(localized: "Timelapse için en az 2 çekim gerekli."))
            return
        }
        phase = .rendering
        progress = 0
        do {
            let url = try await composer.makeVideo(
                from: frames,
                settings: .current(isPro: isPro, speed: speed, overlay: overlay, smartAlignment: smartAlignment),
                onProgress: { [weak self] value in
                    Task { @MainActor in self?.progress = value }
                }
            )
            phase = .finished(url)
        } catch {
            phase = .failed(String(localized: "Video oluşturulamadı: \(error.localizedDescription)"))
        }
    }
}

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
    private var renderTask: Task<Void, Never>?

    init(composer: any TimelapseComposing = TimelapseComposer()) {
        self.composer = composer
    }

    func export(
        frames: [TimelapseFrame],
        isPro: Bool,
        speed: TimelapseSpeed = .normal,
        speedMultiplier: Double? = nil,
        aspect: TimelapseAspect = .threeFour,
        zoom: Double = 1,
        soundtrackURL: URL? = nil,
        bundledBeats: [Double]? = nil,
        beatSync: Bool = false,
        overlay: TimelapseOverlayOptions = TimelapseOverlayOptions(),
        smartAlignment: Bool = false,
        manualAnchor: ManualAlignment? = nil,
        transition: TimelapseTransition = .cut,
        alignmentSubject: AlignmentSubject = .auto
    ) {
        renderTask?.cancel()
        guard frames.count >= 2 else {
            phase = .failed(String(localized: "Timelapse için en az 2 çekim gerekli.", bundle: .appLanguage))
            return
        }
        let composer = composer
        phase = .rendering
        progress = 0
        renderTask = Task { [weak self] in
            do {
                var beats: [Double]? = nil
                if beatSync, let soundtrackURL {
                    if let bundledBeats {
                        beats = bundledBeats
                    } else {
                        beats = try? await AudioBeatAnalyzer.beats(in: soundtrackURL)
                    }
                    if beats?.count ?? 0 < 2 { beats = nil }
                }
                let settings = TimelapseExportSettings.current(
                    isPro: isPro, speed: speed, speedMultiplier: speedMultiplier, aspect: aspect, zoom: zoom, overlay: overlay,
                    smartAlignment: smartAlignment, manualAnchor: manualAnchor, transition: transition,
                    alignmentSubject: alignmentSubject,
                    soundtrackURL: soundtrackURL,
                    beatTimes: beats
                )
                let url = try await composer.makeVideo(
                    from: frames,
                    settings: settings,
                    onProgress: { [weak self] value in
                        guard let self else { return }
                        Task { @MainActor in
                            guard self.renderTask?.isCancelled == false else { return }
                            self.progress = value
                        }
                    }
                )
                try Task.checkCancellation()
                self?.phase = .finished(url)
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                self?.phase = .failed(String(localized: "Video oluşturulamadı: \(error.localizedDescription)", bundle: .appLanguage))
            }
        }
    }

    func cancel() {
        renderTask?.cancel()
    }

    func waitForRender() async {
        await renderTask?.value
    }
}

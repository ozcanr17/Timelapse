import AVFoundation
import Foundation
import UIKit

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
    private(set) var failedInBackground = false

    private let composer: any TimelapseComposing
    private var renderTask: Task<Void, Never>?
    private var retryAction: (() -> Void)?

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
        manualAnchors: [ManualAlignment]? = nil,
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
        failedInBackground = false
        retryAction = { [weak self] in
            self?.export(
                frames: frames, isPro: isPro, speed: speed, speedMultiplier: speedMultiplier,
                aspect: aspect, zoom: zoom, soundtrackURL: soundtrackURL, bundledBeats: bundledBeats,
                beatSync: beatSync, overlay: overlay, smartAlignment: smartAlignment,
                manualAnchor: manualAnchor, manualAnchors: manualAnchors,
                transition: transition, alignmentSubject: alignmentSubject
            )
        }
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
                    if let raw = beats {
                        let audioDuration = (try? await AVURLAsset(url: soundtrackURL).load(.duration).seconds) ?? 0
                        let fps = speedMultiplier.map { min(12, max(1, $0 * 4)) } ?? Double(speed.framesPerSecond)
                        beats = AdaptiveEditEngine.cutTimes(
                            beats: raw,
                            frameCount: frames.count,
                            audioDuration: audioDuration,
                            targetDuration: Double(frames.count) / fps
                        )
                    }
                }
                let transitionPlan = transition == .adaptive
                    ? await Task.detached(priority: .userInitiated) {
                        AdaptiveEditEngine.transitionPlan(for: frames)
                    }.value
                    : nil
                let settings = TimelapseExportSettings.current(
                    isPro: isPro, speed: speed, speedMultiplier: speedMultiplier, aspect: aspect, zoom: zoom, overlay: overlay,
                    smartAlignment: smartAlignment, manualAnchor: manualAnchor, manualAnchors: manualAnchors,
                    transition: transition, transitionPlan: transitionPlan,
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
                if UIApplication.shared.applicationState != .active {
                    self?.failedInBackground = true
                }
                self?.phase = .failed(String(localized: "Video oluşturulamadı: \(error.localizedDescription)", bundle: .appLanguage))
            }
        }
    }

    func cancel() {
        renderTask?.cancel()
        if phase == .rendering {
            phase = .idle
            progress = 0
        }
    }

    static func loopedCutTimes(beats: [Double], frameCount: Int, audioDuration: Double) -> [Double] {
        guard beats.count >= 2, frameCount >= 2 else { return beats }
        var extended = beats
        if audioDuration > 0 {
            var offset = audioDuration
            while extended.count < frameCount {
                for beat in beats where extended.count < frameCount {
                    extended.append(beat + offset)
                }
                offset += audioDuration
            }
        } else {
            var gaps: [Double] = []
            for i in 1..<beats.count { gaps.append(beats[i] - beats[i - 1]) }
            while extended.count < frameCount {
                extended.append((extended.last ?? 0) + gaps[(extended.count - 1) % gaps.count])
            }
        }
        return Array(extended.prefix(frameCount))
    }

    func waitForRender() async {
        await renderTask?.value
    }

    func retryAfterBackgroundFailure() -> Bool {
        guard failedInBackground else { return false }
        failedInBackground = false
        retryAction?()
        return true
    }
}

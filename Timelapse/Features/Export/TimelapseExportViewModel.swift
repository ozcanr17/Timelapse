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
        renderTask = Task { [weak self] in
            do {
                var beats: [Double]? = nil
                if beatSync, let soundtrackURL {
                    var dropTime: Double?
                    if let bundledBeats {
                        beats = bundledBeats
                    } else if let structure = try? await AudioBeatAnalyzer.structure(in: soundtrackURL) {
                        beats = structure.beats
                        dropTime = structure.dropTime
                    }
                    if beats?.count ?? 0 < 2 { beats = nil }
                    if let raw = beats {
                        beats = await Self.alignedCutTimes(beats: raw, frames: frames, dropTime: dropTime)
                    }
                }
                let settings = TimelapseExportSettings.current(
                    isPro: isPro, speed: speed, speedMultiplier: speedMultiplier, aspect: aspect, zoom: zoom, overlay: overlay,
                    smartAlignment: smartAlignment, manualAnchor: manualAnchor, manualAnchors: manualAnchors, transition: transition,
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

    /// Vuruş ızgarasını kare sayısına uzatır ve parça "drop"u biliniyorsa EN BÜYÜK
    /// görsel değişimin yaşandığı kesimi tam drop vuruşuna denk getirir: drop'tan önceki
    /// karelere fazladan vuruş dağıtılır, kronoloji bozulmaz.
    static func alignedCutTimes(beats: [Double], frames: [TimelapseFrame], dropTime: Double?) async -> [Double] {
        guard beats.count >= 2, frames.count >= 2 else { return beats }
        var gaps: [Double] = []
        for i in 1..<beats.count { gaps.append(beats[i] - beats[i - 1]) }

        var extended = beats
        while extended.count < frames.count * 3 {
            extended.append((extended.last ?? 0) + gaps[(extended.count - 1) % gaps.count])
        }

        var allocation = Array(repeating: 1, count: frames.count)

        if let dropTime {
            let scores = await changeScores(frames: frames)
            if let bestCut = scores.indices.max(by: { scores[$0] < scores[$1] }) {
                let dropBeat = extended.enumerated().min(by: { abs($0.element - dropTime) < abs($1.element - dropTime) })?.offset ?? bestCut
                var extras = dropBeat - bestCut
                var cursor = 0
                while extras > 0, bestCut > 0 {
                    if allocation[cursor % bestCut] < 4 {
                        allocation[cursor % bestCut] += 1
                        extras -= 1
                    }
                    cursor += 1
                    if cursor > bestCut * 4 { break }
                }
            }
        }

        var cutTimes: [Double] = []
        var beatCursor = 0
        for count in allocation {
            beatCursor += count
            cutTimes.append(extended[min(beatCursor - 1, extended.count - 1)])
        }
        return cutTimes
    }

    /// Ardışık kareler arasındaki görsel farkın kaba skoru (küçük gri örneklem farkı).
    private static func changeScores(frames: [TimelapseFrame]) async -> [Double] {
        await Task.detached(priority: .userInitiated) {
            var grays: [[Float]] = []
            for frame in frames {
                guard let image = ImageDownsampler.image(from: frame.imageData, maxPixelSize: 24)?.cgImage,
                      let data = image.dataProvider?.data as Data? else {
                    grays.append([])
                    continue
                }
                let bpp = max(image.bitsPerPixel / 8, 1)
                var values: [Float] = []
                var offset = 0
                while offset + 2 < data.count {
                    values.append((Float(data[offset]) + Float(data[offset + 1]) + Float(data[offset + 2])) / 3)
                    offset += bpp
                }
                grays.append(values)
            }
            var scores: [Double] = []
            for i in 0..<(grays.count - 1) {
                let a = grays[i], b = grays[i + 1]
                guard !a.isEmpty, a.count == b.count else { scores.append(0); continue }
                var sum: Float = 0
                for j in a.indices { sum += abs(a[j] - b[j]) }
                scores.append(Double(sum) / Double(a.count))
            }
            return scores
        }.value
    }

    func waitForRender() async {
        await renderTask?.value
    }
}

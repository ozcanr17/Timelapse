import AVFoundation
import Foundation

/// Videoya eklenecek müzik kaynağı: uygulamayla gelen parçalardan biri ya da
/// kullanıcının Dosyalar'dan seçtiği kendi dosyası.
struct SoundtrackOption: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL
    /// Sentezlenmiş parçaların bilinen vuruş aralığı (sn). Analize gerek kalmadan
    /// kusursuz ritim senkronu sağlar.
    let beatInterval: Double?

    var beatGrid: [Double]? {
        guard let beatInterval else { return nil }
        return stride(from: beatInterval, through: 24.0, by: beatInterval).map { $0 }
    }

    static var bundled: [SoundtrackOption] {
        let names: [(file: String, title: String, beat: Double?)] = [
            ("calm", String(localized: "Sakin", bundle: .appLanguage), 1.5),
            ("joyful", String(localized: "Neşeli", bundle: .appLanguage), 0.5),
            ("upbeat", String(localized: "Tempolu", bundle: .appLanguage), 0.6),
            ("sad", String(localized: "Hüzünlü", bundle: .appLanguage), 60.0 / 70.0),
            ("cinematic", String(localized: "Sinematik", bundle: .appLanguage), 2.0)
        ]
        return names.compactMap { entry in
            guard let url = Bundle.main.url(forResource: entry.file, withExtension: "m4a")
                ?? Bundle.main.url(forResource: entry.file, withExtension: "m4a", subdirectory: "Soundtracks")
            else { return nil }
            return SoundtrackOption(id: entry.file, title: entry.title, url: url, beatInterval: entry.beat)
        }
    }
}

/// Şarkının vuruş (beat) anlarını bulur: mono PCM okunur, kısa pencerelerde enerji
/// artışı (spectral flux'ın basit hali) ölçülür ve belirgin tepeler vuruş sayılır.
enum AudioBeatAnalyzer {

    static func beats(in url: URL) async throws -> [Double] {
        try await Task.detached(priority: .userInitiated) {
            try analyze(url).beats
        }.value
    }

    /// Vuruşlara ek olarak parçanın "drop"unu (sessiz/alçak bölümden sonra gelen en
    /// büyük enerji sıçraması — nakarat girişi) bulur.
    static func structure(in url: URL) async throws -> (beats: [Double], dropTime: Double?) {
        try await Task.detached(priority: .userInitiated) {
            let result = try analyze(url)
            return (result.beats, dropTime(energies: result.energies, hopDuration: result.hopDuration))
        }.value
    }

    private static func dropTime(energies: [Double], hopDuration: Double) -> Double? {
        let window = max(4, Int(1.0 / hopDuration))
        guard energies.count > window * 4 else { return nil }
        var rms: [Double] = []
        var stride_i = 0
        while stride_i + window <= energies.count {
            let mean = energies[stride_i..<(stride_i + window)].reduce(0, +) / Double(window)
            rms.append(mean)
            stride_i += window / 2
        }
        guard rms.count > 4 else { return nil }
        let sorted = rms.sorted()
        let median = sorted[sorted.count / 2]
        var best: (index: Int, jump: Double)?
        for i in 1..<rms.count {
            let jump = rms[i] - rms[i - 1]
            if rms[i - 1] <= median, jump > (best?.jump ?? 0) {
                best = (i, jump)
            }
        }
        guard let best, best.jump > median * 0.5 else { return nil }
        return Double(best.index) * Double(window / 2) * hopDuration
    }

    private static func analyze(_ url: URL) throws -> (beats: [Double], energies: [Double], hopDuration: Double) {
        let asset = AVURLAsset(url: url)
        let reader = try AVAssetReader(asset: asset)
        guard let track = asset.tracks(withMediaType: .audio).first else { return ([], [], 0.023) }

        let sampleRate = 22050.0
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        reader.startReading()

        let hop = 512
        var energies: [Double] = []
        var carry: [Int16] = []

        while let buffer = output.copyNextSampleBuffer(),
              let block = CMSampleBufferGetDataBuffer(buffer) {
            var length = 0
            var pointer: UnsafeMutablePointer<CChar>?
            CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &pointer)
            guard let pointer else { continue }
            let count = length / MemoryLayout<Int16>.size
            pointer.withMemoryRebound(to: Int16.self, capacity: count) { samples in
                carry.append(contentsOf: UnsafeBufferPointer(start: samples, count: count))
            }
            while carry.count >= hop {
                let window = carry.prefix(hop)
                var sum = 0.0
                for sample in window {
                    let v = Double(sample) / 32768.0
                    sum += v * v
                }
                energies.append(sum / Double(hop))
                carry.removeFirst(hop)
            }
        }

        let hopDurationEarly = Double(hop) / sampleRate
        guard energies.count > 8 else { return ([], energies, hopDurationEarly) }


        var flux: [Double] = [0]
        for i in 1..<energies.count {
            flux.append(max(0, energies[i] - energies[i - 1]))
        }

        let hopDuration = Double(hop) / sampleRate
        let minGap = 0.25
        let windowRadius = 8
        var beats: [Double] = []
        var lastBeat = -minGap

        for i in windowRadius..<(flux.count - windowRadius) {
            let neighborhood = flux[(i - windowRadius)...(i + windowRadius)]
            let mean = neighborhood.reduce(0, +) / Double(neighborhood.count)
            let time = Double(i) * hopDuration
            if flux[i] > mean * 2.2, flux[i] == neighborhood.max(), time - lastBeat >= minGap {
                beats.append(time)
                lastBeat = time
            }
        }
        if beats.count >= 4 { return (beats, energies, hopDuration) }

        // Belirgin vuruş bulunamadıysa (ör. yumuşak/pad ağırlıklı parça) enerji akısının
        // özilintisinden (autocorrelation) tempo kestirilir ve düzenli bir ızgara üretilir.
        let minLagSeconds = 0.3
        let maxLagSeconds = 1.2
        let minLag = Int(minLagSeconds / hopDuration)
        let maxLag = min(flux.count / 2, Int(maxLagSeconds / hopDuration))
        guard maxLag > minLag else { return (beats, energies, hopDuration) }
        var bestLag = minLag
        var bestScore = -Double.infinity
        for lag in minLag...maxLag {
            var score = 0.0
            for i in 0..<(flux.count - lag) { score += flux[i] * flux[i + lag] }
            if score > bestScore { bestScore = score; bestLag = lag }
        }
        let interval = Double(bestLag) * hopDuration
        let total = Double(flux.count) * hopDuration
        let grid = stride(from: interval, through: total, by: interval).map { $0 }
        return (grid, energies, hopDuration)
    }
}

/// Render edilen sessiz videoya müziği ekler: parça video süresine göre döngülenir ya da
/// kırpılır, son 1.2 saniyede yumuşakça kısılır.
enum SoundtrackMuxer {

    static func mux(videoURL: URL, audioURL: URL) async throws -> URL {
        let videoAsset = AVURLAsset(url: videoURL)
        let audioAsset = AVURLAsset(url: audioURL)

        let composition = AVMutableComposition()
        guard
            let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first,
            let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first,
            let compVideo = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
            let compAudio = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        else { throw TimelapseComposerError.writerFailed }

        let videoDuration = try await videoAsset.load(.duration)
        let audioDuration = try await audioAsset.load(.duration)
        try compVideo.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)

        var cursor = CMTime.zero
        while cursor < videoDuration {
            let remaining = videoDuration - cursor
            let chunk = min(remaining, audioDuration)
            try compAudio.insertTimeRange(CMTimeRange(start: .zero, duration: chunk), of: audioTrack, at: cursor)
            cursor = cursor + chunk
        }

        let mix = AVMutableAudioMix()
        let parameters = AVMutableAudioMixInputParameters(track: compAudio)
        let fadeDuration = CMTime(seconds: 1.2, preferredTimescale: 600)
        let fadeStart = max(.zero, videoDuration - fadeDuration)
        parameters.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: fadeStart, duration: fadeDuration))
        mix.inputParameters = [parameters]

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("timelapse-audio-\(UUID().uuidString)")
            .appendingPathExtension("mp4")

        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough)
        else { throw TimelapseComposerError.writerFailed }
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.audioMix = mix
        try await export.export(to: outputURL, as: .mp4)
        try? FileManager.default.removeItem(at: videoURL)
        return outputURL
    }
}

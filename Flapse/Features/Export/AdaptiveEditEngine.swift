import CoreGraphics
import Foundation
import ImageIO

enum AdaptiveEditEngine {
    static func cutTimes(
        beats: [Double],
        frameCount: Int,
        audioDuration: Double,
        targetDuration: Double
    ) -> [Double] {
        guard frameCount > 0 else { return [] }
        let source = sanitized(beats)
        guard source.count >= 2 else { return Array(source.prefix(frameCount)) }

        let gaps = zip(source.dropFirst(), source).map { $0 - $1 }
        let interval = median(gaps.filter { $0 > 0.01 }) ?? 0.5
        let minimumDuration = source[0] + interval * Double(frameCount - 1)
        let desiredDuration = max(targetDuration, minimumDuration)
        var candidates = source

        if audioDuration > (source.last ?? 0) {
            var offset = audioDuration
            while candidates.count < frameCount || (candidates.last ?? 0) < desiredDuration + interval {
                candidates.append(contentsOf: source.map { $0 + offset })
                offset += audioDuration
            }
        } else {
            var gapIndex = 0
            while candidates.count < frameCount || (candidates.last ?? 0) < desiredDuration + interval {
                let gap = gaps.isEmpty ? interval : gaps[gapIndex % gaps.count]
                candidates.append((candidates.last ?? 0) + max(gap, 0.01))
                gapIndex += 1
            }
        }

        var selected: [Double] = []
        var lowerBound = 0
        for position in 0..<frameCount {
            let progress = frameCount == 1 ? 0 : Double(position) / Double(frameCount - 1)
            let target = source[0] + (desiredDuration - source[0]) * progress
            let remaining = frameCount - position - 1
            let upperBound = max(lowerBound, candidates.count - remaining - 1)
            var bestIndex = lowerBound
            var bestScore = Double.greatestFiniteMagnitude
            for index in lowerBound...upperBound {
                let distance = abs(candidates[index] - target) / interval
                let measureAccent = index % 4 == 0 ? 0.22 : (index % 2 == 0 ? 0.08 : 0)
                let score = distance - measureAccent
                if score < bestScore {
                    bestScore = score
                    bestIndex = index
                }
                if candidates[index] > target + interval { break }
            }
            selected.append(candidates[bestIndex])
            lowerBound = bestIndex + 1
        }
        return selected
    }

    static func transitionPlan(for frames: [TimelapseFrame]) -> [TimelapseTransition] {
        guard frames.count >= 2 else { return [] }
        let thumbnails = frames.map { thumbnailPixels($0.imageData) }
        return zip(thumbnails, thumbnails.dropFirst()).map { current, next in
            guard let current, let next else { return .smooth }
            return transition(from: current, to: next)
        }
    }

    static func transition(from first: Data, to second: Data) -> TimelapseTransition {
        guard let firstPixels = thumbnailPixels(first),
              let secondPixels = thumbnailPixels(second),
              firstPixels.count == secondPixels.count else { return .smooth }
        return transition(from: firstPixels, to: secondPixels)
    }

    private static func transition(from firstPixels: [UInt8], to secondPixels: [UInt8]) -> TimelapseTransition {
        var rawDifference = 0.0
        var firstMean = 0.0
        var secondMean = 0.0
        for index in firstPixels.indices {
            let firstValue = Double(firstPixels[index])
            let secondValue = Double(secondPixels[index])
            rawDifference += abs(firstValue - secondValue)
            firstMean += firstValue
            secondMean += secondValue
        }
        let count = Double(firstPixels.count)
        rawDifference /= count * 255
        let exposureDifference = abs(firstMean - secondMean) / (count * 255)
        let structuralDifference = max(0, rawDifference - exposureDifference * 0.65)
        let score = structuralDifference * 0.7 + rawDifference * 0.3
        if score < 0.11 { return .morph }
        if score < 0.28 { return .smooth }
        return .cut
    }

    private static func sanitized(_ beats: [Double]) -> [Double] {
        beats.filter { $0.isFinite && $0 > 0 }
            .sorted()
            .reduce(into: []) { result, value in
                if result.last.map({ value - $0 > 0.01 }) ?? true { result.append(value) }
            }
    }

    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }

    private static func thumbnailPixels(_ data: Data) -> [UInt8]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 24,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        let width = 24
        let height = 24
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixels
    }
}

import Foundation
import Photos
import UIKit
import ImageIO

struct PhotoImportSource {
    let assetIdentifier: String?
    let selectionIndex: Int
    let load: () async -> Data?
}

@MainActor
protocol PhotoLibraryImporting {
    func buildEntries(
        from sources: [PhotoImportSource],
        maxPixelSize: CGFloat,
        progress: @escaping (Double) -> Void
    ) async -> [Entry]
}

extension PhotoLibraryImporting {
    func buildEntries(from sources: [PhotoImportSource], progress: @escaping (Double) -> Void) async -> [Entry] {
        await buildEntries(from: sources, maxPixelSize: 2560, progress: progress)
    }
}

@MainActor
final class PhotoLibraryImporter: PhotoLibraryImporting {

    func buildEntries(
        from sources: [PhotoImportSource],
        maxPixelSize: CGFloat,
        progress: @escaping (Double) -> Void
    ) async -> [Entry] {
        guard !sources.isEmpty else { return [] }

        let assetDates = libraryDates(for: sources.compactMap(\.assetIdentifier))

        var loaded: [(id: String, index: Int, data: Data, date: Date?)] = []
        loaded.reserveCapacity(sources.count)

        for (offset, source) in sources.enumerated() {
            guard let data = await source.load() else { continue }
            let identifier = source.assetIdentifier ?? UUID().uuidString
            let date = source.assetIdentifier.flatMap { assetDates[$0] } ?? Self.exifDate(from: data)
            loaded.append((identifier, source.selectionIndex, data, date))
            progress(Double(offset + 1) / Double(sources.count) * 0.5)
        }

        let items = loaded.map {
            PhotoImportItem(assetIdentifier: $0.id, creationDate: $0.date, selectionIndex: $0.index)
        }
        let resolved = PhotoImportPlan.resolvedOrder(items)
        let dataByIdentifier = Dictionary(loaded.map { ($0.id, $0.data) }, uniquingKeysWith: { first, _ in first })

        var entries: [Entry] = []
        entries.reserveCapacity(resolved.count)
        for (offset, item) in resolved.enumerated() {
            guard let data = dataByIdentifier[item.assetIdentifier] else { continue }
            guard let downsampled = await downsample(data, maxPixelSize: maxPixelSize) else { continue }
            entries.append(
                Entry(capturedAt: item.date, imageData: downsampled, sourceAssetIdentifier: item.assetIdentifier)
            )
            progress(0.5 + Double(offset + 1) / Double(resolved.count) * 0.5)
        }
        return entries
    }

    private func libraryDates(for identifiers: [String]) -> [String: Date] {
        guard !identifiers.isEmpty else { return [:] }
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else { return [:] }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var map: [String: Date] = [:]
        assets.enumerateObjects { asset, _, _ in
            if let date = asset.creationDate {
                map[asset.localIdentifier] = date
            }
        }
        return map
    }

    private func downsample(_ data: Data, maxPixelSize: CGFloat) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            ImageDownsampler.image(from: data, maxPixelSize: maxPixelSize)?
                .jpegData(compressionQuality: 0.9)
        }.value
    }

    static func exifDate(from data: Data) -> Date? {
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let raw = (exif?[kCGImagePropertyExifDateTimeOriginal] as? String)
            ?? (exif?[kCGImagePropertyExifDateTimeDigitized] as? String)
            ?? (tiff?[kCGImagePropertyTIFFDateTime] as? String)
        guard let raw else { return nil }
        return exifFormatter.date(from: raw)
    }

    private static let exifFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}

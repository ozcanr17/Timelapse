import UIKit
import ImageIO

enum ImageDownsampler {

    static func image(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func image(from data: Data?, maxPixelSize: CGFloat) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: .userInitiated) {
            image(from: data, maxPixelSize: maxPixelSize)
        }.value
    }

    /// Bellek içi küçük resim önbelleği: aynı kare tekrar tekrar diskten okunup
    /// çözülmesin diye. Önbellek isabetinde `load` hiç çağrılmaz (disk erişimi olmaz).
    static func cachedImage(
        key: String,
        maxPixelSize: CGFloat,
        load: () -> Data?
    ) async -> UIImage? {
        let fullKey = "\(key)-\(Int(maxPixelSize))" as NSString
        if let hit = ThumbnailCache.shared.object(forKey: fullKey) { return hit }
        guard let data = load() else { return nil }
        guard let decoded = await image(from: data, maxPixelSize: maxPixelSize) else { return nil }
        let cost = decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        ThumbnailCache.shared.setObject(decoded, forKey: fullKey, cost: cost)
        return decoded
    }
}

enum ThumbnailCache {
    static let shared: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 240
        cache.totalCostLimit = 128 * 1_024 * 1_024
        return cache
    }()
}

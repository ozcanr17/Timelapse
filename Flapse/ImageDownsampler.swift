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

    static func image(
        from data: Data?,
        maxPixelSize: CGFloat,
        priority: TaskPriority = .userInitiated
    ) async -> UIImage? {
        guard let data else { return nil }
        return await Task.detached(priority: priority) {
            image(from: data, maxPixelSize: maxPixelSize)
        }.value
    }

    /// Bellek içi küçük resim önbelleği: aynı kare tekrar tekrar diskten okunup
    /// çözülmesin diye. Önbellek isabetinde `load` hiç çağrılmaz (disk erişimi olmaz).
    static func cachedImage(
        key: String,
        maxPixelSize: CGFloat,
        priority: TaskPriority = .userInitiated,
        load: () -> Data?
    ) async -> UIImage? {
        let fullKey = "\(key)-\(Int(maxPixelSize))" as NSString
        if let hit = ThumbnailCache.shared.object(forKey: fullKey) { return hit }
        guard let data = load() else { return nil }
        guard let decoded = await ThumbnailDecodeCoordinator.shared.image(
            key: fullKey as String,
            data: data,
            maxPixelSize: maxPixelSize,
            priority: priority
        ) else { return nil }
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
        MemoryWarningObserver.shared.onMemoryWarning = { [weak cache] in
            cache?.removeAllObjects()
        }
        return cache
    }()
}

private actor ThumbnailDecodeCoordinator {
    static let shared = ThumbnailDecodeCoordinator()

    private var tasks: [String: Task<UIImage?, Never>] = [:]

    func image(
        key: String,
        data: Data,
        maxPixelSize: CGFloat,
        priority: TaskPriority
    ) async -> UIImage? {
        if let task = tasks[key] {
            return await task.value
        }
        let task = Task.detached(priority: priority) {
            ImageDownsampler.image(from: data, maxPixelSize: maxPixelSize)
        }
        tasks[key] = task
        let image = await task.value
        tasks[key] = nil
        return image
    }
}

private final class MemoryWarningObserver: @unchecked Sendable {
    static let shared = MemoryWarningObserver()

    var onMemoryWarning: (() -> Void)?
    private var token: NSObjectProtocol?

    private init() {
        token = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onMemoryWarning?()
        }
    }

    deinit {
        if let token {
            NotificationCenter.default.removeObserver(token)
        }
    }
}

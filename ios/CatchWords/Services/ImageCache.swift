import UIKit

/// In-memory image cache keyed by STORAGE PATH (signed URLs change, paths don't).
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 400
        // Bounded by decoded bytes, not only by count: 400 full photos (1600 px) would be ~3 GB of bitmaps.
        cache.totalCostLimit = 160 * 1024 * 1024
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString, cost: Self.cost(of: image))
    }

    /// Signing out: the next account must not be shown this one's pictures.
    func removeAll() {
        cache.removeAllObjects()
    }

    func load(url: URL, key: String) async -> UIImage? {
        if let hit = image(for: key) { return hit }
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode ?? 0 < 300 else { return nil }
        // Decoded off the main thread (a list scrolling through photos must not decode them on draw).
        guard let img = await Task.detached(priority: .utility, operation: { () -> UIImage? in
            guard let raw = UIImage(data: data) else { return nil }
            return raw.preparingForDisplay() ?? raw
        }).value else { return nil }
        set(img, for: key)
        return img
    }

    private static func cost(of image: UIImage) -> Int {
        if let cg = image.cgImage { return cg.bytesPerRow * cg.height }
        let px = image.size.width * image.scale * image.size.height * image.scale
        return Int(max(1, px * 4))
    }
}

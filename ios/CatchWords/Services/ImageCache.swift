import UIKit

/// In-memory image cache keyed by STORAGE PATH (signed URLs change, paths don't).
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 400
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func set(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    func load(url: URL, key: String) async -> UIImage? {
        if let hit = image(for: key) { return hit }
        var req = URLRequest(url: url)
        req.cachePolicy = .returnCacheDataElseLoad
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode ?? 0 < 300,
              let img = UIImage(data: data) else { return nil }
        set(img, for: key)
        return img
    }
}

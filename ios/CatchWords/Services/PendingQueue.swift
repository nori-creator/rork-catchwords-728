import UIKit
import ImageIO

/// A photo whose analysis/save failed. Kept as a FILE (never a data URL) with only its path in the index.
nonisolated struct PendingCatch: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let createdAt: Date
    var reason: String
    let lat: Double?
    let lng: Double?
    /// The account that took the photo. Another account signed in on this device never sees it (or
    /// saves it into its own dex); the file stays until its owner comes back. nil = taken before
    /// photos were kept per account, or as a local guest — the next account that signs in adopts it.
    var ownerId: String? = nil
}

/// "Never lose a photo that can't be retaken" — any failure type keeps the photo.
/// The index and the JPEGs live in Application Support, so they survive an app kill or a reboot;
/// the 「解析待ち」 list (home banner, camera badge) offers them again on the next launch.
@Observable
final class PendingQueue {
    static let shared = PendingQueue()

    private let dir: URL
    private var indexURL: URL { dir.appendingPathComponent("index.json") }
    /// This account's photos, newest first (what the home banner and the camera list show).
    private(set) var items: [PendingCatch] = []
    private let thumbs = NSCache<NSString, UIImage>()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        dir = base.appendingPathComponent("pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        items = visible(readIndex())
    }

    private var currentOwner: String? { SupabaseClient.shared.userId }

    /// Every entry on disk (all accounts).
    private func readIndex() -> [PendingCatch] {
        guard let data = try? Data(contentsOf: indexURL),
              let items = try? JSONDecoder().decode([PendingCatch].self, from: data) else { return [] }
        return items
    }

    /// The signed-in account's entries. Entries without an owner are adopted by the account that
    /// sees them first (they were taken on this device before ownership was recorded).
    private func visible(_ all: [PendingCatch]) -> [PendingCatch] {
        let owner = currentOwner
        var everything = all
        if let owner, everything.contains(where: { $0.ownerId == nil }) {
            for i in everything.indices where everything[i].ownerId == nil { everything[i].ownerId = owner }
            write(everything)
        }
        return everything.filter { $0.ownerId == owner }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Re-reads the index for the account signed in now (sign-in, sign-out, account switch).
    func reload() {
        items = visible(readIndex())
    }

    func all() -> [PendingCatch] {
        reload()
        return items
    }

    @discardableResult
    func add(image: UIImage, reason: String, lat: Double?, lng: Double?) -> PendingCatch? {
        guard let jpeg = ImageTools.jpegForUpload(image) else { return nil }
        let item = PendingCatch(id: UUID().uuidString, createdAt: Date(), reason: reason, lat: lat, lng: lng,
                                ownerId: currentOwner)
        do {
            try jpeg.write(to: fileURL(item.id), options: .atomic)
        } catch {
            return nil
        }
        var all = readIndex()
        all.append(item)
        save(all)
        return item
    }

    func updateReason(id: String, reason: String) {
        var all = readIndex()
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].reason = reason
        save(all)
    }

    func image(for item: PendingCatch) -> UIImage? {
        UIImage(contentsOfFile: fileURL(item.id).path)
    }

    /// A small preview for the 「解析待ち」 list, read with ImageIO (never the whole photo decoded per row).
    func thumbnail(for item: PendingCatch, maxSide: CGFloat = 168) -> UIImage? {
        if let hit = thumbs.object(forKey: item.id as NSString) { return hit }
        guard let img = ImageTools.downsampled(url: fileURL(item.id), maxSide: maxSide) else { return nil }
        thumbs.setObject(img, forKey: item.id as NSString)
        return img
    }

    func remove(id: String) {
        try? FileManager.default.removeItem(at: fileURL(id))
        thumbs.removeObject(forKey: id as NSString)
        save(readIndex().filter { $0.id != id })
    }

    private func fileURL(_ id: String) -> URL { dir.appendingPathComponent("\(id).jpg") }

    private func save(_ all: [PendingCatch]) {
        write(all)
        items = all.filter { $0.ownerId == currentOwner }.sorted { $0.createdAt > $1.createdAt }
    }

    private func write(_ all: [PendingCatch]) {
        guard let data = try? JSONEncoder().encode(all) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

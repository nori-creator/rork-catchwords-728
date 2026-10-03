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
    /// Photos whose JPEG is still being written in the background (the shutter must not wait for a
    /// 100–200 ms encode on the main thread). Served from memory until the file is on disk.
    @ObservationIgnored private var inFlight: [String: UIImage] = [:]

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

    /// Queues a photo. The entry (and its id) exists at once; the JPEG is encoded and written off the
    /// main thread. Until then `image(for:)` answers from memory; if the entry is removed meanwhile the
    /// file is deleted as soon as it lands, and if the photo cannot be written the entry goes away.
    @discardableResult
    func add(image: UIImage, reason: String, lat: Double?, lng: Double?) -> PendingCatch? {
        let item = PendingCatch(id: UUID().uuidString, createdAt: Date(), reason: reason, lat: lat, lng: lng,
                                ownerId: currentOwner)
        let url = fileURL(item.id)
        inFlight[item.id] = image
        var all = readIndex()
        all.append(item)
        save(all)
        Task {
            let written = await Task.detached(priority: .userInitiated) { () -> Bool in
                guard let jpeg = ImageTools.jpegForUpload(image) else { return false }
                do {
                    try jpeg.write(to: url, options: .atomic)
                    return true
                } catch {
                    return false
                }
            }.value
            self.finishWrite(id: item.id, written: written)
        }
        return item
    }

    private func finishWrite(id: String, written: Bool) {
        inFlight[id] = nil
        let all = readIndex()
        let stillQueued = all.contains { $0.id == id }
        if written && stillQueued { return }
        // Removed while it was being written (caught, reset, account deleted), or never written.
        try? FileManager.default.removeItem(at: fileURL(id))
        if stillQueued { save(all.filter { $0.id != id }) }
    }

    func updateReason(id: String, reason: String) {
        var all = readIndex()
        guard let i = all.firstIndex(where: { $0.id == id }) else { return }
        all[i].reason = reason
        save(all)
    }

    func image(for item: PendingCatch) -> UIImage? {
        if let img = inFlight[item.id] { return img }
        return UIImage(contentsOfFile: fileURL(item.id).path)
    }

    /// A small preview for the 「解析待ち」 list, read with ImageIO (never the whole photo decoded per row).
    func thumbnail(for item: PendingCatch, maxSide: CGFloat = 168) -> UIImage? {
        if let hit = thumbs.object(forKey: item.id as NSString) { return hit }
        if let img = inFlight[item.id] { return ImageTools.resized(img, maxSide: maxSide) }  // not cached: the file version replaces it
        guard let img = ImageTools.downsampled(url: fileURL(item.id), maxSide: maxSide) else { return nil }
        thumbs.setObject(img, forKey: item.id as NSString)
        return img
    }

    func remove(id: String) {
        inFlight[id] = nil
        try? FileManager.default.removeItem(at: fileURL(id))
        thumbs.removeObject(forKey: id as NSString)
        save(readIndex().filter { $0.id != id })
    }

    /// The account was deleted: its waiting photos go too (nobody can ever open them again).
    func removeAll(ownerId: String) {
        let all = readIndex()
        for item in all where item.ownerId == ownerId {
            inFlight[item.id] = nil
            try? FileManager.default.removeItem(at: fileURL(item.id))
            thumbs.removeObject(forKey: item.id as NSString)
        }
        save(all.filter { $0.ownerId != ownerId })
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

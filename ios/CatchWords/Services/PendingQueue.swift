import UIKit

/// A photo whose analysis/save failed. Kept as a FILE (never a data URL) with only its path in the index.
nonisolated struct PendingCatch: Codable, Identifiable, Sendable, Hashable {
    let id: String
    let createdAt: Date
    var reason: String
    let lat: Double?
    let lng: Double?
}

/// "Never lose a photo that can't be retaken" — any failure type keeps the photo.
final class PendingQueue {
    static let shared = PendingQueue()

    private let dir: URL
    private var indexURL: URL { dir.appendingPathComponent("index.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("pending", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    func all() -> [PendingCatch] {
        guard let data = try? Data(contentsOf: indexURL),
              let items = try? JSONDecoder().decode([PendingCatch].self, from: data) else { return [] }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(image: UIImage, reason: String, lat: Double?, lng: Double?) -> PendingCatch? {
        guard let jpeg = ImageTools.jpegForUpload(image) else { return nil }
        let item = PendingCatch(id: UUID().uuidString, createdAt: Date(), reason: reason, lat: lat, lng: lng)
        do {
            try jpeg.write(to: dir.appendingPathComponent("\(item.id).jpg"), options: .atomic)
        } catch {
            return nil
        }
        var items = all()
        items.append(item)
        save(items)
        return item
    }

    func updateReason(id: String, reason: String) {
        var items = all()
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].reason = reason
        save(items)
    }

    func image(for item: PendingCatch) -> UIImage? {
        UIImage(contentsOfFile: dir.appendingPathComponent("\(item.id).jpg").path)
    }

    func remove(id: String) {
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id).jpg"))
        save(all().filter { $0.id != id })
    }

    /// Account deleted: every waiting photo goes with it.
    func removeAll() {
        for item in all() {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(item.id).jpg"))
        }
        try? FileManager.default.removeItem(at: indexURL)
    }

    private func save(_ items: [PendingCatch]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}

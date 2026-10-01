import RealityKit
import SwiftUI

// MARK: - Dex: a shelf of books, one per category

struct ShelfBook: Identifiable, Equatable {
    let key: String
    let count: Int
    var id: String { key }
}

/// A row of Blender-made books standing on a shelf. Each book is a category (colour from its room,
/// label with emoji / name / count). Tapping a book filters the dex to that category.
struct Bookshelf3DView: View {
    let books: [ShelfBook]
    let selected: String?
    let onSelect: (String?) -> Void

    @State private var entities: [String: Entity] = [:]

    private let spacing: Float = 0.16

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual
                let shelf = await buildShelf()
                content.add(shelf)
                let width = Float(max(1, books.count - 1)) * spacing
                Scene3D.addStudio(to: content, target: [width / 2, 0.1, 0],
                                  distance: max(0.55, width * 1.25 + 0.3), fov: 30)
            } update: { _ in
                highlight(selected)
            }
            // Plain SwiftUI buttons over each book: reliable taps and VoiceOver labels.
            HStack(spacing: 0) {
                ForEach(books) { b in
                    Button {
                        Haptics.selection()
                        onSelect(selected == b.key ? nil : b.key)
                    } label: {
                        Color.clear.contentShape(Rectangle())
                    }
                    .accessibilityLabel(L("\(Category.label(for: b.key))、\(b.count)語"))
                    .accessibilityAddTraits(selected == b.key ? .isSelected : [])
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 190)
    }

    private func buildShelf() async -> Entity {
        let shelf = Entity()
        let board = ModelEntity(
            mesh: .generateBox(width: Float(books.count) * spacing + 0.08, height: 0.012, depth: 0.09, cornerRadius: 0.004),
            materials: [Scene3D.cloth(UIColor(hex: 0xC99A6B))]
        )
        board.position = [Float(max(0, books.count - 1)) * spacing / 2, -0.006, 0]
        shelf.addChild(board)
        var made: [String: Entity] = [:]
        for (i, b) in books.enumerated() {
            guard let book = await Scene3D.load(.book) else { continue }
            let tint = UIColor(hex: Category.room(for: b.key).accentHex)
            for part in ["BookCover", "BookCoverBack", "BookSpine"] {
                Scene3D.paint(book, named: part, with: Scene3D.cloth(tint))
            }
            for band in ["SpineBand0", "SpineBand1"] { Scene3D.paint(book, named: band, with: Scene3D.gold) }
            let label = Scene3D.labelImage(emoji: Category.emoji(for: b.key), title: Category.label(for: b.key),
                                           count: b.count, tint: tint)
            if let mat = await Scene3D.picture(label) { Scene3D.paint(book, named: "BookLabel", with: mat) }
            // Books face the camera, spine left, slightly turned so the spine and pages show.
            book.position = [Float(i) * spacing - 0.07, 0, 0]
            book.orientation = simd_quatf(angle: -0.28, axis: [0, 1, 0])
            shelf.addChild(book)
            made[b.key] = book
        }
        entities = made
        return shelf
    }

    /// The chosen book leans forward and rises; the others settle back.
    private func highlight(_ key: String?) {
        for (k, book) in entities {
            var t = book.transform
            let on = k == key
            t.translation.y = on ? 0.03 : 0
            t.translation.z = on ? 0.04 : 0
            t.rotation = simd_quatf(angle: on ? 0 : -0.28, axis: [0, 1, 0]) * simd_quatf(angle: on ? -0.12 : 0, axis: [1, 0, 0])
            book.move(to: t, relativeTo: book.parent, duration: 0.35, timingFunction: .easeInOut)
        }
    }
}

// MARK: - Home: the album

/// The Blender-made ring album with the newest photo on its cover, turning slowly.
struct Album3DView: View {
    let cover: UIImage?

    @MainActor final class Holder { let pivot = Entity() }
    @State private var holder = Holder()

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            guard let album = await Scene3D.load(.album) else { return }
            for ring in ["AlbumRings0", "AlbumRings1", "AlbumRings2"] {
                Scene3D.paint(album, named: ring, with: Scene3D.gold)
            }
            if let cover, let mat = await Scene3D.picture(cover) {
                Scene3D.paint(album, named: "AlbumPhoto", with: mat)
            }
            album.position = [-0.11, 0, 0]
            holder.pivot.addChild(album)
            holder.pivot.orientation = simd_quatf(angle: -0.3, axis: [0, 1, 0])
            content.add(holder.pivot)
            Scene3D.addStudio(to: content, target: [0, 0.085, 0], distance: 0.62)
        }
        // Cancelled automatically when the view goes away.
        .task {
            var sign: Float = 1
            while !Task.isCancelled {
                var next = holder.pivot.transform
                next.rotation = simd_quatf(angle: 0.3 * sign, axis: [0, 1, 0])
                holder.pivot.move(to: next, relativeTo: holder.pivot.parent, duration: 3.2, timingFunction: .easeInOut)
                sign *= -1
                try? await Task.sleep(for: .milliseconds(3200))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview (for the GitHub simulator check; no login needed)

/// Opened with the launch argument `-uiPreview 3d` (DEBUG builds only) so the "iOS check" workflow
/// can photograph the 3D scenes without an iPhone or an account.
struct Preview3DView: View {
    @State private var selected: String? = "fruit"

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text(L("3D プレビュー")).font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                Bookshelf3DView(books: [ShelfBook(key: "fruit", count: 12), ShelfBook(key: "drink", count: 7),
                                        ShelfBook(key: "animal", count: 4), ShelfBook(key: "tech", count: 9)],
                                selected: selected) { selected = $0 }
                    .background(Theme.card, in: .rect(cornerRadius: 24))
                Album3DView(cover: CaptureViewModel.textCard(for: L("旅行")))
                    .frame(height: 220)
                    .background(Theme.card, in: .rect(cornerRadius: 24))
            }
            .padding(16)
        }
        .background(Color(hex: 0x071A33).ignoresSafeArea())
    }
}

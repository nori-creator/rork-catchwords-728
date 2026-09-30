import RealityKit
import SwiftUI

// MARK: - Catch: the word goes into a glass jar

/// Holds the entities of one jar scene so SwiftUI state changes can drive RealityKit animations.
@MainActor
final class JarScene {
    let root = Entity()
    var jar: Entity?
    var cork: Entity?
    var photo: ModelEntity?
    var stars: [Entity] = []
    private(set) var bloomed = false
    /// Loading can take longer than the choreography's wait before the bloom. A bloom asked for
    /// before the models are ready is remembered and played the moment they are (never dropped).
    private var built = false
    private var bloomRequested = false
    private var wobble: Task<Void, Never>?

    /// Photo height inside the jar (metres). The jar is ~0.22 m tall with its base at y = 0.
    static let photoY: Float = 0.095

    /// Draw order for the see-through parts: the photo first, then the glass over it. Without this
    /// RealityKit may draw the glass first; its depth then hides the photo standing inside the jar
    /// (seen on the CI simulator frames: an empty jar).
    private let sortGroup = ModelSortGroup(depthPass: nil)

    func build(image: UIImage, label: String? = nil) async {
        root.position = .zero
        if let jar = await Scene3D.load(.jar) {
            Scene3D.paint(jar, named: "JarGlass", with: Scene3D.glass)
            if let glass = jar.findEntity(named: "JarGlass") { Self.setSort(glass, group: sortGroup, order: 1) }
            Scene3D.paint(jar, named: "JarRim", with: Scene3D.gold)
            // The Blender marker plane is only a guide; an "invisible" material still renders
            // opaque grey in RealityKit and hid the photo — remove it.
            jar.findEntity(named: "JarStage")?.removeFromParent()
            // The cork is animated on its own: lift it out of the jar model.
            if let cork = jar.findEntity(named: "JarCork") {
                let world = cork.transformMatrix(relativeTo: nil)
                cork.removeFromParent()
                cork.setTransformMatrix(world, relativeTo: nil)
                root.addChild(cork)
                cork.position.y += 0.12
                cork.scale = .init(repeating: 0.001)
                self.cork = cork
            }
            // The word printed on the paper band (the Blender band has no UVs, so a curved strip
            // with its own UVs is laid just over its front).
            if let label, !label.isEmpty, let strip = Self.labelStrip() {
                if var mat = await Scene3D.picture(Self.labelArt(label)) {
                    mat.faceCulling = .none  // whichever way the strip winds, it is seen
                    let e = ModelEntity(mesh: strip, materials: [mat])
                    jar.addChild(e)
                }
            }
            jar.scale = .init(repeating: 0.001)
            root.addChild(jar)
            self.jar = jar
        }
        // The caught photo, standing inside the jar and facing the camera.
        let aspect = Float(image.size.width / max(1, image.size.height))
        let h: Float = 0.105
        let plane = ModelEntity(mesh: .generatePlane(width: h * aspect, height: h, cornerRadius: 0.008))
        if let mat = await Scene3D.picture(image) { plane.model?.materials = [mat] }
        plane.components.set(ModelSortGroupComponent(group: sortGroup, order: 0))
        // A thin paper card behind it, like a print slipped into the jar (also keeps the
        // photo readable against the glass).
        var paper = UnlitMaterial(color: UIColor(red: 1, green: 0.99, blue: 0.96, alpha: 1))
        paper.faceCulling = .none
        let card = ModelEntity(mesh: .generatePlane(width: h * aspect + 0.012, height: h + 0.016, cornerRadius: 0.006),
                               materials: [paper])
        card.position = [0, -0.002, -0.0015]
        plane.addChild(card)
        plane.position = [0, Self.photoY + 0.02, 0]
        plane.scale = .init(repeating: 1.55)
        root.addChild(plane)
        photo = plane

        for i in 0..<12 {
            guard let star = await Scene3D.load(.star) else { break }
            Scene3D.paintAll(star, with: Scene3D.gold)
            star.position = [0, Self.photoY, 0]
            star.scale = .init(repeating: 0.001)
            star.orientation = simd_quatf(angle: Float(i) * 0.9, axis: [0, 0, 1])
            root.addChild(star)
            stars.append(star)
        }
        built = true
        if bloomRequested { bloom() }
    }

    /// A curved strip on the jar's label band (radius 0.0712 m, y 0.040…0.070), facing the camera.
    private static func labelStrip() -> MeshResource? {
        let r: Float = 0.0716, y0: Float = 0.0425, y1: Float = 0.0675
        let span: Float = 1.25   // radians, centred on +z
        let seg = 24
        var pos: [SIMD3<Float>] = [], nor: [SIMD3<Float>] = [], uv: [SIMD2<Float>] = [], idx: [UInt32] = []
        for i in 0...seg {
            let u = Float(i) / Float(seg)
            let a = -span / 2 + span * u
            let n = SIMD3<Float>(sin(a), 0, cos(a))
            pos += [SIMD3(n.x * r, y0, n.z * r), SIMD3(n.x * r, y1, n.z * r)]
            nor += [n, n]
            uv += [SIMD2(u, 0), SIMD2(u, 1)]
        }
        for i in 0..<seg {
            let b = UInt32(i * 2)
            idx += [b, b + 2, b + 1, b + 1, b + 2, b + 3]
        }
        var d = MeshDescriptor(name: "JarWordLabel")
        d.positions = .init(pos)
        d.normals = .init(nor)
        d.textureCoordinates = .init(uv)
        d.primitives = .triangles(idx)
        return try? MeshResource.generate(from: [d])
    }

    /// Ink on paper: the headword, centred, in a warm dark ink with a thin gold rule.
    private static func labelArt(_ text: String) -> UIImage {
        let size = CGSize(width: 1024, height: 205)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor(red: 1, green: 0.973, blue: 0.918, alpha: 1).setFill()
            UIRectFill(CGRect(origin: .zero, size: size))
            let gold = UIColor(red: 0.83, green: 0.64, blue: 0.24, alpha: 1)
            gold.setFill()
            UIRectFill(CGRect(x: 0, y: 14, width: size.width, height: 5))
            UIRectFill(CGRect(x: 0, y: size.height - 19, width: size.width, height: 5))
            let p = NSMutableParagraphStyle()
            p.alignment = .center
            let font = UIFont(name: "PingFangTC-Semibold", size: 124) ?? .systemFont(ofSize: 124, weight: .semibold)
            (text as NSString).draw(in: CGRect(x: 40, y: 8, width: size.width - 80, height: 195),
                                    withAttributes: [.font: font, .paragraphStyle: p,
                                                     .foregroundColor: UIColor(red: 0.2, green: 0.16, blue: 0.12, alpha: 1)])
        }
    }

    private static func setSort(_ e: Entity, group: ModelSortGroup, order: Int32) {
        if e.components.has(ModelComponent.self) { e.components.set(ModelSortGroupComponent(group: group, order: order)) }
        for c in e.children { setSort(c, group: group, order: order) }
    }

    /// 幕2 bloom: the jar forms around the photo, the photo settles in, the cork drops, stars burst.
    func bloom() {
        guard built else {
            bloomRequested = true
            return
        }
        guard !bloomed else { return }
        bloomed = true
        if let jar {
            var t = jar.transform
            t.scale = .one
            jar.move(to: t, relativeTo: root, duration: 0.42, timingFunction: .easeOut)
        }
        if let photo {
            var t = photo.transform
            t.scale = .one
            t.translation = [0, Self.photoY, 0.012]
            photo.move(to: t, relativeTo: root, duration: 0.45, timingFunction: .easeInOut)
        }
        if let cork {
            var t = cork.transform
            t.scale = .one
            cork.move(to: t, relativeTo: root, duration: 0.01, timingFunction: .linear)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(260))
                var down = cork.transform
                down.translation.y -= 0.12
                cork.move(to: down, relativeTo: root, duration: 0.28, timingFunction: .easeIn)
                // The cork seats in the neck: pop + clink (ElevenLabs), timed to the landing.
                try? await Task.sleep(for: .milliseconds(250))
                SoundService.shared.play(.jarCork)
            }
        }
        for (i, star) in stars.enumerated() {
            let angle = Float(i) / Float(max(1, stars.count)) * .pi * 2
            let radius: Float = 0.16 + Float(i % 3) * 0.035
            var out = star.transform
            out.translation = [cos(angle) * radius, Self.photoY + sin(angle) * radius * 0.9, 0.05 + Float(i % 2) * 0.04]
            out.scale = .init(repeating: 0.75 + Float(i % 3) * 0.2)
            out.rotation = simd_quatf(angle: .pi * 1.6, axis: normalize([0.3, 1, 0.2])) * star.orientation
            star.move(to: out, relativeTo: root, duration: 0.7, timingFunction: .easeOut)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(760))
                var gone = out
                gone.translation.y -= 0.06
                gone.scale = .init(repeating: 0.001)
                star.move(to: gone, relativeTo: self.root, duration: 0.5, timingFunction: .easeIn)
            }
        }
        startWobble()
    }

    /// 幕3 hold: never frozen — the jar turns gently back and forth so the glass catches the light.
    private func startWobble() {
        wobble?.cancel()
        wobble = Task { @MainActor [root = self.root] in
            var sign: Float = 1
            while !Task.isCancelled {
                var t = root.transform
                t.rotation = simd_quatf(angle: 0.32 * sign, axis: [0, 1, 0])
                root.move(to: t, relativeTo: root.parent, duration: 1.3, timingFunction: .easeInOut)
                sign *= -1
                try? await Task.sleep(for: .milliseconds(1300))
            }
        }
    }

    func stop() { wobble?.cancel() }
}

/// The caught photo in a Blender-made glass jar (RewardOverlay's photo slot when 3D is on).
struct JarCatch3DView: View {
    let image: UIImage
    /// Printed on the jar's paper band.
    var label: String? = nil
    /// Becomes true at 幕2 (bloom). Before that only the photo is visible, exactly like the 2D version.
    let bloom: Bool
    /// Called once the models are loaded and in the scene.
    var onReady: (() -> Void)? = nil

    @State private var scene = JarScene()

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            await scene.build(image: image, label: label)
            content.add(scene.root)
            Scene3D.addStudio(to: content, target: [0, JarScene.photoY + 0.01, 0], distance: 0.62)
            if bloom { scene.bloom() }
            onReady?()
        } placeholder: {
            Color.clear  // never a spinner in the middle of the celebration
        }
        .onChange(of: bloom) { _, on in if on { scene.bloom() } }
        .onDisappear { scene.stop() }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

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
                    .accessibilityLabel("\(Category.label(for: b.key))、\(b.count)語")
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
    @State private var bloom = false
    @State private var selected: String? = "fruit"

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("3D プレビュー").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                ZStack {
                    LinearGradient(colors: [Color(hex: 0x0B2548), Color(hex: 0x0A1F3E)], startPoint: .top, endPoint: .bottom)
                    JarCatch3DView(image: CaptureViewModel.textCard(for: "芒果"), label: "芒果", bloom: bloom)
                }
                .frame(height: 320)
                .clipShape(.rect(cornerRadius: 24))
                Bookshelf3DView(books: [ShelfBook(key: "fruit", count: 12), ShelfBook(key: "drink", count: 7),
                                        ShelfBook(key: "animal", count: 4), ShelfBook(key: "tech", count: 9)],
                                selected: selected) { selected = $0 }
                    .background(Theme.card, in: .rect(cornerRadius: 24))
                Album3DView(cover: CaptureViewModel.textCard(for: "旅行"))
                    .frame(height: 220)
                    .background(Theme.card, in: .rect(cornerRadius: 24))
            }
            .padding(16)
        }
        .background(Color(hex: 0x071A33).ignoresSafeArea())
        .task {
            try? await Task.sleep(for: .seconds(2))
            bloom = true
        }
    }
}

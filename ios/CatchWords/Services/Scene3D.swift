import RealityKit
import SwiftUI
import UIKit

/// The Blender-made 3D models (`blender/catchwords_assets.py` → `Resources/3D/*.usdz`) and
/// the materials the app paints on them at run time (glass, cover colours, photos).
///
/// Models are loaded once and cloned; a failed load returns nil so every 3D view can fall back
/// to its 2D version instead of showing an empty box.
enum Scene3D {
    enum Model: String {
        case jar = "SpecimenJar"
        case star = "RewardStar"
        case book = "DexBook"
        case album = "PhotoAlbum"
    }

    /// 3D effects are on unless the user turned them off or asked for reduced motion.
    static let enabledKey = "fx.3d"

    private static var cache: [Model: Entity] = [:]

    static func load(_ model: Model) async -> Entity? {
        if let e = cache[model] { return e.clone(recursive: true) }
        guard let e = try? await Entity(named: model.rawValue, in: .main) else { return nil }
        cache[model] = e
        return e.clone(recursive: true)
    }

    // MARK: Materials

    /// Clear glass: nearly transparent, glossy, with a clear coat that catches the key light.
    static var glass: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.86, green: 0.94, blue: 1, alpha: 1))
        m.roughness = .init(floatLiteral: 0.04)
        m.metallic = .init(floatLiteral: 0)
        m.clearcoat = .init(floatLiteral: 1)
        m.clearcoatRoughness = .init(floatLiteral: 0.02)
        // Thin and clear: back faces culled so the two walls don't stack into milk.
        m.blending = .transparent(opacity: .init(floatLiteral: 0.14))
        m.faceCulling = .back
        return m
    }

    /// Gold that glows a little on its own, so it reads as gold even without reflections.
    static var gold: PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 0.96, green: 0.73, blue: 0.24, alpha: 1))
        m.metallic = .init(floatLiteral: 1)
        m.roughness = .init(floatLiteral: 0.22)
        m.emissiveColor = .init(color: UIColor(red: 0.55, green: 0.33, blue: 0.02, alpha: 1))
        m.emissiveIntensity = 0.8
        return m
    }

    static func cloth(_ color: UIColor) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = .init(floatLiteral: 0.72)
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    /// A picture that is always fully lit (photos and labels must keep their real colours).
    static func picture(_ image: UIImage) async -> UnlitMaterial? {
        guard let cg = image.normalizedOrientation().cgImage,
              let tex = try? await TextureResource(image: cg, options: .init(semantic: .color)) else { return nil }
        var m = UnlitMaterial()
        m.color = .init(tint: .white, texture: .init(tex))
        m.blending = .transparent(opacity: .init(floatLiteral: 1))
        return m
    }

    /// Paints every mesh under the entity named `name` (Blender object names survive the export).
    static func paint(_ root: Entity, named name: String, with material: any RealityKit.Material) {
        guard let target = root.findEntity(named: name) else { return }
        paintAll(target, with: material)
    }

    static func paintAll(_ entity: Entity, with material: any RealityKit.Material) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = Array(repeating: material, count: max(1, model.materials.count))
            entity.components.set(model)
        }
        for child in entity.children { paintAll(child, with: material) }
    }

    // MARK: Stage

    /// A soft studio: key light from the upper right, a cool fill, and a camera looking at `target`.
    static func addStudio(to content: RealityViewCameraContent, target: SIMD3<Float>, distance: Float, fov: Float = 32) {
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = fov
        camera.look(at: target, from: target + SIMD3(0, distance * 0.18, distance), relativeTo: nil)
        content.add(camera)

        let key = DirectionalLight()
        key.light.intensity = 2600
        key.look(at: target, from: target + SIMD3(0.5, 0.8, 0.7), relativeTo: nil)
        content.add(key)

        let fill = PointLight()
        fill.light.intensity = 2200
        fill.light.color = UIColor(red: 0.75, green: 0.85, blue: 1, alpha: 1)
        fill.light.attenuationRadius = distance * 4
        fill.position = target + SIMD3(-0.4, 0.1, 0.5)
        content.add(fill)
    }

    /// Text drawn on a card, used for book labels (category emoji + name + count).
    static func labelImage(emoji: String, title: String, count: Int?, tint: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 380)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(red: 1, green: 0.99, blue: 0.96, alpha: 1).setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 36).fill()
            tint.withAlphaComponent(0.9).setStroke()
            let border = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size).insetBy(dx: 14, dy: 14), cornerRadius: 28)
            border.lineWidth = 8
            border.stroke()
            let center = NSMutableParagraphStyle()
            center.alignment = .center
            (emoji as NSString).draw(in: CGRect(x: 0, y: 40, width: size.width, height: 150),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 120), .paragraphStyle: center])
            (title as NSString).draw(in: CGRect(x: 20, y: 200, width: size.width - 40, height: 90),
                                     withAttributes: [.font: UIFont.systemFont(ofSize: 64, weight: .bold),
                                                      .foregroundColor: UIColor(red: 0.07, green: 0.13, blue: 0.24, alpha: 1),
                                                      .paragraphStyle: center])
            if let count {
                ("\(count)語" as NSString).draw(in: CGRect(x: 20, y: 290, width: size.width - 40, height: 60),
                                               withAttributes: [.font: UIFont.systemFont(ofSize: 42, weight: .semibold),
                                                                .foregroundColor: tint,
                                                                .paragraphStyle: center])
            }
            _ = ctx
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

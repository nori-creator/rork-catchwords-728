import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum ImageTools {
    /// Same budget as the web (1600px / q0.9) so payloads stay far below the 8MB cap.
    static func jpegForUpload(_ image: UIImage, maxSide: CGFloat = 1600, quality: CGFloat = 0.88) -> Data? {
        resized(image, maxSide: maxSide).jpegData(compressionQuality: quality)
    }

    static func resized(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

/// iOS subject lifting — the same engine as long-pressing a subject in Photos
/// (`VNGenerateForegroundInstanceMaskRequest`). Runs on-device, free, offline.
/// Note: Vision's foreground model does not run on the Simulator; a real iPhone is required.
nonisolated enum CutoutService {
    /// Lifts the subject nearest to `point` (0–1 normalized, top-left origin) or all subjects.
    /// Returns a transparent PNG cropped to the subject, or nil when nothing could be lifted.
    static func liftSubject(from image: UIImage, near point: CGPoint? = nil) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            lift(image: image, point: point, cropped: true)?.cropped
        }.value
    }

    /// Both versions of the lift: `cropped` is the sticker that gets saved; `full` is the same
    /// subject on a transparent canvas the size of `photo`, so it lines up exactly with the photo
    /// on screen — the cut-out animation fades the background away while the subject stays put.
    struct Lift: @unchecked Sendable {
        let cropped: UIImage
        let full: UIImage
        let photo: UIImage
    }

    static func liftDetailed(from image: UIImage, near point: CGPoint? = nil) async -> Lift? {
        await Task.detached(priority: .userInitiated) {
            lift(image: image, point: point, cropped: false)
        }.value
    }

    private static func lift(image source: UIImage, point: CGPoint?, cropped wantCropOnly: Bool) -> Lift? {
        let image = ImageTools.resized(source, maxSide: 1600)
        guard let cg = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }

        var instances = result.allInstances
        if let point {
            let mask = result.instanceMask
            CVPixelBufferLockBaseAddress(mask, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
            let w = CVPixelBufferGetWidth(mask)
            let h = CVPixelBufferGetHeight(mask)
            let x = min(w - 1, max(0, Int(point.x * CGFloat(w))))
            let y = min(h - 1, max(0, Int(point.y * CGFloat(h))))
            if let base = CVPixelBufferGetBaseAddress(mask) {
                let row = CVPixelBufferGetBytesPerRow(mask)
                func label(_ px: Int, _ py: Int) -> Int { Int(base.advanced(by: py * row + px).load(as: UInt8.self)) }
                var hit = label(x, y)
                // The AI's point can land just beside a thin or small subject: take the nearest
                // instance within ~8% of the image instead of lifting every subject in the photo.
                if hit == 0 {
                    let reach = max(4, Int(Double(max(w, h)) * 0.08))
                    let step = max(1, reach / 16)
                    var best = Int.max
                    for py in stride(from: max(0, y - reach), through: min(h - 1, y + reach), by: step) {
                        for px in stride(from: max(0, x - reach), through: min(w - 1, x + reach), by: step) {
                            let l = label(px, py)
                            guard l != 0 else { continue }
                            let d = (px - x) * (px - x) + (py - y) * (py - y)
                            if d < best { best = d; hit = l }
                        }
                    }
                }
                if hit != 0, instances.contains(hit) { instances = IndexSet(integer: hit) }
            }
        }

        let context = CIContext()
        func render(_ crop: Bool) -> UIImage? {
            guard let masked = try? result.generateMaskedImage(
                ofInstances: instances,
                from: handler,
                croppedToInstancesExtent: crop
            ) else { return nil }
            let ci = CIImage(cvPixelBuffer: masked)
            guard let out = context.createCGImage(ci, from: ci.extent) else { return nil }
            return UIImage(cgImage: out)
        }
        guard let croppedImage = render(true) else { return nil }
        if wantCropOnly { return Lift(cropped: croppedImage, full: croppedImage, photo: image) }
        guard let fullImage = render(false) else { return nil }
        return Lift(cropped: croppedImage, full: fullImage, photo: image)
    }
}

extension UIImage {
    /// Camera images carry EXIF orientation; bake it so Vision coordinates match what the user sees.
    nonisolated func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

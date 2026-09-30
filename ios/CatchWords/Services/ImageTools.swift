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
            lift(image: image, point: point)
        }.value
    }

    private static func lift(image source: UIImage, point: CGPoint?) -> UIImage? {
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
                let label = base.advanced(by: y * row + x).load(as: UInt8.self)
                if label != 0, instances.contains(Int(label)) { instances = IndexSet(integer: Int(label)) }
            }
        }

        guard let masked = try? result.generateMaskedImage(
            ofInstances: instances,
            from: handler,
            croppedToInstancesExtent: true
        ) else { return nil }
        let ci = CIImage(cvPixelBuffer: masked)
        let context = CIContext()
        guard let out = context.createCGImage(ci, from: ci.extent) else { return nil }
        return UIImage(cgImage: out)
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

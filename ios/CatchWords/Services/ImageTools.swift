import UIKit
import ImageIO
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

nonisolated enum ImageTools {
    /// Same budget as the web (1600px / q0.9) so payloads stay far below the 8MB cap.
    static func jpegForUpload(_ image: UIImage, maxSide: CGFloat = 1600, quality: CGFloat = 0.88) -> Data? {
        resized(image, maxSide: maxSide).jpegData(compressionQuality: quality)
    }

    /// `jpegForUpload` off the main thread (a full-size photo takes 100–200 ms to resize and encode).
    static func jpegForUploadInBackground(_ image: UIImage, maxSide: CGFloat = 1600, quality: CGFloat = 0.88) async -> Data? {
        await Task.detached(priority: .userInitiated) { jpegForUpload(image, maxSide: maxSide, quality: quality) }.value
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

    /// Decodes an image file at most `maxSide` px on its long side, already upright (EXIF orientation
    /// applied), without ever holding the full-resolution bitmap. A 48 MP library photo decoded with
    /// `UIImage(data:)` and then redrawn costs ~200 MB and a long main-thread stall.
    static func downsampled(data: Data, maxSide: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return downsampled(source: src, maxSide: maxSide)
    }

    static func downsampled(url: URL, maxSide: CGFloat) -> UIImage? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        return downsampled(source: src, maxSide: maxSide)
    }

    private static func downsampled(source: CGImageSource, maxSide: CGFloat) -> UIImage? {
        let opts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(1, Int(maxSide)),
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, opts as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    /// `downsampled(data:maxSide:)` off the main thread (photos picked from the library).
    static func downsampledInBackground(_ data: Data, maxSide: CGFloat = 2400) async -> UIImage? {
        await Task.detached(priority: .userInitiated) { downsampled(data: data, maxSide: maxSide) }.value
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
        if let point, let hit = nearestInstance(in: result.instanceMask, to: point), instances.contains(hit) {
            instances = IndexSet(integer: hit)
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

extension CutoutService {
    /// The instance label under `point` (0–1, top-left origin) in Vision's label mask, or the nearest
    /// instance within ~8% of the image when the point lands just beside a thin or small subject.
    nonisolated static func nearestInstance(in mask: CVPixelBuffer, to point: CGPoint) -> Int? {
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let w = CVPixelBufferGetWidth(mask)
        let h = CVPixelBufferGetHeight(mask)
        guard w > 0, h > 0, let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let row = CVPixelBufferGetBytesPerRow(mask)
        let x = min(w - 1, max(0, Int(point.x * CGFloat(w))))
        let y = min(h - 1, max(0, Int(point.y * CGFloat(h))))
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
        return hit == 0 ? nil : hit
    }

    /// Card catch: ONE foreground-instance request per photo, reused for every object in it.
    /// Nil when Vision finds no subject (or on the Simulator, where the model does not run).
    nonisolated static func instanceMasks(from source: UIImage) async -> InstanceMasks? {
        await Task.detached(priority: .userInitiated) { () -> InstanceMasks? in
            let image = ImageTools.resized(source, maxSide: 1600)
            guard let cg = image.cgImage else { return nil }
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
            do { try handler.perform([request]) } catch { return nil }
            guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
            return InstanceMasks(observation: result, handler: handler)
        }.value
    }
}

/// The result of `CutoutService.instanceMasks`: hit-test a point, and cut one instance out with its alpha
/// bounding box (normalized to the photo, top-left origin) so the cut-out and its box always match.
nonisolated final class InstanceMasks: @unchecked Sendable {
    nonisolated struct Cut: @unchecked Sendable {
        /// The subject on transparency, cropped exactly to `box`.
        let image: UIImage
        /// The opaque pixels' bounding box, 0–1 of the photo.
        let box: CGRect
    }

    private let observation: VNInstanceMaskObservation
    private let handler: VNImageRequestHandler
    private let lock = NSLock()
    private var cache: [Int: Cut] = [:]

    init(observation: VNInstanceMaskObservation, handler: VNImageRequestHandler) {
        self.observation = observation
        self.handler = handler
    }

    func instance(near point: CGPoint) -> Int? {
        guard let hit = CutoutService.nearestInstance(in: observation.instanceMask, to: point),
              observation.allInstances.contains(hit) else { return nil }
        return hit
    }

    /// Heavy (renders a full-size mask): call off the main thread.
    func cut(instance label: Int) -> Cut? {
        lock.lock()
        defer { lock.unlock() }
        if let c = cache[label] { return c }
        guard let masked = try? observation.generateMaskedImage(ofInstances: IndexSet(integer: label), from: handler,
                                                               croppedToInstancesExtent: false) else { return nil }
        let ci = CIImage(cvPixelBuffer: masked)
        guard let full = CIContext().createCGImage(ci, from: ci.extent),
              let px = Self.alphaBounds(full),
              let cropped = full.cropping(to: px) else { return nil }
        let w = CGFloat(full.width), h = CGFloat(full.height)
        let c = Cut(image: UIImage(cgImage: cropped),
                    box: CGRect(x: px.minX / w, y: px.minY / h, width: px.width / w, height: px.height / h))
        cache[label] = c
        return c
    }

    /// Pixel rect (top-left origin) of every pixel whose alpha is above a faint threshold.
    private static func alphaBounds(_ image: CGImage) -> CGRect? {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = bytes.withUnsafeMutableBytes { raw -> Bool in
            guard let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let rowStart = y * w * 4
            for x in 0..<w where bytes[rowStart + x * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
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

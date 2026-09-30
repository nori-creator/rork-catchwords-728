import SwiftUI
import CoreLocation

/// capture.tsx `Step`: camera → processing → select → card → (reward) → dex.
enum CaptureStep: Equatable {
    case camera
    case processing
    case select
    case card
    case failed(String, retryable: Bool)
}

@Observable
final class CaptureViewModel {
    var step: CaptureStep = .camera
    var photo: UIImage?
    var candidates: [Candidate] = []
    var picked: Candidate?
    var details: CardDetails?
    var cutout: UIImage?
    var isCutting: Bool = false
    var cutoutFailed: Bool = false
    var isLoadingDetails: Bool = false
    var caption: String = ""
    var placeName: String?
    var location: CLLocation?
    var captureType: String = "photo"
    var restoredPendingId: String?

    /// runToken: "cancel" only discards stale results; in-flight work is never killed mid-save.
    private var runToken: Int = 0
    private var cutoutTask: Task<Void, Never>?

    func analyze(_ image: UIImage) {
        runToken += 1
        let token = runToken
        photo = image
        candidates = []
        picked = nil
        details = nil
        cutout = nil
        cutoutFailed = false
        captureType = "photo"
        step = .processing
        SoundService.shared.startAnalyzeLoop()

        Task {
            async let loc = LocationService.shared.current()
            do {
                let found = try await AIService.shared.detect(image: image)
                guard token == runToken else { return }
                SoundService.shared.stopAnalyzeLoop()
                candidates = found.sorted { $0.confidence > $1.confidence }
                Haptics.impact(.medium)
                withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { step = .select }
                if let pid = restoredPendingId {
                    PendingQueue.shared.remove(id: pid)
                    restoredPendingId = nil
                }
            } catch {
                guard token == runToken else { return }
                SoundService.shared.stopAnalyzeLoop()
                let reason = (error as? LocalizedError)?.errorDescription ?? "解析に失敗しました。"
                let retryable = (error as? APIError)?.isRetryable ?? true
                // Keep the photo whatever the failure — but never re-queue a photo restored FROM the queue.
                let here = await loc
                if let pid = restoredPendingId {
                    PendingQueue.shared.updateReason(id: pid, reason: reason)
                } else {
                    PendingQueue.shared.add(image: image, reason: reason,
                                            lat: here?.coordinate.latitude, lng: here?.coordinate.longitude)
                }
                Haptics.warning()
                step = .failed(reason, retryable: retryable)
            }
            let here = await loc
            guard token == runToken else { return }
            location = here
            if let here { placeName = await LocationService.shared.placeName(for: here) }
        }
    }

    func search(text: String) {
        runToken += 1
        let token = runToken
        step = .processing
        captureType = "text"
        photo = nil
        cutout = nil
        SoundService.shared.startAnalyzeLoop()
        Task {
            do {
                let c = try await AIService.shared.lookup(text: text)
                guard token == runToken else { return }
                SoundService.shared.stopAnalyzeLoop()
                candidates = [c]
                pick(c)
            } catch {
                guard token == runToken else { return }
                SoundService.shared.stopAnalyzeLoop()
                step = .failed((error as? LocalizedError)?.errorDescription ?? "見つかりませんでした。", retryable: true)
            }
        }
    }

    /// confirmWord: the card appears immediately — cutout is an upgrade, never a gate.
    func pick(_ candidate: Candidate) {
        picked = candidate
        details = nil
        Haptics.impact(.light)
        SoundService.shared.speak(candidate.headword)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = .card }
        startCutout(for: candidate)
        loadDetails(for: candidate)
    }

    func startCutout(for candidate: Candidate?) {
        guard let photo, cutout == nil else { return }
        cutoutTask?.cancel()
        isCutting = true
        cutoutFailed = false
        let point = candidate.map { CGPoint(x: $0.point[0] / 1000, y: $0.point[1] / 1000) }
        cutoutTask = Task {
            let lifted = await CutoutService.liftSubject(from: photo, near: point)
            guard !Task.isCancelled else { return }
            isCutting = false
            if let lifted {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) { cutout = lifted }
                Haptics.impact(.soft)
            } else {
                cutoutFailed = true
            }
        }
    }

    func useOriginal() {
        cutoutTask?.cancel()
        isCutting = false
        withAnimation(.snappy) { cutout = nil }
    }

    private func loadDetails(for candidate: Candidate) {
        let token = runToken
        isLoadingDetails = true
        Task {
            let d = try? await AIService.shared.cardDetails(for: candidate)
            guard token == runToken, picked == candidate else { return }
            isLoadingDetails = false
            withAnimation(.easeOut(duration: 0.3)) { details = d }
        }
    }

    func draft() -> CatchDraft? {
        guard let picked else { return nil }
        let base = photo ?? Self.textCard(for: picked.headword)
        return CatchDraft(
            candidate: picked, details: details, photo: base, cutout: cutout,
            caption: caption, location: location, placeName: placeName, captureType: captureType
        )
    }

    func restore(_ item: PendingCatch) {
        guard let img = PendingQueue.shared.image(for: item) else {
            PendingQueue.shared.remove(id: item.id)
            return
        }
        restoredPendingId = item.id
        analyze(img)
    }

    func reset() {
        runToken += 1
        SoundService.shared.stopAnalyzeLoop()
        cutoutTask?.cancel()
        photo = nil
        candidates = []
        picked = nil
        details = nil
        cutout = nil
        caption = ""
        placeName = nil
        location = nil
        restoredPendingId = nil
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = .camera }
    }

    /// Text catches get a generated "word card" image so the dex always has a surface.
    static func textCard(for text: String) -> UIImage {
        let size = CGSize(width: 900, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 0.04, green: 0.52, blue: 1, alpha: 1).cgColor,
                          UIColor(red: 0, green: 0.25, blue: 0.82, alpha: 1).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: text.count > 3 ? 150 : 230, weight: .bold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: style,
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let bounds = str.boundingRect(with: CGSize(width: size.width - 80, height: size.height), options: .usesLineFragmentOrigin, context: nil)
            str.draw(in: CGRect(x: 40, y: (size.height - bounds.height) / 2, width: size.width - 80, height: bounds.height))
        }
    }
}

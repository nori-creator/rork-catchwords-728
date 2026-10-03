import SwiftUI
import CoreLocation

/// capture.tsx `Step`: camera → (selfie) → processing → select → (reencounter | card) → (reward) → dex.
enum CaptureStep: Equatable {
    case camera
    case selfie
    case processing
    case select
    case card
    /// Web `reencounter`: the picked word is already in the dex ("再会！").
    case reencounter
    /// Web `offlineSaved`: analysis failed; the photo is kept in "解析待ち".
    case failed(String, retryable: Bool)
}

/// CameraChrome.tsx CAMERA_MODES, in on-screen order: 検索 → 撮影 → スキャン.
enum CameraMode: String, CaseIterable, Identifiable {
    case search, photo, scan
    var id: String { rawValue }
    var label: String {
        switch self {
        case .search: L("検索")
        case .photo: L("撮影")
        case .scan: L("スキャン")
        }
    }
    var shutterIcon: String {
        switch self {
        case .search: "magnifyingglass"
        case .photo: "camera"
        case .scan: "text.viewfinder"
        }
    }
}

@Observable
final class CaptureViewModel {
    var step: CaptureStep = .camera
    var mode: CameraMode = .photo
    var photo: UIImage?
    var selfie: UIImage?
    var candidates: [Candidate] = []
    var picked: Candidate?
    var details: CardDetails?
    var cutout: UIImage?
    /// The same lift, aligned with the photo — drives the cut-out animation on the card.
    var cutoutLift: CutoutService.Lift?
    var isCutting: Bool = false
    var cutoutFailed: Bool = false
    var isLoadingDetails: Bool = false
    var isLookingUp: Bool = false
    /// The owned-word check runs between the tap and the card (capture.tsx:905-919).
    var isCheckingOwned: Bool = false
    var caption: String = ""
    /// The spoken one-liner next to the memo (web VoiceCaptionButton).
    var placeName: String?
    var location: CLLocation?
    var captureType: String = "photo"
    var restoredPendingId: String?
    /// Inline error under "違う単語を入力" (web `input.notTargetLang`).
    var searchError: String?
    /// One-line notice (web toast).
    var toast: String?
    /// The failure was "no connection" (web shows WifiOff; otherwise Sparkles).
    var failedOffline: Bool = false

    // Card catch (docs/prototype/cardcatch-src.html): the photo flow's objects, cut-outs and boxes.
    /// The objects in the photo (candidates grouped per object, each with its Vision cut-out and box).
    var objects: [CatchObject] = []
    /// When the shutter was pressed (the prototype starts the analysis 260 ms after `shoot()`).
    var shotAt: Double?
    /// The photo flow uses the card catch; search, scan and text catches keep the picker and sticker card.
    var usesCardCatch: Bool { captureType == "photo" && photo != nil }
    private var masksTask: Task<InstanceMasks?, Never>?

    // Re-encounter ("再会！")
    var owned: OwnedWord?
    var reencCount: Int?
    var reencPhotoSaved: Bool = false
    var reencFailed: Bool = false

    /// runToken: "cancel" only discards stale results; in-flight work is never killed mid-save.
    private var runToken: Int = 0
    private var cutoutTask: Task<Void, Never>?
    private var detailsTask: Task<CardDetails?, Never>?
    /// Detection may finish while the user is still taking the selfie.
    private var detectOutcome: Result<[Candidate], Error>?
    /// The photo is kept in "解析待ち" from the shutter on (capture.tsx enqueueCapture), and
    /// released only when its job is done: saved, re-encountered, or the user starts over.
    private(set) var pendingId: String?

    /// Starts analysis immediately; the selfie prompt covers the wait (web: "ものと一緒に、もう一枚").
    func analyze(_ image: UIImage, askSelfie: Bool = false) {
        runToken += 1
        let token = runToken
        // A word check still running belongs to the old run: its result is dropped, so its flag must not
        // keep blocking taps on the new run's words.
        isCheckingOwned = false
        isLoadingDetails = false
        photo = image
        selfie = nil
        candidates = []
        picked = nil
        details = nil
        detailsTask = nil
        cutout = nil
        cutoutLift = nil
        cutoutFailed = false
        detectOutcome = nil
        searchError = nil
        owned = nil
        objects = []
        shotAt = nil
        captureType = mode == .scan ? "scan" : "photo"
        let textOnly = mode == .scan
        step = askSelfie ? .selfie : .processing
        // The card catch has its own sounds (no BGM in the prototype); scan keeps the analyze loop.
        if !askSelfie, textOnly { SoundService.shared.startAnalyzeLoop() }
        // One foreground-instance request per photo, started with the server call and reused for every object.
        masksTask?.cancel()
        if textOnly {
            masksTask = nil
        } else {
            masksTask = Task<InstanceMasks?, Never> { await CutoutService.instanceMasks(from: image) }
        }
        // A photo restored from the queue is never queued again (one entry per photo, not per retry).
        if let rid = restoredPendingId {
            pendingId = rid
        } else if pendingId == nil {
            pendingId = PendingQueue.shared.add(image: image, reason: L("解析中"), lat: nil, lng: nil)?.id
        }

        Task {
            async let loc = LocationService.shared.current()
            do {
                let found = textOnly
                    ? try await AIService.shared.detectScan(image: image)
                    : try await AIService.shared.suggest(image: image)
                guard token == runToken else { return }
                if !textOnly {
                    let masks = await masksTask?.value
                    let size = image.size
                    let built = await Task.detached(priority: .userInitiated) {
                        CatchObject.build(candidates: found, masks: masks, photoSize: size)
                    }.value
                    guard token == runToken else { return }
                    objects = built
                }
                detectOutcome = .success(found)
            } catch {
                guard token == runToken else { return }
                detectOutcome = .failure(error)
                if let pid = pendingId {
                    PendingQueue.shared.updateReason(id: pid, reason: Self.reason(error))
                }
            }
            if step != .selfie { advanceAfterDetect() }
            let here = await loc
            guard token == runToken else { return }
            location = here
            if let here { placeName = await LocationService.shared.placeName(for: here) }
        }
    }

    /// "いますぐもう一度試す": same photo, same queue entry.
    func retry() {
        guard let p = photo else { reset(); return }
        restoredPendingId = pendingId
        analyze(p)
    }

    func finishSelfie(_ image: UIImage?) {
        guard step == .selfie else { return }
        selfie = image
        if detectOutcome == nil {
            if !usesCardCatch { SoundService.shared.startAnalyzeLoop() }
            withAnimation(.easeInOut(duration: 0.3)) { step = .processing }
        } else {
            advanceAfterDetect()
        }
    }

    private func advanceAfterDetect() {
        guard let outcome = detectOutcome else { return }
        SoundService.shared.stopAnalyzeLoop()
        switch outcome {
        case .success(let found):
            candidates = found
            if usesCardCatch {
                // The card catch plays its own analysis (focus brackets) and then shows the objects.
                step = .select
                return
            }
            Haptics.impact(.medium)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { step = .select }
        case .failure(let error):
            let retryable = (error as? APIError)?.isRetryable ?? true
            failedOffline = { if case .offline? = error as? APIError { return true }; return false }()
            Haptics.warning()
            step = .failed(Self.reason(error), retryable: retryable)
        }
    }

    static func reason(_ error: Error) -> String {
        if case .timeout? = error as? APIError { return L("通信に時間がかかっています。写真は端末に保存しました。") }
        return (error as? LocalizedError)?.errorDescription ?? L("解析に失敗しました。")
    }

    /// Typed search (`suggestWordCandidates`). One result goes straight on; several go to the picker.
    /// With `keepPhoto` (the "違う単語を入力" box under a photo) the photo stays the sticker and
    /// the screen stays put: a miss is shown inline, never as a full-screen failure.
    func search(text: String, keepPhoto: Bool = false) {
        runToken += 1
        let token = runToken
        isCheckingOwned = false
        searchError = nil
        if !keepPhoto {
            step = .processing
            captureType = "text"
            photo = nil
            selfie = nil
            cutout = nil
            SoundService.shared.startAnalyzeLoop()
        }
        isLookingUp = true
        Task {
            defer { if token == runToken { isLookingUp = false } }
            do {
                let found = try await AIService.shared.candidates(for: text, scene: placeName)
                guard token == runToken else { return }
                SoundService.shared.stopAnalyzeLoop()
                guard !found.isEmpty else { throw APIError.message(Self.notTargetLang) }
                if found.count == 1 {
                    pick(found[0])
                } else {
                    candidates = found
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) { step = .select }
                }
            } catch {
                guard token == runToken else { return }
                SoundService.shared.stopAnalyzeLoop()
                Haptics.warning()
                let message: String = {
                    if case .message? = error as? APIError { return Self.notTargetLang }
                    return (error as? LocalizedError)?.errorDescription ?? Self.notTargetLang
                }()
                if keepPhoto {
                    searchError = message
                } else {
                    showToast(message)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = .camera }
                }
            }
        }
    }

    /// input.notTargetLang (web i18n), with the learning language filled in.
    static var notTargetLang: String { L("学習している言語の単語が見つかりませんでした。別の言い方で調べてみてください。") }

    /// Tap on a word: first ask the server whether it is already in the dex (re-encounter),
    /// then show the card. Card details keep generating in the background.
    func pick(_ candidate: Candidate) {
        guard !isCheckingOwned else { return }
        let token = runToken
        picked = candidate
        details = nil
        detailsTask = nil
        searchError = nil
        Haptics.impact(.light)
        SoundService.shared.speak(candidate.headword)
        isCheckingOwned = true
        Task {
            let found = try? await NativeAPI.call(
                "checkOwnedWord",
                ["headword": candidate.headword, "language": NativeAPI.targetLanguage],
                as: OwnedCheck.self, timeout: 15
            )
            guard token == runToken else { return }
            isCheckingOwned = false
            if let o = found?.owned {
                owned = o
                reencCount = nil
                reencFailed = false
                reencPhotoSaved = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = .reencounter }
            } else {
                // Fail open: a broken check must never block a new catch.
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = .card }
                startCutout(for: candidate)
                loadDetails(for: candidate)
            }
        }
    }

    private struct OwnedCheck: Decodable { let owned: OwnedWord? }

    /// Card catch: a word chosen in the sheet (`chooseWord`). The light/card animation is already running;
    /// the owned-word check decides between the card (details load next) and the re-encounter.
    /// The sticker is the object's cut-out (cut-out mode on), else the photo.
    func choose(_ object: CatchObject, word: Candidate) {
        guard !isCheckingOwned else { return }
        let token = runToken
        picked = word
        details = nil
        detailsTask = nil
        searchError = nil
        cutoutTask?.cancel()
        isCutting = false
        cutoutLift = nil
        cutout = Self.cutoutMode ? object.cut : nil
        isCheckingOwned = true
        Task {
            let found = try? await NativeAPI.call(
                "checkOwnedWord",
                ["headword": word.headword, "language": NativeAPI.targetLanguage],
                as: OwnedCheck.self, timeout: 15
            )
            guard token == runToken, picked == word else { return }
            isCheckingOwned = false
            if let o = found?.owned {
                owned = o
                reencCount = nil
                reencFailed = false
                reencPhotoSaved = false
                withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) { step = .reencounter }
            } else {
                // Fail open: a broken check must never block a new catch.
                step = .card
                loadDetails(for: word)
            }
        }
    }

    /// Settings → 切り抜きモード (web `catchSpeed`, default on). Off = keep the photo as the sticker.
    static let cutoutModeKey = "capture.cutoutMode"
    static var cutoutMode: Bool { UserDefaults.standard.object(forKey: cutoutModeKey) as? Bool ?? true }

    /// Cut-out mode: cutting starts the moment a word is tapped, never delays the card,
    /// and is awaited only right before saving (capture.tsx: 図鑑に入れる前に切り抜きが揃っていること).
    func startCutout(for candidate: Candidate?) {
        guard Self.cutoutMode, let photo, cutout == nil, captureType != "scan" else { return }
        cutoutTask?.cancel()
        isCutting = true
        cutoutFailed = false
        let point = candidate.flatMap { $0.group == nil && $0.point != [500, 500]
            ? CGPoint(x: $0.point[0] / 1000, y: $0.point[1] / 1000) : nil }
        cutoutTask = Task {
            let lifted = await CutoutService.liftDetailed(from: photo, near: point)
            guard !Task.isCancelled else { return }
            isCutting = false
            if let lifted {
                // The card animates from `cutoutLift` (aligned) to `cutout` (the sticker).
                cutoutLift = lifted
                cutout = lifted.cropped
            } else {
                cutoutFailed = true
            }
        }
    }


    /// Waits for a cut-out that is still running (a failed one simply leaves the photo).
    func awaitCutout() async {
        guard isCutting, let task = cutoutTask else { return }
        await task.value
    }

    /// Web: card failure → toast 「カード生成に失敗しました」 and back to the picker.
    private func loadDetails(for candidate: Candidate) {
        let token = runToken
        isLoadingDetails = true
        let task = Task<CardDetails?, Never> {
            try? await AIService.shared.cardDetails(for: candidate)
        }
        detailsTask = task
        Task {
            let d = await task.value
            guard token == runToken, picked == candidate else { return }
            isLoadingDetails = false
            if let d {
                withAnimation(.easeOut(duration: 0.3)) { details = d }
            } else if step == .card {
                showToast(L("カード生成に失敗しました"))
                if usesCardCatch {
                    step = .select   // the card catch goes back to its objects
                } else {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                        step = candidates.isEmpty ? .camera : .select
                    }
                }
            }
        }
    }

    /// Saving needs the real card (level, category, extras). Never save placeholder values:
    /// wait for the card that is already being generated.
    func awaitDetails() async -> CardDetails? {
        if let details { return details }
        return await detailsTask?.value
    }

    func draft(details d: CardDetails) -> CatchDraft? {
        guard let picked else { return nil }
        let base = photo ?? Self.textCard(for: picked.headword)
        return CatchDraft(
            candidate: picked, details: d, photo: base, cutout: cutout, selfie: selfie,
            caption: caption, location: location, placeName: placeName, captureType: captureType
        )
    }

    /// The catch was saved (or re-encountered): the queued photo's job is done.
    func releasePending() {
        if let pid = pendingId { PendingQueue.shared.remove(id: pid) }
        pendingId = nil
        restoredPendingId = nil
    }

    /// "もう一枚撮る" from the failure panel keeps the photo in "解析待ち" (that is what it promised).
    func keepPendingAndReset() {
        pendingId = nil
        restoredPendingId = nil
        reset()
    }

    func restore(_ item: PendingCatch) {
        guard let img = PendingQueue.shared.image(for: item) else {
            PendingQueue.shared.remove(id: item.id)
            return
        }
        restoredPendingId = item.id
        pendingId = item.id
        mode = .photo
        analyze(img)
    }

    /// Goes up with every notice, even the same text twice (the card re-enables its button on each one).
    var toastCount: Int = 0

    func showToast(_ text: String) {
        toastCount += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.25)) { if toast == text { toast = nil } }
        }
    }

    /// Starting over throws the queued photo away too (otherwise "解析待ち" piles up).
    func reset() {
        runToken += 1
        SoundService.shared.stopAnalyzeLoop()
        cutoutTask?.cancel()
        masksTask?.cancel()
        masksTask = nil
        objects = []
        shotAt = nil
        if let pid = pendingId { PendingQueue.shared.remove(id: pid) }
        pendingId = nil
        photo = nil
        selfie = nil
        candidates = []
        picked = nil
        details = nil
        detailsTask = nil
        cutout = nil
        cutoutLift = nil
        caption = ""
        placeName = nil
        location = nil
        restoredPendingId = nil
        detectOutcome = nil
        isLookingUp = false
        isCheckingOwned = false
        isLoadingDetails = false
        searchError = nil
        failedOffline = false
        owned = nil
        reencCount = nil
        reencFailed = false
        reencPhotoSaved = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) { step = .camera }
    }

    /// Text catches get a generated "word card" image so the dex always has a surface.
    static func textCard(for text: String) -> UIImage {
        let size = CGSize(width: 900, height: 900)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor(red: 0.16, green: 0.61, blue: 1, alpha: 1).cgColor,
                          UIColor(red: 0, green: 0.38, blue: 0.88, alpha: 1).cgColor] as CFArray
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

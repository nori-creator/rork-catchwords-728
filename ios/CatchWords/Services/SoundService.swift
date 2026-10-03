import AVFoundation

/// Recorded cinematic SFX from the web app (`public/sfx/el-*.mp3`) with the same per-file trims.
enum SFX: String, CaseIterable {
    case impact = "el-catch-impact"
    case bookOpen = "el-book-open"
    case slide = "el-gallery-slide"
    case sting = "el-celebrate-sting"
    case analyzeLoop = "el-analyze-loop"
    // ElevenLabs SFX (eleven_text_to_sound_v2), trimmed and normalized for these moments:
    case jarCork = "el-jar-cork"        // cork lands in the glass jar: soft pop + bright clink
    case cutTrace = "el-cut-trace"      // scissors round the outline (cut-out mode)
    case stickerLift = "el-sticker-lift" // the cut sticker peels up off the page
    case landBounce = "el-land-bounce"  // a word lands: a light ball-like bounce (pon-pon-pon), no coin clink
    // The owner's pick from the web prototype ("bubble pon"): a page opening / going back.
    case ponOpen = "pon-bubble-open"
    case ponBack = "pon-bubble-back"
    // The card-catch prototype's synthesized SFX (docs/prototype/cardcatch-src.html `SFX`), rendered offline by
    // scripts/render_cardcatch_sfx.py. "cands" and "charge"/"fly" are the provisional picks (trio / harp).
    case ccShutter = "cc-shutter"
    case ccTick = "cc-tick"
    case ccScanStart = "cc-scan-start"
    case ccFound = "cc-found"
    case ccPop = "cc-pop"
    case ccCands1 = "cc-cands-1"
    case ccCands2 = "cc-cands-2"
    case ccCands3 = "cc-cands-3"
    case ccCharge = "cc-charge-harp"
    case ccFly = "cc-fly-harp"
    case ccReveal = "cc-reveal"
    case ccTwinkle = "cc-twinkle"
    case ccLand = "cc-land"

    var gain: Float {
        switch self {
        case .impact: 1.4
        case .bookOpen: 1.6
        case .slide: 1.2
        case .sting: 1.1
        case .analyzeLoop: 0.9
        case .jarCork: 0.9
        case .cutTrace: 0.7
        case .stickerLift: 0.8
        case .landBounce: 1.0
        case .ponOpen: 0.9
        case .ponBack: 0.8
        // Rendered at the prototype's loudness relative to the pon (same 0.9); two files were turned down
        // in rendering to avoid clipping and get that back here (render report: ×2.803 and ×1.640; cc-land ×1.590).
        case .ccShutter: 0.9 * 2.803
        case .ccReveal: 0.9 * 1.640
        case .ccLand: 0.9 * 1.590
        case .ccTick, .ccScanStart, .ccFound, .ccPop, .ccCands1, .ccCands2, .ccCands3,
             .ccCharge, .ccFly, .ccTwinkle: 0.9
        }
    }

    /// The card-catch sounds can overlap themselves (the prototype starts a new WebAudio voice each time).
    var isCardCatch: Bool { rawValue.hasPrefix("cc-") }

    /// The pon and card-catch files are AAC (.m4a); everything else is the web's mp3.
    var fileExtension: String {
        if isCardCatch { return "m4a" }
        switch self {
        case .ponOpen, .ponBack: return "m4a"
        default: return "mp3"
        }
    }

    var offset: TimeInterval {
        switch self {
        case .bookOpen: 0.6
        case .slide: 0.05
        default: 0
        }
    }
}

final class SoundService {
    static let shared = SoundService()

    private var players: [SFX: AVAudioPlayer] = [:]
    private let synthesizer = AVSpeechSynthesizer()
    private var voiceCache: [String: AVSpeechSynthesisVoice?] = [:]
    /// The device voice for a language (zh-TW / en / ja), picked once.
    private func voice(for lang: String) -> AVSpeechSynthesisVoice? {
        if let v = voiceCache[lang] { return v }
        let v = Self.pickVoice(Self.bcp47(lang))
        voiceCache[lang] = v
        return v
    }

    /// The language a text is read in — from the text itself, so a word is never read in another
    /// language's voice (R6): kana → Japanese, Latin only → English, Han → the learning language
    /// (Japanese learners read kanji in Japanese, everyone else in Taiwan Mandarin).
    static func language(of text: String) -> String {
        let c = LanguageRules.counts(text)
        if c.kana > 0 { return "ja" }
        if c.han == 0, c.latin > 0 { return "en" }
        return NativeAPI.targetLanguage == "ja" ? "ja" : "zh-TW"
    }

    static func bcp47(_ lang: String) -> String {
        switch lang {
        case "en": "en-US"
        case "ja": "ja-JP"
        default: "zh-TW"
        }
    }

    private var levelMultiplier: Float {
        // Same values and default as the web (cw-sound-level: off / subtle / full, default subtle).
        switch UserDefaults.standard.string(forKey: "sound.level") ?? "subtle" {
        case "off": 0
        case "full": 0.8
        default: 0.45   // "subtle" (and the old iOS value "soft")
        }
    }

    /// 設定 › 効果音 is off (the sound level "off").
    var isMuted: Bool { levelMultiplier == 0 }

    func configure() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        for sfx in SFX.allCases { _ = player(for: sfx) }
    }

    func play(_ sfx: SFX, volume: Float = 1) {
        let level = levelMultiplier
        guard level > 0, let player = player(for: sfx) else { return }
        player.stop()
        player.currentTime = sfx.offset
        player.numberOfLoops = 0
        player.volume = min(1, sfx.gain * volume * level)
        player.play()
    }

    /// Plays `sfx` on a fresh player so it can overlap an earlier play of the same sound (the prototype's
    /// pops come 130 ms apart and each rings out). Same level rules as `play`.
    func playLayered(_ sfx: SFX, volume: Float = 1) {
        let level = levelMultiplier
        guard level > 0,
              let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: sfx.fileExtension),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        layered.removeAll { !$0.isPlaying }
        player.currentTime = sfx.offset
        player.volume = min(1, sfx.gain * volume * level)
        player.play()
        layered.append(player)
    }

    private var layered: [AVAudioPlayer] = []

    /// A page opening (dex, word detail, tab) or going back: the bubble pon plus its matching tap.
    /// The sound follows the sound level ("off" is silent); the tap follows the vibration switch.
    func pon(open: Bool) {
        play(open ? .ponOpen : .ponBack)
        Haptics.pon(open: open)
    }

    func startAnalyzeLoop() {
        let level = levelMultiplier
        guard level > 0, let player = player(for: .analyzeLoop) else { return }
        player.numberOfLoops = -1
        player.currentTime = 0
        player.volume = 0
        player.play()
        player.setVolume(min(1, SFX.analyzeLoop.gain * 0.5 * level), fadeDuration: 0.6)
    }

    func stopAnalyzeLoop() {
        guard let player = players[.analyzeLoop], player.isPlaying else { return }
        player.setVolume(0, fadeDuration: 0.3)
        Task {
            try? await Task.sleep(for: .milliseconds(320))
            player.stop()
        }
    }

    // MARK: - Pronunciation (the web's server voice)

    /// The same voice as the web (`synthesizeSpeech`: the developer-chosen TTS provider, cached in the
    /// `tts` bucket). Each text is fetched once and kept on the device, so repeats are instant and offline.
    /// Only when the server is slow (>2.5 s) or unreachable does the device voice speak instead —
    /// pressing the button must never be silent.
    private var voicePlayer: AVAudioPlayer?
    private var inflight: [String: Task<Data?, Never>] = [:]
    private var speakToken = 0

    private static let ttsDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("tts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func cacheURL(for text: String) -> URL {
        let key = text.unicodeScalars.reduce(into: UInt64(1469598103934665603)) { h, c in
            h = (h ^ UInt64(c.value)) &* 1099511628211
        }
        return ttsDir.appendingPathComponent("\(language(of: text))-\(String(key, radix: 16)).mp3")
    }

    /// Warm the cache (e.g. when candidates appear) so the first tap plays at once.
    func prefetch(_ text: String) {
        guard !text.isEmpty else { return }
        _ = audio(for: text)
    }

    private func audio(for text: String) -> Task<Data?, Never> {
        if let t = inflight[text] { return t }
        let file = Self.cacheURL(for: text)
        let task = Task<Data?, Never> {
            if let d = try? Data(contentsOf: file) { return d }
            struct Res: Decodable {
                let audioURL: String?
                let locked: Bool?
                enum CodingKeys: String, CodingKey { case locked, audioURL = "audio_url" }
            }
            guard let res = try? await NativeAPI.call(
                "synthesizeSpeech", ["text": String(text.prefix(400)), "language": Self.language(of: text)],
                as: Res.self, timeout: 20
            ), res.locked != true, let raw = res.audioURL else { return nil }
            let data: Data?
            if raw.hasPrefix("data:"), let comma = raw.firstIndex(of: ",") {
                data = Data(base64Encoded: String(raw[raw.index(after: comma)...]))
            } else if let url = URL(string: raw) {
                // Only a real answer is kept: an error page (expired link, 403) cached as the word's
                // audio would make that word silent for good.
                if let (body, response) = try? await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 20)),
                   (response as? HTTPURLResponse)?.statusCode == 200 {
                    data = body
                } else {
                    data = nil
                }
            } else {
                data = nil
            }
            if let data, !data.isEmpty { try? data.write(to: file, options: .atomic) }
            return data
        }
        inflight[text] = task
        Task {
            _ = await task.value
            inflight[text] = nil
        }
        return task
    }

    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        speakToken += 1
        let token = speakToken
        voicePlayer?.stop()
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let task = audio(for: text)
        Task {
            // Whichever comes first: the audio, or 2.5 s of waiting (then the device voice speaks,
            // and the fetch keeps going so the next tap is instant).
            let data: Data? = await withTaskGroup(of: Data?.self) { group in
                group.addTask { await task.value }
                group.addTask {
                    try? await Task.sleep(for: .milliseconds(2500))
                    return nil
                }
                let first: Data?? = await group.next()
                group.cancelAll()
                return first ?? nil
            }
            guard token == speakToken else { return }
            if let data, let player = try? AVAudioPlayer(data: data) {
                voicePlayer = player
                player.volume = 1
                player.play()
            } else {
                speakOnDevice(text)
            }
        }
    }

    /// Device voice fallback: always the text's own language's voice (never a "close" language).
    private func speakOnDevice(_ text: String) {
        guard let voice = voice(for: Self.language(of: text)) else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    private func player(for sfx: SFX) -> AVAudioPlayer? {
        if let existing = players[sfx] { return existing }
        guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: sfx.fileExtension),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[sfx] = player
        return player
    }

    private static func pickVoice(_ lang: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == lang }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
                return lhs.identifier < rhs.identifier
            }
        return voices.first ?? AVSpeechSynthesisVoice(language: lang)
    }
}

import AVFoundation

/// Recorded cinematic SFX from the web app (`public/sfx/el-*.mp3`) with the same per-file trims.
enum SFX: String, CaseIterable {
    case snap = "catch-snap"
    case impact = "el-catch-impact"
    case bookOpen = "el-book-open"
    case slide = "el-gallery-slide"
    case sting = "el-celebrate-sting"
    case analyzeLoop = "el-analyze-loop"

    var gain: Float {
        switch self {
        case .snap: 1.0
        case .impact: 1.4
        case .bookOpen: 1.6
        case .slide: 1.2
        case .sting: 1.1
        case .analyzeLoop: 0.9
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
    private lazy var voice: AVSpeechSynthesisVoice? = Self.pickVoice()

    private var levelMultiplier: Float {
        switch UserDefaults.standard.string(forKey: "sound.level") ?? "full" {
        case "off": 0
        case "soft": 0.45
        default: 0.8
        }
    }

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
        return ttsDir.appendingPathComponent("\(NativeAPI.targetLanguage)-\(String(key, radix: 16)).mp3")
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
                "synthesizeSpeech", ["text": String(text.prefix(400)), "language": NativeAPI.targetLanguage],
                as: Res.self, timeout: 20
            ), res.locked != true, let raw = res.audioURL else { return nil }
            let data: Data?
            if raw.hasPrefix("data:"), let comma = raw.firstIndex(of: ",") {
                data = Data(base64Encoded: String(raw[raw.index(after: comma)...]))
            } else if let url = URL(string: raw) {
                data = try? await URLSession.shared.data(from: url).0
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

    /// Device voice fallback: always the same zh-TW voice (never a "close" language).
    private func speakOnDevice(_ text: String) {
        guard let voice else { return }
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = 0.42
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    private func player(for sfx: SFX) -> AVAudioPlayer? {
        if let existing = players[sfx] { return existing }
        guard let url = Bundle.main.url(forResource: sfx.rawValue, withExtension: "mp3"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        players[sfx] = player
        return player
    }

    private static func pickVoice() -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "zh-TW" }
            .sorted { lhs, rhs in
                if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
                return lhs.identifier < rhs.identifier
            }
        return voices.first ?? AVSpeechSynthesisVoice(language: "zh-TW")
    }
}

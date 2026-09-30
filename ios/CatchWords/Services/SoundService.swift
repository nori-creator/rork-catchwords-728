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

    /// Always the same zh-TW voice for the same device (never falls back to a "close" language).
    func speak(_ text: String) {
        guard !text.isEmpty, let voice else { return }
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

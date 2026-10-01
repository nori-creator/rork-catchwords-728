import AVFoundation
import Speech
import UIKit

/// The single speech-recognition component (web had 3 separate SpeechRecognition copies that never
/// worked in the iOS WebView). Language always comes from the learning language, never hard-coded.
/// Recording and recognition share one audio engine so they never fight over the mic.
@Observable
final class SpeechService {
    enum State: Equatable { case idle, listening, denied, unavailable }

    var state: State = .idle
    var transcript: String = ""

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTask: Task<Void, Never>?
    private var onFinal: ((String) -> Void)?

    /// Learning language → recognizer locale (zh-TW for Taiwan Mandarin, en-US for English).
    var localeIdentifier: String { NativeAPI.speechLanguage }

    var isListening: Bool { state == .listening }

    func toggle(onFinal: @escaping (String) -> Void) {
        if isListening { stop(deliver: true) } else { Task { await start(onFinal: onFinal) } }
    }

    func start(onFinal: @escaping (String) -> Void) async {
        guard !isListening else { return }
        self.onFinal = onFinal
        guard await Self.authorize() else { state = .denied; return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)), recognizer.isAvailable else {
            state = .unavailable
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers, .defaultToSpeaker])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .unavailable
            return
        }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = false }
        request = req
        transcript = ""

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { state = .unavailable; restorePlayback(); return }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
            req?.append(buffer)
        }
        engine.prepare()
        do { try engine.start() } catch {
            input.removeTap(onBus: 0)
            state = .unavailable
            restorePlayback()
            return
        }
        state = .listening
        Haptics.impact(.light)
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal ?? false
            Task { @MainActor in
                guard let self else { return }
                if let text { self.transcript = text; self.armSilence() }
                if isFinal || error != nil { self.stop(deliver: true) }
            }
        }
        armSilence(first: true)
    }

    /// Stops ~1.4s after the last partial result (4s max wait for the first word).
    private func armSilence(first: Bool = false) {
        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(first ? 4 : 1.4))
            guard !Task.isCancelled else { return }
            self?.stop(deliver: true)
        }
    }

    func stop(deliver: Bool) {
        guard isListening else { return }
        silenceTask?.cancel()
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        state = .idle
        restorePlayback()
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if deliver, !text.isEmpty { onFinal?(text) }
        onFinal = nil
    }

    private func restorePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private static func authorize() async -> Bool {
        let speech: Bool = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

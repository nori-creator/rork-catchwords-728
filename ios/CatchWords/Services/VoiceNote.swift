import AVFoundation
import SwiftUI

/// The spoken one-line note of a catch (web VoiceCaptionButton + voice-note.ts): up to 15 s of audio,
/// recorded on the card and uploaded only after the sticker is saved, so saving is never slower.
@Observable
final class VoiceNoteRecorder: NSObject, AVAudioRecorderDelegate {
    /// web MAX_VOICE_NOTE_MS
    static let maxSeconds: Double = 15

    var isRecording: Bool = false
    var secondsLeft: Int = Int(maxSeconds)
    /// The finished recording (m4a), nil until one is made.
    var fileURL: URL?
    var message: String?

    private var recorder: AVAudioRecorder?
    private var ticker: Task<Void, Never>?

    func start() async {
        message = nil
        let granted = await AVAudioApplication.requestRecordPermission()
        guard granted else {
            message = L("マイクを使えませんでした")
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers])
            try session.setActive(true)
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            guard r.record(forDuration: Self.maxSeconds) else { throw APIError.decoding }
            recorder = r
            fileURL = nil
            isRecording = true
            secondsLeft = Int(Self.maxSeconds)
            Haptics.impact(.light)
            ticker = Task { [weak self] in
                while let self, self.isRecording, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(250))
                    let t = self.recorder?.currentTime ?? 0
                    self.secondsLeft = max(0, Int((Self.maxSeconds - t).rounded(.up)))
                }
            }
        } catch {
            message = L("この端末では録音できません")
            restoreSession()
        }
    }

    func stop() {
        recorder?.stop()
    }

    func discard() {
        recorder?.stop()
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
        isRecording = false
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let url = recorder.url
        Task { @MainActor in
            self.isRecording = false
            self.ticker?.cancel()
            self.fileURL = flag ? url : nil
            if flag { Haptics.success() }
            self.restoreSession()
        }
    }

    private func restoreSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
    }
}

/// The mic button beside the one-line note (web: 「文字入力の隣にボタン」).
struct VoiceNoteButton: View {
    let recorder: VoiceNoteRecorder
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if recorder.isRecording {
                Button { recorder.stop() } label: {
                    Label(L("止める（あと\(recorder.secondsLeft)秒）"), systemImage: "stop.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.destructive)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.destructive.opacity(0.1), in: Capsule())
                }
                .buttonStyle(PressableStyle())
            } else if recorder.fileURL != nil {
                Label(L("録れました"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.ok)
                Button { recorder.discard() } label: {
                    Image(systemName: "trash").font(.system(size: 15)).foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel(L("録った一言を捨てる"))
            } else {
                Button { Task { await recorder.start() } } label: {
                    Label(L("声で一言を残す"), systemImage: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primaryInk)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(Theme.primary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(disabled)
            }
            Spacer(minLength: 0)
        }
        if let m = recorder.message {
            Text(m).font(.system(size: 12)).foregroundStyle(Theme.destructive)
        }
    }
}

/// Plays a saved voice note (web: the note's play button in the when / where row).
@Observable
final class VoiceNotePlayer {
    var isPlaying: Bool = false
    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?

    func toggle(url: URL) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        let item = AVPlayerItem(url: url)
        let p = AVPlayer(playerItem: item)
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
        player = p
        p.play()
        isPlaying = true
    }
}

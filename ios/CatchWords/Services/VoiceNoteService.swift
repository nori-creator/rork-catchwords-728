import AVFoundation
import SwiftUI

/// The spoken one-liner kept with a catch (web voice-note.ts / VoiceCaptionButton).
///
/// Same limits as the web: at most 15 seconds, one recording per word (re-recording replaces it),
/// stored at `{user}/{sticker}/voice.mp4` in the `stickers` bucket and linked with
/// `setStickerVoiceVideo`. Recording never slows the save down — the upload happens after it.
@Observable
final class VoiceNoteRecorder: NSObject, AVAudioRecorderDelegate {
    static let maxSeconds: Double = 15

    enum State: Equatable { case idle, recording, recorded }

    private(set) var state: State = .idle
    private(set) var elapsed: Double = 0
    /// Recent input levels (0…1), newest last — drawn as a live waveform while recording.
    private(set) var levels: [CGFloat] = Array(repeating: 0, count: 28)
    private(set) var denied = false
    private(set) var fileURL: URL?

    private var recorder: AVAudioRecorder?
    private var meterTask: Task<Void, Never>?

    var remaining: Int { max(0, Int((Self.maxSeconds - elapsed).rounded(.up))) }

    func toggle() {
        switch state {
        case .recording: stop()
        default: Task { await start() }
        }
    }

    func start() async {
        guard await AVAudioApplication.requestRecordPermission() else {
            denied = true
            Haptics.warning()
            return
        }
        denied = false
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? session.setActive(true)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        guard let rec = try? AVAudioRecorder(url: url, settings: settings) else { return }
        rec.delegate = self
        rec.isMeteringEnabled = true
        guard rec.record(forDuration: Self.maxSeconds) else { return }
        discardFile()
        recorder = rec
        fileURL = url
        elapsed = 0
        levels = Array(repeating: 0, count: levels.count)
        Haptics.impact(.medium)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { state = .recording }
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let r = self.recorder, r.isRecording else { break }
                r.updateMeters()
                // -50 dB (quiet room) … 0 dB (loud) → 0…1, eased so speech fills the bar.
                let db = CGFloat(r.averagePower(forChannel: 0))
                let level = pow(max(0, min(1, (db + 50) / 50)), 1.6)
                self.levels.removeFirst()
                self.levels.append(level)
                self.elapsed = r.currentTime
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    func stop() {
        recorder?.stop()
    }

    func discard() {
        recorder?.stop()
        recorder = nil
        discardFile()
        withAnimation(.snappy) { state = .idle }
    }

    /// A copy of the finished recording that the save owns (and deletes after uploading), so
    /// resetting the card for the next catch can never pull the file out from under the upload.
    func detachedCopy() -> URL? {
        guard state == .recorded, let url = fileURL else { return nil }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("voice-save-\(UUID().uuidString).m4a")
        return (try? FileManager.default.copyItem(at: url, to: copy)) != nil ? copy : nil
    }

    private func discardFile() {
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
        fileURL = nil
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            self.meterTask?.cancel()
            self.recorder = nil
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            // Anything under half a second is a slip of the finger, not a note.
            guard flag, self.elapsed >= 0.5 else {
                self.discard()
                return
            }
            Haptics.success()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { self.state = .recorded }
        }
    }
}

/// Plays a recorded note — a local file right after recording, or the saved one from storage.
@Observable
final class VoiceNotePlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var progress: Double = 0
    private(set) var duration: Double = 0
    private var player: AVAudioPlayer?
    private var tick: Task<Void, Never>?

    func toggle(local: URL? = nil, remote: URL? = nil) {
        if isPlaying { stop(); return }
        Task { await play(local: local, remote: remote) }
    }

    func play(local: URL?, remote: URL?) async {
        var data: Data?
        if let local { data = try? Data(contentsOf: local) }
        if data == nil, let remote {
            isLoading = true
            data = try? await URLSession.shared.data(from: remote).0
            isLoading = false
        }
        guard let data, let p = try? AVAudioPlayer(data: data) else {
            Haptics.warning()
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        p.delegate = self
        p.prepareToPlay()
        player = p
        duration = p.duration
        progress = 0
        p.play()
        isPlaying = true
        tick?.cancel()
        tick = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let p = self.player, p.isPlaying else { break }
                self.progress = p.duration > 0 ? p.currentTime / p.duration : 0
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    func stop() {
        player?.stop()
        finish()
    }

    private func finish() {
        tick?.cancel()
        isPlaying = false
        withAnimation(.easeOut(duration: 0.25)) { progress = 0 }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish() }
    }
}

/// The mic next to the one-line memo on the catch card (web VoiceCaptionButton): tap to record,
/// tap again (or 15 s) to stop; then listen, record again or throw it away.
struct VoiceNoteButton: View {
    @Bindable var recorder: VoiceNoteRecorder
    @State private var player = VoiceNotePlayer()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 10) {
            switch recorder.state {
            case .idle:
                Button { recorder.toggle() } label: {
                    Label(L("声で一言を残す"), systemImage: "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 40)
                        .background(Theme.primary.opacity(0.1), in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            case .recording:
                Button { recorder.stop() } label: {
                    HStack(spacing: 10) {
                        Circle().fill(.white).frame(width: 9, height: 9)
                            .opacity(reduceMotion ? 1 : (Int(recorder.elapsed * 2) % 2 == 0 ? 1 : 0.35))
                        Waveform(levels: recorder.levels, color: .white)
                            .frame(width: 96, height: 22)
                        Text(L("止める（あと\(recorder.remaining)秒）"))
                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Color(hex: 0xE5484D), in: Capsule())
                    .shadow(color: Color(hex: 0xE5484D).opacity(0.35), radius: 10, y: 4)
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(L("録音中。タップで止める"))
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            case .recorded:
                Button { player.toggle(local: recorder.fileURL) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                            .contentTransition(.symbolEffect(.replace))
                        Text(player.isPlaying ? L("一言を止める") : L("録れました"))
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.foreground)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(alignment: .leading) {
                        GeometryReader { g in
                            Theme.primary.opacity(0.14).frame(width: g.size.width * player.progress)
                        }
                    }
                    .background(Theme.card, in: Capsule())
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                Button { player.stop(); recorder.toggle() } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 40, height: 40)
                        .background(Theme.card, in: Circle())
                        .overlay(Circle().stroke(Theme.border, lineWidth: 1))
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                .accessibilityLabel(L("録り直す"))
                Button { player.stop(); recorder.discard() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(PressableStyle(scale: 0.9))
                .accessibilityLabel(L("録った一言を捨てる"))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.foreground)
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: recorder.state)
        .overlay(alignment: .bottomLeading) {
            if recorder.denied {
                Text(L("設定アプリでマイクを許可すると録音できます。"))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .offset(y: 18)
            }
        }
    }
}

/// The saved note on the word's page (web VoiceNotePlayer).
struct VoiceNoteRow: View {
    let url: URL?
    @State private var player = VoiceNotePlayer()

    var body: some View {
        Button { player.toggle(remote: url) } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(Theme.primary).frame(width: 38, height: 38)
                    if player.isLoading {
                        ProgressView().tint(.white).controlSize(.small)
                    } else {
                        Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.isPlaying ? L("一言を止める") : L("一言を聞く"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                    GeometryReader { g in
                        Capsule().fill(Theme.border)
                            .overlay(alignment: .leading) {
                                Capsule().fill(Theme.primary).frame(width: max(4, g.size.width * player.progress))
                            }
                    }
                    .frame(height: 4)
                }
                Image(systemName: "waveform")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.primary.opacity(0.6))
                    .symbolEffect(.variableColor.iterative, isActive: player.isPlaying)
            }
            .padding(12)
            .background(Theme.card, in: .rect(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableStyle())
        .disabled(url == nil)
        .accessibilityLabel(L("一言の録音を聞く"))
    }
}

/// Live input level bars, newest on the right.
private struct Waveform: View {
    let levels: [CGFloat]
    let color: Color

    var body: some View {
        GeometryReader { g in
            let n = max(1, levels.count)
            let w = g.size.width / CGFloat(n)
            HStack(alignment: .center, spacing: 0) {
                ForEach(levels.indices, id: \.self) { i in
                    Capsule()
                        .fill(color.opacity(0.55 + 0.45 * Double(i) / Double(n)))
                        .frame(width: max(1.5, w * 0.55), height: max(3, g.size.height * levels[i]))
                        .frame(width: w)
                }
            }
            .frame(height: g.size.height)
            .animation(.linear(duration: 0.06), value: levels)
        }
    }
}

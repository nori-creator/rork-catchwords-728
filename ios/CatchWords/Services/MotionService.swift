import CoreMotion
import Observation
import UIKit

/// How the phone is tilted, for the holographic cards (`Holographic.swift`): one shared `CMMotionManager`
/// read at 60 Hz, smoothed, and turned into a tilt vector in -1...1 (x = roll left/right, y = pitch
/// toward/away from you).
///
/// It only runs while a holo card is on screen: views call `acquire()` / `release()` and the sensor stops
/// shortly after the last one goes. With Reduce Motion on, or where there is no device motion (the
/// simulator), it never starts and `tilt` stays zero — the cards then fall back to finger-drag tilt.
@MainActor @Observable
final class MotionService {
    static let shared = MotionService()

    /// -1...1 on both axes; zero while stopped.
    private(set) var tilt: CGPoint = .zero
    /// True once real samples are arriving (false on the simulator, with Reduce Motion, or while stopped).
    private(set) var isLive = false

    private let manager = CMMotionManager()
    @ObservationIgnored private var users = 0
    @ObservationIgnored private var stopTask: Task<Void, Never>?
    /// The resting posture the tilt is measured from; it drifts slowly toward how the phone is held, so
    /// lying on a sofa or standing both rest at zero.
    @ObservationIgnored private var reference: (pitch: Double, roll: Double)?
    @ObservationIgnored private var smoothed: (x: Double, y: Double) = (0, 0)
    @ObservationIgnored private var reduceMotionObserver: NSObjectProtocol?

    /// Angle (radians, ≈ 20°) away from the resting posture that reads as a full tilt of 1.
    private static let fullTilt = 0.35
    /// Low-pass factor per sample (60 Hz): ≈ 90 ms to settle, so the foil glides instead of shaking.
    private static let smoothing = 0.18
    /// How fast the resting posture follows the phone (per sample): ≈ 2 s.
    private static let recenter = 0.008

    var isAvailable: Bool { manager.isDeviceMotionAvailable }

    private init() {
        reduceMotionObserver = NotificationCenter.default.addObserver(
            forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reduceMotionChanged() }
        }
    }

    /// A holo card came on screen.
    func acquire() {
        users += 1
        stopTask?.cancel()
        stopTask = nil
        startIfNeeded()
    }

    /// A holo card left the screen. The sensor stops a moment later, so handing the foil from one card to
    /// the next (the carousel) doesn't restart it.
    func release() {
        users = max(0, users - 1)
        guard users == 0, stopTask == nil else { return }
        stopTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            self?.stopTask = nil
            if self?.users == 0 { self?.stopNow() }
        }
    }

    private func startIfNeeded() {
        guard users > 0, !manager.isDeviceMotionActive,
              manager.isDeviceMotionAvailable, !UIAccessibility.isReduceMotionEnabled else { return }
        reference = nil
        smoothed = (0, 0)
        manager.deviceMotionUpdateInterval = 1.0 / 60
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let g = motion?.gravity else { return }
            let gx = g.x, gy = g.y, gz = g.z
            MainActor.assumeIsolated { self?.ingest(gx: gx, gy: gy, gz: gz) }
        }
    }

    private func stopNow() {
        if manager.isDeviceMotionActive { manager.stopDeviceMotionUpdates() }
        reference = nil
        smoothed = (0, 0)
        if tilt != .zero { tilt = .zero }
        if isLive { isLive = false }
    }

    private func reduceMotionChanged() {
        if UIAccessibility.isReduceMotionEnabled { stopNow() } else { startIfNeeded() }
    }

    /// Pitch / roll from gravity (steady whether the phone is flat or upright, unlike Euler angles), measured
    /// from the drifting resting posture, then low-passed.
    private func ingest(gx: Double, gy: Double, gz: Double) {
        let pitch = atan2(gy, -gz)
        let roll = asin(max(-1, min(1, gx)))
        guard var ref = reference else {
            reference = (pitch, roll)
            if !isLive { isLive = true }
            return
        }
        ref.pitch += Self.wrap(pitch - ref.pitch) * Self.recenter
        ref.roll += (roll - ref.roll) * Self.recenter
        reference = ref

        let rawX = max(-1, min(1, (roll - ref.roll) / Self.fullTilt))
        let rawY = max(-1, min(1, Self.wrap(pitch - ref.pitch) / Self.fullTilt))
        smoothed.x += (rawX - smoothed.x) * Self.smoothing
        smoothed.y += (rawY - smoothed.y) * Self.smoothing

        // Only publish a change you could see, so a phone lying still doesn't redraw the card 60 times a second.
        let next = CGPoint(x: smoothed.x, y: smoothed.y)
        if abs(next.x - tilt.x) > 0.002 || abs(next.y - tilt.y) > 0.002 { tilt = next }
    }

    /// An angle difference folded into -π...π.
    private static func wrap(_ a: Double) -> Double {
        var x = a
        while x > .pi { x -= 2 * .pi }
        while x < -.pi { x += 2 * .pi }
        return x
    }
}

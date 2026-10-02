import CoreLocation
import CoreMotion
import Foundation
import Observation

/// 「ここで撮った思い出」: while the camera screen is open, knows where the phone is, which way the back
/// camera faces (compass) and how far it is tilted up or down (Core Motion), and which caught words
/// were photographed within `radius` of here — with the bearing and distance to each.
///
/// Accuracy, honestly: GPS is ±5–20 m outdoors (worse indoors and between tall buildings) and the
/// compass is ±10–20° (worse near steel, magnets and cars, until the user moves the phone around).
/// A sticker stores only WHERE it was taken, not which way the camera faced, so a card floats in the
/// direction of that spot, not on the object itself. Memories closer than the GPS error have no
/// meaningful direction: they are pinned in front of the camera the first time the compass is known
/// and then stay put in the world as the user pans.
///
/// Owns its own CLLocationManager (LocationService is a one-shot lookup with its own delegate) and its
/// own CMMotionManager (independent of any other motion user in the app).
@Observable
final class MemoryLensService: NSObject, CLLocationManagerDelegate {
    nonisolated struct Memory: Identifiable, Equatable {
        let sticker: Sticker
        /// Metres from here.
        let distance: Double
        /// Degrees clockwise from north.
        let bearing: Double
        /// Inside the GPS error: `bearing` is an anchor in front of the camera, not a measurement.
        let isHere: Bool
        var id: String { sticker.id }
    }

    /// Search radius around the current position (m).
    var radius: Double = 60
    /// At most this many cards (closest first), so the preview never fills up.
    var maxCount = 12

    /// Memories within `radius`, closest first.
    private(set) var nearby: [Memory] = []
    /// Smoothed compass heading of the back camera, degrees from true north (magnetic when true north
    /// is unknown). nil until the compass reports, or on devices without one.
    private(set) var heading: Double?
    /// Smoothed camera elevation: radians above (+) / below (−) the horizon.
    private(set) var pitch: Double = 0
    /// Smoothed clockwise tilt of the phone around the screen's normal (radians), so the horizon can
    /// stay level on screen.
    private(set) var roll: Double = 0

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let motion = CMMotionManager()
    @ObservationIgnored private var location: CLLocation?
    @ObservationIgnored private var accuracy: Double = 10
    @ObservationIgnored private var stickers: [Sticker] = []
    /// sticker id → the bearing a "right here" memory was pinned at.
    @ObservationIgnored private var anchors: [String: Double] = [:]
    /// Heading low-pass state as a unit vector (sin, cos), so 359° → 1° never swings through 180°.
    @ObservationIgnored private var headingVector: (x: Double, y: Double)?
    @ObservationIgnored private var running = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        // Every change is delivered and smoothed here (a 1° filter makes the cards step visibly).
        manager.headingFilter = kCLHeadingFilterNone
        manager.headingOrientation = .portrait
    }

    // MARK: Lifecycle

    func start() {
        guard !running else { return }
        running = true
        startLocationIfAllowed()
        startMotion()
    }

    func stop() {
        guard running else { return }
        running = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        motion.stopDeviceMotionUpdates()
        headingVector = nil
        heading = nil
        anchors = [:]
    }

    /// The dex to search (call again whenever it changes).
    func setStickers(_ list: [Sticker]) {
        stickers = list
        recompute()
    }

    private func startLocationIfAllowed() {
        let status = manager.authorizationStatus
        guard running, status == .authorizedWhenInUse || status == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { manager.startUpdatingHeading() }
    }

    /// Pitch and roll come from the gravity vector, which is the same in every reference frame, so the
    /// cheapest frame (no magnetometer) is enough.
    private func startMotion() {
        guard motion.isDeviceMotionAvailable, !motion.isDeviceMotionActive else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: OperationQueue.main) { [weak self] data, _ in
            guard let g = data?.gravity else { return }
            let gx = g.x, gy = g.y, gz = g.z
            // Delivered on the main queue (above), so this is already the main actor.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.applyGravity(x: gx, y: gy, z: gz)
            }
        }
    }

    // MARK: Sensors

    /// Device frame: x right, y toward the top of the screen, z out of the screen toward the user; the
    /// back camera looks along −z. Upright portrait: gravity ≈ (0, −1, 0) → pitch 0. Flat, screen up:
    /// gravity ≈ (0, 0, −1) → pitch −90° (camera looking at the floor).
    private func applyGravity(x: Double, y: Double, z: Double) {
        let n = (x * x + y * y + z * z).squareRoot()
        guard n > 0.1 else { return }
        let alpha = 0.15
        let newPitch = asin(max(-1, min(1, z / n)))
        let nextPitch = pitch + (newPitch - pitch) * alpha
        if abs(nextPitch - pitch) > 0.0005 { pitch = nextPitch }
        // Roll is meaningless when the phone lies (nearly) flat; keep the last value then.
        guard abs(z / n) < 0.9 else { return }
        let newRoll = atan2(x, -y)
        let delta = (newRoll - roll).remainder(dividingBy: 2 * .pi)
        if abs(delta * alpha) > 0.0005 { roll = (roll + delta * alpha).remainder(dividingBy: 2 * .pi) }
    }

    /// Core Location reports the heading of the back camera when the phone is held upright (as the
    /// Compass app does); true north needs a location fix, otherwise magnetic north is used.
    private func applyHeading(trueDegrees: Double, magneticDegrees: Double, accuracy: Double) {
        guard accuracy >= 0 else { return }  // negative = invalid reading
        let deg = trueDegrees >= 0 ? trueDegrees : magneticDegrees
        guard deg >= 0 else { return }
        let rad = deg * .pi / 180
        let target = (x: sin(rad), y: cos(rad))
        let alpha = 0.2
        let v: (x: Double, y: Double)
        if let old = headingVector {
            v = (old.x + (target.x - old.x) * alpha, old.y + (target.y - old.y) * alpha)
        } else {
            v = target
        }
        headingVector = v
        var smoothed = atan2(v.x, v.y) * 180 / .pi
        if smoothed < 0 { smoothed += 360 }
        let first = heading == nil
        if first || abs(Self.relativeAngle(smoothed, heading ?? smoothed)) > 0.1 { heading = smoothed }
        // "Right here" memories get their anchor once the compass is known.
        if first { recompute() }
    }

    private func applyLocation(latitude: Double, longitude: Double, accuracy acc: Double) {
        // Negative = invalid; beyond 100 m the fix says nothing about a 60 m circle.
        guard acc >= 0, acc <= 100 else { return }
        location = CLLocation(latitude: latitude, longitude: longitude)
        accuracy = acc
        recompute()
    }

    // MARK: Nearby memories

    private func recompute() {
        guard let here = location else {
            if !nearby.isEmpty { nearby = [] }
            return
        }
        // Closer than this, the bearing is noise (the fix itself wanders by about this much).
        let hereRadius = max(8, min(accuracy, 30))
        var found: [(sticker: Sticker, distance: Double, there: CLLocation)] = []
        for s in stickers {
            // Only the learner's own picture (a cut-out or the photo), never a stand-in image.
            guard let lat = s.lat, let lng = s.lng, s.cutoutImageUrl != nil || s.objectImageUrl != nil else { continue }
            let there = CLLocation(latitude: lat, longitude: lng)
            let d = here.distance(from: there)
            if d <= radius { found.append((sticker: s, distance: d, there: there)) }
        }
        found.sort { $0.distance < $1.distance }
        var out: [Memory] = []
        for f in found.prefix(maxCount) {
            if f.distance < hereRadius {
                out.append(Memory(sticker: f.sticker, distance: f.distance, bearing: anchor(for: f.sticker.id), isHere: true))
            } else {
                out.append(Memory(sticker: f.sticker, distance: f.distance,
                                  bearing: Self.bearing(from: here.coordinate, to: f.there.coordinate), isHere: false))
            }
        }
        if out != nearby { nearby = out }
    }

    /// A "right here" memory's bearing: fanned out around where the camera faced when it first appeared
    /// (0°, −14°, +14°, −28° …), then kept, so it stays put in the world while the user pans.
    private func anchor(for id: String) -> Double {
        if let a = anchors[id] { return a }
        guard let heading else { return 0 }  // placed in a row until the compass is known
        let i = anchors.count
        let step = Double((i + 1) / 2) * 14 * (i % 2 == 0 ? 1 : -1)
        let a = (heading + step + 360).truncatingRemainder(dividingBy: 360)
        anchors[id] = a
        return a
    }

    /// Initial great-circle bearing from `a` to `b`, degrees clockwise from north (0–360).
    static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLng = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLng) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }

    /// `angle` relative to `reference`, in −180..<180 (negative = to the left).
    static func relativeAngle(_ angle: Double, _ reference: Double) -> Double {
        let d = (angle - reference + 540).truncatingRemainder(dividingBy: 360)
        return (d < 0 ? d + 360 : d) - 180
    }

    // MARK: CLLocationManagerDelegate (called on the main thread; values are copied before the hop)

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in self.startLocationIfAllowed() }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        let lat = last.coordinate.latitude, lng = last.coordinate.longitude, acc = last.horizontalAccuracy
        Task { @MainActor in self.applyLocation(latitude: lat, longitude: lng, accuracy: acc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let t = newHeading.trueHeading, m = newHeading.magneticHeading, acc = newHeading.headingAccuracy
        Task { @MainActor in self.applyHeading(trueDegrees: t, magneticDegrees: m, accuracy: acc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

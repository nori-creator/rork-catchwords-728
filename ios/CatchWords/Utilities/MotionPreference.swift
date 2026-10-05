import SwiftUI
import UIKit

/// 設定 › アニメーション, the one place that decides whether the app moves less (R6-04):
/// - 自動 ("system", the default): follows the iPhone's Reduce Motion.
/// - 見せる ("full"): always the full motion, even with Reduce Motion on.
/// - 減らす ("reduce"): always reduced, even with Reduce Motion off.
///
/// Views never read `accessibilityReduceMotion` themselves: they read `\.appReduceMotion`, which the root
/// (`appMotionPreference()`) sets from this choice and the iPhone's setting. Code outside the view tree
/// (the motion sensor) asks `reducesNow`.
enum MotionPreference {
    static let key = "motion.pref"
    static let system = "system"
    static let full = "full"
    static let reduce = "reduce"
    static let defaultValue = system

    /// Whether motion is reduced for this choice and the iPhone's Reduce Motion.
    static func reduces(pref: String, systemReduce: Bool) -> Bool {
        switch pref {
        case full: false
        case reduce: true
        default: systemReduce
        }
    }

    /// The saved choice and the iPhone's setting right now (for code outside SwiftUI views).
    static var reducesNow: Bool {
        reduces(pref: UserDefaults.standard.string(forKey: key) ?? defaultValue,
                systemReduce: UIAccessibility.isReduceMotionEnabled)
    }
}

nonisolated private struct AppReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True when the app should move less (設定 › アニメーション with the iPhone's Reduce Motion).
    /// Read this instead of `accessibilityReduceMotion`.
    nonisolated var appReduceMotion: Bool {
        get { self[AppReduceMotionKey.self] }
        set { self[AppReduceMotionKey.self] = newValue }
    }
}

extension View {
    /// At the root: works out `\.appReduceMotion` for every screen below, and with reduced motion also
    /// stops the animations that don't ask (springs, slides, repeating pulses).
    func appMotionPreference() -> some View { modifier(AppMotionPreferenceModifier()) }
}

private struct AppMotionPreferenceModifier: ViewModifier {
    @AppStorage(MotionPreference.key) private var pref: String = MotionPreference.defaultValue
    @Environment(\.accessibilityReduceMotion) private var systemReduce

    func body(content: Content) -> some View {
        let reduce = MotionPreference.reduces(pref: pref, systemReduce: systemReduce)
        return content
            .environment(\.appReduceMotion, reduce)
            .transaction { t in if reduce { t.disablesAnimations = true } }
    }
}

import UIKit

/// The UI tests' trace (DEBUG builds launched with `-uiDemo` only; a no-op everywhere else): one line per touch the
/// app's windows receive and per step of the catch, in the app's caches (`uitest-trace.txt`). CI publishes it next
/// to the tour's screenshots, so a tap that did nothing on CI can be followed after the fact — where the touch
/// landed, which gestures took it, and what the words screen did with it.
nonisolated enum UITestTrace {
    static func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        guard DemoBackend.isOn else { return }
        Writer.shared.append(message())
        #endif
    }

    /// At launch: a header naming the run, and the touch log.
    @MainActor
    static func start() {
        #if DEBUG
        guard DemoBackend.isOn else { return }
        let d = UserDefaults.standard
        log("launch uiDemo=\(d.string(forKey: "uiDemo") ?? "-") lang=\(d.string(forKey: "ui.lang") ?? "-")")
        UIWindow.traceTouches()
        #endif
    }

    #if DEBUG
    /// Appends off the main thread, in order.
    nonisolated private final class Writer: @unchecked Sendable {
        static let shared = Writer()
        private let queue = DispatchQueue(label: "app.catchwords.uitest-trace")
        private let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("uitest-trace.txt")
        private let clock: DateFormatter = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "UTC")
            f.dateFormat = "HH:mm:ss.SSS"
            return f
        }()

        func append(_ message: String) {
            let now = Date()
            queue.async { [self] in
                let line = clock.string(from: now) + " " + message + "\n"
                guard let data = line.data(using: .utf8) else { return }
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                } else {
                    try? data.write(to: url)
                }
            }
        }
    }
    #endif
}

#if DEBUG
extension UIWindow {
    /// Every window's `sendEvent` logs its touches as they begin and end — before UIKit handles them (where the touch
    /// landed) and after (what each gesture recognizer made of it). Only reads; the event goes on unchanged.
    static func traceTouches() {
        guard let original = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.sendEvent(_:))),
              let traced = class_getInstanceMethod(UIWindow.self, #selector(UIWindow.cw_traceSendEvent(_:))) else { return }
        method_exchangeImplementations(original, traced)
    }

    /// `dynamic`: the call inside goes through the runtime, so after the exchange it reaches the original.
    @objc private dynamic func cw_traceSendEvent(_ event: UIEvent) {
        traceTouches(of: event, after: false)
        cw_traceSendEvent(event)   // the original sendEvent (exchanged)
        traceTouches(of: event, after: true)
    }

    private func traceTouches(of event: UIEvent, after: Bool) {
        guard event.type == .touches, let touches = event.allTouches else { return }
        for t in touches {
            let phase: String
            switch t.phase {
            case .began: phase = "began"
            case .ended: phase = "ended"
            case .cancelled: phase = "cancelled"
            default: continue
            }
            // Before: where it landed. After: the recognizers' states (0 possible, 3 recognized, 4 cancelled, 5 failed).
            if !after && t.phase != .began { continue }
            let p = t.location(in: self)
            let view = t.view.map { String(describing: type(of: $0)) } ?? "nil"
            let recognizers = (t.gestureRecognizers ?? []).map { r in
                "\(type(of: r))\(r.name.map { "(\($0))" } ?? "")#\(r.state.rawValue)\(r.isEnabled ? "" : "-off")"
            }
            var line = "touch \(phase)\(after ? " handled" : "") @\(Int(p.x)),\(Int(p.y)) window=\(type(of: self))"
            line += " level=\(Int(windowLevel.rawValue)) key=\(isKeyWindow) view=\(view)"
            line += " recognizers=[\(recognizers.joined(separator: " "))]"
            // As a touch begins: every window of the scene (class:level, h = hidden, n = no touches) and the app's state.
            if t.phase == .began, !after, let ws = windowScene {
                let list = ws.windows.map { w in
                    "\(type(of: w)):\(Int(w.windowLevel.rawValue))\(w.isHidden ? "h" : "")\(w.isUserInteractionEnabled ? "" : "n")"
                }
                line += " windows=[\(list.joined(separator: " "))] app=\(UIApplication.shared.applicationState.rawValue)"
            }
            UITestTrace.log(line)
        }
    }
}
#endif

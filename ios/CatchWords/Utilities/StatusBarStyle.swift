import SwiftUI
import UIKit

/// Status-bar text colour per screen. SwiftUI has no status-bar-style modifier and the app's root
/// hosting controller belongs to SwiftUI, so the style is owned by a transparent window that sits
/// one level above the app's window: the topmost visible window's root view controller decides the
/// status bar's appearance. The window never takes touches (user interaction off → hit-testing falls
/// through to the app's window), never becomes key and has no accessibility elements.
enum StatusBarTone: Equatable {
    /// White text: dark full-screen views (camera, scan, analysing, reward, the memorial reveal).
    case light
    /// Dark text: screens that stay paper-coloured even in the dark theme (home, onboarding, month book).
    case dark
    /// Follows the app's colour scheme.
    case automatic
    /// No status bar (the system camera, which draws its own controls there).
    case hidden
}

@MainActor
final class StatusBarController {
    static let shared = StatusBarController()

    private var window: UIWindow?
    private let host = StatusBarHostController()
    /// Screens on screen now, in the order they appeared: the last one is on top and wins.
    private var requests: [(id: UUID, tone: StatusBarTone)] = []

    /// The app's effective colour scheme (theme setting), reported by RootView.
    var baseScheme: ColorScheme = .light {
        didSet { if oldValue != baseScheme { update() } }
    }

    private init() {}

    func install(in scene: UIWindowScene) {
        if let window, window.windowScene === scene { return }
        let w = UIWindow(windowScene: scene)
        w.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue + 1)
        w.backgroundColor = .clear
        w.isOpaque = false
        w.isUserInteractionEnabled = false
        w.accessibilityElementsHidden = true
        w.rootViewController = host
        w.isHidden = false
        window = w
        update()
    }

    func set(_ id: UUID, _ tone: StatusBarTone) {
        if let i = requests.firstIndex(where: { $0.id == id }) {
            guard requests[i].tone != tone else { return }
            requests[i].tone = tone
        } else {
            requests.append((id: id, tone: tone))
        }
        update()
    }

    func remove(_ id: UUID) {
        guard let i = requests.firstIndex(where: { $0.id == id }) else { return }
        requests.remove(at: i)
        update()
    }

    private func update() {
        let tone = requests.last?.tone ?? .automatic
        let style: UIStatusBarStyle
        switch tone {
        case .light: style = .lightContent
        case .dark: style = .darkContent
        case .automatic, .hidden: style = baseScheme == .dark ? .lightContent : .darkContent
        }
        let hidden = tone == .hidden
        guard host.style != style || host.hidden != hidden else { return }
        host.style = style
        host.hidden = hidden
        UIView.animate(withDuration: 0.25) { self.host.setNeedsStatusBarAppearanceUpdate() }
    }
}

/// The overlay window's (empty, transparent) root view controller.
final class StatusBarHostController: UIViewController {
    var style: UIStatusBarStyle = .darkContent
    var hidden: Bool = false

    override var preferredStatusBarStyle: UIStatusBarStyle { style }
    override var prefersStatusBarHidden: Bool { hidden }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }

    override func loadView() {
        let v = UIView()
        v.backgroundColor = .clear
        v.isOpaque = false
        v.isUserInteractionEnabled = false
        view = v
    }
}

/// Finds the scene the app's window lives in and installs the status-bar window there.
private struct StatusBarInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard let scene = window?.windowScene else { return }
            StatusBarController.shared.install(in: scene)
        }
    }
}

private struct StatusBarRoot: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(StatusBarInstaller().frame(width: 0, height: 0).allowsHitTesting(false).accessibilityHidden(true))
            .onAppear { StatusBarController.shared.baseScheme = colorScheme }
            .onChange(of: colorScheme) { _, s in StatusBarController.shared.baseScheme = s }
    }
}

private struct StatusBarToneModifier: ViewModifier {
    let tone: StatusBarTone
    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { StatusBarController.shared.set(id, tone) }
            .onDisappear { StatusBarController.shared.remove(id) }
            .onChange(of: tone) { _, t in StatusBarController.shared.set(id, t) }
    }
}

extension View {
    /// The status bar's text colour while this view is on screen (the most recently shown view wins).
    func statusBarTone(_ tone: StatusBarTone) -> some View {
        modifier(StatusBarToneModifier(tone: tone))
    }

    /// Installs the status-bar window; put once at the app's root, inside `.preferredColorScheme`.
    func statusBarRoot() -> some View {
        modifier(StatusBarRoot())
    }
}

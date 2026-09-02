import AppKit
import SwiftUI

/// Hosts `SplashView` in a borderless floating window, centred on the active
/// screen. An agent app has no ordinary windows, so this is created and torn
/// down by hand rather than declared as a SwiftUI `Window` scene.
@MainActor
final class SplashWindowController {
    static let shared = SplashWindowController()

    private var window: NSWindow?

    /// 520 wide as specified; taller than the original 380 because the
    /// launch-at-login row became a fourth full-width card — at 380 the stack
    /// clipped.
    static let size = NSSize(width: 520, height: 500)
    private static let seenKey = "hasCompletedOnboarding"

    var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: Self.seenKey)
    }

    func showIfFirstLaunch() {
        guard !hasCompletedOnboarding else { return }
        show()
    }

    /// Re-opens the splash on demand from the settings menu, clearing the
    /// first-run flag so the window behaves exactly as it does on a fresh install.
    func showAgain() {
        UserDefaults.standard.set(false, forKey: Self.seenKey)
        show()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        // Transparent backing so the vibrancy view can sample the desktop.
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        let root = SplashView { [weak self] in self?.dismiss() }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )

        let host = NSHostingView(rootView: root)
        host.frame = NSRect(origin: .zero, size: Self.size)
        panel.contentView = host
        panel.center()

        // An LSUIElement app cannot come forward on its own without this.
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        window = panel
    }

    /// Fades out and records completion.
    ///
    /// It deliberately does not try to pop the menu bar panel open: there is no
    /// public API for that, and reaching the status item by KVC raises an
    /// Objective-C exception Swift cannot catch if the key ever changes. The
    /// icon is already in the bar; a crash to save one click is a bad trade.
    func dismiss() {
        UserDefaults.standard.set(true, forKey: Self.seenKey)

        guard let panel = window else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.window = nil
            NSApp.setActivationPolicy(.accessory)
        }
    }

}

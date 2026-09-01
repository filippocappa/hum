import AppKit
import SwiftUI

@main
struct HumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            // Resolved inside the scene body, never as a stored property: a
            // stored `let` would construct the controller during App value
            // creation, ahead of NSApplication.run.
            PopoverView(engine: AudioEngineController.shared)
        } label: {
            MenuBarLabel(state: AudioEngineController.shared.menuBar)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Isolated so the label's only dependency is `isPlaying`.
private struct MenuBarLabel: View {
    @ObservedObject var state: MenuBarState

    var body: some View {
        // Filled icon while running gives a glanceable state cue in the bar.
        Image(systemName: state.isPlaying ? "waveform.circle.fill" : "waveform")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt-and-braces with LSUIElement: guarantees agent behaviour even when
        // the binary is run directly from the build directory via `swift run`.
        NSApp.setActivationPolicy(.accessory)

        // Build the audio graph and install monitors now that AppKit is up.
        AudioEngineController.shared.bootstrap()

        // First run only; returns immediately afterwards.
        SplashWindowController.shared.showIfFirstLaunch()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

import AppKit
import SwiftUI

@main
struct HumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    /// Deliberately a plain `let`, not `@StateObject`: the scene must not
    /// observe the controller. See `AudioEngineController.shared`.
    private let engine = AudioEngineController.shared

    var body: some Scene {
        MenuBarExtra {
            PopoverView(engine: engine)
        } label: {
            MenuBarLabel(state: engine.menuBar)
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
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

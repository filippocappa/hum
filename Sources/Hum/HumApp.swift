import AppKit
import SwiftUI

@main
struct HumApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var engine = AudioEngineController()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(engine: engine)
        } label: {
            // Filled icon while running gives a glanceable state cue in the bar.
            Image(systemName: engine.isPlaying ? "waveform.circle.fill" : "waveform")
        }
        .menuBarExtraStyle(.window)
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

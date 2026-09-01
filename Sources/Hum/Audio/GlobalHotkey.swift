import AppKit

/// Registers ⌥⌘S as a system-wide toggle.
///
/// A *global* monitor only receives key events once the process is trusted for
/// Accessibility; until then macOS silently withholds them, so `isTrusted`
/// reports whether the shortcut is actually live. The *local* monitor needs no
/// permission and covers the case where Hum's own popover has focus.
@MainActor
final class GlobalHotkey {
    private var globalMonitor: Any?
    private var localMonitor: Any?

    /// Whether the process is trusted for Accessibility, i.e. whether the
    /// system-wide half of the shortcut can work at all.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Opens System Settings at the pane where the user grants the permission.
    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    func start(handler: @escaping @MainActor () -> Void) {
        stop()

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard Self.matches(event) else { return }
            Task { @MainActor in handler() }
        }

        // Returning nil swallows the event so it never reaches the popover.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard Self.matches(event) else { return event }
            Task { @MainActor in handler() }
            return nil
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    /// ⌥⌘S. Compared against the device-independent flags so Caps Lock or a
    /// stray numeric-pad bit cannot break the match.
    private nonisolated static func matches(_ event: NSEvent) -> Bool {
        let required: NSEvent.ModifierFlags = [.command, .option]
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.subtracting([.capsLock, .function]) == required else { return false }
        return event.charactersIgnoringModifiers?.lowercased() == "s"
    }

    deinit {
        // `removeMonitor` is main-actor-safe to call with the tokens we hold.
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}

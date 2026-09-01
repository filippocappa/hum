import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// ⌥⌘S by default; the recorder in the splash lets the user rebind it.
    static let togglePlayPause = Self(
        "togglePlayPause",
        default: .init(.s, modifiers: [.option, .command])
    )
}

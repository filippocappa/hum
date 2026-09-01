import Foundation

/// Backing store for the menu bar label, holding the single property it draws.
///
/// The label must not observe `AudioEngineController`: SwiftUI subscriptions are
/// per-object, so every published change there — a volume drag at pointer rate,
/// a warmth drag, the focus countdown — invalidated the label, and AppKit
/// answers that by re-rendering the status item's replicant snapshot through
/// `CALayer.renderInContext`. That is what made slider drags cost 20 % CPU.
@MainActor
final class MenuBarState: ObservableObject {
    @Published private(set) var isPlaying = false

    func update(isPlaying newValue: Bool) {
        if newValue != isPlaying { isPlaying = newValue }
    }
}

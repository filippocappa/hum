import Foundation

/// The focus countdown, on its own observable.
///
/// Kept off `AudioEngineController` for the same reason as `VisualizerState`:
/// SwiftUI subscriptions are per-object, so publishing a value once a second on
/// the controller would re-evaluate every view that reads it — the whole popover
/// body — rather than the one label that shows it.
@MainActor
final class FocusTimerState: ObservableObject {
    /// Whole seconds left, or nil when no timed session is set.
    @Published private(set) var secondsRemaining: Int?

    /// Publishes only when the displayed second actually changes, so a 2 Hz tick
    /// produces at most one update per second.
    func update(seconds: Int?) {
        if seconds != secondsRemaining { secondsRemaining = seconds }
    }

    var text: String {
        guard let secondsRemaining else { return "--:--" }
        let clamped = max(0, secondsRemaining)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }
}

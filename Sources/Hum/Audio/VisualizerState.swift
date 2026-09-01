import Foundation

/// Carries the high-frequency visual signal on its own observable, deliberately
/// separate from `AudioEngineController`.
///
/// The MenuBarExtra label observes the controller (for `isPlaying`), and SwiftUI
/// subscriptions are per-object, not per-property: publishing a 30 Hz gain value
/// on the controller invalidated the label too, and AppKit answers a label
/// invalidation by re-rendering the status item's replicant snapshot through
/// `CALayer.renderInContext`. That cost ~40 % CPU with nothing playing and the
/// popover shut. Only the waveform observes this type, so a gain update can no
/// longer reach the menu bar.
@MainActor
final class VisualizerState: ObservableObject {
    @Published private(set) var gain: Float = 0

    /// Quantised to 1/256 so imperceptible jitter in the tail of a ramp does not
    /// publish a frame the eye cannot resolve.
    func update(gain newValue: Float) {
        let quantised = (newValue * 256).rounded() / 256
        if quantised != gain { gain = quantised }
    }

    func reset() {
        if gain != 0 { gain = 0 }
    }
}

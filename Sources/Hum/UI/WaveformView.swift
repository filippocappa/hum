import SwiftUI

/// Fluid ribbon visualiser.
///
/// The drawing lives in `WaveformLayerView`, backed by Core Animation. This
/// type only maps engine state onto its parameters, so nothing here runs per
/// frame — see the note in `WaveformLayer.swift` for the measurements that
/// forced that split.
struct WaveformView: View {
    /// The DSP's live gain scalar, so the ribbon decays in lockstep with the
    /// audible fade rather than on an animation that merely looks similar.
    var gain: Float
    var profile: NoiseProfile
    /// 0…1 warmth. Drives spatial density: a heavy low-pass reads as slow
    /// rolling swells, an open one as tight ripples.
    var warmth: Double
    var accent: Color

    /// One quantisation step of the published gain is 1/256 ≈ 0.0039, so any
    /// value under that is residue rather than signal.
    private static let silenceFloor: Float = 0.005
    private static let height: CGFloat = 56

    private var clampedGain: Double {
        let g = min(max(gain, 0), 1)
        return g < Self.silenceFloor ? 0 : Double(g)
    }

    /// Slight curve, not a straight scaling: keeps a visible ribbon at low
    /// volume while still collapsing to exactly flat at zero.
    private var amplitude: Double { pow(clampedGain, 0.7) }

    /// Continuous 0…1 presence factor, so the ribbon fades out rather than
    /// switching off at a threshold.
    private var presence: Double { min(clampedGain * 2.5, 1.0) }

    var body: some View {
        WaveformLayerView(
            amplitude: amplitude,
            presence: presence,
            accent: accent,
            density: profile.motion.density * (0.6 + 0.8 * min(max(warmth, 0), 1)),
            speed: profile.motion.speed
        )
        .frame(height: Self.height)
        .allowsHitTesting(false)
    }
}

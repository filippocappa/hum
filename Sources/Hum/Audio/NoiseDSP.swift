import Foundation

/// Noise colours available to the generator.
enum NoiseProfile: String, CaseIterable, Identifiable {
    // Ordered high frequency to low, which is how the picker reads.
    case white, pink, brown

    var id: String { rawValue }

    /// Stable index into the render switch and the makeup-gain table. Declared
    /// explicitly so the display order above can change without silently
    /// remapping which generator or gain each profile gets.
    var dspIndex: Int32 {
        switch self {
        case .brown: return 0
        case .pink:  return 1
        case .white: return 2
        }
    }

    var title: String {
        switch self {
        case .brown: return "Deep Brown"
        case .pink:  return "Pink"
        case .white: return "White"
        }
    }

    /// What the profile sounds like, in plain language — no mathematics, no
    /// promises about what it will do for your concentration.
    var blurb: String {
        switch self {
        case .white: return "Constant static to block voices and sharp sounds."
        case .pink:  return "Softer static with balanced lows and highs."
        case .brown: return "Low rumble to cut out background noise."
        }
    }

    /// Visualiser character: how fast and how finely the curves move.
    var motion: (speed: Double, density: Double) {
        switch self {
        case .brown: return (0.42, 1.15)
        case .pink:  return (0.95, 2.10)
        case .white: return (1.90, 3.60)
        }
    }
}

/// Direct-form-II transposed biquad. Coefficients are only ever recomputed on
/// the render thread, once per block, so the state below stays consistent.
private struct Biquad {
    var b0: Float = 1, b1: Float = 0, b2: Float = 0
    var a1: Float = 0, a2: Float = 0
    var z1: Float = 0, z2: Float = 0

    /// RBJ cookbook low-pass, Butterworth Q.
    mutating func setLowPass(cutoff: Float, sampleRate: Float, q: Float = 0.7071) {
        let f = min(max(cutoff, 20), sampleRate * 0.45)
        let omega = 2 * Float.pi * f / sampleRate
        let sinO = sinf(omega), cosO = cosf(omega)
        let alpha = sinO / (2 * q)

        let a0 = 1 + alpha
        b0 = ((1 - cosO) / 2) / a0
        b1 = (1 - cosO) / a0
        b2 = b0
        a1 = (-2 * cosO) / a0
        a2 = (1 - alpha) / a0
    }

    @inline(__always)
    mutating func process(_ x: Float) -> Float {
        let y = b0 * x + z1
        z1 = b1 * x - a1 * y + z2
        z2 = b2 * x - a2 * y
        return y
    }

    mutating func reset() { z1 = 0; z2 = 0 }
}

/// Lock-free, allocation-free DSP state shared between the UI thread (writers)
/// and the CoreAudio render thread (reader). Parameters are plain scalars that
/// are smoothed per-sample inside the render block, so a torn read can only ever
/// nudge a ramp target — never produce a discontinuity.
final class NoiseDSP: @unchecked Sendable {

    // MARK: Parameters (written from the main thread)

    /// 0…1 linear position from the volume slider.
    var targetVolume: Float = 0
    /// Seconds the gain takes to reach a new target. Transport transitions set a
    /// long crescendo/decrescendo; slider drags set a short one so the control
    /// still feels immediate.
    var rampSeconds: Float = 0.03
    /// Master low-pass corner in Hz (the "warmth" control).
    var cutoffHz: Float = 20_000
    /// Normalised 0…1 warmth, used to place the brown profile's tone biquad.
    var warmthNorm: Float = 0.32
    /// Selected noise colour, stored as the raw enum index for cheap reads.
    var profileIndex: Int32 = 0

    /// Most recent output RMS, published for the visualiser.
    private(set) var level: Float = 0

    /// The live, smoothed gain scalar — the same value the audio is multiplied
    /// by. The visualiser reads this so its decay is the audio's decay, not an
    /// independent animation that happens to look similar.
    var currentGain: Float { currentVolume }

    // MARK: Calibration

    /// Ceiling on the master gain. Full slider is a comfortable listening level
    /// with ample headroom, never a digitally clipped one.
    private static let masterGainCap: Float = 0.85

    /// Per-profile makeup gains, measured with `Tools/measure.swift`. Targets are
    /// not equal RMS: at equal RMS the low-biased brown spectrum reads quieter and
    /// the flat white one reads harsher, so brown sits ~3 dB hot and white ~1.5 dB
    /// cool. Peaks stay below −5 dBFS at full slider on all three.
    /// Indexed by profile: brown, pink, white.
    private static let makeupGains: [Float] = [6.64, 0.66, 1.30]

    // MARK: Internal render state (render thread only)

    private let sampleRate: Float

    private var currentVolume: Float = 0
    private var smoothedLPCoeff: Float = 1

    /// Profile currently being rendered, and the declick gain that dips through
    /// a switch. Swapping generators mid-stream steps the waveform — measurably
    /// ~5x the steady-state sample delta — so the gain drops to zero, the
    /// generator changes, and the gain returns. Well under one screen refresh.
    private var activeProfile: Int32 = 0
    private var switchGain: Float = 1

    // xorshift32 — deterministic, branch-free, and safe to call in real time.
    // `Float.random` is not: it takes a lock on a global generator, which can
    // block the render thread and produce dropouts.
    private var rngState: UInt32 = 0x9E3779B9

    // Paul Kellet pink-noise filter memory.
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0
    private var b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0

    // Brown-noise integrator, tone shaping, and DC blocker memory.
    private var lastBrown: Float = 0
    private var brownTone = Biquad()
    private var brownToneCutoff: Float = -1
    private var dcX1: Float = 0, dcY1: Float = 0

    // Master low-pass memory + RMS envelope follower memory.
    private var lowPassZ: Float = 0
    private var rmsAccumulator: Float = 0

    init(sampleRate: Double) {
        let rate = Float(sampleRate)
        self.sampleRate = rate
        brownTone.setLowPass(cutoff: 425, sampleRate: rate)
        brownToneCutoff = 425
    }

    // MARK: Sample generation

    /// Uniform white noise in [-1, 1).
    @inline(__always)
    private func nextWhite() -> Float {
        rngState ^= rngState << 13
        rngState ^= rngState >> 17
        rngState ^= rngState << 5
        // Map the top 24 bits into [0, 2) without touching the FPU exponent path.
        return Float(rngState >> 8) * (1.0 / 8_388_608.0) - 1.0
    }

    /// Paul Kellet's refined 1/f approximation (±0.05 dB, 10 Hz–20 kHz).
    @inline(__always)
    private func nextPink(_ white: Float) -> Float {
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        let pink = (b0 + b1 + b2 + b3 + b4 + b5 + (white * 0.5362)) * 0.11
        b6 = white * 0.115926
        return pink
    }

    /// Leaky integrator → true Brownian 1/f², normalised well clear of full
    /// scale, then tone-shaped and DC-blocked.
    @inline(__always)
    private func nextBrown(_ white: Float) -> Float {
        let brown = (lastBrown + (0.02 * white)) / 1.02
        lastBrown = brown

        // Second-order low-pass: removes the hiss the −6 dB/oct integrator
        // leaves up top, which is what made this profile read as "too white".
        var out = brownTone.process(brown * 0.45)

        // One-pole DC blocker (~5 Hz). The integrator drifts on any DC bias in
        // the source; unblocked that shows up as inaudible cone excursion,
        // stealing headroom from the audible signal and inviting clipping.
        let blocked = out - dcX1 + 0.9995 * dcY1
        dcX1 = out
        dcY1 = blocked
        out = blocked

        return out
    }

    /// Fills `buffer` with `frames` samples. Called on the CoreAudio render thread.
    func render(into buffer: UnsafeMutablePointer<Float>, frames: Int) {
        let profile = min(max(profileIndex, 0), Int32(Self.makeupGains.count - 1))
        let volumeTarget = min(max(targetVolume, 0), 1)

        // One-pole gain glide. A pole reaches ~95 % of its target in three time
        // constants, so tau is a third of the requested ramp duration.
        let tau = max(min(rampSeconds, 5.0), 0.005) / 3.0
        let gainCoeff = 1.0 - expf(-1.0 / (tau * sampleRate))
        let cutoffCoeff = 1.0 - expf(-1.0 / (0.050 * sampleRate))
        let cutoffTarget = min(max(cutoffHz, 60), sampleRate * 0.45)
        // Derive the master one-pole coefficient once per block and glide *that*,
        // so the render loop stays free of transcendental calls.
        let lpCoeffTarget = 1.0 - expf(-2.0 * .pi * cutoffTarget / sampleRate)

        // Brown tone biquad sweeps 190 Hz…950 Hz, mapped exponentially. The floor
        // matters: below ~190 Hz the biquad strips so much band that the profile
        // goes dead and the integrator's remaining energy piles into the sub
        // range, which is what made warmth = 0 sound broken rather than deep.
        let w = min(max(warmthNorm, 0), 1)
        let toneTarget = 190 * powf(5.0, w)
        if abs(toneTarget - brownToneCutoff) > 0.5 {
            brownTone.setLowPass(cutoff: toneTarget, sampleRate: sampleRate)
            brownToneCutoff = toneTarget
        }

        // ~6 ms each way through a profile change.
        let switchStep = 1.0 / (0.006 * sampleRate)

        var rms: Float = 0

        for i in 0..<frames {
            // Declick state machine: fade out, swap generator, fade back in.
            if activeProfile != profile {
                switchGain -= switchStep
                if switchGain <= 0 {
                    switchGain = 0
                    activeProfile = profile
                }
            } else if switchGain < 1 {
                switchGain = min(1, switchGain + switchStep)
            }

            let white = nextWhite()

            var sample: Float
            switch activeProfile {
            case 0:  sample = nextBrown(white)
            case 1:  sample = nextPink(white)
            default: sample = white * 0.15
            }
            sample *= Self.makeupGains[Int(activeProfile)] * switchGain

            // Master low-pass with a glided coefficient (no zipper noise).
            smoothedLPCoeff += (lpCoeffTarget - smoothedLPCoeff) * cutoffCoeff
            lowPassZ += (sample - lowPassZ) * smoothedLPCoeff
            sample = lowPassZ

            // Perceptual taper: squared response tracks loudness far better than
            // a linear fader, and the cap keeps full scale comfortable.
            currentVolume += (volumeTarget - currentVolume) * gainCoeff
            sample *= currentVolume * currentVolume * Self.masterGainCap

            // Guard rail only — calibration keeps peaks well below unity.
            if sample > 1 { sample = 1 } else if sample < -1 { sample = -1 }

            buffer[i] = sample
            rms += sample * sample
        }

        if frames > 0 {
            let frameRMS = sqrtf(rms / Float(frames))
            // Slew the published level so the visualiser breathes instead of jittering.
            rmsAccumulator += (frameRMS - rmsAccumulator) * 0.25
            level = rmsAccumulator
        }
    }

    /// True once the gain ramp has fully drained — used to defer engine teardown.
    var isSilent: Bool { currentVolume < 0.0005 }

    /// Clears filter memory so a resumed engine starts from a defined state.
    func reset() {
        currentVolume = 0
        b0 = 0; b1 = 0; b2 = 0; b3 = 0; b4 = 0; b5 = 0; b6 = 0
        lastBrown = 0
        brownTone.reset()
        dcX1 = 0; dcY1 = 0
        lowPassZ = 0
        smoothedLPCoeff = 1
        switchGain = 1
        activeProfile = profileIndex
        rmsAccumulator = 0
        level = 0
    }
}

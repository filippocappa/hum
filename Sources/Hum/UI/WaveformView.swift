import SwiftUI

/// Fluid ribbon visualiser. Each layer sums two sinusoidal harmonics of
/// different frequency and drift rate, sampled sparsely and joined with cubic
/// Béziers so the curve reads as continuous rather than polygonal.
struct WaveformView: View {
    /// The DSP's live gain scalar. Driving the ribbon from this — rather than
    /// from a separate SwiftUI animation — is what keeps the visual decay in
    /// lockstep with the audible one through the 500 ms decrescendo, and what
    /// makes the wave flat at 0 % volume even while playback is running.
    var gain: Float
    var profile: NoiseProfile
    /// 0…1 warmth position. Drives spatial density: a heavy low-pass should look
    /// like slow rolling swells, an open one like tight ripples.
    var warmth: Double
    var accent: Color

    /// Below this the ribbon is treated as fully at rest: amplitude, opacity and
    /// motion all clamp to exactly zero, so nothing jitters on indefinitely at a
    /// sliver of gain the ear cannot hear.
    private static let silenceFloor: Float = 0.001

    private var clampedGain: Double {
        let g = min(max(gain, 0), 1)
        return g < Self.silenceFloor ? 0 : Double(g)
    }

    /// Slight curve, not a straight scaling: keeps a visible ribbon at low
    /// volume while still collapsing to exactly flat at zero.
    private var amplitude: Double { pow(clampedGain, 0.7) }

    /// Continuous 0…1 presence factor. The accent ribbon fades out along this
    /// curve and the neutral resting line fades in against it, so there is no
    /// frame at which anything switches on or off.
    private var presence: Double { min(clampedGain * 2.5, 1.0) }

    /// Peak excursion in points at full amplitude.
    private static let peakHeight: Double = 22
    private static let height: CGFloat = 56

    private struct Layer {
        let opacity: Double
        let width: CGFloat
        let heightScale: Double
        /// Spatial frequencies (ω₁, ω₂) and their temporal drift rates (φ₁, φ₂).
        let w1: Double, w2: Double
        let p1: Double, p2: Double
        let offset: Double
    }

    private let layers: [Layer] = [
        .init(opacity: 0.85, width: 1.8, heightScale: 1.00,
              w1: 1.00, w2: 2.30, p1: 1.00, p2: -0.62, offset: 0),
        .init(opacity: 0.28, width: 1.5, heightScale: 0.74,
              w1: 1.45, w2: 3.10, p1: -0.78, p2: 1.24, offset: 1.7)
    ]

    /// The active ribbon carries the profile accent; the trailing one stays
    /// neutral so the accent never muddies against itself.
    private func tint(_ index: Int) -> Color { index == 0 ? accent : .white }

    var body: some View {
        // With presence at zero the ribbon is flat and static, so stop stepping
        // the clock entirely rather than redrawing an unchanging frame at 60 Hz.
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: presence <= 0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let midY = size.height / 2

                // Slow breathing envelope so the ribbon never looks mechanically periodic.
                let breath = 0.88 + 0.12 * sin(t * 0.55)
                let peak = Self.peakHeight * amplitude * breath

                // The resting line is always present underneath, fading in as the
                // accent ribbon fades out — a crossfade, not a swap.
                drawRestingLine(in: &context, size: size, midY: midY, strength: 1 - presence)
                guard presence > 0 else { return }

                let motion = profile.motion
                // Warmth sets how many cycles fit across the width.
                let density = motion.density * (0.6 + 0.8 * min(max(warmth, 0), 1))
                for (index, layer) in layers.enumerated() {
                    let base: Double = 2 * .pi * density
                    let drift: Double = 2 * motion.speed
                    let omega1: Double = base * layer.w1
                    let omega2: Double = base * layer.w2
                    let phase1: Double = t * drift * layer.p1 + layer.offset
                    let phase2: Double = t * drift * layer.p2 + layer.offset
                    let scale: Double = peak * layer.heightScale

                    let path = smoothPath(size: size, midY: midY) { u in
                        let a1: Double = sin(u * omega1 + phase1)
                        let a2: Double = sin(u * omega2 + phase2)
                        // Gaussian window: the ribbon swells at centre and dissolves
                        // into the panel edges instead of terminating abruptly.
                        let centred: Double = (u - 0.5) * 2.4
                        let envelope: Double = exp(-centred * centred)
                        return (a1 * 0.68 + a2 * 0.32) * scale * envelope
                    }
                    context.stroke(path,
                                   with: .color(tint(index).opacity(layer.opacity * presence)),
                                   lineWidth: layer.width)
                }
            }
        }
        .frame(height: Self.height)
    }

    /// Samples `f` at a coarse step and connects the points with cubic Béziers,
    /// using the Catmull-Rom tangent at each knot. Far smoother than a dense
    /// polyline, and cheaper — 15 segments instead of 140 line-to calls.
    private func smoothPath(size: CGSize, midY: CGFloat, _ f: (Double) -> Double) -> Path {
        let segments = 15
        var points: [CGPoint] = []
        points.reserveCapacity(segments + 1)
        for i in 0...segments {
            let u = Double(i) / Double(segments)
            points.append(CGPoint(x: size.width * u, y: midY + f(u)))
        }

        var path = Path()
        path.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p0 = points[max(i - 1, 0)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(i + 2, points.count - 1)]

            // Catmull-Rom → Bézier control points (tension 1/6).
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    /// Resting state: a soft glowing rule, drawn as a wide faint pass beneath a
    /// crisp thin one — cheaper and sharper than a blur filter. `strength`
    /// crossfades it against the accent ribbon.
    private func drawRestingLine(in context: inout GraphicsContext, size: CGSize,
                                 midY: CGFloat, strength: Double) {
        guard strength > 0 else { return }
        var line = Path()
        line.move(to: CGPoint(x: 0, y: midY))
        line.addLine(to: CGPoint(x: size.width, y: midY))

        let fade = GraphicsContext.Shading.linearGradient(
            Gradient(colors: [.clear, .primary, .primary, .clear]),
            startPoint: .zero,
            endPoint: CGPoint(x: size.width, y: 0)
        )

        context.opacity = 0.10 * strength
        context.stroke(line, with: fade, lineWidth: 4)
        context.opacity = 0.45 * strength
        context.stroke(line, with: fade, lineWidth: 1)
        context.opacity = 1
    }
}

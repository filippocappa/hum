import AppKit
import SwiftUI

/// The ribbon, drawn by Core Animation instead of a SwiftUI `Canvas`.
///
/// A `Canvas` inside a `TimelineView` costs roughly 2 ms of app CPU per frame
/// here — measured at ~7 % for this view alone at 30 fps, independent of layer
/// count, knot count, canvas size or backdrop. The work is SwiftUI's per-frame
/// machinery, not the drawing.
///
/// So the animation is handed to the render server: a `CAKeyframeAnimation`
/// morphs between pre-built paths covering exactly one loop of the travelling
/// wave. The app builds those paths once and then does nothing per frame —
/// amplitude, colour and speed are layer properties Core Animation interpolates
/// on its own thread.
final class WaveHostView: NSView {

    private let back = CAShapeLayer()
    private let front = CAShapeLayer()

    /// Keyframes per loop. Core Animation interpolates between them, so this
    /// sets path fidelity rather than frame rate.
    private static let steps = 48
    private static let knots = 9

    private var density: Double = 2.1
    private var loopDuration: Double = 4.0
    private var amplitude: Double = 0
    private var builtSize: CGSize = .zero
    private var builtDensity: Double = -1

    private var frontPaths: [CGPath] = []
    private var backPaths: [CGPath] = []
    /// The resting shape: a straight line with the same segment structure as the
    /// wave paths, so Core Animation can interpolate between them.
    private var flatPath: CGPath?
    private var atRest = true

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(back)
        layer?.addSublayer(front)
        for l in [back, front] {
            l.fillColor = nil
            l.lineCap = .round
            l.lineJoin = .round
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        front.lineWidth = 1.8
        back.lineWidth = 1.5
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        rebuildIfNeeded()
    }

    /// Gives SwiftUI a height to work with; width comes from the call site.
    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 56)
    }

    func apply(amplitude: Double, presence: Double, accent: NSColor,
               density: Double, speed: Double) {
        self.density = density
        self.loopDuration = max(1.2, 4.0 / max(speed, 0.05))

        rebuildIfNeeded()

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        front.strokeColor = accent.withAlphaComponent(0.85).cgColor
        back.strokeColor = NSColor.white.withAlphaComponent(0.28).cgColor
        CATransaction.commit()

        if presence > 0 {
            resume(amplitude: amplitude, presence: presence)
        } else {
            settleToFlatline()
        }
    }

    /// Playing: wave shape, amplitude-scaled, looping.
    private func resume(amplitude: Double, presence: Double) {
        let wasResting = atRest
        atRest = false

        CATransaction.begin()
        // Coming out of rest, unfurl a little more slowly than a routine level
        // change so the line visibly grows back into a wave.
        CATransaction.setAnimationDuration(wasResting ? 0.35 : 0.25)
        if wasResting, let first = frontPaths.first, let firstBack = backPaths.first {
            // Morph the flat line back into the wave, then hand over to the
            // looping animation; adding the loop straight away would snap.
            CATransaction.setCompletionBlock { [weak self] in
                guard let self, !self.atRest else { return }
                self.installAnimations()
            }
            front.path = first
            back.path = firstBack
        }
        setAmplitude(amplitude)
        front.opacity = Float(presence)
        back.opacity = Float(presence * 0.9)
        CATransaction.commit()

        if !wasResting, front.animation(forKey: "path") == nil {
            installAnimations()
        }
    }

    /// Paused or stopped: the ribbon settles into one calm horizontal line at
    /// reduced opacity rather than vanishing.
    private func settleToFlatline() {
        guard !atRest else { return }
        atRest = true

        back.removeAnimation(forKey: "path")
        front.removeAnimation(forKey: "path")

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.55)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        // Scale returns to 1: the stroke itself is scaled by the transform, so
        // collapsing amplitude to zero would thin the line away to nothing.
        for l in [back, front] {
            l.transform = CATransform3DIdentity
        }
        if let flatPath {
            front.path = flatPath
            back.path = flatPath
        }
        front.opacity = 0.22
        back.opacity = 0.08
        CATransaction.commit()
    }

    private func setAmplitude(_ value: Double) {
        self.amplitude = value
        // Floor well above zero: a near-zero scale is a degenerate transform,
        // and `presence` already hides the ribbon when there is nothing to show.
        let scale = max(value, 0.06)
        for l in [back, front] {
            l.transform = CATransform3DMakeScale(1, scale, 1)
        }
    }

    private func rebuildIfNeeded() {
        let size = bounds.size
        guard size.width > 1, size.height > 1 else { return }
        guard size != builtSize || density != builtDensity else { return }
        builtSize = size
        builtDensity = density

        // Never assign `frame` here. The frame setter compensates for the
        // layer's transform, so with a vertical scale already applied it solves
        // for a bounds height of (wanted / scale) — which with a small scale
        // blows the layer up by orders of magnitude and pushes the path out of
        // view. Set bounds and position directly and leave transform alone.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in [back, front] {
            l.bounds = CGRect(origin: .zero, size: size)
            l.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        CATransaction.commit()

        frontPaths = paths(w1: 1.00, w2: 2.30, dir1: 1.0, dir2: -2.0,
                           heightScale: 1.0, offset: 0)
        backPaths = paths(w1: 1.45, w2: 3.10, dir1: -1.0, dir2: 2.0,
                          heightScale: 0.74, offset: 1.7)
        flatPath = flatLine()

        if atRest {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            front.path = flatPath
            back.path = flatPath
            front.opacity = 0.22
            back.opacity = 0.08
            CATransaction.commit()
        } else {
            setAmplitude(amplitude)
            installAnimations()
        }
    }

    /// One full loop of phase, so the keyframes join seamlessly end to end.
    private func paths(w1: Double, w2: Double, dir1: Double, dir2: Double,
                       heightScale: Double, offset: Double) -> [CGPath] {
        let size = builtSize
        let midY = size.height / 2
        let peak = size.height * 0.38 * heightScale

        return (0..<Self.steps).map { step in
            let t = Double(step) / Double(Self.steps) * 2 * .pi
            let path = CGMutablePath()
            var points: [CGPoint] = []
            points.reserveCapacity(Self.knots + 1)

            for k in 0...Self.knots {
                let u = Double(k) / Double(Self.knots)
                let a1 = sin(u * 2 * .pi * density * w1 + t * dir1 + offset)
                let a2 = sin(u * 2 * .pi * density * w2 + t * dir2 + offset)
                // Gaussian window: the ribbon swells at centre and dissolves
                // into the panel edges instead of ending abruptly.
                let centred = (u - 0.5) * 2.4
                let envelope = exp(-centred * centred)
                let y = midY + (a1 * 0.68 + a2 * 0.32) * peak * envelope
                points.append(CGPoint(x: size.width * u, y: y))
            }

            // Catmull-Rom tangents, so the curve reads as continuous.
            path.move(to: points[0])
            for i in 0..<points.count - 1 {
                let p0 = points[max(i - 1, 0)]
                let p1 = points[i]
                let p2 = points[i + 1]
                let p3 = points[min(i + 2, points.count - 1)]
                path.addCurve(
                    to: p2,
                    control1: CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6),
                    control2: CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
                )
            }
            return path
        }
    }

    /// Same knot count and segment structure as the wave paths, so the two
    /// interpolate cleanly instead of snapping.
    private func flatLine() -> CGPath {
        let midY = builtSize.height / 2
        let path = CGMutablePath()
        let points = (0...Self.knots).map {
            CGPoint(x: builtSize.width * Double($0) / Double(Self.knots), y: midY)
        }
        path.move(to: points[0])
        for i in 0..<points.count - 1 {
            let p1 = points[i], p2 = points[i + 1]
            path.addCurve(to: p2,
                          control1: CGPoint(x: p1.x + (p2.x - p1.x) / 3, y: midY),
                          control2: CGPoint(x: p2.x - (p2.x - p1.x) / 3, y: midY))
        }
        return path
    }

    private func installAnimations() {
        guard builtSize.width > 1, !frontPaths.isEmpty else { return }

        func animation(_ values: [CGPath]) -> CAKeyframeAnimation {
            let a = CAKeyframeAnimation(keyPath: "path")
            a.values = values + [values[0]]   // close the loop
            a.duration = loopDuration
            a.repeatCount = .infinity
            a.calculationMode = .cubic
            a.isRemovedOnCompletion = false
            return a
        }

        front.removeAnimation(forKey: "path")
        back.removeAnimation(forKey: "path")

        // Keep the model layer in step with what the animation shows. Without
        // this the model still holds the flat resting path, so the moment the
        // animation is removed the ribbon snaps to a shape it was never showing.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        front.path = frontPaths[0]
        back.path = backPaths[0]
        CATransaction.commit()

        front.add(animation(frontPaths), forKey: "path")
        back.add(animation(backPaths), forKey: "path")
    }
}

/// SwiftUI wrapper. Its `updateNSView` runs only when a parameter actually
/// changes, never per frame.
struct WaveformLayerView: NSViewRepresentable {
    var amplitude: Double
    var presence: Double
    var accent: Color
    var density: Double
    var speed: Double

    func makeNSView(context: Context) -> WaveHostView {
        WaveHostView(frame: .zero)
    }

    func updateNSView(_ view: WaveHostView, context: Context) {
        view.apply(amplitude: amplitude,
                   presence: presence,
                   accent: NSColor(accent),
                   density: density,
                   speed: speed)
    }
}

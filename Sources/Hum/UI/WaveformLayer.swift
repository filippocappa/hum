import AppKit
import SwiftUI

/// The ribbon, drawn by Core Animation instead of a SwiftUI `Canvas`.
///
/// A `Canvas` inside a `TimelineView` costs roughly 2 ms of app CPU per frame
/// here — measured at ~7 % for this view alone at 30 fps, independent of layer
/// count, knot count, canvas size or backdrop. The work is SwiftUI's per-frame
/// machinery, not the drawing. So the animation is handed to the render server:
/// a `CAKeyframeAnimation` morphs between paths covering exactly one loop of the
/// travelling wave, and the app does nothing per frame.
///
/// Play and pause never swap shapes. A baseline layer holds a flat line at the
/// exact centre at all times; the wave collapses onto it and grows back out of
/// it, so there is no frame in which nothing is drawn.
final class WaveHostView: NSView {

    /// Always present, never animated: the line the wave settles onto.
    private let baseline = CAShapeLayer()
    private let back = CAShapeLayer()
    private let front = CAShapeLayer()

    /// Keyframes per loop. Core Animation interpolates between them, so this
    /// sets path fidelity rather than frame rate.
    private static let steps = 48
    private static let knots = 9
    private static let lineWidthFront: CGFloat = 1.8
    private static let lineWidthBack: CGFloat = 1.5
    /// Thinner than the wave: at rest it should read as a quiet rule, not as a
    /// flattened ribbon.
    private static let lineWidthBaseline: CGFloat = 1.0

    /// Collapsed scale. Not zero: the layer transform scales the stroke too, so
    /// the wave thins as it flattens, handing the eye over to the baseline.
    private static let restScale: CGFloat = 0.02
    private static let restBaselineOpacity: Float = 0.30

    private var density: Double = 2.1
    private var loopDuration: Double = 4.0
    private var amplitude: Double = 0
    private var builtSize: CGSize = .zero
    private var builtDensity: Double = -1

    private var frontPaths: [CGPath] = []
    private var backPaths: [CGPath] = []
    private var atRest = true
    private var frozen = false
    private var freezeWork: DispatchWorkItem?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        for l in [baseline, back, front] {
            l.fillColor = nil
            l.lineCap = .round
            l.lineJoin = .round
            layer?.addSublayer(l)
        }
        front.lineWidth = Self.lineWidthFront
        back.lineWidth = Self.lineWidthBack
        baseline.lineWidth = Self.lineWidthBaseline
        baseline.opacity = Self.restBaselineOpacity
        front.opacity = 0
        back.opacity = 0
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

    // MARK: State

    func apply(amplitude: Double, presence: Double, accent: NSColor,
               density: Double, speed: Double) {
        self.density = density
        self.loopDuration = max(1.2, 4.0 / max(speed, 0.05))

        rebuildIfNeeded()

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        front.strokeColor = accent.withAlphaComponent(0.85).cgColor
        back.strokeColor = NSColor.white.withAlphaComponent(0.28).cgColor
        baseline.strokeColor = accent.withAlphaComponent(0.9).cgColor
        CATransaction.commit()

        presence > 0
            ? expand(amplitude: amplitude, presence: presence)
            : collapse()
    }

    /// Grows the same line back into a wave.
    private func expand(amplitude: Double, presence: Double) {
        freezeWork?.cancel()
        freezeWork = nil
        if frozen { unfreeze() }
        if front.animation(forKey: "path") == nil { installAnimations() }

        let wasResting = atRest
        atRest = false
        self.amplitude = amplitude

        CATransaction.begin()
        CATransaction.setAnimationDuration(wasResting ? 0.45 : 0.25)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        setScale(max(CGFloat(amplitude), 0.06))
        front.opacity = Float(presence)
        back.opacity = Float(presence * 0.9)
        // The baseline recedes as the wave takes over, but never before it.
        baseline.opacity = max(0, Self.restBaselineOpacity - 0.30 * Float(presence))
        CATransaction.commit()
    }

    /// Collapses the wave onto the baseline. Nothing is removed or swapped, so
    /// there is no frame without a line on screen.
    private func collapse() {
        guard !atRest else { return }
        atRest = true

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.45)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        setScale(Self.restScale)
        front.opacity = 0
        back.opacity = 0
        baseline.opacity = Self.restBaselineOpacity
        CATransaction.commit()

        // Once it has settled, stop the render server interpolating a wave
        // nobody can see. Freezing preserves phase, so resuming does not jump.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.atRest else { return }
            self.freeze()
        }
        freezeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func setScale(_ scale: CGFloat) {
        for l in [back, front] {
            l.transform = CATransform3DMakeScale(1, scale, 1)
        }
    }

    // MARK: Freezing

    private func freeze() {
        guard !frozen else { return }
        frozen = true
        for l in [back, front] {
            let paused = l.convertTime(CACurrentMediaTime(), from: nil)
            l.speed = 0
            l.timeOffset = paused
        }
    }

    private func unfreeze() {
        guard frozen else { return }
        frozen = false
        for l in [back, front] {
            let paused = l.timeOffset
            l.speed = 1
            l.timeOffset = 0
            l.beginTime = 0
            l.beginTime = l.convertTime(CACurrentMediaTime(), from: nil) - paused
        }
    }

    // MARK: Geometry

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
        for l in [baseline, back, front] {
            l.bounds = CGRect(origin: .zero, size: size)
            l.position = CGPoint(x: size.width / 2, y: size.height / 2)
        }
        baseline.path = flatLine()
        CATransaction.commit()

        frontPaths = paths(w1: 1.00, w2: 2.30, dir1: 1.0, dir2: -2.0,
                           heightScale: 1.0, offset: 0)
        backPaths = paths(w1: 1.45, w2: 3.10, dir1: -1.0, dir2: 2.0,
                          heightScale: 0.74, offset: 1.7)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        setScale(atRest ? Self.restScale : max(CGFloat(amplitude), 0.06))
        CATransaction.commit()

        installAnimations()
    }

    private func flatLine() -> CGPath {
        let midY = builtSize.height / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: midY))
        path.addLine(to: CGPoint(x: builtSize.width, y: midY))
        return path
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
        // this the model holds a stale path, so the ribbon snaps to a shape it
        // was never showing the moment the animation is removed.
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

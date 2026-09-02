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
        // Colour and level changes glide; nothing here runs per frame.
        CATransaction.setAnimationDuration(0.25)
        front.strokeColor = accent.withAlphaComponent(0.85).cgColor
        back.strokeColor = NSColor.white.withAlphaComponent(0.28).cgColor
        front.opacity = Float(presence)
        back.opacity = Float(presence * 0.9)
        setAmplitude(amplitude)
        CATransaction.commit()

        // With nothing to show, drop the animations entirely rather than let the
        // render server keep interpolating an invisible path.
        if presence <= 0 {
            back.removeAllAnimations()
            front.removeAllAnimations()
        } else if front.animation(forKey: "path") == nil {
            installAnimations()
        }
    }

    private func setAmplitude(_ value: Double) {
        self.amplitude = value
        // Floor well above zero: a near-zero scale is a degenerate transform,
        // and `presence` already hides the ribbon when there is nothing to show.
        let scale = max(value, 0.02)
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

        setAmplitude(amplitude)
        installAnimations()
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
        guard builtSize.width > 1 else { return }

        let frontPaths = paths(w1: 1.00, w2: 2.30, dir1: 1.0, dir2: -2.0,
                               heightScale: 1.0, offset: 0)
        let backPaths = paths(w1: 1.45, w2: 3.10, dir1: -1.0, dir2: 2.0,
                              heightScale: 0.74, offset: 1.7)

        front.path = frontPaths[0]
        back.path = backPaths[0]

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

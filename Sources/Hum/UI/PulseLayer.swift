import AppKit
import SwiftUI

/// The glyph's glow, animated by Core Animation rather than SwiftUI.
///
/// A `TimelineView` or a `repeatForever` implicit animation both drive this from
/// the CPU every frame; `CABasicAnimation` on opacity and scale runs on the
/// render server instead, so the app does no work while it breathes.
final class PulseHostView: NSView {

    private let glow = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        glow.type = .radial
        glow.startPoint = CGPoint(x: 0.5, y: 0.5)
        glow.endPoint = CGPoint(x: 1, y: 1)
        glow.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer?.addSublayer(glow)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        glow.frame = bounds
        glow.position = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    func apply(accent: NSColor, active: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.25)
        glow.colors = [accent.cgColor, accent.withAlphaComponent(0).cgColor]
        CATransaction.commit()

        if active {
            guard glow.animation(forKey: "pulse") == nil else { return }

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0.15
            fade.toValue = 0.32

            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.94
            grow.toValue = 1.08

            let group = CAAnimationGroup()
            group.animations = [fade, grow]
            group.duration = 2.4
            group.autoreverses = true
            group.repeatCount = .infinity
            group.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            group.isRemovedOnCompletion = false
            glow.add(group, forKey: "pulse")
        } else {
            glow.removeAnimation(forKey: "pulse")
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            glow.opacity = 0.16
            glow.transform = CATransform3DIdentity
            CATransaction.commit()
        }
    }
}

struct PulseGlowView: NSViewRepresentable {
    var accent: Color
    var active: Bool

    func makeNSView(context: Context) -> PulseHostView { PulseHostView(frame: .zero) }

    func updateNSView(_ view: PulseHostView, context: Context) {
        view.apply(accent: NSColor(accent), active: active)
    }
}

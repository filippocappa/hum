import AppKit
import SwiftUI

/// Native vibrancy bridge. `.behindWindow` blending samples the desktop and any
/// windows *behind* the popover — something SwiftUI's plain `.ultraThinMaterial`
/// cannot do on its own inside a MenuBarExtra window, where it composites only
/// against whatever the window itself has already painted.
struct VisualEffectBackground: NSViewRepresentable {
    /// `.hudWindow` is the most transparent of the window-blending materials,
    /// so wallpaper colour genuinely reads through.
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        // `.active` keeps the blur live even when the app is not frontmost —
        // an agent app almost never is.
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = .active
    }
}

/// Clears the opaque backing the hosting window and its content view paint by
/// default. Without this the vibrancy view composites against solid fill and
/// the panel reads as flat dark grey no matter which material is chosen.
struct WindowBackdropCleaner: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { NSView(frame: .zero) }

    func updateNSView(_ view: NSView, context: Context) {
        // The window is not attached during the first layout pass.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true

            // SwiftUI's hosting views install their own opaque layers above the
            // window backing. Walking only the first-subview chain misses the
            // branch the panel actually sits in, so clear the whole tree —
            // skipping effect views, which paint their material through the layer.
            func clear(_ view: NSView) {
                if !(view is NSVisualEffectView) {
                    view.layer?.backgroundColor = NSColor.clear.cgColor
                }
                view.subviews.forEach(clear)
            }
            if let content = window.contentView { clear(content) }
        }
    }
}

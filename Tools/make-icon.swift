// Renders the Hum app icon with CoreGraphics — no design assets, no dependencies.
// Emits an .iconset, an .icns, and an Xcode-compatible AppIcon.appiconset.
//   swift Tools/make-icon.swift
import AppKit
import CoreGraphics
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/Hum.iconset")
let appiconset = root.appendingPathComponent("Sources/Hum/Resources/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
try? FileManager.default.createDirectory(at: appiconset, withIntermediateDirectories: true)

/// The harmonic curve on the icon face — the same two-sine sum the app's live
/// visualiser draws, frozen at a flattering phase.
func wave(_ u: Double) -> Double {
    let a1 = sin(u * .pi * 2 * 1.15 + 0.4)
    let a2 = sin(u * .pi * 2 * 2.60 - 0.9)
    let centred = (u - 0.5) * 2.4
    return (a1 * 0.68 + a2 * 0.32) * exp(-centred * centred)
}

func render(size: Int) -> CGImage {
    let s = CGFloat(size)
    let space = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // macOS icons sit inset within their canvas rather than filling it.
    let inset = s * 0.06
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let disc = CGPath(ellipseIn: rect, transform: nil)

    // Deep, near-black body with a subtle top-lit vertical gradient.
    ctx.saveGState()
    ctx.addPath(disc)
    ctx.clip()
    let body = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.16, green: 0.15, blue: 0.17, alpha: 1),
        CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(body,
                           start: CGPoint(x: 0, y: rect.maxY),
                           end: CGPoint(x: 0, y: rect.minY),
                           options: [])

    // Warm amber bloom behind the curve.
    let bloom = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 1.0, green: 0.68, blue: 0.32, alpha: 0.22),
        CGColor(red: 1.0, green: 0.68, blue: 0.32, alpha: 0.0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(bloom,
                           startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
                           endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: rect.width * 0.5,
                           options: [])

    // The curve itself: a wide amber glow pass beneath a crisp warm-white one.
    let span = rect.width * 0.62
    let amp = rect.height * 0.17
    func strokeWave(width: CGFloat, color: CGColor) {
        let path = CGMutablePath()
        var first = true
        var x: CGFloat = 0
        while x <= span {
            let u = Double(x / span)
            let pt = CGPoint(x: rect.midX - span / 2 + x, y: rect.midY + CGFloat(wave(u)) * amp)
            if first { path.move(to: pt); first = false } else { path.addLine(to: pt) }
            x += max(span / 240, 0.5)
        }
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.addPath(path)
        ctx.strokePath()
    }
    strokeWave(width: max(s * 0.055, 1.5), color: CGColor(red: 1.0, green: 0.62, blue: 0.22, alpha: 0.45))
    strokeWave(width: max(s * 0.028, 1.0), color: CGColor(red: 1.0, green: 0.95, blue: 0.88, alpha: 1.0))
    ctx.restoreGState()

    // Specular rim, brightest at the top edge.
    ctx.addPath(disc)
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
    ctx.setLineWidth(max(s * 0.006, 0.75))
    ctx.strokePath()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) throws {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try data.write(to: url)
}

// iconset names macOS requires for iconutil.
let variants: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

var cache: [Int: CGImage] = [:]
for v in variants {
    let image = cache[v.px] ?? render(size: v.px)
    cache[v.px] = image
    try write(image, to: iconset.appendingPathComponent("\(v.name).png"))
    try write(image, to: appiconset.appendingPathComponent("\(v.name).png"))
}

// Contents.json so the folder works as a real Xcode asset catalog.
let entries = variants.map { v -> String in
    let base = v.name.replacingOccurrences(of: "icon_", with: "")
    let scale = base.hasSuffix("@2x") ? "2x" : "1x"
    let size = base.replacingOccurrences(of: "@2x", with: "")
    return """
        {"filename":"\(v.name).png","idiom":"mac","scale":"\(scale)","size":"\(size)"}
    """
}
let contents = """
{"images":[
\(entries.joined(separator: ",\n"))
],"info":{"author":"xcode","version":1}}
"""
try contents.write(to: appiconset.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("Rendered \(variants.count) sizes → \(iconset.path) and \(appiconset.path)")

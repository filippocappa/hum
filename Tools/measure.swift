// Offline calibration harness. Renders each profile at full volume and reports
// RMS / peak, so the makeup gains in NoiseDSP are measured rather than guessed.
//   swiftc Sources/Hum/Audio/NoiseDSP.swift Tools/measure.swift -O -o /tmp/measure && /tmp/measure
import Foundation

let sampleRate = 48_000.0
let seconds = 5
let frames = 512

for (index, name) in ["brown", "pink", "white"].enumerated() {
    let dsp = NoiseDSP(sampleRate: sampleRate)
    dsp.profileIndex = Int32(index)
    dsp.targetVolume = 1.0
    dsp.cutoffHz = 20_000      // master filter wide open, to isolate the profile
    dsp.warmthNorm = 0.5    // the app's factory default

    let buffer = UnsafeMutablePointer<Float>.allocate(capacity: frames)
    defer { buffer.deallocate() }

    var sumSquares = 0.0
    var peak: Float = 0
    var counted = 0
    let blocks = Int(sampleRate) * seconds / frames

    for block in 0..<blocks {
        dsp.render(into: buffer, frames: frames)
        guard block > 20 else { continue }   // let the gain ramp settle
        for i in 0..<frames {
            let s = buffer[i]
            sumSquares += Double(s) * Double(s)
            peak = max(peak, abs(s))
            counted += 1
        }
    }

    let rms = sqrt(sumSquares / Double(counted))
    let dbfs = 20 * log10(rms)
    let peakDb = 20 * log10(Double(peak))
    print(String(format: "%-6s rms %.4f (%.1f dBFS)   peak %.4f (%.1f dBFS)",
                 (name as NSString).utf8String!, rms, dbfs, peak, peakDb))
}

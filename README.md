# Hum

A lightweight, native macOS menu-bar noise generator for deep focus.

## Architecture

- **Audio DSP**: Real-time sample synthesis via `AVAudioEngine` & `AVAudioSourceNode` (zero audio loops, lock-free `xorshift32` RNG).
- **Noise Spectra**:
  - **White**: Uniform random distribution `[-1.0, 1.0]`.
  - **Pink**: Paul Kellet 3-pole filter approximation.
  - **Deep Brown**: Leaky integrator (1/f²) with Butterworth biquad low-pass tone shaping and ~5 Hz DC blocking.
- **UI**: Pure SwiftUI, `NSVisualEffectView` translucency, dynamic per-profile accent colors, and a real-time gain-reactive waveform visualizer.
- **Global Shortcut**: `⌥⌘S` to toggle playback from anywhere.

## Requirements

- macOS 14.0+ (Sonoma or later)
- Xcode 15+ / Swift 5.9+

## Installation & Build

```bash
git clone https://github.com/filippocappa/hum.git
cd hush
swift run
```

To build a signed `.app` bundle instead:

```bash
./bundle.sh
open Hum.app          # install: mv Hum.app /Applications
```

`⌥⌘S` requires Accessibility access (**System Settings → Privacy & Security →
Accessibility**). macOS withholds global key events silently until granted, so
the popover shows a prompt while the permission is missing.

## Signal Path

```
xorshift32 → profile generator → per-profile makeup gain
           → master low-pass (glided) → squared volume taper → output
```

Every parameter is interpolated per sample — gain, cutoff, and the switch
between profiles. Measured, no transition exceeds the signal's own steady-state
sample delta, so there is nothing to click.

## Calibration

`Tools/measure.swift` renders each profile offline and reports RMS and peak at
full volume:

```
brown  rms 0.1245 (-18.1 dBFS)   peak 0.529 (-5.5 dBFS)
pink   rms 0.1054 (-19.5 dBFS)   peak 0.435 (-7.2 dBFS)
white  rms 0.0889 (-21.0 dBFS)   peak 0.165 (-15.6 dBFS)
```

Targets are not equal RMS: the low-biased brown spectrum reads quieter and flat
white reads harsher at matched RMS, so brown sits ~3 dB hot and white ~1.5 dB
cool.

## Layout

```
Sources/Hum/
  HumApp.swift                      MenuBarExtra(.window) entry point, agent policy
  Audio/NoiseDSP.swift               lock-free, allocation-free render-thread DSP
  Audio/AudioEngineController.swift  engine graph, focus timer, sleep/wake
  Audio/GlobalHotkey.swift           ⌥⌘S global + local event monitors
  UI/PopoverView.swift               280 pt popover
  UI/WaveformView.swift              Béziered ribbon driven by the live gain scalar
  UI/Controls.swift                  profile pills, glyph sliders, focus chips
  UI/OnboardingView.swift            one-time quick guide
  UI/VisualEffect.swift              vibrancy bridge
  UI/Theme.swift                     per-profile accent palette
Tools/
  measure.swift                      offline RMS / peak calibration harness
  make-icon.swift                    CoreGraphics app icon renderer
```

## License

MIT

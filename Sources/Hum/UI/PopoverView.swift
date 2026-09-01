import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var engine: AudioEngineController

    @StateObject private var loginItem = LoginItemController()

    /// Single source of truth for the accent, so every tinted control changes
    /// together when the profile does.
    private var accent: Color { engine.profile.accent }

    var body: some View {
        controls
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(width: Theme.popoverWidth)
            .background {
                ZStack {
                    VisualEffectBackground(material: .hudWindow, blending: .behindWindow)
                    // Darkens the vibrancy so light text keeps its contrast.
                    Color.black.opacity(Theme.scrim)
                }
                .background(WindowBackdropCleaner())
                .ignoresSafeArea()
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .overlay(
                // Specular edge: a hint of light along the rim, not an outline.
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.45), value: engine.profile)
            .contextMenu {
                Button("Quit Hum") { NSApp.terminate(nil) }
            }
    }

    private var controls: some View {
        VStack(spacing: 0) {
            header

            // Its own view, so a 30 Hz gain update redraws the ribbon alone
            // rather than invalidating the whole popover body.
            WaveformSection(visuals: engine.visuals,
                            profile: engine.profile,
                            warmth: engine.warmth,
                            accent: accent)
                .padding(.top, 2)

            PlaybackHero(isPlaying: engine.isPlaying, accent: accent, action: engine.toggle)

            VStack(spacing: 10) {
                ProfilePicker(selection: $engine.profile, accent: accent)

                CardSurface {
                    VStack(spacing: 11) {
                        VStack(spacing: 4) {
                            SectionLabel(text: "Volume",
                                         trailing: "\(Int((engine.volume * 100).rounded()))%")
                            GlyphSlider(leading: "speaker.fill",
                                        trailing: "speaker.wave.3.fill",
                                        label: "Volume",
                                        accent: accent,
                                        value: $engine.volume)
                        }

                        VStack(spacing: 4) {
                            SectionLabel(text: "Warmth",
                                         trailing: "\(Int((engine.warmth * 100).rounded()))%")
                            GlyphSlider(leading: "waveform.badge.minus",
                                        trailing: "waveform.badge.plus",
                                        label: "Warmth",
                                        accent: accent,
                                        value: $engine.warmth)
                        }
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 10)
                }

                CardSurface {
                    VStack(spacing: 6) {
                        SectionLabel(text: "Focus", trailing: engine.remainingText)
                        FocusChips(selection: $engine.duration, accent: accent)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 10)
                }
            }
            .padding(.top, 12)

            if loginItem.isAvailable { loginItemRow }
            quitRow
        }
        .onAppear {
            loginItem.refresh()
            engine.isPopoverVisible = true
        }
        .onDisappear { engine.isPopoverVisible = false }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItem.refresh()
        }
    }

    // MARK: Sections

    /// Anchors the panel: a breathing mark, the wordmark, and a line that says
    /// what is currently playing — replacing a bare title over a hard divider.
    private var header: some View {
        VStack(spacing: 5) {
            PulsingGlyph(accent: accent, size: 16, glowRadius: 38, active: engine.isPlaying)
                .frame(height: 32)

            Text("Hum")
                .font(.headline.weight(.semibold))

            Text(engine.profile.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                // Fixed height keeps the layout still between profiles.
                .frame(height: 14)
        }
    }

    private var loginItemRow: some View {
        VStack(spacing: 4) {
            CardSurface {
                HStack {
                    Text("Launch at Login")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .tint(accent)
                    .accessibilityLabel("Launch at Login")
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
            }

            // macOS will not let an app re-enable a login item the user turned
            // off in System Settings, so point them there rather than let the
            // switch snap back with no explanation.
            if loginItem.requiresApproval {
                Button("Approve in Login Items") { loginItem.openLoginItemsSettings() }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 10)
    }

    /// Quit lives here rather than in the header, so the top of the popover
    /// stays free of chrome. ⌘Q works whenever the popover has focus.
    private var quitRow: some View {
        QuitButton()
            .padding(.top, 10)
    }
}

/// Isolates the waveform's subscription to `VisualizerState`.
private struct WaveformSection: View {
    @ObservedObject var visuals: VisualizerState
    var profile: NoiseProfile
    var warmth: Double
    var accent: Color

    var body: some View {
        WaveformView(gain: visuals.gain, profile: profile, warmth: warmth, accent: accent)
    }
}

/// Springy press feedback for the transport control.
private struct GlassPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// Foot control. Recedes until pointed at, then reads unmistakably as the
/// destructive action.
private struct QuitButton: View {
    @State private var isHovering = false

    var body: some View {
        Button { NSApp.terminate(nil) } label: {
            Text("Quit Hum")
                .font(.caption)
                .foregroundStyle(isHovering ? Color.red : Color.secondary.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.red.opacity(isHovering ? 0.12 : 0))
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .keyboardShortcut("q", modifiers: .command)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .frame(maxWidth: .infinity)
    }
}

/// Large transport control with a hover-revealed circular background.
private struct PlaybackHero: View {
    var isPlaying: Bool
    var accent: Color
    var action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.thinMaterial)
                    .overlay(Circle().fill(Color.white.opacity(isHovering ? 0.14 : 0.07)))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    .frame(width: 52, height: 52)

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isPlaying ? accent : .white)
                    // Optical centring: the play triangle's mass sits left of centre.
                    .offset(x: isPlaying ? 0 : 1.5)
            }
            .contentShape(Circle())
        }
        .buttonStyle(GlassPressStyle())
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isHovering)
        .animation(.easeOut(duration: 0.15), value: isPlaying)
        .accessibilityLabel(isPlaying ? "Pause" : "Play")
    }
}

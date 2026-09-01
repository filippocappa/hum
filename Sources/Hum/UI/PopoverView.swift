import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var engine: AudioEngineController

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    /// Whether the global half of ⌥⌘S can actually fire. Polled on appear and
    /// on activation, since the user grants it in System Settings, not here.
    @StateObject private var loginItem = LoginItemController()

    @State private var hotkeyTrusted = GlobalHotkey.isTrusted

    /// Single source of truth for the accent, so every tinted control changes
    /// together when the profile does.
    private var accent: Color { engine.profile.accent }

    var body: some View {
        Group {
            if hasSeenOnboarding { controls } else { onboarding }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .frame(width: Theme.popoverWidth)
        .background {
            VisualEffectBackground(material: .hudWindow, blending: .behindWindow)
                .background(WindowBackdropCleaner())
                .ignoresSafeArea()
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        .overlay(
            // Specular edge: a hint of light along the rim, not a drawn outline.
            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.45), value: engine.profile)
        .contextMenu {
            Button("Quit Hum") { NSApp.terminate(nil) }
        }
    }

    private var onboarding: some View {
        OnboardingView {
            withAnimation(.easeOut(duration: 0.25)) { hasSeenOnboarding = true }
        }
    }

    private func refreshTrust() {
        withAnimation(.easeOut(duration: 0.2)) { hotkeyTrusted = GlobalHotkey.isTrusted }
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

            VStack(spacing: 12) {
                profileSection

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

                VStack(spacing: 5) {
                    SectionLabel(text: "Focus", trailing: engine.remainingText)
                    FocusChips(selection: $engine.duration, accent: accent)
                }
            }
            .padding(.top, 10)

            if loginItem.isAvailable { loginItemRow }
            if !hotkeyTrusted { hotkeyHint }
            quitRow
        }
        .onAppear {
            refreshTrust()
            loginItem.refresh()
            engine.isPopoverVisible = true
        }
        .onDisappear { engine.isPopoverVisible = false }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshTrust()
            loginItem.refresh()
        }
    }

    /// macOS withholds global key events until the process is trusted for
    /// Accessibility, and does so silently — so say it rather than let the
    /// shortcut appear broken.
    /// macOS withholds global key events until the process is trusted for
    /// Accessibility, and does so silently. A faint grey caption reads as
    /// something to ignore, so this states the problem and is itself the fix.
    private var loginItemRow: some View {
        VStack(spacing: 4) {
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
                .accessibilityLabel("Launch at Login")
            }

            // macOS will not let an app re-enable a login item the user turned
            // off in System Settings, so point them there instead of failing
            // silently with the switch snapping back.
            if loginItem.requiresApproval {
                Button("Approve in Login Items") { loginItem.openLoginItemsSettings() }
                    .buttonStyle(.plain)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 12)
    }

    private var hotkeyHint: some View {
        Button {
            GlobalHotkey.openAccessibilitySettings()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)

                Text("Enable ⌥⌘S in Accessibility")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.orange.opacity(0.14)))
            .overlay(Capsule().strokeBorder(Color.orange.opacity(0.28), lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Grant Accessibility access so the shortcut works system-wide")
        .padding(.top, 12)
        .transition(.opacity.combined(with: .scale(scale: 0.96)))
    }

    // MARK: Sections

    private var header: some View {
        Text("Hum")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .tracking(1.6)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
    }

    private var profileSection: some View {
        VStack(spacing: 6) {
            ProfilePicker(selection: $engine.profile, accent: accent)

            Text(engine.profile.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                // Fixed height keeps the layout from shifting between profiles.
                .frame(height: 14)
                .animation(.easeOut(duration: 0.15), value: engine.profile)
        }
    }

    /// Quit lives here rather than in the header, so the top of the popover
    /// stays free of chrome. ⌘Q works whenever the popover has focus.
    private var quitRow: some View {
        QuitButton()
            .padding(.top, 12)
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

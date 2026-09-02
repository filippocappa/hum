import KeyboardShortcuts
import SwiftUI

/// First-run splash. Staged entrance: the ambient glow settles first, then the
/// wordmark, then each card in turn — so the eye is led down the window rather
/// than presented with everything at once.
struct SplashView: View {
    var onDismiss: () -> Void

    @StateObject private var loginItem = LoginItemController()

    @State private var glowIn = false
    @State private var titleIn = false
    @State private var cardsIn = 0
    @State private var actionIn = false
    @State private var hoveredCard: Int?

    /// White is the cold-launch default, so the splash wears its silver — the
    /// user lands on exactly the accent they were just shown.
    private let profile = NoiseProfile.white
    private var accent: Color { profile.accent }

    private static let spring = Animation.spring(response: 0.6, dampingFraction: 0.75)
    private static let cardSpring = Animation.spring(response: 0.55, dampingFraction: 0.8)

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                header
                cards.padding(.top, 20)
                Spacer(minLength: 12)
                footer
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)
            .padding(.bottom, 24)
        }
        .frame(width: SplashWindowController.size.width, height: SplashWindowController.size.height)
        .onAppear(perform: runEntrance)
    }

    // MARK: Backdrop

    private var backdrop: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow, blending: .behindWindow)

            // Ambient glow, breathing slowly behind the content.
            RadialGradient(
                colors: [accent.opacity(glowIn ? 0.22 : 0), .clear],
                center: .init(x: 0.5, y: 0.28),
                startRadius: 8,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            PulsingGlyph(accent: accent, size: 26, glowRadius: 68)
                .frame(height: 56)
                .scaleEffect(glowIn ? 1 : 0.8)
                .opacity(glowIn ? 1 : 0)

            Text("Hum")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .tracking(0.5)

            Text("Pure hum, generated live.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .offset(y: titleIn ? 0 : -8)
        .opacity(titleIn ? 1 : 0)
    }

    // MARK: Cards

    private var cards: some View {
        VStack(spacing: 7) {
            card(index: 0, symbol: "waveform.path.ecg",
                 title: "Mathematical noise profiles",
                 detail: "White, Pink and Deep Brown, synthesised sample by sample.")

            card(index: 1, symbol: "dial.medium",
                 title: "Adaptive warmth filter",
                 detail: "A Butterworth biquad sweeping seismic rumble to open velvet.")

            card(index: 2, symbol: "command",
                 title: "Global hotkey",
                 detail: "Toggle from any app, no permissions needed.") {
                KeyboardShortcuts.Recorder(for: .togglePlayPause)
                    .controlSize(.small)
                    .fixedSize()
            }

            if loginItem.isAvailable {
                card(index: 3, symbol: "power",
                     title: "Launch at Login",
                     detail: "Start automatically in your menu bar when your Mac turns on.") {
                    Toggle("", isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .tint(accent)
                    .accessibilityLabel("Launch at Login")
                }
            }
        }
    }

    private func card(index: Int, symbol: String, title: String, detail: String?,
                      @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(hoveredCard == index ? Theme.cardFillHover : Theme.cardFill))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Theme.cardStroke, lineWidth: 1))
        .onHover { hoveredCard = $0 ? index : nil }
        .animation(.easeOut(duration: 0.15), value: hoveredCard)
        .opacity(cardsIn > index ? 1 : 0)
        .offset(y: cardsIn > index ? 0 : 20)
    }

    // MARK: Footer

    private var footer: some View {
        StartButton(accent: accent, foreground: profile.onAccent, action: onDismiss)
            .opacity(actionIn ? 1 : 0)
            .offset(y: actionIn ? 0 : 10)
    }

    // MARK: Entrance

    /// 0.0 glyph · 0.1 title · 0.2–0.5 cards · 0.6 action.
    private func runEntrance() {
        withAnimation(Self.spring) { glowIn = true }
        withAnimation(Self.cardSpring.delay(0.1)) { titleIn = true }
        for i in 1...4 {
            withAnimation(Self.cardSpring.delay(0.2 + Double(i - 1) * 0.1)) { cardsIn = i }
        }
        withAnimation(Self.cardSpring.delay(0.6)) { actionIn = true }
    }
}

/// Primary action with a specular sheen that brightens under the pointer.
private struct StartButton: View {
    var accent: Color
    var foreground: Color
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("Start Focusing")
                .font(.body.weight(.semibold))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    Capsule()
                        .fill(LinearGradient(
                            colors: [accent.opacity(hovering ? 0.95 : 0.85), accent],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .overlay(
                            // Specular top edge, the way light lands on glass.
                            Capsule().stroke(
                                LinearGradient(
                                    colors: [.white.opacity(hovering ? 0.5 : 0.32), .white.opacity(0.06)],
                                    startPoint: .top, endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                        )
                )
                .shadow(color: accent.opacity(hovering ? 0.45 : 0.22), radius: hovering ? 18 : 9, y: 3)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering ? 1.02 : 1)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
    }
}

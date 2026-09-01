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
    @State private var pulse = false

    /// The splash has no live audio to react to, so it borrows brown's caramel.
    private let accent = NoiseProfile.brown.accent

    private static let spring = Animation.spring(response: 0.6, dampingFraction: 0.75)

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                header
                cards.padding(.top, 22)
                Spacer(minLength: 12)
                footer
            }
            .padding(.horizontal, 34)
            .padding(.top, 34)
            .padding(.bottom, 26)
        }
        .frame(width: 520, height: 380)
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
                endRadius: pulse ? 420 : 320
            )
            .blur(radius: 18)
            .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: pulse)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.16))
                    .frame(width: 54, height: 54)
                    .blur(radius: 6)

                Image(systemName: "waveform")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(accent)
            }

            Text("Hum")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .tracking(0.5)

            Text("Pure hum, generated live.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .scaleEffect(titleIn ? 1 : 0.88)
        .opacity(titleIn ? 1 : 0)
    }

    // MARK: Cards

    private var cards: some View {
        VStack(spacing: 8) {
            card(index: 0, symbol: "waveform.path.ecg",
                 title: "Mathematical noise profiles",
                 detail: "White, Pink and Deep Brown, synthesised sample by sample.")

            card(index: 1, symbol: "dial.medium",
                 title: "Adaptive warmth filter",
                 detail: "A Butterworth biquad sweeping seismic rumble to open velvet.")

            card(index: 2, symbol: "command", title: "Global hotkey", detail: nil) {
                KeyboardShortcuts.Recorder(for: .togglePlayPause)
                    .controlSize(.small)
                    .fixedSize()
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
            .fill(Color.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
            .strokeBorder(Color.white.opacity(0.09), lineWidth: 1))
        .opacity(cardsIn > index ? 1 : 0)
        .offset(y: cardsIn > index ? 0 : 14)
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 14) {
            if loginItem.isAvailable {
                HStack(spacing: 8) {
                    Text("Launch at Login")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("", isOn: Binding(
                        get: { loginItem.isEnabled },
                        set: { loginItem.setEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                }
            }

            StartButton(accent: accent, action: onDismiss)
        }
        .opacity(actionIn ? 1 : 0)
        .offset(y: actionIn ? 0 : 10)
    }

    // MARK: Entrance

    private func runEntrance() {
        withAnimation(.easeOut(duration: 0.8)) { glowIn = true }
        pulse = true
        withAnimation(Self.spring.delay(0.08)) { titleIn = true }
        for i in 1...3 {
            withAnimation(Self.spring.delay(0.22 + Double(i - 1) * 0.09)) { cardsIn = i }
        }
        withAnimation(Self.spring.delay(0.58)) { actionIn = true }
    }
}

/// Primary action with a specular sheen that brightens under the pointer.
private struct StartButton: View {
    var accent: Color
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text("Start Focusing")
                .font(.callout.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 26)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(accent.opacity(hovering ? 0.42 : 0.30))
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
                .shadow(color: accent.opacity(hovering ? 0.35 : 0.18), radius: hovering ? 14 : 8, y: 3)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleEffect(hovering ? 1.03 : 1)
        .onHover { hovering = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovering)
    }
}

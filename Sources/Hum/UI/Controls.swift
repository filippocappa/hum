import SwiftUI

/// Capsule pill group for the noise profile, tinted by the active accent.
struct ProfilePicker: View {
    @Binding var selection: NoiseProfile
    var accent: Color

    var body: some View {
        HStack(spacing: 3) {
            ForEach(NoiseProfile.allCases) { profile in
                let selected = profile == selection

                Button {
                    withAnimation(Theme.accentTransition) { selection = profile }
                } label: {
                    Text(profile.title)
                        .font(.caption)
                        .fontWeight(selected ? .semibold : .regular)
                        .foregroundStyle(selected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(accent.opacity(0.34))
                                    .overlay(Capsule().strokeBorder(accent.opacity(0.55), lineWidth: 1))
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.black.opacity(0.18)))
        .overlay(Capsule().strokeBorder(Theme.cardStroke, lineWidth: 1))
        .animation(Theme.accentTransition, value: selection)
    }
}

/// Slider drawn by hand rather than `Slider`, so the fill carries the profile
/// accent and the thumb can take a specular rim. The stock control tints its
/// track but leaves a flat system thumb that reads as foreign here.
struct HumSlider: View {
    @Binding var value: Double
    var accent: Color
    var label: String

    private let track: CGFloat = 5
    private let thumb: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let span = max(geo.size.width - thumb, 1)
            let x = span * CGFloat(min(max(value, 0), 1))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: track)
                    .overlay(Capsule().strokeBorder(Color.black.opacity(0.20), lineWidth: 0.5))

                Capsule()
                    .fill(LinearGradient(colors: [accent.opacity(0.75), accent],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: x + thumb / 2, height: track)

                Circle()
                    .fill(.white)
                    // Specular rim: brighter at the top edge, as light lands.
                    .overlay(
                        Circle().strokeBorder(
                            LinearGradient(colors: [.white, .white.opacity(0.35)],
                                           startPoint: .top, endPoint: .bottom),
                            lineWidth: 0.5
                        )
                    )
                    .frame(width: thumb, height: thumb)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
                    .offset(x: x)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    value = min(1, max(0, Double((g.location.x - thumb / 2) / span)))
                }
            )
        }
        .frame(height: thumb)
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(Int((value * 100).rounded())) percent")
        .accessibilityAdjustableAction { direction in
            value = min(1, max(0, value + (direction == .increment ? 0.05 : -0.05)))
        }
    }
}

/// Glyph-flanked slider row, the shared shape of both audio controls.
struct GlyphSlider: View {
    let leading: String
    let trailing: String
    let label: String
    var accent: Color
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: leading)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .frame(width: 14)
                .accessibilityHidden(true)

            HumSlider(value: $value, accent: accent, label: label)

            Image(systemName: trailing)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .frame(width: 14)
                .accessibilityHidden(true)
        }
    }
}

/// Focus-duration chips.
struct FocusChips: View {
    @Binding var selection: FocusDuration
    var accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FocusDuration.allCases) { option in
                let selected = option == selection

                Button {
                    withAnimation(Theme.accentTransition) { selection = option }
                } label: {
                    Text(option.label)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(selected ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(selected ? accent.opacity(0.30) : .clear))
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? accent.opacity(0.5) : .clear, lineWidth: 1)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .animation(Theme.accentTransition, value: selection)
    }
}

/// The focus card, in one of two states: the duration picker while idle, or a
/// running session with its own transport and countdown.
///
/// The two states share a `matchedGeometryEffect`, so the ∞ pill physically
/// travels into the stop pill rather than one row fading out while another
/// fades in.
struct FocusCard: View {
    /// Held without observing — a tick must not re-render this card, only the
    /// label that shows it. See `CountdownLabel`.
    let focus: FocusTimerState
    @Binding var duration: FocusDuration
    var isPlaying: Bool
    var accent: Color
    var onCancel: () -> Void
    var onToggle: () -> Void

    @Namespace private var morph

    private static let morphSpring = Animation.spring(response: 0.42, dampingFraction: 0.76)

    var body: some View {
        CardSurface {
            VStack(spacing: 7) {
                SectionLabel(text: duration == .continuous ? "Focus" : "Session")

                ZStack {
                    if duration == .continuous {
                        pills
                    } else {
                        session
                    }
                }
                .frame(height: 22)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
        }
        .animation(Self.morphSpring, value: duration)
    }

    // MARK: Idle

    private var pills: some View {
        HStack(spacing: 4) {
            ForEach(FocusDuration.allCases) { option in
                let selected = option == duration

                Button {
                    withAnimation(Self.morphSpring) { duration = option }
                } label: {
                    Text(option.label)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(selected ? .white : .secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if option == .continuous {
                                // The anchor that becomes the stop pill.
                                pillBackground(filled: selected)
                                    .matchedGeometryEffect(id: "leading", in: morph)
                            } else {
                                pillBackground(filled: selected)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }
        }
    }

    // MARK: Active

    private var session: some View {
        HStack(spacing: 5) {
            ActionPill(symbol: "xmark", accent: accent, filled: false, action: onCancel)
                .matchedGeometryEffect(id: "leading", in: morph)
                .accessibilityLabel("End session")

            ActionPill(symbol: isPlaying ? "pause.fill" : "play.fill",
                       accent: accent, filled: isPlaying, action: onToggle)
                .accessibilityLabel(isPlaying ? "Pause" : "Play")
                .transition(.scale(scale: 0.7).combined(with: .opacity))

            Spacer(minLength: 6)

            CountdownLabel(focus: focus, accent: accent)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
                .padding(.trailing, 2)
        }
    }

    private func pillBackground(filled: Bool) -> some View {
        Capsule()
            .fill(filled ? accent.opacity(0.30) : Color.clear)
            .overlay(Capsule().strokeBorder(filled ? accent.opacity(0.5) : .clear, lineWidth: 1))
    }
}

/// Pill-shaped control matching the duration pills, so the morph lands on a
/// shape the eye already knows.
private struct ActionPill: View {
    var symbol: String
    var accent: Color
    var filled: Bool
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(filled ? .white : .secondary)
                .frame(width: 38, height: 22)
                .background(
                    Capsule().fill(filled ? accent.opacity(0.30)
                                          : Color.white.opacity(hovering ? 0.10 : 0.06))
                )
                .overlay(
                    Capsule().strokeBorder(filled ? accent.opacity(0.5) : Theme.cardStroke,
                                           lineWidth: 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// The only view that observes the countdown, so a tick invalidates this label
/// alone rather than the card or the popover around it.
private struct CountdownLabel: View {
    @ObservedObject var focus: FocusTimerState
    var accent: Color

    var body: some View {
        Text(focus.text)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundStyle(accent)
            // Static ambient glow in the active accent; nothing animates, so it
            // costs nothing per frame.
            .shadow(color: accent.opacity(0.45), radius: 5)
            .contentTransition(.numericText(countsDown: true))
            .animation(.easeOut(duration: 0.2), value: focus.secondsRemaining)
            .accessibilityLabel("Time remaining")
    }
}

/// Caption row above a control group.
struct SectionLabel: View {
    let text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Translucent grouping surface shared by the popover and the splash.
struct CardSurface<Content: View>: View {
    var hovered: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(hovered ? Theme.cardFillHover : Theme.cardFill))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Theme.cardStroke, lineWidth: 1))
    }
}

/// The pulsing waveform mark that anchors both windows. The glow is a Core
/// Animation layer; see `PulseLayer.swift` for why it is not a SwiftUI animation.
struct PulsingGlyph: View {
    var accent: Color
    var size: CGFloat
    var glowRadius: CGFloat
    /// When false the mark holds still, costing nothing.
    var active: Bool = true

    var body: some View {
        ZStack {
            PulseGlowView(accent: accent, active: active)
                .frame(width: glowRadius, height: glowRadius)
                .allowsHitTesting(false)

            Image(systemName: "waveform")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(accent)
        }
        .animation(Theme.accentTransition, value: accent)
    }
}

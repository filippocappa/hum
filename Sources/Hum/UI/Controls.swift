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

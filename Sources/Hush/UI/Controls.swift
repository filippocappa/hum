import SwiftUI

/// Capsule pill group for the noise profile. Custom rather than a native
/// segmented picker because the selection indicator has to carry the profile's
/// own accent, which `.pickerStyle(.segmented)` will not tint per-segment.
struct ProfilePicker: View {
    @Binding var selection: NoiseProfile
    var accent: Color

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: 3) {
            ForEach(NoiseProfile.allCases) { profile in
                let selected = profile == selection

                Button {
                    selection = profile
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
                                    .fill(accent.opacity(0.32))
                                    .overlay(Capsule().strokeBorder(accent.opacity(0.55), lineWidth: 1))
                                    .matchedGeometryEffect(id: "selection", in: indicator)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.06)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: selection)
    }
}

/// Stock slider flanked by SF Symbol glyphs — the shared shape of both audio
/// controls, so volume and warmth read as one family.
struct GlyphSlider: View {
    let leading: String
    let trailing: String
    let label: String
    var accent: Color
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: leading)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .frame(width: 14)
                .accessibilityHidden(true)

            Slider(value: $value, in: 0...1)
                .controlSize(.small)
                .tint(accent)
                .accessibilityLabel(label)

            Image(systemName: trailing)
                .foregroundStyle(.secondary)
                .imageScale(.small)
                .frame(width: 14)
                .accessibilityHidden(true)
        }
    }
}

/// Borderless focus-duration chips.
struct FocusChips: View {
    @Binding var selection: FocusDuration
    var accent: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FocusDuration.allCases) { option in
                let selected = option == selection

                Button {
                    selection = option
                } label: {
                    Text(option.label)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(selected ? accent : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(selected ? accent.opacity(0.16) : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
            }
        }
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

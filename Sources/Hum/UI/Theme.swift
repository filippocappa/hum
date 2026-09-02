import SwiftUI

/// Neutral, system-native vocabulary. Accent follows the user's macOS accent
/// colour rather than imposing a brand hue.
enum Theme {
    static let active = Color.green

    static let hairline = Color.primary.opacity(0.08)

    /// Card surfaces, shared by the splash rows and the popover groups.
    static let cardFill = Color.white.opacity(0.04)
    static let cardFillHover = Color.white.opacity(0.08)
    static let cardStroke = Color.white.opacity(0.08)

    /// Darkening laid over the vibrancy so light text keeps its contrast.
    /// Raising this trades legibility for translucency — the wallpaper reads
    /// through less the higher it goes.
    static let scrim = 0.30

    /// Every accent-driven change uses this exact curve, so the glyph, pills,
    /// slider fills and chips cross-fade as one rather than at three speeds.
    static let accentTransition = Animation.easeInOut(duration: 0.25)
    static let track = Color.primary.opacity(0.10)

    static let popoverWidth: CGFloat = 280
    static let cornerRadius: CGFloat = 20
}

extension NoiseProfile {
    /// Each profile carries its own accent, chosen to match how the noise reads:
    /// caramel for the deep rumble, rose for the mid-forward hiss, ice for the
    /// bright one. Kept in the UI layer so the DSP stays free of SwiftUI.
    /// Legible foreground on top of a near-opaque `accent` fill. White reads
    /// fine on amber and coral, but vanishes on silver.
    var onAccent: Color {
        self == .white ? Color(red: 0.10, green: 0.10, blue: 0.12) : .white
    }

    var accent: Color {
        switch self {
        // #CC8F57 — an actual tan-brown. True brown is too dark to read on a
        // dark panel, so this is lifted in value while keeping the hue earthy
        // rather than orange.
        case .brown: return Color(red: 0.80, green: 0.56, blue: 0.34)
        // #FF80B8 — magenta-leaning, so it reads pink rather than coral.
        case .pink:  return Color(red: 1.00, green: 0.50, blue: 0.72)
        case .white: return Color(red: 0.86, green: 0.90, blue: 0.96)
        }
    }
}

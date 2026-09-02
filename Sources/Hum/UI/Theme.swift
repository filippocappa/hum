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
    var accent: Color {
        switch self {
        // #FF9F0A — the system amber, warm enough to read as "deep".
        case .brown: return Color(red: 1.00, green: 0.62, blue: 0.04)
        case .pink:  return Color(red: 0.98, green: 0.48, blue: 0.52)
        case .white: return Color(red: 0.86, green: 0.90, blue: 0.96)
        }
    }
}

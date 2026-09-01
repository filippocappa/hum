import SwiftUI

/// Neutral, system-native vocabulary. Accent follows the user's macOS accent
/// colour rather than imposing a brand hue.
enum Theme {
    static let active = Color.green

    static let hairline = Color.primary.opacity(0.08)
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
        case .brown: return Color(red: 0.85, green: 0.55, blue: 0.25)
        case .pink:  return Color(red: 0.92, green: 0.45, blue: 0.55)
        case .white: return Color(red: 0.75, green: 0.85, blue: 0.98)
        }
    }
}

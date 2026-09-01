import SwiftUI

/// One-time quick guide. Shown in place of the controls on first launch only,
/// then never again — dismissal is persisted in `UserDefaults`.
struct OnboardingView: View {
    var onDismiss: () -> Void

    private let points: [(symbol: String, text: String)] = [
        ("waveform", "Choose your frequency — White, Pink, or Deep Brown."),
        ("dial.low", "Adjust Warmth to filter out high-frequency harshness."),
        ("command", "Press ⌥⌘S anywhere to toggle focus instantly.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Hum")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(.secondary)

            Text("Pure hum, generated live.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(points, id: \.text) { point in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: point.symbol)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                        Text(point.text)
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.top, 18)

            Button(action: onDismiss) {
                Text("Get to Work")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
        }
    }
}

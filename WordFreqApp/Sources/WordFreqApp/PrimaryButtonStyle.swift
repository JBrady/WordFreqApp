import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    var isFocused: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [AppTheme.primaryAccent, AppTheme.secondaryAccent],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            }
            .brightness(configuration.isPressed ? -0.06 : 0)
            .saturation(configuration.isPressed ? 0.92 : 1.0)
            .shadow(color: Color.black.opacity(0.14), radius: 3, y: 1)
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                    .stroke(AppTheme.focusGlow.opacity(isFocused ? 0.85 : 0.0), lineWidth: 1.5)
            }
            .shadow(color: AppTheme.focusGlow.opacity(isFocused ? 0.45 : 0.0), radius: 8, y: 0)
            .scaleEffect(configuration.isPressed ? 0.995 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: isFocused)
    }
}

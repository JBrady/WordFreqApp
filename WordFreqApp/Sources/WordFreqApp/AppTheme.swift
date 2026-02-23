import AppKit
import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 14
    static let buttonCornerRadius: CGFloat = 12
    static let pagePadding: CGFloat = 24
    static let paneGap: CGFloat = 20
    static let cardPadding: CGFloat = 20

    static func pageGradient(for colorScheme: ColorScheme) -> LinearGradient {
        let colors: [Color]
        if colorScheme == .dark {
            colors = [
                Color(nsColor: .init(red: 0.07, green: 0.10, blue: 0.16, alpha: 1.0)).opacity(0.96),
                Color(nsColor: .init(red: 0.10, green: 0.16, blue: 0.28, alpha: 1.0)).opacity(0.94),
                Color(nsColor: .init(red: 0.11, green: 0.24, blue: 0.30, alpha: 1.0)).opacity(0.92)
            ]
        } else {
            colors = [
                Color(nsColor: .init(red: 0.82, green: 0.88, blue: 0.96, alpha: 1.0)).opacity(0.90),
                Color(nsColor: .init(red: 0.75, green: 0.83, blue: 0.92, alpha: 1.0)).opacity(0.88),
                Color(nsColor: .init(red: 0.67, green: 0.78, blue: 0.90, alpha: 1.0)).opacity(0.86)
            ]
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func contentScrim(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.black.opacity(0.22) : Color.white.opacity(0.40)
    }

    static var cardStroke: Color {
        Color.white.opacity(0.24)
    }

    static var panelShadow: Color {
        Color.black.opacity(0.12)
    }

    static var primaryAccent: Color {
        Color(nsColor: .init(red: 0.12, green: 0.64, blue: 0.95, alpha: 1.0))
    }

    static var secondaryAccent: Color {
        Color(nsColor: .init(red: 0.83, green: 0.28, blue: 0.84, alpha: 1.0))
    }

    static var focusGlow: Color {
        Color(nsColor: .init(red: 0.30, green: 0.72, blue: 1.0, alpha: 1.0))
    }

    static var success: Color {
        Color(nsColor: .init(red: 0.16, green: 0.64, blue: 0.36, alpha: 1.0))
    }
}

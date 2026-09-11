import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum CertWatchTheme {
    static let canvas = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let cardFill = Color(red: 0.11, green: 0.12, blue: 0.15)
    static let cardBorderTop = Color.white.opacity(0.12)
    static let cardBorderBottom = Color.white.opacity(0.04)

    static let healthy = Color(red: 0.06, green: 0.73, blue: 0.51)   // #10B981
    static let warning = Color(red: 0.96, green: 0.62, blue: 0.04)   // #F59E0B
    static let critical = Color(red: 0.94, green: 0.27, blue: 0.27)  // #EF4444
    static let muted = Color(red: 0.42, green: 0.45, blue: 0.50)     // #6B7280

    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)

    static let widgetCanvas = adaptiveColor(
        dark: UIColor(red: 0.07, green: 0.08, blue: 0.10, alpha: 1),
        light: UIColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1)
    )
    static let widgetPrimaryText = adaptiveColor(
        dark: .white,
        light: UIColor(red: 0.09, green: 0.10, blue: 0.12, alpha: 1)
    )
    static let widgetSecondaryText = adaptiveColor(
        dark: UIColor.white.withAlphaComponent(0.62),
        light: UIColor(red: 0.42, green: 0.45, blue: 0.50, alpha: 1)
    )

    static func monospaced(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    private static func adaptiveColor(dark: UIColor, light: UIColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}

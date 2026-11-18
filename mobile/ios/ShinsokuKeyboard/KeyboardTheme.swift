import UIKit

/// DESIGN.md §2–§3 tokens for the keyboard extension. Colours resolve light/dark from the trait collection.
enum KeyboardTheme {
    static let canvas = dynamic(dark: 0x101314, light: 0xF7F8F8)
    static let frame = dynamic(dark: 0x161A1B, light: 0xEEF1F1)
    static let raised = dynamic(dark: 0x1D2224, light: 0xFFFFFF)
    static let text = dynamic(dark: 0xE3E9EA, light: 0x1C2426)
    static let textSecondary = dynamic(dark: 0xAEB9BB, light: 0x4A5659)
    static let textTertiary = dynamic(dark: 0x848E90, light: 0x5F6A6D)
    static let hairline = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? rgb(0xE3E9EA, alpha: 0.08)
            : rgb(0x1C2426, alpha: 0.12)
    }
    static let accent = dynamic(dark: 0x6CC3CF, light: 0x1F6470)
    static let accentSubtle = dynamic(dark: 0x23464C, light: 0xD6ECEF)
    /// Text and icons on an accent fill: canvas (dark) / white (light).
    static let onAccent = dynamic(dark: 0x101314, light: 0xFFFFFF)
    static let success = dynamic(dark: 0xA6D189, light: 0x4F7A1F)
    static let warning = dynamic(dark: 0xE5C890, light: 0x8A6400)
    static let danger = dynamic(dark: 0xE78284, light: 0xB3261E)

    /// Pressed state for raised keys: raised + text at 8 %.
    static let raisedPressed = UIColor { trait in
        blend(raised.resolvedColor(with: trait), text.resolvedColor(with: trait), 0.08)
    }
    /// Pressed state for the accent key: accent blended 18 % towards canvas.
    static let accentPressed = UIColor { trait in
        blend(accent.resolvedColor(with: trait), canvas.resolvedColor(with: trait), 0.18)
    }

    static let controlRadius: CGFloat = 10
    static let spacing: CGFloat = 8
    static let margin: CGFloat = 8
    static let statusRowHeight: CGFloat = 28
    static let minKeyHeight: CGFloat = 44
    static let minRecordHeight: CGFloat = 56

    static let statusFont = UIFont.systemFont(ofSize: 13, weight: .regular)
    static let keyFont = UIFont.systemFont(ofSize: 15, weight: .regular)
    static let keyTitleFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
    static let captionFont = UIFont.systemFont(ofSize: 12, weight: .regular)

    private static func dynamic(dark: UInt32, light: UInt32) -> UIColor {
        UIColor { trait in
            trait.userInterfaceStyle == .dark ? rgb(dark) : rgb(light)
        }
    }

    private static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static func blend(_ base: UIColor, _ over: UIColor, _ amount: CGFloat) -> UIColor {
        var (r1, g1, b1, a1): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        var (r2, g2, b2, a2): (CGFloat, CGFloat, CGFloat, CGFloat) = (0, 0, 0, 0)
        base.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        over.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(
            red: r1 + (r2 - r1) * amount,
            green: g1 + (g2 - g1) * amount,
            blue: b1 + (b2 - b1) * amount,
            alpha: a1
        )
    }
}

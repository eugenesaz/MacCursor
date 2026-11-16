import CoreGraphics
import MacCursorCore

/// Colors that depend on what's behind the pointer.
/// CGColor is immutable, so sharing palettes across threads is safe.
public struct Palette: @unchecked Sendable {
    public let kind: PaletteKind
    public let outline: CGColor
    public let effect: CGColor

    /// Dark outline/effects: for light screens.
    public static let forLightScreens = Palette(
        kind: .forLightScreens, outline: rgb(0x141414), effect: rgb(0x141414))
    /// Light outline/effects ("sticker" look): for dark screens.
    public static func of(_ kind: PaletteKind) -> Palette {
        kind == .forDarkScreens ? .forDarkScreens : .forLightScreens
    }

    public static let forDarkScreens = Palette(
        kind: .forDarkScreens, outline: rgb(0xF4F4F4), effect: rgb(0xF4F4F4))
}

public func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

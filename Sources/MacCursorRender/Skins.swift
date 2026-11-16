import CoreGraphics
import MacCursorCore

/// Pointer styles. All art is original and drawn in code. Coordinates: the hotspot
/// (fingertip / paw tip) is at (0,0) and the paw extends downward (negative y).
public enum ParticleKind: Sendable { case bone, heart, dot }

public struct SkinArt {
    public var silhouette: CGPath
    public var fur: CGColor
    public var pads: CGPath? = nil
    public var padColor: CGColor = rgb(0x000000)
    public var nails: CGPath? = nil
    public var nailColor: CGColor = rgb(0x000000)
    /// 0 = no arm/leg.
    public var armWidth: CGFloat = 0
    /// Y where the leg attaches under the paw body.
    public var armTop: CGFloat = 0
    public var isRing = false
    /// Paw print left behind on click, centered at (0,0).
    public var stamp: CGPath? = nil
    /// Where the paw print sits relative to the tip (before rotation).
    public var stampOffsetY: CGFloat = 0
    public var particle: ParticleKind = .dot
    public var particleColor: CGColor = rgb(0xFFD23F)
    /// Fill of the leg or arm; nil means the same as `fur`.
    public var legColor: CGColor? = nil
}

/// Colors that depend on what's behind the pointer.
/// CGColor is immutable, so sharing palettes across threads is safe.
public struct Palette: @unchecked Sendable {
    public let outline: CGColor
    public let effect: CGColor

    /// Dark outline/effects: for light screens.
    public static let forLightScreens = Palette(outline: rgb(0x141414), effect: rgb(0x141414))
    /// Light outline/effects ("sticker" look): for dark screens.
    public static func of(_ kind: PaletteKind) -> Palette {
        kind == .forDarkScreens ? .forDarkScreens : .forLightScreens
    }

    public static let forDarkScreens = Palette(outline: rgb(0xF4F4F4), effect: rgb(0xF4F4F4))
}

public func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha)
}

typealias Oval = (x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat)

func ovals(_ list: [Oval]) -> CGMutablePath {
    let p = CGMutablePath()
    for o in list {
        p.addEllipse(in: CGRect(x: o.x - o.rx, y: o.y - o.ry, width: o.rx * 2, height: o.ry * 2))
    }
    return p
}

func moved(_ path: CGPath, dy: CGFloat, scale: CGFloat = 1) -> CGPath {
    var t = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: 0, y: dy)
    return path.copy(using: &t) ?? path
}

public enum Skins {
    /// The registry of built-in styles. Each style's art lives in its own file in `Styles/`.
    /// Adding a style: a `PointerStyle` case, a file in `Styles/`, a line here, and snapshots.
    public static func art(for kind: PointerStyle) -> SkinArt {
        switch kind {
        case .dogPaw: return dogPaw
        case .catPaw: return catPaw
        case .finger: return cartoonHand
        case .ring: return highlightRing
        }
    }

    public static func particlePath(_ kind: ParticleKind) -> CGPath {
        switch kind {
        case .bone:
            let p = CGMutablePath()
            p.addRoundedRect(
                in: CGRect(x: -6, y: -1.8, width: 12, height: 3.6), cornerWidth: 1.5,
                cornerHeight: 1.5)
            for (x, y) in [(-6.0, -1.8), (-6.0, 1.8), (6.0, -1.8), (6.0, 1.8)] {
                p.addEllipse(in: CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8))
            }
            return p
        case .heart:
            let p = CGMutablePath()
            p.addEllipse(in: CGRect(x: -6, y: -1.5, width: 6.4, height: 6.4))
            p.addEllipse(in: CGRect(x: -0.4, y: -1.5, width: 6.4, height: 6.4))
            p.move(to: CGPoint(x: -5.6, y: 0.6))
            p.addLine(to: CGPoint(x: 5.6, y: 0.6))
            p.addLine(to: CGPoint(x: 0, y: -6.5))
            p.closeSubpath()
            return p
        case .dot:
            return CGPath(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6), transform: nil)
        }
    }
}

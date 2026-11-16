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

private typealias Oval = (x: CGFloat, y: CGFloat, rx: CGFloat, ry: CGFloat)

private func ovals(_ list: [Oval]) -> CGMutablePath {
    let p = CGMutablePath()
    for o in list {
        p.addEllipse(in: CGRect(x: o.x - o.rx, y: o.y - o.ry, width: o.rx * 2, height: o.ry * 2))
    }
    return p
}

private func moved(_ path: CGPath, dy: CGFloat, scale: CGFloat = 1) -> CGPath {
    var t = CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: 0, y: dy)
    return path.copy(using: &t) ?? path
}

public enum Skins {
    public static func art(for kind: PointerStyle) -> SkinArt {
        switch kind {
        case .dogPaw:
            // Big, round, slightly splayed toes with visible nails.
            let toes: [Oval] = [
                (-19, -18, 8, 9), (-7, -10, 8.5, 10), (7, -10, 8.5, 10), (19, -18, 8, 9),
            ]
            let body: Oval = (0, -37, 23, 21)
            let toePads = toes.map { Oval($0.x, $0.y - 1.5, $0.rx * 0.6, $0.ry * 0.6) }
            let mainPad: [Oval] = [(0, -39, 11, 8.5), (-7, -44, 7.5, 6), (7, -44, 7.5, 6)]
            let pads = ovals(toePads + mainPad)
            let nails = ovals(toes.map { Oval($0.x * 1.08, $0.y + $0.ry - 1.2, 2, 3.2) })
            return SkinArt(
                silhouette: ovals(toes + [body]),
                fur: rgb(0xE8C08A),
                pads: pads, padColor: rgb(0x4A322B),
                nails: nails, nailColor: rgb(0x2B1E1A),
                armWidth: 24, armTop: -50,
                stamp: moved(pads, dy: 30, scale: 0.9), stampOffsetY: -26,
                particle: .bone, particleColor: rgb(0xFFF6E5))

        case .catPaw:
            // Smaller, rounder, pink toe beans, claws retracted.
            let toes: [Oval] = [
                (-15, -15, 6.5, 7), (-5.5, -8, 7, 8), (5.5, -8, 7, 8), (15, -15, 6.5, 7),
            ]
            let body: Oval = (0, -31, 19, 17.5)
            let beans = toes.map { Oval($0.x, $0.y - 1, $0.rx * 0.62, $0.ry * 0.62) }
            let mainPad: [Oval] = [(0, -33, 9, 7), (-5.5, -37, 6, 5), (5.5, -37, 6, 5)]
            let pads = ovals(beans + mainPad)
            return SkinArt(
                silhouette: ovals(toes + [body]),
                fur: rgb(0xFAFAFA),
                pads: pads, padColor: rgb(0xF59AB0),
                armWidth: 19, armTop: -42,
                stamp: moved(pads, dy: 25, scale: 0.9), stampOffsetY: -22,
                particle: .heart, particleColor: rgb(0xFF4D73))

        case .ring:
            return SkinArt(
                silhouette: ovals([(0, 0, 22, 22)]),
                fur: rgb(0xFFD23F, 0.35),
                isRing: true,
                particle: .dot, particleColor: rgb(0xFFD23F))
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

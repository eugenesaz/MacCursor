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

        case .finger:
            // A friendly cartoon hand pointing straight up: index finger out, the other
            // three fingers curled into a soft fist, thumb tucked across the front,
            // and a colored wristband cuff where the arm joins.
            func capsule(_ r: CGRect, angle: CGFloat = 0) -> CGPath {
                let rr = min(r.width, r.height) / 2
                var t = CGAffineTransform(translationX: r.midX, y: r.midY)
                    .rotated(by: angle).translatedBy(x: -r.midX, y: -r.midY)
                return CGPath(roundedRect: r, cornerWidth: rr, cornerHeight: rr, transform: &t)
            }
            func line(_ pts: [CGPoint], width: CGFloat = 1.6) -> CGPath {
                let p = CGMutablePath()
                p.addLines(between: pts)
                return p.copy(
                    strokingWithWidth: width, lineCap: .round, lineJoin: .round, miterLimit: 4)
            }

            // Index finger: its rounded top is a half circle whose apex is exactly (0,0).
            let finger = capsule(CGRect(x: -6.5, y: -30, width: 13, height: 30))
            // Fist body, a little wider to the right where the curled fingers are.
            let fist = CGPath(
                roundedRect: CGRect(x: -16, y: -46, width: 36, height: 26),
                cornerWidth: 10, cornerHeight: 10, transform: nil)
            // Curled fingers: three soft rolls stacked on the right, bulging past the fist.
            let rolls: [Oval] = [(13, -24, 8.5, 5.4), (14, -31.5, 8.5, 5.4), (13, -39, 8, 5.2)]
            // Thumb: a capsule lying diagonally across the front of the fist.
            let thumbAngle: CGFloat = 0.5
            let thumbC = CGPoint(x: -5, y: -38)
            let thumb = capsule(
                CGRect(x: thumbC.x - 11, y: thumbC.y - 5, width: 22, height: 10),
                angle: thumbAngle)
            // Palm heel tapering into the wrist, then the cuff over the arm (armWidth 18 before scaling).
            let heel = ovals([(1.5, -44.5, 14, 6.5)])
            let wrist = CGPath(rect: CGRect(x: -9, y: -54, width: 18, height: 10), transform: nil)
            let cuff = CGPath(
                roundedRect: CGRect(x: -12, y: -59, width: 24, height: 9),
                cornerWidth: 3, cornerHeight: 3, transform: nil)

            let hand = CGMutablePath()
            for p in [finger, fist, thumb, heel, wrist, cuff] { hand.addPath(p) }
            hand.addPath(ovals(rolls))

            // Details in a soft darker skin tone: creases between the curled fingers,
            // the thumb's top edge and the fingernail.
            let details = CGMutablePath()
            details.addPath(line([CGPoint(x: 7.5, y: -27.8), CGPoint(x: 20, y: -27.8)]))
            details.addPath(line([CGPoint(x: 9, y: -35.3), CGPoint(x: 19.5, y: -35.3)]))
            let u = CGPoint(x: cos(thumbAngle), y: sin(thumbAngle))
            let n = CGPoint(x: -u.y, y: u.x)
            let tipC = CGPoint(x: thumbC.x + 6 * u.x, y: thumbC.y + 6 * u.y)
            let thumbLine = CGMutablePath()
            thumbLine.move(
                to: CGPoint(x: thumbC.x - 7 * u.x + 5 * n.x, y: thumbC.y - 7 * u.y + 5 * n.y))
            thumbLine.addLine(to: CGPoint(x: tipC.x + 5 * n.x, y: tipC.y + 5 * n.y))
            thumbLine.addArc(
                center: tipC, radius: 5, startAngle: thumbAngle + .pi / 2,
                endAngle: thumbAngle - 0.5, clockwise: true)
            details.addPath(
                thumbLine.copy(
                    strokingWithWidth: 1.6, lineCap: .round,
                    lineJoin: .round, miterLimit: 4))
            details.addPath(
                CGPath(
                    roundedRect: CGRect(x: -3.7, y: -9, width: 7.4, height: 6.6),
                    cornerWidth: 3.7, cornerHeight: 3.3, transform: nil
                )
                .copy(strokingWithWidth: 1.4, lineCap: .round, lineJoin: .round, miterLimit: 4))

            // Scale everything about the tip so the hand matches the dog paw's size.
            let k: CGFloat = 1.18

            // Fingertip print for the click stamp: a small oval of concentric ridges.
            let print = CGMutablePath()
            for (i, r) in [(0, 7.0), (1, 4.8), (2, 2.6)] as [(Int, CGFloat)] {
                let ring = CGPath(
                    ellipseIn: CGRect(x: -r * 0.8, y: -r, width: r * 1.6, height: r * 2),
                    transform: nil)
                print.addPath(
                    i == 2
                        ? ring
                        : ring.copy(
                            strokingWithWidth: 1.3, lineCap: .round,
                            lineJoin: .round, miterLimit: 4))
            }

            return SkinArt(
                silhouette: moved(hand, dy: 0, scale: k),
                fur: rgb(0xFFD7B0),
                pads: moved(cuff, dy: 0, scale: k), padColor: rgb(0x3FA7D6),
                nails: moved(details, dy: 0, scale: k), nailColor: rgb(0xD9946A),
                armWidth: 18 * k, armTop: -58 * k,
                stamp: print, stampOffsetY: -5,
                particle: .dot, particleColor: rgb(0x4FB8E8))

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

import CoreGraphics

extension Skins {
    static var catPaw: StylePack {
        // A black cat's paw: four small oval toes in a tight arc, bright pink toe beans,
        // a three-lobed main pad, slim claws peeking out of the toes and a slim leg.
        // Paws point up, so the pad's three lobes face the wrist.
        func tilted(_ o: Oval, _ angle: CGFloat) -> CGPath {
            var t = CGAffineTransform(translationX: o.x, y: o.y).rotated(by: angle)
            return CGPath(
                ellipseIn: CGRect(x: -o.rx, y: -o.ry, width: o.rx * 2, height: o.ry * 2),
                transform: &t)
        }
        // A slim claw curving outward (side = -1 left, +1 right) from a toe's top.
        func claw(base: CGPoint, side: CGFloat, height h: CGFloat = 3.6) -> CGPath {
            let w: CGFloat = 2.1
            let tip = CGPoint(x: base.x + side * 1.6, y: base.y + h)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: base.x - side * w / 2, y: base.y - 1))
            p.addQuadCurve(
                to: tip, control: CGPoint(x: base.x - side * w * 0.45, y: base.y + h * 0.8))
            p.addQuadCurve(
                to: CGPoint(x: base.x + side * w / 2, y: base.y - 1),
                control: CGPoint(x: base.x + side * w * 0.55, y: base.y + h * 0.35))
            p.closeSubpath()
            return p
        }

        // (x, y, rx, ry, tilt): the outer toes lean out a little.
        let toes: [(o: Oval, tilt: CGFloat)] = [
            ((-12.2, -13, 4.3, 5.3), 0.32), ((-4, -7.5, 4.6, 5.6), 0.08),
            ((4, -7.5, 4.6, 5.6), -0.08), ((12.2, -13, 4.3, 5.3), -0.32),
        ]
        let body: Oval = (0, -26, 15, 13)
        // Claws: one per toe, rising out of its top; the middle two tips are the hotspot.
        let claws = CGMutablePath()
        for t in toes {
            let side: CGFloat = t.o.x < 0 ? -1 : 1
            let top = CGPoint(
                x: t.o.x - sin(t.tilt) * t.o.ry * 0.85,
                y: t.o.y + cos(t.tilt) * t.o.ry * 0.85)
            claws.addPath(claw(base: top, side: side, height: abs(t.o.x) < 8 ? 3.1 : 3.4))
        }
        let paw = CGMutablePath()
        for t in toes { paw.addPath(tilted(t.o, t.tilt)) }
        paw.addPath(ovals([body]))
        paw.addPath(claws)

        // Toe beans: plump ovals sitting a touch low in each toe.
        let pads = CGMutablePath()
        for t in toes {
            pads.addPath(
                tilted((t.o.x, t.o.y - 0.9, t.o.rx * 0.64, t.o.ry * 0.68), t.tilt))
        }
        // Main pad: a rounded top with three lobes underneath.
        pads.addPath(
            ovals([
                (0, -22.6, 6.8, 4.6), (-6, -27.4, 4.3, 4.4), (0, -29, 4.7, 4.6),
                (6, -27.4, 4.3, 4.4),
            ]))

        // Drawn small, then scaled about the tip: a bit smaller than the dog paw.
        let k: CGFloat = 1.15
        let fur = StylePack.Color(rgb(0x1E1E22))
        return StylePack(
            id: "catPaw", name: "Cat paw",
            body: .init(moved(paw, dy: 0, scale: k), fur),
            details: [
                .init(moved(pads, dy: 0, scale: k), rgb(0xFF8FB3)),
                .init(moved(claws, dy: 0, scale: k), rgb(0xC9CAD2)),
            ],
            tail: .leg(.init(width: 14 * k, join: CGPoint(x: 0, y: -36 * k), color: fur)),
            click: .init(
                stamp: .init(moved(pads, dy: 18, scale: 0.9 * k), offset: -16 * k),
                particles: .init(Skins.particlePath(.heart), color: .init(rgb(0xFF4D73)))))
    }
}

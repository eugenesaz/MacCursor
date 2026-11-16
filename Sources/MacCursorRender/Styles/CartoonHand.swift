import CoreGraphics

extension Skins {
    static var cartoonHand: SkinArt {
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
    }
}

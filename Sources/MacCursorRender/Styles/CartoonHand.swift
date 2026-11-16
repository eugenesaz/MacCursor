import CoreGraphics

extension Skins {
    static var cartoonHand: SkinArt {
        // A cartoon glove, black and white, palm toward the viewer: index finger
        // pointing straight up, the other three fingers curled into a soft fist with
        // the thumb tucked across them, a puffy rolled cuff and a grey sleeve below it.
        // Grayscale only. The glove is built from parts listed back to front; each
        // part's ink line shows only where no part in front of it covers it.
        func capsule(from a: CGPoint, to b: CGPoint, r: CGFloat) -> CGPath {
            let p = CGMutablePath()
            p.move(to: a)
            p.addLine(to: b)
            return p.copy(
                strokingWithWidth: 2 * r, lineCap: .round, lineJoin: .round, miterLimit: 4)
        }
        func stroke(_ p: CGPath, _ w: CGFloat) -> CGPath {
            p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 4)
        }
        func curve(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint) -> CGPath {
            let p = CGMutablePath()
            p.move(to: a)
            p.addQuadCurve(to: b, control: c)
            return p
        }
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

        // Index finger, palm (back of the hand) and wrist are one piece, so the
        // finger flows into the hand with no seam. Fingertip apex is exactly (0,0).
        let body = capsule(from: pt(0, -7.5), to: pt(0, -30), r: 7.5)
            .union(
                CGPath(
                    roundedRect: CGRect(x: -11, y: -59, width: 32, height: 34),
                    cornerWidth: 12, cornerHeight: 12, transform: nil)
            )
            .union(
                CGPath(rect: CGRect(x: -10.5, y: -60, width: 21, height: 10), transform: nil))
        // Three curled fingers, folded toward the viewer: fat horizontal rolls
        // stacked down the right of the fist, their knuckles bulging past its edge.
        let curls = [
            capsule(from: pt(4, -28.5), to: pt(15.5, -28.5), r: 5.5),
            capsule(from: pt(4, -37.5), to: pt(16, -37.5), r: 5.5),
            capsule(from: pt(3, -46.5), to: pt(14.5, -46.5), r: 5.2),
        ]
        // Thumb, tucked across the curled fingers from the heel of the hand.
        let thumb = capsule(from: pt(-10, -50.5), to: pt(7.5, -43), r: 5.5)
        // Puffy rolled cuff: a fat soft roll, frontmost.
        let cuff = CGPath(
            roundedRect: CGRect(x: -14.5, y: -70, width: 29, height: 13),
            cornerWidth: 6.5, cornerHeight: 6.5, transform: nil)

        let parts: [CGPath] = [body] + curls + [thumb, cuff]
        let silhouette = parts.dropFirst().reduce(parts[0]) { $0.union($1) }

        // Ink: an inner contour just inside the outer outline (so the white glove
        // stays separate from the light outline on dark screens), plus every part's
        // own edge where it overlaps a part behind it.
        // It reaches 0.5 pt past the edge, under the outline, so no seam shows.
        let inner = stroke(silhouette, 4.0)
            .intersection(silhouette.union(stroke(silhouette, 1)))
        var ink: CGPath = inner
        // Soft grey shading: a crescent on each part's lower right, under its ink.
        var shade: CGPath = CGMutablePath()
        for (i, part) in parts.enumerated() {
            let front = parts[(i + 1)...].reduce(CGMutablePath() as CGPath) { $0.union($1) }
            ink = ink.union(stroke(part, 2.2).subtracting(front).intersection(silhouette))
            var t = CGAffineTransform(translationX: -2.8, y: 2.6)
            let shifted = part.copy(using: &t) ?? part
            let crescent = part.subtracting(shifted).subtracting(front)
            shade = shade.union(crescent)
        }
        // Rolled cuff: a curved fold line along the roll, and short end creases.
        ink = ink.union(stroke(curve(pt(-9, -66.5), pt(0, -64), pt(9, -66.5)), 1.6))
        // Fingertip print for the click stamp: a small oval of concentric ridges.
        let print = CGMutablePath()
        for (i, r) in [(0, 7.0), (1, 4.8), (2, 2.6)] as [(Int, CGFloat)] {
            let ring = CGPath(
                ellipseIn: CGRect(x: -r * 0.8, y: -r, width: r * 1.6, height: r * 2),
                transform: nil)
            print.addPath(i == 2 ? ring : stroke(ring, 1.3))
        }

        return SkinArt(
            silhouette: silhouette,
            fur: rgb(0xFFFFFF),
            pads: shade, padColor: rgb(0xCFCFCF),
            nails: ink, nailColor: rgb(0x141414),
            armWidth: 20, armTop: -66,
            stamp: print, stampOffsetY: -5,
            particle: .dot, particleColor: rgb(0x9E9E9E),
            legColor: rgb(0x8A8A8A))
    }
}

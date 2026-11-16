import CoreGraphics

extension Skins {
    static var cartoonHand: SkinArt {
        // A classic cartoon glove, black and white, back of the hand toward the
        // viewer: index finger pointing straight up, a broad thumb sticking out to
        // the left, the other fingers curled down so only their knuckles show as two
        // bumps on the top right, creases between them, three stitch lines on the
        // back, and a small rolled cuff over a grey sleeve. Grayscale only.
        func capsule(from a: CGPoint, to b: CGPoint, r: CGFloat) -> CGPath {
            let p = CGMutablePath()
            p.move(to: a)
            p.addLine(to: b)
            return p.copy(
                strokingWithWidth: 2 * r, lineCap: .round, lineJoin: .round, miterLimit: 4)
        }
        func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
            CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r),
                   transform: nil)
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

        // The glove: one piece, so the outline flows around it with no seams.
        // Fingertip apex is exactly (0,0).
        let finger = capsule(from: pt(0, -7.5), to: pt(0, -40), r: 7.5)
        let back = CGPath(
            roundedRect: CGRect(x: -7.5, y: -70, width: 38, height: 44),
            cornerWidth: 15, cornerHeight: 15, transform: nil)
        let knuckles = circle(pt(13.5, -27), 7).union(circle(pt(24, -34.5), 6.5))
        // Broad thumb out to the left, its lower edge sweeping down to the cuff.
        let thumb = capsule(from: pt(-5, -51), to: pt(-23, -44.5), r: 7.5)
        let heel = capsule(from: pt(-20, -48), to: pt(-4, -66), r: 7.5)
        let glove = [back, knuckles, thumb, heel].reduce(finger) { $0.union($1) }
        // Small rolled cuff in front of the wrist.
        let cuff = CGPath(
            roundedRect: CGRect(x: -10, y: -80, width: 30, height: 12),
            cornerWidth: 6, cornerHeight: 6, transform: nil)
        let silhouette = glove.union(cuff)

        // Ink: an inner contour just inside the outer outline (so the white glove
        // stays separate from the light outline on dark screens). It reaches 0.5 pt
        // past the edge, under the outline, so no seam shows.
        var ink = stroke(silhouette, 4.0)
            .intersection(silhouette.union(stroke(silhouette, 1)))
        // The cuff's top edge across the wrist.
        ink = ink.union(stroke(cuff, 2.2).intersection(glove).intersection(silhouette))
        // Creases: down the index finger's right side, and between the two knuckles.
        ink = ink.union(stroke(curve(pt(7.5, -23), pt(7.8, -32), pt(9.5, -40)), 1.8))
        ink = ink.union(stroke(curve(pt(19.5, -30), pt(21, -36), pt(22, -42)), 1.8))
        // Three stitch lines on the back of the hand, fanning slightly.
        for (x, lean) in [(8.0, -0.6), (14.5, 0.0), (21.0, 0.8)] as [(CGFloat, CGFloat)] {
            ink = ink.union(stroke(curve(pt(x + lean, -50), pt(x, -56), pt(x - lean, -63)), 1.8))
        }
        // Soft grey shading along the lower right of the glove and cuff.
        var shade: CGPath = CGMutablePath()
        for (part, front) in [(glove, cuff), (cuff, CGMutablePath())] as [(CGPath, CGPath)] {
            var t = CGAffineTransform(translationX: -2.8, y: 2.6)
            let shifted = part.copy(using: &t) ?? part
            shade = shade.union(part.subtracting(shifted).subtracting(front))
        }
        shade = shade.intersection(silhouette)

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
            pads: shade, padColor: rgb(0xDADADA),
            nails: ink, nailColor: rgb(0x141414),
            armWidth: 18, armTop: -76,
            stamp: print, stampOffsetY: -5,
            particle: .dot, particleColor: rgb(0x9E9E9E),
            legColor: rgb(0x8A8A8A))
    }
}

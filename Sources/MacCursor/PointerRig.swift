import AppKit
import QuartzCore

/// The layers that make up the pointer: a fading leg reaching in from off-screen,
/// and the paw on top. Positioned at the hotspot, rotated so the leg points away.
final class PointerRig {
    let root = CALayer()

    // Draw order: leg edges → paw outline → leg fill → paw fill. This merges
    // leg and paw into one silhouette with a single continuous outline.
    private let legEdgeL = CAGradientLayer()
    private let legEdgeR = CAGradientLayer()
    private let back = CALayer()
    private let legFill = CAGradientLayer()
    private let front = CALayer()
    private let outline = CAShapeLayer()
    private let fur = CAShapeLayer()
    private let pads = CAShapeLayer()
    private let nails = CAShapeLayer()

    static let outlineWidth: CGFloat = 2.5
    static let legLength: CGFloat = 560

    init(contentsScale: CGFloat) {
        let all: [CALayer] = [root, legEdgeL, legEdgeR, back, legFill, front, outline, fur, pads, nails]
        for l in all {
            l.contentsScale = contentsScale
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        for l in [root, back, front, outline, fur, pads, nails] as [CALayer] {
            l.bounds = .zero
            l.position = .zero
        }
        back.addSublayer(outline)
        front.addSublayer(fur)
        front.addSublayer(pads)
        front.addSublayer(nails)
        root.addSublayer(legEdgeL)
        root.addSublayer(legEdgeR)
        root.addSublayer(back)
        root.addSublayer(legFill)
        root.addSublayer(front)
    }

    func apply(art: SkinArt, palette: Palette) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let ow = Self.outlineWidth
        outline.path = art.silhouette
        fur.path = art.silhouette
        fur.fillColor = art.fur
        if art.isRing {
            outline.fillColor = nil
            outline.strokeColor = art.particleColor
            outline.lineWidth = 3
        } else {
            outline.fillColor = palette.outline
            outline.strokeColor = palette.outline
            outline.lineWidth = ow * 2
            outline.lineJoin = .round
        }
        pads.path = art.pads
        pads.fillColor = art.padColor
        nails.path = art.nails
        nails.fillColor = art.nailColor

        let hasLeg = art.armWidth > 0
        for l in [legEdgeL, legEdgeR, legFill] { l.isHidden = !hasLeg }
        guard hasLeg else { return }
        let w = art.armWidth, L = Self.legLength, top = art.armTop + 12
        legEdgeL.frame = CGRect(x: -w / 2 - ow, y: top - L, width: ow * 2, height: L)
        legEdgeR.frame = CGRect(x: w / 2 - ow, y: top - L, width: ow * 2, height: L)
        legFill.frame = CGRect(x: -w / 2, y: top - L, width: w, height: L)
        fade(legEdgeL, palette.outline)
        fade(legEdgeR, palette.outline)
        fade(legFill, art.fur)
    }

    private func fade(_ g: CAGradientLayer, _ c: CGColor) {
        g.colors = [c, c, c.copy(alpha: 0)!]
        g.locations = [0, 0.3, 1]
        g.startPoint = CGPoint(x: 0.5, y: 1) // top (layer coords are y-up on macOS)
        g.endPoint = CGPoint(x: 0.5, y: 0)
    }

    /// - angle: radians, CCW; 0 = leg straight down.
    /// - squash: 0…1 poke animation amount.
    func setPose(position: CGPoint, angle: CGFloat, scale: CGFloat, squash: CGFloat) {
        root.position = position
        root.setAffineTransform(CGAffineTransform(rotationAngle: angle).scaledBy(x: scale, y: scale))
        let t = CGAffineTransform(translationX: 0, y: 5 * squash)
            .scaledBy(x: 1 + 0.14 * squash, y: 1 - 0.16 * squash)
        back.setAffineTransform(t)
        front.setAffineTransform(t)
    }
}

/// One click's visual feedback: ripple, paw-print stamp and (when clicking fast) particles.
/// Driven by `render(t:)` so the same code serves live animation and static snapshots.
final class ClickEffect {
    let layer = CALayer()
    let start: CFTimeInterval
    static let duration: CFTimeInterval = 1.1

    private let ripple = CAShapeLayer()
    private var stamp: CAShapeLayer?
    private var stampRotation: CGFloat = 0
    private var particles: [(layer: CALayer, dir: CGVector, spin: CGFloat, dist: CGFloat)] = []
    private let intensity: CGFloat
    private let scale: CGFloat

    init(tip: CGPoint, angle: CGFloat, art: SkinArt, palette: Palette,
         intensity: CGFloat, scale: CGFloat, contentsScale: CGFloat, start: CFTimeInterval) {
        self.start = start
        self.intensity = intensity
        self.scale = scale
        layer.bounds = .zero
        layer.position = tip
        layer.contentsScale = contentsScale

        if let path = art.stamp {
            let s = CAShapeLayer()
            s.contentsScale = contentsScale
            s.path = path
            s.fillColor = palette.effect
            // Print lands where the pads are: below the tip, along the leg.
            let off = art.stampOffsetY * scale
            s.position = CGPoint(x: -sin(angle) * off, y: cos(angle) * off)
            stampRotation = angle + .random(in: -0.25...0.25)
            layer.addSublayer(s)
            stamp = s
        }

        ripple.contentsScale = contentsScale
        ripple.fillColor = nil
        ripple.strokeColor = art.isRing ? art.particleColor : palette.effect
        layer.addSublayer(ripple)

        let count = intensity >= 1.4 ? Int((intensity * 3).rounded()) : 0
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * 2 * .pi + .random(in: -0.3...0.3)
            // Outline trick: a stroked copy behind the fill gives one clean outer edge.
            let p = CALayer()
            p.bounds = .zero
            let path = Skins.particlePath(art.particle)
            if art.particle != .dot {
                let back = CAShapeLayer()
                back.contentsScale = contentsScale
                back.path = path
                back.fillColor = palette.outline
                back.strokeColor = palette.outline
                back.lineWidth = 2.4
                back.lineJoin = .round
                p.addSublayer(back)
            }
            let front = CAShapeLayer()
            front.contentsScale = contentsScale
            front.path = path
            front.fillColor = art.particleColor
            p.addSublayer(front)
            layer.addSublayer(p)
            particles.append((p, CGVector(dx: cos(a), dy: sin(a)),
                              .random(in: -4...4), .random(in: 24...36) + 10 * intensity))
        }
        render(t: 0)
    }

    func render(t: CFTimeInterval) {
        let rt = min(t / 0.45, 1)
        let r = (10 + 22 * intensity * easeOut(rt)) * scale
        ripple.path = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        ripple.lineWidth = (4 * (1 - rt) + 0.5) * scale
        ripple.opacity = Float(1 - rt)

        if let s = stamp {
            let st = min(t / Self.duration, 1)
            let pop = 0.85 + 0.2 * easeOut(min(t / 0.15, 1))
            s.setAffineTransform(CGAffineTransform(rotationAngle: stampRotation).scaledBy(x: pop * scale, y: pop * scale))
            s.opacity = Float(0.55 * pow(1 - st, 1.5))
        }

        let k = min(t / 0.7, 1)
        for p in particles {
            let d = (14 + p.dist * easeOut(k)) * scale
            p.layer.position = CGPoint(x: p.dir.dx * d, y: p.dir.dy * d)
            p.layer.setAffineTransform(CGAffineTransform(rotationAngle: p.spin * k).scaledBy(x: scale, y: scale))
            p.layer.opacity = Float(1 - k * k)
        }
    }

    /// Returns false (and removes itself) once finished.
    func update(now: CFTimeInterval) -> Bool {
        let t = now - start
        if t >= Self.duration {
            layer.removeFromSuperlayer()
            return false
        }
        render(t: t)
        return true
    }

    private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
}

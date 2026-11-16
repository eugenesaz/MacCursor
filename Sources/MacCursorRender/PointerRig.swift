import QuartzCore

/// The layers that make up the pointer: a fading leg reaching in from off-screen,
/// and the paw on top. Positioned at the hotspot, rotated so the leg points away.
public final class PointerRig {
    public let root = CALayer()

    // Draw order: leg edges → paw outline → leg fill → paw fill. This merges
    // leg and paw into one silhouette with a single continuous outline.
    private let legEdgeL = CAGradientLayer()
    private let legEdgeR = CAGradientLayer()
    private let back = CALayer()
    private let legFill = CAGradientLayer()
    private let front = CALayer()
    private let outline = CAShapeLayer()
    private let fur = CAShapeLayer()
    /// One layer per detail (pads, nails, ink…), in drawing order.
    private var details: [CAShapeLayer] = []
    private let contentsScale: CGFloat

    static let outlineWidth: CGFloat = 2.5
    static let legLength: CGFloat = 560

    public init(contentsScale: CGFloat) {
        self.contentsScale = contentsScale
        let all: [CALayer] = [root, legEdgeL, legEdgeR, back, legFill, front, outline, fur]
        for l in all {
            l.contentsScale = contentsScale
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        }
        for l in [root, back, front, outline, fur] as [CALayer] {
            l.bounds = .zero
            l.position = .zero
        }
        back.addSublayer(outline)
        front.addSublayer(fur)
        root.addSublayer(legEdgeL)
        root.addSublayer(legEdgeR)
        root.addSublayer(back)
        root.addSublayer(legFill)
        root.addSublayer(front)
    }

    /// - tailLength: 0…1 share of the full leg; 0 = no leg.
    public func apply(pack: StylePack, palette: Palette, tailLength: CGFloat = 1) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let ow = Self.outlineWidth
        let rule: CAShapeLayerFillRule = pack.body.evenOdd ? .evenOdd : .nonZero
        outline.path = pack.body.path
        outline.fillRule = rule
        fur.path = pack.body.path
        fur.fillRule = rule
        fur.fillColor = pack.body.color.resolved(palette)
        switch pack.outline {
        case .stroke(let color, let width):
            outline.fillColor = nil
            outline.strokeColor = color.resolved(palette)
            outline.lineWidth = width
        case .palette:
            outline.fillColor = palette.outline
            outline.strokeColor = palette.outline
            outline.lineWidth = ow * 2
            outline.lineJoin = .round
        }
        applyDetails(pack.details, palette: palette)

        let leg = tailLength > 0 ? pack.leg : nil
        for l in [legEdgeL, legEdgeR, legFill] { l.isHidden = leg == nil }
        guard let leg else { return }
        let w = leg.width
        let len = Self.legLength * min(tailLength, 1)
        let top = leg.join.y + 12
        let x = leg.join.x
        legEdgeL.frame = CGRect(x: x - w / 2 - ow, y: top - len, width: ow * 2, height: len)
        legEdgeR.frame = CGRect(x: x + w / 2 - ow, y: top - len, width: ow * 2, height: len)
        legFill.frame = CGRect(x: x - w / 2, y: top - len, width: w, height: len)
        fade(legEdgeL, palette.outline)
        fade(legEdgeR, palette.outline)
        fade(legFill, leg.color.resolved(palette))
    }

    private func applyDetails(_ list: [StylePack.Layer], palette: Palette) {
        while details.count < list.count {
            let l = CAShapeLayer()
            l.contentsScale = contentsScale
            l.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            l.bounds = .zero
            l.position = .zero
            front.addSublayer(l)
            details.append(l)
        }
        while details.count > list.count { details.removeLast().removeFromSuperlayer() }
        for (layer, d) in zip(details, list) {
            layer.path = d.path
            layer.fillColor = d.color.resolved(palette)
            layer.fillRule = d.evenOdd ? .evenOdd : .nonZero
        }
    }

    private func fade(_ g: CAGradientLayer, _ c: CGColor) {
        g.colors = [c, c, c.copy(alpha: 0)!]
        g.locations = [0, 0.3, 1]
        g.startPoint = CGPoint(x: 0.5, y: 1)  // top (layer coords are y-up on macOS)
        g.endPoint = CGPoint(x: 0.5, y: 0)
    }

    /// - angle: radians, CCW; 0 = leg straight down.
    /// - squash: 0…1 poke animation amount.
    public func setPose(position: CGPoint, angle: CGFloat, scale: CGFloat, squash: CGFloat) {
        root.position = position
        root.setAffineTransform(
            CGAffineTransform(rotationAngle: angle).scaledBy(x: scale, y: scale))
        let t = CGAffineTransform(translationX: 0, y: 5 * squash)
            .scaledBy(x: 1 + 0.14 * squash, y: 1 - 0.16 * squash)
        back.setAffineTransform(t)
        front.setAffineTransform(t)
    }
}

/// One click's visual feedback: ripple, paw-print stamp and (when clicking fast) particles.
/// Driven by `render(t:)` so the same code serves live animation and static snapshots.
public final class ClickEffect {
    public let layer = CALayer()
    public let start: CFTimeInterval
    public static let duration: CFTimeInterval = 1.1

    private let ripple = CAShapeLayer()
    private var stamp: CAShapeLayer?
    private var stampRotation: CGFloat = 0
    private var particles: [(layer: CALayer, dir: CGVector, spin: CGFloat, dist: CGFloat)] = []
    private let intensity: CGFloat
    private let scale: CGFloat

    public init(
        tip: CGPoint, angle: CGFloat, pack: StylePack, palette: Palette,
        intensity: CGFloat, scale: CGFloat, contentsScale: CGFloat, start: CFTimeInterval,
        seed: UInt64? = nil
    ) {
        // A fixed seed makes the effect repeatable (snapshot tests); live clicks vary.
        var rng = SplitMix64(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        self.start = start
        self.intensity = intensity
        self.scale = scale
        layer.bounds = .zero
        layer.position = tip
        layer.contentsScale = contentsScale

        if let print = pack.click.stamp {
            let s = CAShapeLayer()
            s.contentsScale = contentsScale
            s.path = print.path
            s.fillColor = palette.effect
            // Print lands where the pads are: below the tip, along the leg.
            let off = print.offset * scale
            s.position = CGPoint(x: -sin(angle) * off, y: cos(angle) * off)
            stampRotation = angle + .random(in: -0.25...0.25, using: &rng)
            layer.addSublayer(s)
            stamp = s
        }

        ripple.contentsScale = contentsScale
        ripple.fillColor = nil
        ripple.strokeColor = pack.click.ripple?.resolved(palette) ?? palette.effect
        layer.addSublayer(ripple)

        let spec = pack.click.particles
        let count = spec == nil ? 0 : intensity >= 1.4 ? Int((intensity * 3).rounded()) : 0
        for i in 0..<count {
            guard let spec else { break }
            let a = CGFloat(i) / CGFloat(count) * 2 * .pi + .random(in: -0.3...0.3, using: &rng)
            // Outline trick: a stroked copy behind the fill gives one clean outer edge.
            let p = CALayer()
            p.bounds = .zero
            let path = spec.path
            if spec.outlined {
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
            front.fillColor = spec.color.resolved(palette)
            p.addSublayer(front)
            layer.addSublayer(p)
            particles.append(
                (
                    p, CGVector(dx: cos(a), dy: sin(a)),
                    .random(in: -4...4, using: &rng),
                    .random(in: 24...36, using: &rng) + 10 * intensity
                ))
        }
        render(t: 0)
    }

    public func render(t: CFTimeInterval) {
        let rt = min(t / 0.45, 1)
        let r = (10 + 22 * intensity * easeOut(rt)) * scale
        ripple.path = CGPath(
            ellipseIn: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r), transform: nil)
        ripple.lineWidth = (4 * (1 - rt) + 0.5) * scale
        ripple.opacity = Float(1 - rt)

        if let s = stamp {
            let st = min(t / Self.duration, 1)
            let pop = 0.85 + 0.2 * easeOut(min(t / 0.15, 1))
            s.setAffineTransform(
                CGAffineTransform(rotationAngle: stampRotation).scaledBy(
                    x: pop * scale, y: pop * scale))
            s.opacity = Float(0.55 * pow(1 - st, 1.5))
        }

        let k = min(t / 0.7, 1)
        for p in particles {
            let d = (14 + p.dist * easeOut(k)) * scale
            p.layer.position = CGPoint(x: p.dir.dx * d, y: p.dir.dy * d)
            p.layer.setAffineTransform(
                CGAffineTransform(rotationAngle: p.spin * k).scaledBy(x: scale, y: scale))
            p.layer.opacity = Float(1 - k * k)
        }
    }

    /// Returns false (and removes itself) once finished.
    public func update(now: CFTimeInterval) -> Bool {
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

/// Small seedable generator (SplitMix64), so a seed always gives the same click effect.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

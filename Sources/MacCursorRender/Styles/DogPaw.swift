import CoreGraphics

extension Skins {
    static var dogPaw: SkinArt {
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
    }
}

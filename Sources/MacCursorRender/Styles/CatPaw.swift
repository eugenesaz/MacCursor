import CoreGraphics

extension Skins {
    static var catPaw: SkinArt {
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
    }
}

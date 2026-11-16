import CoreGraphics

extension Skins {
    static var highlightRing: SkinArt {
        return SkinArt(
            silhouette: ovals([(0, 0, 22, 22)]),
            fur: rgb(0xFFD23F, 0.35),
            isRing: true,
            particle: .dot, particleColor: rgb(0xFFD23F))
    }
}

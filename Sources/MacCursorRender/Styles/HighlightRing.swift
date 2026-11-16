import CoreGraphics

extension Skins {
    static var highlightRing: StylePack {
        let gold = StylePack.Color(rgb(0xFFD23F))
        return StylePack(
            id: "ring", name: "Highlight ring",
            body: .init(ovals([(0, 0, 22, 22)]), rgb(0xFFD23F, 0.35)),
            outline: .stroke(gold, width: 3),
            overlay: true,
            click: .init(
                ripple: gold,
                particles: .init(Skins.particlePath(.dot), color: gold, outlined: false)))
    }
}

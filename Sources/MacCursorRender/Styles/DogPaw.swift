import CoreGraphics

extension Skins {
    static var dogPaw: StylePack {
        // Big, round, slightly splayed toes with visible nails.
        let toes: [Oval] = [
            (-19, -18, 8, 9), (-7, -10, 8.5, 10), (7, -10, 8.5, 10), (19, -18, 8, 9),
        ]
        let body: Oval = (0, -37, 23, 21)
        let toePads = toes.map { Oval($0.x, $0.y - 1.5, $0.rx * 0.6, $0.ry * 0.6) }
        let mainPad: [Oval] = [(0, -39, 11, 8.5), (-7, -44, 7.5, 6), (7, -44, 7.5, 6)]
        let pads = ovals(toePads + mainPad)
        let nails = ovals(toes.map { Oval($0.x * 1.08, $0.y + $0.ry - 1.2, 2, 3.2) })
        let fur = StylePack.Color(rgb(0xE8C08A))
        return StylePack(
            id: "dogPaw", name: "Dog paw",
            body: .init(ovals(toes + [body]), fur),
            details: [.init(pads, rgb(0x4A322B)), .init(nails, rgb(0x2B1E1A))],
            tail: .leg(.init(width: 24, join: CGPoint(x: 0, y: -50), color: fur)),
            click: .init(
                stamp: .init(moved(pads, dy: 30, scale: 0.9), offset: -26),
                particles: .init(Skins.particlePath(.bone), color: .init(rgb(0xFFF6E5)))))
    }
}

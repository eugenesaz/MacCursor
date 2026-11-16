import CoreGraphics
import MacCursorCore
import Testing

@testable import MacCursorRender

@Suite struct StyleCatalogTests {
    @Test(arguments: PointerStyle.allCases)
    func everyStyleHasArt(style: PointerStyle) {
        let art = Skins.art(for: style)
        #expect(!art.body.path.boundingBoxOfPath.isEmpty)
    }

    /// The click point is the top center of the art: the highest point of the silhouette is
    /// at y = 0 within 1 pt, nothing is drawn above it, and the art is solid just below it.
    /// (Paws click between the two middle toes, so their notch leaves up to 6 pt there.)
    @Test(arguments: PointerStyle.allCases.filter { !$0.keepsSystemCursor })
    func tipIsTheHotspot(style: PointerStyle) {
        let path = Skins.art(for: style).body.path
        #expect(abs(path.boundingBoxOfPath.maxY) <= 1)
        #expect(!path.contains(CGPoint(x: 0, y: 1.5)))
        #expect(path.contains(CGPoint(x: 0, y: -6)))
    }

    @Test func fingerTipIsExact() {
        let path = Skins.art(for: .finger).body.path
        #expect(path.contains(CGPoint(x: 0, y: -1)))
    }

    @Test func ringIsCenteredOnTheHotspot() {
        let box = Skins.art(for: .ring).body.path.boundingBoxOfPath
        #expect(abs(box.midX) <= 0.5 && abs(box.midY) <= 0.5)
    }

    /// Styles with a leg attach it below the paw; the ring has none.
    @Test(arguments: PointerStyle.allCases)
    func legMatchesTheStyle(style: PointerStyle) throws {
        let art = Skins.art(for: style)
        if style.keepsSystemCursor {
            #expect(art.leg == nil)
        } else {
            let leg = try #require(art.leg)
            #expect(leg.width > 0)
            #expect(leg.join.y < 0)
            #expect(leg.join.y >= art.body.path.boundingBoxOfPath.minY)
        }
    }

    /// The leg is centred under the art where it joins (the paw or the cuff), and its
    /// top corners are hidden inside it, so it doesn't look shifted to one side.
    @Test(arguments: PointerStyle.allCases.filter { !$0.keepsSystemCursor })
    func legIsCentredWhereItJoins(style: PointerStyle) throws {
        let art = Skins.art(for: style)
        let leg = try #require(art.leg)
        let y = leg.join.y + 1
        let silhouette = art.body.path
        let box = silhouette.boundingBoxOfPath
        let xs = stride(from: box.minX, through: box.maxX, by: 0.25)
            .filter { silhouette.contains(CGPoint(x: $0, y: y)) }
        let left = try #require(xs.first)
        let right = try #require(xs.last)
        #expect(abs(leg.join.x - (left + right) / 2) <= 1, "\(style): art spans \(left)…\(right)")
        #expect(left < leg.join.x - leg.width / 2 && leg.join.x + leg.width / 2 < right)
    }

    /// Both palettes exist and contrast with each other, so each reads on its background.
    @Test(arguments: [PaletteKind.forLightScreens, .forDarkScreens])
    func palettesHaveContrastingOutlines(kind: PaletteKind) {
        let palette = Palette.of(kind)
        let other = Palette.of(kind == .forLightScreens ? .forDarkScreens : .forLightScreens)
        #expect(luminance(palette.outline) != luminance(other.outline))
        let dark = luminance(palette.outline) < 0.5
        #expect(dark == (kind == .forLightScreens))
    }

    /// The cartoon hand is black and white only: every color it draws with is a grey.
    @Test func cartoonHandIsGrayscale() {
        let art = Skins.art(for: .finger)
        let colors =
            [art.body.color] + art.details.map(\.color)
            + [art.click.particles?.color, art.leg?.color].compactMap { $0 }
        for c in colors.flatMap({ [$0.forLightScreens, $0.forDarkScreens] }) {
            let p = c.converted(
                to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
                .components!
            #expect(abs(p[0] - p[1]) < 0.01 && abs(p[1] - p[2]) < 0.01, "not grey: \(p)")
        }
    }

    private func luminance(_ c: CGColor) -> Double {
        let srgb = c.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
        let p = srgb.components!
        return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
    }
}

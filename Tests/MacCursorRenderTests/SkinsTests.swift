import CoreGraphics
import MacCursorCore
import Testing

@testable import MacCursorRender

@Suite struct StyleCatalogTests {
    @Test(arguments: PointerStyle.allCases)
    func everyStyleHasArt(style: PointerStyle) {
        let art = Skins.art(for: style)
        #expect(!art.silhouette.boundingBoxOfPath.isEmpty)
    }

    /// The click point is the top center of the art: the highest point of the silhouette is
    /// at y = 0 within 1 pt, nothing is drawn above it, and the art is solid just below it.
    /// (Paws click between the two middle toes, so their notch leaves up to 6 pt there.)
    @Test(arguments: PointerStyle.allCases.filter { !$0.keepsSystemCursor })
    func tipIsTheHotspot(style: PointerStyle) {
        let path = Skins.art(for: style).silhouette
        #expect(abs(path.boundingBoxOfPath.maxY) <= 1)
        #expect(!path.contains(CGPoint(x: 0, y: 1.5)))
        #expect(path.contains(CGPoint(x: 0, y: -6)))
    }

    @Test func fingerTipIsExact() {
        let path = Skins.art(for: .finger).silhouette
        #expect(path.contains(CGPoint(x: 0, y: -1)))
    }

    @Test func ringIsCenteredOnTheHotspot() {
        let box = Skins.art(for: .ring).silhouette.boundingBoxOfPath
        #expect(abs(box.midX) <= 0.5 && abs(box.midY) <= 0.5)
    }

    /// Styles with a leg attach it below the paw; the ring has none.
    @Test(arguments: PointerStyle.allCases)
    func legMatchesTheStyle(style: PointerStyle) {
        let art = Skins.art(for: style)
        if style.keepsSystemCursor {
            #expect(art.armWidth == 0)
        } else {
            #expect(art.armWidth > 0)
            #expect(art.armTop < 0)
            #expect(art.armTop >= art.silhouette.boundingBoxOfPath.minY)
        }
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
        let colors = [art.fur, art.padColor, art.nailColor, art.particleColor, art.legColor]
        for case let c? in colors {
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

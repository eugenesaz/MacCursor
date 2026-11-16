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

    /// The tip of the art is the click point: the top edge of the silhouette sits at y = 0,
    /// centered on x = 0, within 1 pt.
    @Test(arguments: PointerStyle.allCases.filter { !$0.keepsSystemCursor })
    func tipIsTheHotspot(style: PointerStyle) {
        let box = Skins.art(for: style).silhouette.boundingBoxOfPath
        #expect(abs(box.maxY) <= 1)
        #expect(abs(box.midX) <= 1)
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

    private func luminance(_ c: CGColor) -> Double {
        let srgb = c.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)!
        let p = srgb.components!
        return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
    }
}

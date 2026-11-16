import CoreGraphics
import MacCursorCore
import Testing

@testable import MacCursorRender

@Test(arguments: PointerStyle.allCases)
func everySkinHasArt(kind: PointerStyle) {
    let art = Skins.art(for: kind)
    #expect(!art.silhouette.boundingBoxOfPath.isEmpty)
}

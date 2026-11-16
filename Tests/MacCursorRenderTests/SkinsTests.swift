import CoreGraphics
import Testing
@testable import MacCursorRender

@Test(arguments: SkinKind.allCases)
func everySkinHasArt(kind: SkinKind) {
    let art = Skins.art(for: kind)
    #expect(!art.silhouette.boundingBoxOfPath.isEmpty)
}

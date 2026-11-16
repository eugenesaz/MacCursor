import Testing

@testable import MacCursorCore

@Suite struct CursorPolicyTests {
    @Test(arguments: PointerStyle.allCases)
    func hidesOnlyWhenPointerOnAndSettingOn(style: PointerStyle) {
        let paw = style != .ring
        #expect(
            CursorPolicy.hidesSystemCursor(pointerOn: true, settingOn: true, style: style) == paw)
        #expect(!CursorPolicy.hidesSystemCursor(pointerOn: false, settingOn: true, style: style))
        #expect(!CursorPolicy.hidesSystemCursor(pointerOn: true, settingOn: false, style: style))
        #expect(!CursorPolicy.hidesSystemCursor(pointerOn: false, settingOn: false, style: style))
    }

    @Test func ringKeepsTheArrowBecauseItIsDrawnAroundIt() {
        #expect(PointerStyle.ring.keepsSystemCursor)
        #expect(!PointerStyle.dogPaw.keepsSystemCursor)
    }
}

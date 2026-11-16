import Testing

@testable import MacCursorCore

@Suite struct CursorPolicyTests {
    @Test(arguments: [false, true])
    func hidesOnlyWhenPointerOnAndSettingOn(overlay: Bool) {
        #expect(
            CursorPolicy.hidesSystemCursor(
                pointerOn: true, settingOn: true, styleIsOverlay: overlay)
                == !overlay)
        for (on, setting) in [(false, true), (true, false), (false, false)] {
            #expect(
                !CursorPolicy.hidesSystemCursor(
                    pointerOn: on, settingOn: setting, styleIsOverlay: overlay))
        }
    }
}

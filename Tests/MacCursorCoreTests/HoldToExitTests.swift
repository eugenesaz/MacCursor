import CoreGraphics
import Testing

@testable import MacCursorCore

@Suite struct HoldToExitTests {
    @Test func firesOnceAfterAStillHold() {
        var hold = HoldToExit()
        hold.down(at: .zero, time: 10)
        let early = hold.fire(now: 10 + HoldToExit.duration - 0.01)
        #expect(!early)
        hold.moved(to: CGPoint(x: 3, y: 4))
        let onTime = hold.fire(now: 10 + HoldToExit.duration)
        #expect(onTime)
        let again = hold.fire(now: 20)
        #expect(!again)
    }

    @Test func releasingEarlyCancels() {
        var hold = HoldToExit()
        hold.down(at: .zero, time: 0)
        hold.up()
        let fired = hold.fire(now: 5)
        #expect(!fired)
    }

    @Test func movingTooFarCancels() {
        var hold = HoldToExit()
        hold.down(at: .zero, time: 0)
        hold.moved(to: CGPoint(x: HoldToExit.tolerance + 1, y: 0))
        let fired = hold.fire(now: 5)
        #expect(!fired)
    }

    @Test func doesNothingWithoutAPress() {
        var hold = HoldToExit()
        hold.moved(to: CGPoint(x: 100, y: 100))
        let fired = hold.fire(now: 100)
        #expect(!fired)
    }
}

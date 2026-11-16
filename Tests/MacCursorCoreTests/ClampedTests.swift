import Testing

@testable import MacCursorCore

@Test func clampedKeepsValuesInRange() {
    #expect(5.clamped(to: 0...10) == 5)
    #expect((-1).clamped(to: 0...10) == 0)
    #expect(11.clamped(to: 0...10) == 10)
}

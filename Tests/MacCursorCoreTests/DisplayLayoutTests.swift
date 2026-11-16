import CoreGraphics
import Testing

@testable import MacCursorCore

@Suite struct DisplayLayoutTests {
    // Main 1512×982 at the origin, an external 2560×1440 to its left and above (negative x).
    let sideBySide = DisplayLayout(frames: [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: -2560, y: 0, width: 2560, height: 1440),
    ])
    // External stacked on top of the main display.
    let stacked = DisplayLayout(frames: [
        CGRect(x: 0, y: 0, width: 1512, height: 982),
        CGRect(x: -300, y: 982, width: 1920, height: 1080),
    ])

    @Test func findsTheDisplayUnderThePointer() {
        #expect(sideBySide.index(containing: CGPoint(x: 100, y: 100)) == 0)
        #expect(sideBySide.index(containing: CGPoint(x: -100, y: 1200)) == 1)
        #expect(stacked.index(containing: CGPoint(x: 1000, y: 1500)) == 1)
        #expect(stacked.index(containing: CGPoint(x: 1000, y: 500)) == 0)
    }

    /// AppKit's convention for mouse locations: left and top edges belong to the display,
    /// right and bottom edges belong to the neighbor.
    @Test func edgesAndCornersBelongToExactlyOneDisplay() {
        #expect(sideBySide.index(containing: CGPoint(x: 0, y: 500)) == 0)
        #expect(sideBySide.index(containing: CGPoint(x: -0.5, y: 500)) == 1)
        #expect(sideBySide.index(containing: CGPoint(x: 1511.5, y: 982)) == 0)
        #expect(stacked.index(containing: CGPoint(x: 10, y: 982)) == 0)
        #expect(stacked.index(containing: CGPoint(x: 10, y: 982.5)) == 1)
        #expect(sideBySide.index(containing: CGPoint(x: -2560, y: 1440)) == 1)
    }

    @Test func pointsInAGapGoToTheNearestDisplay() {
        // Above the main display, but beside the taller external one: a dead zone.
        #expect(sideBySide.index(containing: CGPoint(x: 700, y: 1300)) == 0)
        #expect(sideBySide.index(containing: CGPoint(x: -3000, y: 50)) == 1)
    }

    @Test func noDisplays() {
        #expect(DisplayLayout(frames: []).index(containing: .zero) == nil)
    }

    @Test func localPointIsRelativeToTheDisplaysBottomLeft() {
        let external = CGRect(x: -2560, y: 0, width: 2560, height: 1440)
        #expect(DisplayLayout.local(CGPoint(x: -2560, y: 0), in: external) == .zero)
        #expect(
            DisplayLayout.local(CGPoint(x: -1, y: 1440), in: external)
                == CGPoint(x: 2559, y: 1440))
        let above = CGRect(x: -300, y: 982, width: 1920, height: 1080)
        #expect(
            DisplayLayout.local(CGPoint(x: 0, y: 1000), in: above) == CGPoint(x: 300, y: 18))
    }

    @Test func legLeansMoreOnTheLeft() {
        let degrees = { (x: Double) in DisplayLayout.leanAngle(localX: x, width: 1000) * 180 / .pi }
        #expect(abs(degrees(0) - 28) < 0.001)
        #expect(abs(degrees(1000) - 8) < 0.001)
        #expect(abs(degrees(500) - 18) < 0.001)
        #expect(abs(degrees(-50) - 28) < 0.001)  // clamped
        #expect(abs(degrees(5000) - 8) < 0.001)
    }
}

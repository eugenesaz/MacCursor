import CoreGraphics
import Testing

@testable import MacCursorCore

@Suite struct DrawSettingsTests {
    let store = MemoryStore()
    var settings: DrawSettings { DrawSettings(store: store) }

    @Test func defaultsOnFirstLaunch() {
        #expect(settings.isOn == true)
        #expect(settings.color == .red)
        #expect(settings.width == .medium)
        #expect(settings.fadeSeconds == 3)
    }

    @Test func valuesPersistUnderTheDocumentedKeys() {
        let s = settings
        s.isOn = false
        s.color = .blue
        s.width = .thick
        s.fadeSeconds = 5
        let reread = DrawSettings(store: store)
        #expect(reread.isOn == false)
        #expect(reread.color == .blue)
        #expect(reread.width == .thick)
        #expect(reread.fadeSeconds == 5)
        #expect(store.values["drawOn"] as? Bool == false)
        #expect(store.values["drawColor"] as? String == "blue")
        #expect(store.values["drawWidth"] as? String == "thick")
        #expect(store.values["drawFadeSeconds"] as? Double == 5)
    }

    @Test(arguments: [(0.0, 1.0), (1.0, 1.0), (4.0, 4.0), (10.0, 10.0), (60.0, 10.0)])
    func fadeIsClamped(input: Double, expected: Double) {
        let s = settings
        s.fadeSeconds = input
        #expect(s.fadeSeconds == expected)
    }

    @Test func badStoredValuesFallBack() {
        store.values["drawColor"] = "plaid"
        store.values["drawWidth"] = 7
        store.values["drawFadeSeconds"] = Double.nan
        #expect(settings.color == .red)
        #expect(settings.width == .medium)
        #expect(settings.fadeSeconds == 3)
        store.values["drawFadeSeconds"] = "long"
        #expect(settings.fadeSeconds == 3)
    }

    @Test func colorsCycleAndWrap() {
        var c = InkColor.red
        var seen: [InkColor] = []
        for _ in InkColor.allCases {
            seen.append(c)
            c = c.next
        }
        #expect(seen == InkColor.allCases)
        #expect(c == .red)
    }
}

@Suite struct InkTriggerTests {
    /// Feeds polled states (keys, mouse button down, key-press counter) and returns each result.
    func run(_ steps: [(HeldKeys, Bool, UInt32)]) -> [InkMode?] {
        var t = InkTrigger()
        return steps.map { t.update(keys: $0.0, buttonDown: $0.1, keyDownCount: $0.2) }
    }

    static let cases: [(HeldKeys, InkMode?)] = [
        ([], nil),
        ([.command], .fading),
        ([.command, .option], .lasting),
        ([.option], nil),
        ([.command, .shift], nil),
        ([.command, .control], nil),
        ([.command, .function], nil),
        ([.command, .option, .shift], nil),
    ]

    @Test(arguments: cases)
    func modeFollowsTheHeldKeys(keys: HeldKeys, expected: InkMode?) {
        #expect(run([(keys, false, 0)]) == [expected])
    }

    @Test func switchingOptionMidHoldSwitchesTheMode() {
        let r = run([
            ([.command], false, 5), ([.command, .option], false, 5), ([.command], false, 5),
        ])
        #expect(r == [.fading, .lasting, .fading])
    }

    @Test func typingDuringTheHoldStopsDrawingUntilCommandIsReleased() {
        let r = run([
            ([.command], false, 5), ([.command], false, 6), ([.command, .option], false, 6),
            ([], false, 6), ([.command], false, 6),
        ])
        #expect(r == [.fading, nil, nil, nil, .fading])
    }

    @Test func clickingDuringTheHoldStopsDrawingUntilCommandIsReleased() {
        let r = run([
            ([.command], true, 0), ([.command], false, 0), ([], false, 0), ([.command], false, 0),
        ])
        #expect(r == [nil, nil, nil, .fading])
    }

    @Test func aShortcutHeldWithOtherModifiersAlsoSpoilsTheHold() {
        let r = run([
            ([.command, .shift], false, 1), ([.command, .shift], false, 2), ([.command], false, 2),
        ])
        #expect(r == [nil, nil, nil])
    }
}

@Suite struct InkStrokeTests {
    @Test func skipsPointsCloserThanTheMinimumStep() {
        var s = InkStroke(start: .zero)
        let added = [CGPoint(x: 1, y: 0), CGPoint(x: 1, y: 1), CGPoint(x: 1.5, y: 0)].map {
            s.add($0)
        }
        #expect(added == [false, false, true])
        #expect(s.points.count == 2)
    }

    @Test func stopsAtTheCap() {
        var s = InkStroke(start: .zero)
        for i in 1..<(InkStroke.maxPoints + 10) { s.add(CGPoint(x: CGFloat(i) * 2, y: 0)) }
        #expect(s.points.count == InkStroke.maxPoints)
        #expect(s.isFull)
        let added = s.add(CGPoint(x: -100, y: 0))
        #expect(!added)
    }

    @Test func aSinglePointIsADot() {
        let s = InkStroke(start: CGPoint(x: 4, y: 5))
        #expect(!s.path.isEmpty)
        #expect(s.path.boundingBoxOfPath == CGRect(x: 4, y: 5, width: 0, height: 0))
    }

    @Test func twoPointsAreAStraightLine() {
        var s = InkStroke(start: .zero)
        s.add(CGPoint(x: 10, y: 0))
        #expect(s.path.boundingBoxOfPath == CGRect(x: 0, y: 0, width: 10, height: 0))
    }

    @Test func manyPointsGiveASmoothPathFromFirstToLast() {
        var s = InkStroke(start: .zero)
        let pts = [CGPoint(x: 10, y: 10), CGPoint(x: 20, y: 0), CGPoint(x: 30, y: 10)]
        for p in pts { s.add(p) }
        let path = s.path
        #expect(path.currentPoint == CGPoint(x: 30, y: 10))
        var quads = 0
        path.applyWithBlock { if $0.pointee.type == .addQuadCurveToPoint { quads += 1 } }
        #expect(quads == 2)
        // Smoothing cuts corners: the curve stays inside the samples' bounds.
        let box = path.boundingBoxOfPath
        #expect(box.minX == 0 && box.maxX == 30)
        #expect(box.minY >= 0 && box.maxY <= 10)
    }
}

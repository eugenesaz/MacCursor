import CoreGraphics
import Testing

@testable import MacCursorRender

@Suite struct SVGPathDataTests {
    private func box(_ d: String) throws -> CGRect {
        try SVGPathData.parse(d).boundingBoxOfPath
    }

    private func failure(_ d: String) -> String? {
        do {
            _ = try SVGPathData.parse(d)
            return nil
        } catch {
            return error.message
        }
    }

    @Test func linesAbsoluteAndRelative() throws {
        #expect(try box("M0 0 L10 0 L10 5 Z") == CGRect(x: 0, y: 0, width: 10, height: 5))
        #expect(try box("m2 3 l10 0 l0 5 z") == CGRect(x: 2, y: 3, width: 10, height: 5))
        #expect(try box("M0 0 H8 V4 h-8 v-4") == CGRect(x: 0, y: 0, width: 8, height: 4))
    }

    @Test func extraPairsAfterMoveAreLines() throws {
        #expect(try box("M0 0 10 0 10 10") == CGRect(x: 0, y: 0, width: 10, height: 10))
        #expect(try box("m1 1 10 0 0 10") == CGRect(x: 1, y: 1, width: 10, height: 10))
    }

    @Test func compactNumbers() throws {
        // "1.5.5" is 1.5 then .5; "10-5" is 10 then -5; exponents.
        #expect(try box("M0,0L1.5.5") == CGRect(x: 0, y: 0, width: 1.5, height: 0.5))
        #expect(try box("M0 0L10-5") == CGRect(x: 0, y: -5, width: 10, height: 5))
        #expect(try box("M0 0L1e1 2E0") == CGRect(x: 0, y: 0, width: 10, height: 2))
    }

    @Test func curvesAndReflections() throws {
        let p = try SVGPathData.parse("M0 0 C0 10 10 10 10 0 S20 -10 20 0 Q25 5 30 0 T40 0")
        let b = p.boundingBoxOfPath
        #expect(abs(b.minX) < 0.001 && abs(b.maxX - 40) < 0.001)
        #expect(b.maxY > 7 && b.minY < -7)
        // T after Q reflects the control point: the curve dips below the axis.
        #expect(p.boundingBoxOfPath.minY < 0)
    }

    @Test func arcMakesAHalfCircle() throws {
        // Upper half circle of radius 10 from (0,0) to (20,0), sweep 1 in y-down space.
        let p = try SVGPathData.parse("M0 0 A10 10 0 0 1 20 0")
        let b = p.boundingBoxOfPath
        #expect(abs(b.width - 20) < 0.01)
        #expect(abs(b.minY + 10) < 0.05)
        #expect(abs(b.maxY) < 0.01)
    }

    @Test func arcFlagsRunTogether() throws {
        let a = try box("M0 0 A10 10 0 1 1 20 0")
        let b = try box("M0 0A10 10 0 1120 0")
        #expect(abs(a.minY - b.minY) < 0.001 && abs(a.width - b.width) < 0.001)
    }

    @Test func arcEdgeCases() throws {
        // Zero radius is a straight line; too-small radii are scaled up to reach the end.
        #expect(try box("M0 0 A0 5 0 0 1 10 0") == CGRect(x: 0, y: 0, width: 10, height: 0))
        let b = try box("M0 0 A1 1 0 0 1 20 0")
        #expect(abs(b.height - 10) < 0.05)
        // Same start and end: nothing drawn.
        #expect(try SVGPathData.parse("M5 5 A3 3 0 0 1 5 5").boundingBoxOfPath.width == 0)
    }

    @Test func fullCircleFromTwoArcs() throws {
        let p = try SVGPathData.parse("M-10 0 A10 10 0 1 0 10 0 A10 10 0 1 0 -10 0 Z")
        #expect(p.contains(.zero))
        #expect(!p.contains(CGPoint(x: 9, y: 9)))
        #expect(abs(p.boundingBoxOfPath.height - 20) < 0.05)
    }

    @Test func malformedDataIsRejected() {
        #expect(failure("L0 0") == "path data must start with a move (M) command")
        #expect(failure("10 10") == "path data must start with a move (M) command")
        #expect(failure("M0 0 L5") == "expected a number at position 7")
        #expect(failure("M0 0 L5 x") == "expected a number at position 8")
        #expect(failure("M0 0 A5 5 0 2 1 9 9") == "expected an arc flag (0 or 1) at position 12")
        #expect(failure("M0 0 Z 5") == "unexpected number after Z at position 7")
        #expect(failure("M0 0 X5 5")?.hasPrefix("expected a number") == true)
    }

    @Test func emptyDataIsAnEmptyPath() throws {
        #expect(try SVGPathData.parse("").isEmpty)
    }
}

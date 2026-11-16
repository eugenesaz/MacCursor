import CoreGraphics

/// Presentation mode's mouse-only way out: press and hold, without moving, to turn it off.
public struct HoldToExit: Sendable {
    public static let duration: Double = 2
    /// How far the pointer may drift, in points, before the hold no longer counts.
    public static let tolerance: CGFloat = 8

    private var press: (at: CGPoint, time: Double)?

    public init() {}

    public var isHolding: Bool { press != nil }

    public mutating func down(at p: CGPoint, time: Double) { press = (p, time) }

    public mutating func moved(to p: CGPoint) {
        guard let press else { return }
        if hypot(p.x - press.at.x, p.y - press.at.y) > Self.tolerance { self.press = nil }
    }

    public mutating func up() { press = nil }

    /// True once, when the press has been held long enough; then the hold is over.
    public mutating func fire(now: Double) -> Bool {
        guard let press, now - press.time >= Self.duration else { return false }
        self.press = nil
        return true
    }
}

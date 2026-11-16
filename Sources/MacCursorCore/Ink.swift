import CoreGraphics

public enum InkMode: Sendable {
    /// Disappears on its own a few seconds after the line ends.
    case fading
    /// Stays until cleared.
    case lasting

    /// Exactly ⌘ → fading, exactly ⌘⌥ → lasting; any other combination doesn't draw.
    public init?(keys: HeldKeys) {
        switch keys {
        case [.command]: self = .fading
        case [.command, .option]: self = .lasting
        default: return nil
        }
    }
}

/// The modifier keys that matter for drawing.
public struct HeldKeys: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let command = HeldKeys(rawValue: 1 << 0)
    public static let option = HeldKeys(rawValue: 1 << 1)
    public static let control = HeldKeys(rawValue: 1 << 2)
    public static let shift = HeldKeys(rawValue: 1 << 3)
    public static let function = HeldKeys(rawValue: 1 << 4)
}

/// One press of the mouse button. A press made with ⌘ or ⌘⌥ held draws until the button is
/// released, and the press, drags and release are all kept from the app underneath.
public struct InkGesture: Sendable {
    /// A drawing press is in progress (its events are claimed until `up`).
    public private(set) var isActive = false
    private var stopped = false

    public init() {}

    /// The button went down. Returns the mode when this press draws.
    public mutating func down(keys: HeldKeys) -> InkMode? {
        guard let mode = InkMode(keys: keys) else { return nil }
        isActive = true
        stopped = false
        return mode
    }

    /// The mouse moved with the button down. Returns the mode to draw in: switching ⌥ switches
    /// it; letting go of ⌘ stops drawing until the button is released.
    public mutating func drag(keys: HeldKeys) -> InkMode? {
        guard isActive, !stopped else { return nil }
        let mode = InkMode(keys: keys)
        if mode == nil { stopped = true }
        return mode
    }

    /// The button went up. Returns whether it ends a drawing press (and is claimed too).
    public mutating func up() -> Bool {
        defer {
            isActive = false
            stopped = false
        }
        return isActive
    }
}

/// One line of ink: the sampled points and a smoothed path through them.
public struct InkStroke: Sendable {
    /// Points closer than this to the previous one are skipped.
    public static let minStep: CGFloat = 1.5
    /// A longer line carries on as a new stroke, so redrawing the path stays cheap.
    public static let maxPoints = 1000

    public private(set) var points: [CGPoint]

    public init(start: CGPoint) { points = [start] }

    public var isFull: Bool { points.count >= Self.maxPoints }
    public var last: CGPoint { points[points.count - 1] }

    /// Adds `p` unless it's too close to the last point or the stroke is full.
    /// Returns whether it was added.
    @discardableResult
    public mutating func add(_ p: CGPoint) -> Bool {
        guard !isFull, hypot(p.x - last.x, p.y - last.y) >= Self.minStep else { return false }
        points.append(p)
        return true
    }

    /// Quadratic curves through the midpoints of the samples, with the samples as control
    /// points. A single point is a zero-length line, which round caps draw as a dot.
    public var path: CGPath {
        let path = CGMutablePath()
        let first = points[0]
        path.move(to: first)
        guard points.count > 2 else {
            path.addLine(to: last)
            return path
        }
        path.addLine(to: mid(first, points[1]))
        for i in 1..<(points.count - 1) {
            path.addQuadCurve(to: mid(points[i], points[i + 1]), control: points[i])
        }
        path.addLine(to: last)
        return path
    }

    private func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

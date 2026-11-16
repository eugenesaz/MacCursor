import CoreGraphics

public enum InkMode: Sendable {
    /// Disappears on its own a few seconds after the line ends.
    case fading
    /// Stays until cleared.
    case lasting
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

/// Decides whether moving the mouse draws, from polled input state (no key events, so no
/// Accessibility permission). Hold ⌘ for fading ink, ⌘⌥ for lasting ink.
///
/// ⌘ is part of every shortcut, so a hold during which a key is typed (⌘C, ⌘-Tab) or a mouse
/// button is pressed (⌘-click) draws nothing more until ⌘ is released.
public struct InkTrigger: Sendable {
    /// The key-press counter when this ⌘ hold was first seen; nil while ⌘ is up.
    private var keyCountAtHold: UInt32?
    private var spoiled = false

    public init() {}

    /// `keyDownCount`: a counter that goes up with every key press (system-wide).
    public mutating func update(keys: HeldKeys, buttonDown: Bool, keyDownCount: UInt32)
        -> InkMode?
    {
        guard keys.contains(.command) else {
            keyCountAtHold = nil
            spoiled = false
            return nil
        }
        if let start = keyCountAtHold {
            if keyDownCount != start { spoiled = true }
        } else {
            keyCountAtHold = keyDownCount
        }
        if buttonDown { spoiled = true }
        guard !spoiled else { return nil }
        switch keys {
        case [.command]: return .fading
        case [.command, .option]: return .lasting
        default: return nil
        }
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

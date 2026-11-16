import CoreGraphics

/// Display geometry in AppKit global coordinates (origin at the bottom-left of the main
/// display, y up). Plain values, so it's testable without real screens.
public struct DisplayLayout: Sendable {
    public let frames: [CGRect]

    public init(frames: [CGRect]) { self.frames = frames }

    /// The display that shows the pointer at `p`. Uses AppKit's mouse convention
    /// (`NSMouseInRect`, not flipped): x in [minX, maxX), y in (minY, maxY]. A point in a
    /// gap between displays goes to the nearest one.
    public func index(containing p: CGPoint) -> Int? {
        if let i = frames.firstIndex(where: { Self.contains($0, p) }) { return i }
        return frames.indices.min { Self.distance(p, frames[$0]) < Self.distance(p, frames[$1]) }
    }

    /// `p` relative to the display's bottom-left corner.
    public static func local(_ p: CGPoint, in frame: CGRect) -> CGPoint {
        CGPoint(x: p.x - frame.minX, y: p.y - frame.minY)
    }

    /// The leg leans in from the lower right: 28° at the left edge, 8° at the right edge.
    /// Radians, counterclockwise.
    public static func leanAngle(localX: Double, width: Double) -> Double {
        let fx = width > 0 ? (localX / width).clamped(to: 0...1) : 0.5
        return (8 + 20 * (1 - fx)) * .pi / 180
    }

    static func contains(_ r: CGRect, _ p: CGPoint) -> Bool {
        p.x >= r.minX && p.x < r.maxX && p.y > r.minY && p.y <= r.maxY
    }

    static func distance(_ p: CGPoint, _ r: CGRect) -> Double {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX)
        let dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }
}

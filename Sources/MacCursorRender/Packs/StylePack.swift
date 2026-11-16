import CoreGraphics
import MacCursorCore

/// A pointer style, ready to draw: what a pack's `style.json` and `art.svg` describe.
/// Coordinates: the hotspot is (0,0), y points up, the art extends downward (negative y).
/// CGPath and CGColor are immutable, so sharing packs across threads is safe.
public struct StylePack: @unchecked Sendable {
    public var id: String
    public var name: String
    public var author = ""
    public var license = ""
    public var version: String? = nil

    /// The silhouette: filled, and outlined per `outline`.
    public var body: Layer
    /// Drawn in order on top of the body (pads, nails, ink, shading…).
    public var details: [Layer] = []
    public var outline: Outline = .palette
    /// Drawn around the system arrow, which stays visible; no poke squash on click.
    public var overlay = false
    public var tail: Tail? = nil
    public var click = Click()

    public init(
        id: String, name: String, body: Layer, details: [Layer] = [],
        outline: Outline = .palette, overlay: Bool = false, tail: Tail? = nil,
        click: Click = Click()
    ) {
        self.id = id
        self.name = name
        self.body = body
        self.details = details
        self.outline = outline
        self.overlay = overlay
        self.tail = tail
        self.click = click
    }

    /// Whether the Tail slider changes this style.
    public var hasTail: Bool { tail != nil }

    public var jet: Jet? {
        if case .jet(let j) = tail { return j }
        return nil
    }

    /// The leg, if the tail is one.
    public var leg: Leg? {
        if case .leg(let l) = tail { return l }
        return nil
    }

    /// A colour that may differ on dark screens.
    public struct Color: @unchecked Sendable {
        public var forLightScreens: CGColor
        public var forDarkScreens: CGColor

        public init(_ c: CGColor, dark: CGColor? = nil) {
            forLightScreens = c
            forDarkScreens = dark ?? c
        }

        public func resolved(_ palette: Palette) -> CGColor {
            palette.kind == .forDarkScreens ? forDarkScreens : forLightScreens
        }
    }

    public struct Layer: @unchecked Sendable {
        public var path: CGPath
        public var color: Color
        public var evenOdd = false

        public init(_ path: CGPath, _ color: Color, evenOdd: Bool = false) {
            self.path = path
            self.color = color
            self.evenOdd = evenOdd
        }

        public init(_ path: CGPath, _ color: CGColor, evenOdd: Bool = false) {
            self.init(path, Color(color), evenOdd: evenOdd)
        }
    }

    public enum Outline: @unchecked Sendable {
        /// A thick outline in the palette's colour (dark on light screens, light on dark).
        case palette
        /// A plain stroke of a fixed colour, with no palette outline (the ring).
        case stroke(Color, width: CGFloat)
    }

    public enum Tail: @unchecked Sendable {
        case leg(Leg)
        case jet(Jet)
    }

    /// A jet flame instead of a leg: an outer flame and a brighter core, flickering lengthwise.
    /// Paths are relative to `join`, where the flame attaches, and point down (negative y).
    public struct Jet: @unchecked Sendable {
        public var flame: CGPath
        public var core: CGPath
        public var color: Color
        public var coreColor: Color
        public var join: CGPoint

        public init(flame: CGPath, core: CGPath, color: Color, coreColor: Color, join: CGPoint) {
            self.flame = flame
            self.core = core
            self.color = color
            self.coreColor = coreColor
            self.join = join
        }
    }

    /// A fading leg or sleeve reaching in from off-screen.
    public struct Leg: @unchecked Sendable {
        public var width: CGFloat
        /// Where the leg joins the art: its centre line's x, and the y of the join.
        public var join: CGPoint
        public var color: Color

        public init(width: CGFloat, join: CGPoint, color: Color) {
            self.width = width
            self.join = join
            self.color = color
        }
    }

    public struct Click: @unchecked Sendable {
        /// The ripple's colour; nil = the palette's effect colour.
        public var ripple: Color? = nil
        public var stamp: Stamp? = nil
        public var particles: Particles? = nil

        public init(ripple: Color? = nil, stamp: Stamp? = nil, particles: Particles? = nil) {
            self.ripple = ripple
            self.stamp = stamp
            self.particles = particles
        }
    }

    /// A print left behind on click, centred at (0,0) of its own path.
    public struct Stamp: @unchecked Sendable {
        public var path: CGPath
        /// Where it lands along the tail, from the tip (negative = toward the leg).
        public var offset: CGFloat

        public init(_ path: CGPath, offset: CGFloat) {
            self.path = path
            self.offset = offset
        }
    }

    public struct Particles: @unchecked Sendable {
        public var path: CGPath
        public var color: Color
        /// A palette-coloured outline behind each particle.
        public var outlined = true
        /// Each particle points the way it flies (art "up" = outward) and doesn't spin.
        public var facesOutward = false
        /// Particles start at the click point instead of a small ring around it.
        public var fromCenter = false
        /// Particles on every click; fast clicking adds more.
        public var minimum = 0

        public init(
            _ path: CGPath, color: Color, outlined: Bool = true, facesOutward: Bool = false,
            fromCenter: Bool = false, minimum: Int = 0
        ) {
            self.path = path
            self.color = color
            self.outlined = outlined
            self.facesOutward = facesOutward
            self.fromCenter = fromCenter
            self.minimum = minimum
        }
    }
}

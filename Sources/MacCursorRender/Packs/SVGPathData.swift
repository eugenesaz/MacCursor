import CoreGraphics
import Foundation

/// Parses SVG path data (the `d` attribute): every command, absolute and relative,
/// with implicit repeats. Arcs become cubic Béziers. Coordinates stay in SVG space (y down).
enum SVGPathData {
    struct Failure: Error, Equatable {
        let message: String
    }

    static func parse(_ d: String) throws(Failure) -> CGPath {
        var s = Scanner(Array(d.utf8))
        let path = CGMutablePath()
        var cur = CGPoint.zero
        var start = CGPoint.zero
        // The previous segment's second control point, for S and T reflection.
        var lastCubic: CGPoint?
        var lastQuad: CGPoint?
        var command: UInt8?
        var started = false

        while true {
            s.skipSeparators()
            guard let c = s.peek else { break }
            if Scanner.isCommand(c) {
                command = c
                s.advance()
                if !started && c != UInt8(ascii: "M") && c != UInt8(ascii: "m") {
                    throw Failure(message: "path data must start with a move (M) command")
                }
                started = true
                if c == UInt8(ascii: "Z") || c == UInt8(ascii: "z") {
                    path.closeSubpath()
                    cur = start
                    lastCubic = nil
                    lastQuad = nil
                    continue
                }
            } else if command == nil {
                throw Failure(message: "path data must start with a move (M) command")
            } else if command == UInt8(ascii: "Z") || command == UInt8(ascii: "z") {
                throw Failure(message: "unexpected number after Z at position \(s.position)")
            }
            guard let cmd = command else { break }
            let rel = cmd >= UInt8(ascii: "a")
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                rel ? CGPoint(x: cur.x + x, y: cur.y + y) : CGPoint(x: x, y: y)
            }
            var nextCubic: CGPoint?
            var nextQuad: CGPoint?
            switch cmd | 0x20 {  // lowercase
            case UInt8(ascii: "m"):
                let p = pt(try s.number(), try s.number())
                path.move(to: p)
                cur = p
                start = p
                // Further coordinate pairs after a move are lines.
                command = rel ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                let p = pt(try s.number(), try s.number())
                path.addLine(to: p)
                cur = p
            case UInt8(ascii: "h"):
                let x = try s.number()
                cur = CGPoint(x: rel ? cur.x + x : x, y: cur.y)
                path.addLine(to: cur)
            case UInt8(ascii: "v"):
                let y = try s.number()
                cur = CGPoint(x: cur.x, y: rel ? cur.y + y : y)
                path.addLine(to: cur)
            case UInt8(ascii: "c"):
                let c1 = pt(try s.number(), try s.number())
                let c2 = pt(try s.number(), try s.number())
                let p = pt(try s.number(), try s.number())
                path.addCurve(to: p, control1: c1, control2: c2)
                cur = p
                nextCubic = c2
            case UInt8(ascii: "s"):
                let c1 = lastCubic.map { reflect($0, about: cur) } ?? cur
                let c2 = pt(try s.number(), try s.number())
                let p = pt(try s.number(), try s.number())
                path.addCurve(to: p, control1: c1, control2: c2)
                cur = p
                nextCubic = c2
            case UInt8(ascii: "q"):
                let c = pt(try s.number(), try s.number())
                let p = pt(try s.number(), try s.number())
                path.addQuadCurve(to: p, control: c)
                cur = p
                nextQuad = c
            case UInt8(ascii: "t"):
                let c = lastQuad.map { reflect($0, about: cur) } ?? cur
                let p = pt(try s.number(), try s.number())
                path.addQuadCurve(to: p, control: c)
                cur = p
                nextQuad = c
            case UInt8(ascii: "a"):
                let rx = try s.number()
                let ry = try s.number()
                let rotation = try s.number()
                let large = try s.flag()
                let sweep = try s.flag()
                let p = pt(try s.number(), try s.number())
                addArc(
                    to: path, from: cur, rx: rx, ry: ry, degrees: rotation, large: large,
                    sweep: sweep, end: p)
                cur = p
            default:
                throw Failure(message: "unknown path command at position \(s.position)")
            }
            lastCubic = nextCubic
            lastQuad = nextQuad
        }
        return path
    }

    private static func reflect(_ p: CGPoint, about c: CGPoint) -> CGPoint {
        CGPoint(x: 2 * c.x - p.x, y: 2 * c.y - p.y)
    }

    /// Endpoint arc → cubics, per SVG 1.1 implementation notes F.6.5–F.6.6.
    static func addArc(
        to path: CGMutablePath, from p0: CGPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat,
        large: Bool, sweep: Bool, end p: CGPoint
    ) {
        if p0 == p { return }
        var rx = abs(rx)
        var ry = abs(ry)
        if rx == 0 || ry == 0 {
            path.addLine(to: p)
            return
        }
        let phi = degrees * .pi / 180
        let cosP = cos(phi)
        let sinP = sin(phi)
        let dx2 = (p0.x - p.x) / 2
        let dy2 = (p0.y - p.y) / 2
        let x1 = cosP * dx2 + sinP * dy2
        let y1 = -sinP * dx2 + cosP * dy2
        // Radii too small to reach the end point are scaled up just enough.
        let lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry)
        if lambda > 1 {
            rx *= lambda.squareRoot()
            ry *= lambda.squareRoot()
        }
        let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
        let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
        let coef = (large != sweep ? 1 : -1) * max(0, num / den).squareRoot()
        let cxp = coef * rx * y1 / ry
        let cyp = -coef * ry * x1 / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let theta = angle(1, 0, (x1 - cxp) / rx, (y1 - cyp) / ry)
        var delta = angle((x1 - cxp) / rx, (y1 - cyp) / ry, (-x1 - cxp) / rx, (-y1 - cyp) / ry)
        if !sweep && delta > 0 { delta -= 2 * .pi }
        if sweep && delta < 0 { delta += 2 * .pi }

        let n = max(1, Int((abs(delta) / (.pi / 2)).rounded(.up)))
        let step = delta / CGFloat(n)
        let t = 4 / 3 * tan(step / 4)
        func map(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(
                x: cx + rx * x * cosP - ry * y * sinP,
                y: cy + rx * x * sinP + ry * y * cosP)
        }
        for i in 0..<n {
            let a1 = theta + CGFloat(i) * step
            let a2 = a1 + step
            let c1 = map(cos(a1) - t * sin(a1), sin(a1) + t * cos(a1))
            let c2 = map(cos(a2) + t * sin(a2), sin(a2) - t * cos(a2))
            // The last segment ends exactly on the requested point.
            let to = i == n - 1 ? p : map(cos(a2), sin(a2))
            path.addCurve(to: to, control1: c1, control2: c2)
        }
    }
}

/// A byte scanner for SVG number lists: path data, `points`, `transform` arguments.
struct Scanner {
    private let bytes: [UInt8]
    private(set) var position = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var peek: UInt8? { position < bytes.count ? bytes[position] : nil }
    var atEnd: Bool { position >= bytes.count }
    mutating func advance() { position += 1 }

    static func isCommand(_ c: UInt8) -> Bool {
        "MmLlHhVvCcSsQqTtAaZz".utf8.contains(c)
    }

    static func isSpace(_ c: UInt8) -> Bool { c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D }

    mutating func skipSeparators() {
        while let c = peek, Self.isSpace(c) || c == UInt8(ascii: ",") { advance() }
    }

    /// A number: sign, digits, a fraction and an exponent. "1.5.5" is 1.5 then .5; "1-2" is 1, -2.
    mutating func number() throws(SVGPathData.Failure) -> CGFloat {
        skipSeparators()
        let begin = position
        if let c = peek, c == UInt8(ascii: "+") || c == UInt8(ascii: "-") { advance() }
        var digits = 0
        while let c = peek, Self.isDigit(c) {
            advance()
            digits += 1
        }
        if peek == UInt8(ascii: ".") {
            advance()
            while let c = peek, Self.isDigit(c) {
                advance()
                digits += 1
            }
        }
        if digits > 0, let c = peek, c == UInt8(ascii: "e") || c == UInt8(ascii: "E") {
            let mark = position
            advance()
            if let c = peek, c == UInt8(ascii: "+") || c == UInt8(ascii: "-") { advance() }
            var expDigits = 0
            while let c = peek, Self.isDigit(c) {
                advance()
                expDigits += 1
            }
            if expDigits == 0 { position = mark }
        }
        guard digits > 0,
            let text = String(bytes: bytes[begin..<position], encoding: .ascii),
            let value = Double(text), value.isFinite
        else {
            position = begin
            throw SVGPathData.Failure(message: "expected a number at position \(begin)")
        }
        return CGFloat(value)
    }

    /// An arc flag: a single 0 or 1, which may be run together with what follows ("110").
    mutating func flag() throws(SVGPathData.Failure) -> Bool {
        skipSeparators()
        switch peek {
        case UInt8(ascii: "0"):
            advance()
            return false
        case UInt8(ascii: "1"):
            advance()
            return true
        default:
            throw SVGPathData.Failure(
                message: "expected an arc flag (0 or 1) at position \(position)")
        }
    }

    private static func isDigit(_ c: UInt8) -> Bool { c >= 0x30 && c <= 0x39 }
}

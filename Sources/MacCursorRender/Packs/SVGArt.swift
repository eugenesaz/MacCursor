import CoreGraphics
import Foundation

/// The art from a pack's SVG file: one path per element `id`, in SVG coordinates (y down).
/// Reads a strict subset (see `docs/style-packs.md`) so the art never silently looks different
/// from the editor, and refuses anything that could reference other files or run code.
struct SVGArt {
    /// Every element with an `id` that is a shape, or a group with shapes in it.
    var paths: [String: CGPath] = [:]
    /// Ids whose element asked for `fill-rule="evenodd"`.
    var evenOdd: Set<String> = []
    var problems: [PackProblem] = []
    var warnings: [PackProblem] = []

    static let file = "art.svg"

    /// Elements we draw or safely skip. Anything else (except other XML namespaces, such as
    /// an editor's own metadata) is an error.
    static let shapes: Set<String> = ["path", "rect", "circle", "ellipse", "polygon", "polyline"]
    static let containers: Set<String> = ["svg", "g"]
    static let skipped: Set<String> = ["title", "desc", "metadata", "defs"]
    /// Never allowed, anywhere, including inside `defs`.
    static let forbidden: Set<String> = [
        "image", "use", "text", "style", "script", "foreignObject", "iframe", "a", "feImage",
    ]

    static func read(_ data: Data, file: String = SVGArt.file) -> SVGArt {
        var art = SVGArt()
        // Entities can expand without bound and DTDs can point at other files: refuse both.
        if data.range(of: Data("<!DOCTYPE".utf8)) != nil
            || data.range(of: Data("<!ENTITY".utf8)) != nil
        {
            art.problems.append(
                PackProblem(file: file, "must not contain a DOCTYPE or ENTITY declaration"))
            return art
        }
        let reader = Reader(file: file)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.shouldProcessNamespaces = false
        parser.delegate = reader
        if !parser.parse() && reader.problems.isEmpty {
            let line = parser.lineNumber
            let why = parser.parserError?.localizedDescription ?? "unknown error"
            reader.problems.append(
                PackProblem(file: file, "isn't well-formed XML (line \(line)): \(why)"))
        }
        if !reader.sawRoot && reader.problems.isEmpty {
            reader.problems.append(PackProblem(file: file, "has no <svg> root element"))
        }
        art.problems = reader.problems
        art.warnings = reader.warnings
        art.paths = reader.paths.mapValues { $0 as CGPath }
        art.evenOdd = reader.evenOdd
        return art
    }

    private final class Reader: NSObject, XMLParserDelegate {
        let file: String
        var problems: [PackProblem] = []
        var warnings: [PackProblem] = []
        var paths: [String: CGMutablePath] = [:]
        var evenOdd: Set<String> = []
        var sawRoot = false

        private struct Frame {
            var transform: CGAffineTransform
            var id: String?
            /// Inside defs/title/desc/metadata or another namespace: not drawn.
            var hidden: Bool
        }
        private var stack: [Frame] = []
        private var warnedStroke = false

        init(file: String) { self.file = file }

        private func fail(_ name: String, _ message: String) {
            problems.append(PackProblem(file: file, location: "element <\(name)>", message))
        }

        func parser(
            _ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
            qualifiedName: String?, attributes: [String: String]
        ) {
            let parent = stack.last
            if stack.isEmpty {
                guard name == "svg" else {
                    fail(name, "must be inside an <svg> root element")
                    parser.abortParsing()
                    return
                }
                sawRoot = true
            }
            if SVGArt.forbidden.contains(name) {
                fail(name, "isn't allowed in a style pack (no images, text, styles or links)")
            }
            for key in attributes.keys {
                let k = key.lowercased()
                if k == "href" || k.hasSuffix(":href") {
                    fail(name, "must not link to anything (\(key))")
                } else if k.hasPrefix("on") {
                    fail(name, "must not have event handlers (\(key))")
                }
            }

            let namespaced = name.contains(":")
            var hidden =
                (parent?.hidden ?? false) || SVGArt.skipped.contains(name) || namespaced
                || SVGArt.forbidden.contains(name)
            if !hidden && !SVGArt.shapes.contains(name) && !SVGArt.containers.contains(name) {
                // Clip paths, gradients and the like only make sense inside defs.
                fail(name, "isn't supported; use only paths and basic shapes")
                hidden = true
            }

            var transform = parent?.transform ?? .identity
            if !hidden, let t = attributes["transform"] {
                switch SVGTransform.parse(t) {
                case .success(let local): transform = local.concatenating(transform)
                case .failure(let f): fail(name, "has a bad transform: \(f.message)")
                }
            }
            let id = attributes["id"].flatMap { $0.isEmpty ? nil : $0 }
            stack.append(Frame(transform: transform, id: hidden ? nil : id, hidden: hidden))
            guard !hidden else { return }

            if let id, fillRule(attributes) == "evenodd" { evenOdd.insert(id) }
            if let id, paths[id] == nil,
                SVGArt.containers.contains(name) || SVGArt.shapes.contains(name)
            {
                paths[id] = CGMutablePath()
            }
            for k in ["clip-path", "mask", "filter"] where attributes[k] != nil {
                warnings.append(
                    PackProblem(
                        file: file, location: "element <\(name)>", "\(k) is ignored"))
            }
            if !warnedStroke, let s = attributes["stroke"], s != "none",
                SVGArt.shapes.contains(name)
            {
                warnedStroke = true
                warnings.append(
                    PackProblem(
                        file: file, location: "element <\(name)>",
                        "has a stroke, which is ignored: convert strokes to outlines"))
            }
            guard SVGArt.shapes.contains(name) else { return }
            switch SVGShape.path(name, attributes) {
            case .failure(let f):
                fail(name, f.message)
            case .success(let shape):
                // The shape goes into its own id and every enclosing group's id.
                for frame in stack {
                    if let fid = frame.id { paths[fid]?.addPath(shape, transform: transform) }
                }
            }
        }

        func parser(
            _ parser: XMLParser, didEndElement name: String, namespaceURI: String?,
            qualifiedName: String?
        ) {
            stack.removeLast()
        }

        func parser(_ parser: XMLParser, foundCDATA block: Data) {
            if !(stack.last?.hidden ?? true) {
                problems.append(PackProblem(file: file, "must not contain CDATA sections"))
            }
        }

        /// `fill-rule` from the attribute or a `style="fill-rule: …"` declaration.
        private func fillRule(_ a: [String: String]) -> String? {
            if let r = a["fill-rule"] { return r.trimmingCharacters(in: .whitespaces) }
            guard let style = a["style"] else { return nil }
            for decl in style.split(separator: ";") {
                let kv = decl.split(separator: ":", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespaces)
                }
                if kv.count == 2, kv[0] == "fill-rule" { return kv[1] }
            }
            return nil
        }
    }
}

/// Basic shapes as paths.
enum SVGShape {
    static func path(_ name: String, _ a: [String: String]) -> Result<CGPath, SVGPathData.Failure> {
        do {
            return .success(try make(name, a))
        } catch let f as SVGPathData.Failure {
            return .failure(f)
        } catch {
            return .failure(SVGPathData.Failure(message: "\(error)"))
        }
    }

    private static func make(_ name: String, _ a: [String: String]) throws -> CGPath {
        func len(_ key: String, _ fallback: CGFloat? = nil) throws -> CGFloat {
            guard let raw = a[key] else {
                if let fallback { return fallback }
                throw SVGPathData.Failure(message: "needs a \(key) attribute")
            }
            var text = raw.trimmingCharacters(in: .whitespaces)
            if text.hasSuffix("px") { text.removeLast(2) }
            guard let v = Double(text), v.isFinite else {
                throw SVGPathData.Failure(message: "\(key) must be a plain number (got \"\(raw)\")")
            }
            return CGFloat(v)
        }
        switch name {
        case "path":
            guard let d = a["d"] else { throw SVGPathData.Failure(message: "needs a d attribute") }
            return try SVGPathData.parse(d)
        case "rect":
            let x = try len("x", 0)
            let y = try len("y", 0)
            let w = try len("width")
            let h = try len("height")
            guard w >= 0, h >= 0 else {
                throw SVGPathData.Failure(message: "width and height must not be negative")
            }
            var rx = a["rx"] != nil ? try len("rx") : nil
            var ry = a["ry"] != nil ? try len("ry") : nil
            rx = rx ?? ry
            ry = ry ?? rx
            let cw = min(max(rx ?? 0, 0), w / 2)
            let ch = min(max(ry ?? 0, 0), h / 2)
            let rect = CGRect(x: x, y: y, width: w, height: h)
            return cw > 0 && ch > 0
                ? CGPath(roundedRect: rect, cornerWidth: cw, cornerHeight: ch, transform: nil)
                : CGPath(rect: rect, transform: nil)
        case "circle":
            let r = try len("r")
            return CGPath(
                ellipseIn: CGRect(
                    x: try len("cx", 0) - r, y: try len("cy", 0) - r, width: 2 * r, height: 2 * r),
                transform: nil)
        case "ellipse":
            let rx = try len("rx")
            let ry = try len("ry")
            return CGPath(
                ellipseIn: CGRect(
                    x: try len("cx", 0) - rx, y: try len("cy", 0) - ry, width: 2 * rx,
                    height: 2 * ry), transform: nil)
        default:  // polygon, polyline
            var s = Scanner(Array((a["points"] ?? "").utf8))
            var pts: [CGPoint] = []
            while true {
                s.skipSeparators()
                if s.atEnd { break }
                pts.append(CGPoint(x: try s.number(), y: try s.number()))
            }
            guard pts.count >= 2 else {
                throw SVGPathData.Failure(message: "needs at least two points")
            }
            let p = CGMutablePath()
            p.addLines(between: pts)
            if name == "polygon" { p.closeSubpath() }
            return p
        }
    }
}

/// The `transform` attribute: a list of matrix, translate, scale, rotate, skewX, skewY.
enum SVGTransform {
    static func parse(_ text: String) -> Result<CGAffineTransform, SVGPathData.Failure> {
        var result = CGAffineTransform.identity
        var rest = Substring(text)
        while true {
            rest = rest.drop { $0.isWhitespace || $0 == "," }
            if rest.isEmpty { break }
            guard let open = rest.firstIndex(of: "("), let close = rest.firstIndex(of: ")"),
                open < close
            else {
                return .failure(SVGPathData.Failure(message: "can't read \"\(rest)\""))
            }
            let name = rest[..<open].trimmingCharacters(in: .whitespaces)
            var s = Scanner(Array(rest[rest.index(after: open)..<close].utf8))
            var args: [CGFloat] = []
            do {
                while true {
                    s.skipSeparators()
                    if s.atEnd { break }
                    args.append(try s.number())
                }
            } catch {
                return .failure(error)
            }
            let t: CGAffineTransform
            switch (name, args.count) {
            case ("matrix", 6):
                t = CGAffineTransform(
                    a: args[0], b: args[1], c: args[2], d: args[3], tx: args[4], ty: args[5])
            case ("translate", 1): t = CGAffineTransform(translationX: args[0], y: 0)
            case ("translate", 2): t = CGAffineTransform(translationX: args[0], y: args[1])
            case ("scale", 1): t = CGAffineTransform(scaleX: args[0], y: args[0])
            case ("scale", 2): t = CGAffineTransform(scaleX: args[0], y: args[1])
            case ("rotate", 1): t = CGAffineTransform(rotationAngle: args[0] * .pi / 180)
            case ("rotate", 3):
                t = CGAffineTransform(translationX: args[1], y: args[2])
                    .rotated(by: args[0] * .pi / 180)
                    .translatedBy(x: -args[1], y: -args[2])
            case ("skewX", 1):
                t = CGAffineTransform(a: 1, b: 0, c: tan(args[0] * .pi / 180), d: 1, tx: 0, ty: 0)
            case ("skewY", 1):
                t = CGAffineTransform(a: 1, b: tan(args[0] * .pi / 180), c: 0, d: 1, tx: 0, ty: 0)
            default:
                return .failure(
                    SVGPathData.Failure(
                        message: "\(name)() with \(args.count) numbers isn't supported"))
            }
            // "A B" applies B first, then A.
            result = t.concatenating(result)
            rest = rest[rest.index(after: close)...]
        }
        return .success(result)
    }
}

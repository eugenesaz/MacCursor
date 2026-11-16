import CoreGraphics
import Foundation

/// What `style.json` says, before its art is looked up in the SVG.
/// Positions are still in SVG coordinates; art is referenced by element id.
struct Manifest {
    static let file = "style.json"
    static let format = 1
    static let maxBytes = 64 * 1024

    var id = ""
    var name = ""
    var author = ""
    var license = ""
    var version: String?
    var artFile = "art.svg"
    var hotspot = CGPoint.zero

    struct Art {
        var id: String
        /// Where the reference came from, for messages: `"details[0].art"`.
        var keyPath: String
    }
    struct Colored {
        var art: Art
        var color: CGColor
    }
    var body: Colored?
    var details: [Colored] = []
    enum Outline {
        case palette
        case stroke(CGColor, CGFloat)
    }
    var outline = Outline.palette
    var overlay = false

    struct Leg {
        var width: CGFloat
        var join: CGPoint
        var color: CGColor
    }
    struct Jet {
        var flame: Art
        var core: Art
        var color: CGColor
        var coreColor: CGColor
        var join: CGPoint
        /// Points from the join to the flame's tip; nil = as drawn.
        var length: CGFloat?
    }
    var leg: Leg?
    var jet: Jet?

    /// nil = the palette's effect colour.
    var ripple: CGColor?
    var stamp: (art: Art, offset: CGFloat)?
    struct Particles {
        /// nil = the built-in dot.
        var art: Art?
        var color: CGColor
        var outlined: Bool
        var facesOutward: Bool
        var fromCenter: Bool
        var minimum: Int
    }
    var particles: Particles?

    /// Colour overrides for the light-on-dark palette.
    struct Dark {
        var body: CGColor?
        var details: [CGColor?] = []
        var outline: CGColor?
        var leg: CGColor?
        var jet: CGColor?
        var jetCore: CGColor?
        var ripple: CGColor?
        var particles: CGColor?
    }
    var dark = Dark()

    /// Reads and checks the manifest. Every problem is collected; `nil` only if it isn't JSON.
    static func read(_ data: Data) -> (Manifest?, problems: [PackProblem], warnings: [PackProblem])
    {
        let r = JSONReader(file: file)
        guard data.count <= maxBytes else {
            r.fail("", "is larger than 64 KB")
            return (nil, r.problems, [])
        }
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            r.fail("", "isn't valid JSON: \((error as NSError).localizedDescription)")
            return (nil, r.problems, [])
        }
        guard let top = root as? [String: Any] else {
            r.fail("", "must be a JSON object { … }")
            return (nil, r.problems, [])
        }
        var m = Manifest()
        r.allow(
            top, "",
            [
                "format", "id", "name", "author", "license", "version", "art", "hotspot", "body",
                "details", "outline", "overlay", "tail", "click", "darkScreens",
            ])

        switch top["format"] {
        case nil: r.fail("format", "is missing (use 1)")
        case let n as NSNumber where !r.isBool(n) && n.doubleValue == Double(format): break
        case let n as NSNumber where !r.isBool(n) && n.doubleValue > Double(format):
            r.fail("format", "is \(n), which needs a newer version of MacCursor")
        case let v?: r.fail("format", "must be 1 (got \(r.got(v)))")
        }

        if let id = r.string(top, "id", "") {
            if id.range(of: #"^[A-Za-z][A-Za-z0-9._-]{0,63}$"#, options: .regularExpression) == nil
            {
                r.fail(
                    "id",
                    "must start with a letter and use only letters, digits, \".\", \"_\" or \"-\" (at most 64; got \(r.got(id)))"
                )
            }
            m.id = id
        }
        if let name = r.string(top, "name", "") {
            if name.trimmingCharacters(in: .whitespaces).isEmpty || name.count > 40 {
                r.fail("name", "must be 1 to 40 characters (got \(name.count))")
            }
            m.name = name
        }
        if let author = r.string(top, "author", "") {
            if author.trimmingCharacters(in: .whitespaces).isEmpty { r.fail("author", "is empty") }
            m.author = author
        }
        if let license = r.string(top, "license", "") {
            if license.trimmingCharacters(in: .whitespaces).isEmpty {
                r.fail("license", "is empty")
            }
            m.license = license
        }
        m.version = r.string(top, "version", "", required: false)
        if let art = r.string(top, "art", "") {
            if art.range(of: #"^[A-Za-z0-9_-][A-Za-z0-9._-]*\.svg$"#, options: .regularExpression)
                == nil
            {
                r.fail(
                    "art", "must be a file name ending in .svg, with no folders (got \(r.got(art)))"
                )
            }
            m.artFile = art
        }
        if let p = r.point(top, "hotspot", "") { m.hotspot = p }

        if let body = r.object(top, "body", "") {
            m.body = r.colored(body, "body")
        }
        if let list = top["details"] {
            if let list = list as? [Any] {
                if list.count > 8 { r.fail("details", "has \(list.count) layers; at most 8") }
                for (i, item) in list.prefix(8).enumerated() {
                    guard let o = r.asObject(item, "details[\(i)]") else { continue }
                    if let c = r.colored(o, "details[\(i)]") { m.details.append(c) }
                }
            } else {
                r.fail("details", "must be a list [ … ] (got \(r.got(list)))")
            }
        }

        switch top["outline"] {
        case nil: break
        case let s as String where s == "palette": break
        case let o as [String: Any]:
            r.allow(o, "outline", ["color", "width"])
            let color = r.color(o, "color", "outline")
            let width = r.number(o, "width", "outline", 0.5...8)
            if let color, let width { m.outline = .stroke(color, width) }
        case let v?:
            r.fail("outline", "must be \"palette\" or { \"color\", \"width\" } (got \(r.got(v)))")
        }
        m.overlay = r.bool(top, "overlay", "") ?? false

        if let tail = r.object(top, "tail", "", required: false) {
            r.allow(tail, "tail", ["leg", "jet"])
            if tail["leg"] != nil && tail["jet"] != nil {
                r.fail("tail", "can have a leg or a jet, not both")
            }
            if let leg = r.object(tail, "leg", "tail", required: false) {
                r.allow(leg, "tail.leg", ["width", "join", "color"])
                let w = r.number(leg, "width", "tail.leg", 1...80)
                let j = r.point(leg, "join", "tail.leg")
                let c = r.color(leg, "color", "tail.leg")
                if let w, let j, let c { m.leg = Leg(width: w, join: j, color: c) }
            }
            if let jet = r.object(tail, "jet", "tail", required: false) {
                r.allow(jet, "tail.jet", ["flame", "core", "color", "coreColor", "join", "length"])
                let flame = r.art(jet, "flame", "tail.jet")
                let core = r.art(jet, "core", "tail.jet")
                let c = r.color(jet, "color", "tail.jet")
                let cc = r.color(jet, "coreColor", "tail.jet")
                let j = r.point(jet, "join", "tail.jet")
                let length = r.number(
                    jet, "length", "tail.jet", 1...PointerRig.legLength, required: false)
                if let flame, let core, let c, let cc, let j {
                    m.jet = Jet(
                        flame: flame, core: core, color: c, coreColor: cc, join: j, length: length)
                }
            }
            if tail["leg"] == nil && tail["jet"] == nil {
                r.fail("tail", "needs a \"leg\" or a \"jet\" (leave \"tail\" out for none)")
            }
        }

        if let click = r.object(top, "click", "", required: false) {
            r.allow(click, "click", ["ripple", "stamp", "particles"])
            switch click["ripple"] {
            case nil: break
            case let s as String where s == "effect": break
            case let v?:
                m.ripple = r.parseColor(v, "click.ripple", hint: "\"effect\" or a colour")
            }
            if let st = r.object(click, "stamp", "click", required: false) {
                r.allow(st, "click.stamp", ["art", "offset"])
                let art = r.art(st, "art", "click.stamp")
                let offset = r.number(st, "offset", "click.stamp", -200...200, required: false) ?? 0
                if let art { m.stamp = (art, offset) }
            }
            if let p = r.object(click, "particles", "click", required: false) {
                r.allow(
                    p, "click.particles",
                    ["art", "color", "outlined", "facing", "origin", "minimum"])
                var art: Art?
                var isDot = false
                if let a = r.string(p, "art", "click.particles", required: false) {
                    if a == "dot" {
                        isDot = true
                    } else {
                        art = Art(id: a, keyPath: "click.particles.art")
                    }
                } else if p["art"] == nil {
                    isDot = true
                }
                let color = r.color(p, "color", "click.particles")
                let outlined = r.bool(p, "outlined", "click.particles") ?? !isDot
                let facing =
                    r.choice(p, "facing", "click.particles", ["spin", "outward"]) ?? "spin"
                let origin = r.choice(p, "origin", "click.particles", ["ring", "center"]) ?? "ring"
                var minimum = 0
                if let n = r.number(p, "minimum", "click.particles", 0...16, required: false) {
                    if n != n.rounded() {
                        r.fail("click.particles.minimum", "must be a whole number (got \(n))")
                    }
                    minimum = Int(n)
                }
                if let color, art != nil || isDot {
                    m.particles = Particles(
                        art: art, color: color, outlined: outlined,
                        facesOutward: facing == "outward", fromCenter: origin == "center",
                        minimum: minimum)
                }
            }
        }

        if let d = r.object(top, "darkScreens", "", required: false) {
            let p = "darkScreens"
            r.allow(
                d, p,
                ["body", "details", "outline", "leg", "jet", "jetCore", "ripple", "particles"])
            m.dark.body = r.color(d, "body", p, required: false)
            m.dark.outline = r.color(d, "outline", p, required: false)
            m.dark.leg = r.color(d, "leg", p, required: false)
            m.dark.jet = r.color(d, "jet", p, required: false)
            m.dark.jetCore = r.color(d, "jetCore", p, required: false)
            m.dark.ripple = r.color(d, "ripple", p, required: false)
            m.dark.particles = r.color(d, "particles", p, required: false)
            if let list = d["details"] {
                if let list = list as? [Any] {
                    if list.count > m.details.count {
                        r.fail(
                            "darkScreens.details", "has more colours than \"details\" has layers")
                    }
                    m.dark.details = list.enumerated().map { i, v in
                        v is NSNull ? nil : r.parseColor(v, "darkScreens.details[\(i)]")
                    }
                } else {
                    r.fail("darkScreens.details", "must be a list of colours (got \(r.got(list)))")
                }
            }
        }
        return (m, r.problems, r.warnings)
    }
}

/// Typed reads from parsed JSON that record a problem, with its key path, for every mismatch.
final class JSONReader {
    let file: String
    var problems: [PackProblem] = []
    var warnings: [PackProblem] = []

    init(file: String) { self.file = file }

    func fail(_ path: String, _ message: String) {
        problems.append(
            PackProblem(file: file, location: path.isEmpty ? "" : "\"\(path)\"", message))
    }

    private func join(_ prefix: String, _ key: String) -> String {
        prefix.isEmpty ? key : "\(prefix).\(key)"
    }

    func isBool(_ n: NSNumber) -> Bool { CFGetTypeID(n) == CFBooleanGetTypeID() }

    /// A short description of a JSON value, for "(got …)".
    func got(_ v: Any) -> String {
        switch v {
        case let s as String: return "\"\(s.count > 40 ? String(s.prefix(40)) + "…" : s)\""
        case let n as NSNumber: return isBool(n) ? (n.boolValue ? "true" : "false") : "\(n)"
        case is [Any]: return "a list"
        case is [String: Any]: return "an object"
        case is NSNull: return "null"
        default: return "\(type(of: v))"
        }
    }

    /// Unknown keys are warnings, so packs made for a newer app still load.
    func allow(_ o: [String: Any], _ prefix: String, _ keys: Set<String>) {
        for k in o.keys.sorted() where !keys.contains(k) {
            warnings.append(
                PackProblem(
                    file: file, location: "\"\(join(prefix, k))\"", "isn't a known key; ignored"))
        }
    }

    func asObject(_ v: Any, _ path: String) -> [String: Any]? {
        if let o = v as? [String: Any] { return o }
        fail(path, "must be an object { … } (got \(got(v)))")
        return nil
    }

    func object(_ o: [String: Any], _ key: String, _ prefix: String, required: Bool = true)
        -> [String: Any]?
    {
        guard let v = o[key] else {
            if required { fail(join(prefix, key), "is missing") }
            return nil
        }
        return asObject(v, join(prefix, key))
    }

    func string(_ o: [String: Any], _ key: String, _ prefix: String, required: Bool = true)
        -> String?
    {
        guard let v = o[key] else {
            if required { fail(join(prefix, key), "is missing") }
            return nil
        }
        if let s = v as? String { return s }
        fail(join(prefix, key), "must be text in quotes (got \(got(v)))")
        return nil
    }

    func number(
        _ o: [String: Any], _ key: String, _ prefix: String, _ range: ClosedRange<CGFloat>,
        required: Bool = true
    ) -> CGFloat? {
        let path = join(prefix, key)
        guard let v = o[key] else {
            if required { fail(path, "is missing") }
            return nil
        }
        let lo = String(format: "%g", Double(range.lowerBound))
        let hi = String(format: "%g", Double(range.upperBound))
        if let n = v as? NSNumber, !isBool(n), n.doubleValue.isFinite,
            range.contains(CGFloat(n.doubleValue))
        {
            return CGFloat(n.doubleValue)
        }
        fail(path, "must be a number from \(lo) to \(hi) (got \(got(v)))")
        return nil
    }

    func bool(_ o: [String: Any], _ key: String, _ prefix: String) -> Bool? {
        guard let v = o[key] else { return nil }
        if let n = v as? NSNumber, isBool(n) { return n.boolValue }
        fail(join(prefix, key), "must be true or false (got \(got(v)))")
        return nil
    }

    func choice(_ o: [String: Any], _ key: String, _ prefix: String, _ options: [String])
        -> String?
    {
        guard let v = o[key] else { return nil }
        if let s = v as? String, options.contains(s) { return s }
        let list = options.map { "\"\($0)\"" }.joined(separator: " or ")
        fail(join(prefix, key), "must be \(list) (got \(got(v)))")
        return nil
    }

    /// `[x, y]`, any finite numbers.
    func point(_ o: [String: Any], _ key: String, _ prefix: String) -> CGPoint? {
        let path = join(prefix, key)
        guard let v = o[key] else {
            fail(path, "is missing")
            return nil
        }
        if let a = v as? [Any], a.count == 2,
            let x = a[0] as? NSNumber, let y = a[1] as? NSNumber, !isBool(x), !isBool(y),
            x.doubleValue.isFinite, y.doubleValue.isFinite
        {
            return CGPoint(x: x.doubleValue, y: y.doubleValue)
        }
        fail(path, "must be a pair of numbers [x, y] (got \(got(v)))")
        return nil
    }

    func art(_ o: [String: Any], _ key: String, _ prefix: String) -> Manifest.Art? {
        guard let id = string(o, key, prefix) else { return nil }
        if id.isEmpty {
            fail(join(prefix, key), "is empty")
            return nil
        }
        return Manifest.Art(id: id, keyPath: join(prefix, key))
    }

    func color(_ o: [String: Any], _ key: String, _ prefix: String, required: Bool = true)
        -> CGColor?
    {
        guard let v = o[key] else {
            if required { fail(join(prefix, key), "is missing") }
            return nil
        }
        return parseColor(v, join(prefix, key))
    }

    func colored(_ o: [String: Any], _ prefix: String) -> Manifest.Colored? {
        allow(o, prefix, ["art", "color"])
        let a = art(o, "art", prefix)
        let c = color(o, "color", prefix)
        guard let a, let c else { return nil }
        return Manifest.Colored(art: a, color: c)
    }

    /// `#RGB`, `#RRGGBB` or `#RRGGBBAA`, sRGB.
    func parseColor(_ v: Any, _ path: String, hint: String = "a colour") -> CGColor? {
        if let s = v as? String, let c = Self.color(hex: s) { return c }
        fail(path, "must be \(hint) like \"#E8C08A\" or \"#E8C08A80\" (got \(got(v)))")
        return nil
    }

    static func color(hex: String) -> CGColor? {
        guard hex.hasPrefix("#") else { return nil }
        var digits = String(hex.dropFirst())
        guard digits.allSatisfy(\.isHexDigit) else { return nil }
        if digits.count == 3 { digits = digits.map { "\($0)\($0)" }.joined() }
        if digits.count == 6 { digits += "FF" }
        guard digits.count == 8, let v = UInt32(digits, radix: 16) else { return nil }
        return CGColor(
            srgbRed: CGFloat((v >> 24) & 0xFF) / 255, green: CGFloat((v >> 16) & 0xFF) / 255,
            blue: CGFloat((v >> 8) & 0xFF) / 255, alpha: CGFloat(v & 0xFF) / 255)
    }
}

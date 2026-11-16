import CoreGraphics
import Foundation

/// The outcome of loading one pack: the style if it's valid, and everything found wrong with it.
public struct PackLoad: @unchecked Sendable {
    public var pack: StylePack?
    /// Any problem means the pack isn't loaded.
    public var problems: [PackProblem]
    /// Things that are ignored, such as unknown keys or strokes in the art.
    public var warnings: [PackProblem]

    public init(pack: StylePack?, problems: [PackProblem], warnings: [PackProblem]) {
        self.pack = pack
        self.problems = problems
        self.warnings = warnings
    }

    public var isValid: Bool { pack != nil && problems.isEmpty }
}

/// Reads a pack (a folder, or files already in memory from a `.maccursorstyle`) into a
/// `StylePack`, checking every rule in `docs/style-packs.md`. Never throws or crashes on bad input.
public enum StylePackLoader {
    public static let maxArtBytes = 512 * 1024
    public static let maxSegments = 20_000
    /// How far from the hotspot art may reach, in points at 1×.
    public static let maxReach: CGFloat = 200

    /// Loads the pack in `folder`. Only `style.json` and the art file it names are read.
    public static func load(folder: URL) -> PackLoad {
        var files: [String: Data] = [:]
        var problems: [PackProblem] = []
        let manifestURL = folder.appendingPathComponent(Manifest.file)
        switch readFile(manifestURL, limit: Manifest.maxBytes) {
        case .success(let d): files[Manifest.file] = d
        case .failure(let p):
            problems.append(PackProblem(file: Manifest.file, p.message))
            return PackLoad(pack: nil, problems: problems, warnings: [])
        }
        // The art file name comes from the manifest; peek at it without the full checks.
        let artName = artFileName(files[Manifest.file] ?? Data()) ?? SVGArt.file
        if isPlainFileName(artName) {
            switch readFile(folder.appendingPathComponent(artName), limit: maxArtBytes) {
            case .success(let d): files[artName] = d
            case .failure(let p): problems.append(PackProblem(file: artName, p.message))
            }
        }
        var result = load(files: files)
        // A file that couldn't be read is reported once, not again as "missing".
        let unread = Set(problems.map(\.file))
        result.problems =
            problems
            + result.problems.filter { !(unread.contains($0.file) && $0.message == "is missing") }
        if !result.problems.isEmpty { result.pack = nil }
        return result
    }

    /// Loads a pack from its files' contents, keyed by file name.
    public static func load(files: [String: Data]) -> PackLoad {
        guard let json = files[Manifest.file] else {
            return PackLoad(
                pack: nil, problems: [PackProblem(file: Manifest.file, "is missing")], warnings: [])
        }
        let (read, manifestProblems, warnings) = Manifest.read(json)
        var problems = manifestProblems
        var allWarnings = warnings
        guard let m = read else {
            return PackLoad(pack: nil, problems: problems, warnings: warnings)
        }

        let artFile = m.artFile
        guard let svgData = files[artFile] else {
            if isPlainFileName(artFile) {
                problems.append(PackProblem(file: artFile, "is missing"))
            }
            return PackLoad(pack: nil, problems: problems, warnings: allWarnings)
        }
        guard svgData.count <= maxArtBytes else {
            problems.append(PackProblem(file: artFile, "is larger than 512 KB"))
            return PackLoad(pack: nil, problems: problems, warnings: allWarnings)
        }
        let svg = SVGArt.read(svgData, file: artFile)
        problems += svg.problems
        allWarnings += svg.warnings
        guard svg.problems.isEmpty else {
            return PackLoad(pack: nil, problems: problems, warnings: allWarnings)
        }

        // SVG space (y down, hotspot anywhere) → pointer space (y up, hotspot at 0,0).
        let toPointer = CGAffineTransform(
            a: 1, b: 0, c: 0, d: -1, tx: -m.hotspot.x, ty: m.hotspot.y)
        var segments = 0
        func path(_ art: Manifest.Art, relativeTo origin: CGPoint = .zero) -> CGPath? {
            guard let raw = svg.paths[art.id] else {
                problems.append(
                    PackProblem(
                        file: artFile, location: "element \"\(art.id)\"",
                        "not found (referenced by \"\(art.keyPath)\")"))
                return nil
            }
            var t = toPointer.concatenating(
                CGAffineTransform(translationX: -origin.x, y: -origin.y))
            let p = raw.copy(using: &t) ?? raw
            segments += p.segmentCount
            let box = p.boundingBoxOfPath
            if p.isEmpty || box.isNull {
                problems.append(
                    PackProblem(file: artFile, location: "element \"\(art.id)\"", "is empty"))
                return nil
            }
            let reach = max(
                abs(box.minX + origin.x), abs(box.maxX + origin.x), abs(box.minY + origin.y),
                abs(box.maxY + origin.y))
            if reach > maxReach {
                problems.append(
                    PackProblem(
                        file: artFile, location: "element \"\(art.id)\"",
                        "reaches \(Int(reach)) pt from the hotspot; keep art within 200 pt"))
            }
            return p
        }
        func evenOdd(_ art: Manifest.Art) -> Bool { svg.evenOdd.contains(art.id) }
        func point(_ p: CGPoint) -> CGPoint { p.applying(toPointer) }
        func color(_ light: CGColor, _ dark: CGColor?) -> StylePack.Color {
            StylePack.Color(light, dark: dark)
        }

        let body = m.body.flatMap { b in
            path(b.art).map {
                StylePack.Layer($0, color(b.color, m.dark.body), evenOdd: evenOdd(b.art))
            }
        }
        var details: [StylePack.Layer] = []
        for (i, d) in m.details.enumerated() {
            guard let p = path(d.art) else { continue }
            let dark = i < m.dark.details.count ? m.dark.details[i] : nil
            details.append(StylePack.Layer(p, color(d.color, dark), evenOdd: evenOdd(d.art)))
        }

        var tail: StylePack.Tail?
        if let leg = m.leg {
            tail = .leg(
                StylePack.Leg(
                    width: leg.width, join: point(leg.join), color: color(leg.color, m.dark.leg)))
        }
        if let jet = m.jet {
            let join = point(jet.join)
            if let flame = path(jet.flame, relativeTo: join),
                let core = path(jet.core, relativeTo: join)
            {
                tail = .jet(
                    StylePack.Jet(
                        flame: flame, core: core, color: color(jet.color, m.dark.jet),
                        coreColor: color(jet.coreColor, m.dark.jetCore), join: join))
            }
        }

        var click = StylePack.Click()
        if let r = m.ripple { click.ripple = color(r, m.dark.ripple) }
        if let st = m.stamp, let p = path(st.art) {
            click.stamp = StylePack.Stamp(p, offset: -st.offset)
        }
        if let pt = m.particles {
            let shape = pt.art.map { path($0) } ?? dot
            if let shape {
                click.particles = StylePack.Particles(
                    shape, color: color(pt.color, m.dark.particles), outlined: pt.outlined,
                    facesOutward: pt.facesOutward, fromCenter: pt.fromCenter, minimum: pt.minimum)
            }
        }

        var outline = StylePack.Outline.palette
        if case .stroke(let c, let w) = m.outline {
            outline = .stroke(color(c, m.dark.outline), width: w)
        }

        if segments > maxSegments {
            problems.append(
                PackProblem(
                    file: artFile,
                    "has \(segments) path segments in the art used; at most \(maxSegments)"))
        }
        guard problems.isEmpty, let body else {
            return PackLoad(pack: nil, problems: problems, warnings: allWarnings)
        }
        var pack = StylePack(
            id: m.id, name: m.name, body: body, details: details, outline: outline,
            overlay: m.overlay, tail: tail, click: click)
        pack.author = m.author
        pack.license = m.license
        pack.version = m.version
        return PackLoad(pack: pack, problems: [], warnings: allWarnings)
    }

    /// The built-in 6 pt particle dot, centred.
    static var dot: CGPath {
        CGPath(ellipseIn: CGRect(x: -3, y: -3, width: 6, height: 6), transform: nil)
    }

    static func isPlainFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".") && !name.contains("/") && !name.contains("\\")
    }

    /// The art file a manifest names, if it's a plain file name.
    public static func loadArtName(_ json: Data) -> String? {
        artFileName(json).flatMap { isPlainFileName($0) ? $0 : nil }
    }

    static func artFileName(_ json: Data) -> String? {
        (try? JSONSerialization.jsonObject(with: json) as? [String: Any])?["art"] as? String
    }

    struct ReadFailure: Error {
        let message: String
    }

    /// Reads a regular file (not a link or folder), checking its size before reading it.
    static func readFile(_ url: URL, limit: Int) -> Result<Data, ReadFailure> {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let v = try? url.resourceValues(forKeys: keys) else {
            return .failure(ReadFailure(message: "is missing"))
        }
        if v.isSymbolicLink == true {
            return .failure(ReadFailure(message: "is a link; packs must hold the file itself"))
        }
        guard v.isRegularFile == true else { return .failure(ReadFailure(message: "isn't a file")) }
        if let size = v.fileSize, size > limit {
            return .failure(ReadFailure(message: "is larger than \(limit / 1024) KB"))
        }
        guard let data = try? Data(contentsOf: url), data.count <= limit else {
            return .failure(ReadFailure(message: "can't be read"))
        }
        return .success(data)
    }
}

extension CGPath {
    /// Number of drawing commands (moves, lines, curves, closes).
    var segmentCount: Int {
        var n = 0
        applyWithBlock { _ in n += 1 }
        return n
    }
}

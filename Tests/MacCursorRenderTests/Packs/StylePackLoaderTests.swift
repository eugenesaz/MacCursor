import CoreGraphics
import Foundation
import Testing

@testable import MacCursorRender

/// A small valid pack, as JSON text, that tests change one key at a time.
enum PackFixture {
    static let svg = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
          <circle id="body" cx="50" cy="30" r="20"/>
          <circle id="pads" cx="50" cy="35" r="6"/>
          <circle id="stamp" cx="50" cy="10" r="5"/>
          <path id="spark" d="M50 5 L53 15 L47 15 Z"/>
          <path id="flame" d="M45 50 L55 50 L50 90 Z"/>
          <path id="core" d="M48 50 L52 50 L50 70 Z"/>
        </svg>
        """

    static var manifest: [String: Any] {
        [
            "format": 1, "id": "test.minimal", "name": "Minimal", "author": "Tests",
            "license": "CC0-1.0", "art": "art.svg", "hotspot": [50, 10],
            "body": ["art": "body", "color": "#E8C08A"],
        ]
    }

    static func files(_ m: [String: Any], svg: String = svg) -> [String: Data] {
        let json = try! JSONSerialization.data(withJSONObject: m, options: [.sortedKeys])
        return ["style.json": json, "art.svg": Data(svg.utf8)]
    }

    static func load(_ change: (inout [String: Any]) -> Void = { _ in }) -> PackLoad {
        var m = manifest
        change(&m)
        return StylePackLoader.load(files: files(m))
    }

    /// Writes a pack folder into a fresh temporary directory.
    static func folder(_ files: [String: Data], name: String = "pack") throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCursorTests-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (n, d) in files { try d.write(to: dir.appendingPathComponent(n)) }
        return dir
    }
}

@Suite struct StylePackLoaderTests {
    private func messages(_ l: PackLoad) -> [String] { l.problems.map(\.description) }

    @Test func minimalPackLoads() throws {
        let l = PackFixture.load()
        #expect(l.problems.isEmpty, "\(messages(l))")
        let pack = try #require(l.pack)
        #expect(pack.id == "test.minimal" && pack.name == "Minimal")
        #expect(pack.author == "Tests" && pack.license == "CC0-1.0")
        // The hotspot (50,10) is the top of the circle: in pointer space the art hangs below 0.
        let box = pack.body.path.boundingBoxOfPath
        #expect(abs(box.maxY) < 0.001 && abs(box.minY + 40) < 0.001)
        #expect(abs(box.midX) < 0.001)
        #expect(pack.tail == nil && pack.click.particles == nil && pack.click.stamp == nil)
    }

    @Test func everyOptionalPartLoads() throws {
        let l = PackFixture.load {
            $0["details"] = [["art": "pads", "color": "#4A322B"]]
            $0["outline"] = ["color": "#FFD23F", "width": 3]
            $0["overlay"] = true
            $0["tail"] = ["leg": ["width": 24, "join": [50, 45], "color": "#E8C08A"]]
            $0["click"] = [
                "ripple": "#FF0000",
                "stamp": ["art": "stamp", "offset": 26],
                "particles": [
                    "art": "spark", "color": "#FFF6E5", "facing": "outward", "origin": "center",
                    "minimum": 8,
                ],
            ]
            $0["darkScreens"] = ["body": "#000", "details": ["#111"], "particles": "#222"]
        }
        #expect(l.problems.isEmpty, "\(messages(l))")
        let p = try #require(l.pack)
        #expect(p.details.count == 1 && p.overlay)
        #expect(p.leg?.width == 24 && p.leg?.join == CGPoint(x: 0, y: -35))
        #expect(p.click.stamp?.offset == -26)
        let particles = try #require(p.click.particles)
        #expect(particles.facesOutward && particles.fromCenter && particles.minimum == 8)
        #expect(particles.outlined)
        #expect(p.body.color.forDarkScreens != p.body.color.forLightScreens)
        guard case .stroke(_, let width) = p.outline else {
            Issue.record("outline should be a stroke")
            return
        }
        #expect(width == 3)
    }

    @Test func jetPathsAreRelativeToTheirJoin() throws {
        let l = PackFixture.load {
            $0["tail"] = [
                "jet": [
                    "flame": "flame", "core": "core", "color": "#3D55E0CC",
                    "coreColor": "#BFD0FF", "join": [50, 50],
                ]
            ]
        }
        #expect(l.problems.isEmpty, "\(messages(l))")
        let jet = try #require(l.pack?.jet)
        #expect(jet.join == CGPoint(x: 0, y: -40))
        let box = jet.flame.boundingBoxOfPath
        #expect(abs(box.maxY) < 0.001 && abs(box.minY + 40) < 0.001)
    }

    @Test func dotParticlesAreBuiltInAndNotOutlined() throws {
        let l = PackFixture.load { $0["click"] = ["particles": ["art": "dot", "color": "#FFF"]] }
        let p = try #require(l.pack?.click.particles)
        #expect(!p.outlined)
        #expect(p.path.boundingBoxOfPath == CGRect(x: -3, y: -3, width: 6, height: 6))
    }

    @Test func requiredKeysAreReportedTogether() {
        let l = StylePackLoader.load(
            files: PackFixture.files(["format": 1, "art": "art.svg"]))
        #expect(
            messages(l) == [
                "style.json: \"id\" is missing", "style.json: \"name\" is missing",
                "style.json: \"author\" is missing", "style.json: \"license\" is missing",
                "style.json: \"hotspot\" is missing", "style.json: \"body\" is missing",
            ])
        #expect(l.pack == nil)
    }

    @Test(
        arguments: [
            ("format", 2, "style.json: \"format\" is 2, which needs a newer version of MacCursor"),
            ("format", "1", "style.json: \"format\" must be 1 (got \"1\")"),
            ("name", "", "style.json: \"name\" must be 1 to 40 characters (got 0)"),
            ("overlay", "yes", "style.json: \"overlay\" must be true or false (got \"yes\")"),
            (
                "hotspot", [1],
                "style.json: \"hotspot\" must be a pair of numbers [x, y] (got a list)"
            ),
            (
                "art", "../x.svg",
                "style.json: \"art\" must be a file name ending in .svg, with no folders (got \"../x.svg\")"
            ),
            ("details", "pads", "style.json: \"details\" must be a list [ … ] (got \"pads\")"),
        ] as [(String, any Sendable, String)])
    func topLevelValuesAreChecked(key: String, value: any Sendable, message: String) {
        let l = PackFixture.load { $0[key] = value }
        #expect(messages(l).contains(message), "\(messages(l))")
        #expect(l.pack == nil)
    }

    @Test func idRules() {
        for bad in ["1abc", "has space", String(repeating: "a", count: 65), ""] {
            #expect(PackFixture.load { $0["id"] = bad }.pack == nil, "\(bad)")
        }
        for good in ["a", "dogPaw", "com.example.cool-cursor_2"] {
            #expect(PackFixture.load { $0["id"] = good }.pack != nil, "\(good)")
        }
    }

    @Test func rangesAndColours() {
        let l = PackFixture.load {
            $0["body"] = ["art": "body", "color": "tan"]
            $0["tail"] = ["leg": ["width": "wide", "join": [50, 45], "color": "#E8C08A"]]
            $0["outline"] = ["color": "#FFF", "width": 20]
            $0["click"] = ["particles": ["color": "#FFF", "minimum": 30, "facing": "up"]]
        }
        #expect(
            Set(messages(l)) == [
                "style.json: \"body.color\" must be a colour like \"#E8C08A\" or \"#E8C08A80\" (got \"tan\")",
                "style.json: \"tail.leg.width\" must be a number from 1 to 80 (got \"wide\")",
                "style.json: \"outline.width\" must be a number from 0.5 to 8 (got 20)",
                "style.json: \"click.particles.minimum\" must be a number from 0 to 16 (got 30)",
                "style.json: \"click.particles.facing\" must be \"spin\" or \"outward\" (got \"up\")",
            ])
    }

    @Test func colourForms() {
        #expect(JSONReader.color(hex: "#FFF")?.components == [1, 1, 1, 1])
        #expect(JSONReader.color(hex: "#00000080")?.alpha ?? 0 > 0.5)
        for bad in ["FFF", "#FFFF", "#GGGGGG", "#1234567"] {
            #expect(JSONReader.color(hex: bad) == nil, "\(bad)")
        }
    }

    @Test func tooManyDetails() {
        let l = PackFixture.load {
            $0["details"] = Array(repeating: ["art": "pads", "color": "#000"], count: 9)
        }
        #expect(messages(l).contains("style.json: \"details\" has 9 layers; at most 8"))
    }

    @Test func tailNeedsExactlyOnePart() {
        #expect(
            messages(PackFixture.load { $0["tail"] = [String: Any]() }).contains(
                "style.json: \"tail\" needs a \"leg\" or a \"jet\" (leave \"tail\" out for none)"))
    }

    @Test func unknownKeysWarnOnly() {
        let l = PackFixture.load {
            $0["sparkle"] = true
            $0["body"] = ["art": "body", "color": "#000", "glow": 1]
        }
        #expect(l.isValid)
        #expect(
            l.warnings.map(\.description) == [
                "style.json: \"sparkle\" isn't a known key; ignored",
                "style.json: \"body.glow\" isn't a known key; ignored",
            ])
    }

    @Test func missingArtElementNamesItsReference() {
        let l = PackFixture.load { $0["details"] = [["art": "toes", "color": "#000"]] }
        #expect(
            messages(l) == [
                "art.svg: element \"toes\" not found (referenced by \"details[0].art\")"
            ])
    }

    @Test func artTooFarFromTheHotspot() {
        let svg = PackFixture.svg.replacingOccurrences(
            of: "<circle id=\"pads\" cx=\"50\" cy=\"35\" r=\"6\"/>",
            with: "<circle id=\"pads\" cx=\"50\" cy=\"400\" r=\"6\"/>")
        var m = PackFixture.manifest
        m["details"] = [["art": "pads", "color": "#000"]]
        let l = StylePackLoader.load(files: PackFixture.files(m, svg: svg))
        #expect(
            messages(l) == [
                "art.svg: element \"pads\" reaches 396 pt from the hotspot; keep art within 200 pt"
            ])
    }

    @Test func tooManySegments() {
        let d = "M0 0" + String(repeating: " l0.001 0", count: 20_001)
        let svg = "<svg><path id=\"body\" d=\"\(d)\"/></svg>"
        let l = StylePackLoader.load(files: PackFixture.files(PackFixture.manifest, svg: svg))
        #expect(messages(l).first?.contains("path segments") == true)
    }

    @Test func notJSON() {
        let l = StylePackLoader.load(files: ["style.json": Data("{ name: x".utf8)])
        #expect(messages(l).first?.hasPrefix("style.json: isn't valid JSON") == true)
    }

    @Test func svgProblemsStopTheLoad() {
        let l = StylePackLoader.load(
            files: PackFixture.files(PackFixture.manifest, svg: "<svg><image/></svg>"))
        #expect(l.pack == nil)
        #expect(messages(l).first?.hasPrefix("art.svg: element <image>") == true)
    }

    // MARK: Folders

    @Test func loadsFromAFolder() throws {
        let dir = try PackFixture.folder(PackFixture.files(PackFixture.manifest))
        #expect(StylePackLoader.load(folder: dir).isValid)
    }

    @Test func missingFilesInAFolder() throws {
        let empty = try PackFixture.folder([:])
        #expect(
            StylePackLoader.load(folder: empty).problems.map(\.description) == [
                "style.json: is missing"
            ])
        var files = PackFixture.files(PackFixture.manifest)
        files["art.svg"] = nil
        let noArt = try PackFixture.folder(files)
        #expect(
            StylePackLoader.load(folder: noArt).problems.map(\.description) == [
                "art.svg: is missing"
            ])
    }

    @Test func oversizedFilesAreRejectedBeforeReading() throws {
        var files = PackFixture.files(PackFixture.manifest)
        files["art.svg"] = Data(count: 10 * 1024 * 1024)
        let dir = try PackFixture.folder(files)
        #expect(
            StylePackLoader.load(folder: dir).problems.map(\.description) == [
                "art.svg: is larger than 512 KB"
            ])
    }

    @Test func linkedFilesAreRejected() throws {
        var files = PackFixture.files(PackFixture.manifest)
        let art = files.removeValue(forKey: "art.svg")!
        let dir = try PackFixture.folder(files)
        let outside = dir.deletingLastPathComponent().appendingPathComponent("outside.svg")
        try art.write(to: outside)
        try FileManager.default.createSymbolicLink(
            at: dir.appendingPathComponent("art.svg"), withDestinationURL: outside)
        #expect(
            StylePackLoader.load(folder: dir).problems.map(\.description) == [
                "art.svg: is a link; packs must hold the file itself"
            ])
    }
}

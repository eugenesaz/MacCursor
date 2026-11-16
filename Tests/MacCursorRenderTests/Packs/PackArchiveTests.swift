import Foundation
import Testing

@testable import MacCursorRender

@Suite struct PackArchiveTests {
    let files = PackFixture.files(PackFixture.manifest)

    private func message(_ data: Data) -> String? {
        if case .failure(let p) = PackArchive.read(data) { return p.description }
        return nil
    }

    /// Offsets in an archive made by `PackArchive.write`, for tampering with it.
    private func centralDirectory(_ data: Data) -> Int {
        Int(data[data.count - 6]) | Int(data[data.count - 5]) << 8
            | Int(data[data.count - 4]) << 16 | Int(data[data.count - 3]) << 24
    }

    private func patch32(_ data: inout Data, at i: Int, _ v: UInt32) {
        for k in 0..<4 { data[i + k] = UInt8((v >> (8 * UInt32(k))) & 0xFF) }
    }

    @Test func roundTrip() throws {
        let zip = PackArchive.write(files: files)
        let back = try PackArchive.read(zip).get()
        #expect(back == files)
        #expect(PackArchive.load(zip).isValid)
    }

    @Test func writingIsDeterministic() {
        #expect(PackArchive.write(files: files) == PackArchive.write(files: files))
    }

    @Test func deflatesWhenItHelps() throws {
        var big = files
        big["art.svg"] = Data(
            (PackFixture.svg + String(repeating: "<!-- pad -->", count: 500)).utf8)
        let zip = PackArchive.write(files: big)
        #expect(zip.count < big["art.svg"]!.count)
        #expect(try PackArchive.read(zip).get() == big)
    }

    @Test func otherFilesAreIgnored() throws {
        var more = files
        more["README.md"] = Data("hello".utf8)
        let back = try PackArchive.read(PackArchive.write(files: more)).get()
        #expect(Set(back.keys) == ["style.json", "art.svg"])
    }

    // MARK: Made by other tools

    private func zipTool(_ args: [String], in dir: URL) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: args[0])
        p.arguments = Array(args.dropFirst())
        p.currentDirectoryURL = dir
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        #expect(p.terminationStatus == 0)
    }

    @Test func zipCommandAtTheRootAndInAFolder() throws {
        let pack = try PackFixture.folder(files, name: "cool-cursor")
        let parent = pack.deletingLastPathComponent()
        try zipTool(["/usr/bin/zip", "-q", "-r", "folder.zip", "cool-cursor"], in: parent)
        try zipTool(
            [
                "/usr/bin/zip", "-q", "-j", "flat.zip", "cool-cursor/style.json",
                "cool-cursor/art.svg",
            ], in: parent)
        for name in ["folder.zip", "flat.zip"] {
            let data = try Data(contentsOf: parent.appendingPathComponent(name))
            #expect(PackArchive.load(data).isValid, "\(name)")
        }
    }

    /// Finder's Compress (ditto) adds __MACOSX and ._ files, and can use data descriptors.
    @Test func finderStyleArchive() throws {
        let pack = try PackFixture.folder(files, name: "cool-cursor")
        let parent = pack.deletingLastPathComponent()
        try zipTool(
            [
                "/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", "cool-cursor",
                "finder.zip",
            ],
            in: parent)
        let data = try Data(contentsOf: parent.appendingPathComponent("finder.zip"))
        #expect(PackArchive.load(data).isValid)
    }

    // MARK: Refused

    @Test func notAZip() {
        #expect(
            message(Data("hello, this is not a zip file at all".utf8))
                == "isn't a style pack file (not a zip archive)")
        #expect(message(Data()) == "isn't a style pack file (not a zip archive)")
    }

    @Test func tooLarge() {
        #expect(message(Data(count: 3 * 1024 * 1024))?.hasPrefix("is larger than 2 MB") == true)
    }

    @Test func noManifest() {
        let zip = PackArchive.write(files: ["art.svg": files["art.svg"]!])
        #expect(message(zip) == "has no style.json at its top level")
    }

    @Test func twoPacksInOneFile() {
        let zip = PackArchive.write(files: [
            "a/style.json": files["style.json"]!, "b/style.json": files["style.json"]!,
        ])
        #expect(message(zip) == "holds more than one pack folder; put one pack in each file")
    }

    @Test(arguments: ["../style.json", "/etc/style.json", "a/../../style.json", "a\\style.json"])
    func unsafePaths(name: String) {
        let zip = PackArchive.write(files: [name: files["style.json"]!])
        #expect(message(zip)?.hasPrefix("contains an unsafe path") == true)
    }

    @Test func links() {
        var zip = PackArchive.write(files: files)
        let cd = centralDirectory(zip)
        // First entry's external attributes: a symbolic link instead of a file.
        patch32(&zip, at: cd + 38, UInt32(0o120777) << 16)
        #expect(message(zip)?.hasPrefix("contains a link") == true)
    }

    @Test func encrypted() {
        var zip = PackArchive.write(files: files)
        zip[centralDirectory(zip) + 8] |= 1
        #expect(message(zip) == "is encrypted, which isn't supported")
    }

    @Test func zip64() {
        var zip = PackArchive.write(files: files)
        patch32(&zip, at: centralDirectory(zip) + 24, 0xFFFF_FFFF)
        #expect(message(zip) == "is a zip64 archive, which isn't supported")
    }

    @Test func tooManyEntries() {
        var many = files
        for i in 0..<31 { many["extra\(i).txt"] = Data("x".utf8) }
        #expect(
            message(PackArchive.write(files: many)) == "holds 33 files; a style pack has at most 32"
        )
    }

    @Test func declaredSizeOverTheLimit() {
        var big = files
        big["art.svg"] = Data(repeating: 0x20, count: 600 * 1024)
        #expect(message(PackArchive.write(files: big)) == "art.svg: is larger than 512 KB")
    }

    /// An entry that lies about its size and inflates to 10 MB stops at the limit.
    @Test func zipBombStopsAtTheLimit() {
        var bomb = files
        bomb["art.svg"] = Data(repeating: 0x20, count: 10 * 1024 * 1024)
        var zip = PackArchive.write(files: bomb)
        let cd = centralDirectory(zip)
        // The art entry is second; find it after the first central entry.
        let firstNameLen = Int(zip[cd + 28]) | Int(zip[cd + 29]) << 8
        let second = cd + 46 + firstNameLen
        patch32(&zip, at: second + 24, 1000)  // claimed size: 1000 bytes
        #expect(zip.count < 2 * 1024 * 1024)
        #expect(message(zip) == "art.svg: is damaged or larger than 512 KB when unpacked")
    }

    @Test func inflateNeverExceedsItsLimit() throws {
        let zeros = Data(count: 5 * 1024 * 1024)
        let packed = try #require(PackArchive.deflate(zeros))
        #expect(PackArchive.inflate(packed, limit: 1024) == nil)
        #expect(PackArchive.inflate(packed, limit: zeros.count) == zeros)
    }

    @Test func truncatedOrCorrupt() {
        let zip = PackArchive.write(files: files)
        #expect(message(zip.prefix(zip.count - 10)) != nil)
        var flipped = zip
        flipped[40] ^= 0xFF  // inside style.json's data
        #expect(message(flipped)?.contains("is damaged") == true)
    }

    @Test func crcMatchesKnownValue() {
        #expect(CRC32.checksum(Data("123456789".utf8)) == 0xCBF4_3926)
    }
}

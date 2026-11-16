import Foundation
import Testing

@testable import MacCursorRender

@Suite struct PackInstallTests {
    let styles = FileManager.default.temporaryDirectory
        .appendingPathComponent("MacCursorTests-\(UUID().uuidString)/Styles")

    private func files(id: String = "a.cool", name: String = "Cool") -> [String: Data] {
        var m = PackFixture.manifest
        m["id"] = id
        m["name"] = name
        return PackFixture.files(m)
    }

    private func library() -> StyleLibrary {
        StyleLibrary.load(builtinDirectory: BuiltinPacks.directory, userDirectory: styles)
    }

    @Test func freshInstallMakesAFolderNamedByID() throws {
        let folder = try PackInstall.install(files: files(), id: "a.cool", into: styles)
        #expect(folder.lastPathComponent == "a.cool")
        let lib = library()
        #expect(lib.user.map(\.id) == ["a.cool"])
        #expect(lib.user.first?.folder?.standardizedFileURL == folder.standardizedFileURL)
    }

    @Test func decisions() throws {
        let pack = try #require(StylePackLoader.load(files: files()).pack)
        guard case .install = PackInstall.decide(pack, in: library()) else {
            Issue.record("expected install")
            return
        }
        _ = try PackInstall.install(files: files(), id: "a.cool", into: styles)
        guard case .replace(let old) = PackInstall.decide(pack, in: library()) else {
            Issue.record("expected replace")
            return
        }
        #expect(old.id == "a.cool")
        let builtin = try #require(StylePackLoader.load(files: files(id: "dogPaw")).pack)
        guard case .refuse(let why) = PackInstall.decide(builtin, in: library()) else {
            Issue.record("expected refuse")
            return
        }
        #expect(why.contains("built-in"))
    }

    @Test func replaceSwapsTheOldFolder() throws {
        let first = try PackInstall.install(
            files: files(name: "Old"), id: "a.cool", into: styles)
        let second = try PackInstall.install(
            files: files(name: "New"), id: "a.cool", into: styles, replacing: first)
        #expect(second.standardizedFileURL == first.standardizedFileURL)
        #expect(library().user.map(\.name) == ["New"])
    }

    @Test func aFolderInTheWayGetsANumber() throws {
        try FileManager.default.createDirectory(
            at: styles.appendingPathComponent("a.cool"), withIntermediateDirectories: true)
        let folder = try PackInstall.install(files: files(), id: "a.cool", into: styles)
        #expect(folder.lastPathComponent == "a.cool 2")
    }

    @Test func leftoverTempFoldersAreIgnoredAndCleaned() throws {
        let temp = styles.appendingPathComponent(PackInstall.tempPrefix + "crashed")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        for (n, d) in files() { try d.write(to: temp.appendingPathComponent(n)) }
        #expect(library().user.isEmpty && library().failures.isEmpty)
        PackInstall.cleanLeftovers(in: styles)
        #expect(!FileManager.default.fileExists(atPath: temp.path))
    }

    @Test func unsafeNamesAreNeverWritten() throws {
        var f = files()
        f["../escape.txt"] = Data("x".utf8)
        let folder = try PackInstall.install(files: f, id: "a.cool", into: styles)
        #expect(
            !FileManager.default.fileExists(
                atPath: styles.appendingPathComponent("escape.txt").path))
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted() == [
                "art.svg", "style.json",
            ])
    }

    /// The whole import path from bytes: an invalid file never reaches the folder.
    @Test func invalidFilesWriteNothing() {
        let load = PackArchive.load(Data("not a zip".utf8))
        #expect(load.pack == nil)
        #expect(!FileManager.default.fileExists(atPath: styles.path))
    }
}

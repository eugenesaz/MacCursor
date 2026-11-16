import Foundation
import Testing

@testable import MacCursorRender

@Suite struct StyleLibraryTests {
    /// A fresh user Styles folder holding one pack per (folder, id, name).
    private func userFolder(_ packs: [(folder: String, id: String, name: String)]) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacCursorTests-\(UUID().uuidString)/Styles")
        for p in packs {
            var m = PackFixture.manifest
            m["id"] = p.id
            m["name"] = p.name
            let dir = root.appendingPathComponent(p.folder)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for (n, d) in PackFixture.files(m) { try d.write(to: dir.appendingPathComponent(n)) }
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func load(_ user: URL?) -> StyleLibrary {
        StyleLibrary.load(builtinDirectory: BuiltinPacks.directory, userDirectory: user)
    }

    @Test func userPacksFollowTheBuiltinsSortedByName() throws {
        let dir = try userFolder([
            ("z-folder", "a.zebra", "Zebra"), ("a-folder", "a.apple", "apple"),
            ("m-folder", "a.mango", "Mango"),
        ])
        let lib = load(dir)
        #expect(lib.builtins.map(\.id) == StyleLibrary.builtinOrder)
        #expect(lib.user.map(\.name) == ["apple", "Mango", "Zebra"])
        #expect(lib.all.count == 7 && lib.failures.isEmpty)
        #expect(!lib.isBuiltin(id: "a.apple") && lib.isBuiltin(id: "ring"))
    }

    @Test func duplicateIdsKeepTheFirstFolderByName() throws {
        let dir = try userFolder([("b", "same.id", "Second"), ("a", "same.id", "First")])
        let lib = load(dir)
        #expect(lib.user.map(\.name) == ["First"])
        #expect(
            lib.failures.flatMap(\.messages) == [
                "b/style.json: \"id\" \"same.id\" is already used by another style in the Styles folder"
            ])
    }

    @Test func builtinIdsAreRefused() throws {
        let lib = load(try userFolder([("fake", "dogPaw", "Fake paw")]))
        #expect(lib.user.isEmpty)
        #expect(
            lib.failures.flatMap(\.messages) == [
                "fake/style.json: \"id\" \"dogPaw\" is a built-in style's id; choose another"
            ])
        #expect(lib.resolved(id: "dogPaw").name == "Dog paw")
    }

    @Test func brokenPacksAreReportedAndOthersStillLoad() throws {
        let dir = try userFolder([("good", "a.good", "Good")])
        let bad = dir.appendingPathComponent("bad")
        try FileManager.default.createDirectory(at: bad, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: bad.appendingPathComponent("style.json"))
        let lib = load(dir)
        #expect(lib.user.map(\.id) == ["a.good"])
        #expect(lib.failures.map(\.name) == ["bad"])
        #expect(lib.failures.first?.isBuiltin == false)
    }

    @Test func hiddenFoldersAndFilesAreSkipped() throws {
        let dir = try userFolder([
            (".import-123", "a.hidden", "Hidden"), ("shown", "a.shown", "Shown"),
        ])
        try Data("x".utf8).write(to: dir.appendingPathComponent("notes.txt"))
        let lib = load(dir)
        #expect(lib.user.map(\.id) == ["a.shown"] && lib.failures.isEmpty)
    }

    @Test func atMostOneHundredUserPacks() throws {
        let packs = (0..<101).map { (String(format: "p%03d", $0), "a.p\($0)", "P \($0)") }
        let lib = load(try userFolder(packs))
        #expect(lib.user.count == 100)
        #expect(lib.failures.map(\.name) == ["p100"])
    }

    @Test func missingFoldersAreFine() {
        let nowhere = URL(fileURLWithPath: "/nonexistent/\(UUID().uuidString)")
        let lib = load(nowhere)
        #expect(lib.user.isEmpty && lib.failures.isEmpty && lib.builtins.count == 4)
    }

    /// A saved id whose pack is gone draws the dog paw, without needing the setting changed.
    @Test func unknownIdsResolveToTheDogPaw() {
        #expect(load(nil).resolved(id: "a.uninstalled").id == "dogPaw")
    }

    /// With no built-ins at all (a damaged app), there's still a pointer.
    @Test func noBuiltinsFallsBackToARingInCode() {
        let lib = StyleLibrary.load(builtinDirectory: nil, userDirectory: nil)
        let p = lib.resolved(id: "dogPaw")
        #expect(p.id == "fallback.ring" && p.overlay)
    }
}

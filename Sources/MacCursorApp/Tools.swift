import Foundation
import MacCursorRender

/// Command-line tools for style pack authors and the gallery's CI. They never open a window
/// or touch the cursor. See `docs/making-a-style.md`.
enum Tools {
    static let usage = """
        usage:
          MacCursor --validate [--builtin] <pack folder or .maccursorstyle>…
          MacCursor --pack <pack folder> [-o <file.maccursorstyle>]
          MacCursor --preview <pack folder or .maccursorstyle> <out.png>
          MacCursor --render <output folder>
        """

    /// Runs the tool the arguments ask for and returns its exit code, or nil to start the app.
    static func run(_ args: [String]) -> Int32? {
        guard args.count > 1 else { return nil }
        let rest = Array(args.dropFirst(2))
        switch args[1] {
        case "--validate": return validate(rest)
        case "--pack": return pack(rest)
        case "--preview": return preview(rest)
        case "--render":
            guard let dir = rest.first else { return fail(usage) }
            let library = StyleLibrary.load(
                builtinDirectory: StyleStore.builtinDirectory, userDirectory: nil)
            SnapshotRenderer.run(directory: dir, packs: library.builtins)
            return 0
        case "--help", "-h":
            print(usage)
            return 0
        default:
            // Launch Services and Xcode pass their own arguments (-NSDocumentRevisionsDebugMode…).
            return args[1].hasPrefix("--") ? fail("unknown option \(args[1])\n\(usage)") : nil
        }
    }

    /// Loads one pack from a folder or a `.maccursorstyle` file, adding the checks the app
    /// makes when it loads a user pack.
    static func load(_ path: String, builtin: Bool = false) -> (name: String, load: PackLoad) {
        let url = URL(fileURLWithPath: path)
        var isFolder: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isFolder)
        var result = isFolder.boolValue ? StylePackLoader.load(folder: url) : loadFile(url)
        if !builtin, let id = result.pack?.id, StyleLibrary.builtinOrder.contains(id) {
            result.problems.append(
                PackProblem(
                    file: "style.json", location: "\"id\"",
                    "\"\(id)\" is a built-in style's id; choose another"))
            result.pack = nil
        }
        return (url.lastPathComponent, result)
    }

    /// `--validate`: prints problems and warnings to stderr and `ok <id>` per valid pack.
    /// `--builtin` (for this repo's own packs) allows the built-in ids.
    static func validate(_ args: [String]) -> Int32 {
        let builtin = args.first == "--builtin"
        let paths = builtin ? Array(args.dropFirst()) : args
        guard !paths.isEmpty else { return fail(usage) }
        var allValid = true
        for path in paths {
            let (name, result) = load(path, builtin: builtin)
            for w in result.warnings { eprint("warning: \(w.described(in: name))") }
            for p in result.problems { eprint("error: \(p.described(in: name))") }
            if let pack = result.pack, result.problems.isEmpty {
                print("ok \(pack.id)")
            } else {
                allValid = false
            }
        }
        return allValid ? 0 : 1
    }

    /// Reads a pack file, checking its size before reading it.
    static func loadFile(_ url: URL) -> PackLoad {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize
        guard let size else {
            return PackLoad(
                pack: nil, problems: [PackProblem(file: "", "doesn't exist")], warnings: [])
        }
        guard size <= PackArchive.maxArchiveBytes, let data = try? Data(contentsOf: url) else {
            return PackLoad(
                pack: nil,
                problems: [PackProblem(file: "", "is larger than 2 MB or can't be read")],
                warnings: [])
        }
        return PackArchive.load(data)
    }

    /// `--pack`: validates a pack folder and, only if it's valid, writes the single file.
    static func pack(_ args: [String]) -> Int32 {
        var args = args
        let builtin = args.first == "--builtin"
        if builtin { args.removeFirst() }
        var output: String?
        if let i = args.firstIndex(of: "-o") {
            guard i + 1 < args.count else { return fail(usage) }
            output = args[i + 1]
            args.removeSubrange(i...(i + 1))
        }
        guard args.count == 1, let folder = args.first else { return fail(usage) }
        let url = URL(fileURLWithPath: folder)
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder, isDirectory: &isFolder),
            isFolder.boolValue
        else { return fail("\(folder) isn't a pack folder") }
        guard validate((builtin ? ["--builtin"] : []) + [folder]) == 0,
            let manifest = try? Data(contentsOf: url.appendingPathComponent("style.json")),
            let artName = StylePackLoader.loadArtName(manifest),
            let art = try? Data(contentsOf: url.appendingPathComponent(artName)),
            let id = StylePackLoader.load(folder: url).pack?.id
        else {
            eprint("not packed: fix the problems above first")
            return 1
        }
        let data = PackArchive.write(files: ["style.json": manifest, artName: art])
        let out = URL(fileURLWithPath: output ?? "\(id).\(PackArchive.fileExtension)")
        do {
            try data.write(to: out, options: .atomic)
        } catch {
            return fail("can't write \(out.path): \(error.localizedDescription)")
        }
        print(out.path)
        return 0
    }

    /// `--preview`: a PNG sheet of the pack at three sizes and clicking, on both backgrounds.
    static func preview(_ args: [String]) -> Int32 {
        guard args.count == 2 else { return fail(usage) }
        let (name, result) = load(args[0], builtin: true)
        for p in result.problems { eprint("error: \(p.described(in: name))") }
        guard let pack = result.pack, result.problems.isEmpty else { return 1 }
        guard let image = SnapshotRenderer.sheet(for: pack) else { return fail("couldn't render") }
        SnapshotRenderer.writePNG(image, to: URL(fileURLWithPath: args[1]))
        print(args[1])
        return 0
    }

    static func eprint(_ s: String) {
        FileHandle.standardError.write(Data((s + "\n").utf8))
    }

    private static func fail(_ message: String) -> Int32 {
        eprint(message)
        return 2
    }
}

import Foundation
import MacCursorRender

/// Command-line tools for style pack authors and the gallery's CI. They never open a window
/// or touch the cursor. See `docs/making-a-style.md`.
enum Tools {
    static let usage = """
        usage:
          MacCursor --validate <pack folder or .maccursorstyle>…
          MacCursor --render <output folder>
        """

    /// Runs the tool the arguments ask for and returns its exit code, or nil to start the app.
    static func run(_ args: [String]) -> Int32? {
        guard args.count > 1 else { return nil }
        let rest = Array(args.dropFirst(2))
        switch args[1] {
        case "--validate": return validate(rest)
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

    /// Loads one pack from a folder (or, later, a pack file), adding the checks the app makes
    /// when it loads a user pack.
    static func load(_ path: String, builtin: Bool = false) -> (name: String, load: PackLoad) {
        let url = URL(fileURLWithPath: path)
        var result = StylePackLoader.load(folder: url)
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

    static func eprint(_ s: String) {
        FileHandle.standardError.write(Data((s + "\n").utf8))
    }

    private static func fail(_ message: String) -> Int32 {
        eprint(message)
        return 2
    }
}

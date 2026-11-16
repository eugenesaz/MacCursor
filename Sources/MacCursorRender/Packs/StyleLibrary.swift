import CoreGraphics
import Foundation

/// Every style the app can show: the built-in packs inside the app, then the user's packs from
/// their Styles folder, plus what couldn't be loaded and why. Loading is pure and can run on
/// any thread; the app swaps a new library in on the main thread.
public struct StyleLibrary: Sendable {
    /// Menu order of the built-ins. Built-in packs not listed here follow, by name.
    public static let builtinOrder = ["dogPaw", "catPaw", "finger", "ring"]
    public static let defaultID = "dogPaw"
    public static let maxUserPacks = 100

    public private(set) var builtins: [StylePack] = []
    /// Sorted by name, for the menu.
    public private(set) var user: [StylePack] = []
    public private(set) var failures: [Failure] = []

    /// A pack that couldn't be loaded.
    public struct Failure: Sendable, Equatable {
        /// The pack's folder name.
        public let name: String
        public let isBuiltin: Bool
        public let problems: [PackProblem]

        /// One line per problem, prefixed with the folder name.
        public var messages: [String] { problems.map { $0.described(in: name) } }
    }

    public init() {}

    public var all: [StylePack] { builtins + user }

    public func pack(id: String) -> StylePack? { all.first { $0.id == id } }

    /// The style to draw for a saved id: that pack, or the dog paw if it's missing or broken,
    /// or, if even the built-ins failed to load, a ring drawn in code.
    public func resolved(id: String) -> StylePack {
        pack(id: id) ?? pack(id: Self.defaultID) ?? builtins.first ?? Self.fallback
    }

    public func isBuiltin(id: String) -> Bool { builtins.contains { $0.id == id } }

    /// Loads both folders. Either may be nil or missing.
    public static func load(builtinDirectory: URL?, userDirectory: URL?) -> StyleLibrary {
        var lib = StyleLibrary()
        for (name, load) in packs(in: builtinDirectory) {
            if let pack = load.pack, load.problems.isEmpty {
                lib.builtins.append(pack)
            } else {
                lib.failures.append(Failure(name: name, isBuiltin: true, problems: load.problems))
            }
        }
        lib.builtins.sort { a, b in
            let ia = builtinOrder.firstIndex(of: a.id) ?? Int.max
            let ib = builtinOrder.firstIndex(of: b.id) ?? Int.max
            return ia != ib ? ia < ib : a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        var seen = Set(lib.builtins.map(\.id))
        for (name, load) in packs(in: userDirectory) {
            guard let pack = load.pack, load.problems.isEmpty else {
                lib.failures.append(Failure(name: name, isBuiltin: false, problems: load.problems))
                continue
            }
            if lib.isBuiltin(id: pack.id) {
                lib.failures.append(
                    Failure(
                        name: name, isBuiltin: false,
                        problems: [
                            PackProblem(
                                file: Manifest.file, location: "\"id\"",
                                "\"\(pack.id)\" is a built-in style's id; choose another")
                        ]))
                continue
            }
            guard !seen.contains(pack.id) else {
                lib.failures.append(
                    Failure(
                        name: name, isBuiltin: false,
                        problems: [
                            PackProblem(
                                file: Manifest.file, location: "\"id\"",
                                "\"\(pack.id)\" is already used by another style in the Styles folder"
                            )
                        ]))
                continue
            }
            guard lib.user.count < maxUserPacks else {
                lib.failures.append(
                    Failure(
                        name: name, isBuiltin: false,
                        problems: [
                            PackProblem(
                                file: "",
                                "wasn't loaded: at most \(maxUserPacks) styles can be installed")
                        ]))
                continue
            }
            seen.insert(pack.id)
            lib.user.append(pack)
        }
        lib.user.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return lib
    }

    /// Pack folders in `dir`, sorted by name. Hidden folders (such as half-finished imports,
    /// which start with ".") and plain files are skipped.
    public static func packFolders(in dir: URL?) -> [URL] {
        guard let dir,
            let items = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                options: [.skipsHiddenFiles])
        else { return [] }
        return
            items
            .filter {
                let v = try? $0.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return v?.isDirectory == true && v?.isSymbolicLink != true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func packs(in dir: URL?) -> [(String, PackLoad)] {
        packFolders(in: dir).map { ($0.lastPathComponent, StylePackLoader.load(folder: $0)) }
    }

    /// Used only if no built-in pack loads (a damaged app), so there is always a pointer.
    public static var fallback: StylePack {
        let gold = StylePack.Color(rgb(0xFFD23F))
        let ring = CGPath(ellipseIn: CGRect(x: -22, y: -22, width: 44, height: 44), transform: nil)
        return StylePack(
            id: "fallback.ring", name: "Highlight ring",
            body: .init(ring, rgb(0xFFD23F, 0.35)), outline: .stroke(gold, width: 3),
            overlay: true,
            click: .init(
                ripple: gold, particles: .init(StylePackLoader.dot, color: gold, outlined: false)))
    }
}

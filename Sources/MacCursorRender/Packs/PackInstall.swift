import Foundation

/// Installing and removing user packs in the Styles folder. Pure file work, no UI, so it can
/// be tested against a temporary folder.
public enum PackInstall {
    /// Folders being written start with this, so the library skips them (hidden) until they're
    /// complete, and leftovers from a crash are cleaned up.
    public static let tempPrefix = ".import-"

    public enum Decision {
        /// A new style.
        case install
        /// A user pack with the same id is installed; it will be replaced.
        case replace(StylePack)
        /// Can't be installed; the reason is shown to the user.
        case refuse(String)
    }

    public static func decide(_ pack: StylePack, in library: StyleLibrary) -> Decision {
        if library.isBuiltin(id: pack.id) {
            return .refuse(
                "\"\(pack.name)\" uses the id \"\(pack.id)\", which belongs to a built-in style.")
        }
        if let existing = library.user.first(where: { $0.id == pack.id }) {
            return .replace(existing)
        }
        if library.user.count >= StyleLibrary.maxUserPacks {
            return .refuse("At most \(StyleLibrary.maxUserPacks) styles can be installed.")
        }
        return .install
    }

    /// Writes a pack's files into `styles` as one folder, all at once: into a hidden temporary
    /// folder first, then moved (or swapped) into place. Returns the pack's folder.
    /// - replacing: the folder of the installed pack with the same id, if any.
    public static func install(
        files: [String: Data], id: String, into styles: URL, replacing: URL? = nil
    ) throws -> URL {
        let fm = FileManager.default
        try fm.createDirectory(at: styles, withIntermediateDirectories: true)
        let temp = styles.appendingPathComponent(tempPrefix + UUID().uuidString)
        try fm.createDirectory(at: temp, withIntermediateDirectories: false)
        do {
            for (name, data) in files {
                // Names come from our own archive reader; check again anyway.
                guard StylePackLoader.isPlainFileName(name) else { continue }
                try data.write(to: temp.appendingPathComponent(name), options: .withoutOverwriting)
            }
            if let old = replacing, fm.fileExists(atPath: old.path) {
                _ = try fm.replaceItemAt(old, withItemAt: temp)
                return old
            }
            let dest = freeFolder(named: id, in: styles)
            try fm.moveItem(at: temp, to: dest)
            return dest
        } catch {
            try? fm.removeItem(at: temp)
            throw error
        }
    }

    /// `<id>`, or `<id> 2`, `<id> 3`… if a folder with that name is already there.
    static func freeFolder(named id: String, in styles: URL) -> URL {
        var url = styles.appendingPathComponent(id)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = styles.appendingPathComponent("\(id) \(n)")
            n += 1
        }
        return url
    }

    /// Removes half-written imports left behind by a crash.
    public static func cleanLeftovers(in styles: URL) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: styles.path) else { return }
        for name in items where name.hasPrefix(tempPrefix) {
            try? fm.removeItem(at: styles.appendingPathComponent(name))
        }
    }
}

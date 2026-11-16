import AppKit
import MacCursorRender

/// The style packs the app knows about: built-ins from the app bundle and the user's
/// Styles folder. Packs are read on a background queue; the library is replaced as a whole,
/// on the main thread. The user folder is watched, so added, edited or removed packs show up
/// without a relaunch.
@MainActor
final class StyleStore {
    static let shared = StyleStore()

    /// `MacCursor.app/Contents/Resources/Styles`.
    nonisolated static var builtinDirectory: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Styles", isDirectory: true)
    }

    /// `~/Library/Application Support/MacCursor/Styles`.
    nonisolated static var userDirectory: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(
                "Library/Application Support")
        return base.appendingPathComponent("MacCursor/Styles", isDirectory: true)
    }

    private(set) var library: StyleLibrary
    /// Called on the main thread after the library changes.
    var onChange: (() -> Void)?

    private var watcher: StyleFolderWatcher?
    private let loadQueue = DispatchQueue(label: "MacCursor.StyleStore.load", qos: .utility)
    /// Each reload gets a number; only the newest result is applied.
    private var generation = 0

    private init() {
        // Built-ins load synchronously at launch (a few milliseconds), so the first frame
        // already shows the chosen built-in style.
        library = StyleLibrary.load(builtinDirectory: Self.builtinDirectory, userDirectory: nil)
        for f in library.failures { log("built-in style failed: \(f.messages)") }
    }

    func pack(for id: String) -> StylePack { library.resolved(id: id) }

    /// Creates the user folder if needed, loads it, and starts watching it.
    func start() {
        try? FileManager.default.createDirectory(
            at: Self.userDirectory, withIntermediateDirectories: true)
        PackInstall.cleanLeftovers(in: Self.userDirectory)
        reload()
        guard watcher == nil else { return }
        let w = StyleFolderWatcher(directory: Self.userDirectory) {
            Task { @MainActor in StyleStore.shared.reload() }
        }
        w.start()
        watcher = w
    }

    /// Re-reads every pack off the main thread, then swaps the library in.
    func reload() {
        generation += 1
        let mine = generation
        let builtin = Self.builtinDirectory
        let user = Self.userDirectory
        loadQueue.async {
            let lib = StyleLibrary.load(builtinDirectory: builtin, userDirectory: user)
            Task { @MainActor in
                let store = StyleStore.shared
                guard mine == store.generation else { return }
                store.library = lib
                if !lib.failures.isEmpty {
                    log("styles that couldn't load: \(lib.failures.flatMap(\.messages))")
                }
                store.onChange?()
            }
        }
    }

    /// Re-reads every pack right away, on the main thread: after an import or removal the
    /// user has just asked for, so the menu and pointer are up to date before the next click.
    func reloadNow() {
        generation += 1
        library = StyleLibrary.load(
            builtinDirectory: Self.builtinDirectory, userDirectory: Self.userDirectory)
        onChange?()
    }

    /// Opens the user Styles folder in Finder, creating it first if needed.
    func openFolder() {
        try? FileManager.default.createDirectory(
            at: Self.userDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(Self.userDirectory)
    }
}

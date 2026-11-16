import AppKit
import MacCursorRender

/// The style packs the app knows about: built-ins from the app bundle and the user's
/// Styles folder. The library is replaced as a whole, on the main thread.
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

    private init() {
        library = StyleLibrary.load(builtinDirectory: Self.builtinDirectory, userDirectory: nil)
        for f in library.failures { log("built-in style failed: \(f.messages)") }
    }

    func pack(for id: String) -> StylePack { library.resolved(id: id) }
}

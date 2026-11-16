import Foundation

@testable import MacCursorRender

/// The built-in packs from `Resources/Styles` in this checkout.
enum BuiltinPacks {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Styles")

    static let library = StyleLibrary.load(builtinDirectory: directory, userDirectory: nil)

    static func pack(_ id: String) -> StylePack {
        guard let p = library.pack(id: id) else { fatalError("built-in pack \(id) didn't load") }
        return p
    }
}

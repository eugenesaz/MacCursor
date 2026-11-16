import Foundation

@testable import MacCursorRender

/// The built-in packs from `Resources/Styles` in this checkout.
enum BuiltinPacks {
    static let directory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Styles")

    static let library = StyleLibrary.load(builtinDirectory: directory, userDirectory: nil)

    static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().appendingPathComponent("Fixtures/Packs")

    /// The rocket fixture: original test art using every engine feature built-ins don't.
    static let rocket: StylePack = {
        let l = StylePackLoader.load(folder: fixtures.appendingPathComponent("rocket"))
        guard let p = l.pack else { fatalError("rocket fixture: \(l.problems)") }
        return p
    }()

    static func pack(_ id: String) -> StylePack {
        guard let p = library.pack(id: id) else { fatalError("built-in pack \(id) didn't load") }
        return p
    }
}

import AppKit
import MacCursorCore
import MacCursorRender

/// UserDefaults-backed preferences.
@MainActor
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var mood: Mood {
        get { Mood(rawValue: d.string(forKey: "mood") ?? "") ?? .normal }
        set { d.set(newValue.rawValue, forKey: "mood") }
    }
    let sound = SoundSettings(store: UserDefaults.standard)

    let pointer = PointerSettings(store: UserDefaults.standard)

    func resolvedPalette() -> Palette {
        .of(pointer.paletteKind(systemIsDark: Self.systemIsDark()))
    }

    static func systemIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension UserDefaults: SettingsStore {}

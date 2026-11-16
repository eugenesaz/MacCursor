import AppKit
import MacCursorCore
import MacCursorRender

enum Mood: String, CaseIterable {
    case subtle, normal, wild

    var title: String {
        switch self {
        case .subtle: return "Subtle"
        case .normal: return "Normal"
        case .wild: return "Wild"
        }
    }
    var intensity: CGFloat { [.subtle: 0.6, .normal: 1.0, .wild: 1.6][self]! }
}

/// UserDefaults-backed preferences.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var mood: Mood {
        get { Mood(rawValue: d.string(forKey: "mood") ?? "") ?? .normal }
        set { d.set(newValue.rawValue, forKey: "mood") }
    }
    var sound: Bool {
        get { d.object(forKey: "sound") as? Bool ?? true }
        set { d.set(newValue, forKey: "sound") }
    }

    let pointer = PointerSettings(store: UserDefaults.standard)

    func resolvedPalette() -> Palette {
        .of(pointer.paletteKind(systemIsDark: Self.systemIsDark()))
    }

    static func systemIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension UserDefaults: SettingsStore {}

import AppKit

enum ColorMode: String, CaseIterable {
    case auto, darkPointer, lightPointer

    var title: String {
        switch self {
        case .auto: return "Auto (follow system appearance)"
        case .darkPointer: return "Dark — for light screens"
        case .lightPointer: return "Light — for dark screens"
        }
    }
}

enum Mood: String, CaseIterable {
    case subtle, normal, wild

    var title: String {
        switch self {
        case .subtle: return "Subtle"
        case .normal: return "Normal"
        case .wild: return "Wild"
        }
    }
    var scale: CGFloat { [.subtle: 0.8, .normal: 1.0, .wild: 1.3][self]! }
    var intensity: CGFloat { [.subtle: 0.6, .normal: 1.0, .wild: 1.6][self]! }
}

/// UserDefaults-backed preferences.
final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    var skin: SkinKind {
        get { SkinKind(rawValue: d.string(forKey: "skin") ?? "") ?? .dogPaw }
        set { d.set(newValue.rawValue, forKey: "skin") }
    }
    var colorMode: ColorMode {
        get { ColorMode(rawValue: d.string(forKey: "colorMode") ?? "") ?? .auto }
        set { d.set(newValue.rawValue, forKey: "colorMode") }
    }
    var mood: Mood {
        get { Mood(rawValue: d.string(forKey: "mood") ?? "") ?? .normal }
        set { d.set(newValue.rawValue, forKey: "mood") }
    }
    var sound: Bool {
        get { d.object(forKey: "sound") as? Bool ?? true }
        set { d.set(newValue, forKey: "sound") }
    }
    var hideSystemCursor: Bool {
        get { d.object(forKey: "hideSystemCursor") as? Bool ?? true }
        set { d.set(newValue, forKey: "hideSystemCursor") }
    }

    func resolvedPalette() -> Palette {
        switch colorMode {
        case .darkPointer: return .forLightScreens
        case .lightPointer: return .forDarkScreens
        case .auto: return Self.systemIsDark() ? .forDarkScreens : .forLightScreens
        }
    }

    static func systemIsDark() -> Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

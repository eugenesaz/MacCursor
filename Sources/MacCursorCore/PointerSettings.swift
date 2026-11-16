import Foundation

/// Where settings live. `UserDefaults` conforms as is; tests use a dictionary.
public protocol SettingsStore: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
}

/// The pointer styles. The art for each lives in MacCursorRender.
public enum PointerStyle: String, CaseIterable, Sendable {
    case dogPaw, catPaw, finger, ring

    public var title: String {
        switch self {
        case .dogPaw: return "Dog paw"
        case .catPaw: return "Cat paw"
        case .finger: return "Cartoon hand"
        case .ring: return "Highlight ring"
        }
    }
}

public enum ColorMode: String, CaseIterable, Sendable {
    case auto, darkPointer, lightPointer

    public var title: String {
        switch self {
        case .auto: return "Auto (follow system appearance)"
        case .darkPointer: return "Dark — for light screens"
        case .lightPointer: return "Light — for dark screens"
        }
    }
}

/// Which of a style's two palettes to draw with.
public enum PaletteKind: Sendable {
    case forLightScreens, forDarkScreens
}

/// The pointer's saved settings. Every read validates what's stored and falls back to
/// the default, so a bad value can never break the app.
public final class PointerSettings {
    public static let sizeRange: ClosedRange<Double> = 0.4...1.6
    public static let defaultSize = 0.75
    public static let tailLengthRange: ClosedRange<Double> = 0...1
    public static let defaultTailLength = 1.0

    private let store: SettingsStore

    public init(store: SettingsStore) { self.store = store }

    // Keys match the proof of concept, so existing settings carry over.
    private enum Key {
        static let style = "skin"
        static let size = "size"
        static let tailLength = "tailLength"
        static let colorMode = "colorMode"
        static let hidesSystemCursor = "hideSystemCursor"
    }

    public var style: PointerStyle {
        get { (store.object(forKey: Key.style) as? String).flatMap(PointerStyle.init) ?? .dogPaw }
        set { store.set(newValue.rawValue, forKey: Key.style) }
    }

    /// Multiplier on the base art size.
    public var size: Double {
        get {
            guard let v = store.object(forKey: Key.size) as? Double, v.isFinite else {
                return Self.defaultSize
            }
            return v.clamped(to: Self.sizeRange)
        }
        set {
            let v = newValue.isFinite ? newValue.clamped(to: Self.sizeRange) : Self.defaultSize
            store.set(v, forKey: Key.size)
        }
    }

    /// Share of the full leg/sleeve (the "tail") to draw: 0 = none, 1 = full length.
    public var tailLength: Double {
        get {
            guard let v = store.object(forKey: Key.tailLength) as? Double, v.isFinite else {
                return Self.defaultTailLength
            }
            return v.clamped(to: Self.tailLengthRange)
        }
        set {
            let v =
                newValue.isFinite
                ? newValue.clamped(to: Self.tailLengthRange) : Self.defaultTailLength
            store.set(v, forKey: Key.tailLength)
        }
    }

    public var colorMode: ColorMode {
        get { (store.object(forKey: Key.colorMode) as? String).flatMap(ColorMode.init) ?? .auto }
        set { store.set(newValue.rawValue, forKey: Key.colorMode) }
    }

    public var hidesSystemCursor: Bool {
        get { store.object(forKey: Key.hidesSystemCursor) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.hidesSystemCursor) }
    }

    public func paletteKind(systemIsDark: Bool) -> PaletteKind {
        switch colorMode {
        case .darkPointer: return .forLightScreens
        case .lightPointer: return .forDarkScreens
        case .auto: return systemIsDark ? .forDarkScreens : .forLightScreens
        }
    }
}

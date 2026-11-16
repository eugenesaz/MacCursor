/// Preset ink colors: vivid, and the same in light and dark mode.
public enum InkColor: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple, white, black

    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// sRGB components, 0…1.
    public var rgb: (red: Double, green: Double, blue: Double) {
        switch self {
        case .red: return (1.00, 0.18, 0.20)
        case .orange: return (1.00, 0.55, 0.05)
        case .yellow: return (1.00, 0.86, 0.00)
        case .green: return (0.15, 0.80, 0.30)
        case .blue: return (0.10, 0.50, 1.00)
        case .purple: return (0.65, 0.30, 0.95)
        case .white: return (1.00, 1.00, 1.00)
        case .black: return (0.00, 0.00, 0.00)
        }
    }

    /// The color after this one in the menu order, wrapping after the last.
    public var next: InkColor {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

public enum InkWidth: String, CaseIterable, Sendable {
    case thin, medium, thick

    public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    /// Line width in points.
    public var points: Double {
        switch self {
        case .thin: return 3
        case .medium: return 6
        case .thick: return 10
        }
    }
}

/// Drawing on screen: saved settings. Every read validates what's stored and falls back to
/// the default.
public final class DrawSettings {
    public static let fadeRange: ClosedRange<Double> = 1...10
    public static let defaultFadeSeconds = 3.0
    /// The fade times offered in the menu.
    public static let fadeChoices: [Double] = [1, 2, 3, 5, 10]

    private let store: SettingsStore

    public init(store: SettingsStore) { self.store = store }

    private enum Key {
        static let isOn = "drawOn"
        static let color = "drawColor"
        static let width = "drawWidth"
        static let fadeSeconds = "drawFadeSeconds"
    }

    public var isOn: Bool {
        get { store.object(forKey: Key.isOn) as? Bool ?? true }
        set { store.set(newValue, forKey: Key.isOn) }
    }

    public var color: InkColor {
        get { (store.object(forKey: Key.color) as? String).flatMap(InkColor.init) ?? .red }
        set { store.set(newValue.rawValue, forKey: Key.color) }
    }

    public var width: InkWidth {
        get { (store.object(forKey: Key.width) as? String).flatMap(InkWidth.init) ?? .medium }
        set { store.set(newValue.rawValue, forKey: Key.width) }
    }

    /// How long fading ink stays fully visible after the line ends.
    public var fadeSeconds: Double {
        get {
            guard let v = store.object(forKey: Key.fadeSeconds) as? Double, v.isFinite else {
                return Self.defaultFadeSeconds
            }
            return v.clamped(to: Self.fadeRange)
        }
        set {
            let v =
                newValue.isFinite ? newValue.clamped(to: Self.fadeRange) : Self.defaultFadeSeconds
            store.set(v, forKey: Key.fadeSeconds)
        }
    }
}

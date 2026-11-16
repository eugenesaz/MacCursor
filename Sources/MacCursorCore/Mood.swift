/// How strongly clicks react: animation size and, when the sound follows the mood, its tone.
public enum Mood: String, CaseIterable, Sendable {
    case subtle, normal, wild

    public var title: String {
        switch self {
        case .subtle: return "Subtle"
        case .normal: return "Normal"
        case .wild: return "Wild"
        }
    }

    /// Multiplier on the click animation.
    public var intensity: Double {
        switch self {
        case .subtle: return 0.6
        case .normal: return 1.0
        case .wild: return 1.6
        }
    }
}

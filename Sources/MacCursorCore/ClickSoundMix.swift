/// How loud and at what pitch one click plays.
public struct ClickSoundMix: Sendable {
    public var volume: Double
    public var quieterWhenFast: Bool
    public var followsMood: Bool

    /// Each extra click in the window takes this much off, down to `fastFloor`.
    static let fastStep = 0.15
    static let fastFloor = 0.4
    /// Largest random change in pitch, either way.
    static let maxJitter = 0.03

    public init(volume: Double, quieterWhenFast: Bool, followsMood: Bool) {
        self.volume = volume
        self.quieterWhenFast = quieterWhenFast
        self.followsMood = followsMood
    }

    /// Amplitude multiplier, 0…1. `recentClicks` counts the clicks in the last 1.2 s,
    /// this one included.
    public func gain(recentClicks: Int, mood: Mood) -> Double {
        let v = volume.isFinite ? volume.clamped(to: 0...1) : 0
        let n = max(recentClicks, 1)
        let fast =
            quieterWhenFast ? max(Self.fastFloor, 1 - Self.fastStep * Double(n - 1)) : 1
        return v * v * moodGain(mood) * fast
    }

    /// Playback rate. `jitter` is a random number in −1…1 (clamped).
    public func pitch(mood: Mood, jitter: Double) -> Double {
        let j = jitter.isFinite ? jitter.clamped(to: -1...1) : 0
        return moodPitch(mood) * (1 + Self.maxJitter * j)
    }

    private func moodGain(_ mood: Mood) -> Double {
        guard followsMood else { return 1 }
        return mood == .subtle ? 0.7 : 1
    }

    private func moodPitch(_ mood: Mood) -> Double {
        guard followsMood else { return 1 }
        switch mood {
        case .subtle: return 0.9
        case .normal: return 1
        case .wild: return 1.12
        }
    }
}

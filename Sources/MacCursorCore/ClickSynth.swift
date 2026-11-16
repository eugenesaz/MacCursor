import Foundation

/// Makes the click sounds as mono samples, so the repo ships no audio files.
/// Each one is a short tone and/or noise burst with a soft attack, a decay and a fade to
/// exactly zero, so it never starts or ends with a click of its own.
public enum ClickSynth {
    public static let sampleRate = 48_000.0
    /// Every sound, generated or loaded, is scaled to this loudness (`loudness(of:)`) so a
    /// volume means the same for each. At full volume that's about 3 dB above the old Pop at 0.4.
    public static let level: Float = 0.05
    /// Per-sound correction on top: the ear hears Tick's high pitch as louder.
    static func trim(_ kind: ClickSoundKind) -> Float { kind == .tick ? 0.6 : 1 }

    /// Samples for a generated kind, or nil for `.pop` (the app loads the system sound).
    public static func samples(for kind: ClickSoundKind) -> [Float]? {
        let raw: [Float]
        switch kind {
        case .tap: raw = tap()
        case .tick: raw = tick()
        case .knock: raw = knock()
        case .boop: raw = boop()
        case .pop: return nil
        }
        return leveled(raw, to: level * trim(kind))
    }

    // MARK: The sounds

    /// A soft, low thump with a touch of noise, like a fingertip on a desk.
    private static func tap() -> [Float] {
        var noise = Noise(seed: 1, smoothing: 0.25)
        return render(duration: 0.060, attack: 0.0015) { t in
            0.6 * sin(2 * .pi * 190 * t) * exp(-t / 0.018) + 0.4 * noise.next() * exp(-t / 0.004)
        }
    }

    /// A tiny, high tick, like a watch.
    private static func tick() -> [Float] {
        var noise = Noise(seed: 2, smoothing: 0.9)
        return render(duration: 0.030, attack: 0.0008) { t in
            0.7 * sin(2 * .pi * 2600 * t) * exp(-t / 0.0035) + 0.3 * noise.next() * exp(-t / 0.002)
        }
    }

    /// A short, woody knock: a falling low tone, an overtone and a noise strike.
    private static func knock() -> [Float] {
        var noise = Noise(seed: 3, smoothing: 0.4)
        var phase = 0.0
        return render(duration: 0.090, attack: 0.001) { t in
            let f = 300 + 60 * exp(-t / 0.01)
            phase += 2 * .pi * f / sampleRate
            return sin(phase) * exp(-t / 0.025) + 0.5 * sin(2 * .pi * 920 * t) * exp(-t / 0.012)
                + 0.4 * noise.next() * exp(-t / 0.003)
        }
    }

    /// A round, cartoon "boop" that slides down in pitch.
    private static func boop() -> [Float] {
        var phase = 0.0
        return render(duration: 0.080, attack: 0.004) { t in
            let f = 380 + 300 * exp(-t / 0.02)
            phase += 2 * .pi * f / sampleRate
            return sin(phase) * exp(-t / 0.03)
        }
    }

    // MARK: Helpers

    /// Runs `wave` for each sample and applies a linear attack and a 5 ms fade-out.
    private static func render(
        duration: Double, attack: Double, wave: (Double) -> Double
    ) -> [Float] {
        let count = Int(duration * sampleRate)
        let attackCount = max(1, Int(attack * sampleRate))
        var out = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let t = Double(i) / sampleRate
            let a = min(1, Double(i) / Double(attackCount))
            out[i] = Float(wave(t) * a)
        }
        return trimmed(out, maxCount: count, fadeCount: Int(0.005 * sampleRate))
    }

    /// How loud a short sound is heard: the RMS of its loudest 20 ms (or of the whole sound,
    /// if shorter). Peaks say little about this; a sharp pop and a round boop with the same
    /// peak sound very different.
    public static func loudness(of samples: [Float]) -> Float {
        let window = min(samples.count, Int(0.020 * sampleRate))
        guard window > 0 else { return 0 }
        var sum = samples.prefix(window).reduce(0) { $0 + Double($1 * $1) }
        var best = sum
        for i in window..<samples.count {
            sum +=
                Double(samples[i] * samples[i]) - Double(samples[i - window] * samples[i - window])
            best = max(best, sum)
        }
        return Float(sqrt(max(best, 0) / Double(window)))
    }

    /// `samples` scaled so `loudness(of:)` is `target`. Silence stays silent.
    public static func leveled(_ samples: [Float], to target: Float) -> [Float] {
        let now = loudness(of: samples)
        guard now > 0 else { return samples }
        let k = target / now
        return samples.map { $0 * k }
    }

    /// At most `maxCount` samples, with the last `fadeCount` (or fewer, for a shorter sound)
    /// faded linearly down to exactly zero.
    public static func trimmed(_ samples: [Float], maxCount: Int, fadeCount: Int) -> [Float] {
        var out = Array(samples.prefix(maxCount))
        let n = min(fadeCount, out.count)
        guard n > 0 else { return out }
        let start = out.count - n
        for i in 0..<n {
            let w = n == 1 ? 0 : Float(n - 1 - i) / Float(n - 1)
            out[start + i] *= w
        }
        return out
    }

    /// The average of the channels, sample by sample (all channels the same length).
    public static func mono(_ channels: [[Float]]) -> [Float] {
        guard let first = channels.first else { return [] }
        let k = 1 / Float(channels.count)
        return first.indices.map { i in channels.reduce(0) { $0 + $1[i] } * k }
    }
}

/// Seeded, smoothed white noise, so the sounds are the same on every run.
private struct Noise {
    private var state: UInt32
    private var last = 0.0
    private let smoothing: Double  // 0 = silent, 1 = raw white noise

    init(seed: UInt32, smoothing: Double) {
        state = seed
        self.smoothing = smoothing
    }

    mutating func next() -> Double {
        state = state &* 1_664_525 &+ 1_013_904_223
        let white = Double(state) / Double(UInt32.max) * 2 - 1
        last += smoothing * (white - last)
        return last
    }
}

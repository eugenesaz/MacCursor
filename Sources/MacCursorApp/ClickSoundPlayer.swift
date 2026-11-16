import AVFoundation
import MacCursorCore

/// Plays the click sound with low latency: the sounds are made once and played from memory
/// through a small pool of voices. The engine runs only around clicks, so an idle app uses no
/// audio CPU.
@MainActor
final class ClickSoundPlayer {
    private struct Voice {
        let player = AVAudioPlayerNode()
        let speed = AVAudioUnitVarispeed()
        var endsAt: CFTimeInterval = 0
    }

    private static let voiceCount = 3
    private static let idlePause: TimeInterval = 5
    private static let previewInterval: CFTimeInterval = 0.15
    private static let popURL = URL(fileURLWithPath: "/System/Library/Sounds/Pop.aiff")

    private let settings = Settings.shared
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(
        standardFormatWithSampleRate: ClickSynth.sampleRate, channels: 1)!
    private var voices: [Voice] = []
    private var buffers: [ClickSoundKind: AVAudioPCMBuffer] = [:]
    private var idleTimer: Timer?
    private var lastPreview: CFTimeInterval = 0
    private var configObserver: NSObjectProtocol?

    init() {
        for _ in 0..<Self.voiceCount {
            let v = Voice()
            engine.attach(v.player)
            engine.attach(v.speed)
            voices.append(v)
        }
        connect()
        // Output device changes (headphones, a new default output) stop the engine; the next
        // click reconnects and starts it again.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.connect() }
        }
    }

    /// A real click. `recentClicks` counts the clicks in the last 1.2 s, this one included.
    func click(recentClicks: Int) {
        let sound = settings.sound
        guard sound.isOn else { return }
        play(kind: sound.kind, mix: sound.mix, recentClicks: recentClicks)
    }

    /// A sample of the current settings for the menu, played even when the sound is off.
    /// `throttled` previews (from a dragged slider) play at most every 150 ms.
    func preview(throttled: Bool = false) {
        let now = CACurrentMediaTime()
        if throttled && now - lastPreview < Self.previewInterval { return }
        lastPreview = now
        let sound = settings.sound
        play(kind: sound.kind, mix: sound.mix, recentClicks: 1)
    }

    private func play(kind: ClickSoundKind, mix: ClickSoundMix, recentClicks: Int) {
        let mood = settings.mood
        let gain = mix.gain(recentClicks: recentClicks, mood: mood)
        guard gain > 0, let buffer = buffer(for: kind) else { return }
        if !engine.isRunning {
            do { try engine.start() } catch { return }
        }
        let rate = mix.pitch(mood: mood, jitter: .random(in: -1...1))
        let now = CACurrentMediaTime()
        // An idle voice, or the one closest to finishing.
        let i = voices.indices.min { voices[$0].endsAt < voices[$1].endsAt }!
        let v = voices[i]
        v.player.stop()
        v.player.volume = Float(gain)
        v.speed.rate = Float(rate)
        v.player.scheduleBuffer(buffer)
        v.player.play()
        voices[i].endsAt = now + Double(buffer.frameLength) / ClickSynth.sampleRate / rate
        scheduleIdlePause()
    }

    private func scheduleIdlePause() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: Self.idlePause, repeats: false) {
            [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                for v in self.voices { v.player.stop() }
                self.engine.pause()
            }
        }
    }

    private func connect() {
        for v in voices {
            engine.connect(v.player, to: v.speed, format: format)
            engine.connect(v.speed, to: engine.mainMixerNode, format: format)
        }
    }

    // MARK: Buffers

    private func buffer(for kind: ClickSoundKind) -> AVAudioPCMBuffer? {
        if let b = buffers[kind] { return b }
        let b: AVAudioPCMBuffer?
        if let samples = ClickSynth.samples(for: kind) ?? Self.loadPop() {
            b = makeBuffer(samples)
        } else {
            b = buffer(for: .tap)  // Pop is missing from this macOS: use Tap, and remember that
        }
        buffers[kind] = b
        return b
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        guard
            let b = AVAudioPCMBuffer(
                pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let data = b.floatChannelData
        else { return nil }
        b.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer {
            data[0].update(from: $0.baseAddress!, count: samples.count)
        }
        return b
    }

    /// The system Pop sound as mono, cut to 350 ms with a 40 ms fade and leveled like the
    /// generated sounds. Nil if it's missing or not at 48 kHz.
    private static func loadPop() -> [Float]? {
        guard
            let file = try? AVAudioFile(forReading: popURL),
            file.processingFormat.sampleRate == ClickSynth.sampleRate,
            let b = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
            (try? file.read(into: b)) != nil,
            let data = b.floatChannelData
        else { return nil }
        let n = Int(b.frameLength)
        let channels = (0..<Int(b.format.channelCount)).map {
            Array(UnsafeBufferPointer(start: data[$0], count: n))
        }
        let rate = ClickSynth.sampleRate
        let cut = ClickSynth.trimmed(
            ClickSynth.mono(channels), maxCount: Int(0.35 * rate), fadeCount: Int(0.04 * rate))
        return ClickSynth.leveled(cut, to: ClickSynth.level)
    }
}

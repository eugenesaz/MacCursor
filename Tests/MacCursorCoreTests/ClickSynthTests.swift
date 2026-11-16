import Testing

@testable import MacCursorCore

@Suite struct ClickSynthTests {
    static let generated: [ClickSoundKind] = [.tap, .tick, .knock, .boop]

    @Test(arguments: generated)
    func generatedSoundsAreShortCleanAndLevel(kind: ClickSoundKind) throws {
        let s = try #require(ClickSynth.samples(for: kind))
        #expect(!s.isEmpty)
        #expect(Double(s.count) / ClickSynth.sampleRate <= 0.150)
        #expect(s.allSatisfy { $0.isFinite })
        let target = ClickSynth.level * ClickSynth.trim(kind)
        #expect(abs(ClickSynth.loudness(of: s) - target) < 0.0001)
        #expect((s.map(abs).max() ?? 1) < 0.5)
        #expect(abs(s.first!) < 0.05)
        #expect(s.last! == 0)
    }

    @Test(arguments: generated)
    func generationIsDeterministic(kind: ClickSoundKind) {
        #expect(ClickSynth.samples(for: kind) == ClickSynth.samples(for: kind))
    }

    @Test func soundsDiffer() {
        let all = Self.generated.compactMap { ClickSynth.samples(for: $0) }
        #expect(Set(all).count == Self.generated.count)
    }

    @Test func popIsNotGenerated() {
        #expect(ClickSynth.samples(for: .pop) == nil)
    }

    @Test func loudnessIsTheRMSOfTheLoudest20ms() {
        let window = Int(0.020 * ClickSynth.sampleRate)
        // Quiet, then a loud block exactly one window long, then quiet again.
        let s =
            [Float](repeating: 0.1, count: window) + [Float](repeating: 0.5, count: window)
            + [Float](repeating: 0.1, count: window)
        #expect(abs(ClickSynth.loudness(of: s) - 0.5) < 1e-4)
    }

    @Test func loudnessOfAShortSoundUsesAllOfIt() {
        #expect(abs(ClickSynth.loudness(of: [0.3, -0.3, 0.3, -0.3]) - 0.3) < 1e-6)
        #expect(ClickSynth.loudness(of: []) == 0)
    }

    @Test func leveledScalesToTheTarget() {
        let s: [Float] = [0, 0.4, -0.4, 0.2]
        let l = ClickSynth.leveled(s, to: 0.05)
        #expect(abs(ClickSynth.loudness(of: l) - 0.05) < 1e-6)
        #expect(abs(l[1] / l[3] - 2) < 1e-5)  // shape kept
    }

    @Test func leveledLeavesSilenceAlone() {
        #expect(ClickSynth.leveled([0, 0, 0], to: 0.05) == [0, 0, 0])
        #expect(ClickSynth.leveled([], to: 0.05) == [])
    }

    @Test func trimmedCutsAndFadesToZero() {
        let long = [Float](repeating: 1, count: 1000)
        let t = ClickSynth.trimmed(long, maxCount: 100, fadeCount: 10)
        #expect(t.count == 100)
        #expect(t[0] == 1)
        #expect(t[89] == 1)
        #expect(t[99] == 0)
        #expect(t[95] < t[90])
    }

    @Test func trimmedKeepsShortSoundsButStillEndsAtZero() {
        let t = ClickSynth.trimmed([1, 1, 1, 1], maxCount: 100, fadeCount: 2)
        #expect(t.count == 4)
        #expect(t[0] == 1 && t[1] == 1)
        #expect(t[3] == 0)
    }

    @Test func mixingToMonoAveragesChannels() {
        #expect(ClickSynth.mono([[1, 0.5], [0, -0.5]]) == [0.5, 0])
        #expect(ClickSynth.mono([[0.25, 1]]) == [0.25, 1])
        #expect(ClickSynth.mono([]) == [])
    }
}

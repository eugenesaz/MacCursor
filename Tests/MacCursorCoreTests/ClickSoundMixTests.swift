import Testing

@testable import MacCursorCore

@Suite struct ClickSoundMixTests {
    func mix(
        volume: Double = 1, quieter: Bool = true, follows: Bool = true
    ) -> ClickSoundMix {
        ClickSoundMix(volume: volume, quieterWhenFast: quieter, followsMood: follows)
    }

    @Test func zeroVolumeIsSilent() {
        #expect(mix(volume: 0).gain(recentClicks: 1, mood: .normal) == 0)
    }

    @Test(arguments: [0.0, 0.25, 0.47, 0.5, 1.0])
    func volumeFollowsASquaredCurve(volume: Double) {
        let g = mix(volume: volume).gain(recentClicks: 1, mood: .normal)
        #expect(abs(g - volume * volume) < 1e-9)
    }

    @Test func fastClickingGetsQuieterDownToAFloor() {
        let m = mix()
        let gains = (1...10).map { m.gain(recentClicks: $0, mood: .normal) }
        #expect(gains[0] == 1)
        #expect(abs(gains[1] - 0.85) < 1e-9)
        for (a, b) in zip(gains, gains.dropFirst()) { #expect(b <= a) }
        #expect(gains.last! == 0.4)
        #expect(gains.min()! >= 0.4)
    }

    @Test func noSofteningWhenTurnedOff() {
        let m = mix(quieter: false)
        #expect(m.gain(recentClicks: 9, mood: .normal) == 1)
    }

    @Test func zeroOrNegativeClickCountsCountAsOne() {
        #expect(mix().gain(recentClicks: 0, mood: .normal) == 1)
    }

    @Test func moodChangesGainAndPitch() {
        let m = mix()
        #expect(m.gain(recentClicks: 1, mood: .subtle) == 0.7)
        #expect(m.gain(recentClicks: 1, mood: .wild) == 1.0)
        #expect(m.pitch(mood: .subtle, jitter: 0) == 0.9)
        #expect(m.pitch(mood: .normal, jitter: 0) == 1.0)
        #expect(m.pitch(mood: .wild, jitter: 0) == 1.12)
    }

    @Test func moodIgnoredWhenNotFollowing() {
        let m = mix(follows: false)
        #expect(m.gain(recentClicks: 1, mood: .subtle) == 1)
        #expect(m.pitch(mood: .wild, jitter: 0) == 1)
    }

    @Test(arguments: [-5.0, -1.0, -0.5, 0.0, 0.5, 1.0, 5.0])
    func jitterStaysWithinThreePercent(jitter: Double) {
        let p = mix(follows: false).pitch(mood: .normal, jitter: jitter)
        #expect(p >= 0.97 - 1e-9 && p <= 1.03 + 1e-9)
    }

    @Test func badVolumeIsTreatedAsSilentOrFull() {
        #expect(mix(volume: -1).gain(recentClicks: 1, mood: .normal) == 0)
        #expect(mix(volume: 3).gain(recentClicks: 1, mood: .normal) == 1)
    }
}

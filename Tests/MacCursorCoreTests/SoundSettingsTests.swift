import Testing

@testable import MacCursorCore

@Suite struct SoundSettingsTests {
    let store = MemoryStore()
    var settings: SoundSettings { SoundSettings(store: store) }

    @Test func defaultsOnFirstLaunch() {
        #expect(settings.isOn == true)
        #expect(settings.volume == 0.47)
        #expect(settings.kind == .tap)
        #expect(settings.quieterWhenFast == true)
        #expect(settings.followsMood == true)
    }

    @Test func valuesPersistInTheStore() {
        let s = settings
        s.isOn = false
        s.volume = 0.8
        s.kind = .boop
        s.quieterWhenFast = false
        s.followsMood = false
        let reread = SoundSettings(store: store)
        #expect(reread.isOn == false)
        #expect(reread.volume == 0.8)
        #expect(reread.kind == .boop)
        #expect(reread.quieterWhenFast == false)
        #expect(reread.followsMood == false)
    }

    @Test func usesTheDocumentedKeys() {
        let s = settings
        s.isOn = false
        s.volume = 0.5
        s.kind = .knock
        s.quieterWhenFast = false
        s.followsMood = false
        #expect(store.values["sound"] as? Bool == false)
        #expect(store.values["soundVolume"] as? Double == 0.5)
        #expect(store.values["soundKind"] as? String == "knock")
        #expect(store.values["soundQuieterWhenFast"] as? Bool == false)
        #expect(store.values["soundFollowsMood"] as? Bool == false)
    }

    @Test func readsTheExistingOnOffKey() {
        store.values["sound"] = false
        #expect(settings.isOn == false)
    }

    @Test(arguments: [(-1.0, 0.0), (0.0, 0.0), (0.5, 0.5), (1.0, 1.0), (4.0, 1.0)])
    func volumeIsClamped(input: Double, expected: Double) {
        let s = settings
        s.volume = input
        #expect(s.volume == expected)
        #expect(store.values["soundVolume"] as? Double == expected)
    }

    @Test func badStoredValuesFallBack() {
        store.values["soundVolume"] = "loud"
        store.values["soundKind"] = "bark"
        #expect(settings.volume == 0.47)
        #expect(settings.kind == .tap)
        store.values["soundVolume"] = Double.nan
        #expect(settings.volume == 0.47)
        store.values["soundVolume"] = 7.0
        #expect(settings.volume == 1.0)
    }

    @Test func nonFiniteWriteStoresTheDefault() {
        let s = settings
        s.volume = .infinity
        #expect(s.volume == 0.47)
    }

    @Test func everyKindHasATitle() {
        #expect(ClickSoundKind.allCases.map(\.title) == ["Tap", "Tick", "Knock", "Boop", "Pop"])
    }
}

import Foundation
import Testing

@testable import MacCursorCore

/// In-memory stand-in for UserDefaults.
final class MemoryStore: SettingsStore {
    var values: [String: Any] = [:]
    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) { values[key] = value }
}

@Suite struct PointerSettingsTests {
    let store = MemoryStore()
    var settings: PointerSettings { PointerSettings(store: store) }

    @Test func defaultsOnFirstLaunch() {
        #expect(settings.styleID == "dogPaw")
        #expect(settings.size == 0.75)
        #expect(settings.colorMode == .auto)
        #expect(settings.hidesSystemCursor == true)
        #expect(settings.animatesStyle == true)
    }

    @Test func animationSettingPersists() {
        settings.animatesStyle = false
        #expect(PointerSettings(store: store).animatesStyle == false)
        #expect(store.values["animateStyle"] as? Bool == false)
        store.values["animateStyle"] = "no"
        #expect(settings.animatesStyle == true)
    }

    @Test func valuesPersistInTheStore() {
        let s = settings
        s.styleID = "catPaw"
        s.size = 1.2
        s.colorMode = .lightPointer
        s.hidesSystemCursor = false
        let reread = PointerSettings(store: store)
        #expect(reread.styleID == "catPaw")
        #expect(reread.size == 1.2)
        #expect(reread.colorMode == .lightPointer)
        #expect(reread.hidesSystemCursor == false)
    }

    @Test func keepsThePOCKeys() {
        let s = settings
        s.styleID = "ring"
        s.colorMode = .darkPointer
        #expect(store.values["skin"] as? String == "ring")
        #expect(store.values["colorMode"] as? String == "darkPointer")
        s.hidesSystemCursor = false
        #expect(store.values["hideSystemCursor"] as? Bool == false)
    }

    @Test(arguments: [(-3.0, 0.4), (0.1, 0.4), (0.4, 0.4), (1.0, 1.0), (1.6, 1.6), (9.0, 1.6)])
    func sizeIsClamped(input: Double, expected: Double) {
        let s = settings
        s.size = input
        #expect(s.size == expected)
    }

    @Test func badStoredValuesFallBackToDefaults() {
        store.values = [
            "skin": "unicorn", "colorMode": 42, "size": "big", "hideSystemCursor": "yes",
        ]
        #expect(settings.styleID == "unicorn", "an unknown id is kept; the app falls back")
        #expect(settings.colorMode == .auto)
        #expect(settings.size == 0.75)
        #expect(settings.hidesSystemCursor == true)
    }

    @Test func outOfRangeStoredSizeIsClampedOnRead() {
        store.values["size"] = 5.0
        #expect(settings.size == 1.6)
        store.values["size"] = Double.nan
        #expect(settings.size == 0.75)
    }

    @Test func tailLengthDefaultsToFullAndPersists() {
        #expect(settings.tailLength == 1.0)
        settings.tailLength = 0.3
        #expect(PointerSettings(store: store).tailLength == 0.3)
        #expect(store.values["tailLength"] as? Double == 0.3)
    }

    @Test(arguments: [(-1.0, 0.0), (0.0, 0.0), (0.5, 0.5), (1.0, 1.0), (3.0, 1.0)])
    func tailLengthIsClamped(input: Double, expected: Double) {
        let s = settings
        s.tailLength = input
        #expect(s.tailLength == expected)
    }

    @Test func badStoredTailLengthFallsBackToFull() {
        store.values["tailLength"] = "long"
        #expect(settings.tailLength == 1.0)
        store.values["tailLength"] = Double.nan
        #expect(settings.tailLength == 1.0)
        store.values["tailLength"] = -2.0
        #expect(settings.tailLength == 0.0)
        settings.tailLength = .infinity
        #expect(settings.tailLength == 1.0)
    }

    @Test(arguments: [
        (ColorMode.auto, false, PaletteKind.forLightScreens),
        (.auto, true, .forDarkScreens),
        (.darkPointer, false, .forLightScreens),
        (.darkPointer, true, .forLightScreens),
        (.lightPointer, false, .forDarkScreens),
        (.lightPointer, true, .forDarkScreens),
    ])
    func paletteChoice(mode: ColorMode, systemIsDark: Bool, expected: PaletteKind) {
        let s = settings
        s.colorMode = mode
        #expect(s.paletteKind(systemIsDark: systemIsDark) == expected)
    }

    /// Ids saved by v0.1.x (the old style enum's raw values) read back unchanged.
    @Test(arguments: ["dogPaw", "catPaw", "finger", "ring"])
    func oldStyleIDsCarryOver(id: String) {
        store.values["skin"] = id
        #expect(settings.styleID == id)
    }

    @Test func nonTextOrEmptyStyleFallsBackToTheDogPaw() {
        store.values["skin"] = 3
        #expect(settings.styleID == "dogPaw")
        store.values["skin"] = ""
        #expect(settings.styleID == "dogPaw")
    }
}

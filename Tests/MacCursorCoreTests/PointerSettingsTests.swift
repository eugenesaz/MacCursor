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
        #expect(settings.style == .dogPaw)
        #expect(settings.size == 0.75)
        #expect(settings.colorMode == .auto)
        #expect(settings.hidesSystemCursor == true)
    }

    @Test func valuesPersistInTheStore() {
        let s = settings
        s.style = .catPaw
        s.size = 1.2
        s.colorMode = .lightPointer
        s.hidesSystemCursor = false
        let reread = PointerSettings(store: store)
        #expect(reread.style == .catPaw)
        #expect(reread.size == 1.2)
        #expect(reread.colorMode == .lightPointer)
        #expect(reread.hidesSystemCursor == false)
    }

    @Test func keepsThePOCKeys() {
        let s = settings
        s.style = .ring
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
        #expect(settings.style == .dogPaw)
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

    @Test func everyStyleHasATitle() {
        for style in PointerStyle.allCases { #expect(!style.title.isEmpty) }
    }
}

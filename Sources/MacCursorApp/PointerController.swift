import AppKit
import MacCursorCore
import MacCursorRender

/// What the rest of the app (menus, and later click effects, presentation mode and hotkeys)
/// may read and change about the pointer. Every setter saves the setting and applies it live.
@MainActor
protocol PointerController: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ on: Bool)

    /// The chosen style pack's id. A missing pack draws the dog paw but keeps the id.
    var styleID: String { get set }
    /// 0.4…1.6; out-of-range values are clamped.
    var size: Double { get set }
    /// 0…1 share of the full leg/sleeve; 0 = no tail. Out-of-range values are clamped.
    var tailLength: Double { get set }
    var colorMode: ColorMode { get set }
    var hidesSystemCursor: Bool { get set }

    /// The palette in use right now (Auto resolved against the system appearance).
    var palette: Palette { get }
    /// The pointer tip in global AppKit coordinates, and the index of the display showing it.
    var tip: (location: CGPoint, display: Int?) { get }
}

extension OverlayController: PointerController {
    var styleID: String {
        get { settings.pointer.styleID }
        set {
            settings.pointer.styleID = newValue
            refreshStyle()
        }
    }

    var size: Double {
        get { settings.pointer.size }
        set {
            settings.pointer.size = newValue
            wakeOverlays()
        }
    }

    var tailLength: Double {
        get { settings.pointer.tailLength }
        set {
            settings.pointer.tailLength = newValue
            applyRig()
        }
    }

    var colorMode: ColorMode {
        get { settings.pointer.colorMode }
        set {
            settings.pointer.colorMode = newValue
            refreshStyle()
        }
    }

    var hidesSystemCursor: Bool {
        get { settings.pointer.hidesSystemCursor }
        set {
            settings.pointer.hidesSystemCursor = newValue
            updateCursorVisibility()
        }
    }

    var palette: Palette { settings.resolvedPalette() }

    var tip: (location: CGPoint, display: Int?) {
        let mouse = mouseLocation
        return (mouse, displayIndex(for: mouse))
    }
}

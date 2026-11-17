import AppKit

/// Window levels for MacCursor's click-through windows.
///
/// The pointer must sit above every window that can take a click, or it hides behind it while
/// the real cursor is hidden: system prompts and some apps' panels float above the screen-saver
/// level. Only displays captured by a game or a full-screen capture (the shielding level) and
/// the system's own cursor-level indicators stay above it.
enum OverlayLevel {
    private static let shielding = Int(CGShieldingWindowLevel())

    /// The pointer, its click effects and drawings.
    static let pointer = NSWindow.Level(rawValue: shielding - 2)
    /// On-screen notices (`Toast`), above the pointer.
    static let notice = NSWindow.Level(rawValue: shielding - 1)
}

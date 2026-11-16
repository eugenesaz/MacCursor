public enum CursorPolicy {
    /// Whether the system arrow should be hidden right now. Overlay styles (the ring) are
    /// drawn around the arrow, so it stays visible.
    public static func hidesSystemCursor(pointerOn: Bool, settingOn: Bool, styleIsOverlay: Bool)
        -> Bool
    {
        pointerOn && settingOn && !styleIsOverlay
    }
}

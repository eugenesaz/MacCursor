extension PointerStyle {
    /// The ring is drawn around the system arrow, so the arrow stays visible.
    public var keepsSystemCursor: Bool { self == .ring }
}

public enum CursorPolicy {
    /// Whether the system arrow should be hidden right now.
    public static func hidesSystemCursor(pointerOn: Bool, settingOn: Bool, style: PointerStyle)
        -> Bool
    {
        pointerOn && settingOn && !style.keepsSystemCursor
    }
}

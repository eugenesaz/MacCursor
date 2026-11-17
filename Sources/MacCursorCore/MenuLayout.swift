/// One row of the menu bar menu, by meaning. The app turns each into menu items and wires up its
/// action; some (`inkColors`, `drawHints`) stand for a run of items.
public enum MenuRow: Equatable, Sendable {
    case separator
    case header(String)

    case showPointer, presentation, presentationHint

    case style(id: String)
    /// The selected style's own switch, right under it.
    case animate
    case styleProblems(count: Int)
    case manageStyles, importStyle, removeStyle, openStylesFolder

    case size, tail, mood, color, hideSystemCursor

    case clickSound, draw
    case drawOn, allowDrawing, clearDrawing, nextInkColor, inkColors, inkWidths, fadeTimes
    case drawHints

    case version, checkForUpdates, quit
}

/// What the menu layout depends on.
public struct MenuState: Sendable {
    /// Every style in menu order: built-ins first, then custom ones.
    public var styleIDs: [String]
    public var selectedStyleID: String
    public var selectedStyleAnimates: Bool
    public var hasCustomStyles: Bool
    public var styleFailures: Int
    public var isPresenting: Bool
    public var canCheckForUpdates: Bool
    /// Drawing is on but Accessibility access is missing.
    public var drawNeedsAccess: Bool

    public init(
        styleIDs: [String], selectedStyleID: String, selectedStyleAnimates: Bool,
        hasCustomStyles: Bool, styleFailures: Int, isPresenting: Bool, canCheckForUpdates: Bool,
        drawNeedsAccess: Bool
    ) {
        self.styleIDs = styleIDs
        self.selectedStyleID = selectedStyleID
        self.selectedStyleAnimates = selectedStyleAnimates
        self.hasCustomStyles = hasCustomStyles
        self.styleFailures = styleFailures
        self.isPresenting = isPresenting
        self.canCheckForUpdates = canCheckForUpdates
        self.drawNeedsAccess = drawNeedsAccess
    }
}

/// The order and visibility of the menu's rows (`SPEC-menu-layout.md`).
public enum MenuLayout {
    public static func main(_ s: MenuState) -> [MenuRow] {
        var rows: [MenuRow] = [.showPointer, .presentation]
        if s.isPresenting { rows.append(.presentationHint) }

        rows += [.separator, .header("Style")]
        for id in s.styleIDs {
            rows.append(.style(id: id))
            if id == s.selectedStyleID && s.selectedStyleAnimates { rows.append(.animate) }
        }
        if s.styleFailures > 0 { rows.append(.styleProblems(count: s.styleFailures)) }
        rows.append(.manageStyles)

        rows += [
            .separator, .header("For all styles"),
            .size, .tail, .mood, .color, .hideSystemCursor,
            .separator, .clickSound, .draw,
            .separator, .version,
        ]
        if s.canCheckForUpdates { rows.append(.checkForUpdates) }
        rows.append(.quit)
        return rows
    }

    public static func manageStyles(_ s: MenuState) -> [MenuRow] {
        s.hasCustomStyles
            ? [.importStyle, .removeStyle, .openStylesFolder] : [.importStyle, .openStylesFolder]
    }

    public static func draw(_ s: MenuState) -> [MenuRow] {
        var rows: [MenuRow] = [.drawOn]
        if s.drawNeedsAccess { rows.append(.allowDrawing) }
        rows += [
            .clearDrawing, .nextInkColor,
            .separator, .header("Color"), .inkColors,
            .separator, .header("Thickness"), .inkWidths,
            .separator, .header("Fading lines disappear after"), .fadeTimes,
            .separator, .drawHints,
        ]
        return rows
    }
}

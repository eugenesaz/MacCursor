import Testing

@testable import MacCursorCore

@Suite struct MenuLayoutTests {
    static let builtins = ["ring", "cartoon-hand", "cat-paw", "dog-paw"]

    static func state(
        styles: [String] = builtins, selected: String = "ring", animates: Bool = false,
        custom: Bool = false, failures: Int = 0, presenting: Bool = false,
        updater: Bool = true, drawNeedsAccess: Bool = false
    ) -> MenuState {
        MenuState(
            styleIDs: styles, selectedStyleID: selected, selectedStyleAnimates: animates,
            hasCustomStyles: custom, styleFailures: failures, isPresenting: presenting,
            canCheckForUpdates: updater, drawNeedsAccess: drawNeedsAccess)
    }

    @Test func defaultMenu() {
        #expect(
            MenuLayout.main(Self.state()) == [
                .showPointer, .presentation,
                .separator,
                .header("Style"),
                .style(id: "ring"), .style(id: "cartoon-hand"), .style(id: "cat-paw"),
                .style(id: "dog-paw"),
                .manageStyles,
                .separator,
                .header("For all styles"),
                .size, .tail, .mood, .color, .hideSystemCursor,
                .separator,
                .clickSound, .draw,
                .separator,
                .version, .checkForUpdates, .quit,
            ])
    }

    @Test func defaultMenuHas23Rows() {
        #expect(MenuLayout.main(Self.state()).count == 23)
    }

    @Test func builtinAndCustomStylesShareOneRun() {
        let rows = MenuLayout.main(Self.state(styles: Self.builtins + ["rocket"], custom: true))
        let styles = rows.indices.filter { if case .style = rows[$0] { true } else { false } }
        #expect(styles.count == 5)
        #expect(styles == Array(styles.first!...styles.last!))
        #expect(rows[styles.last!] == .style(id: "rocket"))
    }

    @Test func animateFollowsTheSelectedStyleOnly() {
        let rows = MenuLayout.main(
            Self.state(styles: Self.builtins + ["rocket"], selected: "cat-paw", animates: true))
        let i = rows.firstIndex(of: .style(id: "cat-paw"))!
        #expect(rows[i + 1] == .animate)
        #expect(rows.filter { $0 == .animate }.count == 1)
    }

    @Test func noAnimateForAStyleThatCantAnimate() {
        #expect(!MenuLayout.main(Self.state(selected: "dog-paw")).contains(.animate))
    }

    @Test func noAnimateWhenTheSelectedIdIsntListed() {
        #expect(!MenuLayout.main(Self.state(selected: "gone", animates: true)).contains(.animate))
    }

    @Test func styleProblemsComeAfterTheListOnlyWhenSomeFailed() {
        #expect(
            !MenuLayout.main(Self.state()).contains {
                if case .styleProblems = $0 { true } else { false }
            })
        let rows = MenuLayout.main(Self.state(failures: 2))
        let i = rows.firstIndex(of: .styleProblems(count: 2))!
        #expect(rows[i - 1] == .style(id: "dog-paw"))
        #expect(rows[i + 1] == .manageStyles)
    }

    @Test func manageStyles() {
        #expect(MenuLayout.manageStyles(Self.state()) == [.importStyle, .openStylesFolder])
        #expect(
            MenuLayout.manageStyles(Self.state(custom: true)) == [
                .importStyle, .removeStyle, .openStylesFolder,
            ])
    }

    @Test func presentationHintOnlyWhilePresenting() {
        #expect(!MenuLayout.main(Self.state()).contains(.presentationHint))
        #expect(
            Array(MenuLayout.main(Self.state(presenting: true)).prefix(3)) == [
                .showPointer, .presentation, .presentationHint,
            ])
    }

    @Test func noCheckForUpdatesWithoutAnUpdater() {
        #expect(!MenuLayout.main(Self.state(updater: false)).contains(.checkForUpdates))
    }

    @Test func drawPutsTheHintsLast() {
        #expect(
            MenuLayout.draw(Self.state()) == [
                .drawOn, .clearDrawing, .nextInkColor,
                .separator, .header("Color"), .inkColors,
                .separator, .header("Thickness"), .inkWidths,
                .separator, .header("Fading lines disappear after"), .fadeTimes,
                .separator, .drawHints,
            ])
    }

    @Test func drawAsksForAccessRightAfterTheSwitch() {
        #expect(
            Array(MenuLayout.draw(Self.state(drawNeedsAccess: true)).prefix(3)) == [
                .drawOn, .allowDrawing, .clearDrawing,
            ])
    }
}

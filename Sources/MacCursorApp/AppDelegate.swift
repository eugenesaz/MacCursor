import AppKit
import Carbon.HIToolbox
import MacCursorCore
import MacCursorRender

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let controller = OverlayController()
    /// Pointer state goes through here; `controller` is used directly only for the
    /// presentation-mode prototype until the `presentation` module replaces it.
    private var pointer: PointerController { controller }
    private let settings = Settings.shared
    private let updater = Updater()
    private var menuIsOpen = false
    private lazy var installer = StyleInstaller(
        select: { [weak self] id in self?.pointer.styleID = id },
        showProblems: { [weak self] title, message, lines in
            self?.showProblems(title: title, message: message, lines: lines)
        })

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        HotKeys.shared.register(id: 1, keyCode: kVK_ANSI_P, modifiers: controlKey | optionKey) {
            [weak self] in
            self?.togglePointer()
        }
        HotKeys.shared.register(id: 2, keyCode: kVK_ANSI_T, modifiers: controlKey | optionKey) {
            [weak self] in
            self?.togglePresentation()
        }
        HotKeys.shared.register(id: 4, keyCode: kVK_ANSI_C, modifiers: controlKey | optionKey) {
            [weak self] in
            self?.nextInkColor()
        }
        controller.presentation.letsPressThrough = { [weak self] p in
            guard let self else { return false }
            return self.menuIsOpen || self.statusItemFrame?.contains(p) == true
        }
        controller.presentation.onHoldToExit = { [weak self] in self?.setPresentation(false) }
        StyleStore.shared.onChange = { [weak self] in self?.controller.refreshStyle() }
        StyleStore.shared.start()
        pointer.setEnabled(true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pointer.setEnabled(false)
    }

    // MARK: Actions

    @objc private func togglePointer() {
        let wasPresenting = controller.presentation.isOn
        pointer.setEnabled(!pointer.isEnabled)
        if wasPresenting && !controller.presentation.isOn { showPresentationOff() }
        updateIcon()
    }

    @objc private func togglePresentation() {
        setPresentation(!controller.presentation.isOn)
    }

    private static let presentationExitHint = "Press ⌃⌥T or hold a click for 2 seconds to exit"

    private func setPresentation(_ on: Bool) {
        guard on != controller.presentation.isOn else { return }
        if on {
            if !pointer.isEnabled { pointer.setEnabled(true) }
            if controller.presentation.enable() {
                Toast.shared.show("Presentation mode on", detail: Self.presentationExitHint)
            } else {
                let alert = NSAlert()
                alert.messageText = "Presentation mode needs Accessibility access"
                alert.informativeText =
                    "Enable MacCursor in System Settings → Privacy & Security → Accessibility, then try again. Clicks are blocked from reaching apps while it's on; press ⌃⌥T to exit."
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        } else {
            controller.presentation.disable()
            showPresentationOff()
        }
        updateIcon()
    }

    private func showPresentationOff() {
        Toast.shared.show("Presentation mode off", seconds: 1.5)
    }

    /// The menu bar icon's frame in AppKit screen coordinates.
    private var statusItemFrame: CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    @objc private func pickSkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        pointer.styleID = id
    }

    @objc private func openStylesFolder() { StyleStore.shared.openFolder() }

    @objc private func importStyle() { installer.importStyle() }

    @objc private func removeStyle() { installer.removeStyle(currentID: pointer.styleID) }

    @objc private func showStyleProblems() {
        let failures = StyleStore.shared.library.failures
        showProblems(
            title: "Some styles couldn't load",
            message:
                "Fix these in the style's files; MacCursor picks up the change as soon as you save.",
            lines: failures.flatMap(\.messages))
    }

    /// An alert with a scrolling, selectable list, so problems can be copied.
    func showProblems(title: String, message: String, lines: [String]) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 460, height: 160))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        let text = NSTextView(frame: scroll.bounds)
        text.isEditable = false
        text.isSelectable = true
        text.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        text.string = lines.joined(separator: "\n")
        text.autoresizingMask = [.width]
        scroll.documentView = text
        alert.accessoryView = scroll
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func pickMood(_ sender: NSMenuItem) {
        settings.mood = Mood(rawValue: sender.representedObject as! String)!
    }

    @objc private func pickColor(_ sender: NSMenuItem) {
        pointer.colorMode = ColorMode(rawValue: sender.representedObject as! String)!
    }

    @objc private func sizeChanged(_ sender: NSSlider) {
        pointer.size = sender.doubleValue
    }

    @objc private func tailChanged(_ sender: NSSlider) {
        pointer.tailLength = sender.doubleValue
    }

    @objc private func checkForUpdates() { updater?.checkForUpdates() }

    @objc private func toggleSound() { settings.sound.isOn.toggle() }

    @objc private func soundVolumeChanged(_ sender: NSSlider) {
        settings.sound.volume = sender.doubleValue
        controller.clickSound.preview(throttled: true)
    }

    @objc private func pickSound(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
            let kind = ClickSoundKind(rawValue: raw)
        else { return }
        settings.sound.kind = kind
        controller.clickSound.preview()
    }

    @objc private func toggleQuieterWhenFast() { settings.sound.quieterWhenFast.toggle() }

    @objc private func toggleSoundFollowsMood() { settings.sound.followsMood.toggle() }

    @objc private func toggleDraw() {
        settings.draw.isOn.toggle()
        controller.updateInk()
    }

    @objc private func allowDrawing() {
        _ = PresentationMode.hasAccessibility(prompt: true)
        NSWorkspace.shared.open(
            URL(
                string:
                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            )!)
    }

    @objc private func clearDrawing() { controller.clearInk() }

    @objc private func nextInkColor() { settings.draw.color = settings.draw.color.next }

    @objc private func pickInkColor(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let c = InkColor(rawValue: raw)
        else { return }
        settings.draw.color = c
    }

    @objc private func pickInkWidth(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let w = InkWidth(rawValue: raw)
        else { return }
        settings.draw.width = w
    }

    @objc private func pickFade(_ sender: NSMenuItem) {
        guard let seconds = sender.representedObject as? Double else { return }
        settings.draw.fadeSeconds = seconds
    }

    @objc private func toggleAnimation() { pointer.animatesStyle.toggle() }

    @objc private func toggleHideCursor() {
        pointer.hidesSystemCursor.toggle()
    }

    private func updateIcon() {
        // A highlighted arrow when on, a plain one when off, a screen while presenting.
        let name =
            controller.presentation.isOn
            ? "rectangle.inset.filled.and.cursorarrow"
            : pointer.isEnabled ? "cursorarrow.rays" : "cursorarrow"
        statusItem.button?.image = NSImage(
            systemSymbolName: name, accessibilityDescription: "MacCursor")
    }

    // MARK: Menu

    func menuWillOpen(_ menu: NSMenu) { menuIsOpen = true }
    func menuDidClose(_ menu: NSMenu) { menuIsOpen = false }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let state = menuState()
        for row in MenuLayout.main(state) { add(row, to: menu, state: state) }
    }

    private func menuState() -> MenuState {
        let library = StyleStore.shared.library
        return MenuState(
            styleIDs: library.all.map(\.id),
            selectedStyleID: library.resolved(id: pointer.styleID).id,
            selectedStyleAnimates: pointer.styleIsAnimated,
            hasCustomStyles: !library.user.isEmpty,
            styleFailures: library.failures.count,
            isPresenting: controller.presentation.isOn,
            canCheckForUpdates: updater != nil,
            drawNeedsAccess: settings.draw.isOn && pointer.isEnabled && !controller.ink.isReady)
    }

    /// Adds the menu items for one layout row.
    private func add(_ row: MenuRow, to menu: NSMenu, state: MenuState) {
        switch row {
        case .separator: menu.addItem(.separator())
        case .header(let title): menu.addItem(header(title))

        case .showPointer:
            menu.addItem(
                checked("Show pointer", #selector(togglePointer), pointer.isEnabled, key: "p"))
        case .presentation:
            menu.addItem(
                checked(
                    "Presentation mode", #selector(togglePresentation),
                    controller.presentation.isOn, key: "t"))
        case .presentationHint:
            menu.addItem(hint("Clicks don't reach apps. \(Self.presentationExitHint)."))

        case .style(let id):
            let library = StyleStore.shared.library
            guard let pack = library.all.first(where: { $0.id == id }) else { return }
            let i = checked(pack.name, #selector(pickSkin(_:)), id == state.selectedStyleID)
            i.representedObject = id
            if !pack.author.isEmpty && !library.isBuiltin(id: id) {
                i.toolTip = "By \(pack.author) · \(pack.license)"
            }
            menu.addItem(i)
        case .animate:
            let i = checked("Animate", #selector(toggleAnimation), pointer.animatesStyle)
            i.indentationLevel = 1
            menu.addItem(i)
        case .styleProblems(let n):
            menu.addItem(
                item("\(n) style\(n == 1 ? "" : "s") couldn't load…", #selector(showStyleProblems)))
        case .manageStyles:
            menu.addItem(submenu("Manage Styles", MenuLayout.manageStyles(state), state: state))
        case .importStyle: menu.addItem(item("Import Style…", #selector(importStyle)))
        case .removeStyle: menu.addItem(item("Remove Style…", #selector(removeStyle)))
        case .openStylesFolder:
            menu.addItem(item("Open Styles Folder", #selector(openStylesFolder)))

        case .size:
            menu.addItem(
                sliderItem(
                    "Size", value: pointer.size, range: PointerSettings.sizeRange,
                    action: #selector(sizeChanged(_:)), accessibility: "Pointer size"))
        case .tail:
            menu.addItem(
                sliderItem(
                    "Tail", value: pointer.tailLength, range: PointerSettings.tailLengthRange,
                    action: #selector(tailChanged(_:)), accessibility: "Tail length"))
        case .mood:
            let sub = NSMenu()
            for mood in Mood.allCases {
                let i = checked(mood.title, #selector(pickMood(_:)), settings.mood == mood)
                i.representedObject = mood.rawValue
                sub.addItem(i)
            }
            menu.addItem(parent("Mood", sub))
        case .color:
            let sub = NSMenu()
            for mode in ColorMode.allCases {
                let i = checked(mode.title, #selector(pickColor(_:)), pointer.colorMode == mode)
                i.representedObject = mode.rawValue
                sub.addItem(i)
            }
            menu.addItem(parent("Color", sub))
        case .hideSystemCursor:
            menu.addItem(
                checked(
                    "Hide system cursor", #selector(toggleHideCursor), pointer.hidesSystemCursor))

        case .clickSound: menu.addItem(soundMenuItem())
        case .draw: menu.addItem(submenu("Draw", MenuLayout.draw(state), state: state))
        case .drawOn:
            menu.addItem(checked("Draw on screen", #selector(toggleDraw), settings.draw.isOn))
        case .allowDrawing:
            menu.addItem(item("Allow Drawing in Accessibility Settings…", #selector(allowDrawing)))
        case .clearDrawing: menu.addItem(item("Clear drawing", #selector(clearDrawing)))
        case .nextInkColor: menu.addItem(item("Next color", #selector(nextInkColor), key: "c"))
        case .inkColors:
            for color in InkColor.allCases {
                let i = checked(
                    color.title, #selector(pickInkColor(_:)), settings.draw.color == color)
                i.representedObject = color.rawValue
                i.image = swatch(color)
                menu.addItem(i)
            }
        case .inkWidths:
            for width in InkWidth.allCases {
                let i = checked(
                    width.title, #selector(pickInkWidth(_:)), settings.draw.width == width)
                i.representedObject = width.rawValue
                menu.addItem(i)
            }
        case .fadeTimes:
            for seconds in DrawSettings.fadeChoices {
                let i = checked(
                    "\(Int(seconds)) s", #selector(pickFade(_:)),
                    settings.draw.fadeSeconds == seconds)
                i.representedObject = seconds
                menu.addItem(i)
            }
        case .drawHints:
            for text in [
                "Hold ⌘ and drag: the line fades", "Hold ⌘⌥ and drag: the line stays",
                "Hold ⌘ and right-click: clear the drawing",
            ] {
                menu.addItem(hint(text))
            }

        case .version:
            let version = NSMenuItem(
                title: "Version \(Updater.version)", action: nil, keyEquivalent: "")
            version.isEnabled = false
            menu.addItem(version)
        case .checkForUpdates:
            menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        case .quit:
            menu.addItem(
                NSMenuItem(
                    title: "Quit MacCursor", action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q"))
        }
    }

    /// "Click sound ▸": on/off, volume, which sound, and how it reacts.
    private func soundMenuItem() -> NSMenuItem {
        let sound = settings.sound
        let sub = NSMenu()
        sub.addItem(checked("Play click sound", #selector(toggleSound), sound.isOn))

        sub.addItem(.separator())
        sub.addItem(header("Volume"))
        sub.addItem(
            sliderItem(
                nil, value: sound.volume, range: SoundSettings.volumeRange,
                action: #selector(soundVolumeChanged(_:)), accessibility: "Click sound volume"))

        sub.addItem(.separator())
        sub.addItem(header("Sound"))
        for kind in ClickSoundKind.allCases {
            let i = checked(kind.title, #selector(pickSound(_:)), sound.kind == kind)
            i.representedObject = kind.rawValue
            sub.addItem(i)
        }

        sub.addItem(.separator())
        sub.addItem(
            checked(
                "Quieter when clicking fast", #selector(toggleQuieterWhenFast),
                sound.quieterWhenFast))
        sub.addItem(checked("Follow mood", #selector(toggleSoundFollowsMood), sound.followsMood))
        return parent("Click sound", sub)
    }

    private func submenu(_ title: String, _ rows: [MenuRow], state: MenuState) -> NSMenuItem {
        let sub = NSMenu()
        for row in rows { add(row, to: sub, state: state) }
        return parent(title, sub)
    }

    private func parent(_ title: String, _ sub: NSMenu) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.submenu = sub
        return i
    }

    private func checked(
        _ title: String, _ action: Selector, _ on: Bool, key: String = ""
    ) -> NSMenuItem {
        let i = item(title, action, key: key)
        i.state = on ? .on : .off
        return i
    }

    /// A greyed, indented line of explanation.
    private func hint(_ title: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        i.indentationLevel = 1
        return i
    }

    /// A filled circle of the ink color, outlined so white and black show on any menu.
    private func swatch(_ color: InkColor) -> NSImage {
        let c = color.rgb
        return NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            let dot = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1).setFill()
            dot.fill()
            NSColor.gray.setStroke()
            dot.lineWidth = 0.5
            dot.stroke()
            return true
        }
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { i.keyEquivalentModifierMask = [.control, .option] }
        i.target = self
        return i
    }

    /// A slider row, with an optional label on its left. Labelled sliders all line up.
    private func sliderItem(
        _ label: String?, value: Double, range: ClosedRange<Double>, action: Selector,
        accessibility: String
    ) -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
        var x: CGFloat = 20
        if let label {
            let text = NSTextField(labelWithString: label)
            text.font = .menuFont(ofSize: 0)
            text.sizeToFit()
            text.frame.origin = CGPoint(x: x, y: (view.bounds.height - text.frame.height) / 2)
            view.addSubview(text)
            x = 60
        }
        let slider = NSSlider(
            value: value, minValue: range.lowerBound, maxValue: range.upperBound,
            target: self, action: action)
        slider.isContinuous = true
        slider.frame = NSRect(x: x, y: 4, width: 200 - x, height: 22)
        slider.setAccessibilityLabel(accessibility)
        view.addSubview(slider)
        let item = NSMenuItem()
        item.view = view
        return item
    }

    private func header(_ title: String) -> NSMenuItem {
        if #available(macOS 14.0, *) { return NSMenuItem.sectionHeader(title: title) }
        let i = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        i.isEnabled = false
        return i
    }
}

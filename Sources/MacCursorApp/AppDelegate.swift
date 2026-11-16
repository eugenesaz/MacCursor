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

        let show = item("Show pointer", #selector(togglePointer), key: "p")
        show.state = pointer.isEnabled ? .on : .off
        menu.addItem(show)
        let pres = item("Presentation mode", #selector(togglePresentation), key: "t")
        pres.state = controller.presentation.isOn ? .on : .off
        menu.addItem(pres)
        if controller.presentation.isOn {
            let hint = NSMenuItem(
                title: "Clicks don't reach apps. \(Self.presentationExitHint).",
                action: nil, keyEquivalent: "")
            hint.isEnabled = false
            hint.indentationLevel = 1
            menu.addItem(hint)
        }

        menu.addItem(.separator())
        menu.addItem(header("Style"))
        let library = StyleStore.shared.library
        let current = library.resolved(id: pointer.styleID).id
        for (n, pack) in library.all.enumerated() {
            if n == library.builtins.count { menu.addItem(.separator()) }
            let i = item(pack.name, #selector(pickSkin(_:)))
            i.representedObject = pack.id
            i.state = pack.id == current ? .on : .off
            if !pack.author.isEmpty && !library.isBuiltin(id: pack.id) {
                i.toolTip = "By \(pack.author) · \(pack.license)"
            }
            menu.addItem(i)
        }
        let failed = library.failures.count
        if failed > 0 {
            let title = "\(failed) style\(failed == 1 ? "" : "s") couldn't load…"
            menu.addItem(item(title, #selector(showStyleProblems)))
        }
        menu.addItem(item("Import Style…", #selector(importStyle)))
        if !library.user.isEmpty {
            menu.addItem(item("Remove Style…", #selector(removeStyle)))
        }
        menu.addItem(item("Open Styles Folder", #selector(openStylesFolder)))

        menu.addItem(header("Size"))
        menu.addItem(
            sliderItem(
                value: pointer.size, range: PointerSettings.sizeRange,
                action: #selector(sizeChanged(_:)), label: "Pointer size"))

        menu.addItem(header("Tail"))
        menu.addItem(
            sliderItem(
                value: pointer.tailLength, range: PointerSettings.tailLengthRange,
                action: #selector(tailChanged(_:)), label: "Tail length"))

        menu.addItem(header("Mood"))
        for mood in Mood.allCases {
            let i = item(mood.title, #selector(pickMood(_:)))
            i.representedObject = mood.rawValue
            i.state = settings.mood == mood ? .on : .off
            menu.addItem(i)
        }

        let colorItem = NSMenuItem(title: "Color", action: nil, keyEquivalent: "")
        let colorMenu = NSMenu()
        for mode in ColorMode.allCases {
            let i = item(mode.title, #selector(pickColor(_:)))
            i.representedObject = mode.rawValue
            i.state = pointer.colorMode == mode ? .on : .off
            colorMenu.addItem(i)
        }
        colorItem.submenu = colorMenu
        menu.addItem(.separator())
        menu.addItem(colorItem)

        menu.addItem(soundMenuItem())
        menu.addItem(drawMenuItem())
        let hide = item("Hide system cursor", #selector(toggleHideCursor))
        hide.state = pointer.hidesSystemCursor ? .on : .off
        menu.addItem(hide)

        menu.addItem(.separator())
        let version = NSMenuItem(
            title: "Version \(Updater.version)", action: nil, keyEquivalent: "")
        version.isEnabled = false
        menu.addItem(version)
        if updater != nil {
            menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        }
        menu.addItem(
            NSMenuItem(
                title: "Quit MacCursor", action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"))
    }

    /// "Click sound ▸": on/off, volume, which sound, and how it reacts.
    private func soundMenuItem() -> NSMenuItem {
        let sound = settings.sound
        let sub = NSMenu()
        let on = item("Play click sound", #selector(toggleSound))
        on.state = sound.isOn ? .on : .off
        sub.addItem(on)

        sub.addItem(.separator())
        sub.addItem(header("Volume"))
        sub.addItem(
            sliderItem(
                value: sound.volume, range: SoundSettings.volumeRange,
                action: #selector(soundVolumeChanged(_:)), label: "Click sound volume"))

        sub.addItem(.separator())
        sub.addItem(header("Sound"))
        for kind in ClickSoundKind.allCases {
            let i = item(kind.title, #selector(pickSound(_:)))
            i.representedObject = kind.rawValue
            i.state = sound.kind == kind ? .on : .off
            sub.addItem(i)
        }

        sub.addItem(.separator())
        let fast = item("Quieter when clicking fast", #selector(toggleQuieterWhenFast))
        fast.state = sound.quieterWhenFast ? .on : .off
        sub.addItem(fast)
        let mood = item("Follow mood", #selector(toggleSoundFollowsMood))
        mood.state = sound.followsMood ? .on : .off
        sub.addItem(mood)

        let parent = NSMenuItem(title: "Click sound", action: nil, keyEquivalent: "")
        parent.submenu = sub
        return parent
    }

    /// "Draw ▸": on/off, how to draw, clear, color, thickness and fade time.
    private func drawMenuItem() -> NSMenuItem {
        let draw = settings.draw
        let sub = NSMenu()
        let on = item("Draw on screen", #selector(toggleDraw))
        on.state = draw.isOn ? .on : .off
        sub.addItem(on)
        if draw.isOn && pointer.isEnabled && !controller.ink.isReady {
            sub.addItem(item("Allow Drawing in Accessibility Settings…", #selector(allowDrawing)))
        }
        for hint in [
            "Hold ⌘ and drag: the line fades", "Hold ⌘⌥ and drag: the line stays",
            "Hold ⌘ and right-click: clear the drawing",
        ] {
            let i = NSMenuItem(title: hint, action: nil, keyEquivalent: "")
            i.isEnabled = false
            i.indentationLevel = 1
            sub.addItem(i)
        }
        sub.addItem(item("Clear drawing", #selector(clearDrawing)))
        sub.addItem(item("Next color", #selector(nextInkColor), key: "c"))

        sub.addItem(.separator())
        sub.addItem(header("Color"))
        for color in InkColor.allCases {
            let i = item(color.title, #selector(pickInkColor(_:)))
            i.representedObject = color.rawValue
            i.state = draw.color == color ? .on : .off
            i.image = swatch(color)
            sub.addItem(i)
        }

        sub.addItem(.separator())
        sub.addItem(header("Thickness"))
        for width in InkWidth.allCases {
            let i = item(width.title, #selector(pickInkWidth(_:)))
            i.representedObject = width.rawValue
            i.state = draw.width == width ? .on : .off
            sub.addItem(i)
        }

        sub.addItem(.separator())
        sub.addItem(header("Fading lines disappear after"))
        for seconds in DrawSettings.fadeChoices {
            let i = item("\(Int(seconds)) s", #selector(pickFade(_:)))
            i.representedObject = seconds
            i.state = draw.fadeSeconds == seconds ? .on : .off
            sub.addItem(i)
        }

        let parent = NSMenuItem(title: "Draw", action: nil, keyEquivalent: "")
        parent.submenu = sub
        return parent
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

    private func sliderItem(
        value: Double, range: ClosedRange<Double>, action: Selector, label: String
    ) -> NSMenuItem {
        let slider = NSSlider(
            value: value, minValue: range.lowerBound, maxValue: range.upperBound,
            target: self, action: action)
        slider.isContinuous = true
        slider.frame = NSRect(x: 20, y: 4, width: 180, height: 22)
        slider.setAccessibilityLabel(label)
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 30))
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

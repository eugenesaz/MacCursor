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
        StyleStore.shared.onChange = { [weak self] in self?.controller.refreshStyle() }
        StyleStore.shared.start()
        pointer.setEnabled(true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        pointer.setEnabled(false)
    }

    // MARK: Actions

    @objc private func togglePointer() {
        pointer.setEnabled(!pointer.isEnabled)
        updateIcon()
    }

    @objc private func togglePresentation() {
        if controller.presentation.isOn {
            controller.presentation.disable()
        } else {
            if !pointer.isEnabled { pointer.setEnabled(true) }
            if !controller.presentation.enable() {
                let alert = NSAlert()
                alert.messageText = "Presentation mode needs Accessibility access"
                alert.informativeText =
                    "Enable MacCursor in System Settings → Privacy & Security → Accessibility, then try again. Clicks are blocked from reaching apps while it's on; press ⌃⌥T to exit."
                NSApp.activate(ignoringOtherApps: true)
                alert.runModal()
            }
        }
        updateIcon()
    }

    @objc private func pickSkin(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        pointer.styleID = id
    }

    @objc private func openStylesFolder() { StyleStore.shared.openFolder() }

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

    @objc private func toggleSound() { settings.sound.toggle() }

    @objc private func toggleHideCursor() {
        pointer.hidesSystemCursor.toggle()
    }

    private func updateIcon() {
        let name =
            controller.presentation.isOn
            ? "pawprint.circle.fill"
            : pointer.isEnabled ? "pawprint.fill" : "pawprint"
        statusItem.button?.image = NSImage(
            systemSymbolName: name, accessibilityDescription: "MacCursor")
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let show = item("Show pointer", #selector(togglePointer), key: "p")
        show.state = pointer.isEnabled ? .on : .off
        menu.addItem(show)
        let pres = item("Presentation mode", #selector(togglePresentation), key: "t")
        pres.state = controller.presentation.isOn ? .on : .off
        menu.addItem(pres)

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

        let sound = item("Click sound", #selector(toggleSound))
        sound.state = settings.sound ? .on : .off
        menu.addItem(sound)
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

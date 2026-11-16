import AppKit
import Carbon.HIToolbox
import MacCursorCore
import MacCursorRender

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let controller = OverlayController()
    private let settings = Settings.shared

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
        controller.setEnabled(true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.setEnabled(false)
    }

    // MARK: Actions

    @objc private func togglePointer() {
        controller.setEnabled(!controller.isEnabled)
        updateIcon()
    }

    @objc private func togglePresentation() {
        if controller.presentation.isOn {
            controller.presentation.disable()
        } else {
            if !controller.isEnabled { controller.setEnabled(true) }
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
        settings.pointer.style = PointerStyle(rawValue: sender.representedObject as! String)!
        controller.refreshStyle()
    }

    @objc private func pickMood(_ sender: NSMenuItem) {
        settings.mood = Mood(rawValue: sender.representedObject as! String)!
    }

    @objc private func pickColor(_ sender: NSMenuItem) {
        settings.pointer.colorMode = ColorMode(rawValue: sender.representedObject as! String)!
        controller.refreshStyle()
    }

    @objc private func sizeChanged(_ sender: NSSlider) {
        settings.pointer.size = sender.doubleValue
        controller.wakeOverlays()
    }

    @objc private func toggleSound() { settings.sound.toggle() }

    @objc private func toggleHideCursor() {
        settings.pointer.hidesSystemCursor.toggle()
        controller.updateCursorVisibility()
    }

    private func updateIcon() {
        let name =
            controller.presentation.isOn
            ? "pawprint.circle.fill"
            : controller.isEnabled ? "pawprint.fill" : "pawprint"
        statusItem.button?.image = NSImage(
            systemSymbolName: name, accessibilityDescription: "MacCursor")
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let show = item("Show pointer", #selector(togglePointer), key: "p")
        show.state = controller.isEnabled ? .on : .off
        menu.addItem(show)
        let pres = item("Presentation mode", #selector(togglePresentation), key: "t")
        pres.state = controller.presentation.isOn ? .on : .off
        menu.addItem(pres)

        menu.addItem(.separator())
        menu.addItem(header("Style"))
        for kind in PointerStyle.allCases {
            let i = item(kind.title, #selector(pickSkin(_:)))
            i.representedObject = kind.rawValue
            i.state = settings.pointer.style == kind ? .on : .off
            menu.addItem(i)
        }

        menu.addItem(header("Size"))
        menu.addItem(sizeSliderItem())

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
            i.state = settings.pointer.colorMode == mode ? .on : .off
            colorMenu.addItem(i)
        }
        colorItem.submenu = colorMenu
        menu.addItem(.separator())
        menu.addItem(colorItem)

        let sound = item("Click sound", #selector(toggleSound))
        sound.state = settings.sound ? .on : .off
        menu.addItem(sound)
        let hide = item("Hide system cursor", #selector(toggleHideCursor))
        hide.state = settings.pointer.hidesSystemCursor ? .on : .off
        menu.addItem(hide)

        menu.addItem(.separator())
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

    private func sizeSliderItem() -> NSMenuItem {
        let range = PointerSettings.sizeRange
        let slider = NSSlider(
            value: settings.pointer.size, minValue: range.lowerBound, maxValue: range.upperBound,
            target: self, action: #selector(sizeChanged(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 20, y: 4, width: 180, height: 22)
        slider.setAccessibilityLabel("Pointer size")
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

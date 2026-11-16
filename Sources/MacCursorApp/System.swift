import AppKit
import ApplicationServices
import Carbon.HIToolbox
import MacCursorCore
import MacCursorRender

// MARK: - Global hotkeys (Carbon; needs no permissions)

@MainActor
final class HotKeys {
    static let shared = HotKeys()
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var installed = false

    func register(id: UInt32, keyCode: Int, modifiers: Int, _ handler: @escaping () -> Void) {
        installIfNeeded()
        handlers[id] = handler
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: OSType(0x4D43_5352), id: id)  // 'MCSR'
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hkID,
            GetApplicationEventTarget(), 0, &ref)
        if let ref { refs.append(ref) }
        log("hotkey \(id) registered: \(status == noErr)")
    }

    private func installIfNeeded() {
        guard !installed else { return }
        installed = true
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                DispatchQueue.main.async { HotKeys.shared.handlers[hk.id]?() }
                return noErr
            }, 1, &spec, nil, nil)
    }
}

// MARK: - Presentation mode: swallow mouse clicks, keep keyboard

@MainActor
final class PresentationMode {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var onClick: (() -> Void)?
    /// Presses (and their releases) that something else handles, e.g. drawing.
    var passThrough: ((CGEventType, CGEvent) -> Bool)?
    var isOn: Bool { tap != nil }

    static func hasAccessibility(prompt: Bool) -> Bool {
        // The value of kAXTrustedCheckOptionPrompt (a C global Swift 6 won't let us read).
        let key = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Returns false if Accessibility permission is missing (the system prompt is shown).
    @discardableResult
    func enable() -> Bool {
        guard !isOn else { return true }
        guard Self.hasAccessibility(prompt: true) else {
            log("presentation mode: Accessibility permission missing")
            return false
        }
        let types: [CGEventType] = [
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp,
        ]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let me = Unmanaged.passUnretained(self).toOpaque()
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    let pm = Unmanaged<PresentationMode>.fromOpaque(refcon!).takeUnretainedValue()
                    // The tap runs on the main run loop.
                    if MainActor.assumeIsolated({ pm.passThrough?(type, event) ?? false }) {
                        return Unmanaged.passUnretained(event)
                    }
                    switch type {
                    case .tapDisabledByTimeout, .tapDisabledByUserInput:
                        if let t = pm.tap { CGEvent.tapEnable(tap: t, enable: true) }
                        return Unmanaged.passUnretained(event)
                    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                        DispatchQueue.main.async { pm.onClick?() }
                        return nil  // swallow
                    default:
                        return nil  // swallow the matching mouse-up
                    }
                },
                userInfo: me)
        else {
            log("presentation mode: tapCreate failed")
            return false
        }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("presentation mode ON")
        return true
    }

    func disable() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        log("presentation mode OFF")
    }
}

func log(_ s: String) {
    FileHandle.standardError.write(("[MacCursor] " + s + "\n").data(using: .utf8)!)
}

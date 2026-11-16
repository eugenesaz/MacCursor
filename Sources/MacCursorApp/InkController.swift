import AppKit
import MacCursorCore
import QuartzCore

/// Draws ink while the mouse button is held with ⌘ (fading) or ⌘⌥ (lasting). An event tap
/// keeps those presses, drags and releases from the app underneath, so it needs the
/// Accessibility permission. The lines live in each overlay's `inkLayer`.
@MainActor
final class InkController {
    static let maxLasting = 200

    private let settings: DrawSettings
    private var gesture = InkGesture()
    private var current: (stroke: InkStroke, layer: CAShapeLayer, mode: InkMode, overlay: Overlay)?
    private var lasting: [CAShapeLayer] = []
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retry: Timer?

    /// The overlay to draw on at a point (AppKit global coordinates); nil where drawing isn't
    /// possible (no display there, screen locked).
    var overlayAt: (CGPoint) -> Overlay? = { _ in nil }
    /// Runs while drawing: claimed drags don't reach the pointer's motion monitors.
    var onDraw: () -> Void = {}
    /// Where the mouse is during a drawing press (AppKit global coordinates). The claimed
    /// drags never reach the event system, so `NSEvent.mouseLocation` stays where the press
    /// started; the pointer follows this instead. After the release it's kept until the
    /// system position moves on, so the pointer doesn't jump back to the start.
    var drawingPosition: CGPoint? {
        if !gesture.isActive, let stale = staleSystemPosition,
            NSEvent.mouseLocation != stale
        {
            lastDrawingPosition = nil
            staleSystemPosition = nil
        }
        return lastDrawingPosition
    }
    private var lastDrawingPosition: CGPoint?
    private var staleSystemPosition: CGPoint?

    init(settings: DrawSettings) { self.settings = settings }

    /// The event tap is in place, so ⌘-drags draw.
    var isReady: Bool { tap != nil }
    var isDrawing: Bool { gesture.isActive }

    /// Starts or stops listening. Without Accessibility it retries every 2 s, so granting the
    /// permission takes effect without a relaunch.
    func setActive(_ on: Bool) {
        if on {
            installTap()
        } else {
            removeTap()
            gesture = InkGesture()
            endStroke()
            lastDrawingPosition = nil
            staleSystemPosition = nil
        }
    }

    /// Whether a press with these keys draws instead of reaching apps.
    func claimsClick(keys: HeldKeys) -> Bool {
        isDrawing || (isReady && InkMode(keys: keys) != nil)
    }

    /// For Presentation Mode, which swallows clicks: the events drawing needs to see.
    func wants(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .leftMouseDown:
            return isReady && InkMode(keys: HeldKeys(event.flags)) != nil
                && overlayAt(Self.appKitPoint(event.location)) != nil
        case .leftMouseUp: return isDrawing
        default: return false
        }
    }

    /// Removes all ink, fading and lasting, on every display.
    func clear(overlays: [Overlay]) {
        current = nil
        lasting.removeAll()
        for overlay in overlays {
            for layer in overlay.inkLayer.sublayers ?? [] { layer.removeFromSuperlayer() }
        }
    }

    // MARK: Events

    /// Returns true to keep the event from the app underneath.
    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        case .leftMouseDown:
            let p = Self.appKitPoint(event.location)
            guard settings.isOn, let overlay = overlayAt(p),
                let mode = gesture.down(keys: HeldKeys(event.flags))
            else { return false }
            endStroke()
            startStroke(mode: mode, at: overlay.local(p), on: overlay)
            lastDrawingPosition = p
            staleSystemPosition = nil
            onDraw()
            return true
        case .leftMouseDragged:
            guard gesture.isActive else { return false }
            let p = Self.appKitPoint(event.location)
            draw(mode: gesture.drag(keys: HeldKeys(event.flags)), at: p)
            lastDrawingPosition = p
            staleSystemPosition = nil
            onDraw()
            return true
        case .leftMouseUp:
            guard gesture.up() else { return false }
            endStroke()
            lastDrawingPosition = Self.appKitPoint(event.location)
            staleSystemPosition = NSEvent.mouseLocation
            onDraw()
            return true
        default:
            return false
        }
    }

    private func draw(mode: InkMode?, at p: CGPoint) {
        if let c = current, c.mode != mode || c.stroke.isFull {
            endStroke()
            // ⌥ switched or the line is full: carry on as a new line from the same point.
            if let mode { startStroke(mode: mode, at: c.stroke.last, on: c.overlay) }
        }
        guard var c = current, c.stroke.add(c.overlay.local(p)) else { return }
        current = c
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        c.layer.path = c.stroke.path
        CATransaction.commit()
    }

    // MARK: Strokes

    private func startStroke(mode: InkMode, at p: CGPoint, on overlay: Overlay) {
        let stroke = InkStroke(start: p)
        let layer = CAShapeLayer()
        let c = settings.color.rgb
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = overlay.inkLayer.bounds
        layer.contentsScale = overlay.backingScale
        layer.fillColor = nil
        layer.strokeColor = CGColor(srgbRed: c.red, green: c.green, blue: c.blue, alpha: 1)
        layer.lineWidth = settings.width.points
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.path = stroke.path
        overlay.inkLayer.addSublayer(layer)
        CATransaction.commit()
        current = (stroke, layer, mode, overlay)
    }

    private func endStroke() {
        guard let c = current else { return }
        current = nil
        switch c.mode {
        case .lasting:
            lasting.removeAll { $0.superlayer == nil }
            lasting.append(c.layer)
            if lasting.count > Self.maxLasting {
                lasting.removeFirst().removeFromSuperlayer()
            }
        case .fading:
            fade(c.layer, after: settings.fadeSeconds)
        }
    }

    /// Fully visible for `delay`, then fades out over 0.5 s on the render server and is removed.
    private func fade(_ layer: CAShapeLayer, after delay: Double) {
        let duration = 0.5
        let anim = CABasicAnimation(keyPath: "opacity")
        anim.fromValue = 1
        anim.toValue = 0
        anim.beginTime = layer.convertTime(CACurrentMediaTime(), from: nil) + delay
        anim.duration = duration
        anim.fillMode = .backwards
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = 0
        layer.add(anim, forKey: "fade")
        CATransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay + duration) { [weak layer] in
            layer?.removeFromSuperlayer()
        }
    }

    // MARK: Event tap

    private func installTap() {
        guard tap == nil else { return }
        guard PresentationMode.hasAccessibility(prompt: false) else {
            scheduleRetry()
            return
        }
        let types: [CGEventType] = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, refcon in
                    let ink = Unmanaged<InkController>.fromOpaque(refcon!).takeUnretainedValue()
                    // The tap runs on the main run loop.
                    let swallow = MainActor.assumeIsolated { ink.handle(type, event) }
                    return swallow ? nil : Unmanaged.passUnretained(event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque())
        else {
            log("draw: tapCreate failed")
            scheduleRetry()
            return
        }
        retry?.invalidate()
        retry = nil
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log("draw: ready")
    }

    private func scheduleRetry() {
        guard retry == nil else { return }
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.installTap() }
        }
        RunLoop.main.add(t, forMode: .common)
        retry = t
    }

    private func removeTap() {
        retry?.invalidate()
        retry = nil
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
    }

    /// Event-tap locations have their origin at the top left of the main display, y down.
    private static func appKitPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - p.y)
    }
}

extension HeldKeys {
    init(_ flags: CGEventFlags) {
        self = []
        if flags.contains(.maskCommand) { insert(.command) }
        if flags.contains(.maskAlternate) { insert(.option) }
        if flags.contains(.maskControl) { insert(.control) }
        if flags.contains(.maskShift) { insert(.shift) }
        if flags.contains(.maskSecondaryFn) { insert(.function) }
    }
}

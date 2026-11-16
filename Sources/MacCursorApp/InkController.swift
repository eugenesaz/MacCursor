import AppKit
import MacCursorCore
import QuartzCore

/// Draws ink while ⌘ (fading) or ⌘⌥ (lasting) is held and the mouse moves. Input is polled,
/// so no Accessibility permission is needed. The lines live in each overlay's `inkLayer`.
@MainActor
final class InkController {
    private let settings: DrawSettings
    private var trigger = InkTrigger()
    private var current: (stroke: InkStroke, layer: CAShapeLayer, mode: InkMode, overlay: Overlay)?
    private var lasting: [CAShapeLayer] = []
    static let maxLasting = 200

    init(settings: DrawSettings) { self.settings = settings }

    /// Call on every mouse move and on the backstop timer. `overlay`: the display under the
    /// mouse; nil when there is none or drawing isn't possible (pointer off, screen locked).
    func tick(mouse: CGPoint, overlay: Overlay?, overlays: [Overlay]) {
        let polled = trigger.update(
            keys: Self.heldKeys(), buttonDown: Self.buttonDown(),
            keyDownCount: CGEventSource.counterForEventType(
                .combinedSessionState, eventType: .keyDown))
        let mode = settings.isOn && overlay != nil ? polled : nil

        if let c = current, !overlays.contains(where: { $0 === c.overlay }) {
            current = nil  // its display went away, and the line with it
        }
        if let c = current, c.mode != mode || c.stroke.isFull {
            endStroke()
            if c.mode == mode, let mode {
                // Full: carry on as a new line from the same point.
                startStroke(mode: mode, at: c.stroke.last, on: c.overlay)
            }
        }
        guard let mode, let overlay else { return }
        if current == nil {
            startStroke(mode: mode, at: overlay.local(mouse), on: overlay)
        } else if var c = current, c.stroke.add(c.overlay.local(mouse)) {
            current = c
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            c.layer.path = c.stroke.path
            CATransaction.commit()
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

    private static func heldKeys() -> HeldKeys {
        let flags = CGEventSource.flagsState(.combinedSessionState)
        var keys: HeldKeys = []
        if flags.contains(.maskCommand) { keys.insert(.command) }
        if flags.contains(.maskAlternate) { keys.insert(.option) }
        if flags.contains(.maskControl) { keys.insert(.control) }
        if flags.contains(.maskShift) { keys.insert(.shift) }
        if flags.contains(.maskSecondaryFn) { keys.insert(.function) }
        return keys
    }

    private static func buttonDown() -> Bool {
        [CGMouseButton.left, .right, .center].contains {
            CGEventSource.buttonState(.combinedSessionState, button: $0)
        }
    }
}

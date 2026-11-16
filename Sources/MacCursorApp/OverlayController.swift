import AppKit
import MacCursorCore
import MacCursorRender
import QuartzCore

/// One transparent, click-through window covering one display.
final class Overlay {
    let window: NSPanel
    let frame: CGRect
    let rig: PointerRig
    let backingScale: CGFloat
    private let effectsLayer = CALayer()
    private var effects: [ClickEffect] = []

    init(screen: NSScreen) {
        frame = screen.frame
        backingScale = screen.backingScaleFactor
        window = NSPanel(
            contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [
            .canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle,
        ]
        window.isReleasedWhenClosed = false
        window.sharingType = .readOnly  // must show up in screen shares & recordings
        window.setFrame(frame, display: false)

        let view = NSView(frame: CGRect(origin: .zero, size: frame.size))
        view.wantsLayer = true
        window.contentView = view
        rig = PointerRig(contentsScale: backingScale)
        effectsLayer.frame = view.bounds
        view.layer!.addSublayer(effectsLayer)
        view.layer!.addSublayer(rig.root)
        window.orderFrontRegardless()
    }

    func local(_ p: CGPoint) -> CGPoint { DisplayLayout.local(p, in: frame) }

    func angle(at local: CGPoint) -> CGFloat {
        DisplayLayout.leanAngle(localX: local.x, width: frame.width)
    }

    /// `active`: this display shows the pointer (exactly one display does).
    func update(
        mouse: CGPoint, active: Bool, now: CFTimeInterval, scale: CGFloat, squash: CGFloat
    ) {
        rig.root.isHidden = !active
        if active {
            let p = local(mouse)
            rig.setPose(position: p, angle: angle(at: p), scale: scale, squash: squash)
        }
        effects = effects.filter { $0.update(now: now) }
    }

    func addEffect(
        at mouse: CGPoint, art: SkinArt, palette: Palette, intensity: CGFloat, scale: CGFloat,
        now: CFTimeInterval
    ) {
        let p = local(mouse)
        let fx = ClickEffect(
            tip: p, angle: angle(at: p), art: art, palette: palette,
            intensity: intensity, scale: scale, contentsScale: backingScale, start: now)
        effectsLayer.addSublayer(fx.layer)
        effects.append(fx)
    }

    func close() {
        window.orderOut(nil)
        window.close()
    }
}

final class OverlayController {
    private var overlays: [Overlay] = []
    private var layout = DisplayLayout(frames: [])
    private var pendingRebuild: DispatchWorkItem?
    private var timer: Timer?
    private var monitors: [Any] = []
    private var clickTimes: [CFTimeInterval] = []
    private var lastClick: CFTimeInterval = -10
    private var lastIntensity: CGFloat = 1
    private var art = Skins.art(for: .dogPaw)
    private var palette = Palette.forLightScreens
    private var lastSystemDark = false
    private var tickCount = 0
    private let settings = Settings.shared
    let presentation = PresentationMode()
    private(set) var isEnabled = false

    init() {
        presentation.onClick = { [weak self] in self?.handleClick() }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, self.isEnabled else { return }
            self.scheduleRebuild()
        }
    }

    func setEnabled(_ on: Bool) {
        guard on != isEnabled else { return }
        isEnabled = on
        if on {
            rebuild()
            let t = Timer(timeInterval: 1.0 / 120, repeats: true) { [weak self] _ in self?.tick() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
            let mask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            if let g = NSEvent.addGlobalMonitorForEvents(
                matching: mask, handler: { [weak self] _ in self?.handleClick() })
            {
                monitors.append(g)
            }
            if let l = NSEvent.addLocalMonitorForEvents(
                matching: mask,
                handler: { [weak self] e in
                    self?.handleClick()
                    return e
                })
            {
                monitors.append(l)
            }
        } else {
            timer?.invalidate()
            timer = nil
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
            for overlay in overlays { overlay.close() }
            overlays.removeAll()
            presentation.disable()
        }
        updateCursorVisibility()
        log("pointer \(on ? "enabled" : "disabled")")
    }

    /// Re-read skin / color settings.
    func refreshStyle() {
        art = Skins.art(for: settings.pointer.style)
        palette = settings.resolvedPalette()
        lastSystemDark = Settings.systemIsDark()
        for overlay in overlays { overlay.rig.apply(art: art, palette: palette) }
        updateCursorVisibility()
    }

    func updateCursorVisibility() {
        cursorHider.setHidden(
            CursorPolicy.hidesSystemCursor(
                pointerOn: isEnabled, settingOn: settings.pointer.hidesSystemCursor,
                style: settings.pointer.style))
    }

    /// Display changes arrive in bursts (one per display and property); rebuild once after.
    private func scheduleRebuild() {
        pendingRebuild?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isEnabled else { return }
            self.rebuild()
        }
        pendingRebuild = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func activeOverlay(for mouse: CGPoint) -> Overlay? {
        layout.index(containing: mouse).map { overlays[$0] }
    }

    private func rebuild() {
        for overlay in overlays { overlay.close() }
        overlays = NSScreen.screens.map(Overlay.init)
        layout = DisplayLayout(frames: overlays.map(\.frame))
        refreshStyle()
        log("overlays: \(overlays.count) display(s)")
    }

    private func tick() {
        let now = CACurrentMediaTime()
        tickCount += 1
        // Auto color: notice system light/dark switches (~twice a second).
        if tickCount % 60 == 0, settings.pointer.colorMode == .auto,
            Settings.systemIsDark() != lastSystemDark
        {
            refreshStyle()
        }
        let mood = settings.mood
        let t = now - lastClick
        let squash =
            art.isRing
            ? 0 : t < 0.2 ? CGFloat(sin(.pi * t / 0.2)) * min(1, 0.6 + 0.2 * lastIntensity) : 0
        let mouse = NSEvent.mouseLocation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let active = activeOverlay(for: mouse)
        for overlay in overlays {
            overlay.update(
                mouse: mouse, active: overlay === active, now: now,
                scale: mood.scale, squash: squash)
        }
        CATransaction.commit()
    }

    private func handleClick() {
        guard isEnabled else { return }
        let now = CACurrentMediaTime()
        clickTimes = clickTimes.filter { now - $0 < 1.2 } + [now]
        lastClick = now
        let mood = settings.mood
        // Faster clicking → bigger reaction.
        lastIntensity = min(1 + CGFloat(clickTimes.count - 1) * 0.55, 3.2) * mood.intensity
        let mouse = NSEvent.mouseLocation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        activeOverlay(for: mouse)?
            .addEffect(
                at: mouse, art: art, palette: palette, intensity: lastIntensity, scale: mood.scale,
                now: now)
        CATransaction.commit()
        if settings.sound, let s = NSSound(named: "Pop")?.copy() as? NSSound {
            s.volume = 0.4
            s.play()
        }
    }
}

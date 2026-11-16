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
    private var displayLink: CADisplayLink?
    private var lastPose: (mouse: CGPoint, active: Bool, scale: CGFloat, squash: CGFloat)?
    private var idleFrames = 0

    /// `onFrame` runs once per refresh of this overlay's display (up to 120 Hz on ProMotion).
    init(screen: NSScreen, onFrame: @escaping (Overlay) -> Void) {
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

        let target = FrameTarget()
        let link = screen.displayLink(target: target, selector: #selector(FrameTarget.frame))
        target.onFrame = { [unowned self] in onFrame(self) }
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func local(_ p: CGPoint) -> CGPoint { DisplayLayout.local(p, in: frame) }

    func angle(at local: CGPoint) -> CGFloat {
        DisplayLayout.leanAngle(localX: local.x, width: frame.width)
    }

    /// `active`: this display shows the pointer (exactly one display does).
    func update(
        mouse: CGPoint, active: Bool, now: CFTimeInterval, scale: CGFloat, squash: CGFloat
    ) {
        // Nothing moved and nothing is animating: skip the frame (keeps idle CPU near zero).
        if effects.isEmpty, let last = lastPose, last.mouse == mouse, last.active == active,
            last.scale == scale, last.squash == squash
        {
            // Still for a quarter second: stop the display link until `wake()`.
            idleFrames += 1
            if idleFrames > 30 { displayLink?.isPaused = true }
            return
        }
        idleFrames = 0
        lastPose = (mouse, active, scale, squash)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
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
        wake()
    }

    /// Forces the next frame to redraw (after a style change).
    func invalidatePose() {
        lastPose = nil
        wake()
    }

    /// Resumes per-frame updates after the pointer moves or something starts animating.
    func wake() {
        idleFrames = 0
        displayLink?.isPaused = false
    }

    func close() {
        displayLink?.invalidate()
        displayLink = nil
        window.orderOut(nil)
        window.close()
    }
}

/// CADisplayLink needs an Objective-C target.
private final class FrameTarget: NSObject {
    var onFrame: (() -> Void)?
    @objc func frame() { onFrame?() }
}

final class OverlayController {
    private var overlays: [Overlay] = []
    private var layout = DisplayLayout(frames: [])
    private var pendingRebuild: DispatchWorkItem?
    private var appearanceTimer: Timer?
    private var monitors: [Any] = []
    private var clickTimes: [CFTimeInterval] = []
    private var lastClick: CFTimeInterval = -10
    private var lastIntensity: CGFloat = 1
    private var art = Skins.art(for: .dogPaw)
    private var palette = Palette.forLightScreens
    private var lastSystemDark = false
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
            // Auto color: notice system light/dark switches twice a second.
            let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkAppearance()
            }
            RunLoop.main.add(t, forMode: .common)
            appearanceTimer = t
            let moves: NSEvent.EventTypeMask = [
                .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            ]
            if let g = NSEvent.addGlobalMonitorForEvents(
                matching: moves, handler: { [weak self] _ in self?.wakeOverlays() })
            {
                monitors.append(g)
            }
            if let l = NSEvent.addLocalMonitorForEvents(
                matching: moves,
                handler: { [weak self] e in
                    self?.wakeOverlays()
                    return e
                })
            {
                monitors.append(l)
            }
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
            appearanceTimer?.invalidate()
            appearanceTimer = nil
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
        for overlay in overlays {
            overlay.rig.apply(art: art, palette: palette)
            overlay.invalidatePose()
        }
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
        overlays = NSScreen.screens.map { screen in
            Overlay(screen: screen) { [weak self] overlay in self?.frame(for: overlay) }
        }
        layout = DisplayLayout(frames: overlays.map(\.frame))
        refreshStyle()
        log("overlays: \(overlays.count) display(s)")
    }

    private func wakeOverlays() {
        for overlay in overlays { overlay.wake() }
    }

    private func checkAppearance() {
        if settings.pointer.colorMode == .auto, Settings.systemIsDark() != lastSystemDark {
            refreshStyle()
        }
    }

    /// One display refresh for one overlay.
    private func frame(for overlay: Overlay) {
        let now = CACurrentMediaTime()
        let mood = settings.mood
        let t = now - lastClick
        let squash =
            art.isRing
            ? 0 : t < 0.2 ? CGFloat(sin(.pi * t / 0.2)) * min(1, 0.6 + 0.2 * lastIntensity) : 0
        let mouse = NSEvent.mouseLocation
        overlay.update(
            mouse: mouse, active: overlay === activeOverlay(for: mouse), now: now,
            scale: mood.scale, squash: squash)
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

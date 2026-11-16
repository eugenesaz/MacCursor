import AppKit
import MacCursorCore
import MacCursorRender
import QuartzCore

/// One transparent, click-through window covering one display.
@MainActor
final class Overlay {
    let window: NSPanel
    let frame: CGRect
    let rig: PointerRig
    let backingScale: CGFloat
    private let effectsLayer = CALayer()
    /// Drawn lines: above the click effects, below the pointer.
    let inkLayer = CALayer()
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
        rig.root.isHidden = true  // until the first frame positions it
        effectsLayer.frame = view.bounds
        view.layer!.addSublayer(effectsLayer)
        inkLayer.frame = view.bounds
        view.layer!.addSublayer(inkLayer)
        view.layer!.addSublayer(rig.root)
        window.orderFrontRegardless()

        let target = FrameTarget()
        let link = screen.displayLink(target: target, selector: #selector(FrameTarget.frame))
        target.onFrame = { [weak self] in
            guard let self else { return }
            onFrame(self)
        }
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
        // A display without the pointer only needs to redraw when that changes.
        if effects.isEmpty, let last = lastPose, last.active == active,
            !active || (last.mouse == mouse && last.scale == scale && last.squash == squash)
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
        at mouse: CGPoint, pack: StylePack, palette: Palette, intensity: CGFloat, scale: CGFloat,
        now: CFTimeInterval
    ) {
        let p = local(mouse)
        let fx = ClickEffect(
            tip: p, angle: angle(at: p), pack: pack, palette: palette,
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
@MainActor
private final class FrameTarget: NSObject {
    var onFrame: (() -> Void)?
    @objc func frame() { onFrame?() }
}

@MainActor
final class OverlayController {
    private var overlays: [Overlay] = []
    private var layout = DisplayLayout(frames: [])
    private var pendingRebuild: DispatchWorkItem?
    private var appearanceObservation: NSKeyValueObservation?
    private var monitors: [Any] = []
    private var clickTimes: [CFTimeInterval] = []
    /// Plays the click sound; the menu uses it for previews.
    let clickSound = ClickSoundPlayer()
    private var lastClick: CFTimeInterval = -10
    private var lastIntensity: CGFloat = 1
    private var pack = StyleStore.shared.pack(for: Settings.shared.pointer.styleID)
    private var activePalette = Palette.forLightScreens
    private var mouseWatch: Timer?
    private var lastWatchedMouse = CGPoint(x: -1, y: -1)
    /// True while the screen is locked or another user's session is active.
    private var sessionInactive = false
    private var lastSystemDark = false
    let settings = Settings.shared
    let presentation = PresentationMode()
    let ink = InkController(settings: Settings.shared.draw)
    private(set) var isEnabled = false

    init() {
        presentation.onClick = { [weak self] in self?.handleClick() }
        presentation.passThrough = { [weak self] type, event in
            self?.ink.wants(type, event) ?? false
        }
        ink.overlayAt = { [weak self] p in
            guard let self, !self.sessionInactive else { return nil }
            return self.activeOverlay(for: p)
        }
        ink.onDraw = { [weak self] in self?.wakeOverlays() }
        ink.onClear = { [weak self] in self?.clearInk() }
        observeSession()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // Delivered on the main queue.
            MainActor.assumeIsolated {
                guard let self, self.isEnabled else { return }
                self.scheduleRebuild()
            }
        }
    }

    func setEnabled(_ on: Bool) {
        guard on != isEnabled else { return }
        isEnabled = on
        if on {
            rebuild()
            // Auto color: follow system light/dark switches as they happen.
            appearanceObservation = NSApp.observe(\.effectiveAppearance) {
                @Sendable [weak self] _, _ in
                Task { @MainActor in self?.checkAppearance() }
            }
            // Backstop for motion the event monitors miss: inside our own menu (local
            // monitors don't run during menu tracking), cursor warps. Cheap at 15 Hz.
            let watch = Timer(timeInterval: 1.0 / 15, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.watchMouse() }
            }
            RunLoop.main.add(watch, forMode: .common)
            mouseWatch = watch
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
            appearanceObservation = nil
            mouseWatch?.invalidate()
            mouseWatch = nil
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
            clearInk()
            for overlay in overlays { overlay.close() }
            overlays.removeAll()
            layout = DisplayLayout(frames: [])
            presentation.disable()
        }
        updateInk()
        updateCursorVisibility()
        log("pointer \(on ? "enabled" : "disabled")")
    }

    /// Re-read skin / color settings.
    func refreshStyle() {
        pack = StyleStore.shared.pack(for: settings.pointer.styleID)
        activePalette = settings.resolvedPalette()
        lastSystemDark = Settings.systemIsDark()
        applyRig()
        updateCursorVisibility()
    }

    /// Redraws every overlay's pointer with the current art, palette and tail length.
    /// Cheap enough to run on every tick of the Tail slider; `refreshStyle` rebuilds the art.
    func applyRig() {
        for overlay in overlays {
            overlay.rig.apply(
                pack: pack, palette: activePalette,
                tailLength: CGFloat(settings.pointer.tailLength))
            overlay.invalidatePose()
        }
    }

    func updateCursorVisibility() {
        cursorHider.setHidden(
            CursorPolicy.hidesSystemCursor(
                pointerOn: isEnabled && !sessionInactive,
                settingOn: settings.pointer.hidesSystemCursor,
                styleIsOverlay: pack.overlay))
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

    func displayIndex(for mouse: CGPoint) -> Int? { layout.index(containing: mouse) }

    private func activeOverlay(for mouse: CGPoint) -> Overlay? {
        displayIndex(for: mouse).map { overlays[$0] }
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

    /// The mouse position the pointer follows (AppKit global coordinates).
    var mouseLocation: CGPoint { ink.drawingPosition ?? NSEvent.mouseLocation }

    /// Pointer scale: the size setting (the mood no longer scales the pointer).
    private var scale: CGFloat { CGFloat(settings.pointer.size) }

    private func watchMouse() {
        let mouse = mouseLocation
        guard mouse != lastWatchedMouse else { return }
        lastWatchedMouse = mouse
        wakeOverlays()
    }

    /// Removes every drawn line.
    func clearInk() { ink.clear(overlays: overlays) }

    /// Starts or stops drawing after the pointer or the Draw setting changed.
    func updateInk() {
        ink.setActive(isEnabled && settings.draw.isOn)
        if !settings.draw.isOn { clearInk() }
    }

    /// The lock screen and other sessions draw above our overlay, so they must get the
    /// real arrow back.
    private func observeSession() {
        let workspace = NSWorkspace.shared.notificationCenter
        let distributed = DistributedNotificationCenter.default()
        let inactive: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.sessionDidResignActiveNotification),
            (distributed, Notification.Name("com.apple.screenIsLocked")),
        ]
        let active: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification),
            (distributed, Notification.Name("com.apple.screenIsUnlocked")),
        ]
        for (center, name) in inactive + active {
            let isInactive = inactive.contains { $0.1 == name }
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.sessionInactive = isInactive
                    self.updateCursorVisibility()
                    log("session \(isInactive ? "inactive: arrow back" : "active again")")
                }
            }
        }
    }

    /// Redraws on the next frame, e.g. after the size changed.
    func wakeOverlays() {
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
        let t = now - lastClick
        let squash =
            pack.overlay
            ? 0 : t < 0.2 ? CGFloat(sin(.pi * t / 0.2)) * min(1, 0.6 + 0.2 * lastIntensity) : 0
        let mouse = mouseLocation
        overlay.update(
            mouse: mouse, active: overlay === activeOverlay(for: mouse), now: now,
            scale: scale, squash: squash)
    }

    private func handleClick() {
        // A press that draws gets no click effect or sound.
        let keys = HeldKeys(CGEventSource.flagsState(.combinedSessionState))
        guard isEnabled, !ink.claimsClick(keys: keys) else { return }
        let now = CACurrentMediaTime()
        clickTimes = clickTimes.filter { now - $0 < 1.2 } + [now]
        lastClick = now
        let mood = settings.mood
        // Faster clicking → bigger reaction.
        lastIntensity = min(1 + CGFloat(clickTimes.count - 1) * 0.55, 3.2) * CGFloat(mood.intensity)
        let mouse = mouseLocation
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        activeOverlay(for: mouse)?
            .addEffect(
                at: mouse, pack: pack, palette: activePalette, intensity: lastIntensity,
                scale: scale,
                now: now)
        CATransaction.commit()
        clickSound.click(recentClicks: clickTimes.count)
    }
}

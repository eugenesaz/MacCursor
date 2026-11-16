import AppKit

/// Hides and shows the system cursor while another app is in front.
protocol CursorHiding: AnyObject {
    var isHidden: Bool { get }
    func setHidden(_ hide: Bool)
}

/// The app-wide hider: SkyLight when available, otherwise a no-op that logs once.
let cursorHider: CursorHiding = SkyLightCursorHider.make() ?? UnavailableCursorHider()

/// Used when the private API is missing (a future macOS may change it). The arrow stays
/// visible and everything else keeps working.
final class UnavailableCursorHider: CursorHiding {
    private var logged = false
    var isHidden: Bool { false }
    func setHidden(_ hide: Bool) {
        guard hide, !logged else { return }
        logged = true
        log("hide system cursor: SkyLight API unavailable; the arrow stays visible")
    }
}

// CGDisplayHideCursor (even with the private "SetsCursorInBackground" property) no longer
// hides the arrow on screen on macOS 26+. What works: register a fully transparent cursor
// with SkyLight under our own name and make it current. The window server resets the cursor
// as the pointer crosses windows, so a watcher thread re-applies it the moment the cursor
// seed changes. Undocumented private API: may break in future macOS releases.
// Technique credit: Cursorlight (github.com/Zawalid/Cursorlight, MIT).
final class SkyLightCursorHider: CursorHiding {
    fileprivate typealias ConnFn = @convention(c) () -> Int32
    fileprivate typealias RegisterFn =
        @convention(c) (
            Int32, UnsafePointer<CChar>, Bool, Bool, UInt, CFArray, CGSize, CGPoint,
            UnsafeMutablePointer<Int>, CGRect, CGFloat, Int
        ) -> Int32
    fileprivate typealias SetRegisteredFn =
        @convention(c) (Int32, UnsafePointer<CChar>, UnsafeMutablePointer<Int>) -> Int32
    fileprivate typealias RemoveFn = @convention(c) (Int32, UnsafePointer<CChar>, Bool) -> Int32
    fileprivate typealias SeedFn = @convention(c) () -> Int32
    fileprivate typealias SetSystemFn = @convention(c) (Int32, Int32) -> Int32
    fileprivate typealias DockFn = @convention(c) (Int32, Bool) -> Int32
    fileprivate typealias SetPropFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private struct API {
        let connection: ConnFn
        let register: RegisterFn
        let setRegistered: SetRegisteredFn
        let seed: SeedFn
        let remove: RemoveFn?
        let setSystem: SetSystemFn?
        let dock: DockFn?
        let setProperty: SetPropFn?
    }

    static let cursorName = "io.github.eugenesaz.maccursor.blank"

    private let api: API
    private var watcher: Watcher?
    private var monitor: Any?
    var isHidden: Bool { watcher != nil }

    private init(api: API) { self.api = api }

    /// nil when the private symbols can't be found.
    static func make() -> SkyLightCursorHider? {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let h = dlopen(path, RTLD_NOW) else { return nil }
        func load<T>(_ name: String, _: T.Type) -> T? {
            dlsym(h, name).map { unsafeBitCast($0, to: T.self) }
        }
        guard let c = load("SLSMainConnectionID", ConnFn.self),
            let r = load("SLSRegisterCursorWithImages", RegisterFn.self),
            let s = load("SLSSetRegisteredCursor", SetRegisteredFn.self),
            let seed = load("SLSCurrentCursorSeed", SeedFn.self)
        else { return nil }
        let api = API(
            connection: c, register: r, setRegistered: s, seed: seed,
            remove: load("SLSRemoveRegisteredCursor", RemoveFn.self),
            setSystem: load("SLSSetSystemDefinedCursor", SetSystemFn.self),
            dock: load("SLSSetDockCursorOverride", DockFn.self),
            setProperty: load("SLSSetConnectionProperty", SetPropFn.self))
        return SkyLightCursorHider(api: api)
    }

    func setHidden(_ hide: Bool) {
        guard hide != isHidden else { return }
        if hide { self.hide() } else { show() }
    }

    private func hide() {
        let cid = api.connection()
        _ = api.setProperty?(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        let size = CGSize(width: 16, height: 16)
        guard
            let ctx = CGContext(
                data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let blank = ctx.makeImage()
        else { return }
        var seed = 0
        let err = Self.cursorName.withCString {
            api.register(
                cid, $0, true, true, 1, [blank] as CFArray, size, .zero, &seed,
                CGRect(origin: .zero, size: size), 0, 0)
        }
        log("hide system cursor: register=\(err)")
        guard err == 0 else { return }
        _ = api.dock?(cid, true)  // keep it hidden over the Dock too
        let w = Watcher(api: api, cid: cid)
        watcher = w
        w.apply()
        let t = Thread { w.run() }
        t.qualityOfService = .userInteractive
        t.start()
        // Re-apply right away on pointer activity, without waiting for the next poll.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
            .leftMouseDown, .leftMouseUp,
        ]) { _ in w.apply() }
    }

    private func show() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        guard let w = watcher else { return }
        w.stop()
        watcher = nil
        let cid = api.connection()
        _ = api.dock?(cid, false)
        _ = Self.cursorName.withCString { api.remove?(cid, $0, true) }
        _ = api.setSystem?(cid, 0)  // back to the arrow
        log("show system cursor")
    }

    /// Re-applies the blank cursor whenever the window server changes it.
    private final class Watcher: @unchecked Sendable {
        private let api: API
        private let cid: Int32
        private let lock = NSLock()
        private var running = true
        private var lastSeed: Int32

        init(api: API, cid: Int32) {
            self.api = api
            self.cid = cid
            lastSeed = api.seed()
        }

        func apply() {
            lock.lock()
            defer { lock.unlock() }
            guard running else { return }
            var seed = 0
            _ = SkyLightCursorHider.cursorName.withCString { api.setRegistered(cid, $0, &seed) }
            lastSeed = api.seed()
        }

        func stop() {
            lock.lock()
            running = false
            lock.unlock()
        }

        /// Polls fast right after a change (pointer moving), slower when idle. Pointer
        /// events also re-apply right away (see `hide()`), so the idle poll only catches
        /// changes without movement, such as switching apps from the keyboard.
        func run() {
            var quiet = 0
            while true {
                lock.lock()
                let alive = running
                let changed = api.seed() != lastSeed
                lock.unlock()
                guard alive else { return }
                if changed {
                    apply()
                    quiet = 0
                } else {
                    quiet = min(quiet + 1, 601)
                }
                usleep(quiet > 600 ? 16_000 : 400)
            }
        }
    }
}

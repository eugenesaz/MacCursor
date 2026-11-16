import AppKit
import MacCursorCore
import MacCursorRender

// `MacCursor --render <dir>` renders every skin × palette × state to PNGs (no permissions needed).
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--render"), i + 1 < args.count {
    SnapshotRenderer.run(directory: args[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// Restore the system cursor on Ctrl-C / kill during development.
for sig in [SIGINT, SIGTERM] {
    signal(sig) { _ in
        CGDisplayShowCursor(CGMainDisplayID())
        exit(0)
    }
}

app.run()

import AppKit
import MacCursorCore
import MacCursorRender

// Command-line tools (`--validate`, `--render`, …) run and exit without starting the app.
if let status = Tools.run(CommandLine.arguments) { exit(status) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)

// Bring the arrow back when stopped by Ctrl-C, `kill` or a closed terminal. The handlers run
// on the main queue (not in signal context), so they can call AppKit safely.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM, SIGHUP] {
    signal(sig, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    source.setEventHandler {
        cursorHider.setHidden(false)
        exit(0)
    }
    source.resume()
    signalSources.append(source)
}

app.run()

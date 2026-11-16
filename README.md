<img src="assets/icon.svg" width="64" height="64" alt="">

# MacCursor

A free, open-source macOS menu bar app that makes your cursor impossible to miss on calls, screen shares and recordings. Your pointer becomes a **dog paw** (or a cat paw, a pointing finger or a highlight ring) that reaches in from the edge of the screen and *boops* every click.

> **Status: early development (pre-0.1).** See [IDEA.md](IDEA.md) for the product plan.

## Features

- Click-through overlay on every display. Clicking, dragging, scrolling and selecting work as normal.
- Styles: **Dog paw**, **Cat paw**, **Pointing finger**, **Highlight ring** (original art, drawn in code)
- **Size** slider in the menu (0.4× to 1.6×, applied live)
- **Light / Dark / Auto** colors. Auto follows the system appearance: a dark outline on light screens, a light "sticker" outline on dark screens.
- Hides the real system cursor, so you never see two pointers (optional; the ring keeps the arrow inside it). Uses a private macOS API, see below.
- Follows the cursor at your display's refresh rate (up to 120 Hz), and uses almost no CPU when the mouse is still.
- Shows up in full-screen shares and recordings.
- Click feedback: a ripple and a paw-print stamp. Fast clicking adds bones (dog), hearts (cat) or dots. Moods: Subtle / Normal / Wild. Click sound (toggle).
- **Presentation mode** (prototype): clicks animate but never reach apps, and the keyboard keeps working.
- Hotkeys: `⌃⌥P` toggles the pointer, `⌃⌥T` toggles presentation mode.

## Requirements

macOS 26 or later.

## Build & run

Needs the Xcode Command Line Tools (`xcode-select --install`).

```sh
./scripts/check.sh                  # format lint, build, all tests
./scripts/bundle.sh                 # → build/MacCursor.app (ad-hoc signed)
open build/MacCursor.app            # paw icon appears in the menu bar
```

Render every style, palette and size to PNGs (no permissions needed):

```sh
build/MacCursor.app/Contents/MacOS/MacCursor --render build/snapshots
```

The scripts use bash and apply a workaround for a known broken Command Line Tools install (`scripts/swift-env.sh`); on a healthy install it does nothing.

### Permissions
- **None** for the pointer and click effects.
- **Accessibility** only for presentation mode, which blocks clicks. Each local rebuild changes the ad-hoc signature, so you may need to remove the app from and re-add it to System Settings → Privacy & Security → Accessibility.

### About the private API
macOS doesn't let a background app hide the system cursor. MacCursor registers a blank cursor through the private SkyLight framework instead (technique credit: [Cursorlight](https://github.com/Zawalid/Cursorlight), MIT). If a future macOS removes it, MacCursor keeps working and the arrow simply stays visible. You can also turn it off: **Hide system cursor** in the menu.

## Project layout

| Path | What |
|---|---|
| `Sources/MacCursorCore/` | Pure logic, fully unit-tested: settings, display geometry, cursor policy |
| `Sources/MacCursorRender/` | Pointer art (paths, palettes), the pointer layers and click effects, the snapshot renderer |
| `Sources/MacCursorApp/` | The menu bar app: overlay windows, tracking, cursor hiding, hotkeys, presentation mode |
| `Tests/` | swift-testing unit tests and snapshot tests (reference PNGs in `Tests/MacCursorRenderTests/Snapshots/`) |
| `docs/manual-test.md` | What to check by hand before merging and releasing |

## License

TBD (MIT planned).

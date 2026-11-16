<img src="assets/icon.svg" width="64" height="64" alt="">

# MacCursor

A free, open-source macOS menu bar app that makes your cursor impossible to miss on calls, screen shares and recordings. Your pointer becomes a **dog paw** (or cat paw, or highlight ring) that reaches in from the edge of the screen and *boops* every click.

> **Status: proof of concept.** See [IDEA.md](IDEA.md) for the product plan.

## Features (POC)

- Click-through overlay on every display. Clicking, dragging and selecting work as normal.
- Styles: **Dog paw**, **Cat paw**, **Highlight ring** (original art, drawn in code)
- Click feedback: a ripple and a paw-print stamp. Fast clicking adds bones (dog), hearts (cat) or dots (ring).
- Moods: Subtle / Normal / Wild
- **Light / Dark / Auto** colors. Auto follows the system appearance: a dark outline on light screens, a light "sticker" outline on dark screens.
- Hides the real system cursor (optional; uses a private API)
- **Presentation mode**: clicks animate but never reach apps, and the keyboard keeps working
- Click sound (toggle)
- Hotkeys: `⌃⌥P` toggles the pointer, `⌃⌥T` toggles presentation mode

## Build & run

Needs macOS 14+ and the Xcode Command Line Tools (`xcode-select --install`).

```sh
./scripts/bundle.sh                 # → build/MacCursor.app (ad-hoc signed)
open build/MacCursor.app            # paw icon appears in the menu bar
```

Render all skins to PNGs (no permissions needed):

```sh
build/MacCursor.app/Contents/MacOS/MacCursor --render build/snapshots
```

### Permissions
- **None** for the pointer and click effects.
- **Accessibility** only for presentation mode, which blocks clicks. Each rebuild changes the ad-hoc signature, so you may need to remove the app from and re-add it to System Settings → Privacy & Security → Accessibility.

## Project layout

| File | What |
|---|---|
| `Sources/MacCursor/Skins.swift` | Pointer art (paths, colors) and light/dark palettes |
| `Sources/MacCursor/PointerRig.swift` | Pointer layers (leg + paw) and click effects |
| `Sources/MacCursor/OverlayController.swift` | Per-display overlay windows, 120 Hz tracking, click handling |
| `Sources/MacCursor/System.swift` | Cursor hiding, hotkeys, presentation-mode event tap |
| `Sources/MacCursor/AppDelegate.swift` | Menu bar menu |

## License

TBD (MIT planned).

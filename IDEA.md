# MacCursor: Product Idea

> Inspired by [Pokey](https://pokeyapp.com/), analyzed on 2026-11-15. This is a plan for our **own free, open-source** app in the same category. It is not commercial. It needs its own name, art, sounds and copy. We don't reuse Pokey's hand graphic, branding or text.

## 1. What the reference product is

Pokey is a **cursor highlighter for macOS**, used in presentations, screen shares and video calls. It replaces the normal pointer with an animated hand that "pokes" on every click, so viewers on Zoom, Meet, Loom or OBS can follow what the presenter is doing.

| Aspect | Pokey |
|---|---|
| Platform | macOS 26+, outside the App Store, Developer ID signed and notarized |
| Price | $4.99 one-time, no trial, no subscription, free updates |
| Refunds | 14-day money-back. Creators get a refund for posting a reel about the app |
| Checkout / licensing | Polar (license key shown on the confirmation page and sent by email) |
| Audience | Presenters, sales, educators, content creators, anyone on calls |
| Hook | "Forget boring cursor highlighters." It sells personality, not just utility |

### Feature list
1. **Click-through overlay pointer.** Only the look changes. Clicks, drags and selection still work in every app.
2. **Five intensity "moods"**, from a subtle highlight to an over-the-top pointer. Faster clicking makes the poke wilder.
3. **Menu bar app** with an on/off toggle.
4. **Global hotkey** to toggle it on and off.
5. **Presentation Mode.** Clicks only animate the pointer and never reach the app underneath, so slides don't advance and links don't open. The keyboard keeps working. `⌃⌥T` exits.
6. **Tap sound** (a "knock") on each click, with a toggle and volume slider. Calls pick it up through the "share system audio" option.
7. **Shows up in screen capture** when the whole screen is shared. It does not show up in single-window shares.
8. **Multi-display support** with no setup.

### Captured cursor examples (reference only, don't ship these)
Captured from the site's demo video (`raw/pokey-demo.mp4`, 93 s, 1470×956) and its inline SVG. Everything is in [`research/pokey/`](research/pokey/).

**Pointer anatomy.** A white cartoon glove with a pointing index finger, a black outline and a ribbed cuff, on a long black "arm/stick". The stick runs off the bottom edge of the screen and fades out. Its angle leans about 15 to 25° and changes as the pointer moves, as if pivoting from a point below the screen. The fingertip is the hotspot. The site's own SVG is `viewBox 0 0 159 470` with a gradient on the arm.

![hero pointer](research/pokey/examples/pointer-hero.png)

**Pointer variants** (picked from the menu). Left to right: *Tiny hand* (index finger, thumb out), *Cat paw* (black-and-white paw with a claw), *Middle child* (a cheeky finger gesture).

![variants](research/pokey/examples/variants-sheet.png)

**Click effects.** Left to right: idle, light click (comic "impact lines" burst around the fingertip), harder or faster click (big outlined comic **starburst**). The hand also squashes or jabs forward on a tap.

![clicks](research/pokey/examples/clicks-sheet.png)

**Menu bar menu**, read directly off the video:
```
Hide pointer          ⌃⌥P
Presentation mode     ⌃⌥T
──────────
Pointer mood   [slider: "Shy finger" … "In your face"]   (5 stops)
  Tiny hand / Cat paw / Middle child      (pointer style, radio)
Color ▸
✓ Animate on click
──────────
Poke the developer…    (feedback)
Check for Updates…     (Sparkle)
Quit
```
![menu](research/pokey/examples/menu-moods-full.png)

Other captures:
- `video-sheets/sheet_{0,30,60}.png`: 1 fps contact sheets of the whole demo
- `hires/`: full-resolution key frames
- `raw/`: page HTML, slide images, original SVGs

**Takeaways for our design:**
- The "hand on a stick from offscreen" look is the signature. It shows up from far away, even in a small Zoom tile. We should find our **own** equally loud silhouette (for example a laser-pointer beam from a screen edge, a magic wand or a foam finger) rather than copying the glove.
- The mood slider sets size, animation strength and effect type on one scale.
- Picking a pointer style is a cheap, fun feature that people share. Color is a submenu.
- Presentation Mode shows a toast/HUD when turned on ("… is in presentation mode now", with the exit keys) and a small "Presentation mode off" pill when it turns off.

### Light vs dark appearance (Pokey's "Color" submenu)
Pokey handles dark UIs with a **manual** `Color ▸ Dark / Light` submenu. It does **not** switch on its own.

![color submenu](research/pokey/examples/color-light-vs-dark.png)

*Top row: the **Light** setting on a dark Figma canvas. Bottom row: the default **Dark** setting on light or colored backgrounds. Left to right: idle, light click, hard click.*

| Element | Dark setting (for light UIs) | Light setting (for dark UIs) |
|---|---|---|
| Glove | White fill, black outline | **Unchanged**: white fill, black outline. It reads on both |
| Arm / stick | Solid black, fading to transparent at the screen edge | **Light grey** (about 60% white), same fade |
| Light click (impact lines) | Black strokes | Light-grey strokes |
| Hard click (starburst) | Black outline, transparent fill | Grey fragmented shards (no crisp outline) |

![submenu](research/pokey/examples/color-submenu.png)

**What we'll do better:**
- **Auto** mode as the default. Follow the system appearance (`effectiveAppearance`) at minimum. As an opt-in extra, sample the luminance under the cursor so the pointer flips when it moves from a dark editor to a light browser.
- Every skin ships **two palettes** (light-ui and dark-ui) in `skin.json`, and the click effects follow the same palette.
- Keep a contrasting outline on the hand/paw in both modes (Pokey's trick). The outline is what keeps it readable anywhere.

### Our pointer styles (planned)
| Style | Notes |
|---|---|
| Pointing finger | Our own take on the classic hand. Not the Pokey glove |
| Cat paw | Toe beans and a claw on a hard click |
| **Dog paw** 🐶 | A rounder, fluffier paw with big pads. A hard click could do a "boop" squash plus a tiny bark sound option |
| Middle-finger joke style (optional) | Behind a "cheeky" toggle |
| Foam finger, magic wand, laser beam | Later skins and community contributions |

### Known limitations they call out
- Single-window shares don't show the overlay.
- Multiplayer tools (Figma, Miro, Canva) show their own cursors to collaborators.
- Corporate MDM may block installing apps from outside the App Store.

## 2. Our product concept

**One sentence:** a small, delightful menu bar app that makes your cursor and clicks impossible to miss on a call, and a little fun.

**Core value:** viewers always know where you're pointing and when you click, and presenters get a light moment of personality.

### MVP (v1.0), at parity with the reference
- [ ] Transparent click-through overlay that follows the cursor on all displays
- [ ] Our own pointer art in several styles (see "Our pointer styles" below), plus a click animation
- [ ] **Light / Dark / Auto** pointer color so it reads on both light and dark UIs (see section 2b)
- [ ] Intensity levels (3 to 5) and click-rate-driven "excitement"
- [ ] Click sound with on/off and volume
- [ ] Menu bar UI with toggle, mode, sound and preferences
- [ ] Global hotkey toggle
- [ ] Presentation Mode that swallows mouse clicks and keeps the keyboard working, with an escape hotkey
- [ ] Onboarding for permissions (Accessibility), with clear instructions
- [ ] Update channel (Sparkle with GitHub Releases)

### Differentiators (v1.x ideas)
- **Free and open source**: everything included, and anyone can contribute pointer styles.
- **Community skins / pointer packs** (a simple folder format with SVG plus a JSON manifest, contributed by PR; also user-uploaded PNG/GIF)
- **Click ripple + keystroke overlay** (show `⌘C`, `⌘Tab` on screen; popular with tutorial makers)
- **Spotlight / dim-the-rest mode** and a **zoom lens** around the cursor
- **Annotate mode**: draw on screen temporarily, with strokes that fade after N seconds
- **Auto-enable** when Zoom, Meet, Keynote or OBS starts sharing or recording
- **Hide when idle**, and **"left vs right click" colors**
- **Custom sounds**, or **haptic-style screen shake** at the highest intensity

## 3. Technical approach (macOS, Swift)

**Stack:** Swift 6, SwiftUI for settings and the `MenuBarExtra`, AppKit and Core Animation for the overlay. Target is macOS 26.

| Concern | Implementation |
|---|---|
| Overlay | One borderless `NSPanel` per `NSScreen`, `backgroundColor = .clear`, `ignoresMouseEvents = true`, level ≥ `.screenSaver`, `collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]` |
| Cursor tracking | `NSEvent.addGlobalMonitorForEvents` for `.mouseMoved`, `.leftMouseDown/Up`, `.leftMouseDragged` and right-click, plus a local monitor. Use `CADisplayLink` / `NSEvent.mouseLocation` for smooth 120 Hz position updates |
| Hiding the real cursor | Hard part: `CGDisplayHideCursor` only works for the frontmost app. Options: (a) don't hide it and draw the art so it encloses the system arrow, (b) the private CGS "SetsCursorInBackground" trick (risky across OS updates). **Spike this first.** |
| Presentation Mode | A `CGEventTap` at `kCGSessionEventTap` (not listen-only) that drops mouse down/up events and passes keyboard events through. Needs the **Accessibility** permission. Always provide an escape hotkey and a watchdog |
| Animation | Core Animation layers (or SpriteKit for particle effects). Intensity = f(mode, clicks per second over a rolling window) |
| Sound | `AVAudioPlayer` / `AVAudioEngine` with preloaded short samples. Plays through system output, so calls capture it with "share system audio" |
| Hotkeys | Carbon `RegisterEventHotKey` (needs no permission), or the `KeyboardShortcuts` package for user-configurable shortcuts |
| Multi-display | Rebuild the overlay windows on `NSApplication.didChangeScreenParametersNotification` and handle mixed Retina scales |
| Screen capture | The overlay is a normal window (`sharingType = .readOnly`), so full-screen shares and recordings include it |
| Launch at login | `SMAppService.mainApp` |
| Distribution | GitHub Releases (DMG/zip) + a **Homebrew cask**, **Sparkle** appcast for updates. Notarization needs a $99/yr Apple Developer account. Without it, users must right-click → Open (or run `xattr -d com.apple.quarantine`), and the README should say so |
| Appearance | Pointer color modes Light / Dark / Auto: read `NSApp.effectiveAppearance`, or sample screen luminance under the cursor with ScreenCaptureKit (needs Screen Recording permission, so it should be opt-in) |

### Permissions
- **None** needed for the basic overlay and click animation (global mouse monitors work without Accessibility).
- **Accessibility** needed only for Presentation Mode (blocking clicks) and any future keystroke overlay.

### Main risks
1. Hiding the system cursor from a background app (see above).
2. Event taps being disabled by the system on timeout, so they must re-enable themselves.
3. Overlay latency or jitter. It has to feel like it's glued to the cursor.
4. Window-level quirks with full-screen apps, Stage Manager and Mission Control.

## 4. Open-source plan
- **License:** MIT (or Apache-2.0). All pointer art and sounds must be original or CC0 so the repo stays clean. **Don't include any Pokey assets.** The `research/` captures are local reference only and stay out of the public repo (add them to `.gitignore`).
- **Repo layout:** `App/` (Swift), `Skins/<name>/` (SVG + `skin.json`: hotspot, arm, light/dark colors, click effects), `Sounds/`, `docs/`.
- **Contributions:** new skins are the easy first PR (dog paw, cat paw, foam finger, …). Use a CONTRIBUTING guide with an art spec (canvas size, hotspot, outline width, light/dark variants).
- **CI:** GitHub Actions on `macos-latest` to build, run tests, and on a tag publish a signed release plus the Sparkle appcast.
- **Promotion:** README GIFs of each skin in light and dark mode, Show HN or r/macapps, a Homebrew cask.

## 5. Suggested build order
1. **Spike:** overlay that follows the cursor on all screens, plus an attempt at hiding the system cursor.
2. Click animation + sound + intensity modes.
3. Menu bar UI, settings, hotkey, launch at login.
4. Presentation Mode (event tap + permission onboarding).
5. Art/brand pass (our own pointer designs and sounds).
6. Open-source release: README with GIFs, LICENSE, CONTRIBUTING (skin spec), CI, Homebrew cask, Sparkle.

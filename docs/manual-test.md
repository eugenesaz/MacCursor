# Manual test list

Things automated tests can't check. Run the rows that a change touches before merging it,
and all of them before a release. Build with `./scripts/bundle.sh` and run
`open build/MacCursor.app`. Each row says what to do and what you should see.

## Cursor hiding
Style: Dog paw, with "Hide system cursor" on.

| # | Do | Expect |
|---|---|---|
| H1 | Move the pointer over a few apps (Finder, Safari, Terminal) and the desktop | Only the paw shows, never the arrow |
| H2 | Move over the Dock and the menu bar, and open a menu | No arrow |
| H3 | Drag a file, and select text by dragging | No arrow while dragging |
| H4 | ⌘Tab to another app, then switch Spaces (⌃→) | No arrow after the switch |
| H5 | Hover a text field and a window edge | No I-beam or resize arrow either (V1 limitation) |
| H6 | Turn off "Hide system cursor" in the menu | The arrow shows again under the paw |
| H7 | Pick "Highlight ring" | The arrow shows inside the ring |
| H8 | ⌃⌥P to turn the pointer off | The arrow comes back |
| H9 | Quit from the menu | The arrow comes back |
| H10 | Run `build/MacCursor.app/Contents/MacOS/MacCursor` in Terminal, then press Ctrl-C | The arrow comes back |
| H11 | Start it again and run `killall -TERM MacCursor`, then `killall -HUP MacCursor` | The arrow comes back each time |
| H12 | Start it again and run `killall -KILL MacCursor` (a crash) | The arrow comes back within a second, since the window server drops our cursor with our connection. If it doesn't, file a bug |
| H13 | Open MacCursor's own menu, hold still for 2 s, then move between items | The paw follows inside the menu (it never freezes) |
| H14 | Lock the screen (⌃⌘Q), then unlock | The lock screen shows the normal arrow; after unlocking the paw is back and the arrow hidden again |
| H15 | Switch to another user (fast user switching) and back | Same as H14 |

## Displays
Needs a second display.

| # | Do | Expect |
|---|---|---|
| D1 | Move the pointer slowly across the border between displays, in both directions | The paw jumps across with no gap and never shows twice |
| D2 | Click at each corner of each display | The click lands exactly under the paw's tip |
| D3 | Unplug the second display, then plug it back in | Within a second the paw works on both; no leftover windows (check Mission Control) |
| D4 | Change one display's resolution or arrangement in System Settings | The paw stays on the cursor afterwards |
| D5 | Mix a Retina and a non-Retina display | The paw is crisp on both |
| D6 | Open a full-screen app on one display, and Mission Control | The paw stays visible above both |

## Tracking and CPU

| # | Do | Expect |
|---|---|---|
| T1 | Swing the mouse fast in circles on a 120 Hz (ProMotion) display | The paw stays glued to the cursor, with no visible trailing |
| T2 | Record the screen at 120 fps (QuickTime) while moving fast and step through frames | The paw tip is within one frame of the click point |
| T3 | Leave the mouse still for 10 s; Activity Monitor → CPU for MacCursor | Under 1% (measured about 0.1% on an M-series Mac, 2026-11-15) |
| T4 | Keep moving the mouse; check CPU | Under 10% of one core |
| T5 | Click fast for a few seconds | Click effects animate smoothly, and the paw doesn't freeze after you stop |
| T6 | Leave it still for a minute, then move | The paw follows immediately (no wake-up delay) |

## Look: size, color, styles

| # | Do | Expect |
|---|---|---|
| L1 | First launch (run `defaults delete io.github.eugenesaz.maccursor` first) | The paw is clearly smaller than the old proof of concept (0.75×) |
| L2 | Drag the Size slider in the menu from end to end | The paw resizes live, from small to large, with no flicker |
| L3 | Quit and relaunch | The size is kept |
| L4 | Color: Auto. Switch System Settings → Appearance between Light and Dark | The paw's outline flips (dark on light, light on dark) within a second |
| L5 | Color: Dark, then Light, with either system appearance | The outline stays dark, or light, as picked |
| L6 | Try each style on a light page and on a dark editor | Each one reads clearly on both |
| L7 | Drag the Tail slider in the menu from end to end, with a paw and with the hand | The tail shortens and grows live with no flicker; far left shows just the paw or hand with a closed outline; far right matches the full length |
| L8 | Set a short tail, quit and relaunch | The tail length is kept |
| L9 | Set a short tail, switch to Highlight ring, then back to a paw | The ring has no tail; the paw comes back with the same short tail |

To review the art without running the app: `build/MacCursor.app/Contents/MacOS/MacCursor --render build/snapshots`
writes every style × palette × size, plus each paw and the hand with no tail and a short
tail, as a PNG (the same images the snapshot tests compare).

## Click sound
Start from defaults (`defaults delete io.github.eugenesaz.maccursor`), or note your old settings.

| # | Do | Expect |
|---|---|---|
| C1 | Click a few times with the default settings | A soft "tap", clearly quieter than the old Pop |
| C2 | Click sound ▸ drag the Volume slider from end to end | A preview plays as you drag, getting louder to the right; far left is silent |
| C3 | Pick each of Tap, Tick, Knock, Boop and Pop | Each plays once when picked, then on every click; all sound about equally loud |
| C4 | Click 10 times as fast as you can | The clicks get softer and never stack into a rattle |
| C5 | Turn off "Quieter when clicking fast", repeat C4 | Every click is the same level, still no pile-up |
| C6 | Mood: Subtle, then Wild, with "Follow mood" on | Subtle is softer and lower, Wild is brighter but not louder |
| C7 | Turn off "Play click sound", click; then pick a sound | Clicks are silent; picking a sound still plays a preview |
| C8 | Change several sound settings, quit and relaunch | All of them are kept |
| C9 | Plug in or unplug headphones (or switch output in Control Center), then click | The sound plays on the new output |
| C10 | Click, then leave the mouse still for 10 s; check CPU (Activity Monitor) | Under 1%, as T3 (the audio engine pauses after 5 s) |
| C11 | Turn the pointer off (⌃⌥P) and click | No sound |
| C12 | Share the screen with "share system audio" (Zoom/Meet) and click | The viewer hears the click |

## Screen sharing

| # | Do | Expect |
|---|---|---|
| S1 | Share your entire screen in Zoom or Google Meet; watch from another device | The viewer sees the paw and its click effects |
| S2 | Record the screen with QuickTime or ⌘⇧5 | The recording shows the paw |
| S3 | Share only one window | The paw doesn't show (macOS limitation, expected) |

## Spec success criteria → where they're checked (`SPEC-pointer.md`)

| # | Criterion | Checked by |
|---|---|---|
| 1 | check.sh passes | `./scripts/check.sh` |
| 2 | Arrow never visible; back on toggle-off and quit | H1–H15 |
| 3 | Tip within 1 pt of the click point | `DisplayLayoutTests`, `BuiltinStyleTests`, D2 |
| 4 | No visible lag at 120 Hz | T1, T2 |
| 5 | Display changes rebuild within 1 s | D3, D4 |
| 6 | 4 styles × 2 palettes render | `SnapshotTests`, L6 |
| 7 | Size 0.4–1.6×, default 0.75×, kept | `PointerSettingsTests`, L1–L3 |
| 8 | Auto color switches within 1 s | `PointerSettingsTests`, L4 |
| 9 | CPU under 1% idle, 10% moving | T3, T4 |
| 10 | Visible in a full-screen share | S1, S2 |

Tail length (`SPEC-tail-length.md`, #15):

| # | Criterion | Checked by |
|---|---|---|
| 1 | check.sh passes; existing snapshots unchanged | `./scripts/check.sh` |
| 2 | Setting default, persistence, clamping, bad values | `PointerSettingsTests` |
| 3 | No-tail and short-tail art for each paw and the hand | `SnapshotTests` (`*-tail*.png`) |
| 4 | Live change, kept after relaunch, far left none, far right full | L7, L8 |
| 5 | Kept across a switch to the ring and back | L9 |
| 6 | No change in CPU | T3, T4 |

## Style packs (`SPEC-skins.md`, #9)

Use the rocket test pack (`Tests/MacCursorRenderTests/Fixtures/Packs/rocket`) and the template
(`docs/style-template`). `MC=build/MacCursor.app/Contents/MacOS/MacCursor`.

| # | Do | Expect |
|---|---|---|
| P1 | Update from v0.1.2 with each built-in style selected in turn | The same style is selected after the update, and looks the same |
| P2 | **Open Styles Folder** | Finder opens `~/Library/Application Support/MacCursor/Styles/` (created if missing) |
| P3 | Copy the rocket folder into it | **Rocket** appears in the Style menu after a separator within 2 s, without relaunching |
| P4 | Select Rocket; change `body.color` in its `style.json` and save | The pointer's colour changes within 2 s |
| P5 | Break it: delete a closing `}` and save | The pointer shows the dog paw; the menu shows **1 style couldn't load…**; clicking it lists the JSON problem, copyable |
| P6 | Fix it and save | Rocket comes back and is selected again, without picking it |
| P7 | Rocket selected: drag the Tail slider; click slowly, then fast | The flame shortens to nothing at the far left and flickers; every click fires 8 darts from the centre, pointing outward; fast clicks fire more |
| P8 | Delete the rocket folder | It leaves the menu; the pointer shows the dog paw |
| P9 | `$MC --pack docs/style-template`, download it again through Safari (so it's quarantined), **Import Style…** it | A preview with name, author, licence and version; **Import** selects it |
| P10 | Import the same file again | The dialog says **Replace "My style" 1.0.0 with My style 1.0.0?** |
| P11 | Import a `.maccursorstyle` that is really a renamed PNG; then one of the built-ins packed with `--pack --builtin` | A "couldn't import" alert listing the problem; a "can't import" alert about the built-in id. Nothing is written to the Styles folder |
| P12 | **Remove Style…**, pick the template's style | Its folder is in the Trash; the pointer goes back to the dog paw |
| P13 | With 3–4 user styles installed, watch Activity Monitor while idle and moving | CPU is the same as with only built-ins (T3, T4) |

Style packs (`SPEC-skins.md`, #9) criteria:

| # | Criterion | Checked by |
|---|---|---|
| 1 | check.sh passes; old snapshots unchanged, now from packs | `./scripts/check.sh`, `SnapshotTests` |
| 2 | Built-ins are packs that pass `--validate` | `check.sh` (style packs: validate), `BuiltinStyleTests` |
| 3 | Saved style kept after updating | `PointerSettingsTests.oldStyleIDsCarryOver`, P1 |
| 4 | New pack appears and edits redraw within 2 s | P3, P4 |
| 5 | Broken packs rejected with clear messages, no crash | `StylePackLoaderTests`, `SVGArtTests`, `StyleLibraryTests`, P5 |
| 6 | Every #9 engine feature | `EngineFeatureTests`, rocket snapshots, P7 |
| 7 | `--validate`, `--pack`, `--preview` | `check.sh` (style packs steps) |
| 8 | Loading off the main thread; CPU unchanged | `StyleStore.reload`, P13 |
| 8a | Import installs and selects after one confirmation; bad files write nothing | `PackArchiveTests`, `PackInstallTests`, P9–P11 |
| 8b | The guide alone gets a pack from template to file | Making the rocket fixture from `docs/making-a-style.md` |
| 9 | Docs let someone make a pack without reading code | `docs/making-a-style.md`, `docs/style-packs.md` |

## Updates

| # | Do | Expect |
|---|---|---|
| U1 | Local build: open the menu | **Version 0.1.0** and **Check for Updates…** above Quit; no update dialog appears by itself |
| U2 | Ad-hoc build (`CODESIGN_IDENTITY=- ./scripts/bundle.sh`) | Launches; pointer, cursor hiding and presentation mode work under the hardened runtime |
| U3 | End to end, before announcing a release (`SPEC-updates.md`): install vX.Y.Z from GitHub in `~/Applications`, publish vX.Y.Z+1, **Check for Updates…** | Shows the new notes, installs, relaunches as the new version; no second **Open Anyway**; Accessibility still granted; the arrow never stays hidden during the swap |
| U4 | With the older version installed again: `defaults write io.github.eugenesaz.maccursor SULastCheckTime -date "2020-01-01 00:00:00 +0000"`, relaunch | The update dialog appears by itself within a minute |

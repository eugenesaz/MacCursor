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
| H16 | Open a dialog that floats above apps (a password or permission prompt, e.g. **System Settings ▸ Users & Groups ▸ Add User**) and move over it | The paw shows on top of the dialog |
| H17 | Start the screen saver (hot corner, or `open -a ScreenSaverEngine`), then stop it | No paw over the screen saver; the paw is back afterwards |

## Displays
Needs a second display.

| # | Do | Expect |
|---|---|---|
| D0 | Without Accessibility granted, open the Draw menu and choose Allow Drawing…; grant it | System Settings opens; within 2 s drawing works, no relaunch |
| D1 | Hold ⌘ and drag in a circle, then let go | A smooth red line follows the pointer's tip, under the pointer; about 3 s after letting go it fades out |
| D1a | During D1, watch the pointer; let go and wait without moving | The pointer stays on the line's tip the whole time and doesn't jump back after release |
| D2 | Hold ⌘⌥ and drag, wait 10 s | The line stays |
| D3 | Hold ⌘ and right-click (also with ⌘⌥; and Draw ▸ Clear drawing) | Every line is gone, on every display; nothing underneath gets the right-click (no context menu), no click effect or sound |
| D3a | Right-click with ⌘⇧ or ⌃⌘ held, or with no keys | A normal right-click; lines stay |
| D3b | With Presentation mode on, ⌘ right-click | The drawing is cleared |
| D3c | Press ⌃⌥X | Nothing happens in MacCursor (the hotkey is gone) |
| D4 | While dragging with ⌘, press and release ⌥ | The line switches between fading and lasting at that point |
| D5 | Press ⌃⌥C a few times between lines; pick a color, Thick, and 10 s in the menu | Each new line uses the new color / thickness / fade time; existing lines keep theirs |
| D6 | Hold ⌘ or ⌘⌥ and move without clicking; use ⌘C, ⌘-Tab | Nothing is drawn |
| D7 | ⌘-drag over Finder icons, a browser link and a window title bar | Nothing is selected, opened or moved; no click effect or sound |
| D8 | Hold ⌘⇧ or ⌃⌘ and click | A normal click (not drawn, reaches the app) |
| D9 | During a ⌘-drag, let go of ⌘ but keep the button down, then release | The line ends; the release doesn't click anything |
| D10 | Draw over a Keynote/PowerPoint slide in play mode, with Presentation mode on and off | The slide doesn't advance; drawing works in both |
| D11 | Draw on the second display; start a line on one display and cross to the other | Works there; the crossing line is cut off at the edge |
| D12 | Turn off Draw ▸ Draw on screen and ⌘-click | A normal ⌘-click; existing lines were cleared |
| D13 | Change the draw settings, quit and relaunch | They are kept |
| D14 | Draw 20 lasting lines, then move the pointer around; leave the mouse still 10 s | Pointer motion stays smooth; CPU under 1% when still |
| D15 | Share the screen (Zoom/Meet) and record with QuickTime while drawing | Lines show in both |

## Presentation mode (#42)

| # | Do | Expect |
|---|---|---|
| T1 | Turn Presentation mode on from the menu | A notice near the bottom of the screen: on, and how to exit; it fades after about 3 s |
| T2 | With it on, click the menu bar icon and untick Presentation mode | The menu opens and works; a "Presentation mode off" notice shows; clicks reach apps again |
| T3 | With it on, open the menu | A greyed line under Presentation mode explains how to exit |
| T4 | With it on, press and hold a click still for 2 s anywhere | The mode turns off with the "off" notice; nothing underneath was clicked |
| T5 | With it on, hold a click and move more than a few points, or let go before 2 s | The mode stays on |
| T6 | With it on, press ⌃⌥T; then ⌃⌥P | ⌃⌥T turns it off with the notice; ⌃⌥P (pointer off) also ends it, with the notice |
| T7 | Turn it on during a full-screen Keynote slide show | The notice shows over the slides |

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

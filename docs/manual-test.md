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
| T3 | Leave the mouse still for 10 s; Activity Monitor → CPU for MacCursor | Under 1% (measured 0.05% on an M-series Mac, 2026-11-15) |
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

To review the art without running the app: `build/MacCursor.app/Contents/MacOS/MacCursor --render build/snapshots`
writes every style × palette × size as a PNG (the same images the snapshot tests compare).

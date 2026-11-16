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

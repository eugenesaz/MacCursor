# Changelog

Notes for each release, written for people using MacCursor. The newest version is at the top.
The section for a version is what the update dialog shows.

## [0.4.3] - 2026-11-16

- Easier to leave **Presentation mode**:
  - a notice on screen says it's on and how to turn it off, and another says when it's off;
  - press **⌃⌥T**, or **press and hold a click for 2 seconds** anywhere;
  - MacCursor's menu bar icon and menu keep working while it's on, so you can untick it there.

## [0.4.2] - 2026-11-16

- The pointer now moves with you while you draw. Before, it stayed where the line started.

## [0.4.1] - 2026-11-16

- Drawing now needs a click: hold **⌘** (fading line) or **⌘⌥** (lasting line) and **drag**.
  Just holding ⌘ and moving the mouse no longer leaves stray lines.
- The drag is kept from the app underneath, so nothing gets clicked, selected or moved. This
  uses the Accessibility permission (the same one Presentation mode uses); if it's missing,
  **Draw ▸ Allow Drawing in Accessibility Settings…** takes you there.

## [0.4.0] - 2026-11-16

- **Draw on screen** to point things out while presenting:
  - hold **⌘** and move the mouse to draw a line that fades away after a few seconds;
  - hold **⌘⌥** for a line that stays until you clear it with **⌃⌥X**.
  - Nothing underneath is clicked, and no extra permission is needed. Typing a shortcut or
    clicking while ⌘ is down doesn't draw, so ⌘C, ⌘-Tab and ⌘-click work as before.
- A new **Draw** menu: eight ink colors (**⌃⌥C** switches to the next), three thicknesses,
  how long fading lines stay (1–10 s), and an off switch.

## [0.3.2] - 2026-11-16

- MacCursor has an app icon in Finder, the Applications folder and the Dock.
- The menu bar icon is now an arrow pointer instead of a paw: highlighted when the pointer is
  on, plain when it's off, and a screen with a pointer in presentation mode.

## [0.3.1] - 2026-11-16

- Styles with a jet flame can make it as long as the paws' legs: add `"length": 560` to the
  jet in `style.json`.

## [0.3.0] - 2026-11-16

- The click sound is much quieter by default, and **Click sound** in the menu is now a submenu:
  - a **Volume** slider, with a preview as you drag;
  - five sounds: **Tap** (the new default), **Tick**, **Knock**, **Boop**, and the old **Pop**;
  - **Quieter when clicking fast:** quick clicks get softer and no longer pile up;
  - **Follow mood:** Subtle is softer and lower, Wild is brighter.

## [0.2.0] - 2026-11-16

- **Styles you can add yourself.** Choose **Import Style…** in the menu to add a style someone
  sent you as a `.maccursorstyle` file. You see a preview first, and **Remove Style…** takes it
  out again.
- **Make your own style** in any vector editor, with no coding: an SVG drawing and a short
  settings file. MacCursor shows your changes live each time you save. See "Making a style" in
  the docs.
- The built-in styles are now made the same way. They look exactly as before, and your chosen
  style is kept.

## [0.1.2] - 2026-11-16

- New **Tail** slider in the menu, under Size: shorten the paw's leg or the hand's sleeve, or
  slide it all the way left to show just the paw or hand. The highlight ring has no tail.

## [0.1.1] - 2026-11-16

- The cartoon hand is redrawn as a classic cartoon glove: a pointing finger, a broad thumb,
  knuckles on the right, stitch lines and a rolled cuff.
- The cartoon hand's sleeve now comes straight out of the middle of the cuff.

## [0.1.0] - 2026-11-16

- First release. Your pointer becomes a dog paw, cat paw, cartoon hand or highlight ring that's
  easy to follow on calls, screen shares and recordings.
- Hides the normal arrow, so you never see two pointers.
- Works on every display, follows the mouse at your display's refresh rate, and uses almost no
  CPU when the mouse is still.
- Size slider, and Light, Dark or Auto colors for light and dark screens.
- Updates itself: MacCursor checks once a day, or right away with **Check for Updates…**.

# Making a style

You can draw your own MacCursor pointer in any vector editor and share it as one file. No
coding needed. This guide goes from an empty template to a `.maccursorstyle` file you can send
to anyone. The exact format is in [Style pack format](style-packs.md).

## 1. Start from the template

1. In MacCursor's menu, choose **Manage Styles ▸ Open Styles Folder**. Finder opens
   `~/Library/Application Support/MacCursor/Styles/`.
2. Copy the [template folder](style-template) into it and rename the copy, e.g. `cool-cursor`.
   (On GitHub, download the repository as a zip, or get `style-template.maccursorstyle` from the
   latest release and import it with **Manage Styles ▸ Import Style…**: it then sits in the Styles folder as
   `com.example.my-style`.)
3. Open `style.json` in a text editor and change `id` (e.g. `com.yourname.cool-cursor`) and
   `name` (what the menu shows, e.g. `Cool cursor`).

The new style appears in the **Style** menu straight away. Pick it: from now on, every time you
save `art.svg` or `style.json`, the pointer updates within a second or two. If something's wrong,
the menu shows **1 style couldn't load…** with the reason.

## 2. Draw

Open `art.svg` in Figma, Inkscape, Illustrator, Affinity Designer or any editor that writes SVG.

**The canvas.** 1 unit = 1 point at 1× size; the menu's default size is 0.75×. The built-in
paws are about 50 points wide and 60 tall; anything up to about 100 × 100 works well. Keep
everything within 200 points of the tip.

**The tip.** The click lands on the **hotspot**: put it at the very top of your art, where a
fingertip or paw tip would touch, and write its position in `style.json` as `"hotspot": [x, y]`.
The template's is `[50, 10]`.

**Layers and ids.** MacCursor finds your art by element id. The template uses:

| id | What |
|---|---|
| `body` | The silhouette. MacCursor fills it with `body.color` and draws the outline around it. Make it one closed shape, or a group of overlapping shapes. |
| `spot` | A detail drawn on top. Add as many as you like (up to 8), each listed in `details`. |
| `stamp` | The print left where you click, drawn centred on the tip. |
| `star` | The particle that flies out when you click fast, centred on the tip, pointing up. |

Rename or add ids freely, as long as `style.json` uses the same names. Your editor's fills don't
matter: colours come from `style.json`, so you can use any fills that help you see.

**Hide the stamp and particle** while drawing: they sit on top of the tip. Hiding them in your
editor (`display="none"`) is fine; MacCursor still uses them.

**Rules that keep it looking right:**
- **Convert strokes to outlines.** MacCursor ignores strokes. Figma: *Outline stroke* (⌥⌘O).
  Inkscape: *Path › Stroke to Path*. Illustrator: *Object › Path › Outline Stroke*. Affinity:
  *Layer › Expand Stroke*.
- **No text, images or effects.** Convert text to paths; shadows, blurs, masks and gradients
  don't carry over.
- **Leave about 3 points between separate parts** (like toes), so the outline between them shows.
- **Holes:** to cut a hole, set the element's fill rule to *even-odd* (`fill-rule="evenodd"`).

## 3. Export plain SVG

MacCursor reads a strict, safe subset of SVG. These settings keep your ids and avoid what it
can't read:

- **Figma:** name each layer with its id (`body`, `spot`…). Select the frame, *Export › SVG*,
  open the settings (…) and tick **Include "id" attribute**. Flatten boolean groups (⌘E).
- **Inkscape:** set ids in *Object › Object Properties* (⇧⌘O), then *File › Save a Copy… ›
  Plain SVG*.
- **Illustrator:** name the layers or objects with their ids. *File › Export › Export As… ›
  SVG*, then **Styling: Presentation Attributes** (not CSS), **Object IDs: Layer Names**,
  Decimal: 2 or more.
- **Affinity Designer:** name the layers with their ids, then *Export › SVG* and keep layer names
  as ids (the "flatten transforms" option is fine either way).

Not sure what your editor wrote? Open the SVG in a text editor and look for `id="body"`.

## 4. Fill in style.json

The template shows the common keys:

```json
{
  "format": 1,
  "id": "com.yourname.cool-cursor",
  "name": "Cool cursor",
  "author": "Your name",
  "license": "CC0-1.0",
  "version": "1.0.0",
  "art": "art.svg",
  "hotspot": [50, 10],
  "body": { "art": "body", "color": "#7E57C2" },
  "details": [{ "art": "spot", "color": "#FFFFFF" }],
  "tail": { "leg": { "width": 18, "join": [50, 64], "color": "#7E57C2" } },
  "click": {
    "stamp": { "art": "stamp", "offset": 0 },
    "particles": { "art": "star", "color": "#FFC107" }
  },
  "darkScreens": { "body": "#B39DDB", "leg": "#B39DDB" }
}
```

- **Tail:** a `leg` reaching in from off-screen (set `join` to the middle of the art's bottom
  edge), a `jet` flame (add `"length": 560` to make it as long as a leg), or leave `tail`
  out for none. The menu's Tail slider shortens it. A jet flickers; **Animate**, which the menu
  shows under the selected style, holds it still.
- **Click:** `stamp` and `particles` are optional. `"facing": "outward"` makes particles point
  the way they fly; `"origin": "center"` starts them at the click; `"minimum": 8` fires 8 on
  every click instead of only when clicking fast.
- **Dark screens:** MacCursor draws a dark outline on light screens and a light one on dark
  screens. If a colour of yours disappears against one of them, give it a `darkScreens` colour.
- **A ring around the arrow** instead of a replacement: `"overlay": true`, with
  `"outline": { "color": "#FFD23F", "width": 3 }`.

Every key is described in [Style pack format](style-packs.md).

## 5. Check it

Look at it at every size, on both backgrounds:

```sh
MC=/Applications/MacCursor.app/Contents/MacOS/MacCursor
$MC --validate cool-cursor
$MC --preview cool-cursor preview.png && open preview.png
```

(Run these in Terminal from the Styles folder: `cd ~/Library/Application\ Support/MacCursor/Styles`.)

Also try it for real: move fast, click fast, drag the Size and Tail sliders, switch the Color
menu between Light and Dark.

## 6. Share it

```sh
$MC --pack cool-cursor
```

This writes `com.yourname.cool-cursor.maccursorstyle`. Send it to anyone with MacCursor: they
choose **Manage Styles ▸ Import Style…** in the menu and pick the file. A newer version with the same `id`
replaces the old one (bump `version` so they can tell).

You can also make the file by hand: zip `style.json` and `art.svg` (Finder's *Compress* works)
and rename the `.zip` to `.maccursorstyle`.

Before sharing publicly, read the licence rules in [CONTRIBUTING](../CONTRIBUTING.md): only art
you made yourself, or art under CC0 or MIT, and no logos, trademarks or characters you don't own.

## Common problems

| Message | Fix |
|---|---|
| `element "body" not found (referenced by "body.art")` | The SVG has no element with that id. Check your editor's export kept ids (step 3). |
| `element <style> isn't allowed…` | Your editor wrote CSS. Export with presentation attributes instead (Illustrator: *Styling: Presentation Attributes*). |
| `element <text> isn't allowed…` | Convert text to outlines/paths. |
| `element <linearGradient> isn't supported…` | Gradients aren't supported; use flat colours. |
| `has a stroke, which is ignored` (warning) | Convert strokes to outlines, or that part is missing. |
| `reaches 260 pt from the hotspot` | Art is too far from the tip, often a stray point or a wrong `hotspot`. |
| `"hotspot" must be a pair of numbers [x, y]` | Write it as `[50, 10]`, not `"50,10"`. |
| `must not contain a DOCTYPE or ENTITY declaration` | Older "Save As SVG" options add one. Use the export settings in step 3, or delete the `<!DOCTYPE …>` line. |
| `isn't valid JSON` | A missing comma or quote in `style.json`. A JSON validator shows the line. |
| `"id" "dogPaw" is a built-in style's id` | Pick your own id. |
| The tip doesn't click where it looks | `hotspot` isn't on the tip. |
| Parts disappear on dark screens | Add `darkScreens` colours. |

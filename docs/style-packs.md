# Style pack format (format 1)

This is the exact reference for MacCursor's style packs. To make one step by step, start with
[Making a style](making-a-style.md).

A **style pack** describes one pointer style with two files:

```
my-style/                ← any folder name; the manifest's "id" is what counts
  style.json             ← the manifest
  art.svg                ← all the vector art (the name is set in the manifest)
```

Nothing else in the folder is read, so you can keep a README, a preview or your editor's source
file next to them.

To share a pack, turn the folder into one **`.maccursorstyle`** file with
`MacCursor --pack my-style` (see [Tools](#tools)). That file is a standard zip holding
`style.json` and the art file, at its root or inside one top-level folder. People add it with
**Import Style…** in MacCursor's menu.

## Coordinates

- Art is in SVG user units. **1 unit = 1 point** at size 1.0× (the menu's default size is 0.75×).
- SVG's y axis points down. Every position in `style.json` (`hotspot`, `join`) is in the same
  SVG coordinates as the art.
- The **hotspot** is the point that clicks. Put it at the very tip of the art. The tail and the
  click effects are placed relative to it, and the pointer leans around it as it moves.
- The `viewBox`, `width` and `height` of the SVG don't matter, only the units.
- All art must stay within 200 points of the hotspot.

## style.json

| Key | Type | Required | Meaning |
|---|---|---|---|
| `format` | number | yes | Always `1`. A higher number means the pack needs a newer MacCursor. |
| `id` | text | yes | Unique id: starts with a letter, then letters, digits, `.`, `_` or `-`; at most 64 characters. Reverse-DNS style is a good habit: `com.yourname.cool-cursor`. The built-in ids (`dogPaw`, `catPaw`, `finger`, `ring`) are taken. |
| `name` | text | yes | Shown in the Style menu. 1–40 characters. |
| `author` | text | yes | Your name or handle. |
| `license` | text | yes | An [SPDX id](https://spdx.org/licenses/) such as `CC0-1.0` or `MIT`, or `Proprietary`. See [CONTRIBUTING](../CONTRIBUTING.md) for what's allowed in public packs. |
| `version` | text | no | Shown when someone replaces an installed copy, e.g. `1.0.0`. |
| `art` | text | yes | The SVG file's name, e.g. `art.svg`. No folders. |
| `hotspot` | `[x, y]` | yes | The click point. |
| `body` | object | yes | `{ "art": "<id>", "color": "<colour>" }`: the silhouette. MacCursor fills it and draws the outline around it. |
| `details` | list | no | Up to 8 `{ "art", "color" }` layers drawn on top of the body, in order: pads, nails, eyes, shading, ink. |
| `outline` | text or object | no | `"palette"` (default): a thick outline that's dark on light screens and light on dark screens. Or `{ "color": "<colour>", "width": 0.5–8 }`: a plain stroke of one colour and no palette outline. |
| `overlay` | true/false | no | `true` draws the style *around* the system arrow, which stays visible (like the highlight ring). Clicks don't squash it. Default `false`: the style replaces the arrow. |
| `tail` | object | no | A leg or a jet flame; leave it out for none. The menu's **Tail** slider shortens it. See below. |
| `click` | object | no | Click effects. Left out: a ripple only. See below. |
| `darkScreens` | object | no | Colours to use on dark screens instead. See below. |

**Colours** are `"#RGB"`, `"#RRGGBB"` or `"#RRGGBBAA"` (the last two digits are opacity), in sRGB.

**Unknown keys** are ignored, with a warning from `--validate`. That way a pack made for a newer
MacCursor still works in an older one, without the new features.

### tail

Either a leg:

```json
"tail": { "leg": { "width": 24, "join": [60, 70], "color": "#E8C08A" } }
```

| Key | Meaning |
|---|---|
| `width` | 1–80 points. |
| `join` | Where the leg meets the art: the middle of its top edge. MacCursor starts the leg 12 points inside the art, so the art covers the join. |
| `color` | The leg's fill. It fades out over its length, and the outline runs down both sides. |

Or a jet flame:

```json
"tail": { "jet": { "flame": "flame", "core": "core", "color": "#FF7A1AE6", "coreColor": "#FFE08A", "join": [40, 52], "length": 560 } }
```

| Key | Meaning |
|---|---|
| `flame`, `core` | Art ids. Draw them in place, pointing down from `join`. The core is drawn over the flame. |
| `color`, `coreColor` | Their fills. |
| `join` | Where the flame attaches. It flickers lengthwise about this point, and the Tail slider shortens it toward this point while keeping its width. The jet is drawn behind the body, so let the flame start a little inside it. |
| `length` | Optional, 1–560 points: how far the flame reaches from `join` with the Tail slider at full. The flame and core are stretched lengthwise to fit, keeping their width, so a short drawing can reach off-screen like a leg (legs are 560 points). Left out: as drawn. |

### click

```json
"click": {
  "ripple": "effect",
  "stamp": { "art": "stamp", "offset": 26 },
  "particles": { "art": "particle", "color": "#FFF6E5", "outlined": true,
                 "facing": "spin", "origin": "ring", "minimum": 0 }
}
```

| Key | Meaning |
|---|---|
| `ripple` | `"effect"` (default): the palette's colour, dark on light screens and light on dark ones. Or a colour. |
| `stamp` | A print left where you click, fading out. `art`: draw it centred on the hotspot. `offset`: points from the tip along the tail, where it lands (−200 to 200, default 0). Leave `stamp` out for none. |
| `particles.art` | An art id, drawn centred on the hotspot with its "up" pointing up, or `"dot"` (a built-in 6-point dot). Default `"dot"`. |
| `particles.color` | Required. |
| `particles.outlined` | A palette outline behind each particle. Default `true`; `false` for `"dot"`. |
| `particles.facing` | `"spin"` (default): each particle tumbles. `"outward"`: each one points the way it flies and doesn't spin. |
| `particles.origin` | `"ring"` (default): particles start just outside the ripple. `"center"`: they start at the click point. |
| `particles.minimum` | 0–16 particles on every click. Fast clicking adds more. Default 0: particles only when clicking fast. |

### darkScreens

Colours for the light-on-dark palette, used when the Color menu (or Auto) picks it. Any key you
leave out keeps its normal colour.

```json
"darkScreens": {
  "body": "#C9D3DE", "details": ["#81D4FA", null], "outline": "#…",
  "leg": "#…", "jet": "#…", "jetCore": "#…", "ripple": "#…", "particles": "#…"
}
```

`details` lists colours in the same order as `details` above; `null` keeps that layer's colour.
`outline` only applies to an `outline` with a fixed colour.

## art.svg

Each `art` value in `style.json` names an element by its `id`. That element can be a shape, or a
group (`<g>`) whose shapes are combined into one.

Supported:
- `svg`, `g`, `path`, `rect` (with `rx`/`ry`), `circle`, `ellipse`, `polygon`, `polyline`.
- All path commands, absolute and relative: `M L H V C S Q T A Z`.
- `transform` on any element: `matrix`, `translate`, `scale`, `rotate`, `skewX`, `skewY`.
- `fill-rule="evenodd"` on the named element (as an attribute or in its `style`), to cut holes.

Skipped (fine to leave in): `title`, `desc`, `metadata`, anything inside `defs`, and your editor's
own elements in other namespaces (such as `sodipodi:` or `inkscape:`).

Ignored, with no effect on the pointer: fill and stroke colours (colours come from
`style.json`), stroke widths, `opacity`, `display` and `visibility`, `viewBox`. `clip-path`,
`mask`, `filter` and strokes are ignored with a warning: **convert strokes to outlines** in your
editor, or they'll be missing.

Not allowed (the pack is rejected): `image`, `use`, `text`, `style`, `script`,
`foreignObject`, links (`href`, `xlink:href`), event handlers (`onclick`…), a `DOCTYPE` or
`ENTITY`, gradients and other elements outside `defs`. A pack is pictures only: it can't load
other files or run anything.

## Limits

A pack is rejected, with a message for each problem, if:

- `style.json` is over 64 KB or the art file over 512 KB;
- the art uses more than 20,000 path segments, or reaches more than 200 points from the hotspot;
- an `art` id isn't in the SVG, or names an empty element;
- a value has the wrong type or is out of its range;
- (pack files) the file is over 2 MB, holds more than 32 entries, isn't a plain zip (encrypted,
  zip64, split), contains links or paths outside itself, or a file doesn't match its checksum.

MacCursor loads at most 100 styles from the Styles folder. If two packs share an `id`, the one in
the folder whose name sorts first wins.

## Where packs live

- Built-in: inside the app, `MacCursor.app/Contents/Resources/Styles/`.
- Yours: `~/Library/Application Support/MacCursor/Styles/`, one folder per pack. **Open Styles
  Folder** in the menu opens it. MacCursor watches it: adding, editing or removing a pack there
  shows up within a second or two.

## Tools

The app's binary has command-line tools that never open a window:

```sh
MC=/Applications/MacCursor.app/Contents/MacOS/MacCursor
$MC --validate my-style                 # or my-style.maccursorstyle; exits 1 if invalid
$MC --pack my-style                     # writes <id>.maccursorstyle (only if valid)
$MC --pack my-style -o cool.maccursorstyle
$MC --preview my-style preview.png      # three sizes and a click, light and dark
```

From a checkout of this repository, `scripts/style-pack.sh validate|pack|preview …` does the same.
`--pack` writes the same bytes for the same input.

## Example: the dog paw

[`Resources/Styles/dog-paw`](../Resources/Styles/dog-paw) is a complete pack: a body of five
ovals, pads and nails as details, a leg, a paw-print stamp and bone particles.

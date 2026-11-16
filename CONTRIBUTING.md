# Contributing to MacCursor

Thanks for helping! There are two kinds of contribution: **styles** (pointer art) and **code**.

## Styles

Anyone can make a style without writing code: see [Making a style](docs/making-a-style.md) and
the [format reference](docs/style-packs.md). Share the `.maccursorstyle` file however you like.

### Licence rules for public styles

A style shared publicly (posted online, offered for a gallery, or proposed for MacCursor itself)
must be art you have the right to share:

- **Your own original art**, or art you have permission to use, released under
  **CC0-1.0** or **MIT**. Put the SPDX id in `style.json`'s `license` and your name in `author`.
- Art by someone else **only if it's CC0-1.0 or MIT**, with its author credited in `author`.
- **No logos, trademarks, brand marks or characters you don't own**, even redrawn, and no art
  traced from someone else's work. A style that *looks like* a company's product mark is still
  their trademark.

A style you keep to yourself, or share privately with permission, can use any licence you choose,
including `Proprietary`. MacCursor loads it the same way.

### Art checklist

- [ ] `MacCursor --validate` passes with no warnings.
- [ ] The tip (hotspot) is where the click lands.
- [ ] It reads clearly at 0.4×, 0.75× and 1.6× on light and dark screens (`--preview`).
- [ ] Separate parts have about 3 points between them, so the outline reads.
- [ ] Your `id` is your own (e.g. `com.yourname.style-name`), and `version` is set.

## Code

1. Open an issue first (or find one) so we can agree on the change.
2. Build and test with `./scripts/check.sh` (format lint, build, unit and snapshot tests, pack
   validation). The [README](README.md#build-from-source) has the setup.
3. Keep pull requests small and reference the issue (`Closes #N`).
4. Snapshot references in `Tests/MacCursorRenderTests/Snapshots/` change only on purpose: update
   them with `UPDATE_SNAPSHOTS=1 ./scripts/swift-test.sh --filter Snapshot` and review the PNGs.

Built-in styles live in `Resources/Styles/` as ordinary packs; new built-ins follow the same
licence rules (MIT, original art).

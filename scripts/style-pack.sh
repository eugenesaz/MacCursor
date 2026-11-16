#!/usr/bin/env bash
# Runs MacCursor's style pack tools from a repo checkout, without building the app bundle.
#   scripts/style-pack.sh validate <pack folder or .maccursorstyle>…
#   scripts/style-pack.sh pack <pack folder> [-o <file>]
#   scripts/style-pack.sh preview <pack folder or .maccursorstyle> <out.png>
# In an installed app, call the binary directly instead, e.g.
#   /Applications/MacCursor.app/Contents/MacOS/MacCursor --validate my-style
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cmd="${1:-}"
[ -n "$cmd" ] || { sed -n '2,8p' "$0" >&2; exit 2; }
shift
# Paths are resolved before changing into the repo to build.
args=()
for a in "$@"; do
  if [ -e "$a" ] || [[ "$a" == *.png ]] || [[ "$a" == *.maccursorstyle ]]; then
    args+=("$(cd "$(dirname "$a")" && pwd)/$(basename "$a")")
  else
    args+=("$a")
  fi
done
cd "$ROOT"
# shellcheck source=swift-env.sh
source scripts/swift-env.sh
scripts/fetch-sparkle.sh >/dev/null
swift build -c release --product MacCursor >/dev/null
BIN="$(swift build -c release --show-bin-path)/MacCursor"
exec "$BIN" "--$cmd" "${args[@]+"${args[@]}"}"

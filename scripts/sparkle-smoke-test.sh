#!/usr/bin/env bash
# Checks scripts/sparkle-tool.swift end to end with a throwaway key. Used by check.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=swift-env.sh
source scripts/swift-env.sh
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
swiftc -O -o "$work/tool" scripts/sparkle-tool.swift 2>/dev/null || swiftc -O -o "$work/tool" scripts/sparkle-tool.swift

public="$("$work/tool" generate-key "$work/key")"
key="$(cat "$work/key/sparkle-private-key.txt")"
[ "$(SPARKLE_PRIVATE_KEY="$key" "$work/tool" public-key)" = "$public" ] || { echo "public-key mismatch" >&2; exit 1; }
if "$work/tool" generate-key "$work/key" 2>/dev/null; then echo "overwrote an existing key" >&2; exit 1; fi

printf 'zip bytes' > "$work/app.zip"
printf -- '- Fixed <things> & stuff\n  over two lines.\n- Second\n' > "$work/notes.md"
SPARKLE_PRIVATE_KEY="$key" "$work/tool" appcast 1.2.3 "$work/app.zip" \
  "https://example.com/a.zip?x=1&y=2" "$work/notes.md" "$public" > "$work/appcast.xml"
xmllint --noout "$work/appcast.xml"
grep -q 'sparkle:version>1.2.3<' "$work/appcast.xml"
grep -q 'length="9"' "$work/appcast.xml"
grep -q 'sparkle:edSignature="[A-Za-z0-9+/=]\{88\}"' "$work/appcast.xml"
grep -q '<li>Fixed &lt;things&gt; &amp; stuff over two lines.</li><li>Second</li>' "$work/appcast.xml"
grep -q 'url="https://example.com/a.zip?x=1&amp;y=2"' "$work/appcast.xml"

# A key that doesn't match the app's SUPublicEDKey must not produce a feed.
other="$("$work/tool" generate-key "$work/other")"
if SPARKLE_PRIVATE_KEY="$key" "$work/tool" appcast 1.2.3 "$work/app.zip" u "$work/notes.md" "$other" \
  >/dev/null 2>&1; then
  echo "appcast accepted a key that doesn't match the public key" >&2
  exit 1
fi
grep -q '<sparkle:minimumSystemVersion>26.0<' "$work/appcast.xml"

# The app's plist must point at this repo's releases and carry a valid 32-byte public key.
plist=Resources/Info.plist
feed="$(/usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$plist")"
[ "$feed" = "https://github.com/eugenesaz/MacCursor/releases/latest/download/appcast.xml" ] \
  || { echo "SUFeedURL is $feed" >&2; exit 1; }
pub="$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$plist")"
[ "$(printf '%s' "$pub" | base64 -d | wc -c | tr -d ' ')" = 32 ] \
  || { echo "SUPublicEDKey is not a 32-byte Ed25519 key" >&2; exit 1; }
echo "sparkle: appcast smoke test passed"

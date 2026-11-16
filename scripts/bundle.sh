#!/usr/bin/env bash
# Builds build/MacCursor.app from the Swift package and signs it.
# CODESIGN_IDENTITY overrides the signing identity; the default "-" means ad-hoc.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=swift-env.sh
source scripts/swift-env.sh

IDENTITY="${CODESIGN_IDENTITY:--}"
APP=build/MacCursor.app

swift build -c release --product MacCursor
BIN="$(swift build -c release --show-bin-path)/MacCursor"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$BIN" "$APP/Contents/MacOS/MacCursor"
codesign --force --sign "$IDENTITY" "$APP" >/dev/null
echo "Built $APP"

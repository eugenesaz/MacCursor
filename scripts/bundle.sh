#!/usr/bin/env bash
# Builds build/MacCursor.app (ad-hoc signed).
# Uses swiftc directly so it works with just the Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/MacCursor.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target "$(uname -m)-apple-macosx14.0" \
  -framework AppKit -framework Carbon \
  Sources/MacCursor/*.swift -o "$APP/Contents/MacOS/MacCursor"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --sign - "$APP" >/dev/null
echo "Built $APP"

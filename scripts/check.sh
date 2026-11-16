#!/usr/bin/env bash
# Every gate that must pass before a commit. Run from anywhere.
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=swift-env.sh
source scripts/swift-env.sh

step() { printf '\n==> %s\n' "$*"; }

step "sparkle: fetch";      scripts/fetch-sparkle.sh
step "swift: format lint"; swift format lint --strict -r Sources Tests Package.swift scripts/sparkle-tool.swift
step "swift: build";       swift build
step "swift: test";        scripts/swift-test.sh
step "style packs: validate"
BIN="$(swift build --show-bin-path)/MacCursor"
"$BIN" --validate --builtin Resources/Styles/*
"$BIN" --validate Tests/MacCursorRenderTests/Fixtures/Packs/rocket
if "$BIN" --validate Tests/MacCursorRenderTests/Fixtures/Packs/broken 2>/dev/null; then
  echo "the broken fixture pack passed validation" >&2; exit 1
fi
step "sparkle: appcast";    scripts/sparkle-smoke-test.sh

printf '\nAll checks passed.\n'

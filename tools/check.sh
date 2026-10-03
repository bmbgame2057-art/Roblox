#!/usr/bin/env bash
# Runs every check: format, lint, type check, tests, and rebuilds the place file.
# Requires rojo, lune, luau-lsp, selene and stylua on PATH, plus Roblox type definitions:
#   ROBLOX_TYPES=path/to/globalTypes.d.luau  (https://github.com/JohnnyMorganz/luau-lsp/blob/main/scripts/globalTypes.d.luau)
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== stylua"
stylua --check src tests

echo "== selene"
selene src

echo "== luau-lsp"
rojo sourcemap default.project.json -o sourcemap.json
if [[ -n "${ROBLOX_TYPES:-}" ]]; then
	output=$(luau-lsp analyze --sourcemap=sourcemap.json --definitions=@roblox="$ROBLOX_TYPES" --base-luaurc=.luaurc src/ 2>&1 | grep -v '^\[' || true)
	if [[ -n "$output" ]]; then
		echo "$output"
		exit 1
	fi
	echo "0 errors"
else
	echo "skipped (set ROBLOX_TYPES to the Roblox definitions file)"
fi

echo "== tests"
lune run tests/run.luau

echo "== place"
lune run tools/build-place.luau

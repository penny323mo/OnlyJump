#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
editor="${GODOT_BIN:-godot}"
mkdir -p build/web
touch build/.gdignore
"$editor" --headless --import
"$editor" --headless --export-release Web build/web/index.html
mkdir -p build/web/fonts
cp web/fonts/BarlowCondensed-ExtraBoldItalic.ttf web/fonts/OFL.txt build/web/fonts/
touch build/web/.nojekyll

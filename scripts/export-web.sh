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
cp web/controls.js web/credits.txt web/ledge-grab.mp4 build/web/
# Pages caches subresources independently of HTML. A new shell must load
# the matching input bridge and game pack even if Safari cached the old ones.
python3 - <<'PYTHON'
from hashlib import sha256
from pathlib import Path
out = Path('build/web')
page = out / 'index.html'
html = page.read_text()
for name in ('index.pck', 'controls.js'):
    source = out / name
    digest = sha256(source.read_bytes()).hexdigest()[:12]
    versioned = source.with_name(f'{source.stem}-{digest}{source.suffix}')
    source.replace(versioned)
    html = html.replace(name, versioned.name)
page.write_text(html)
PYTHON
touch build/web/.nojekyll

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
cp web/apple-touch-icon.png build/web/
cp web/controls.js web/credits.txt web/ledge-grab.mp4 web/duo-pull-up.mp4 web/girder-recovery.mp4 web/girder-traverse.mp4 web/awning-grapple.mp4 web/pendulum-clock.mp4 web/spirit-level.mp4 web/laundry-lift.mp4 web/tape-measure.mp4 web/toy-track.mp4 web/turntable.mp4 web/polytone.mp4 web/characters.webp web/slope-stance.webp web/landing-marks.webp build/web/
# Pages caches subresources independently of HTML. A new shell must load
# the matching input bridge and game pack even if Safari cached the old ones.
python3 - <<'PYTHON'
from hashlib import sha256
from pathlib import Path
out = Path('build/web')
page = out / 'index.html'
html = page.read_text()
# In the pinned 4.7.2 template a broken body can leave the reader or WASM
# compiler pending. Forward those rejections through the existing APIs.
loader = out / 'index.js'
js = loader.read_text()
for before, after in [
    # A single-use engine can consume the original stream. Cloning tees the
    # entire WASM download into a second buffer that our game never reads.
    ('new Response(response.clone().body,', 'new Response(me.config.unloadAfterInit ? response.body : response.clone().body,'),
    ('\n\t\t\t\tonloadprogress(reader, controller).then(', '\n\t\t\t\treturn onloadprogress(reader, controller).then('),
    ('getModuleConfig = function (loadPath, response)', 'getModuleConfig = function (loadPath, response, rejectInit)'),
    ('me.config.getModuleConfig(loadPath, cloned)', 'me.config.getModuleConfig(loadPath, cloned, reject)'),
    ('WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done)',
     'WebAssembly.instantiateStreaming(Promise.resolve(r), imports).then(done, rejectInit)'),
    ('r.arrayBuffer().then(function (buffer) {\n\t\t\t\t\t\tWebAssembly.instantiate(buffer, imports).then(done);\n\t\t\t\t\t});',
     'r.arrayBuffer().then(buffer => WebAssembly.instantiate(buffer, imports)).then(done, rejectInit);'),
]:
    if js.count(before) != 1:
        raise SystemExit('Recheck Godot download error handling for this template')
    js = js.replace(before, after)
loader.write_text(js)
for name in ('index.pck', 'index.js', 'controls.js', 'characters.webp'):
    source = out / name
    digest = sha256(source.read_bytes()).hexdigest()[:12]
    versioned = source.with_name(f'{source.stem}-{digest}{source.suffix}')
    source.replace(versioned)
    html = html.replace(name, versioned.name)
page.write_text(html)
PYTHON
touch build/web/.nojekyll

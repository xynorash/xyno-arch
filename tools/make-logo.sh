#!/usr/bin/env bash
# Regenerate the fastfetch logo from the transparent-background PNG.
#
#   tools/make-logo.sh [image.png]
#
# Writes the large logo (108x34, wide terminals) and a medium one (54x18, for
# the 130-179 column tier) into home/.config/xynorash/fastfetch/.
#
# Crops the image to its visible pixels, then converts it with chafa using
# half/quadrant block symbols in 24-bit colour: the mode that keeps thin
# strokes and the colour gradient legible (braille is too faint, pure ASCII
# punctuation too noisy). Writes home/.config/xynorash/fastfetch/xynorash.txt.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
src=${1:-$repo/tools/xynorash_logo_transparent.png}
outdir=$repo/home/.config/xynorash/fastfetch

command -v chafa >/dev/null || { echo "chafa is required (pacman -S chafa)" >&2; exit 1; }
python3 -c 'import PIL' 2>/dev/null || { echo "python-pillow is required (pacman -S python-pillow)" >&2; exit 1; }
tmp=$(mktemp --suffix=.png); trap 'rm -f "$tmp"' EXIT

python3 -I - "$src" "$tmp" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert('RGBA')
x0, y0, x1, y1 = im.getchannel('A').point(lambda a: 255 if a > 8 else 0).getbbox()
pad = 12
im.crop((max(x0 - pad, 0), max(y0 - pad, 0), min(x1 + pad, im.width), min(y1 + pad, im.height))).save(sys.argv[2])
PY

for spec in "xynorash.txt 108x34" "xynorash-m.txt 54x18"; do
  read -r name size <<< "$spec"
  chafa -f symbols --symbols half+quad+vhalf --size "$size" \
        --colors full --work 9 --dither none "$tmp" > "$outdir/$name"
  echo "wrote $outdir/$name ($(wc -l < "$outdir/$name") rows)"
done

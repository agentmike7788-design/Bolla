#!/usr/bin/env python3
"""Contact sheet with time marks from a frame list (G8 Runde 4, graveyard_shots_round4.gd).

    python tools/contact_sheet.py <frames.json> <out.jpg> [--cols=4] [--width=640] [--title="..."]

<frames.json>: {"frames": [{"file": "x.png", "label": "+1.2 s · table_examine"}, ...]} – the files lie next to it.
Each frame is scaled to --width, gets its label in a bar above it; a title line on top. Needs Pillow.
"""
import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

BAR = 30
GAP = 6
TITLE = 40
BG = (24, 24, 24)
FG = (235, 225, 205)
ACCENT = (232, 170, 70)


def _font(size):
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def main(argv):
    args = [a for a in argv if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in argv if a.startswith("--") and "=" in a)
    if len(args) != 2:
        print(__doc__)
        return 2
    src, out = args
    cols = int(opts.get("cols", 4))
    width = int(opts.get("width", 640))
    title = opts.get("title", "")
    with open(src, encoding="utf-8") as f:
        frames = json.load(f)["frames"]
    base = os.path.dirname(os.path.abspath(src))
    tiles = []
    for fr in frames:
        img = Image.open(os.path.join(base, fr["file"])).convert("RGB")
        h = round(img.height * width / img.width)
        tiles.append((img.resize((width, h), Image.LANCZOS), fr.get("label", "")))
    tile_h = max(t[0].height for t in tiles)
    rows = (len(tiles) + cols - 1) // cols
    top = TITLE if title else 0
    sheet = Image.new("RGB", (cols * width + (cols + 1) * GAP, top + rows * (tile_h + BAR + GAP) + GAP), BG)
    draw = ImageDraw.Draw(sheet)
    if title:
        draw.text((GAP + 4, 8), title, fill=ACCENT, font=_font(22))
    font = _font(17)
    for i, (img, label) in enumerate(tiles):
        x = GAP + (i % cols) * (width + GAP)
        y = top + GAP + (i // cols) * (tile_h + BAR + GAP)
        draw.text((x + 4, y + 5), label, fill=FG, font=font)
        sheet.paste(img, (x, y + BAR))
    sheet.save(out, quality=88)
    print(out, sheet.size)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

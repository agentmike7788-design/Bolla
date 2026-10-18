"""G9 Gehtempo: contact sheet of the frames of src/world/village/village_shots_tempo.gd – before (upper rows) and after
(lower rows), the same camera, one frame per beat, the game clock, the way since the last frame and the clip's speed_scale
under each frame.

    python3 tools/tempo_strip.py <dir with <walk>_<tag>_<nn>.jpg + <walk>_<tag>.txt> <walk> <out.jpg> [crop x0,y0,x1,y1]
"""
import csv
import os
import sys

from PIL import Image, ImageDraw, ImageFont

TAGS = (("vorher", "vorher (Phase 7/8)"), ("nachher", "nachher (G9 Gehtempo)"))
TILE_W = 400
PAD = 8
LABEL_H = 34
HEAD_H = 30


def _font(size):
    for f in ("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "/usr/share/fonts/dejavu/DejaVuSans.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()


def main():
    src, walk, out = sys.argv[1], sys.argv[2], sys.argv[3]
    crop = tuple(int(v) for v in sys.argv[4].split(",")) if len(sys.argv) > 4 else None
    rows = []
    for tag, title in TAGS:
        stats = list(csv.DictReader(open(os.path.join(src, "%s_%s.txt" % (walk, tag))), delimiter="\t"))
        tiles = []
        for s in stats:
            img = Image.open(os.path.join(src, "%s_%s_%02d.jpg" % (walk, tag, int(s["frame"]))))
            if crop:
                img = img.crop(crop)
            img = img.resize((TILE_W, int(img.height * TILE_W / img.width)))
            tiles.append((img, s))
        rows.append((title, tiles))
    n = max(len(t) for _, t in rows)
    th = rows[0][1][0][0].height
    w = PAD + n * (TILE_W + PAD)
    h = sum(HEAD_H + th + LABEL_H + PAD for _ in rows) + PAD
    sheet = Image.new("RGB", (w, h), (24, 22, 20))
    d = ImageDraw.Draw(sheet)
    big, small = _font(20), _font(15)
    y = PAD
    for title, tiles in rows:
        d.text((PAD, y + 4), title, fill=(235, 225, 200), font=big)
        y += HEAD_H
        for i, (img, s) in enumerate(tiles):
            x = PAD + i * (TILE_W + PAD)
            sheet.paste(img, (x, y))
            if float(s["step_m"]) > 50.0 or s["anim"] == "idle":
                text = "%s  im Haus (angekommen)" % s["clock"]
            else:
                text = "%s  +%s m  %s × %s" % (s["clock"], s["step_m"].replace(".", ","), s["anim"],
                                                s["speed_scale"].replace(".", ","))
            d.text((x + 2, y + th + 6), text, fill=(220, 210, 190), font=small)
        y += th + LABEL_H + PAD
    sheet.save(out, quality=90)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()

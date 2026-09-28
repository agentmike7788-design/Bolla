"""Painted particle textures for Phase 4 (docs/PHASE4_DESIGN.md section 8), Pillow only.

  assets/vfx/ph_vfx_fly_atlas.png     4 x 64 x 64 (256 x 64): a painted fly in four wing-beat
                                      frames, ink blue #1F2A3A with an amber glint
  assets/vfx/ph_vfx_stench_wisp.png   128 x 128: a curled wisp of stench, pale olive, soft brush
                                      edge - never green-turquoise (reserved for the supernatural)
  assets/vfx/ph_vfx_smoke_wisp.png    128 x 128: juniper smoke, warm grey

Straight (non-premultiplied) alpha; the colour is spread over the whole image so filtering never
pulls in dark fringes; the outermost pixels are fully transparent (billboards show no edge).
Deterministic (fixed seeds). The particles and materials belong to P4 (mat_vfx_fly, mat_vfx_wisp,
mat_vfx_smoke).

Run:  python tools/textures/paint_vfx.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "vfx")

INK = (0x1F, 0x2A, 0x3A)
AMBER = (0xF2, 0xA9, 0x3B)
WING = (0xB4, 0xB0, 0xA4)          # smoky, warm-grey wing membrane (no cold tint)
OLIVE = (0x9C, 0x98, 0x6C)         # pale olive
OLIVE_DARK = (0x7E, 0x7A, 0x52)
SMOKE = (0xA2, 0x99, 0x8C)         # warm grey
SMOKE_LIGHT = (0xC4, 0xBC, 0xAE)


# --- tiny value noise (no numpy) -------------------------------------------------------------

class Noise:
    def __init__(self, seed: int, cells: int = 8):
        rnd = random.Random(seed)
        self.n = cells
        self.g = [[rnd.random() for _ in range(cells + 1)] for _ in range(cells + 1)]

    def at(self, u: float, v: float) -> float:
        """Smooth value noise in [0, 1] for u, v in [0, 1] (tiles at the cell grid)."""
        x, y = u * self.n, v * self.n
        i, j = int(math.floor(x)) % self.n, int(math.floor(y)) % self.n
        fx, fy = x - math.floor(x), y - math.floor(y)
        sx, sy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        i1, j1 = (i + 1) % self.n, (j + 1) % self.n
        a = self.g[j][i] + (self.g[j][i1] - self.g[j][i]) * sx
        b = self.g[j1][i] + (self.g[j1][i1] - self.g[j1][i]) * sx
        return a + (b - a) * sy


def _fbm(noises, u: float, v: float) -> float:
    total, amp, norm = 0.0, 1.0, 0.0
    for k, nz in enumerate(noises):
        total += nz.at(u * (1 + k), v * (1 + k)) * amp
        norm += amp
        amp *= 0.55
    return total / norm


def _clear_border(img: Image.Image, width: int = 1) -> Image.Image:
    px = img.load()
    w, h = img.size
    for x in range(w):
        for y in range(h):
            if x < width or y < width or x >= w - width or y >= h - width:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    return img


# --- fly atlas -----------------------------------------------------------------------------------

def _fly_frame(wing_deg: float, seed: int) -> Image.Image:
    """One 64 x 64 frame, painted at 4x and scaled down (soft painterly edges). The fly faces up
    (-V); wing_deg = angle of the wings above the body axis (a wing beat over four frames)."""
    s = 4
    size = 64 * s
    rnd = random.Random(seed)
    cx, cy = size / 2, size / 2 + 2 * s
    hinge = (cx, cy - 4 * s)
    wings = Image.new("L", (size, size), 0)
    for sgn in (-1, 1):
        layer = Image.new("L", (size, size), 0)
        d = ImageDraw.Draw(layer)
        x0 = hinge[0] + (1 if sgn > 0 else -23) * s
        d.ellipse([x0, hinge[1] - 6.5 * s, x0 + 24 * s, hinge[1] + 6.5 * s], fill=int(255 * 0.55))
        vx = hinge[0] + sgn * 20 * s
        d.line([hinge, (vx, hinge[1])], fill=170, width=s)                       # a darker vein
        # rotate the wing back from the side (pointing -/+X) towards the tail by (90 - wing_deg)
        layer = layer.rotate(sgn * (90.0 - wing_deg) * 0.8, center=hinge, resample=Image.BICUBIC)
        wings.paste(layer, (0, 0), layer)
    body = Image.new("L", (size, size), 0)
    db = ImageDraw.Draw(body)
    for sgn in (-1, 1):  # six short legs
        for k, (ang, ln) in enumerate(((35, 9), (80, 8), (125, 10))):
            a = math.radians(ang)
            x0, y0 = cx + sgn * 2 * s, cy + (k - 1) * 3 * s
            x1, y1 = x0 + sgn * math.sin(a) * ln * s, y0 - math.cos(a) * ln * s
            db.line([(x0, y0), (x1, y1), (x1 + sgn * 2 * s, y1 + 3 * s)], fill=255, width=int(1.2 * s))
    for ox, oy, rx, ry in ((0, -9, 4.6, 3.8), (0, -3, 5.8, 5.4), (0, 6, 5.6, 7.0)):   # head, thorax, abdomen
        jit = rnd.uniform(-0.3, 0.3) * s
        db.ellipse([cx + (ox - rx) * s + jit, cy + (oy - ry) * s, cx + (ox + rx) * s + jit, cy + (oy + ry) * s],
                   fill=255)
    wings = wings.filter(ImageFilter.GaussianBlur(1.2 * s))
    body = body.filter(ImageFilter.GaussianBlur(0.6 * s))
    # colour: ink body over smoky wings, faint abdomen stripes, amber glint, dark red-brown eyes
    rgb = Image.composite(Image.new("RGB", (size, size), INK), Image.new("RGB", (size, size), WING), body)
    stripes = Image.new("L", (size, size), 0)
    ds = ImageDraw.Draw(stripes)
    for k in range(3):
        y = cy + (3 + k * 3.2) * s
        ds.line([(cx - 4 * s, y), (cx + 4 * s, y)], fill=90, width=s)
    rgb = Image.composite(Image.new("RGB", (size, size), (0x3A, 0x44, 0x50)), rgb, stripes.filter(ImageFilter.GaussianBlur(s)))
    glint = Image.new("L", (size, size), 0)
    ImageDraw.Draw(glint).ellipse([cx - 4.2 * s, cy - 8.0 * s, cx - 0.4 * s, cy - 4.2 * s], fill=255)
    rgb = Image.composite(Image.new("RGB", (size, size), AMBER), rgb, glint.filter(ImageFilter.GaussianBlur(0.5 * s)))
    eyes = Image.new("L", (size, size), 0)
    de = ImageDraw.Draw(eyes)
    for sgn in (-1, 1):
        de.ellipse([cx + sgn * 2.6 * s - 2.4 * s, cy - 12.2 * s, cx + sgn * 2.6 * s + 2.4 * s, cy - 7.8 * s], fill=220)
    rgb = Image.composite(Image.new("RGB", (size, size), (0x5A, 0x2E, 0x26)), rgb, eyes.filter(ImageFilter.GaussianBlur(s)))
    alpha = Image.new("L", (size, size), 0)
    wpx, bpx, apx = wings.load(), body.load(), alpha.load()
    for y in range(size):
        for x in range(size):
            b = bpx[x, y] / 255.0
            apx[x, y] = int(255 * (b + wpx[x, y] / 255.0 * (1.0 - b)))
    img = rgb.convert("RGBA")
    img.putalpha(alpha)
    return img.resize((64, 64), Image.LANCZOS)


def fly_atlas() -> str:
    atlas = Image.new("RGBA", (256, 64), INK + (0,))
    for i, wing in enumerate((18.0, 52.0, 78.0, 40.0)):   # a wing beat: down, mid, up, mid
        atlas.paste(_fly_frame(wing, 30 + i), (i * 64, 0))
    path = os.path.join(OUT, "ph_vfx_fly_atlas.png")
    # every frame keeps a clear 1 px border
    px = atlas.load()
    for x in range(256):
        for y in range(64):
            if x % 64 in (0, 63) or y in (0, 63):
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)
    atlas.save(path)
    return path


# --- wisps ----------------------------------------------------------------------------------

def _wisp(size: int, base, light, seed: int, curl: float, peak: float, lumps: int) -> Image.Image:
    """A curled, soft-edged wisp: gaussian dabs along a rising spiral, broken up by brush noise."""
    rnd = random.Random(seed)
    noises = [Noise(seed + k, 4 + 2 * k) for k in range(3)]
    dabs = []
    for strand, (w0, off, ln) in enumerate(((1.0, 0.0, 1.0),)):   # one curling ribbon
        for k in range(lumps):
            t = k / (lumps - 1) * ln
            x = 0.5 + 0.2 * math.sin(t * curl * math.tau + off) * (0.6 + 0.4 * t) + (strand * 0.08)
            y = 0.86 - 0.7 * t
            if t > 0.75:  # the tip curls over
                a = (t - 0.75) / 0.25 * math.pi * 0.9
                x += 0.05 * (1 - math.cos(a))
                y += 0.03 * math.sin(a)
            r = 0.11 * (1 - 0.45 * t) + rnd.uniform(-0.012, 0.012)
            dabs.append((x, y, r, w0 * (0.5 + 0.5 * (1 - t))))
    img = Image.new("RGBA", (size, size), base + (0,))
    px = img.load()
    for j in range(size):
        v = (j + 0.5) / size
        for i in range(size):
            u = (i + 0.5) / size
            a = 0.0
            for x, y, r, w in dabs:
                d2 = ((u - x) ** 2 + (v - y) ** 2) / (r * r)
                if d2 < 9.0:
                    a += w * math.exp(-d2 * 1.6)
            n = _fbm(noises, u, v)
            a = max(0.0, min(1.0, a * 0.9)) * (0.45 + 0.8 * n)          # brush breaks up the mass
            a = max(0.0, a - 0.06) / 0.94
            edge = min(u, v, 1 - u, 1 - v) / 0.12                          # fade out to the border
            a *= max(0.0, min(1.0, edge)) ** 1.5
            a = min(peak, a * peak * 1.25)
            t = max(0.0, min(1.0, n * 1.4 - 0.2))
            c = tuple(int(b + (l - b) * t) for b, l in zip(base, light))
            px[i, j] = c + (int(255 * a),)
    return _clear_border(img)


def stench_wisp() -> str:
    path = os.path.join(OUT, "ph_vfx_stench_wisp.png")
    _wisp(128, OLIVE_DARK, OLIVE, 51, curl=1.1, peak=0.8, lumps=32).save(path)
    return path


def smoke_wisp() -> str:
    path = os.path.join(OUT, "ph_vfx_smoke_wisp.png")
    _wisp(128, SMOKE, SMOKE_LIGHT, 61, curl=0.7, peak=0.72, lumps=28).save(path)
    return path


def build() -> None:
    os.makedirs(OUT, exist_ok=True)
    for fn in (fly_atlas, stench_wisp, smoke_wisp):
        print("[vfx]", fn())


if __name__ == "__main__":
    build()

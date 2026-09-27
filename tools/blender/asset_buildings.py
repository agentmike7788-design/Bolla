"""Gravekeeper's hut (small morgue). Front (door) faces -Y in Blender = +Z in Godot."""
import math
import random

import bpy

import lib_painted as L

STONE = L.hexc("#7E8187")
WOOD = L.hexc("#6E5238")
WOOD_DARK = L.hexc("#4A3626")
ROOF = L.hexc("#5A4E48")
ROOF_MOSS = L.hexc("#5E7148")
IRON = L.hexc("#3A3C40")

W, D, H = 3.4, 3.0, 2.3   # walls: width (x), depth (y), height above foundation
F = 0.45                  # foundation height


def _planks_wall(x0, x1, y, h, seed, along="x"):
    parts = []
    n = max(2, int(abs(x1 - x0) / 0.22))
    step = (x1 - x0) / n
    for i in range(n):
        c = x0 + step * (i + 0.5)
        ph = h + random.uniform(-0.05, 0.05)
        col = L.scale_c(WOOD, random.uniform(0.82, 1.12))
        loc = (c, y, F + ph / 2) if along == "x" else (y, c, F + ph / 2)
        sc = (abs(step) / 2 * 0.96, 0.05, ph / 2) if along == "x" else (0.05, abs(step) / 2 * 0.96, ph / 2)
        p = L.part("cube", col, loc=loc, scale=sc, rot=(0, random.uniform(-1.2, 1.2), 0),
                   jit=0.008, seed=seed + i, paint_kw={"ao": 0.45, "zrange": (F, F + h)})
        parts.append(p)
    return parts


def build():
    L.reset(60)
    parts = []
    # stone foundation
    found = L.prim("cube", loc=(0, 0, F / 2), scale=(W / 2 + 0.12, D / 2 + 0.12, F / 2))
    L.subdivide(found, 3)
    L.jitter(found, 0.03, 2.0, 1)
    L.paint(found, STONE, var=0.25, ao=0.5, seed=2, hue_shift=ROOF_MOSS)
    L.set_mat(found, L.MAT_PAINTED)
    parts.append(found)
    # walls (planks); gable walls on +-x get their own plank height
    parts += _planks_wall(-W / 2, W / 2, -D / 2, H, 10)            # front
    parts += _planks_wall(-W / 2, W / 2, D / 2, H, 40)             # back
    parts += _planks_wall(-D / 2, D / 2, -W / 2, H, 70, along="y")  # left
    parts += _planks_wall(-D / 2, D / 2, W / 2, H, 90, along="y")   # right
    # corner posts & top beams
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", WOOD_DARK, loc=(sx * W / 2, sy * D / 2, F + H / 2),
                                scale=(0.09, 0.09, H / 2 + 0.03), jit=0.01, seed=sx + sy * 3))
    for sy in (-1, 1):
        parts.append(L.part("cube", WOOD_DARK, loc=(0, sy * D / 2, F + H), scale=(W / 2 + 0.1, 0.08, 0.07), seed=5))
    # gable triangles (left/right)
    gable_h = 1.5
    for sx in (-1, 1):
        g = L.prism_x([(-D / 2, F + H), (D / 2, F + H), (0, F + H + gable_h)], sx * W / 2, 0.1)
        L.paint(g, WOOD, var=0.2, seed=7)
        L.set_mat(g, L.MAT_PAINTED)
        parts.append(g)
    # crooked, sagging roof made of shingle rows
    pitch = math.degrees(math.atan2(gable_h, D / 2))
    slope_len = math.hypot(D / 2, gable_h) + 0.45
    rows = 7
    for side in (-1, 1):
        for r in range(rows):
            t = (r + 0.5) / rows
            y = side * (0.05 + t * (slope_len - 0.1) * math.cos(math.radians(pitch)))
            z = F + H + gable_h + 0.12 - t * slope_len * math.sin(math.radians(pitch))
            col = L.mix(ROOF, ROOF_MOSS, random.uniform(0.0, 0.45) + (0.25 if side > 0 else 0))
            sh = L.prim("cube", loc=(0, y, z), scale=(W / 2 + 0.45, slope_len / rows * 0.62, 0.045),
                        rot=(side * -pitch - 4 * side, 0, 0))
            L.subdivide(sh, 4)
            for v in sh.data.vertices:  # sag in the middle
                v.co.z -= 0.09 * (1 - (v.co.x / (W / 2 + 0.45)) ** 2)
            L.jitter(sh, 0.025, 1.3, r + side * 10)
            L.paint(sh, col, var=0.22, ao=0.2, top=0.15, seed=r)
            L.set_mat(sh, L.MAT_PAINTED)
            parts.append(sh)
    parts.append(L.part("cube", WOOD_DARK, loc=(0, 0, F + H + gable_h + 0.14), scale=(W / 2 + 0.5, 0.1, 0.08),
                        rot=(0, -1.5, 0), jit=0.02, seed=3))
    # leaning stone chimney (back right)
    ch = L.prim("cube", loc=(1.0, 0.7, F + H + 1.4), scale=(0.28, 0.28, 0.85))
    L.subdivide(ch, 3)
    L.jitter(ch, 0.03, 2.0, 4)
    L.bend(ch, 0.12, F + H + 0.6, F + H + 2.3)
    L.paint(ch, STONE, var=0.25, ao=0.3, seed=5, hue_shift=ROOF_MOSS)
    L.set_mat(ch, L.MAT_PAINTED)
    parts.append(ch)
    # door (front, -Y) with frame and iron hinges
    fy = -D / 2 - 0.06
    parts.append(L.part("cube", L.scale_c(WOOD_DARK, 0.8), loc=(-0.55, fy, F + 0.95), scale=(0.5, 0.04, 0.97), seed=8))
    for i in range(4):
        parts.append(L.part("cube", L.scale_c(WOOD_DARK, random.uniform(0.95, 1.25)),
                            loc=(-0.9 + i * 0.235, fy - 0.03, F + 0.9), scale=(0.11, 0.03, 0.88), jit=0.006, seed=20 + i))
    for z in (F + 0.4, F + 1.45):
        parts.append(L.part("cube", IRON, loc=(-0.72, fy - 0.07, z), scale=(0.3, 0.015, 0.035), seed=9))
    # steps
    parts.append(L.part("cube", STONE, loc=(-0.55, -D / 2 - 0.45, 0.14), scale=(0.62, 0.3, 0.14), jit=0.02, seed=11))
    # window with warm light (front right)
    wx, wz = 0.85, F + 1.3
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(wx, fy + 0.02, wz), scale=(0.36, 0.02, 0.32)))
    for (sx, sz) in ((0.4, 0.04), (0.04, 0.36)):
        parts.append(L.part("cube", WOOD_DARK, loc=(wx, fy - 0.03, wz), scale=(sx, 0.03, sz), seed=12))
    parts.append(L.part("cube", WOOD_DARK, loc=(wx, fy - 0.05, wz - 0.38), scale=(0.46, 0.08, 0.04), seed=13))
    # lantern bracket + lantern beside door
    lx = 0.12
    parts.append(L.part("cube", IRON, loc=(lx, fy - 0.2, F + 1.95), scale=(0.02, 0.2, 0.02)))
    parts.append(L.part("cube", IRON, loc=(lx, fy - 0.38, F + 1.8), scale=(0.08, 0.08, 0.02)))
    parts.append(L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(lx, fy - 0.38, F + 1.68), scale=(0.06, 0.06, 0.1)))
    parts.append(L.part("cone", IRON, loc=(lx, fy - 0.38, F + 1.84), vertices=4, radius1=0.1, depth=0.1, rot=(0, 0, 45)))
    obj = L.join(parts, "ph_bld_gravekeeper_hut")
    L.marker(obj, "light_lantern", (lx, fy - 0.38, F + 1.5))  # below the glass: no self-shadowing
    L.marker(obj, "light_window", (wx, fy + 0.4, wz))
    L.finish(obj, "ph_bld_gravekeeper_hut", "buildings", 30)


if __name__ == "__main__":
    build()

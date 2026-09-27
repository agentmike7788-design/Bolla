"""Lantern post, candles, shovel, crate, iron fence segment, gate post."""
import math
import random

import bpy

import lib_painted as L

WOOD = L.hexc("#6E5238")
WOOD_DARK = L.hexc("#4A3626")
IRON = L.hexc("#3A3C40")
RUST = L.hexc("#6A4A3A")
STONE = L.hexc("#7E8187")
MOSS = L.hexc("#5E7148")
WAX = L.hexc("#E6D8B8")


def lantern_post():
    L.reset(70)
    parts = [L.part("cube", WOOD_DARK, loc=(0, 0, 1.1), scale=(0.07, 0.07, 1.1), jit=0.015, seed=1,
                    paint_kw={"ao": 0.5}),
             L.part("cube", WOOD_DARK, loc=(0.28, 0, 2.12), scale=(0.3, 0.05, 0.05), jit=0.01, seed=2),
             L.part("cube", WOOD_DARK, loc=(0.12, 0, 1.95), scale=(0.16, 0.03, 0.03), rot=(0, -45, 0), seed=3),
             L.part("cube", IRON, loc=(0.52, 0, 1.98), scale=(0.01, 0.01, 0.1)),
             L.part("cube", IRON, loc=(0.52, 0, 1.64), scale=(0.1, 0.1, 0.02)),
             L.part("cube", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(0.52, 0, 1.77), scale=(0.075, 0.075, 0.12)),
             L.part("cone", IRON, loc=(0.52, 0, 1.94), vertices=4, radius1=0.13, depth=0.12, rot=(0, 0, 45))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", IRON, loc=(0.52 + sx * 0.075, sy * 0.075, 1.77), scale=(0.012, 0.012, 0.12)))
    obj = L.join(parts, "ph_prop_lantern_post")
    L.marker(obj, "light_lantern", (0.52, 0, 1.55))  # below the cage: no self-shadowing
    L.finish(obj, "ph_prop_lantern_post", "props", 30)


def candle_cluster():
    L.reset(71)
    parts = []
    for i, (x, y, h) in enumerate(((0, 0, 0.22), (0.09, 0.06, 0.14), (-0.07, 0.08, 0.1))):
        c = L.prim("cyl", loc=(x, y, h / 2), radius=0.035, depth=h, vertices=8)
        for v in c.data.vertices:  # melted top
            if v.co.z > h * 0.4:
                v.co.z -= random.uniform(0, 0.02)
        L.paint(c, WAX, var=0.1, ao=0.3, seed=i)
        L.set_mat(c, L.MAT_PAINTED)
        parts.append(c)
        parts.append(L.part("cone", (1, 1, 1), mat=L.MAT_EMISSIVE, loc=(x, y, h + 0.03), radius1=0.014,
                            depth=0.05, vertices=6))
    obj = L.join(parts, "ph_prop_candle_cluster")
    L.marker(obj, "light_candle", (0, 0.03, 0.3))
    L.finish(obj, "ph_prop_candle_cluster", "props", 50)


def shovel():
    """Shovel leaning against a wall: built upright, the object is tilted."""
    L.reset(72)
    parts = [L.part("cyl", WOOD, loc=(0, 0, 0.75), radius=0.022, depth=1.1, vertices=6, jit=0.004, seed=1),
             L.part("cube", WOOD, loc=(0, 0, 1.33), scale=(0.08, 0.02, 0.02)),
             L.part("cube", IRON, loc=(0, 0, 0.14), scale=(0.12, 0.012, 0.16), jit=0.01, seed=2,
                    paint_kw={"hue_shift": RUST, "var": 0.3})]
    obj = L.join(parts, "ph_prop_shovel")
    obj.rotation_euler.x = math.radians(-18)
    L.finish(obj, "ph_prop_shovel", "props", 40)


def crate():
    L.reset(73)
    parts = []
    s = 0.32
    for i in range(3):  # plank rows on each side
        z = 0.1 + i * 0.21
        for (x, y, sx, sy) in ((0, -s, s, 0.02), (0, s, s, 0.02), (-s, 0, 0.02, s), (s, 0, 0.02, s)):
            parts.append(L.part("cube", L.scale_c(WOOD, random.uniform(0.8, 1.15)), loc=(x, y, z),
                                scale=(sx, sy, 0.095), jit=0.005, seed=i * 4 + len(parts)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(L.part("cube", WOOD_DARK, loc=(sx * s, sy * s, 0.32), scale=(0.035, 0.035, 0.33), seed=9))
    parts.append(L.part("cube", WOOD, loc=(0, 0, 0.64), scale=(s, s, 0.02), jit=0.005, seed=12))
    L.finish(L.join(parts, "ph_prop_crate"), "ph_prop_crate", "props", 30)


def fence_segment():
    """2 m wrought-iron fence segment along +X, starting at x = 0."""
    L.reset(74)
    parts = []
    for z in (0.18, 0.92):
        parts.append(L.part("cube", IRON, loc=(1.0, 0, z), scale=(1.0, 0.015, 0.02), seed=int(z * 10)))
    n = 11
    for i in range(n):
        x = (i + 0.5) * 2.0 / n
        h = 1.05 + (0.06 if i % 2 == 0 else 0.0)
        lean = random.uniform(-2.5, 2.5)
        p = L.part("cube", IRON, loc=(x, 0, h / 2), scale=(0.012, 0.012, h / 2), rot=(lean, lean * 0.5, 0))
        tip = L.part("cone", IRON, loc=(x, 0, h + 0.05), radius1=0.03, depth=0.1, vertices=4, rot=(lean, 0, 45))
        parts += [p, tip]
    for o in parts:
        L.paint(o, IRON, var=0.25, ao=0.2, hue_shift=RUST, seed=3)
    L.finish(L.join(parts, "ph_prop_fence_iron"), "ph_prop_fence_iron", "props", 30)


def gate_post():
    L.reset(75)
    body = L.prim("cube", loc=(0, 0, 0.75), scale=(0.2, 0.2, 0.75))
    L.subdivide(body, 3)
    L.jitter(body, 0.02, 2.0, 1)
    L.paint(body, STONE, var=0.25, ao=0.5, hue_shift=MOSS, seed=2)
    L.set_mat(body, L.MAT_PAINTED)
    cap = L.part("cube", STONE, loc=(0, 0, 1.56), scale=(0.25, 0.25, 0.06), jit=0.01, seed=3)
    ball = L.part("sphere", STONE, loc=(0, 0, 1.72), radius=0.11, segments=10, ring_count=6,
                  paint_kw={"hue_shift": MOSS})
    L.finish(L.join([body, cap, ball], "ph_prop_gate_post"), "ph_prop_gate_post", "props", 40)


def build():
    lantern_post()
    candle_cluster()
    shovel()
    crate()
    fence_segment()
    gate_post()


if __name__ == "__main__":
    build()

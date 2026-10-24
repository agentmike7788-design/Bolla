"""G9 Gehtempo (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1): the pace of the data schedule walks.

The generators (build_phase8_schedules.py, build_phase9_schedules.py, retime_walks.py) time every walk from the flat
length of its waypoint polyline (data/world/village_layout.json, data/world/graveyard_layout.json – the same points the
world builds) at the pace of data/config/npc_config.tres:
  walk_m_per_minute 0.8 (1.6 m/s real at 0.5 s per game minute – the walk clip at speed_scale 0.97),
  cart_m_per_minute 0.55 (pushing / riding on the handcart – the push clip at 0.96),
  band walk_min/max_m_per_minute 0.5–1.0, cart_min/max_m_per_minute 0.4–0.7 (WalkTempo / test_walk_tempo check it).
Rounding as ScheduleBuilder.travel_minutes: ceil(length / pace), at least 1 minute.
"""
import json
import math
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONFIG = os.path.join(ROOT, "data", "config", "npc_config.tres")
VILLAGE = os.path.join(ROOT, "data", "world", "village_layout.json")
GRAVEYARD = os.path.join(ROOT, "data", "world", "graveyard_layout.json")
CART_ANIMS = ("push_cart", "sit_cart")
RUN_ANIMS = ("run", "climb")


def _config():
    with open(CONFIG, encoding="utf-8") as f:
        text = f.read()
    out = {}
    for key in ("walk_m_per_minute", "walk_min_m_per_minute", "walk_max_m_per_minute", "cart_m_per_minute",
                "cart_min_m_per_minute", "cart_max_m_per_minute"):
        m = re.search(r"^%s = ([0-9.]+)$" % key, text, re.M)
        out[key] = float(m.group(1))
    return out


CFG = _config()
WALK = CFG["walk_m_per_minute"]
CART = CFG["cart_m_per_minute"]


def _graveyard_points():
    with open(GRAVEYARD, encoding="utf-8") as f:
        lay = json.load(f)
    pts = {k: v for k, v in lay["waypoints"].items() if isinstance(v, list)}
    pts.update({k: v[:2] for k, v in lay.get("visitor_spots", {}).items()})
    pts.update(lay.get("visitor_waypoints", {}))
    return pts, lay.get("visitor_routes", {})


def _village_points():
    with open(VILLAGE, encoding="utf-8") as f:
        return json.load(f)["waypoints"]


GY, ROUTES = _graveyard_points()
VIL = _village_points()


def points(region):
    return VIL if region == "village" else GY


def length(path, region="village"):
    pts = points(region)
    return sum(math.hypot(pts[a][0] - pts[b][0], pts[a][1] - pts[b][1]) for a, b in zip(path, path[1:]))


def gait(animation="walk", cart=False):
    if cart or animation in CART_ANIMS:
        return "cart"
    if animation in RUN_ANIMS:
        return "run"
    return "walk"


def minutes(path, region="village", animation="walk", cart=False):
    """Game minutes of the polyline at the gait's pace (ScheduleBuilder.travel_minutes: ceil, ≥ 1; 0 = no distance)."""
    d = length(path, region)
    if d <= 0.0001:
        return 0
    pace = CART if gait(animation, cart) == "cart" else WALK
    return max(1, math.ceil(d / pace - 0.0001))


def band(g):
    if g == "cart":
        return CFG["cart_min_m_per_minute"], CFG["cart_max_m_per_minute"]
    if g == "run":
        return 0.0, float("inf")
    return CFG["walk_min_m_per_minute"], CFG["walk_max_m_per_minute"]


def in_band(path, region, travel, animation="walk", cart=False):
    if travel <= 0:
        return True
    lo, hi = band(gait(animation, cart))
    pace = length(path, region) / travel
    # A step of one or two minutes may be slower (whole minutes, rounded up) – WalkTempo.SHORT_MINUTES.
    return pace <= hi + 0.0001 and (pace >= lo - 0.0001 or travel <= 2)


def route_up(target):
    """The baked route road_end -> ... -> target (gv_<grave> or a waypoint id; data/world/graveyard_layout.json)."""
    key = target[3:] if target.startswith("gv_") else target
    return list(ROUTES.get(key, ["road_end", "road_mid", "gate_outside", "gate_inside", target]))

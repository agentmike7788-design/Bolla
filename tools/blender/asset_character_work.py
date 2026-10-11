"""G8 Runde 3 (user: "annimationen fehlen", "die leichen preperation annimation fehlen auch"): the gravekeeper's
work at the morgue table and the other hand work that only had the generic reach (`interact`).
'Tod ist Handwerk, nicht Horror': calm, practised movements, nothing shown inside - the organ work stays
under the cloth and the screen veil (MorgueTable), the hands and the tool tell what he does.

The table clips assume the table's centre line TABLE_D in front of him (he stands at its long side,
facing it: MorgueTable / ToolAnimConfig.table_stand_*), the body's surface at ~1.0 m. The head work
(comb, braid, teeth) is done standing at the head end, so every clip works straight ahead and reads the
same from both long sides.

  table_examine-loop   bent over the body, the left hand resting on it, the right palpating, the head close
  table_search-loop    both hands turning hems and pockets, by turns
  table_wash-loop      the wet cloth (ph_tool_washcloth) in long strokes along the body, the left hand steadying
  table_cut-loop       the scalpel (ph_tool_scalpel), a slow, precise stroke, the left hand flat beside it;
                       he does not look (the head turned aside)
  table_comb-loop      at the head: the comb (ph_tool_comb) in short strokes, the left hand at the temple
  table_smoke-loop     the smouldering juniper (ph_tool_juniper) carried in a slow arc over the body
  table_shroud-loop    the linen (ph_tool_linen) between both fists: lifted, cast forward over the body,
                       laid down and smoothed
  table_snip-loop      at the head: the left hand lifts the braid, the shears (ph_tool_shears) cut
  table_pull-loop      at the head: the pliers (ph_tool_pliers), a short twist and pull, the face turned away
  hand_draw / hand_stow / hand_stow_walk   any of the small tools out of / back into the tool bag at the
                       right hip (shared by all of them; the table clips cross-fade in, hold_blends)
  pray-loop            hands folded, the head bowed (the blessing at the chapel altar, the devotion)
  write-loop           at a desk: the left hand holds the page, the right writes (the register, the archive)
  bench_work-loop      fine work at a bench with both hands (the preparation desk, the archive cupboard)
  place_low-loop       a deep bow, both hands set down / take up something low (the ossuary, piles, decor)
  weed_pull            45 frames one-shot like kneel_place: down at the grave, the right hand pulls twice, up
  fill_can-loop        the watering can (ph_tool_watering_can at can_grip) dipped into the rain barrel
  rake-loop            the rake (ph_tool_rake) drawn towards him through the leaves; rake_take / rake_put /
                       rake_put_walk bring it (it shows at once - it leans at the grave, like the can)

Pose keys (on top of rig.py's bones; every key of one clip carries the same keys - they are blended):
  "r_at"/"l_at": (x, y, z) armature-space targets of the right / left fist, "r_w"/"l_w": (w,) how firmly the
  rigid arm is turned onto it (0 = the keyed arm pose). The tool clips key the right fist and the tool as
  asset_character_tools does ("w_fist", "w_dir", "w_axis", "w_grip", "w_home"); two-handed tools (linen,
  rake) let the left fist slide along the handle there.
"""
import math

from mathutils import Vector

import asset_character as C
import asset_character_tools as T
import rig

TABLE_D = 0.64         # the table's centre line in front of him (ToolAnimConfig.table_stand_distance)
TOP = 1.05             # the body's surface on the table (chest)
HEAD_D = 0.62          # the head end: he stands on the table's axis, the dead's head centre this far ahead
FACE = 1.08            # the face / the hair on the table
MARKER = "tool_hand"   # tool-bone marker in the tool bone's rest frame (the hand tools hang there)


# --- helpers ----------------------------------------------------------------------------------------

def _toward(a, b) -> tuple:
    """(elev, az) of the direction a -> b (asset_character._up convention)."""
    d = (Vector(b) - Vector(a)).normalized()
    return (math.degrees(math.asin(max(-1.0, min(1.0, d.z)))), math.degrees(math.atan2(-d.x, d.y)))


def _tool(fist, elev, az, face, grip, **more) -> dict:
    """Tool keys with the working side facing `face` (the swing axis n = d x face)."""
    d = C._up(elev, az).normalized()
    n = d.cross(Vector(face))
    if n.length < 1e-4:
        n = d.cross(Vector((0.0, 0.0, 1.0)))
    return T._w(tuple(fist), elev, az, tuple(n.normalized()), tuple(grip), **more)


def _hands(r=None, l=None, rw: float = 1.0, lw: float = 1.0) -> dict:
    """Fist targets (None = that arm keeps its keyed pose: weight 0, target the rest fist)."""
    out = {}
    out["r_at"] = tuple(r) if r is not None else tuple(C.FIST[-1])
    out["r_w"] = (rw if r is not None else 0.0,)
    out["l_at"] = tuple(l) if l is not None else tuple(C.FIST[1])
    out["l_w"] = (lw if l is not None else 0.0,)
    return out


def _pose(*parts) -> dict:
    return rig.add(C._stance(), *parts)


def _work(pose_fn, name: str = ""):
    """rig.add_action post hook: the fists onto their targets, then the tool onto the right fist."""
    wield = T._wield(pose_fn, name)

    def post(arm, t):
        pose = pose_fn(t)
        for bone, key in (("arm_r", "r"), ("arm_l", "l")):
            w = float(pose.get(key + "_w", (0.0,))[0])
            if w > 0.001:
                C._aim_arm(arm, bone, Vector(pose[key + "_at"][:3]), min(1.0, w))
        wield(arm, t)
    return post


def _y(d: float) -> float:
    """A point d m beyond the table's centre line (negative: nearer to him)."""
    return -(TABLE_D + d)


# --- the table: examining by hand -----------------------------------------------------------------

def _examine_keys() -> list:
    a = _pose(C._body(17.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.015)),
              _hands((-0.16, _y(-0.1), TOP + 0.03), (0.15, _y(-0.06), TOP)))
    b = _pose(C._body(19.0, -4.0, head=-2.0, hips=(4.0, 0, 0, 0, 0.03, -0.02)),
              {"head": (0.0, 0.0, -8.0)}, _hands((-0.08, _y(0.02), TOP - 0.01), (0.15, _y(-0.06), TOP - 0.01)))
    c = _pose(C._body(19.0, -8.0, head=-2.0, hips=(4.0, 0, 0, 0, 0.03, -0.02)),
              {"head": (0.0, 0.0, -14.0)}, _hands((-0.27, _y(-0.02), TOP), (0.15, _y(-0.06), TOP - 0.01)))
    d = _pose(C._body(18.0, -2.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.015)),
              {"head": (0.0, 0.0, 4.0)}, _hands((-0.2, _y(-0.1), TOP + 0.07), (0.16, _y(-0.05), TOP)))
    return [(0.0, a), (0.28, b), (0.52, c), (0.78, d)]


def table_examine(t: float) -> dict:
    """48 frames = 1.6 s loop: bent over the body, the left hand resting flat, the right one pressing and
    feeling its way along, the head close and following it."""
    return rig.keyed(t, _examine_keys())


def table_search(t: float) -> dict:
    """36 frames = 1.2 s loop: both hands at the clothes - the right lifts a hem and turns it while the
    left pats a pocket, then the other way round."""
    body = C._body(18.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.02, -0.015))
    r_up, r_dn = (-0.2, _y(-0.2), TOP + 0.1), (-0.18, _y(-0.14), TOP + 0.01)
    l_up, l_dn = (0.18, _y(-0.2), TOP + 0.09), (0.16, _y(-0.14), TOP + 0.01)
    a = _pose(body, {"spine": (0.0, 0.0, -5.0)}, _hands(r_up, l_dn))
    b = _pose(body, {"spine": (0.0, 0.0, 5.0)}, _hands(r_dn, l_up))
    return rig.keyed(t, [(0.0, a), (0.5, b)])


# --- the table: the small tools --------------------------------------------------------------------

WASH_BITE = 0.2


def _wash_keys() -> list:
    down, face = -38.0, (0.0, 0.0, -1.0)
    left = {"l_at": (0.3, _y(-0.1), TOP), "l_w": (1.0,), "r_at": tuple(C.FIST[-1]), "r_w": (0.0,)}
    grip = (0.03, 0.0, 1.0, 0.0)
    start = _pose(C._body(22.0, 8.0, head=-3.0, hips=(4.0, 0, 0, 0, 0.03, -0.02)), left,
                  _tool((0.1, _y(-0.02), TOP + 0.08), down, 180.0, face, grip))
    press = _pose(C._body(23.0, 6.0, head=-3.0, hips=(4.0, 0, 0, 0, 0.03, -0.025)), left,
                  _tool((0.06, _y(0.0), TOP + 0.06), down, 185.0, face, grip))
    mid = _pose(C._body(23.0, -4.0, head=-3.0, hips=(4.0, 0, 0, 0, 0.03, -0.025)), left,
                _tool((-0.14, _y(-0.02), TOP + 0.06), down, 175.0, face, grip))
    end = _pose(C._body(22.0, -12.0, head=-3.0, hips=(4.0, 0, 0, 0, 0.03, -0.02)), left,
                _tool((-0.32, _y(-0.06), TOP + 0.07), down, 165.0, face, grip))
    lift = _pose(C._body(20.0, -2.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.015)), left,
                 _tool((-0.1, _y(-0.12), TOP + 0.14), -25.0, 180.0, face, grip))
    return [(0.0, start), (WASH_BITE, press), (0.45, mid), (0.62, end), (0.82, lift)]


def table_wash(t: float) -> dict:
    """42 frames = 1.4 s loop (the wash cue's interval): the wet cloth pressed onto the body and drawn in one
    long stroke along it (the stroke sounds at WASH_BITE), lifted and brought back; the left hand steadies."""
    return rig.keyed(t, _wash_keys())


CUT_BITE = 0.3


def _cut_keys() -> list:
    face = (-1.0, 0.0, 0.0)   # the edge leads the stroke towards his right
    grip = (0.04, 0.0, 1.0, 0.0)
    body = C._body(25.0, 0.0, head=-6.0, hips=(5.0, 0, 0, 0, 0.035, -0.03))
    away = {"head": (0.0, 0.0, 26.0)}   # "ohne hinzusehen": the face turned aside
    left = {"l_at": (0.1, _y(0.02), TOP), "l_w": (1.0,), "r_at": tuple(C.FIST[-1]), "r_w": (0.0,)}
    ready = _pose(body, away, left, _tool((-0.04, _y(0.0), TOP + 0.16), -62.0, 180.0, face, grip))
    on = _pose(body, away, left, _tool((-0.05, _y(0.0), TOP + 0.12), -68.0, 182.0, face, grip))
    drawn = _pose(body, away, left, _tool((-0.17, _y(0.0), TOP + 0.12), -68.0, 186.0, face, grip))
    off = _pose(body, away, left, _tool((-0.15, _y(-0.03), TOP + 0.19), -55.0, 182.0, face, grip))
    return [(0.0, ready), (CUT_BITE, on), (0.62, drawn), (0.82, off)]


def table_cut(t: float) -> dict:
    """45 frames = 1.5 s loop: the scalpel set on (at CUT_BITE, the anatomy cue), drawn slowly a hand's breadth
    towards his right, lifted off and set on again; the left hand lies flat beside the cut, his face is
    turned away. Under the cloth - nothing to see but the hands."""
    return rig.keyed(t, _cut_keys())


COMB_BITE = 0.25


def _comb_keys() -> list:
    face = (0.0, 0.0, -1.0)    # the teeth into the hair
    grip = (0.04, 0.0, 1.0, 0.0)
    body = C._body(20.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.015))
    left = {"l_at": (0.11, -HEAD_D, FACE - 0.02), "l_w": (1.0,), "r_at": tuple(C.FIST[-1]), "r_w": (0.0,)}
    far = _pose(body, left, _tool((-0.03, -HEAD_D + 0.02, FACE + 0.08), -12.0, 90.0, face, grip))
    on = _pose(body, left, _tool((-0.03, -HEAD_D + 0.04, FACE + 0.04), -18.0, 90.0, face, grip))
    near = _pose(C._body(16.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.01)), left,
                 _tool((-0.04, -HEAD_D + 0.26, FACE + 0.02), -12.0, 92.0, face, grip))
    up = _pose(C._body(17.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.01)), left,
               _tool((-0.03, -HEAD_D + 0.16, FACE + 0.13), 5.0, 90.0, face, grip))
    return [(0.0, far), (COMB_BITE, on), (0.55, near), (0.78, up)]


def table_comb(t: float) -> dict:
    """36 frames = 1.2 s loop: standing at the head end - the comb set into the hair at the brow (COMB_BITE) and
    drawn over the crown towards him, lifted back; the left hand holds the head at the temple."""
    return rig.keyed(t, _comb_keys())


def _smoke_keys() -> list:
    face = (0.0, 1.0, 0.0)
    grip = (0.04, 0.0, 1.0, 0.0)
    left = {"l_at": (0.12, -0.32, 0.86), "l_w": (0.8,), "r_at": tuple(C.FIST[-1]), "r_w": (0.0,)}
    a = _pose(C._body(16.0, 14.0, head=-3.0), left, _tool((0.14, _y(-0.12), TOP + 0.26), 45.0, 185.0, face, grip))
    b = _pose(C._body(20.0, 0.0, head=-2.0), left, _tool((-0.08, _y(-0.02), TOP + 0.2), 38.0, 180.0, face, grip))
    c = _pose(C._body(16.0, -14.0, head=-3.0), left, _tool((-0.32, _y(-0.12), TOP + 0.26), 45.0, 175.0, face, grip))
    d = _pose(C._body(14.0, 0.0, head=-2.0), left, _tool((-0.1, _y(-0.22), TOP + 0.34), 55.0, 180.0, face, grip))
    return [(0.0, a), (0.3, b), (0.5, c), (0.78, d)]


def table_smoke(t: float) -> dict:
    """48 frames = 1.6 s loop: the smouldering juniper bundle held up and carried in a slow arc over the body
    from his left to his right and back high; the left hand low in front, the head bowed."""
    return rig.keyed(t, _smoke_keys())


def _shroud_keys() -> list:
    grip = (0.0, 0.58, 1.0, 1.0)            # right fist at the edge's start, the left slides to ~0.6 m
    hang = (0.0, 0.62, 0.78)                # face up and back = it hangs forward over the table's edge
    cast = (0.0, 0.55, -0.85)               # face back-down = it flies out forward and up
    laid = (0.0, 0.92, 0.38)                # face back = it lies forward over the body
    drag = (0.0, 0.85, 0.52)
    gather = _pose(C._body(12.0, 0.0, head=2.0),
                   _tool((-0.3, -0.38, 1.16), 0.0, -90.0, hang, grip))
    lift = _pose(C._body(4.0, 0.0, head=0.0, hips=(0, 0, 0, 0, 0.02, 0.0)),
                 _tool((-0.3, -0.36, 1.42), 6.0, -90.0, cast, grip))
    throw = _pose(C._body(22.0, 0.0, head=4.0, hips=(3.0, 0, 0, 0, 0.0, -0.01)),
                  _tool((-0.3, _y(0.0), TOP + 0.24), 0.0, -90.0, laid, grip))
    lay = _pose(C._body(20.0, 0.0, head=-2.0, hips=(4.0, 0, 0, 0, 0.03, -0.02)),
                _tool((-0.3, _y(0.04), TOP + 0.08), 0.0, -90.0, laid, grip))
    smooth = _pose(C._body(17.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.03, -0.015)),
                   _tool((-0.3, _y(-0.16), TOP + 0.08), 0.0, -90.0, drag, grip))
    return [(0.0, gather), (0.24, lift), (0.42, throw), (0.56, lay), (0.8, smooth)]


def table_shroud(t: float) -> dict:
    """54 frames = 1.8 s loop: the linen between both fists along its top edge - gathered in front of him,
    lifted, cast forward over the body, laid down and smoothed back towards him."""
    return rig.keyed(t, _shroud_keys())


SNIP_BITE = 0.5


def _snip_keys() -> list:
    face = (0.0, 0.0, 1.0)
    grip = (0.03, 0.0, 1.0, 0.0)
    body = C._body(16.0, 0.0, head=-2.0, hips=(3.0, 0, 0, 0, 0.02, -0.01))
    left = {"l_at": (0.08, -HEAD_D + 0.2, FACE + 0.1), "l_w": (1.0,), "r_at": tuple(C.FIST[-1]), "r_w": (0.0,)}
    open_ = _pose(body, left, _tool((-0.08, -HEAD_D + 0.16, FACE + 0.08), -6.0, 150.0, face, grip))
    cut = _pose(body, left, _tool((-0.05, -HEAD_D + 0.18, FACE + 0.07), -10.0, 140.0, face, grip))
    return [(0.0, open_), (SNIP_BITE, cut), (0.7, open_)]


def table_snip(t: float) -> dict:
    """27 frames = 0.9 s loop (the snip cue): at the head end the left hand lifts the braid, the shears close
    on it (SNIP_BITE) and open again."""
    return rig.keyed(t, _snip_keys())


PULL_BITE = 0.55


def _pull_keys() -> list:
    face = (0.0, -1.0, 0.0)
    grip = (0.04, 0.0, 1.0, 0.0)
    body = C._body(24.0, 0.0, head=-4.0, hips=(4.0, 0, 0, 0, 0.03, -0.02))
    away = {"head": (0.0, 0.0, -24.0)}     # "du siehst dabei nicht hin"
    left = {"l_at": (0.08, -HEAD_D + 0.06, FACE), "l_w": (1.0,), "r_at": tuple(C.FIST[-1]), "r_w": (0.0,)}
    set_ = _pose(body, away, left, _tool((-0.03, -HEAD_D - 0.08, FACE + 0.15), -76.0, 180.0, face, grip))
    grip_ = _pose(body, away, left, _tool((-0.03, -HEAD_D - 0.08, FACE + 0.12), -78.0, 176.0, face, grip))
    pulled = _pose(C._body(20.0, 0.0, head=-6.0, hips=(3.0, 0, 0, 0, 0.035, -0.015)), away, left,
                   _tool((-0.05, -HEAD_D - 0.02, FACE + 0.23), -60.0, 192.0, face, grip))
    return [(0.0, set_), (0.3, grip_), (PULL_BITE, grip_), (0.72, pulled), (0.9, set_)]


def table_pull(t: float) -> dict:
    """45 frames = 1.5 s loop: at the head end the pliers set on, a short twist and a pull (PULL_BITE, the
    anatomy cue), the left hand on the forehead; his face is turned away."""
    return rig.keyed(t, _pull_keys())


# --- the small tools out of / back into the tool bag ---------------------------------------------------

def _hand_ready() -> dict:
    """The pose the hand tools are drawn into (the table clips cross-fade from it)."""
    return _pose(C._body(18.0, 0.0, head=6.0), _hands(),
                 _tool((-0.18, -0.44, 1.02), -35.0, 180.0, (0.0, 0.0, 1.0), (0.04, 0.0, 1.0, 0.0)))


def _hand_bag_keys() -> list:
    ready = _hand_ready()
    grip = (0.04, 0.0, 0.0, 0.0)
    rest = _pose({"leg_l": (9.0, 0.0, 0.0), "leg_r": (-9.0, 0.0, 0.0)}, _hands(),
                 T._w((-0.36, 0.0, 0.7), T.BAG_DIR[0], T.BAG_DIR[1], (1.0, 0.0, 0.0), grip, w_home=(1.0,)))
    bag = _pose(C._body(6.0, -6.0), _hands(), {"arm_r": (10.0, 0.0, -10.0)},
                T._w((-0.4, 0.05, 0.76), T.BAG_DIR[0], T.BAG_DIR[1], (1.0, 0.0, 0.0), (0.04, 0.0, 1.0, 0.0)))
    lift = _pose(C._body(10.0, -4.0), _hands(),
                 _tool((-0.3, -0.25, 0.95), -10.0, 170.0, (0.0, 0.0, 1.0), (0.04, 0.0, 1.0, 0.0)))
    return [rest, bag, lift, ready]


HAND_BAG = 0.36          # the fist at the bag: the tool appears (ToolAnimConfig.draw_show_at)
HAND_STOW_BAG = 0.7      # back at the bag: it disappears (ToolAnimConfig.stow_hide_at)


def hand_draw(t: float) -> dict:
    """10 frames one-shot: the right hand to the tool bag at the hip, the small tool out (HAND_BAG) and up
    in front of him (the table clips cross-fade in from there)."""
    rest, bag, lift, ready = _hand_bag_keys()
    return rig.keyed(t, [(0.0, rest), (HAND_BAG, bag), (0.66, lift), (1.0, ready)], wrap=False)


def hand_stow(t: float) -> dict:
    """10 frames one-shot: the draw backwards (hidden at HAND_STOW_BAG)."""
    rest, bag, lift, ready = _hand_bag_keys()
    return rig.keyed(t, [(0.0, ready), (0.34, lift), (HAND_STOW_BAG, bag), (1.0, rest)], wrap=False)


def _stow_walk(stow_fn):
    """One walk cycle: the stow over walking legs, the arms settling into the walk swing at the end."""
    def fn(t: float) -> dict:
        g = C.walk(t)
        upper = stow_fn(min(1.0, t / 0.85))
        out = dict(g)
        fade = rig.ease((t - 0.7) / 0.3)
        for bone in ("arm_l", "arm_r", "spine", "head"):
            a = tuple(upper.get(bone, rig.ZERO)) + rig.ZERO[len(upper.get(bone, rig.ZERO)):]
            b = tuple(g.get(bone, rig.ZERO)) + rig.ZERO[len(g.get(bone, rig.ZERO)):]
            out[bone] = tuple(x + (y - x) * fade for x, y in zip(a, b))
        for k in ("w_fist", "w_dir", "w_axis", "w_home", "r_at", "l_at"):
            if k in upper:
                out[k] = upper[k]
        out["w_grip"] = tuple(v * (1.0 - fade) if i in (2, 3) else v for i, v in enumerate(upper["w_grip"]))
        for k in ("r_w", "l_w"):
            out[k] = (float(upper.get(k, (0.0,))[0]) * (1.0 - fade),)
        return out
    return fn


hand_stow_walk = _stow_walk(hand_stow)


# --- other hand work ----------------------------------------------------------------------------------

def pray(t: float) -> dict:
    """90 frames = 3 s loop: standing still, the hands folded in front, the head bowed, slow breathing; once
    the head sinks a little lower."""
    sink = 4.0 * math.sin(rig.TAU * t) ** 2
    return rig.add(rig.breathe(t, 0.7), rig.bowed(20.0 + sink, 5.0), rig.folded(28.0, 26.0),
                   {"feet": {"leg_l": 0.0, "leg_r": 0.0}})


WRITE_DESK = 0.86


def write(t: float) -> dict:
    """45 frames = 1.5 s loop: at the desk, bent over the page; the left hand holds it flat, the right writes a
    line in small strokes and moves on."""
    s = math.sin(rig.TAU * t * 3.0)
    x = -0.06 - 0.1 * rig.ease(t / 0.8) + 0.1 * rig.ease((t - 0.8) / 0.2)
    body = C._body(24.0, 2.0, head=12.0, hips=(3.0, 0, 0, 0, 0.02, -0.01))
    return _pose(body, rig.breathe(t, 0.4), _hands((x, -0.5 + 0.01 * s, WRITE_DESK + 0.02 + 0.012 * abs(s)),
                                                   (0.16, -0.46, WRITE_DESK)))


def bench_work(t: float) -> dict:
    """45 frames = 1.5 s loop: fine work at a bench: both hands close together in front, by turns holding and
    turning (filling a jar, binding a bundle), the head low over it."""
    body = C._body(22.0, 0.0, head=12.0, hips=(3.0, 0, 0, 0, 0.02, -0.01))
    a = _pose(body, _hands((-0.08, -0.5, 0.98), (0.08, -0.5, 0.94)))
    b = _pose(C._body(24.0, -4.0, head=12.0, hips=(3.0, 0, 0, 0, 0.02, -0.012)),
              _hands((-0.06, -0.54, 0.92), (0.1, -0.47, 1.0)))
    c = _pose(C._body(22.0, 4.0, head=10.0, hips=(3.0, 0, 0, 0, 0.02, -0.01)),
              _hands((-0.12, -0.48, 1.0), (0.04, -0.52, 0.95)))
    return rig.keyed(t, [(0.0, a), (0.35, b), (0.68, c)])


def place_low(t: float) -> dict:
    """48 frames = 1.6 s loop: he bows deep from the hips (the hips back, the planted legs read as bent
    knees), both hands go down in front to set something down (or take it up), a moment, and up again."""
    up = _pose(C._body(8.0, 0.0), _hands((-0.14, -0.4, 0.86), (0.14, -0.4, 0.86), 0.6, 0.6))
    bow = _pose({"spine": (52.0, 0.0, 0.0), "head": (-18.0, 0.0, 0.0), "hips": (8.0, 0.0, 0.0, 0.0, 0.05, -0.1)},
                _hands((-0.14, -0.62, 0.42), (0.14, -0.62, 0.42)))
    set_ = _pose({"spine": (54.0, 0.0, 0.0), "head": (-14.0, 0.0, 0.0), "hips": (8.0, 0.0, 0.0, 0.0, 0.05, -0.11)},
                 _hands((-0.16, -0.66, 0.36), (0.12, -0.66, 0.38)))
    return rig.keyed(t, [(0.0, up), (0.32, bow), (0.5, set_), (0.66, set_), (0.92, up)])


def weed_pull(t: float) -> dict:
    """45 frames one-shot (like kneel_place): down at the grave, the right hand grips a weed in the mound,
    pulls it out and tosses it aside - twice -, and up again; the left hand rests on the knee."""
    down = {"hips": (6.0, 0.0, 0.0, 0.0, 0.04, -0.3), "spine": (32.0, 0.0, 0.0), "head": (-6.0, 0.0, 0.0),
            "arm_r": (-64.0, -4.0, 4.0), "arm_l": (-30.0, 12.0, 0.0), "leg_l": (14.0, 0.0, -2.0),
            "leg_r": (6.0, 0.0, 2.0), "feet": {"leg_l": 0.0, "leg_r": 0.0}}
    grip = rig.add(down, {"arm_r": (-8.0, 0.0, 0.0), "spine": (4.0, 0.0, 0.0)})
    pull = rig.add(down, {"arm_r": (18.0, 0.0, -12.0), "spine": (-4.0, 0.0, -8.0)})
    rest = {"feet": {"leg_l": 0.0, "leg_r": 0.0}}
    return rig.keyed(t, [(0.0, rest), (0.22, down), (0.34, grip), (0.46, pull), (0.56, grip), (0.68, pull),
                         (0.78, down), (1.0, rest)], wrap=False)


def fill_can(t: float) -> dict:
    """40 frames loop: at the rain barrel, the can in the right hand dipped in (ph_tool_watering_can at
    can_grip, tilted forward so it fills), a slow bob; the left hand on the barrel's rim."""
    s = math.sin(rig.TAU * t)
    return _pose(rig.breathe(t, 0.6), C._body(26.0, 0.0, head=8.0, hips=(3.0, 0, 0, 0, 0.02, -0.01)),
                 {"arm_r": (-58.0 + 4.0 * s, -6.0, 4.0), "arm_l": (-64.0, 14.0, 0.0)})


# --- the rake ---------------------------------------------------------------------------------------

RAKE_GRIP = (0.24, 0.72, 1.0, 1.0)     # the right fist high on the handle, the left lower down


def _rake_pose(spine, twist, fist, head) -> dict:
    elev, az = _toward(fist, head)
    return _pose(C._body(spine, twist), _hands(),
                 _tool(fist, elev, az, (0.0, 0.0, -1.0), RAKE_GRIP))


def _rake_keys() -> list:
    out = _rake_pose(18.0, 4.0, (-0.18, -0.42, 1.0), (-0.02, -1.48, 0.08))
    on = _rake_pose(20.0, 4.0, (-0.18, -0.44, 0.96), (-0.02, -1.44, 0.0))
    pulled = _rake_pose(10.0, -4.0, (-0.2, -0.22, 0.92), (-0.06, -1.0, 0.0))
    lift = _rake_pose(12.0, 0.0, (-0.2, -0.26, 1.0), (-0.05, -1.08, 0.14))
    return [(0.0, out), (0.15, on), (0.62, pulled), (0.78, lift)]


RAKE_BITE = 0.15


def rake(t: float) -> dict:
    """36 frames = 1.2 s loop: the rake set down far out (RAKE_BITE) and drawn towards him through the leaves,
    lifted and pushed out again."""
    return rig.keyed(t, _rake_keys())


def _rake_bring(reverse: bool):
    def fn(t: float) -> dict:
        first = _rake_keys()[0][1]
        rest = dict(first)
        rest.update(_pose({"leg_l": (9.0, 0.0, 0.0), "leg_r": (-9.0, 0.0, 0.0)}, _hands()))
        for k in ("spine", "head", "arm_r", "arm_l", "hips"):
            rest.pop(k, None)
        rest["w_grip"] = (RAKE_GRIP[0], RAKE_GRIP[1], 0.0, 0.0)
        keys = [(0.0, rest), (1.0, first)]
        if reverse:
            keys = [(0.0, first), (1.0, rest)]
        return rig.keyed(t, keys, wrap=False)
    return fn


rake_take = _rake_bring(False)
rake_put = _rake_bring(True)
rake_put_walk = _stow_walk(rake_put)


# --- the clip list -------------------------------------------------------------------------------------

def actions() -> list:
    """(name, frames, pose fn, post hook) of every work clip (rig.add_action)."""
    table = [("table_examine-loop", 48, table_examine), ("table_search-loop", 36, table_search),
             ("table_wash-loop", 42, table_wash), ("table_cut-loop", 45, table_cut),
             ("table_comb-loop", 36, table_comb), ("table_smoke-loop", 48, table_smoke),
             ("table_shroud-loop", 54, table_shroud), ("table_snip-loop", 27, table_snip),
             ("table_pull-loop", 45, table_pull),
             ("hand_draw", 10, hand_draw), ("hand_stow", 10, hand_stow), ("hand_stow_walk", 16, hand_stow_walk),
             ("pray-loop", 90, pray), ("write-loop", 45, write), ("bench_work-loop", 45, bench_work),
             ("place_low-loop", 48, place_low), ("weed_pull", 45, weed_pull), ("fill_can-loop", 40, fill_can),
             ("rake-loop", 36, rake), ("rake_take", 8, rake_take), ("rake_put", 8, rake_put),
             ("rake_put_walk", 16, rake_put_walk)]
    return [(name, frames, fn, _work(fn, name)) for name, frames, fn in table]


def marker(arm) -> None:
    """The hand tools' marker on the tool bone, in the bone's rest frame (tool space = bone space)."""
    import bpy
    e = bpy.data.objects.new(MARKER, None)
    bpy.context.collection.objects.link(e)
    e.parent = arm
    e.parent_type = "BONE"
    e.parent_bone = C.TOOL
    bpy.context.view_layer.update()
    e.matrix_world = T.REST.copy()

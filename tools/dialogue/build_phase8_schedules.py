"""Phase 8 schedule entries (docs/PHASE8_DESIGN.md §2.1.4, §2.5.1, §2.6, §2.7, §1.6; P6 owns data/npc/*_schedule.tres).

    python3 tools/dialogue/retime_walks.py        # first: the Phase-7 base entries (the shadow copies below read them)
    python3 tools/dialogue/build_phase8_schedules.py
    python3 tools/dialogue/build_phase9_schedules.py

New schedules: beggar (Veit), peddler (Hanne), apprentice (Jakob's village part – his working day on the hill
is the runtime schedule of P3). Existing villager schedules get today_flag overlays only (idempotent, sub_resource
prefix "p8_"); on a day without the flag nothing changes (ScheduleResolver skips the entries – Phase 7 bitgleich):
  visit_<npc>_day          – Esch, Theres, Liesel visit their dead (§2.1.4; set by Visitors' plan, P2)
  fest_kathrein_day        – the dance in the Holderkrug 19:00–23:00 (§2.7.1; Festivals, P4)
  fest_lights_day          – the gathering at the Holderbrücke, up the hill, back after the descent
                             (§2.7.2; the procession on the cemetery is P4's runtime schedule)
  night_<path>_<npc>_day   – the night visits at the sick light (§1.6; NightPaths, P7 – the day of the visit's
                             enter minute, e.g. night_np_ott_washer_day = the calendar day of 02:40)
  beggar_gate_day          – Veit at the cemetery gate on odd days (§2.6; Wanderers, P7)
  peddler_day              – Hanne's day (day % 6 == 1, §2.6; Wanderers, P7)
  apprentice_off_day       – Jakob's free day in the inn (§2.5.1; Apprentice, P3)
  meet_<npc>_day           – a friendship meeting on the hill (W3 QA8-03; Orders, conditions.schedule_flag):
                             Fenner at l_12 (of_fenner_2), Rosine at Jakob's bench (of_rosine_3)
Waypoints of W-Welt (§4.2–§4.6): veit_gate, peddler_gate, lights_gate, gv_<plot>, v_church_step, v_bridge_sit,
v_well_peddler, v_remise_sleep, v_peddler_in, v_peddler_out, v_in_inn_jakob, v_ott_door,
v_kehr_door; the dance places v_in_inn_fest_1…4 are a P6 request to W-Welt (D6 Tanzfläche).

G9 Gehtempo (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1; tools/dialogue/walk_tempo.py): every walk takes the
minutes of its polyline at NpcConfig.walk_m_per_minute (0.8 m per game minute = 1.6 m/s real; the cart 0.55). The
times the systems need stay – the arrival at a stay (a visit, a meeting, a knock, the dance, the procession at the
graves) and the departure where a system ends a window (the end of a visit, of a meeting, Hanne's well, Veit's church
step); the walk before an arrival leaves earlier (walk_to). Between the village (v_road_in) and the hill (road_end) the
figure is off the map for GAP minutes (the Kutschweg). A plain entry that starts while an overlay walk is still on its
way does not cut it (ScheduleResolver lets the walk go on), so shadow() copies only the overlay's stays.
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import walk_tempo as wt  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NPC = os.path.join(ROOT, "data", "npc")
P = "p8_"
ENTRY_SCRIPT = "res://src/systems/npc/schedule_entry.gd"
SCHEDULE_SCRIPT = "res://src/systems/npc/npc_schedule.gd"
DAY = 1440
## Off the map between v_road_in (village) and road_end (hill): the Kutschweg.
GAP = 5


def q(s):
    return json.dumps(s, ensure_ascii=False)


class E:
    def __init__(self, start, path, activity="idle", animation="idle", travel=0, dialogue="", visible=True, region="village",
                 flag=""):
        self.start, self.path, self.activity, self.animation = start % DAY, path, activity, animation
        self.travel, self.dialogue, self.visible, self.region, self.flag = travel, dialogue, visible, region, flag

    @property
    def arrive(self):
        return self.start + self.travel

    def block(self, sid, ext):
        lines = ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("%s")' % ext]
        if self.start:
            lines.append("start_minute = %d" % self.start)
        if self.travel:
            lines.append("travel_minutes = %d" % self.travel)
        if self.activity != "idle":
            lines.append('activity = &"%s"' % self.activity)
        if self.animation != "idle":
            lines.append('animation = &"%s"' % self.animation)
        lines.append("path = PackedStringArray(%s)" % ", ".join(q(p) for p in self.path))
        if self.dialogue:
            lines.append('dialogue_id = &"%s"' % self.dialogue)
        if not self.visible:
            lines.append("visible = false")
        if self.region:
            lines.append('region = &"%s"' % self.region)
        if self.flag:
            lines.append('today_flag = &"%s"' % self.flag)
        return "\n".join(lines)


# W-Welt (W2): the graveyard walks follow the baked visitor routes of data/world/graveyard_layout.json (road_end ->
# ... -> gate_inside -> vw_* -> the place) and take the polyline time (NpcConfig.walk_m_per_minute): the figure
# arrives at the stay's minute and leaves the hill at its minute - no straight line through fence and graves.
LAYOUT = wt.GRAVEYARD
WALK_M_PER_MINUTE = wt.WALK


def _layout():
    with open(LAYOUT, encoding="utf-8") as f:
        return json.load(f)


def _points():
    return wt.GY


def route_up(target):
    """The baked route road_end -> ... -> target (gv_<grave> or a waypoint id) and its walking minutes."""
    path = wt.route_up(target)
    return path, wt.minutes(path, "")


def village_minutes(path):
    """Walking minutes of a village polyline (data/world/village_layout.json, NpcConfig.walk_m_per_minute)."""
    return wt.minutes(path, "village")


def walk(start, path, minutes=None, flag="", region="village", animation="walk"):
    """A walk from `start`; `minutes` None = the polyline's minutes at the pace, else checked against the band."""
    if minutes is None:
        minutes = wt.minutes(path, region, animation)
    elif not wt.in_band(path, region, minutes, animation):
        raise ValueError("walk %s at %d: %.1f m in %d min is out of the G9 band" % (path, start, wt.length(path, region), minutes))
    return E(start, path, "walk", animation, minutes, "", True, region, flag)


def walk_to(arrive, path, flag="", region="village", animation="walk"):
    """A walk that arrives at `arrive` (it leaves the polyline's minutes earlier)."""
    minutes = wt.minutes(path, region, animation)
    return walk(arrive - minutes, path, minutes, flag, region, animation)


def stay(start, at, dialogue="", flag="", region="village", animation="idle", activity="idle"):
    return E(start, [at], activity, animation, 0, dialogue, True, region, flag)


def hide(start, at, flag="", region="village"):
    return E(start, [at], "home", "idle", 0, "", False, region, flag)


def arrive_hide(w, at=None):
    """Gone at the end of walk `w` – none when the walk runs past midnight (the plain 00:00 entry takes over then)."""
    if w.start + w.travel >= DAY:
        return []
    return [hide(w.arrive, at or w.path[-1], w.flag, w.region)]


def visit(target, arrive, leave, flag, dialogue, animation, activity="mourn", walk_anim="walk"):
    """Up the baked route (arriving at `arrive`), stay, back down from `leave`, gone at the road end."""
    path, _ = route_up(target)
    at = path[-1]
    down = walk(leave, list(reversed(path)), None, flag, region="", animation=walk_anim)
    return [
        walk_to(arrive, path, flag, region="", animation=walk_anim),
        stay(arrive, at, dialogue, flag, region="", animation=animation, activity=activity),
        down,
        hide(down.arrive, "road_end", flag, region=""),
    ]


def up_and_down(flag, out_path, hill, back_path, back_stay):
    """A trip from the village to the hill: `hill` (the graveyard entries, the first a walk from road_end, the last the
    hide at road_end); before it the village way `out_path` (off the map GAP minutes before the hill walk), after it
    `back_path` (GAP minutes after the hill hide), then `back_stay` (an E, its start set to the arrival)."""
    out = walk_to(hill[0].start - GAP, out_path, flag)
    back = walk(hill[-1].start + GAP, back_path, None, flag)
    back_stay.start = back.arrive % DAY
    back_stay.flag = flag
    return [out, hide(out.arrive, out_path[-1], flag)] + hill + [back, back_stay]


def meet_up(flag, target, arrive, leave, dialogue, out_path, back_path, back):
    """W3 (QA8-03): a meet order on the hill (Orders sets `flag` = the day while it is accepted): from the village
    over the bridge, up the baked route to `target` (arriving at `arrive`), stay, back down from `leave`, then over
    `back_path` to `back` (an E for the rest of the afternoon). `target` "<route>:<stop>" ends the route at <stop>
    (a free spot next to a bench instead of the seat)."""
    route, stop = (target.split(":") + [""])[:2]
    path, _ = route_up(route)
    if stop:
        path = path[:path.index(stop) + 1]
    down = walk(leave, list(reversed(path)), None, flag, region="")
    hill = [
        walk_to(arrive, path, flag, region=""),
        stay(arrive, path[-1], dialogue, flag, region=""),
        down,
        hide(down.arrive, "road_end", flag, region=""),
    ]
    return up_and_down(flag, out_path, hill, back_path, back)


def shadow(base_starts, entries):
    """A base entry that starts inside a flag overlay would win over it (a later start) – each such start gets a flag
    copy of the overlay entry active there. Only the overlay's stationary / hidden entries are copied: a base start
    inside an overlay walk does not cut the walk (ScheduleResolver, G9) – the walk must be followed by an overlay
    entry (its arrival), which this checks."""
    out = list(entries)
    flags = {}
    for e in entries:
        if e.flag:
            flags.setdefault(e.flag, []).append(e)
    for flag, group in flags.items():
        group = sorted(group, key=lambda e: e.start)
        first, last = group[0].start, group[-1].start
        starts = {e.start for e in group}
        for s in sorted(base_starts):
            if not (first < s < last) or s in starts:
                continue
            active = [e for e in group if e.start <= s][-1]
            if active.travel > 0 and active.start + active.travel > s:
                assert active.start + active.travel <= last or active.start + active.travel >= DAY, \
                    "%s: base start %d inside the closing walk at %d" % (flag, s, active.start)
                continue
            copy = E(s, [active.path[-1]], active.activity if active.travel == 0 else "idle",
                     active.animation if active.travel == 0 else "idle", 0, active.dialogue, active.visible, active.region, flag)
            out.append(copy)
            starts.add(s)
    return out


def write_new(npc_id, display, entries):
    entries = shadow([e.start for e in entries if not e.flag], entries)
    blocks = [e.block("%s%s_%02d" % (P, npc_id, i + 1), "1") for i, e in enumerate(entries)]
    refs = ", ".join('SubResource("%s%s_%02d")' % (P, npc_id, i + 1) for i in range(len(entries)))
    text = ('[gd_resource type="Resource" script_class="NpcSchedule" format=3]\n\n'
            '[ext_resource type="Script" path="%s" id="1"]\n[ext_resource type="Script" path="%s" id="2"]\n\n'
            % (ENTRY_SCRIPT, SCHEDULE_SCRIPT) + "\n\n".join(blocks) +
            '\n\n[resource]\nscript = ExtResource("2")\nnpc_id = &"%s"\ndisplay_name = %s\nentries = Array[ExtResource("1")]([%s])\n'
            % (npc_id, q(display), refs))
    with open(os.path.join(NPC, npc_id + "_schedule.tres"), "w", encoding="utf-8") as f:
        f.write(text)


def patch(npc_id, entries):
    path = os.path.join(NPC, npc_id + "_schedule.tres")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    ext = re.search(r'\[ext_resource type="Script" path="%s" id="([^"]+)"\]' % re.escape(ENTRY_SCRIPT), text).group(1)
    head, _, rest = text.partition("\n\n")
    blocks = [b.strip("\n") for b in rest.split("\n\n") if b.strip()]
    blocks = [b for b in blocks if not re.match(r'\[sub_resource type="Resource" id="%s' % P, b)]
    ref_re = re.compile(r'(, )?SubResource\("%s[^"]*"\)' % P)
    blocks = [ref_re.sub("", b) for b in blocks]
    base_starts = []
    for b in blocks:
        if 'script = ExtResource("%s")' % ext in b and "today_flag" not in b:
            m = re.search(r"^start_minute = (\d+)$", b, re.M)
            base_starts.append(int(m.group(1)) if m else 0)
    entries = shadow(base_starts, entries)
    new = [e.block("%s%s_%02d" % (P, npc_id, i + 1), ext) for i, e in enumerate(entries)]
    refs = ['SubResource("%s%s_%02d")' % (P, npc_id, i + 1) for i in range(len(entries))]
    ri = [i for i, b in enumerate(blocks) if b.startswith("[resource]")][0]
    res = blocks[ri]
    m = re.search(r'^entries = Array\[ExtResource\("[^"]+"\)\]\(\[(.*)\]\)$', res, re.M)
    existing = [r.strip() for r in m.group(1).split(",") if r.strip()]
    res = res[:m.start()] + 'entries = Array[ExtResource("%s")]([%s])' % (ext, ", ".join(existing + refs)) + res[m.end():]
    blocks[ri] = res
    first = 1 if blocks[0].startswith("[ext_resource") else 0
    out = blocks[:first] + new + blocks[first:]
    with open(path, "w", encoding="utf-8") as f:
        f.write(head + "\n\n" + "\n\n".join(out) + "\n")


# --- shared overlays ---------------------------------------------------------------------------------------

DOOR = {"v_in_inn_bar": "v_inn_door", "v_in_inn_table": "v_inn_door", "v_in_inn_corner": "v_inn_door",
        "v_in_office_desk": "v_office_door", "v_in_surgery_desk": "v_surgery_door", "v_in_surgery_lectern": "v_surgery_door",
        "v_in_church_altar": "v_church_door", "v_in_inn_jakob": "v_inn_door"}
LIGHTS = "fest_lights_day"
KATHREIN = "fest_kathrein_day"
TO_ROAD = ["v_inn_door", "v_anger_w", "v_bridge", "v_road_in"]
FROM_ROAD = list(reversed(TO_ROAD))


## The gathering place of the Lichtgang at the Holderbrücke: W-Welt names it v_lights_gather (§4.6); until that
## waypoint exists the bridge itself (v_bridge) is used – the routes run over checked village segments.
GATHER = "v_bridge"
TO_BRIDGE = {"v_inn_door": ["v_anger_w"], "v_anvil": ["v_anger_w"], "v_board": ["v_anger_w"], "v_shop_window": ["v_well"],
             "v_church_door": ["v_well"], "v_dorn_door": ["v_well"], "v_surgery_door": ["v_well"], "v_house_n": ["v_anger_w"]}
## G9: the procession reaches the graves at at_graves (fest_lights.tres, 17:00) and leaves them from leave (18:00–18:30);
## the longest baked way up (the Lindenacker) sets when the village must have gone up and when it is back.
LIGHTS_AT_GRAVES = 1020
LIGHTS_LEAVE_LAST = 1110
HILL_MAX = max(wt.minutes(r, "") for k, r in wt.ROUTES.items()
               if k.split("_")[0] in ("plot", "old", "h", "l", "lights") and all(not p.startswith("@") for p in r))
LIGHTS_UP = [GATHER, "v_road_in"]
## Off at the road end before the first one starts up the hill …
LIGHTS_HIDE = LIGHTS_AT_GRAVES - HILL_MAX - GAP
## … at the bridge half an hour before (16:00–16:30 before G9) …
LIGHTS_GATHER = LIGHTS_HIDE - village_minutes(LIGHTS_UP) - 30
## … and back over the bridge once the last one is down.
LIGHTS_BACK = LIGHTS_LEAVE_LAST + HILL_MAX + GAP


def lights(home, back_to, back_dialogue="", back_activity="idle", back_anim="idle", back_visible=True, home_at=-1):
    """§2.7.2: from `home` to the Holderbrücke with the lanterns, up the hill (hidden in the village – the procession is
    P4's runtime schedule on the cemetery), back after the descent. G9: the procession is at the graves at 17:00 – the
    village gathers LIGHTS_GATHER (14:41), goes up LIGHTS_HIDE (15:17) and is back from LIGHTS_BACK (20:13); who would
    be at home by then goes home (back_visible False), `home_at` ≥ 0 = gone at that minute (after the inn)."""
    out_from = DOOR.get(home, home)
    back_door = DOOR.get(back_to, back_to)
    up = walk(LIGHTS_GATHER + 30, LIGHTS_UP, None, LIGHTS, animation="lantern_walk")
    back = walk(LIGHTS_BACK, ["v_road_in", GATHER] + TO_BRIDGE[back_door] + [back_door], None, LIGHTS, animation="lantern_walk")
    entries = [
        walk_to(LIGHTS_GATHER, [out_from] + TO_BRIDGE[out_from] + [GATHER], LIGHTS),
        stay(LIGHTS_GATHER, GATHER, "", LIGHTS, animation="idle"),
        up,
        hide(up.arrive, "v_road_in", LIGHTS),
        back,
    ]
    last = E(back.arrive, [back_to], back_activity if back_visible else "home", back_anim if back_visible else "idle", 0,
             back_dialogue if back_visible else "", back_visible, "village", LIGHTS)
    entries.append(last)
    if home_at >= 0:
        entries.append(hide(home_at, back_door, LIGHTS))
    return entries


def innkeeper():
    # W3 (QA8-03): of_rosine_3 „Oben bei Jakob" – Rosine at Jakob's bench 15:00–15:40 (meet window 900–940),
    # standing beside it (vw_39), back behind the bar after the way down.
    patch("innkeeper", lights("v_in_inn_bar", "v_in_inn_bar", "v_innkeeper", "shop", "polish_mug") + meet_up(
        "meet_innkeeper_day", "apprentice_lunch:vw_39", 895, 940, "v_innkeeper", TO_ROAD, FROM_ROAD,
        E(0, ["v_in_inn_bar"], "shop", "polish_mug", 0, "v_innkeeper")))


def smith():
    v = "visit_smith_day"
    # §2.1.4: Esch at old_01 (Wendel Gratz) 13:40–14:30; the smithy is shut while he is up there (G9: from the anvil
    # before noon, back at the anvil in the afternoon).
    hill = visit("gv_old_01", 820, 870, v, "v_smith", "mourn_stand")
    patch("smith", up_and_down(v, ["v_anvil", "v_anger_w", "v_bridge", "v_road_in"], hill,
                               ["v_road_in", "v_bridge", "v_anger_w", "v_anvil"], E(0, ["v_anvil"], "shop", "work", 0, "v_smith")) + [
        # §2.7.1 Kathreintanz.
        walk_to(1140, ["v_linden", "v_inn_door"], KATHREIN),
        stay(1140, "v_in_inn_fest_1", "v_smith", KATHREIN),
        hide(1380, "v_house_n", KATHREIN),
    ] + lights("v_anvil", "v_house_n", back_visible=False))


def grocer():
    v = "visit_grocer_day"
    # §2.1.4: Theres at old_08 (Dorothee Mahn) 14:40–15:30, kneeling, then waiting for a word (G8 Runde 1: 30 + look 2
    # + VisitorConfig.wait_minutes_villager 18); the shop is shut while she is up there.
    hill = visit("gv_old_08", 880, 930, v, "v_grocer", "kneel")
    patch("grocer", up_and_down(v, ["v_shop_window", "v_well", "v_bridge", "v_road_in"], hill,
                                ["v_road_in", "v_bridge", "v_well", "v_shop_window"], E(0, ["v_shop_window"], "shop", "work", 0, "v_grocer")) + [
        walk_to(1140, ["v_shop_window", "v_inn_door"], KATHREIN),
        stay(1140, "v_in_inn_fest_2", "v_grocer", KATHREIN),
        hide(1380, "v_shop_window", KATHREIN),
    ] + lights("v_shop_window", "v_shop_window", back_visible=False))


def mayor():
    # W3 (QA8-03): of_fenner_2 „Ein Platz mit Blick" – Fenner at l_12 16:00–16:40 (meet window 960–1000). G9: from the
    # Amtshaus after lunch, back down the long way round the Lindenacker – straight to his table in the inn (as every
    # evening).
    patch("mayor", meet_up(
        "meet_mayor_day", "gv_l_12", 955, 1000, "v_mayor",
        ["v_office_door", "v_well", "v_bridge", "v_road_in"], FROM_ROAD,
        E(0, ["v_in_inn_table"], "idle", "idle", 0, "v_mayor")) + [
        stay(1260, "v_in_inn_table", "v_mayor", KATHREIN),
        hide(1380, "v_office_door", KATHREIN),
    ] + lights("v_board", "v_board", "v_mayor", "idle", "proclaim"))


def night_visit(flag, home, way, knock, inside_until, dialogue, animation="walk"):
    """§1.6 a night visit at the sick light (NightPaths): to the door (arriving at the knock), knock, inside, out at the
    door for a word, home again."""
    there = [home] + way
    back = walk(inside_until + 2, list(reversed(there)), None, flag, animation=animation)
    return [
        walk_to(knock, there, flag, animation=animation),
        stay(knock, there[-1], "", flag, animation="knock"),
        hide(knock + 1, there[-1], flag),
        stay(inside_until, there[-1], dialogue, flag),
        back,
    ] + arrive_hide(back, home)


def priest():
    patch("priest", lights("v_in_church_altar", "v_in_inn_corner", "v_priest", home_at=1320)
          # §1.6 night visits (the Versehgang with the lantern).
          + night_visit("night_np_ott_priest_day", "v_church_door", ["v_well", "v_ott_lane_w", "v_ott_lane", "v_ott_door"], 1260, 1300,
                        "v_priest", "lantern_walk")
          + night_visit("night_np_kehr_priest_day", "v_church_door", ["v_well", "v_kehr_lane", "v_kehr_door"], 1260, 1290,
                        "v_priest", "lantern_walk"))


def surgeon():
    # §2.1.4 / §2.7.2: Quast never goes up – at the Lichtgang he waits at the bridge (G9: from the gathering on until his
    # evening at the bridge, when the plain day takes over).
    # He leaves when he is back from lunch (14:00) and comes to the gathering a little late.
    bridge_walk = 1086 - village_minutes(["v_surgery_door", "v_well", "v_bridge"])
    to_bridge = walk(840, ["v_surgery_door", "v_well", "v_bridge"], None, LIGHTS)
    entries = [
        to_bridge,
        stay(to_bridge.arrive, "v_bridge", "v_surgeon", LIGHTS),
        stay(bridge_walk, "v_bridge", "v_surgeon", LIGHTS),
    ]
    # W-Welt (W2): to the Otts between the surgery and the remise, to the Kehrs over the Anger.
    for path_id, door, way in (("np_ott", "v_ott_door", ["v_ott_lane_w", "v_ott_lane"]), ("np_kehr", "v_kehr_door", ["v_anger_w", "v_kehr_lane"])):
        entries += night_visit("night_%s_surgeon_day" % path_id, "v_surgery_door", way + [door], 1350, 1390, "v_surgeon")
    patch("surgeon", entries)


def washer():
    v = "visit_washer_day"
    f = "night_np_ott_washer_day"
    # The plain morning: to the wash place at 06:00, washing from 06:38 (tools/dialogue/retime_walks.py).
    wash_walk = 398 - village_minutes(["v_dorn_door", "v_wash"])
    # §2.1.4: Liesel at the Lindenacker 09:40–10:40 instead of the wake (the graves of both cottages – P2 picks the
    # grave at runtime; linden_spot is the data fallback). G8 Runde 1: until 12:00 – her round of up to six graves
    # (30 + 5 × 15 + look 2) and the wait for a word (VisitorConfig.wait_minutes_villager 18). G9: no washing that
    # morning – she leaves from home.
    hill = visit("linden_spot", 580, 720, v, "v_washer", "kneel")
    visit_day = [hide(wash_walk, "v_dorn_door", v)] + up_and_down(
        v, ["v_dorn_door", "v_well", "v_bridge", "v_road_in"], hill, ["v_road_in", "v_bridge", "v_well", "v_dorn_door"],
        E(0, ["v_dorn_door"], "home", "idle", 0, "", False))
    # §2.7.1: 20:00–21:00 at the dance.
    back = walk(1260, ["v_inn_door", "v_dorn_door"], None, KATHREIN)
    dance = [
        walk_to(1200, ["v_dorn_door", "v_inn_door"], KATHREIN),
        stay(1200, "v_in_inn_fest_3", "v_washer", KATHREIN),
        back,
        hide(back.arrive, "v_dorn_door", KATHREIN),
    ]
    # §1.6: the wake at the Otts' after the death (02:40–05:30); home to bed afterwards (no washing that morning).
    wake = night_visit(f, "v_dorn_door", ["v_well", "v_ott_lane_w", "v_ott_lane", "v_ott_door"], 160, 330, "v_washer")
    wake.append(hide(398, "v_dorn_door", f))
    patch("washer", visit_day + dance + wake + lights("v_dorn_door", "v_dorn_door", back_visible=False))


def carter():
    # Osric keeps his Phase-7 schedule (the carter fixture of W-Welt): on Kathrein he is in the inn from 22:00 as
    # every evening – he does not dance ("Ich fahr nur.", §8.2).
    patch("carter", [])


def beggar():
    g = "beggar_gate_day"
    # G9: Veit's places follow Wanderers (church step 08:00–11:30, the bridge 13:00–19:30, the well bench 21:00–23:30,
    # odd days the gate 13:40–16:00): he leaves the church step at 11:30 and the bridge at 19:30 (the supper at the
    # remise 17:00–18:06 is gone – the way there and back took longer than the meal), the bench at 23:29.
    up = walk_to(820, ["road_end", "road_mid", "gate_outside", "veit_gate"], g, region="", animation="walk_stiff")
    down = walk(960, ["veit_gate", "gate_outside", "road_mid", "road_end"], None, g, region="", animation="walk_stiff")
    lup = walk_to(1005, ["road_end", "road_mid", "gate_outside", "lights_gate"], LIGHTS, region="", animation="walk_stiff")
    ldown = walk(1110, ["lights_gate", "gate_outside", "road_mid", "road_end"], None, LIGHTS, region="", animation="walk_stiff")
    gate_out = walk_to(up.start - GAP, ["v_bridge_sit", "v_road_in"], g, animation="walk_stiff")
    gate_back = walk(down.arrive + GAP, ["v_road_in", "v_bridge_sit"], None, g, animation="walk_stiff")
    lights_out = walk_to(lup.start - GAP, ["v_bridge_sit", "v_road_in"], LIGHTS, animation="walk_stiff")
    lights_back = walk(ldown.arrive + GAP, ["v_road_in", "v_bridge_sit"], None, LIGHTS, animation="walk_stiff")
    church = walk(690, ["v_church_step", "v_well", "v_bridge_sit"], None, animation="walk_stiff")
    bench = walk(1170, ["v_bridge_sit", "v_well", "v_well_bench"], None, animation="walk_stiff")
    home = ["v_well_bench", "v_well", "v_remise_sleep"]
    night = walk(DAY - village_minutes(home), home, None, animation="walk_stiff")
    write_new("beggar", "Veit Ammer", [
        hide(0, "v_remise_sleep"),
        walk_to(480, ["v_remise_sleep", "v_anger_w", "v_church_step"], animation="walk_stiff"),
        stay(480, "v_church_step", "beggar", animation="sit_beg", activity="beg"),
        church,
        stay(church.arrive, "v_bridge_sit", "beggar", animation="sit_beg", activity="beg"),
        bench,
        stay(bench.arrive, "v_well_bench", "beggar", animation="sit_beg", activity="beg"),
        night,
        # Odd days 13:40–16:00 outside the cemetery gate (§2.6).
        gate_out,
        hide(gate_out.arrive, "v_road_in", g),
        up,
        stay(820, "veit_gate", "beggar", g, region="", animation="sit_ground", activity="beg"),   # W3: on the ground
        down,
        hide(down.arrive, "road_end", g, region=""),
        gate_back,
        stay(gate_back.arrive, "v_bridge_sit", "beggar", g, animation="sit_beg", activity="beg"),
        # The Lichtgang: no candle ("Meine liegen im Wasser."), he stands at the gate (lights_gate).
        lights_out,
        hide(lights_out.arrive, "v_road_in", LIGHTS),
        lup,
        stay(1005, "lights_gate", "beggar", LIGHTS, region=""),
        ldown,
        hide(ldown.arrive, "road_end", LIGHTS, region=""),
        lights_back,
        stay(lights_back.arrive, "v_bridge_sit", "beggar", LIGHTS, animation="sit_beg", activity="beg"),
    ])


def peddler():
    d = "peddler_day"
    # Every 6th day (§2.6, Wanderers): at the well 10:00–14:00, the cemetery gate 15:40–16:20, then up the forest path to
    # the west (Ilse's way). G9: over the bridge before 09:30, off from the well at 14:00, early at the gate.
    to_road = walk(840, ["v_well_peddler", "v_well", "v_bridge", "v_road_in"], None, d)
    up = walk(to_road.arrive + GAP, ["road_end", "road_mid", "gate_outside", "peddler_gate"], None, d, region="")
    west = walk(980, ["peddler_gate", "gate_outside", "peddler_west", "trader_spot", "trader_mid", "trader_far"], None, d, region="")
    write_new("peddler", "Hanne Vogelsang", [
        hide(0, "v_peddler_out"),
        walk_to(600, ["v_peddler_in", "v_bridge", "v_well", "v_well_peddler"], d),
        stay(600, "v_well_peddler", "peddler", d, animation="offer", activity="shop"),
        to_road,
        hide(to_road.arrive, "v_road_in", d),
        up,
        stay(up.arrive, "peddler_gate", "peddler", d, region="", animation="offer", activity="shop"),
        # W-Welt (W2): outside along the south fence to the west corner, then Ilse's way (not across the graves).
        west,
        hide(west.arrive, "trader_far", d, region=""),
    ])


## G9 – Jakob's day (Apprentice, data/config/apprentice_config.tres): on the hill he walks up from road_end at
## arrive_minute (07:30) to read the board at 08:25; in the village he leaves the inn GAP minutes and the way to the bridge
## before; of an evening he is back in the inn after the way down from the box (src/systems/apprentice/apprentice.gd
## computes the same from the world).
APPRENTICE_ARRIVE = 450
## ApprenticeConfig.end_minute 15:30, 10 minutes at the box, the way down from the box, the Kutschweg, the way to the inn.
APPRENTICE_EVENING = 930 + 10 + route_up("apprentice_box")[1] + GAP + village_minutes(FROM_ROAD)


def apprentice():
    off = "apprentice_off_day"
    leave = walk_to(APPRENTICE_ARRIVE - GAP, TO_ROAD)
    write_new("apprentice", "Jakob Wackernagel", [
        hide(0, "v_inn_door"),
        stay(leave.start - 15, "v_in_inn_jakob", "v_apprentice"),
        leave,
        hide(leave.arrive, "v_road_in"),
        stay(APPRENTICE_EVENING, "v_in_inn_sweep", "v_apprentice", animation="sweep"),
        hide(1260, "v_inn_door"),
        # The free day (§2.5.1: "Jakob hilft heute im Krug").
        stay(leave.start, "v_in_inn_jakob", "v_apprentice", off, animation="talk"),
        stay(APPRENTICE_EVENING, "v_in_inn_jakob", "v_apprentice", off, animation="talk"),
        # Kathreintanz until 23:00; the Lichtgang: he carries his mother's lantern.
        stay(1260, "v_in_inn_jakob", "v_apprentice", KATHREIN),
        hide(1380, "v_inn_door", KATHREIN),
    ] + lights("v_in_inn_jakob", "v_in_inn_jakob", "v_apprentice", "idle", "talk", home_at=1320))


def main():
    for fn in (innkeeper, smith, grocer, mayor, priest, surgeon, washer, carter, beggar, peddler, apprentice):
        fn()
    print("Phase-8 schedules written to", NPC)


if __name__ == "__main__":
    main()

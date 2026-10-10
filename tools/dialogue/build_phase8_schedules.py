"""Phase 8 schedule entries (docs/PHASE8_DESIGN.md §2.1.4, §2.5.1, §2.6, §2.7, §1.6; P6 owns data/npc/*_schedule.tres).

    python3 tools/dialogue/build_phase8_schedules.py

New schedules: beggar (Veit), peddler (Hanne), apprentice (Jakob's village part – his working day on the hill
is the runtime schedule of P3). Existing villager schedules get today_flag overlays only (idempotent, sub_resource
prefix "p8_"); on a day without the flag nothing changes (ScheduleResolver skips the entries – Phase 7 bitgleich):
  visit_<npc>_day          – Esch, Theres, Liesel visit their dead (§2.1.4; set by Visitors' plan, P2)
  fest_kathrein_day        – the dance in the Holderkrug 19:00–23:00 (§2.7.1; Festivals, P4)
  fest_lights_day          – the gathering at the Holderbrücke 16:00, up the hill 16:45, back after 18:30
                             (§2.7.2; the procession on the cemetery is P4's runtime schedule)
  night_<path>_<npc>_day   – the night visits at the sick light (§1.6; NightPaths, P7 – the day of the visit's
                             enter minute, e.g. night_np_ott_washer_day = the calendar day of 02:40)
  beggar_gate_day          – Veit at the cemetery gate on odd days (§2.6; Wanderers, P7)
  peddler_day              – Hanne's day (day % 6 == 1, §2.6; Wanderers, P7)
  apprentice_off_day       – Jakob's free day in the inn (§2.5.1; Apprentice, P3)
Waypoints of W-Welt (§4.2–§4.6): veit_gate, peddler_gate, lights_gate, gv_<plot>, v_church_step, v_bridge_sit,
v_well_peddler, v_remise_sleep, v_peddler_in, v_peddler_out, v_in_inn_jakob, v_ott_door,
v_kehr_door; the dance places v_in_inn_fest_1…4 are a P6 request to W-Welt (D6 Tanzfläche).
"""
import json
import os
import re

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NPC = os.path.join(ROOT, "data", "npc")
P = "p8_"
ENTRY_SCRIPT = "res://src/systems/npc/schedule_entry.gd"
SCHEDULE_SCRIPT = "res://src/systems/npc/npc_schedule.gd"


def q(s):
    return json.dumps(s, ensure_ascii=False)


class E:
    def __init__(self, start, path, activity="idle", animation="idle", travel=0, dialogue="", visible=True, region="village",
                 flag=""):
        self.start, self.path, self.activity, self.animation = start, path, activity, animation
        self.travel, self.dialogue, self.visible, self.region, self.flag = travel, dialogue, visible, region, flag

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


def walk(start, path, minutes, flag="", region="village", animation="walk"):
    return E(start, path, "walk", animation, minutes, "", True, region, flag)


def stay(start, at, dialogue="", flag="", region="village", animation="idle", activity="idle"):
    return E(start, [at], activity, animation, 0, dialogue, True, region, flag)


def hide(start, at, flag="", region="village"):
    return E(start, [at], "home", "idle", 0, "", False, region, flag)


def shadow(base_starts, entries):
    """A base entry that starts inside a flag overlay would win over it (a later start) – each such start gets a flag
    copy of the overlay entry active there. Only stationary / hidden overlay entries may be shadowed (a walk would
    restart): the times are chosen so, and this checks it."""
    out = list(entries)
    groups = {}
    for e in entries:
        if e.flag:
            groups.setdefault((e.flag, e.region == ""), []).append(e)
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
            assert active.travel == 0 or active.start + active.travel <= s, \
                "%s: base start %d falls into the walk at %d" % (flag, s, active.start)
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


## The gathering place of the Lichtgang at the Holderbrücke: W-Welt names it v_lights_gather (§4.6); until that
## waypoint exists the bridge itself (v_bridge) is used – the routes run over checked village segments.
GATHER = "v_bridge"
TO_BRIDGE = {"v_inn_door": ["v_anger_w"], "v_anvil": ["v_anger_w"], "v_board": ["v_anger_w"], "v_shop_window": ["v_well"],
             "v_church_door": ["v_well"], "v_dorn_door": ["v_well"], "v_surgery_door": ["v_well"]}


def lights(home, back_to, back_dialogue="", back_activity="idle", back_anim="idle", back_visible=True):
    """§2.7.2: from `home` to the Holderbrücke at 16:00 with the lanterns, up the hill at 16:30 (hidden in the village
    from 16:35 – the procession is P4's runtime schedule on the cemetery), back after the descent at 18:45."""
    out_from = DOOR.get(home, home)
    back_door = DOOR.get(back_to, back_to)
    entries = [
        walk(950, [out_from] + TO_BRIDGE[out_from] + [GATHER], 10, LIGHTS),
        stay(960, GATHER, "", LIGHTS, animation="idle"),
        walk(990, [GATHER, "v_road_in"], 5, LIGHTS, animation="lantern_walk"),
        hide(995, "v_road_in", LIGHTS),
        walk(1125, ["v_road_in", GATHER] + TO_BRIDGE[back_door] + [back_door], 12, LIGHTS, animation="lantern_walk"),
    ]
    last = E(1137, [back_to], back_activity, back_anim, 0, back_dialogue, back_visible, "village", LIGHTS)
    entries.append(last)
    return entries


def innkeeper():
    patch("innkeeper", lights("v_in_inn_bar", "v_in_inn_bar", "v_innkeeper", "shop"))


def smith():
    v = "visit_smith_day"
    patch("smith", [
        # §2.1.4: Esch at old_01 (Wendel Gratz) 13:40–14:30; the smithy is shut 13:00–15:00.
        walk(780, ["v_inn_door", "v_anger_w", "v_bridge", "v_road_in"], 6, v),
        hide(786, "v_road_in", v),
        walk(810, ["road_end", "road_mid", "gate_outside", "gv_old_01"], 10, v, region=""),
        stay(820, "gv_old_01", "v_smith", v, region="", animation="mourn_stand", activity="mourn"),
        walk(870, ["gv_old_01", "gate_outside", "road_mid", "road_end"], 12, v, region=""),
        hide(882, "road_end", v, region=""),
        walk(895, ["v_road_in", "v_bridge", "v_anger_w", "v_anvil"], 8, v),
        stay(903, "v_anvil", "v_smith", v, animation="work", activity="shop"),
        # §2.7.1 Kathreintanz.
        walk(1136, ["v_linden", "v_inn_door"], 4, KATHREIN),
        stay(1140, "v_in_inn_fest_1", "v_smith", KATHREIN),
        hide(1380, "v_house_n", KATHREIN),
    ] + lights("v_anvil", "v_anvil", "v_smith", "shop", "work"))


def grocer():
    v = "visit_grocer_day"
    patch("grocer", [
        # §2.1.4: Theres at old_08 (Dorothee Mahn) 14:40–15:10, kneeling; the shop is shut 14:05–16:00.
        walk(845, ["v_shop_window", "v_well", "v_bridge", "v_road_in"], 8, v),
        hide(853, "v_road_in", v),
        walk(870, ["road_end", "road_mid", "gate_outside", "gv_old_08"], 10, v, region=""),
        stay(880, "gv_old_08", "v_grocer", v, region="", animation="kneel", activity="mourn"),
        walk(910, ["gv_old_08", "gate_outside", "road_mid", "road_end"], 12, v, region=""),
        hide(922, "road_end", v, region=""),
        walk(945, ["v_road_in", "v_bridge", "v_well", "v_shop_window"], 10, v),
        stay(955, "v_shop_window", "v_grocer", v, animation="work", activity="shop"),
        walk(1135, ["v_shop_window", "v_inn_door"], 5, KATHREIN),
        stay(1140, "v_in_inn_fest_2", "v_grocer", KATHREIN),
        hide(1380, "v_shop_window", KATHREIN),
    ] + lights("v_shop_window", "v_shop_window", "v_grocer", "shop", "work"))


def mayor():
    patch("mayor", [
        stay(1260, "v_in_inn_table", "v_mayor", KATHREIN),
        hide(1380, "v_office_door", KATHREIN),
    ] + lights("v_board", "v_board", "v_mayor"))


def priest():
    patch("priest", lights("v_in_church_altar", "v_in_inn_corner", "v_priest") + [
        # §1.6 night visits (the Versehgang with the lantern).
        walk(1250, ["v_church_door", "v_well", "v_ott_door"], 10, "night_np_ott_priest_day", animation="lantern_walk"),
        stay(1260, "v_ott_door", "", "night_np_ott_priest_day", animation="knock"),
        hide(1261, "v_ott_door", "night_np_ott_priest_day"),
        stay(1300, "v_ott_door", "v_priest", "night_np_ott_priest_day"),
        walk(1302, ["v_ott_door", "v_well", "v_church_door"], 10, "night_np_ott_priest_day", animation="lantern_walk"),
        hide(1312, "v_church_door", "night_np_ott_priest_day"),
        walk(1250, ["v_church_door", "v_well", "v_kehr_door"], 10, "night_np_kehr_priest_day", animation="lantern_walk"),
        stay(1260, "v_kehr_door", "", "night_np_kehr_priest_day", animation="knock"),
        hide(1261, "v_kehr_door", "night_np_kehr_priest_day"),
        stay(1290, "v_kehr_door", "v_priest", "night_np_kehr_priest_day"),
        walk(1292, ["v_kehr_door", "v_well", "v_church_door"], 10, "night_np_kehr_priest_day", animation="lantern_walk"),
        hide(1302, "v_church_door", "night_np_kehr_priest_day"),
    ])


def surgeon():
    entries = [
        # §2.1.4 / §2.7.2: Quast never goes up – at the Lichtgang he stays at the bridge.
        walk(960, ["v_surgery_door", "v_well", "v_bridge"], 6, LIGHTS),
        stay(966, "v_bridge", "v_surgeon", LIGHTS),
    ]
    for path_id, door in (("np_ott", "v_ott_door"), ("np_kehr", "v_kehr_door")):
        f = "night_%s_surgeon_day" % path_id
        entries += [
            walk(1340, ["v_surgery_door", "v_anger_w", door], 10, f),
            stay(1350, door, "", f, animation="knock"),
            hide(1351, door, f),
            stay(1390, door, "v_surgeon", f),
            walk(1392, [door, "v_anger_w", "v_surgery_door"], 10, f),
            hide(1402, "v_surgery_door", f),
        ]
    patch("surgeon", entries)


def washer():
    v = "visit_washer_day"
    f = "night_np_ott_washer_day"
    patch("washer", [
        # §2.1.4: Liesel at the Lindenacker 09:40–10:40 instead of the wake (the graves of both cottages – P2 picks the
        # grave at runtime; linden_spot is the data fallback).
        walk(540, ["v_dorn_door", "v_well", "v_bridge", "v_road_in"], 8, v),
        hide(548, "v_road_in", v),
        walk(570, ["road_end", "road_mid", "gate_outside", "dropoff", "w_east_pass", "w_linden_n", "linden_spot"], 10, v, region=""),
        stay(580, "linden_spot", "v_washer", v, region="", animation="kneel", activity="mourn"),
        walk(640, ["linden_spot", "w_linden_n", "w_east_pass", "dropoff", "gate_outside", "road_mid", "road_end"], 15, v, region=""),
        hide(655, "road_end", v, region=""),
        walk(690, ["v_road_in", "v_bridge", "v_well", "v_dorn_door"], 8, v),
        hide(698, "v_dorn_door", v),
        # §2.7.1: 20:00–21:00 at the dance.
        walk(1195, ["v_dorn_door", "v_inn_door"], 5, KATHREIN),
        stay(1200, "v_in_inn_fest_3", "v_washer", KATHREIN),
        walk(1260, ["v_inn_door", "v_dorn_door"], 5, KATHREIN),
        hide(1265, "v_dorn_door", KATHREIN),
        # §1.6: the wake at the Otts' after the death (02:40–05:30).
        walk(150, ["v_dorn_door", "v_well", "v_ott_door"], 10, f),
        stay(160, "v_ott_door", "", f, animation="knock"),
        hide(161, "v_ott_door", f),
        stay(330, "v_ott_door", "v_washer", f),
        walk(332, ["v_ott_door", "v_well", "v_dorn_door"], 10, f),
        hide(342, "v_dorn_door", f),
    ] + lights("v_dorn_door", "v_dorn_door", "v_washer", "shop", "work"))


def carter():
    # Osric keeps his Phase-7 schedule (the carter fixture of W-Welt): on Kathrein he is in the inn from 21:55 as
    # every evening – he does not dance ("Ich fahr nur.", §8.2).
    patch("carter", [])


def beggar():
    g = "beggar_gate_day"
    write_new("beggar", "Veit Ammer", [
        hide(0, "v_remise_sleep"),
        walk(470, ["v_remise_sleep", "v_anger_w", "v_church_step"], 10, animation="walk_stiff"),
        stay(480, "v_church_step", "beggar", animation="sit_beg", activity="beg"),
        walk(690, ["v_church_step", "v_well", "v_bridge_sit"], 10, animation="walk_stiff"),
        stay(700, "v_bridge_sit", "beggar", animation="sit_beg", activity="beg"),
        walk(1020, ["v_bridge_sit", "v_anger_w", "v_remise_sleep"], 8, animation="walk_stiff"),
        hide(1028, "v_remise_sleep"),
        walk(1078, ["v_remise_sleep", "v_anger_w", "v_bridge_sit"], 8, animation="walk_stiff"),
        stay(1086, "v_bridge_sit", "beggar", animation="sit_beg", activity="beg"),
        walk(1170, ["v_bridge_sit", "v_anger_w", "v_remise_sleep"], 8, animation="walk_stiff"),
        hide(1178, "v_remise_sleep"),
        walk(1250, ["v_remise_sleep", "v_well", "v_well_bench"], 10, animation="walk_stiff"),
        stay(1260, "v_well_bench", "beggar", animation="sit_beg", activity="beg"),
        walk(1410, ["v_well_bench", "v_well", "v_remise_sleep"], 8, animation="walk_stiff"),
        hide(1418, "v_remise_sleep"),
        # Odd days 13:40–16:00 outside the cemetery gate (§2.6).
        walk(780, ["v_bridge_sit", "v_road_in"], 6, g, animation="walk_stiff"),
        hide(786, "v_road_in", g),
        walk(800, ["road_end", "road_mid", "gate_outside", "veit_gate"], 20, g, region="", animation="walk_stiff"),
        stay(820, "veit_gate", "beggar", g, region="", animation="sit_beg", activity="beg"),
        walk(960, ["veit_gate", "gate_outside", "road_mid", "road_end"], 20, g, region="", animation="walk_stiff"),
        hide(980, "road_end", g, region=""),
        walk(1000, ["v_road_in", "v_bridge_sit"], 6, g, animation="walk_stiff"),
        stay(1006, "v_bridge_sit", "beggar", g, animation="sit_beg", activity="beg"),
        # The Lichtgang: no candle ("Meine liegen im Wasser."), he stands at the gate (lights_gate).
        walk(960, ["v_bridge_sit", "v_road_in"], 6, LIGHTS, animation="walk_stiff"),
        hide(966, "v_road_in", LIGHTS),
        walk(985, ["road_end", "road_mid", "gate_outside", "lights_gate"], 20, LIGHTS, region="", animation="walk_stiff"),
        stay(1005, "lights_gate", "beggar", LIGHTS, region=""),
        walk(1110, ["lights_gate", "gate_outside", "road_mid", "road_end"], 20, LIGHTS, region="", animation="walk_stiff"),
        hide(1130, "road_end", LIGHTS, region=""),
        walk(1150, ["v_road_in", "v_bridge_sit"], 6, LIGHTS, animation="walk_stiff"),
        stay(1156, "v_bridge_sit", "beggar", LIGHTS, animation="sit_beg", activity="beg"),
    ])


def peddler():
    d = "peddler_day"
    write_new("peddler", "Hanne Vogelsang", [
        hide(0, "v_peddler_out"),
        # Every 6th day (§2.6): over the bridge at 09:30, the well 10:00–14:00, the cemetery gate 15:40–16:20, then
        # up the forest path to the west (Ilse's way).
        walk(570, ["v_peddler_in", "v_bridge", "v_well", "v_well_peddler"], 30, d),
        stay(600, "v_well_peddler", "peddler", d, animation="offer", activity="shop"),
        walk(840, ["v_well_peddler", "v_well", "v_bridge", "v_road_in"], 10, d),
        hide(850, "v_road_in", d),
        walk(920, ["road_end", "road_mid", "gate_outside", "peddler_gate"], 20, d, region=""),
        stay(940, "peddler_gate", "peddler", d, region="", animation="offer", activity="shop"),
        walk(980, ["peddler_gate", "trader_spot", "trader_mid", "trader_far"], 20, d, region=""),
        hide(1000, "trader_far", d, region=""),
    ])


def apprentice():
    off = "apprentice_off_day"
    write_new("apprentice", "Jakob Wackernagel", [
        hide(0, "v_inn_door"),
        stay(450, "v_in_inn_jakob", "v_apprentice"),
        walk(465, ["v_inn_door", "v_anger_w", "v_bridge", "v_road_in"], 10),
        hide(475, "v_road_in"),
        stay(1020, "v_in_inn_jakob", "v_apprentice", animation="talk"),
        hide(1260, "v_inn_door"),
        # The free day (§2.5.1: "Jakob hilft heute im Krug").
        stay(465, "v_in_inn_jakob", "v_apprentice", off, animation="talk"),
        stay(1020, "v_in_inn_jakob", "v_apprentice", off, animation="talk"),
        # Kathreintanz until 23:00; the Lichtgang: he carries his mother's lantern.
        stay(1260, "v_in_inn_jakob", "v_apprentice", KATHREIN),
        hide(1380, "v_inn_door", KATHREIN),
    ] + lights("v_in_inn_jakob", "v_in_inn_jakob", "v_apprentice", "idle", "talk"))


def main():
    for fn in (innkeeper, smith, grocer, mayor, priest, surgeon, washer, carter, beggar, peddler, apprentice):
        fn()
    print("Phase-8 schedules written to", NPC)


if __name__ == "__main__":
    main()

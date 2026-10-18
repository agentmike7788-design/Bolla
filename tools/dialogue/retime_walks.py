"""G9 Gehtempo (docs/PHASE9_DESIGN.md „G9 – Benutzerentscheidungen“ 1): the Phase-7 entries of data/npc/*_schedule.tres
(made in the editor, no generator) at the natural pace – run before build_phase8_schedules.py / build_phase9_schedules.py
(their shadow copies read the plain starts):

    python3 tools/dialogue/retime_walks.py [--check]

Each walk below gets the minutes of its polyline (walk_tempo.py: 0.8 m per game minute, the cart 0.55); the rule is
„Ankunft bleibt, Abfahrt früher“ – the stay it walks to begins as before, the stay before ends earlier – except:
  carter  – Osric leaves the dropoff at 10:00 (dialogue and loading until then, WhoKnowsConfig.depart_with_carter_minute):
            on the road end 10:54, in the village (GAP 30 as before) 11:24 → at the remise 12:22;
  grocer / washer – Theres and Liesel at the well 16:00–16:30 (NpcLife chatter ch_well_spin, 3.5 s a line): both leave
            at 16:30 as before, the shop / the washing at the door open again at 16:52 / 16:47 (before 16:35);
  mayor   – Fenner at the board until 18:00 (chatter ch_linden_bench with Esch at the linden 17:34–18:00), in the inn
            18:34 (before 18:05);
  priest  – the consecration of the Lindenacker: at the linden at 09:20, back from 10:30 (to the road end 11:43).
Idempotent (absolute values). --check only reports every data walk outside the band.
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(__file__))
import walk_tempo as wt  # noqa: E402

NPC = os.path.join(wt.ROOT, "data", "npc")

# {npc: {sub_resource id: start_minute}} – the walks get their polyline minutes; stays (no path of two points) only
# the start. The comment is the clock time and the reason.
BASE = {
    "carter": {
        "morning_arrive": 390,      # 06:30 → 07:24 at the bier (the cart, 54 min; delivery 07:40 as before)
        "morning_leave": 600,       # 10:00 → 10:54 at the road end
        "day_home": 654,
        "v_walk_remise": 684,       # 11:24 → 12:22 at the remise
        "v_remise": 742,
        "v_walk_inn": 822,          # 13:42 → 14:05 in the inn as before
        "v_walk_inn_night": 1297,   # 21:37 → 22:00 in the inn as before
    },
    "grocer": {
        "Resource_m247r": 928,      # 15:28 → 15:50 at the well
        "Resource_6bmho": 950,
        "Resource_cvoyc": 990,      # 16:30 as before → 16:52 the shop opens again (ch_well_spin until 16:30)
        "Resource_yxotm": 1012,
    },
    "innkeeper": {
        "Resource_gwt02": 350,      # 05:50 → 06:10 at the well as before
        "Resource_2fim3": 390,      # 06:30 → 06:50 behind the bar as before
    },
    "mayor": {
        "Resource_0oylv": 691,      # 11:31 → 12:20 at the board
        "Resource_f1tkc": 762,      # 12:42 → 13:05 at the desk
        "Resource_tdu31": 942,      # 15:42 → 16:05 at the board
        "Resource_irxlc": 1080,     # 18:00 as before (ch_linden_bench) → 18:34 in the inn
        "Resource_ofwtp": 1114,
    },
    "oldwoman": {
        "Resource_34akn": 527,      # 08:47 → 09:06 on the well bench
        "Resource_cy44s": 647,      # 10:47 → 11:06 home
    },
    "priest": {
        "Resource_pbuyb": 671,      # 11:11 → 11:38 at the Hagedorn gate
        "Resource_aevy6": 1071,     # 17:51 → 18:10 in the inn
        "Resource_dcyle": 487,      # consecration: 08:07 → 09:20 at the linden
        "Resource_d8ent": 630,      # 10:30 → 11:43 at the road end
        "Resource_frwys": 703,
    },
    "smith": {
        "Resource_dneqq": 377,      # 06:17 → 06:40 at the anvil
        "Resource_386d2": 743,      # 12:23 → 13:06 at the anvil
        "Resource_vcg37": 1038,     # 17:18 → 17:34 at the linden
    },
    "surgeon": {
        "Resource_d058b": 679,      # 11:19 → 12:10 home for lunch
        "Resource_uj5n2": 789,      # 13:09 → 14:00 at the desk
        "Resource_n2mmb": 1036,     # 17:16 → 18:06 at the bridge
    },
    "washer": {
        "Resource_gkglj": 360,      # 06:00 → 06:38 at the wash place
        "Resource_ye1ld": 888,      # 14:48 → 15:05 at the well
        "Resource_nb3dv": 990,      # 16:30 as before (ch_well_spin) → 16:47 at her door
        "Resource_7ggjs": 1007,
    },
}


def _blocks(text):
    return [b for b in text.split("\n\n")]


def _get(block, key, default=""):
    m = re.search(r"^%s = (.*)$" % key, block, re.M)
    return m.group(1) if m else default


def _set(block, key, value, after):
    """Set `key` (int; 0 removes it, as Godot writes defaults) – inserted after the line `after` when missing."""
    lines = block.split("\n")
    lines = [ln for ln in lines if not ln.startswith(key + " = ")]
    if value:
        i = max(k for k, ln in enumerate(lines) if ln.startswith(after) or ln.startswith("script = ")) + 1
        lines.insert(i, "%s = %d" % (key, value))
    return "\n".join(lines)


def entry_info(block):
    path = re.findall(r'"([^"]*)"', _get(block, "path", "PackedStringArray()"))
    region = _get(block, "region", '&""')[2:-1]
    anim = _get(block, "animation", '&"idle"')[2:-1]
    cart = _get(block, "with_cart", "false") == "true"
    travel = int(_get(block, "travel_minutes", "0"))
    start = int(_get(block, "start_minute", "0"))
    flag = _get(block, "today_flag", '&""')[2:-1]
    return path, region, anim, cart, travel, start, flag


def retime():
    for npc, table in BASE.items():
        fn = os.path.join(NPC, npc + "_schedule.tres")
        with open(fn, encoding="utf-8") as f:
            text = f.read()
        blocks = _blocks(text)
        done = set()
        for i, b in enumerate(blocks):
            m = re.match(r'\[sub_resource type="Resource" id="([^"]+)"\]', b.strip())
            if not m or m.group(1) not in table:
                continue
            sid = m.group(1)
            path, region, anim, cart, travel, _, _ = entry_info(b)
            b = _set(b, "start_minute", table[sid], "script = ")
            if travel > 0 and len(path) >= 2:
                b = _set(b, "travel_minutes", wt.minutes(path, region, anim, cart), "start_minute")
            blocks[i] = b
            done.add(sid)
        missing = set(table) - done
        assert not missing, "%s: no block %s" % (npc, sorted(missing))
        with open(fn, "w", encoding="utf-8") as f:
            f.write("\n\n".join(blocks))


def check():
    bad = 0
    for name in sorted(os.listdir(NPC)):
        if not name.endswith("_schedule.tres"):
            continue
        with open(os.path.join(NPC, name), encoding="utf-8") as f:
            text = f.read()
        for b in _blocks(text):
            if not b.strip().startswith("[sub_resource"):
                continue
            path, region, anim, cart, travel, start, flag = entry_info(b)
            if travel > 0 and len(path) >= 2 and not wt.in_band(path, region, travel, anim, cart):
                bad += 1
                print("%s %s %02d:%02d %d min %.1f m %s" % (name, flag, start // 60, start % 60, travel, wt.length(path, region),
                                                         " ".join(path)))
    print("%d walks out of the band" % bad)
    return bad


if __name__ == "__main__":
    if "--check" not in sys.argv:
        retime()
    sys.exit(1 if check() else 0)

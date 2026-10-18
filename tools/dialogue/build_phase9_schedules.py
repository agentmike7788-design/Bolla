"""Phase 9 schedules (docs/PHASE9_DESIGN.md §2.2.5, §2.2.7, §2.5.1, §4.3–§4.5; P6 owns data/npc/*_schedule.tres).

    python3 tools/dialogue/build_phase9_schedules.py

New schedules (sub_resource prefix "p9_"); the existing villager schedules stay bit-identical (Phase 8 bitgleich):
  stranger      – Cornelius Brenneisen (§2.5.1): over the Holderbrücke 09:30 on his first day, up the Kutschweg 13:30,
                  outside the cemetery gate 14:10–15:30 (StrangerConfig.gate_window, never inside), the inn 18:00–21:00
                  (inn_window, his table). Flags: stranger_day (each of his days), stranger_arrive_day (the first one).
  kin_sieber_v  – Johann Sieber in the village (§2.2.5): from H4 on the bench before the house 14:00–16:00
                  (WhoKnowsConfig.bench_window, flag sieber_bench_day), ending B the evenings 18:00–20:00 (sieber_evening_day),
                  ending A the departure (§4.5): with Hanne (sieber_depart_peddler_day – 1 minute behind her, 16:20 from the gate
                  up the forest path, walk_bundle) or on Osric's cart (sieber_depart_carter_day – 10:00 down the Kutschweg, sit_cart).
  watchman      – the night watchman's lantern at the Siebers' door (ending C, §2.2.7, §4.6 D12): 21:00–06:00 while
                  sieber_watch_day holds the day (set for every calendar day of the watch, also after midnight). Prio A: the
                  lantern without a figure (W-Welt shows the prop ph_prop_watch_lantern at the entry's spot); Prio B the figure.
Every flag holds the day it applies to (ScheduleResolver.is_today) and is set by the system that knows the plan:
stranger_* – Stranger (P5), sieber_bench_day / sieber_depart_* / sieber_watch_day – WhoKnows (P4), sieber_evening_day – the
accepted order oq_johann_evening (Orders P1 / WhoKnows P4).
New waypoints for W-Welt (§3.1, §4.3–§4.5): village v_sieber_door, v_sieber_bench (§3.1), the inn table v_in_inn_stranger
(inn_layout.json, §4.4 / D11); graveyard stranger_gate (§4.4 / G4), sieber_gate (Johann waiting beside Hanne at the gate).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_phase8_schedules as s8  # noqa: E402

s8.P = "p9_"
walk, walk_to, stay, hide, write_new, patch = s8.walk, s8.walk_to, s8.stay, s8.hide, s8.write_new, s8.patch
GAP, arrive_hide = s8.GAP, s8.arrive_hide
# G9 Gehtempo (build_phase8_schedules.py, walk_tempo.py): the walks take the polyline's minutes at the pace; the
# arrivals the systems need stay (StrangerConfig.gate_window 14:10–15:30 / inn_window, WhoKnowsConfig.bench_window and the
# departures 16:20 / 10:00, the knocks of NightPaths, the bench of ending B at 18:00, the watch from 21:00).

STRANGER = "stranger_day"
ARRIVE = "stranger_arrive_day"
BENCH = "sieber_bench_day"
EVENING = "sieber_evening_day"
WITH_PEDDLER = "sieber_depart_peddler_day"
WITH_CARTER = "sieber_depart_carter_day"
WATCH = "sieber_watch_day"
TO_GATE = ["road_end", "road_mid", "gate_outside"]
# W-Welt (§4.6 D8): from the Siebers' door along the west bank to the bridge (straight through the house is no way).
LANES = ["v_sieber_lane_s", "v_sieber_lane_e", "v_sieber_lane_n"]
FROM_DOOR = ["v_sieber_door", "v_sieber_yard"] + LANES + ["v_road_in"]


def stranger():
    up = walk_to(850, TO_GATE + ["stranger_gate"], STRANGER, region="")
    out = walk_to(up.start - GAP, s8.TO_ROAD, STRANGER)
    down = walk(930, ["stranger_gate"] + list(reversed(TO_GATE)), None, STRANGER, region="")
    back = walk(down.arrive + GAP, s8.FROM_ROAD, None, STRANGER)
    arrive = walk_to(590, ["v_peddler_in", "v_bridge", "v_anger_w", "v_inn_door"], ARRIVE)
    write_new("stranger", "Cornelius Brenneisen", [
        hide(0, "v_road_in"),
        # Each of his days: in the inn by night, up to the gate in the afternoon (14:10–15:30), at his table in the evening.
        hide(0, "v_inn_door", STRANGER),
        out,
        hide(out.arrive, "v_road_in", STRANGER),
        up,
        stay(850, "stranger_gate", "stranger", STRANGER, region="", animation="wait_gate", activity="wait"),
        down,
        hide(down.arrive, "road_end", STRANGER, region=""),
        back,
        hide(back.arrive, "v_inn_door", STRANGER),
        stay(1080, "v_in_inn_stranger", "stranger", STRANGER, animation="sit_inn", activity="sit"),
        hide(1260, "v_inn_door", STRANGER),
        # The first day of a visit: over the Holderbrücke on foot, at the inn by 09:50.
        arrive,
        hide(590, "v_inn_door", ARRIVE),
    ])


def kin_sieber_v():
    # Ending A with Hanne (§4.5): one minute behind her up the Kutschweg to the gate (she leaves the well at 14:00 – the
    # peddler's schedule of build_phase8_schedules.py), beside her at the gate, one minute behind her up the forest path.
    hanne_up = 840 + s8.village_minutes(["v_well_peddler", "v_well", "v_bridge", "v_road_in"]) + GAP
    p_up = walk(hanne_up + 1, TO_GATE + ["sieber_gate"], None, WITH_PEDDLER, region="", animation="walk_bundle")
    p_out = walk_to(p_up.start - GAP, FROM_DOOR, WITH_PEDDLER, animation="walk_bundle")
    p_west = walk(981, ["sieber_gate", "gate_outside", "peddler_west", "trader_spot", "trader_mid", "trader_far"], None, WITH_PEDDLER,
                  region="", animation="walk_bundle")
    # Ending A with Osric (§4.5): up to the cart at the dropoff, then on the loading bed down the Kutschweg at 10:00 (the
    # cart's pace – Osric's way back, carter_schedule.tres).
    c_up = walk_to(580, TO_GATE + ["dropoff"], WITH_CARTER, region="", animation="walk_bundle")
    c_out = walk_to(c_up.start - GAP, FROM_DOOR, WITH_CARTER, animation="walk_bundle")
    c_ride = walk(600, ["dropoff", "gate_outside", "road_mid", "road_end"], None, WITH_CARTER, region="", animation="sit_cart")
    write_new("kin_sieber_v", "Johann Sieber", [
        hide(0, "v_sieber_door"),
        # From H4: the bench before the house 14:00–16:00 (he is at Grete's grave 10:00–11:00 – Visitors).
        walk(836, ["v_sieber_door", "v_sieber_bench"], 4, BENCH),
        stay(840, "v_sieber_bench", "kin_sieber_v", BENCH, animation="sit_bench", activity="sit"),
        walk(960, ["v_sieber_bench", "v_sieber_door"], 4, BENCH),
        hide(964, "v_sieber_door", BENCH),
        # Ending B: the two evenings 18:00–20:00.
        walk(1076, ["v_sieber_door", "v_sieber_bench"], 4, EVENING),
        stay(1080, "v_sieber_bench", "kin_sieber_v", EVENING, animation="sit_bench", activity="sit"),
        walk(1200, ["v_sieber_bench", "v_sieber_door"], 4, EVENING),
        hide(1204, "v_sieber_door", EVENING),
        # the same waypoints as Hanne's way, with his bundle.
        p_out,
        hide(p_out.arrive, "v_road_in", WITH_PEDDLER),
        p_up,
        stay(p_up.arrive, "sieber_gate", "kin_sieber_v", WITH_PEDDLER, region=""),
        p_west,
        hide(p_west.arrive, "trader_far", WITH_PEDDLER, region=""),
        c_out,
        hide(c_out.arrive, "v_road_in", WITH_CARTER),
        c_up,
        stay(580, "dropoff", "kin_sieber_v", WITH_CARTER, region="", animation="sit_cart", activity="sit"),
        c_ride,
        hide(c_ride.arrive, "road_end", WITH_CARTER, region=""),
    ])


def watchman():
    # W3 („Restbedarf“ 4): the figure (Prio B) – from the Amtshaus over the bridge to his place between door and bench
    # (v_sieber_watch), the lantern in his hand all night (21:00–06:00), home again in the morning.
    home = walk(360, ["v_sieber_watch", "v_sieber_yard"] + LANES + ["v_road_in", "v_bridge", "v_well", "v_office_door"], None, WATCH)
    write_new("watchman", "Der Nachtwächter", [
        hide(0, "v_office_door"),
        stay(0, "v_sieber_watch", "", WATCH, animation="stand_watch", activity="watch"),
        home,
        stay(1260, "v_sieber_watch", "", WATCH, animation="stand_watch", activity="watch"),
        hide(home.arrive, "v_office_door", WATCH),
        walk_to(1260, ["v_office_door", "v_well", "v_bridge", "v_road_in"] + list(reversed(LANES)) + ["v_sieber_yard", "v_sieber_watch"],
                WATCH),
    ])


def to_siebers(start):
    """The village way from `start` (a door) to the Siebers' door: over the bridge and along the west bank."""
    via = {"v_surgery_door": ["v_well", "v_bridge"], "v_church_door": ["v_well", "v_bridge"],
           "v_dorn_door": ["v_linden", "v_anger_w", "v_bridge"]}[start]
    return [start] + via + ["v_road_in"] + list(reversed(LANES)) + ["v_sieber_yard", "v_sieber_door"]


def to_bench(start):
    """The way from `start` to the second seat of the Siebers' bench (the bench stands before the yard)."""
    return to_siebers(start)[:-2] + ["v_sieber_bench_2"]


def vigil(npc, flag, knock, inside_until, dialogue, animation="walk"):
    """W3 („Restbedarf“ 2): a night visit at the Siebers' (the sick light, NightPaths): to the door (arriving at the
    knock), knock, inside, out at the door for a word, home again."""
    home = {"surgeon": "v_surgery_door", "priest": "v_church_door", "washer": "v_dorn_door"}[npc]
    there = to_siebers(home)
    back = walk(inside_until + 2, list(reversed(there)), None, flag, animation=animation)
    return [
        walk_to(knock, there, flag, animation=animation),
        stay(knock, "v_sieber_door", "", flag, animation="knock"),
        hide(knock + 1, "v_sieber_door", flag),
        stay(inside_until, "v_sieber_door", dialogue, flag),
        back,
    ] + arrive_hide(back, home)


def evening(npc, flag, until, animation="walk"):
    """W3 („Restbedarf“ 3): ending B – Lenz (first evening) / Liesel (second) on the bench beside Johann 18:00–20:00."""
    home = {"priest": "v_church_door", "washer": "v_dorn_door"}[npc]
    way = to_bench(home)
    back = walk(until, list(reversed(way)), None, flag, animation=animation)
    return [
        walk_to(1080, way, flag, animation=animation),
        stay(1080, "v_sieber_bench_2", "", flag, animation="sit_bench", activity="sit"),
        back,
        hide(back.arrive, home, flag),
    ]


def sieber_nights():
    patch("surgeon", vigil("surgeon", "night_np_sieber_surgeon_day", 1350, 1390, "v_surgeon"))
    patch("priest", vigil("priest", "night_np_sieber_priest_day", 1260, 1300, "v_priest", "lantern_walk")
          + evening("priest", "sieber_evening_priest_day", 1200, "lantern_walk"))
    # Liesel's wake (02:40–05:30): home to bed afterwards – no washing that morning (as after the Otts' wake).
    patch("washer", vigil("washer", "night_np_sieber_washer_day", 160, 330, "v_washer")
          + evening("washer", "sieber_evening_washer_day", 1200))


def main():
    stranger()
    kin_sieber_v()
    watchman()
    sieber_nights()
    print("Phase-9 schedules written to", s8.NPC)


if __name__ == "__main__":
    main()

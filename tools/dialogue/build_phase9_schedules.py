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
walk, stay, hide, write_new = s8.walk, s8.stay, s8.hide, s8.write_new

STRANGER = "stranger_day"
ARRIVE = "stranger_arrive_day"
BENCH = "sieber_bench_day"
EVENING = "sieber_evening_day"
WITH_PEDDLER = "sieber_depart_peddler_day"
WITH_CARTER = "sieber_depart_carter_day"
WATCH = "sieber_watch_day"
TO_GATE = ["road_end", "road_mid", "gate_outside"]


def stranger():
    write_new("stranger", "Cornelius Brenneisen", [
        hide(0, "v_road_in"),
        # Each of his days: in the inn by night, up to the gate in the afternoon, at his table in the evening.
        hide(0, "v_inn_door", STRANGER),
        walk(810, ["v_inn_door", "v_anger_w", "v_bridge", "v_road_in"], 10, STRANGER),
        hide(820, "v_road_in", STRANGER),
        walk(830, TO_GATE + ["stranger_gate"], 20, STRANGER, region=""),
        stay(850, "stranger_gate", "stranger", STRANGER, region="", animation="wait_gate", activity="wait"),
        walk(930, ["stranger_gate"] + list(reversed(TO_GATE)), 20, STRANGER, region=""),
        hide(950, "road_end", STRANGER, region=""),
        walk(960, ["v_road_in", "v_bridge", "v_anger_w", "v_inn_door"], 10, STRANGER),
        hide(970, "v_inn_door", STRANGER),
        stay(1080, "v_in_inn_stranger", "stranger", STRANGER, animation="sit_inn", activity="sit"),
        hide(1260, "v_inn_door", STRANGER),
        # The first day of a visit: over the Holderbrücke on foot at 09:30.
        walk(570, ["v_peddler_in", "v_bridge", "v_anger_w", "v_inn_door"], 20, ARRIVE),
        hide(590, "v_inn_door", ARRIVE),
    ])


def kin_sieber_v():
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
        # Ending A with Hanne (§4.5): one minute behind her down to the road, at the gate beside her, 16:20 up the forest
        # path to the west with his bundle – the same waypoints as Hanne's way.
        walk(841, ["v_sieber_door", "v_road_in"], 9, WITH_PEDDLER, animation="walk_bundle"),
        hide(850, "v_road_in", WITH_PEDDLER),
        walk(921, TO_GATE + ["sieber_gate"], 20, WITH_PEDDLER, region="", animation="walk_bundle"),
        stay(941, "sieber_gate", "kin_sieber_v", WITH_PEDDLER, region=""),
        walk(981, ["sieber_gate", "gate_outside", "peddler_west", "trader_spot", "trader_mid", "trader_far"], 20, WITH_PEDDLER,
             region="", animation="walk_bundle"),
        hide(1001, "trader_far", WITH_PEDDLER, region=""),
        # Ending A with Osric (§4.5): up to the cart at the dropoff, then on the loading bed down the Kutschweg at 10:00.
        walk(545, ["v_sieber_door", "v_road_in"], 9, WITH_CARTER, animation="walk_bundle"),
        hide(554, "v_road_in", WITH_CARTER),
        walk(560, TO_GATE + ["dropoff"], 20, WITH_CARTER, region="", animation="walk_bundle"),
        stay(580, "dropoff", "kin_sieber_v", WITH_CARTER, region="", animation="sit_cart", activity="sit"),
        walk(600, ["dropoff", "gate_outside", "road_mid", "road_end"], 40, WITH_CARTER, region="", animation="sit_cart"),
        hide(640, "road_end", WITH_CARTER, region=""),
    ])


def watchman():
    write_new("watchman", "Der Nachtwächter", [
        hide(0, "v_sieber_door"),
        stay(0, "v_sieber_door", "", WATCH, animation="lantern", activity="watch"),
        hide(360, "v_sieber_door", WATCH),
        stay(1260, "v_sieber_door", "", WATCH, animation="lantern", activity="watch"),
    ])


def main():
    stranger()
    kin_sieber_v()
    watchman()
    print("Phase-9 schedules written to", s8.NPC)


if __name__ == "__main__":
    main()

extends TestCase
## P2 (docs/PHASE8_DESIGN.md §2.1.4, §2.2.1–§2.2.3, §3.4, §5.1, §10): Visitors – the plan at 06:00
## (deterministic; first visit the day after the burial, every 3 (+0/1) days in mourning, then 7; the opening
## spread; a household walks all its graves; ≤ 3 a day / ≤ 2 at once; none before p8_open, on the night of the
## lights or at a DUG grave), kin_house at the delivery, the villagers' visits (visit_<npc>_day), the visible
## phases from plan + clock (bouquet, look, waiting, gone), noise ≤ 8 m, save / load mid-visit without replay,
## the W0 fixture key "phase". VisitRules as pure functions.

const Harness := preload("res://tests/unit/visitors_harness.gd")

var h: Harness
var cfg: VisitorConfig
var changed: Array = []


func before_each() -> void:
	GameState.reset()
	cfg = Phase8Fixtures.visitor_config()
	TimeManager.load_state({"day": 53, "minute_of_day": 300})
	h = Harness.new()
	h.setup(tree)
	h.households_only()
	changed.clear()
	EventBus.visitor_changed.connect(_on_changed)


func after_each() -> void:
	EventBus.visitor_changed.disconnect(_on_changed)
	h.teardown()
	await wait_frames(1)
	GameState.reset()


func _on_changed(visit_id: String, kin_id: StringName, grave_id: String, phase: StringName) -> void:
	changed.append([visit_id, kin_id, grave_id, phase])


# --- VisitRules ----------------------------------------------------------------------------------

func test_rules_next_due() -> void:
	assert_eq(VisitRules.next_due("l_01", 54, -1, 53, cfg), 55, "the day after the burial")
	var d := VisitRules.next_due("l_01", 54, 55, 53, cfg)
	assert_true(d == 58 or d == 59, "mourning: 3 (+0/1) – %d" % d)
	assert_eq(VisitRules.next_due("l_01", 54, 55, 53, cfg), d, "deterministic")
	assert_eq(VisitRules.next_due("l_01", 30, 52, 53, cfg), 59, "after 21 days: every 7")
	var open_mourning := VisitRules.next_due("l_02", 45, -1, 53, cfg)
	assert_true(open_mourning >= 53 and open_mourning <= 55, "opening: in mourning on the first three days")
	var open_old := VisitRules.next_due("l_03", 20, -1, 53, cfg)
	assert_true(open_old >= 53 and open_old <= 59, "opening: older by seed mod 7")
	assert_eq(VisitRules.household_due([58, -1, 56]), 56, "a household comes with its earliest grave")
	assert_eq(VisitRules.household_due([-1]), -1)


func test_rules_villager_due_and_lights() -> void:
	assert_eq(VisitRules.villager_due(-1, 53, 2, 6, -1), 55, "p8_open_day + first_offset")
	assert_eq(VisitRules.villager_due(55, 53, 2, 6, -1), 61)
	assert_eq(VisitRules.villager_due(54, 53, 1, 4, 58), 59, "the night of the lights moves it one day")


func test_rules_timeline() -> void:
	var t := VisitRules.timeline(570, 13, 1, true, true, cfg)
	var phases: Array = t.map(func(s: Dictionary) -> StringName: return s.phase)
	assert_eq(phases, [&"arriving", &"mourning", &"mourning", &"mourning", &"waiting", &"leaving", &"gone"])
	assert_eq(VisitRules.look_end(t, 0), 570 + 13 + 2 + 30 + 2)
	assert_eq(VisitRules.end_minute(t), 570 + VisitRules.duration(13, 1, true, true, cfg))
	var length := VisitRules.duration(13, 1, true, true, cfg)
	assert_true(length >= 60 and length <= 90, "60–90 minutes (%d)" % length)
	assert_eq(VisitRules.duration(13, 2, false, false, cfg) - VisitRules.duration(13, 1, false, false, cfg), 15, "a round: ≈ 15 per grave")
	assert_eq(VisitRules.segment_at(t, 569), {})
	assert_eq(VisitRules.segment_at(t, 600).step, &"mourn")
	assert_eq(VisitRules.segment_at(t, 2000).phase, &"gone")


func test_rules_slots_caps() -> void:
	assert_eq(VisitRules.assign_slots(4, [], 60, cfg), PackedInt32Array([570, 750, 900, -1]), "≤ 3 a day")
	assert_eq(VisitRules.assign_slots(2, [[800, 870], [860, 930]], 69, cfg), PackedInt32Array([570, -1]), "villagers count")
	assert_eq(VisitRules.assign_slots(1, [[560, 640], [565, 600]], 60, cfg), PackedInt32Array([750]), "≤ 2 at once")


# --- plan ----------------------------------------------------------------------------------------

func test_first_visit_the_day_after_the_burial() -> void:
	h.bury("l_01", &"house_kehr", 54)
	assert_eq(h.plan(54), [], "not on the day of the burial")
	var plan := h.plan(55)
	assert_eq(plan.size(), 1)
	assert_eq([plan[0].kin_id, plan[0].graves, plan[0].slot, plan[0].flowers], ["kin_kehr", ["l_01"], 570, true], "always with flowers")
	assert_eq(plan, h.plan(55), "deterministic")


func test_household_walks_all_its_graves_and_kin_for_grave() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.bury("l_04", &"house_kehr", 50)
	h.bury("l_02", &"house_brandt", 54)
	assert_eq(h.visitors.kin_for_grave("l_04"), &"kin_kehr")
	assert_eq(h.visitors.kin_for_grave("l_02"), &"kin_brandt")
	assert_eq(h.visitors.kin_for_grave("l_05"), &"", "nobody")
	assert_eq(h.visitors.graves_of(&"kin_kehr"), PackedStringArray(["l_01", "l_04"]))
	var plan := h.plan(55)
	assert_eq(plan.map(func(v: Dictionary) -> String: return v.kin_id), ["kin_kehr", "kin_brandt"])
	assert_eq(plan[0].graves, ["l_01", "l_04"], "one round")
	assert_eq([plan[0].slot, plan[1].slot], [570, 750], "the slots in order")


func test_caps_and_villagers() -> void:
	h.all_kin()
	for spec: Array in [["l_01", &"house_kehr"], ["l_02", &"house_brandt"], ["l_03", &"house_ott"], ["l_04", &"house_sieber"]]:
		h.bury(spec[0], spec[1], 54)
	var plan := h.plan(55)
	assert_eq(plan.size(), 3, "≤ 3 visits a day")
	var kins: Array = plan.map(func(v: Dictionary) -> String: return v.kin_id)
	assert_true(kins.has("kin_smith") and kins.has("kin_grocer"), "Esch and Theres come on p8_open_day + 2")
	assert_eq(GameState.get_flag(&"visit_smith_day"), 55, "visit_<npc>_day for the graveyard Npc")
	assert_eq(GameState.get_flag(&"visit_grocer_day"), 55)
	var esch: Dictionary = plan.filter(func(v: Dictionary) -> bool: return v.kin_id == "kin_smith")[0]
	assert_eq([esch.graves, esch.slot], [["old_01"], 820], "at old_01 13:40")
	var households: Array = plan.filter(func(v: Dictionary) -> bool: return not String(v.kin_id) in ["kin_smith", "kin_grocer"])
	assert_eq(households.size(), 1)
	assert_eq(households[0].kin_id, "kin_brandt", "the first by due day, then kin id")
	var next := h.plan(56)
	assert_eq(next.size(), 3, "the overflow comes tomorrow")


func test_liesel_visits_her_circle() -> void:
	h.all_kin()
	h.bury("l_05", &"cottage_dorn", 50)
	h.bury("l_09", &"", 40, 9, &"d1_hagedorn")
	assert_eq(h.visitors.graves_of(&"kin_washer"), PackedStringArray(["l_05", "l_09"]), "both cottages + D1")
	assert_eq(h.visitors.kin_for_grave("l_09"), &"kin_washer")
	var plan := h.plan(54)
	var liesel: Array = plan.filter(func(v: Dictionary) -> bool: return v.kin_id == "kin_washer")
	assert_eq(liesel.size(), 1, "p8_open_day + 1")
	assert_eq(liesel[0].slot, 580, "09:40 at the grave")


func test_no_visits_before_open_on_the_lights_or_at_a_dug_grave() -> void:
	h.bury("l_01", &"house_kehr", 54)
	GameState.set_flag(&"fest_lights_day", 55)
	assert_eq(h.plan(55), [], "the night of the lights")
	GameState.clear_flag(&"fest_lights_day")
	GameState.set_flag(&"p8_open", false)
	assert_eq(h.plan(55), [], "before p8_open")
	GameState.set_flag(&"p8_open", true)
	h.graveyard.get_grave("l_01").state = GraveRecord.State.DUG
	assert_eq(h.plan(55), [], "a DUG grave")


func test_plan_at_six_from_the_clock() -> void:
	h.bury("l_01", &"house_kehr", 54)
	TimeManager.load_state({"day": 55, "minute_of_day": 350})
	TimeManager.advance(9)
	assert_eq(h.visitors.save_state().plan, [], "05:59")
	TimeManager.advance(1)
	assert_eq(h.visitors.save_state().plan_day, 55)
	assert_eq((h.visitors.save_state().plan as Array).size(), 1, "planned at 06:00")


# --- the visit on the clock ----------------------------------------------------------------------

func test_visit_phases_bouquet_and_look() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	var id := h.visit_id(&"kin_kehr")
	assert_eq(h.visitors.active_visits(), [], "before 09:30")
	h.walk_clock(571)
	assert_eq(h.visitors.visit_state(id).phase, &"arriving")
	assert_eq(changed.back(), [id, &"kin_kehr", "l_01", &"arriving"])
	h.walk_clock(586)
	assert_true(h.care.bouquet_fresh("l_01"), "the bouquet on the mound")
	assert_eq(h.visitors.visit_state(id).step, &"mourn")
	assert_eq(h.visitors.active_visits().size(), 1)
	assert_true(h.visitors.mourning_at("l_01"), "the apprentice leaves her alone")
	var viewed := [false]
	var cb := func(_g: String, _k: StringName, _v: StringName) -> void: viewed[0] = true
	EventBus.grave_viewed.connect(cb)
	h.walk_clock(618)
	EventBus.grave_viewed.disconnect(cb)
	assert_true(viewed[0], "the look at 10:17")
	assert_eq(h.rep.count(&"visit_pleased"), 1, "kept")
	assert_eq(h.visitors.visit_state(id).phase, &"waiting", "a wish to offer: she waits")
	assert_false(h.visitors.waiting_visit().is_empty())
	assert_true(h.visitors.visited_on("l_01", 55))
	h.walk_clock(700)
	assert_eq(h.visitors.visit_state(id).phase, &"gone")
	assert_eq(changed.map(func(c: Array) -> StringName: return c[3]), [&"arriving", &"mourning", &"waiting", &"leaving", &"gone"])
	assert_eq(GameState.get_stat(&"visits_total"), 1)
	assert_eq(h.visitors.active_visits(), [])


func test_time_skip_runs_the_whole_visit() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.clock(1000)
	assert_eq(h.rep.count(&"visit_pleased"), 1, "the look taken once")
	assert_eq(GameState.get_stat(&"visits_total"), 1)
	h.clock(1100)
	assert_eq(h.rep.count(&"visit_pleased"), 1, "not again")


func test_save_load_mid_visit_without_replay() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.walk_clock(620)
	var state := h.visitors.save_state()
	var json: Variant = JSON.parse_string(JSON.stringify(state))
	var other := Visitors.new()
	other.config = cfg
	other.kin_data = Phase8Fixtures.kin_list()
	h.root.add_child(other)
	h.visitors.queue_free()
	await wait_frames(1)
	other.load_state(json)
	assert_eq(other.save_state(), state, "identical after JSON")
	assert_eq(other.visit_state(str(state.plan[0].visit_id)).phase, &"waiting", "she stands where plan + clock put her")
	h.walk_clock(700)
	assert_eq(h.rep.count(&"visit_pleased"), 1, "the look is not replayed")
	assert_eq(GameState.get_stat(&"visits_total"), 1)


func test_noise_near_a_mourner() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.walk_clock(590)
	var plot := h.root.get_node("l_01") as Node3D
	h.visitors.note_noise(plot.global_position + Vector3(9.0, 0, 0), &"dig")
	assert_eq(h.rep.count(&"visit_noise"), 0, "9 m")
	h.visitors.note_noise(plot.global_position + Vector3(2.0, 0, 0), &"water")
	assert_eq(h.rep.count(&"visit_noise"), 0, "not a noisy action")
	h.visitors.note_noise(plot.global_position + Vector3(7.5, 0, 0), &"dig")
	assert_eq(h.rep.count(&"visit_noise"), 1, "≤ 8 m")
	h.visitors.note_noise(plot.global_position, &"chop")
	assert_eq(h.rep.count(&"visit_noise"), 1, "once per visit")
	assert_eq(h.life.events.back()[0], &"noise_at_grave")


func test_noise_once_a_day() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.bury("l_02", &"house_brandt", 54)
	h.plan(55)
	h.walk_clock(590)
	h.visitors.note_noise((h.root.get_node("l_01") as Node3D).global_position, &"dig")
	h.walk_clock(770)
	h.visitors.note_noise((h.root.get_node("l_02") as Node3D).global_position, &"dig")
	assert_eq(h.rep.count(&"visit_noise"), 1, "at most once a day")


func test_next_visit_in_mourning_rhythm() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.clock(1000)
	var due := VisitRules.next_due("l_01", 54, 55, 53, cfg)
	for day: int in range(56, due):
		assert_eq(h.plan(day), [], "day %d" % day)
	assert_eq(h.plan(due).size(), 1, "day %d" % due)


func test_opening_after_six_plans_the_rest_of_the_day() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.bury("l_02", &"house_brandt", 54)
	GameState.set_flag(&"p8_open", false)
	TimeManager.load_state({"day": 55, "minute_of_day": 359})
	TimeManager.advance(1)
	assert_eq(h.visitors.save_state().plan, [], "not open yet at 06:00")
	TimeManager.advance(300)
	GameState.set_flag(&"p8_open", true)
	TimeManager.advance(1)
	var plan: Array = h.visitors.save_state().plan
	assert_eq(plan.size(), 1, "opened at 11:01: only the visit still to come")
	assert_eq(int(plan[0].slot), 750)
	assert_true(h.visitors.save_state().plan_open)


func test_fixture_phase_key_still_works() -> void:
	var v := Phase8Fixtures.visit_now(&"kin_kehr", "l_02", &"mourning", tree, 55)
	assert_eq(v.active_visits().size(), 1)
	assert_eq(v.visit_of(&"kin_kehr").phase, &"mourning")
	assert_true(v.mourning_at("l_02"))
	v.queue_free()
	await wait_frames(1)


func test_kin_house_at_the_delivery() -> void:
	var cm := CorpseManager.new()
	var r := CorpseRecord.new()
	r.seed = 4711
	GameState.clear_flag(&"village_open")
	cm.assign_kin_house(r, 55)
	assert_eq(r.kin_house, &"", "before village_open nothing")
	GameState.set_flag(&"village_open", true)
	cm.assign_kin_house(r, 55)
	var houses := PackedStringArray(["house_kehr", "house_brandt", "house_ott", "house_sieber", "cottage_dorn"])
	assert_eq(r.kin_house, StringName(houses[posmod(hash([55, 4711]), houses.size())]), "the Phase-7 mourning ribbon")
	var d2 := CorpseRecord.new()
	d2.story_id = &"d2_ott"
	cm.assign_kin_house(d2, 59)
	assert_eq(d2.kin_house, &"house_ott", "§2.9 Gesa Ott")
	cm.free()


func test_stub_free() -> void:
	for path: String in ["res://src/systems/visitors/visitors.gd", "res://src/systems/visitors/visit_rules.gd",
			"res://src/systems/visitors/wish_rules.gd", "res://src/systems/visitors/grave_view.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("## STUB ("), path)

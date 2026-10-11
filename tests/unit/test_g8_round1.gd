extends TestCase
## G8 Runde 1 (user decisions on the four open points, docs/PHASE8_DESIGN.md „(G8 Runde 1 angepasst)"):
## B8-1 visitors wait longer (a household up to 100 minutes, till 16:30, gone 3 minutes after the talk; every visitor
## waits for a word; villagers 18) and the gate bell (GateBell: cue, swing, HUD note only on the graveyard);
## B8-2 the vase wish names where the vase comes from (WishData.source_text → the wish card's „Woher" line);
## E8-2 the stipend stays in the parish chest from 80 coins on (Phase 8 open); B8-3 the village-wide talk about the
## jars – every tip one smaller once a specimen was sold.

const Harness := preload("res://tests/unit/visitors_harness.gd")
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")


## A player stand-in with just the region (GateBell reads region_id).
class PlayerRegion extends Node3D:
	var region_id: StringName = &"graveyard"
	var in_interior: bool = false

var h: Harness
var cfg: VisitorConfig
var notes: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.load_state({"day": 53, "minute_of_day": 300})
	cfg = (Database.config(&"visitor_config") as VisitorConfig).duplicate(true) as VisitorConfig
	h = Harness.new()
	h.setup(tree)
	h.households_only()
	h.visitors.config = cfg
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	h.teardown()
	await wait_frames(1)
	GameState.reset()


func _on_note(text: String, _kind: StringName) -> void:
	notes.append(text)


# --- B8-1: the wait ----------------------------------------------------------------------------------------

func test_data_values() -> void:
	assert_eq([cfg.wait_minutes, cfg.wait_min_minutes, cfg.wait_until_minute, cfg.wait_minutes_villager,
			cfg.leave_after_talk_minutes, cfg.wait_always, cfg.bell_cue], [100, 10, 990, 18, 3, true, &"gate_bell"])
	var defaults := VisitorConfig.new()
	assert_eq([defaults.wait_minutes, defaults.wait_minutes_villager, defaults.wait_always, defaults.rumor_tip_malus],
			[cfg.wait_minutes, cfg.wait_minutes_villager, cfg.wait_always, cfg.rumor_tip_malus], "class default = .tres")


func test_wait_length_rules() -> void:
	assert_eq(VisitRules.wait_length(617, false, cfg), 100, "09:30 slot: the full 100 minutes")
	assert_eq(VisitRules.wait_length(947, false, cfg), 43, "15:00 slot: till 16:30")
	assert_eq(VisitRules.wait_length(985, false, cfg), 10, "never less than wait_min_minutes")
	assert_eq(VisitRules.wait_length(617, true, cfg), 18, "villagers: their day goes on in the village")
	assert_eq(VisitRules.wait_after_talk(100, 617, 640, cfg), 26, "gone 3 minutes after the talk")
	assert_eq(VisitRules.wait_after_talk(100, 617, 800, cfg), 100, "never longer than the wait")


func test_a_household_waits_for_a_word_even_without_a_wish() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	var id := h.visit_id(&"kin_kehr")
	# Three wishes open already: nothing to offer, no tip – before G8 she left right after the look.
	h.visitors.load_state(_with_open_wishes(h.visitors.save_state(), 3))
	h.walk_clock(620)
	assert_eq(h.visitors.visit_state(id).phase, &"waiting", "she waits for a word")
	h.walk_clock(700)
	assert_eq(h.visitors.visit_state(id).phase, &"waiting", "still at 11:40 (≈ 40 minutes were the old window)")
	h.walk_clock(720)
	assert_eq(h.visitors.visit_state(id).phase, &"leaving", "after 100 minutes she goes")


func test_she_goes_three_minutes_after_the_talk() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	var id := h.visit_id(&"kin_kehr")
	h.walk_clock(630)
	assert_eq(h.visitors.visit_state(id).phase, &"waiting")
	var kin := Phase8Fixtures.kin(&"kin_kehr")
	EventBus.dialogue_ended.emit(kin.dialogue_id)
	assert_true(h.visitors.save_state().plan[0].has("talked"), "the end of the talk is saved")
	h.walk_clock(632)
	assert_eq(h.visitors.visit_state(id).phase, &"waiting")
	h.walk_clock(634)
	assert_eq(h.visitors.visit_state(id).phase, &"leaving", "3 minutes later she goes")
	assert_false(h.visitors.note_talked(id), "once")


func test_a_tip_still_in_her_hand_keeps_her_waiting() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	var id := h.visit_id(&"kin_kehr")
	h.walk_clock(630)
	var st := h.visitors.save_state()
	st.plan[0]["tip"] = 2
	h.visitors.load_state(st)
	assert_false(h.visitors.note_talked(id), "the coins are not taken yet")
	h.walk_clock(690)
	assert_eq(h.visitors.visit_state(id).phase, &"waiting")


func test_save_load_after_the_talk_keeps_the_timeline() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	var id := h.visit_id(&"kin_kehr")
	h.walk_clock(630)
	assert_true(h.visitors.note_talked(id))
	var state := h.visitors.save_state()
	var json: Variant = JSON.parse_string(JSON.stringify(state))
	h.visitors.load_state(json)
	assert_eq(h.visitors.save_state(), state, "identical after JSON")
	h.walk_clock(634)
	assert_eq(h.visitors.visit_state(id).phase, &"leaving")


func test_villagers_wait_eighteen_minutes() -> void:
	h.all_kin()
	h.plan(55)
	var esch := h.visitors.visit_of(&"kin_smith")
	assert_false(esch.is_empty(), "Esch comes on p8_open_day + 2")
	h.walk_clock(853)
	assert_eq(h.visitors.visit_state(str(esch.visit_id)).phase, &"waiting", "after the look at 14:12")
	h.walk_clock(871)
	assert_eq(h.visitors.visit_state(str(esch.visit_id)).phase, &"leaving", "14:30 – his data schedule leaves then")


func test_villager_schedules_match_the_wait() -> void:
	# Theres stays until 15:30, Liesel until 12:00 on their visit days (build_phase8_schedules.py).
	for spec: Array in [[&"grocer", "visit_grocer_day", 930], [&"washer", "visit_washer_day", 720]]:
		var sched := load("res://data/npc/%s_schedule.tres" % spec[0]) as NpcSchedule
		var leaves := sched.entries.filter(func(e: ScheduleEntry) -> bool:
			return String(e.today_flag) == spec[1] and e.start_minute == spec[2])
		assert_false(leaves.is_empty(), "%s walks down at %d" % [spec[0], spec[2]])


# --- B8-1: the gate bell -------------------------------------------------------------------------------------

func test_gate_bell_rings_when_a_visitor_comes_up() -> void:
	var bell := GateBell.new()
	h.root.add_child(bell)
	var player := PlayerRegion.new()
	player.add_to_group(&"player")
	h.root.add_child(player)
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	h.walk_clock(571)
	assert_eq(bell.rings, 1, "the bell at the gate")
	assert_has(notes, "Am Tor läutet es – Martha Kehr kommt herauf.")
	h.walk_clock(700)
	assert_eq(bell.rings, 1, "only on arriving")
	player.set(&"region_id", &"village")
	notes.clear()
	assert_false(bell.ring("Martha Kehr"), "no note in the village")
	assert_eq(notes, [])
	player.queue_free()


func test_gate_bell_cue_and_model() -> void:
	assert_true(Audio.has_cue(&"gate_bell"), "cue gate_bell")
	var path := "res://assets/models/props/ph_prop_gate_bell.glb"
	assert_true(ResourceLoader.exists(path))
	var model := (load(path) as PackedScene).instantiate() as Node3D
	var bell := model.find_child("bell", true, false) as Node3D
	assert_not_null(bell, "the swinging child mesh")
	var tris := 0
	for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			tris += (mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_true(tris >= 40 and tris <= 600, "%d tris" % tris)
	var bracket := bell.get_parent() as MeshInstance3D
	assert_not_null(bracket, "the bell hangs from the bracket")
	var top := bracket.get_aabb().end.y
	assert_true(top > 1.6 and top <= 1.85, "below the post top 1.85 m (%.2f)" % top)
	assert_true(bell.position.y > 1.6, "the pivot at the arm (%.2f)" % bell.position.y)
	model.free()


# --- B8-2: the vase ------------------------------------------------------------------------------------------

func test_vase_wish_names_where_the_vase_comes_from() -> void:
	var w := Database.wish(&"w_vase") as WishData
	assert_true(w.source_text.contains("Werkbank") and w.source_text.contains("Theres"), w.source_text)
	assert_true(w.ask_text.contains("Werkbank"), "she says it too")
	var recipe := Database.recipe(&"decor_grave_vase") as RecipeData
	assert_eq([recipe.station, recipe.requires_flag], [&"workbench", &""], "at the workbench, always")
	assert_eq(recipe.inputs, {&"stone": 1, &"seeds": 1} as Dictionary[StringName, int])
	var grocer := Database.shop(&"grocer") as ShopData
	assert_true(grocer.sells.has(&"seeds"), "seeds at Theres' shop")


func test_the_offer_carries_the_origin() -> void:
	h.bury("l_01", &"house_kehr", 54)
	h.plan(55)
	var id := h.visit_id(&"kin_kehr")
	var st := h.visitors.save_state()
	st["wishes"] = [{"wish_id": "w_0007", "kind": "vase", "grave_id": "l_01", "kin_id": "kin_kehr", "state": "offered",
			"day": 55, "candle_seen": false, "template": "w_vase"}]
	st.plan[0]["offered"] = "w_0007"
	h.visitors.load_state(st)
	var card := h.visitors.offer_wish(id)
	assert_eq(str(card.get("source", "")), (Database.wish(&"w_vase") as WishData).source_text, "the wish card origin line")


# --- E8-2 / B8-3: coins -----------------------------------------------------------------------------------------

func test_stipend_stays_in_the_parish_chest_from_eighty_coins() -> void:
	var rep := Reputation.new()
	rep.config = (Database.config(&"reputation_config") as ReputationConfig).duplicate(true) as ReputationConfig
	assert_eq([rep.config.stipend_purse_cap, rep.config.stipend_cap_flag], [80, &"p8_open"])
	var bag := FakeInventory.new()
	rep.stipend_inventory = bag
	h.root.add_child(rep)
	GameState.stats[&"reputation"] = 100
	bag.add_item(&"coin", 79)
	assert_eq(int(rep.apply_daily(60).stipend), 4, "79: paid")
	bag.add_item(&"coin", 1)
	assert_eq(int(rep.apply_daily(61).stipend), 0, "80: withheld")
	assert_true(bool(rep.last_daily().get("stipend_withheld", false)))
	assert_true(notes.any(func(t: String) -> bool: return t.contains("Gemeindekasse")), "the note")
	GameState.set_flag(&"p8_open", false)
	assert_eq(int(rep.apply_daily(62).stipend), 4, "before Phase 8: as in Phase 3–7")


func test_the_village_talks_about_the_jars() -> void:
	h.bury("l_01", &"house_kehr", 54, 16)
	assert_false(h.visitors.village_rumor())
	GameState.add_stat(&"specimens_sold", 1)
	assert_true(h.visitors.village_rumor(), "every family hears it")
	var full := WishRules.tip(8, 16, 0, cfg)
	assert_eq(full, 3)
	# A done wish of Martha Kehr pays one coin less.
	h.plan(55)
	var st := h.visitors.save_state()
	st["wishes"] = [{"wish_id": "w_0001", "kind": "tend", "grave_id": "l_01", "kin_id": "kin_kehr", "state": "accepted",
			"day": 54, "candle_seen": false, "template": "w_tend"}]
	st["goodwill"] = {"kin_kehr": 8}
	h.visitors.load_state(st)
	h.walk_clock(620)
	assert_eq(h.visitors.tip_of(h.visit_id(&"kin_kehr")), full - cfg.rumor_tip_malus)


# --- helpers ------------------------------------------------------------------------------------------------

## Three accepted wishes on other graves (max_open reached – nothing left to offer).
func _with_open_wishes(st: Dictionary, n: int) -> Dictionary:
	var list: Array = []
	for i: int in n:
		list.append({"wish_id": "w_%04d" % (i + 1), "kind": "candle", "grave_id": ["l_02", "l_03", "l_04"][i], "kin_id": "kin_brandt",
				"state": "accepted", "day": 55, "candle_seen": false, "template": "w_candle"})
	st["wishes"] = list
	return st

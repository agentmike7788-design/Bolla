extends TestCase
## Phase 3 (P1, docs/PHASE3_DESIGN.md §1.2, §2.1, §3.4 "Ausbau"): ExpansionManager – sections,
## prerequisites and their texts, atomic clearing (cost off, yield in), progress, automatic
## unlock after the last obstacle (plots EMPTY, signals, reputation +4), debug unlock,
## save/load, post_load repair. ClearableObstacle: world_rect and cleared state.
## Uses the Phase-3 fixtures (sections, clearables) and doubles for plots, score, reputation.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const LOCKED := GraveRecord.State.LOCKED
const EMPTY := GraveRecord.State.EMPTY


## Grave place with a section (group "grave_plot").
class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false
	var section_id: StringName = &"yard"


## CemeteryScore with a fixed rating.
class ScoreDouble extends CemeteryScore:
	var tier: StringName = &"neglected"

	func rating() -> StringName:
		return tier


## Reputation (group "reputation"): records change / event calls.
class ReputationDouble extends Reputation:
	var calls: Array = []

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])


## Inventory without room for anything.
class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false


var world: Node3D
var graveyard: Graveyard
var expansion: ExpansionManager
var score: ScoreDouble
var rep: ReputationDouble
var inv: Inventory
var obstacles: Dictionary = {}
var events: Array = []


func before_each() -> void:
	world = Node3D.new()
	world.name = "World"
	graveyard = Graveyard.new()
	graveyard.economy = load(FIXTURE_ECONOMY) as EconomyConfig
	graveyard.tables = load(FIXTURE_TABLES) as CorpseTables
	graveyard.section_data = Phase3Fixtures.sections()
	graveyard.reputation_config = Phase3Fixtures.reputation_config()
	world.add_child(graveyard)
	expansion = ExpansionManager.new()
	expansion.section_data = Phase3Fixtures.sections()
	for id: StringName in Phase3Fixtures.CLEARABLE_IDS:
		expansion.clearable_data[id] = Phase3Fixtures.clearable(id)
	world.add_child(expansion)
	score = ScoreDouble.new()
	world.add_child(score)
	rep = ReputationDouble.new()
	world.add_child(rep)
	for spec: Array in [["plot_01", &"yard"], ["plot_07", &"east"], ["plot_08", &"east"], ["plot_09", &"east"],
			["plot_10", &"north"], ["plot_11", &"north"], ["plot_12", &"north"]]:
		var plot := PlotDouble.new()
		plot.grave_id = spec[0]
		plot.section_id = spec[1]
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	obstacles.clear()
	for spec: Array in [["obs_e_01", &"east", &"bramble"], ["obs_e_02", &"east", &"rubble"], ["obs_e_gap_1", &"east", &"fence_gap"],
			["obs_n_hedge", &"north", &"hedge"], ["obs_n_01", &"north", &"stump"]]:
		var obstacle := ClearableObstacle.new()
		obstacle.obstacle_id = spec[0]
		obstacle.section_id = spec[1]
		obstacle.kind = spec[2]
		obstacle.name = spec[0]
		world.add_child(obstacle)
		obstacles[spec[0]] = obstacle
	tree.root.add_child(world)
	inv = FakeInventory.new()
	events.clear()
	EventBus.obstacle_cleared.connect(_on_cleared)
	EventBus.section_progress_changed.connect(_on_progress)
	EventBus.section_unlocked.connect(_on_unlocked)
	EventBus.grave_state_changed.connect(_on_state)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.obstacle_cleared.disconnect(_on_cleared)
	EventBus.section_progress_changed.disconnect(_on_progress)
	EventBus.section_unlocked.disconnect(_on_unlocked)
	EventBus.grave_state_changed.disconnect(_on_state)
	EventBus.notification_requested.disconnect(_on_note)
	inv.free()


# --- setup ---

func test_groups_and_save_contract() -> void:
	assert_true(expansion.is_in_group(&"expansion"))
	assert_true(expansion.is_in_group(&"saveable"))
	assert_eq([expansion.save_id, expansion.save_order], ["expansion", 5])


func test_sections_and_initial_state() -> void:
	var ids: Array = []
	for s: SectionData in expansion.sections():
		ids.append(s.id)
	assert_eq(ids, [&"yard", &"east", &"north"], "sorted by order")
	assert_true(expansion.is_unlocked(&"yard"))
	assert_false(expansion.is_unlocked(&"east"))
	assert_false(expansion.is_unlocked(&"north"))
	assert_false(expansion.is_unlocked(&"nowhere"))
	assert_eq(expansion.unlocked_indices(), PackedInt32Array([1]))
	assert_eq(expansion.obstacle_ids(&"east"), PackedStringArray(["obs_e_01", "obs_e_02", "obs_e_gap_1"]))
	assert_eq(expansion.progress(&"east"), Vector2i(0, 3))
	assert_eq(expansion.progress(&"north"), Vector2i(0, 2))
	assert_eq(expansion.progress(&"yard"), Vector2i(0, 0))
	assert_eq(graveyard.get_grave("plot_07").state, LOCKED)
	assert_eq(graveyard.get_grave("plot_01").state, EMPTY)
	assert_eq(expansion.data_of("obs_e_gap_1").id, &"fence_gap")
	assert_null(expansion.data_of("obs_nope"))
	for id: String in obstacles:
		assert_false((obstacles[id] as ClearableObstacle).cleared, id)


func test_real_data_is_used_without_injection() -> void:
	var plain := ExpansionManager.new()
	world.add_child(plain)
	assert_eq(plain.sections().size(), 4, "Phase 4: + elder")
	assert_eq(plain.data_of("obs_e_01"), Database.clearable(&"bramble"))
	plain.free()


# --- prerequisites ---

func test_block_reasons() -> void:
	assert_eq(expansion.block_reason(&"east"), "", "east: from day 1")
	assert_eq(expansion.block_reason(&"yard"), "")
	assert_eq(expansion.block_reason(&"north"), "Erst die Ostwiese freilegen")
	expansion.unlock(&"east")
	score.tier = &"tended"
	var at: int = graveyard.economy.rating_thresholds[2]
	assert_eq(expansion.block_reason(&"north"), "Erst Friedhof „Würdevoll“ (%d)" % at)
	score.tier = &"dignified"
	assert_eq(expansion.block_reason(&"north"), "")


func test_rating_falls_back_to_the_graveyard_without_score() -> void:
	score.remove_from_group(&"cemetery_score")
	expansion.unlock(&"east")
	assert_true(expansion.block_reason(&"north").begins_with("Erst Friedhof"), "no graves: neglected")
	score.add_to_group(&"cemetery_score")
	score.tier = &""
	assert_true(expansion.block_reason(&"north").begins_with("Erst Friedhof"), "empty rating: fallback")


func test_blocked_section_cannot_be_cleared() -> void:
	assert_false(expansion.can_clear("obs_n_hedge", inv))
	assert_false(expansion.clear("obs_n_hedge", inv))
	expansion.unlock(&"east")
	score.tier = &"tended"
	assert_false(expansion.can_clear("obs_n_hedge", inv), "rating missing")
	score.tier = &"dignified"
	assert_true(expansion.can_clear("obs_n_hedge", inv))
	assert_eq(inv.count(&"wood"), 0, "checks change nothing")


# --- cost & yield ---

func test_missing_cost_and_can_clear() -> void:
	assert_eq(expansion.missing_cost("obs_e_gap_1", inv), {&"wood": 2, &"iron_fittings": 1})
	assert_false(expansion.can_clear("obs_e_gap_1", inv))
	inv.add_item(&"wood", 3)
	assert_eq(expansion.missing_cost("obs_e_gap_1", inv), {&"iron_fittings": 1})
	inv.add_item(&"iron_fittings", 1)
	assert_eq(expansion.missing_cost("obs_e_gap_1", inv), {})
	assert_true(expansion.can_clear("obs_e_gap_1", inv))
	assert_eq(expansion.missing_cost("obs_e_01", inv), {}, "bramble costs nothing")
	assert_eq(expansion.missing_cost("obs_nope", inv), {})
	assert_false(expansion.can_clear("obs_nope", inv))
	assert_false(expansion.can_clear("obs_e_01", null))


func test_yield_must_fit() -> void:
	var full := FullInventory.new()
	full.add_item(&"wood", 2)
	full.add_item(&"iron_fittings", 1)
	assert_false(expansion.yield_fits("obs_e_01", full))
	assert_false(expansion.can_clear("obs_e_01", full), "no room for the wood")
	assert_false(expansion.clear("obs_e_01", full))
	assert_true(expansion.can_clear("obs_e_gap_1", full), "a fence gap yields nothing")
	full.free()


func test_clear_is_atomic() -> void:
	inv.add_item(&"wood", 2)
	inv.add_item(&"iron_fittings", 1)
	assert_true(expansion.clear("obs_e_gap_1", inv))
	assert_eq([inv.count(&"wood"), inv.count(&"iron_fittings")], [0, 0], "cost taken")
	assert_true(expansion.is_cleared("obs_e_gap_1"))
	assert_true((obstacles["obs_e_gap_1"] as ClearableObstacle).cleared)
	assert_eq(events, [["cleared", "obs_e_gap_1", &"east"], ["progress", &"east", 1, 3]])
	events.clear()
	assert_false(expansion.clear("obs_e_gap_1", inv), "already cleared")
	assert_true(expansion.clear("obs_e_02", inv))
	assert_eq(inv.count(&"stone"), 2, "rubble yields 2 stone")
	assert_eq(expansion.progress(&"east"), Vector2i(2, 3))
	assert_false(expansion.is_unlocked(&"east"))
	assert_eq(rep.calls, [], "no reputation before the unlock")


# --- unlock ---

func test_last_obstacle_unlocks_the_section() -> void:
	inv.add_item(&"wood", 2)
	inv.add_item(&"iron_fittings", 1)
	expansion.clear("obs_e_gap_1", inv)
	expansion.clear("obs_e_02", inv)
	events.clear()
	assert_true(expansion.clear("obs_e_01", inv))
	assert_eq(inv.count(&"wood"), 1, "bramble yields 1 wood")
	assert_true(expansion.is_unlocked(&"east"))
	assert_eq(expansion.unlocked_indices(), PackedInt32Array([1, 2]))
	assert_eq(events, [
		["cleared", "obs_e_01", &"east"],
		["progress", &"east", 3, 3],
		["state", "plot_07", EMPTY], ["state", "plot_08", EMPTY], ["state", "plot_09", EMPTY],
		["unlocked", &"east"],
		["note", "Die Ostwiese ist freigelegt – 3 neue Grabstellen.", &"reward"],
	])
	for id: String in ["plot_07", "plot_08", "plot_09"]:
		assert_eq(graveyard.get_grave(id).state, EMPTY, id)
	assert_eq(graveyard.get_grave("plot_10").state, LOCKED)
	assert_eq(rep.calls, [["event", &"section_unlocked", "Ostwiese freigelegt"]], "reputation +4 via event points")
	assert_eq(Phase3Fixtures.reputation_config().event_points[&"section_unlocked"], 4)
	assert_eq(expansion.block_reason(&"east"), "")


func test_debug_unlock_clears_the_rest_once() -> void:
	expansion.clear("obs_e_01", inv)
	events.clear()
	assert_true(expansion.unlock(&"east"))
	assert_true(expansion.is_cleared("obs_e_02"))
	assert_true((obstacles["obs_e_gap_1"] as ClearableObstacle).cleared)
	assert_eq(expansion.progress(&"east"), Vector2i(3, 3))
	assert_eq(events[0], ["progress", &"east", 3, 3])
	assert_false(_has("cleared"), "no obstacle_cleared for a debug unlock")
	assert_eq(graveyard.get_grave("plot_09").state, EMPTY)
	events.clear()
	assert_false(expansion.unlock(&"east"), "only once")
	assert_false(expansion.unlock(&"yard"), "open from the start")
	assert_false(expansion.unlock(&"nowhere"))
	assert_eq(events, [])
	assert_eq(rep.calls.size(), 1)


func test_unlock_without_reputation_node() -> void:
	rep.remove_from_group(&"reputation")
	assert_true(expansion.unlock(&"east"))
	assert_eq(rep.calls, [])
	assert_eq(graveyard.get_grave("plot_07").state, EMPTY)


# --- save / load ---

func test_save_load_round_trip() -> void:
	expansion.clear("obs_e_01", inv)
	expansion.unlock(&"east")
	expansion.unlock(&"north")
	var saved := expansion.save_state()
	assert_eq(saved.unlocked, [&"east", &"north"])
	assert_true((saved.cleared as Array).has("obs_e_01"))
	var plain: Dictionary = JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(saved))))
	expansion.load_state({})
	assert_false(expansion.is_unlocked(&"east"))
	assert_false((obstacles["obs_e_01"] as ClearableObstacle).cleared, "load {} shows every obstacle again")
	assert_eq(expansion.save_state(), {"cleared": [], "unlocked": []})
	expansion.load_state(plain)
	assert_eq(expansion.save_state().unlocked, saved.unlocked)
	assert_true(expansion.is_unlocked(&"north"))
	assert_true((obstacles["obs_n_hedge"] as ClearableObstacle).cleared, "obstacles of open sections cleared")
	var bare := JSON.parse_string(JSON.stringify(saved)) as Dictionary
	expansion.load_state(bare)
	assert_true(expansion.is_unlocked(&"east"), "plain JSON strings accepted")


func test_load_state_is_tolerant() -> void:
	expansion.load_state({"cleared": ["obs_e_02", 7, ""], "unlocked": ["moon", 3]})
	assert_true(expansion.is_cleared("obs_e_02"))
	assert_eq(expansion.progress(&"east"), Vector2i(1, 3))
	assert_eq(expansion.unlocked_indices(), PackedInt32Array([1]), "unknown section ignored")
	expansion.load_state({"cleared": "x", "unlocked": {}})
	assert_eq(expansion.save_state(), {"cleared": [], "unlocked": []})


func test_post_load_repairs_locked_plots_of_open_sections() -> void:
	expansion.unlock(&"east")
	var saved := expansion.save_state()
	graveyard.load_state({})
	assert_eq(graveyard.get_grave("plot_07").state, LOCKED, "graveyard state without the unlock")
	expansion.load_state(saved)
	expansion.post_load()
	assert_eq(graveyard.get_grave("plot_07").state, EMPTY, "repaired")
	assert_eq(graveyard.get_grave("plot_10").state, LOCKED)
	events.clear()
	expansion.post_load()
	assert_eq(events, [], "nothing to repair")


func test_collect_state_round_trip_via_save_manager() -> void:
	expansion.clear("obs_e_01", inv)
	var a := SaveManager.collect_state()
	assert_true(a.nodes.has("expansion"))
	SaveManager.apply_state(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(a)))))
	assert_eq(SaveManager.collect_state(), a)
	assert_true(expansion.is_cleared("obs_e_01"))


# --- ClearableObstacle ---

func test_obstacle_world_rect() -> void:
	var o: ClearableObstacle = obstacles["obs_e_01"]
	o.footprint = Rect2(-1, -0.5, 2, 1)
	o.position = Vector3(10, 0, -4)
	assert_eq(o.world_rect(), Rect2(9, -4.5, 2, 1))
	o.rotation.y = PI / 2
	var r := o.world_rect()
	assert_true(r.position.is_equal_approx(Vector2(9.5, -5)) and r.size.is_equal_approx(Vector2(1, 2)), "rotated: %s" % r)


func test_obstacle_scene_hides_model_when_cleared() -> void:
	var o := (load("res://src/entities/clearable/clearable.tscn") as PackedScene).instantiate() as ClearableObstacle
	o.obstacle_id = "obs_e_03"
	o.section_id = &"east"
	o.kind = &"fence_gap"
	var model := Node3D.new()
	model.name = "Model"
	o.add_child(model)
	var repaired := Node3D.new()
	repaired.name = "Repaired"
	o.add_child(repaired)
	world.add_child(o)
	expansion.collect_obstacles()
	assert_eq(expansion.progress(&"east"), Vector2i(0, 4))
	assert_true(model.visible)
	assert_false(repaired.visible)
	assert_true(o.interactable.enabled)
	inv.add_item(&"wood", 2)
	inv.add_item(&"iron_fittings", 1)
	expansion.clear("obs_e_03", inv)
	assert_false(model.visible)
	assert_true(repaired.visible, "fence gap: repaired fence")
	assert_false(o.interactable.enabled)


# --- helpers ---

func _has(kind: String) -> bool:
	for e: Array in events:
		if e[0] == kind:
			return true
	return false


func _on_cleared(id: String, section: StringName) -> void:
	events.append(["cleared", id, section])


func _on_progress(section: StringName, done: int, total: int) -> void:
	events.append(["progress", section, done, total])


func _on_unlocked(section: StringName) -> void:
	events.append(["unlocked", section])


func _on_state(id: String, state: int) -> void:
	events.append(["state", id, state])


func _on_note(text: String, kind: StringName) -> void:
	events.append(["note", text, kind])


# --- Phase 4 (P1, docs/PHASE4_DESIGN.md §2.10, §3.4): the Holunderwinkel -------------------------

## Journal (group "journal"): records add_clue calls.
class JournalDouble extends Node:
	var calls: Array = []

	func add_clue(id: StringName, corpse_id: String = "", silent: bool = false) -> bool:
		calls.append([id, corpse_id, silent])
		return true


func test_elder_needs_the_key_flag() -> void:
	_add_elder()
	assert_eq(expansion.block_reason(&"elder"), "Das Pförtchen ist verschlossen.")
	inv.add_item(&"wood", 5)
	inv.add_item(&"iron_fittings", 1)
	assert_false(expansion.can_clear("obs_h_gate", inv))
	assert_false(expansion.clear("obs_h_gate", inv))
	GameState.set_flag(&"has_elder_key", true)
	assert_eq(expansion.block_reason(&"elder"), "")
	assert_true(expansion.can_clear("obs_h_gate", inv))


func test_requires_flag_without_text_has_a_fallback() -> void:
	var s := Phase4Fixtures.elder_section().duplicate() as SectionData
	s.requires_flag_text = ""
	var list: Array[SectionData] = Phase3Fixtures.sections()
	list.append(s)
	expansion.section_data = list
	assert_eq(expansion.block_reason(&"elder"), ExpansionManager.TEXT_NEEDS_FLAG)


func test_clearing_the_holunderwinkel_opens_six_plots_and_the_clue() -> void:
	var journal := _add_elder()
	GameState.set_flag(&"has_elder_key", true)
	inv.add_item(&"wood", 2)
	inv.add_item(&"iron_fittings", 1)
	var ids := expansion.obstacle_ids(&"elder")
	assert_eq(ids.size(), 10, "gate + 2 thickets + 6 pits + gap")
	var minutes := 0
	for id: String in ids:
		minutes += expansion.data_of(id).minutes
	assert_eq(minutes, 300, "§2.10: 5 h")
	for id: String in ids:
		if id != "obs_h_gap_1":
			assert_true(expansion.clear(id, inv), id)
	assert_eq(journal.calls, [], "not before the last obstacle")
	assert_eq(inv.count(&"wood"), 6, "2 thickets × 2 wood")
	assert_true(expansion.clear("obs_h_gap_1", inv))
	assert_eq([inv.count(&"wood"), inv.count(&"iron_fittings")], [4, 0], "cost 2 wood + 1 iron, yield 4 wood")
	assert_true(expansion.is_unlocked(&"elder"))
	for i: int in 6:
		assert_eq(graveyard.get_grave("h_0%d" % (i + 1)).state, EMPTY)
	assert_eq(journal.calls, [[&"c_six_pits", "", false]])
	assert_has(events, ["note", Phase4Fixtures.elder_section().unlock_text, &"reward"])
	assert_has(rep.calls, ["event", &"section_unlocked", "Holunderwinkel freigelegt"])
	assert_eq(expansion.unlocked_indices(), PackedInt32Array([1, 4]))


func test_other_sections_add_no_clue() -> void:
	var journal := _add_elder()
	expansion.unlock(&"east")
	assert_eq(journal.calls, [])


func test_real_elder_data() -> void:
	var elder := Database.section(&"elder") as SectionData
	assert_not_null(elder)
	assert_eq([elder.order, elder.requires_flag, elder.counts_for_cemetery, elder.chapter, elder.decor_cap],
			[4, &"has_elder_key", false, &"six_pits", 6])
	var counts := {&"gate_small": 10, &"elder_thicket": 40, &"sunken_pit": 30}
	for kind: StringName in counts:
		var data := Database.clearable(kind) as ClearableData
		assert_not_null(data, String(kind))
		assert_eq(data.minutes, counts[kind], String(kind))
	assert_eq((Database.clearable(&"elder_thicket") as ClearableData).yield_items, {&"wood": 2})


## Adds the elder section (+ its plots and obstacles) to both managers; returns a journal double.
func _add_elder() -> JournalDouble:
	var sections: Array[SectionData] = Phase3Fixtures.sections()
	sections.append(Phase4Fixtures.elder_section())
	graveyard.section_data = sections
	expansion.section_data = sections
	for id: StringName in Phase4Fixtures.CLEARABLE_IDS:
		expansion.clearable_data[id] = Phase4Fixtures.clearable(id)
	for i: int in 6:
		var plot := PlotDouble.new()
		plot.grave_id = "h_0%d" % (i + 1)
		plot.section_id = &"elder"
		plot.add_to_group(&"grave_plot")
		world.add_child(plot)
	var specs: Array = [["obs_h_gate", &"gate_small"], ["obs_h_thicket_1", &"elder_thicket"], ["obs_h_thicket_2", &"elder_thicket"]]
	for i: int in 6:
		specs.append(["obs_h_pit_%d" % (i + 1), &"sunken_pit"])
	specs.append(["obs_h_gap_1", &"fence_gap"])
	for spec: Array in specs:
		var obstacle := ClearableObstacle.new()
		obstacle.obstacle_id = spec[0]
		obstacle.section_id = &"elder"
		obstacle.kind = spec[1]
		obstacle.name = spec[0]
		world.add_child(obstacle)
	graveyard.load_state({})
	expansion.collect_obstacles()
	var journal := JournalDouble.new()
	journal.add_to_group(&"journal")
	world.add_child(journal)
	return journal

extends TestCase
## P3 (docs/PHASE3_DESIGN.md §2.4, §3.4, §10): DirtGrowth rules and the CleanlinessManager –
## growth from game minutes (3 × 1 day == 1 × 3 days), locked sections / grave states / covered
## spots do not grow, tending (by hand, rake for leaves), penalty, start state vs. {} state,
## bundled signals, save/load; DirtSpot prompts. Other systems are group doubles.


class FakeExpansion extends Node:
	var open: Dictionary = {&"yard": true, &"east": false}

	func _init() -> void:
		add_to_group(&"expansion")

	func is_unlocked(section_id: StringName) -> bool:
		return bool(open.get(section_id, false))


class FakeGraveyard extends Node:
	var records: Dictionary = {}

	func _init() -> void:
		add_to_group(&"graveyard")

	func set_state(id: String, state: GraveRecord.State) -> void:
		var r := GraveRecord.new()
		r.id = id
		r.state = state
		records[id] = r

	func get_grave(id: String) -> GraveRecord:
		return records.get(id) as GraveRecord


class FakeDecorations extends Node:
	var covered: Array[Rect2] = []

	func _init() -> void:
		add_to_group(&"decorations")

	func suppresses_dirt_at(p: Vector2) -> bool:
		for r: Rect2 in covered:
			if r.has_point(p):
				return true
		return false


const DAY := 1440

var cfg: CleanlinessConfig
var world: Node3D
var expansion: FakeExpansion
var graveyard: FakeGraveyard
var decorations: FakeDecorations
var manager: CleanlinessManager
var inv: Inventory
var dirt_events: Array = []
var clean_events: Array = []


func before_each() -> void:
	cfg = Phase3Fixtures.cleanliness_config()
	world = Node3D.new()
	world.name = "CleanWorld"
	tree.root.add_child(world)
	expansion = FakeExpansion.new()
	graveyard = FakeGraveyard.new()
	decorations = FakeDecorations.new()
	world.add_child(expansion)
	world.add_child(graveyard)
	world.add_child(decorations)
	graveyard.set_state("plot_01", GraveRecord.State.EMPTY)
	_spot("dirt_y01", &"yard", &"weeds", Vector3(0, 0, 0), 1.5)
	_spot("dirt_y02", &"yard", &"leaves", Vector3(4, 0, 0), 2.2)
	_spot("dirt_y03", &"yard", &"weeds", Vector3(8, 0, 0))
	_spot("dirt_e01", &"east", &"weeds", Vector3(14, 0, 0), 1.0)
	_spot("dirt_plot_01", &"yard", &"weeds", Vector3(0, 0, 6), 0.0, "plot_01")
	inv = Inventory.new()
	world.add_child(inv)
	manager = CleanlinessManager.new()
	manager.config = cfg
	world.add_child(manager)
	EventBus.dirt_changed.connect(_on_dirt)
	EventBus.cleanliness_changed.connect(_on_clean)


func after_each() -> void:
	EventBus.dirt_changed.disconnect(_on_dirt)
	EventBus.cleanliness_changed.disconnect(_on_clean)


func _on_dirt(id: String, level: int) -> void:
	dirt_events.append([id, level])


func _on_clean(penalty: int, dirty: int) -> void:
	clean_events.append([penalty, dirty])


func _spot(id: String, section: StringName, kind: StringName, pos: Vector3, start: float = 0.0, grave: String = "") -> DirtSpot:
	var s := DirtSpot.new()
	s.name = id
	s.spot_id = id
	s.section_id = section
	s.kind = kind
	s.start_progress = start
	s.grave_id = grave
	s.position = pos
	world.add_child(s)
	return s


func _put(id: String, value: float) -> void:
	var data := manager.save_state()
	data.spots[id] = value
	manager.load_state(data)


# --- DirtGrowth ---------------------------------------------------------------------------

func test_rate_has_a_fixed_jitter_per_spot() -> void:
	for id: String in ["dirt_y01", "dirt_y02", "dirt_e03", "dirt_plot_07", "x"]:
		for kind: StringName in [&"weeds", &"leaves"]:
			var r := DirtGrowth.rate(id, kind, cfg)
			var base: float = cfg.growth_per_day[kind]
			assert_true(r >= base * 0.75 - 0.0001 and r <= base * 1.25 + 0.0001, "%s %s: %f" % [id, kind, r])
			assert_eq(DirtGrowth.rate(id, kind, cfg), r, "deterministic")
	assert_eq(DirtGrowth.rate("dirt_y01", &"moss", cfg), 0.0, "unknown kind does not grow")
	var no_jitter := cfg.duplicate() as CleanlinessConfig
	no_jitter.growth_jitter = 0.0
	assert_almost(DirtGrowth.rate("dirt_y01", &"weeds", no_jitter), 0.30)
	assert_almost(DirtGrowth.rate("dirt_y01", &"leaves", no_jitter), 0.40)
	var rates := {}
	for i: int in 20:
		rates[snappedf(DirtGrowth.rate("dirt_%02d" % i, &"weeds", cfg), 0.0001)] = true
	assert_true(rates.size() > 5, "spots differ")


func test_grow_is_a_function_of_minutes() -> void:
	var r := 0.3
	var three_single := DirtGrowth.grow(DirtGrowth.grow(DirtGrowth.grow(0.2, r, DAY, cfg), r, DAY, cfg), r, DAY, cfg)
	assert_almost(three_single, DirtGrowth.grow(0.2, r, 3 * DAY, cfg), 0.000001, "3 × 1 day == 1 × 3 days")
	assert_almost(DirtGrowth.grow(0.0, r, DAY, cfg), 0.3)
	assert_almost(DirtGrowth.grow(0.0, r, 60, cfg), 0.3 / 24.0)
	var hourly := 0.0
	for h: int in 24:
		hourly = DirtGrowth.grow(hourly, r, 60, cfg)
	assert_almost(hourly, 0.3, 0.000001, "24 × 1 h == 1 day")
	assert_eq(DirtGrowth.grow(1.2, r, 0, cfg), 1.2, "no minutes")
	assert_eq(DirtGrowth.grow(1.2, r, -30, cfg), 1.2, "negative minutes")
	assert_almost(DirtGrowth.grow(3.5, r, 100 * DAY, cfg), 3.999, 0.000001, "clamped to max_level + 0.999")


func test_level_is_floor_clamped() -> void:
	var cases := [[0.0, 0], [0.99, 0], [1.0, 1], [1.99, 1], [2.0, 2], [2.5, 2], [3.0, 3], [3.999, 3], [7.0, 3], [-1.0, 0]]
	for c: Array in cases:
		assert_eq(DirtGrowth.level(c[0], cfg), c[1], "progress %s" % str(c[0]))


# --- manager: growth ----------------------------------------------------------------------

func test_collects_the_spots() -> void:
	assert_eq(manager.spot_ids(), PackedStringArray(["dirt_y01", "dirt_y02", "dirt_y03", "dirt_e01", "dirt_plot_01"]))
	assert_eq(manager.last_total, TimeManager.total_minutes())
	for id: String in manager.spot_ids():
		assert_eq(manager.progress(id), 0.0, "%s starts at 0 until the start state" % id)


func test_growth_from_minutes_three_single_days_equal_three_days() -> void:
	var start := manager.last_total
	manager.update_to(start + DAY)
	manager.update_to(start + 2 * DAY)
	manager.update_to(start + 3 * DAY)
	var stepped := manager.progress("dirt_y03")
	var leaves := manager.progress("dirt_y02")
	manager.load_state({"last_total": start, "spots": {}})
	manager.update_to(start + 3 * DAY)
	assert_almost(manager.progress("dirt_y03"), stepped, 0.000001)
	assert_almost(manager.progress("dirt_y02"), leaves, 0.000001)
	assert_almost(stepped, DirtGrowth.rate("dirt_y03", &"weeds", cfg) * 3.0, 0.000001)
	assert_almost(leaves, DirtGrowth.rate("dirt_y02", &"leaves", cfg) * 3.0, 0.000001)


func test_growth_through_time_manager_skip() -> void:
	TimeManager.advance(3 * DAY)
	assert_eq(manager.last_total, TimeManager.total_minutes())
	assert_almost(manager.progress("dirt_y03"), DirtGrowth.rate("dirt_y03", &"weeds", cfg) * 3.0, 0.000001, "hourly steps")
	manager.update_to(TimeManager.total_minutes())
	assert_almost(manager.progress("dirt_y03"), DirtGrowth.rate("dirt_y03", &"weeds", cfg) * 3.0, 0.000001, "no double growth")
	manager.update_to(TimeManager.total_minutes() - 600)
	assert_eq(manager.last_total, TimeManager.total_minutes(), "time never runs back")


func test_locked_section_does_not_grow() -> void:
	assert_false(manager.is_growing("dirt_e01"))
	manager.update_to(manager.last_total + 5 * DAY)
	assert_eq(manager.progress("dirt_e01"), 0.0)
	expansion.open[&"east"] = true
	assert_true(manager.is_growing("dirt_e01"))
	manager.update_to(manager.last_total + DAY)
	assert_almost(manager.progress("dirt_e01"), DirtGrowth.rate("dirt_e01", &"weeds", cfg), 0.000001, "starts at 0 after unlocking")


func test_grave_spot_grows_only_when_filled_or_marked() -> void:
	for state: GraveRecord.State in [GraveRecord.State.EMPTY, GraveRecord.State.DUG, GraveRecord.State.LOCKED, GraveRecord.State.OLD]:
		graveyard.set_state("plot_01", state)
		assert_false(manager.is_growing("dirt_plot_01"), "state %d" % state)
	manager.update_to(manager.last_total + 2 * DAY)
	assert_eq(manager.progress("dirt_plot_01"), 0.0)
	graveyard.set_state("plot_01", GraveRecord.State.FILLED)
	assert_true(manager.is_growing("dirt_plot_01"))
	graveyard.set_state("plot_01", GraveRecord.State.MARKED)
	assert_true(manager.is_growing("dirt_plot_01"))
	manager.update_to(manager.last_total + DAY)
	assert_true(manager.progress("dirt_plot_01") > 0.0)
	graveyard.records.clear()
	assert_false(manager.is_growing("dirt_plot_01"), "unknown grave")


func test_gravel_and_flower_beds_suppress_growth() -> void:
	decorations.covered.append(Rect2(Vector2(7.5, -0.5), Vector2(1, 1)))
	assert_false(manager.is_growing("dirt_y03"))
	assert_true(manager.is_growing("dirt_y01"))
	manager.update_to(manager.last_total + 2 * DAY)
	assert_eq(manager.progress("dirt_y03"), 0.0)
	assert_true(manager.progress("dirt_y01") > 0.0)
	assert_false(manager.is_growing("no_such_spot"))


func test_level_changes_signal_once_per_skip() -> void:
	_put("dirt_y03", 0.95)
	dirt_events.clear()
	clean_events.clear()
	TimeManager.advance(DAY)
	assert_has(dirt_events, ["dirt_y03", 1])
	for e: Array in dirt_events:
		assert_true(e[0] != "dirt_e01", "locked spot never changes")
	assert_eq(clean_events.size(), 1, "bundled: one cleanliness_changed per time skip")
	assert_eq(clean_events[0], [manager.penalty(), manager.dirty_count()])
	dirt_events.clear()
	clean_events.clear()
	TimeManager.advance(60)
	assert_eq(dirt_events, [], "no level change → no dirt_changed")
	assert_eq(clean_events, [], "no level change → no cleanliness_changed")


# --- tending ------------------------------------------------------------------------------

func test_tend_minutes_by_hand_and_rake() -> void:
	_put("dirt_y01", 0.5)
	assert_eq(manager.tend_minutes("dirt_y01", inv), 0, "level 0")
	_put("dirt_y01", 1.2)
	assert_eq(manager.tend_minutes("dirt_y01", inv), 15)
	_put("dirt_y01", 2.2)
	assert_eq(manager.tend_minutes("dirt_y01", null), 15, "weeding needs no item")
	_put("dirt_y01", 3.5)
	assert_eq(manager.tend_minutes("dirt_y01", inv), 25)
	_put("dirt_y02", 2.0)
	assert_eq(manager.tend_minutes("dirt_y02", inv), 0, "leaves need the rake")
	assert_eq(manager.tend_minutes("dirt_y02", null), 0)
	inv.add_item(&"rake", 1)
	assert_eq(inv.count(&"rake"), 1)
	assert_eq(manager.tend_minutes("dirt_y02", inv), 10)
	assert_eq(manager.tend_minutes("nope", inv), 0)


func test_tend_resets_progress_and_signals() -> void:
	_put("dirt_y01", 2.4)
	_put("dirt_y02", 3.1)
	dirt_events.clear()
	clean_events.clear()
	assert_true(manager.tend("dirt_y01", inv))
	assert_eq(manager.progress("dirt_y01"), 0.0)
	assert_eq(manager.level("dirt_y01"), 0)
	assert_eq(dirt_events, [["dirt_y01", 0]])
	assert_eq(clean_events, [[2, 1]], "leaves level 3 remain")
	assert_false(manager.tend("dirt_y01", inv), "already clean")
	assert_false(manager.tend("dirt_y02", inv), "no rake")
	assert_eq(manager.level("dirt_y02"), 3)
	inv.add_item(&"rake", 1)
	assert_true(manager.tend("dirt_y02", inv))
	assert_eq(inv.count(&"rake"), 1, "the rake is a tool, not used up")
	assert_eq(manager.penalty(), 0)


func test_penalty_and_dirty_count() -> void:
	var data := manager.save_state()
	data.spots = {"dirt_y01": 0.5, "dirt_y02": 1.5, "dirt_y03": 2.5, "dirt_plot_01": 3.9}
	manager.load_state(data)
	assert_eq(manager.penalty(), 0 + 0 + 1 + 2)
	assert_eq(manager.dirty_count(), 2)
	assert_eq(manager.dirty_count(1), 3)
	assert_eq(manager.dirty_count(3), 1)
	var custom := cfg.duplicate() as CleanlinessConfig
	custom.penalty_by_level = PackedInt32Array([0, 1, 2, 3])
	manager.config = custom
	assert_eq(manager.penalty(), 0 + 1 + 2 + 3)


func test_penalty_capped_per_spot() -> void:
	var data := manager.save_state()
	for id: String in manager.spot_ids():
		data.spots[id] = 9.0
	manager.load_state(data)
	assert_eq(manager.penalty(), 2 * manager.spot_ids().size(), "at most 2 per spot")


# --- start state / save -------------------------------------------------------------------

func test_start_state_from_layout() -> void:
	clean_events.clear()
	EventBus.new_game_started.emit()
	assert_eq(manager.progress("dirt_y01"), 1.5)
	assert_eq(manager.progress("dirt_y02"), 2.2)
	assert_eq(manager.level("dirt_y02"), 2)
	assert_eq(manager.progress("dirt_y03"), 0.0)
	assert_eq(manager.progress("dirt_e01"), 0.0, "locked section starts at 0")
	assert_eq(manager.last_total, TimeManager.total_minutes())
	assert_eq(clean_events, [[1, 1]])


func test_empty_state_means_freshly_tended() -> void:
	manager.apply_start_state()
	TimeManager.advance(90)
	manager.load_state({})
	for id: String in manager.spot_ids():
		assert_eq(manager.progress(id), 0.0, id)
	assert_eq(manager.last_total, TimeManager.total_minutes(), "clock from now")
	assert_eq(manager.penalty(), 0)


func test_save_load_round_trip() -> void:
	manager.apply_start_state()
	TimeManager.advance(2 * DAY + 37)
	var saved := manager.save_state()
	assert_eq(saved.last_total, TimeManager.total_minutes())
	assert_eq(saved.spots.size(), 5)
	var json: Dictionary = JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(saved))))
	var progress := {}
	for id: String in manager.spot_ids():
		progress[id] = manager.progress(id)
	manager.load_state({})
	manager.load_state(json)
	for id: String in manager.spot_ids():
		assert_almost(manager.progress(id), progress[id], 0.000001, id)
	assert_eq(manager.last_total, saved.last_total)
	assert_eq(manager.save_state(), saved)


func test_load_ignores_unknown_and_bad_values() -> void:
	manager.load_state({"last_total": TimeManager.total_minutes() + 999, "spots": {"ghost_spot": 2.0, "dirt_y01": "x", "dirt_y03": 12.0}})
	assert_false(manager.spot_ids().has("ghost_spot"))
	assert_eq(manager.progress("dirt_y01"), 0.0)
	assert_almost(manager.progress("dirt_y03"), 3.999, 0.000001, "clamped")
	assert_eq(manager.last_total, TimeManager.total_minutes(), "a future last_total is clamped to now")


# --- DirtSpot -----------------------------------------------------------------------------

func test_dirt_spot_prompts() -> void:
	var weeds := world.get_node("dirt_y01") as DirtSpot
	var leaves := world.get_node("dirt_y02") as DirtSpot
	assert_eq(weeds.get_interaction_prompt(null), "", "level 0: not focusable")
	_put("dirt_y01", 3.2)
	_put("dirt_y02", 1.1)
	assert_eq(weeds.get_interaction_prompt(null), "[E] Unkraut jäten (25 Min)")
	assert_eq(leaves.get_interaction_prompt(null), DirtSpot.PROMPT_NEEDS_RAKE)
	assert_eq(DirtSpot.PROMPT_NEEDS_RAKE, "Rechen nötig – Werkbank")
	assert_false(weeds.can_interact(null))
	assert_eq(weeds.action_label(), "Unkraut jäten")
	assert_eq(leaves.action_label(), "Laub harken")


func test_dirt_spot_shows_levels() -> void:
	var weeds := world.get_node("dirt_y01") as DirtSpot
	_put("dirt_y01", 2.5)
	assert_eq(weeds.shown_level, 2)
	manager.tend("dirt_y01", inv)
	assert_eq(weeds.shown_level, 0)
	assert_eq(DirtSpot.model_path(&"weeds", 1), "res://assets/models/environment/ph_env_weeds_1.glb")
	assert_eq(DirtSpot.model_path(&"leaves", 3), "res://assets/models/environment/ph_env_leaves_3.glb")
	assert_eq(DirtSpot.model_path(&"moss", 1), "")


func test_real_config_matches_the_phase4_fixture() -> void:
	var real := Database.config(&"cleanliness_config") as CleanlinessConfig
	assert_not_null(real)
	# Phase 4 (§2.14 / §2.8): the data follows the Phase-4 fixture; the rule tests keep Phase 3's.
	var phase4 := Phase4Fixtures.cleanliness_config()
	for prop: Dictionary in CleanlinessConfig.new().get_property_list():
		if int(prop.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			assert_eq(real.get(prop.name), phase4.get(prop.name), String(prop.name))
	assert_true(Database.has_item(real.rake_item), "the rake exists")
	var recipe := Database.recipe(&"rake") as RecipeData
	assert_not_null(recipe)
	if recipe != null:
		assert_eq(recipe.inputs, {&"wood": 3})
		assert_eq(recipe.craft_minutes, 20)
		assert_eq(recipe.category, &"tool")
		assert_eq(recipe.station, &"workbench")
	var rake := Database.item(&"rake") as ItemData
	assert_eq(rake.category, ItemData.Category.TOOL)
	assert_eq(rake.max_stack, 1)


## Phase 4 §2.14 (a): an overgrown spot costs 3 instead of 2 ([0, 0, 1, 3], the real data).
func test_phase4_penalty_table() -> void:
	manager.config = Phase4Fixtures.cleanliness_config()
	assert_eq(manager.config.penalty_by_level, PackedInt32Array([0, 0, 1, 3]))
	var data := manager.save_state()
	data.spots = {"dirt_y01": 0.5, "dirt_y02": 1.5, "dirt_y03": 2.5, "dirt_plot_01": 3.9}
	manager.load_state(data)
	assert_eq(manager.penalty(), 0 + 0 + 1 + 3)
	manager.config = Database.config(&"cleanliness_config") as CleanlinessConfig
	assert_eq(manager.penalty(), 4, "data/config uses the Phase-4 table")

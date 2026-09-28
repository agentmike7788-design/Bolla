extends TestCase
## Phase 5 (P2, docs/PHASE5_DESIGN.md §2.2, §3.4, §10): GatherRules (charges, yield + tier-2 bonus,
## regrowth by regrow_days incl. multi-day jumps, alder stages stump / sapling / tree, tool /
## section / flag / room reasons, minutes by tier), GatherManager (register, gather, signals,
## trees_felled, refresh on day_started, save / load / post_load) and the GatherNode entity
## (registration in both tree orders, model per stage, elder bush without models, prompts,
## timed action). Uses the Phase-5 fixtures (gather kinds, sections, action config).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const FULL := GatherRules.STAGE_FULL
const PARTIAL := GatherRules.STAGE_PARTIAL
const EMPTY := GatherRules.STAGE_EMPTY
const REGROWING := GatherRules.STAGE_REGROWING


## Inventory without room for anything.
class FullInventory extends "res://tests/fixtures/fake_inventory.gd":
	func can_add(_id: StringName, _amount: int) -> bool:
		return false


var world: Node3D
var manager: GatherManager
var inv: Inventory
var events: Array = []


func before_each() -> void:
	world = Node3D.new()
	world.name = "World"
	manager = GatherManager.new()
	for data: GatherNodeData in Phase5Fixtures.gather_kinds():
		manager.kind_data[data.id] = data
	world.add_child(manager)
	tree.root.add_child(world)
	TimeManager.day = 5
	inv = FakeInventory.new()
	events.clear()
	EventBus.resource_gathered.connect(_on_gathered)
	EventBus.gather_node_changed.connect(_on_changed)


func after_each() -> void:
	EventBus.resource_gathered.disconnect(_on_gathered)
	EventBus.gather_node_changed.disconnect(_on_changed)
	inv.free()


# --- GatherRules -------------------------------------------------------------------------------

func test_full_state_and_tolerant_refresh() -> void:
	var clay := _kind(&"clay_pit")
	assert_eq(GatherRules.full_state(clay, 4), {"charges": 3, "last_taken_day": -1, "last_refresh_day": 4})
	assert_eq(GatherRules.refreshed({}, 7, clay), {"charges": 3, "last_taken_day": -1, "last_refresh_day": 7}, "{} = full")
	assert_eq(GatherRules.refreshed({"charges": 99, "last_taken_day": "x"}, 7, clay).charges, 3, "clamped")
	assert_eq(GatherRules.refreshed({"charges": 0.0, "last_taken_day": 7.0, "last_refresh_day": 7}, 7, clay).charges, 0, "JSON floats")
	assert_eq(GatherRules.refreshed({"charges": 0}, 7, clay).charges, 3, "taken day unknown: full again")
	assert_eq(GatherRules.refreshed({"charges": 1, "last_taken_day": 6, "last_refresh_day": 9}, 7, clay).last_refresh_day, 9,
			"last_refresh_day never goes back")
	assert_eq(GatherRules.stage({}, 1, clay), FULL)
	assert_eq(GatherRules.days_left({}, 1, clay), 0)


func test_daily_regrowth() -> void:
	var clay := _kind(&"clay_pit")
	var taken := {"charges": 1, "last_taken_day": 5, "last_refresh_day": 5}
	assert_eq(GatherRules.refreshed(taken, 5, clay).charges, 1, "same day: nothing grows")
	assert_eq(GatherRules.stage(taken, 5, clay), PARTIAL)
	assert_eq(GatherRules.days_left(taken, 5, clay), 1)
	var next := GatherRules.refreshed(taken, 6, clay)
	assert_eq(next, {"charges": 3, "last_taken_day": 5, "last_refresh_day": 6}, "regrow_days 1: full next morning")
	assert_eq(GatherRules.refreshed(next, 6, clay), next, "idempotent")
	assert_eq(GatherRules.stage(next, 6, clay), FULL)


func test_regrowth_after_several_days_and_jumps() -> void:
	var flax := _kind(&"flax_bed")
	var taken := {"charges": 0, "last_taken_day": 5, "last_refresh_day": 5}
	assert_eq(GatherRules.days_left(taken, 5, flax), 3)
	assert_eq(GatherRules.refreshed(taken, 6, flax).charges, 0)
	assert_eq(GatherRules.days_left(taken, 6, flax), 2)
	assert_eq(GatherRules.refreshed(taken, 7, flax).charges, 0)
	assert_eq(GatherRules.days_left(taken, 7, flax), 1)
	assert_eq(GatherRules.refreshed(taken, 8, flax).charges, 1, "regrow_days 3")
	assert_eq(GatherRules.refreshed(taken, 30, flax).charges, 1, "a long jump: full once, no overflow")
	var herbs := _kind(&"herb_patch")
	var half := {"charges": 1, "last_taken_day": 5, "last_refresh_day": 5}
	assert_eq(GatherRules.refreshed(half, 6, herbs).charges, 1, "a partial node waits the full regrow_days")
	assert_eq(GatherRules.refreshed(half, 7, herbs).charges, 2)


func test_alder_stages() -> void:
	var alder := _kind(&"alder")
	var felled := {"charges": 0, "last_taken_day": 10, "last_refresh_day": 10}
	var stages: Array = []
	for day: int in range(10, 16):
		var now := GatherRules.refreshed(felled, day, alder)
		stages.append(GatherRules.stage(now, day, alder))
	assert_eq(stages, [EMPTY, EMPTY, REGROWING, REGROWING, REGROWING, FULL], "stump 0–1, sapling 2–4, tree from day 5")
	assert_eq(GatherRules.stage(felled, 12, _kind(&"flax_bed")), EMPTY, "no regrowing stage without regrow_stage_days")


func test_yield_with_tier_two_bonus() -> void:
	var expected := {&"alder": [4, 4, 5], &"clay_pit": [2, 2, 3], &"rubble_face": [2, 2, 3], &"ore_vein": [1, 1, 1],
			&"workstone_ledge": [1, 1, 1], &"flax_bed": [3, 3, 3], &"elder_bush": [2, 2, 2], &"herb_patch": [1, 1, 1]}
	for id: StringName in expected:
		var got: Array = []
		for tier: int in 3:
			got.append(GatherRules.yield_for(_kind(id), tier))
		assert_eq(got, expected[id], String(id))
	assert_eq(GatherRules.yield_for(null, 2), 0)


func test_minutes_by_tier() -> void:
	var actions := Phase5Fixtures.action_config()
	var expected := {&"alder": [60, 50, 35], &"clay_pit": [30, 25, 20], &"rubble_face": [30, 25, 20], &"ore_vein": [40, 30, 25],
			&"workstone_ledge": [45, 35, 25], &"flax_bed": [20, 20, 20], &"elder_bush": [10, 10, 10], &"herb_patch": [10, 10, 10]}
	for id: StringName in expected:
		var got: Array = []
		for tier: int in 3:
			got.append(GatherRules.minutes_for(_kind(id), tier, actions))
		assert_eq(got, expected[id], String(id))


func test_block_reasons_in_order() -> void:
	var alder := _kind(&"alder")
	var full := GatherRules.full_state(alder, 5)
	var felled := {"charges": 0, "last_taken_day": 5, "last_refresh_day": 5}
	assert_eq(GatherRules.block_reason(full, alder, inv, 1, true, false), GatherRules.TEXT_NOT_OPEN, "flag first")
	assert_eq(GatherRules.block_reason(full, alder, inv, 1, false, true), GatherRules.TEXT_SECTION)
	assert_eq(GatherRules.block_reason(felled, alder, inv, 1, true, true), "Abgeerntet – in 5 Tagen wieder")
	var tool := GatherRules.block_reason(full, alder, inv, 0, true, true)
	assert_true(tool.contains("nötig"), "tool missing: %s" % tool)
	assert_eq(GatherRules.block_reason(full, alder, inv, 1, true, true), "")
	var clay := _kind(&"clay_pit")
	var used := {"charges": 0, "last_taken_day": 5, "last_refresh_day": 5}
	assert_eq(GatherRules.block_reason(used, clay, inv, 0, true, true), "Abgeerntet – morgen wieder")
	assert_eq(GatherRules.block_reason(GatherRules.full_state(clay, 5), clay, inv, 0, true, true), "", "shovel tier 0 is enough")
	var full_inv := FullInventory.new()
	assert_eq(GatherRules.block_reason(GatherRules.full_state(clay, 5), clay, full_inv, 0, true, true), GatherRules.TEXT_NO_ROOM)
	full_inv.free()
	assert_eq(GatherRules.block_reason(full, null, inv, 2, true, true), GatherRules.TEXT_NOT_OPEN)
	var ledge := _kind(&"workstone_ledge")
	assert_ne(GatherRules.block_reason(GatherRules.full_state(ledge, 5), ledge, inv, 1, true, true), "", "workstone: pickaxe 2")


# --- GatherManager -----------------------------------------------------------------------------

func test_group_and_save_contract() -> void:
	assert_true(manager.is_in_group(&"gathering"))
	assert_true(manager.is_in_group(&"saveable"))
	assert_eq([manager.save_id, manager.save_order], ["gathering", 25])


func test_register_starts_full() -> void:
	manager.register("gather_clay", _kind(&"clay_pit"))
	assert_true(manager.is_registered("gather_clay"))
	assert_eq(manager.state_of("gather_clay"), {"charges": 3, "last_taken_day": -1, "last_refresh_day": 5})
	assert_eq([manager.charges("gather_clay"), manager.stage("gather_clay")], [3, FULL])
	assert_eq([manager.state_of("nope"), manager.charges("nope")], [{}, 0])
	manager.register("", _kind(&"clay_pit"))
	manager.register("gather_x", null)
	assert_false(manager.is_registered("gather_x"))


func test_gather_takes_a_charge_and_emits() -> void:
	manager.register("gather_clay", _kind(&"clay_pit"))
	assert_eq(manager.gather("gather_clay", inv, 0), 2)
	assert_eq(inv.count(&"clay"), 2)
	assert_eq(manager.state_of("gather_clay"), {"charges": 2, "last_taken_day": 5, "last_refresh_day": 5})
	assert_eq(events, [["gathered", "gather_clay", &"clay", 2], ["changed", "gather_clay", 2, PARTIAL]])
	assert_eq(manager.gather("gather_clay", inv, 2), 3, "shovel 2: +1")
	assert_eq(manager.gather("gather_clay", inv, 0), 2)
	assert_eq(manager.stage("gather_clay"), EMPTY)
	events.clear()
	assert_eq(manager.gather("gather_clay", inv, 2), 0, "empty → refused")
	assert_eq(events, [])
	assert_eq(inv.count(&"clay"), 7)
	assert_eq(manager.block_reason("gather_clay", inv, 0), "Abgeerntet – morgen wieder")


func test_gather_is_refused_without_tool_room_or_registration() -> void:
	manager.register("gather_ore", _kind(&"ore_vein"))
	assert_eq(manager.gather("gather_ore", inv, 0), 0, "pickaxe 1 needed")
	var full_inv := FullInventory.new()
	assert_eq(manager.gather("gather_ore", full_inv, 1), 0, "no room")
	full_inv.free()
	assert_eq(manager.gather("gather_nope", inv, 2), 0)
	assert_eq(manager.gather("gather_ore", null, 2), 0)
	assert_eq(manager.charges("gather_ore"), 3, "nothing taken")
	assert_eq(events, [])
	assert_eq(manager.gather("gather_ore", inv, 1), 1)


func test_felling_an_alder_counts_and_regrows_in_stages() -> void:
	manager.register("gather_alder_1", _kind(&"alder"))
	manager.register("gather_flax_1", _kind(&"flax_bed"))
	assert_eq(manager.gather("gather_alder_1", inv, 0), 0, "axe 1 needed")
	assert_eq(manager.gather("gather_alder_1", inv, 2), 5, "axe 2: +1 wood")
	assert_eq(GameState.get_stat(&"trees_felled"), 1)
	manager.gather("gather_flax_1", inv, 0)
	assert_eq(GameState.get_stat(&"trees_felled"), 1, "only alders count")
	assert_eq(manager.stage("gather_alder_1"), EMPTY, "stump")
	var stages: Array = []
	for day: int in range(6, 11):
		TimeManager.day = day
		EventBus.day_started.emit(day)
		stages.append(manager.stage("gather_alder_1"))
	assert_eq(stages, [EMPTY, REGROWING, REGROWING, REGROWING, FULL])
	assert_eq(manager.days_left("gather_alder_1"), 0)
	assert_has(events, ["changed", "gather_alder_1", 0, REGROWING], "stump → sapling is announced")
	assert_has(events, ["changed", "gather_alder_1", 1, FULL])


func test_refresh_on_day_started_is_idempotent() -> void:
	manager.register("gather_herbs_1", _kind(&"herb_patch"))
	manager.gather("gather_herbs_1", inv, 0)
	manager.gather("gather_herbs_1", inv, 0)
	events.clear()
	TimeManager.day = 6
	EventBus.day_started.emit(6)
	assert_eq(events, [], "regrow_days 2: nothing yet")
	TimeManager.day = 7
	EventBus.day_started.emit(7)
	assert_eq(events, [["changed", "gather_herbs_1", 2, FULL]])
	events.clear()
	manager.refresh(7)
	assert_eq(events, [], "a second refresh changes nothing")
	assert_eq(manager.state_of("gather_herbs_1"), {"charges": 2, "last_taken_day": 5, "last_refresh_day": 7})


func test_save_load_round_trip() -> void:
	manager.register("gather_alder_1", _kind(&"alder"))
	manager.register("gather_clay", _kind(&"clay_pit"))
	manager.gather("gather_alder_1", inv, 1)
	manager.gather("gather_clay", inv, 0)
	var saved := manager.save_state()
	assert_eq(saved, {"gather_alder_1": {"charges": 0, "last_taken_day": 5, "last_refresh_day": 5},
			"gather_clay": {"charges": 2, "last_taken_day": 5, "last_refresh_day": 5}})
	var plain: Dictionary = JSON.parse_string(JSON.stringify(saved))
	manager.load_state({})
	assert_eq([manager.charges("gather_alder_1"), manager.charges("gather_clay")], [1, 3], "{} = all full")
	manager.load_state(plain)
	manager.post_load()
	assert_eq(manager.save_state(), saved, "plain JSON floats accepted, identical")
	assert_eq(manager.stage("gather_alder_1"), EMPTY)


func test_load_is_tolerant_and_keeps_unknown_nodes() -> void:
	manager.register("gather_clay", _kind(&"clay_pit"))
	manager.load_state({"gather_clay": {"charges": 9, "last_taken_day": 5}, "gather_later": {"charges": 0, "last_taken_day": 4,
			"last_refresh_day": 4}, "broken": 3})
	assert_eq(manager.charges("gather_clay"), 3, "clamped")
	assert_true(manager.save_state().has("gather_later"), "state of a node the world has not built yet is kept")
	assert_false(manager.save_state().has("broken"))
	manager.load_state({"gather_clay": {"charges": "x"}})
	assert_eq(manager.charges("gather_clay"), 3, "broken value → full")


func test_post_load_regrows_for_today() -> void:
	manager.register("gather_flax_1", _kind(&"flax_bed"))
	manager.load_state({"gather_flax_1": {"charges": 0, "last_taken_day": 2, "last_refresh_day": 4}})
	assert_eq(manager.charges("gather_flax_1"), 0, "loaded as saved")
	events.clear()
	manager.post_load()
	assert_eq(manager.charges("gather_flax_1"), 1, "day 5 − 2 ≥ 3")
	assert_eq(events, [["changed", "gather_flax_1", 1, FULL]], "every node shows its stage after a load")


func test_collect_state_round_trip_via_save_manager() -> void:
	manager.register("gather_ore", _kind(&"ore_vein"))
	manager.gather("gather_ore", inv, 1)
	var a := SaveManager.collect_state()
	assert_true(a.nodes.has("gathering"))
	SaveManager.apply_state(JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(a)))))
	assert_eq(SaveManager.collect_state(), a)
	assert_eq(manager.charges("gather_ore"), 2)


# --- GatherNode --------------------------------------------------------------------------------

func test_node_registers_itself_and_shows_its_stage() -> void:
	var node := _node("gather_alder_1", &"alder", true)
	assert_true(manager.is_registered("gather_alder_1"))
	assert_true(node.is_in_group(&"gather_node"))
	assert_eq(_visible(node), [true, false, false], "tree")
	manager.gather("gather_alder_1", inv, 1)
	assert_eq(_visible(node), [false, true, false], "stump")
	TimeManager.day = 7
	EventBus.day_started.emit(7)
	assert_eq(_visible(node), [false, false, true], "sapling")
	TimeManager.day = 10
	EventBus.day_started.emit(10)
	assert_eq(_visible(node), [true, false, false], "tree again")


func test_manager_collects_nodes_added_before_it() -> void:
	manager.free()
	var node := _node("gather_clay", &"clay_pit", true)
	var late := GatherManager.new()
	for data: GatherNodeData in Phase5Fixtures.gather_kinds():
		late.kind_data[data.id] = data
	world.add_child(late)
	assert_true(late.is_registered("gather_clay"))
	assert_eq(node.shown_stage, FULL)
	manager = late


func test_partial_node_keeps_its_full_model() -> void:
	var node := _node("gather_clay", &"clay_pit", true)
	manager.gather("gather_clay", inv, 0)
	assert_eq(node.shown_stage, PARTIAL)
	assert_eq(_visible(node), [true, false, false])


func test_elder_bush_node_changes_no_model() -> void:
	var bush := Node3D.new()
	bush.name = "ElderBush"
	var leaves := Node3D.new()
	bush.add_child(leaves)
	world.add_child(bush)
	var node := GatherNode.new()
	node.node_id = "gather_elder_1"
	node.kind = &"elder_bush"
	bush.add_child(node)
	manager.gather("gather_elder_1", inv, 0)
	assert_eq(node.shown_stage, EMPTY)
	assert_true(bush.visible and leaves.visible, "the bush stays as it is")
	assert_eq(node.get_child_count(), 0, "no model of its own")
	assert_eq(inv.count(&"elderberries"), 2)


func test_node_prompts() -> void:
	var node := _node("gather_clay", &"clay_pit", false)
	var player := await _player()
	assert_eq(node.get_interaction_prompt(player), "", "before workshop_open: no prompt")
	assert_false(node.can_interact(player))
	GameState.set_flag(&"workshop_open")
	assert_eq(node.get_interaction_prompt(player), "[E] Lehm stechen (30 Min) → +2 Lehm")
	assert_true(node.can_interact(player))
	for i: int in 3:
		manager.gather("gather_clay", player.inventory, 0)
	assert_eq(node.get_interaction_prompt(player), "Abgeerntet – morgen wieder")
	assert_false(node.can_interact(player))
	var alder := _node("gather_alder_2", &"alder", false)
	assert_true(alder.get_interaction_prompt(player).contains("nötig"), "axe 1 missing")


func test_section_gate_uses_the_section_text() -> void:
	var expansion := ExpansionManager.new()
	var sections: Array[SectionData] = [Phase5Fixtures.section(&"bruch"), Phase5Fixtures.section(&"quarry")]
	expansion.section_data = sections
	world.add_child(expansion)
	GameState.set_flag(&"workshop_open")
	var ore := _node("gather_ore", &"ore_vein", false)
	ore.section_id = &"quarry"
	var flax := _node("gather_flax_1", &"flax_bed", false)
	flax.section_id = &"bruch"
	assert_eq(ore.get_interaction_prompt(null), "Findlinge versperren den Weg.")
	assert_eq(flax.get_interaction_prompt(null), "Die Pforte ist zu. Osric weiß, wer den Schlüssel hat.")
	assert_false(flax.section_open())
	GameState.set_flag(&"bruch_license")
	expansion.unlock(&"bruch")
	assert_true(flax.section_open())
	assert_eq(ore.get_interaction_prompt(null), "Findlinge versperren den Weg.", "quarry still closed")
	expansion.unlock(&"quarry")
	assert_true(ore.get_interaction_prompt(null).contains("nötig"), "open – now the pickaxe is missing")


func test_interact_runs_a_timed_action() -> void:
	var node := _node("gather_flax_1", &"flax_bed", false)
	var player := await _player()
	GameState.set_flag(&"workshop_open")
	var start := TimeManager.minute_of_day
	node.interact(player)
	assert_eq(player.inventory.count(&"flax"), 3)
	assert_eq(TimeManager.minute_of_day, start + 20)
	assert_eq(manager.stage("gather_flax_1"), EMPTY)
	node.interact(player)
	assert_eq(player.inventory.count(&"flax"), 3, "empty: nothing started")


func test_real_gather_data_matches_the_contract() -> void:
	assert_eq(Database.gather_kinds().size(), 8)
	for fixture: GatherNodeData in Phase5Fixtures.gather_kinds():
		var real := Database.gather_kind(fixture.id) as GatherNodeData
		assert_not_null(real, String(fixture.id))
		if real == null:
			continue
		assert_eq([real.item_id, real.yield_amount, real.charges_max, real.regrow_days, real.minutes, real.tool_kind, real.min_tier,
				real.tier2_bonus, real.requires_flag], [fixture.item_id, fixture.yield_amount, fixture.charges_max, fixture.regrow_days,
				fixture.minutes, fixture.tool_kind, fixture.min_tier, fixture.tier2_bonus, fixture.requires_flag], String(fixture.id))
		assert_true(Database.has_item(real.item_id), "%s yields a known item" % fixture.id)
	assert_eq(Array((Database.gather_kind(&"alder") as GatherNodeData).regrow_stage_days), [2, 5])


func test_real_material_items() -> void:
	for id: StringName in Phase5Fixtures.MATERIAL_IDS:
		var real := Database.item(id) as ItemData
		var fixture := Phase5Fixtures.item(id)
		assert_not_null(real, String(id))
		if real == null:
			continue
		assert_eq([real.category, real.display_name, real.max_stack], [ItemData.Category.MATERIAL, fixture.display_name,
				fixture.max_stack], String(id))
		assert_true(real.description.length() >= 20, "%s has a description" % id)


# --- helpers -----------------------------------------------------------------------------------

func _kind(id: StringName) -> GatherNodeData:
	return Phase5Fixtures.gather_kind(id)


## A GatherNode in the world (with Full / Empty / Regrow children when `models`).
func _node(id: String, kind: StringName, models: bool) -> GatherNode:
	var node := GatherNode.new()
	node.node_id = id
	node.kind = kind
	node.name = id
	if models:
		for model_name: String in [GatherNode.FULL_NAME, GatherNode.EMPTY_NAME, GatherNode.REGROW_NAME]:
			var model := Node3D.new()
			model.name = model_name
			node.add_child(model)
	world.add_child(node)
	return node


func _visible(node: GatherNode) -> Array:
	var out: Array = []
	for model_name: String in [GatherNode.FULL_NAME, GatherNode.EMPTY_NAME, GatherNode.REGROW_NAME]:
		out.append((node.get_node(model_name) as Node3D).visible)
	return out


func _player() -> Player:
	var p := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old := p.get_node("Inventory")
	p.remove_child(old)
	old.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	p.add_child(fake)
	p.actions = Phase5Fixtures.action_config()
	p.instant_actions = true
	p.set_physics_process(false)
	tree.root.add_child(p)
	await tree.physics_frame
	return p


func _on_gathered(id: String, item: StringName, amount: int) -> void:
	events.append(["gathered", id, item, amount])


func _on_changed(id: String, charges: int, stage: StringName) -> void:
	events.append(["changed", id, charges, stage])

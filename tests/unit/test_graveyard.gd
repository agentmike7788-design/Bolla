extends TestCase
## M3: Graveyard – plot collection, state machine EMPTY -> DUG -> FILLED -> MARKED (OLD fixed),
## signal order, payment, cemetery quality, slice completion, save/load; GraveRecord dicts.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const EMPTY := GraveRecord.State.EMPTY
const DUG := GraveRecord.State.DUG
const FILLED := GraveRecord.State.FILLED
const MARKED := GraveRecord.State.MARKED
const OLD := GraveRecord.State.OLD


## Grave place (group "grave_plot") with the two properties the Graveyard reads.
class PlotDouble extends Node3D:
	var grave_id: String = ""
	var is_old: bool = false


var tables: CorpseTables
var economy: EconomyConfig
var world: Node3D
var graveyard: Graveyard
var corpses: CorpseManager
var inv: Inventory
var events: Array = []


func before_each() -> void:
	tables = load(FIXTURE_TABLES) as CorpseTables
	economy = load(FIXTURE_ECONOMY) as EconomyConfig
	world = Node3D.new()
	world.name = "World"
	var container := Node3D.new()
	container.name = "Corpses"
	world.add_child(container)
	corpses = CorpseManager.new()
	corpses.tables = tables
	corpses.economy = economy
	corpses.container_path = ^"../Corpses"
	world.add_child(corpses)
	graveyard = _new_graveyard()
	world.add_child(graveyard)
	for id: String in ["plot_01", "plot_02", "old_01", "plot_03"]:
		world.add_child(_plot(id, id.begins_with("old")))
	tree.root.add_child(world)
	inv = FakeInventory.new()
	events.clear()
	EventBus.grave_state_changed.connect(_on_state)
	EventBus.grave_completed.connect(_on_completed)
	EventBus.payment_received.connect(_on_payment)
	EventBus.cemetery_quality_changed.connect(_on_quality)
	EventBus.corpse_buried.connect(_on_buried)
	EventBus.corpse_updated.connect(_on_corpse_updated)
	EventBus.slice_completed.connect(_on_slice)
	EventBus.ui_panel_requested.connect(_on_panel)


func after_each() -> void:
	EventBus.grave_state_changed.disconnect(_on_state)
	EventBus.grave_completed.disconnect(_on_completed)
	EventBus.payment_received.disconnect(_on_payment)
	EventBus.cemetery_quality_changed.disconnect(_on_quality)
	EventBus.corpse_buried.disconnect(_on_buried)
	EventBus.corpse_updated.disconnect(_on_corpse_updated)
	EventBus.slice_completed.disconnect(_on_slice)
	EventBus.ui_panel_requested.disconnect(_on_panel)
	inv.free()


# --- setup ---

func test_groups_and_save_contract() -> void:
	assert_true(graveyard.is_in_group(&"graveyard"))
	assert_true(graveyard.is_in_group(&"saveable"))
	assert_eq(graveyard.save_id, "graveyard")
	assert_eq(graveyard.save_order, 10)


func test_collects_plots_on_ready() -> void:
	var ids: Array = []
	var states: Array = []
	for g: GraveRecord in graveyard.graves():
		ids.append(g.id)
		states.append(g.state)
	assert_eq(ids, ["plot_01", "plot_02", "old_01", "plot_03"], "tree order")
	assert_eq(states, [EMPTY, EMPTY, OLD, EMPTY])
	assert_eq(graveyard.free_plot_count(), 3)
	assert_eq(graveyard.get_grave("old_01").state, OLD)
	assert_null(graveyard.get_grave("plot_99"))
	assert_eq(graveyard.total_quality(), 0)
	assert_eq(graveyard.rating(), &"neglected")
	assert_eq(events, [], "_ready is silent")


func test_plots_without_id_or_duplicates_are_skipped() -> void:
	_leave_plot_group()
	var other := Node3D.new()
	for id: String in ["plot_01", "", "plot_01", "plot_02"]:
		other.add_child(_plot(id, false))
	var second := _new_graveyard()
	other.add_child(second)
	tree.root.add_child(other)
	var ids: Array = []
	for g: GraveRecord in second.graves():
		ids.append(g.id)
	assert_eq(ids, ["plot_01", "plot_02"], "empty id and duplicate plot_01 ignored")


# --- state machine ---

func test_dig() -> void:
	assert_true(graveyard.dig("plot_01"))
	assert_eq(graveyard.get_grave("plot_01").state, DUG)
	assert_eq(events, [["state", "plot_01", DUG]])
	assert_eq(graveyard.free_plot_count(), 3, "DUG still counts as free")
	events.clear()
	assert_false(graveyard.dig("plot_01"), "already dug")
	assert_false(graveyard.dig("old_01"), "old graves stay")
	assert_false(graveyard.dig("plot_99"), "unknown")
	assert_eq(events, [])


func test_bury() -> void:
	var r := _corpse()
	assert_false(graveyard.bury("plot_01", r.id), "EMPTY cannot be filled")
	graveyard.dig("plot_01")
	events.clear()
	assert_true(graveyard.bury("plot_01", r.id))
	var g := graveyard.get_grave("plot_01")
	assert_eq(g.state, FILLED)
	assert_eq(g.corpse_id, r.id)
	assert_eq(r.location, &"buried")
	assert_eq(r.grave_id, "plot_01")
	assert_null(corpses.get_corpse_node(r.id))
	assert_eq(GameState.get_stat(&"burials"), 1)
	assert_eq(graveyard.free_plot_count(), 2)
	assert_eq(events, [["corpse_updated", r.id], ["state", "plot_01", FILLED], ["buried", r.id, "plot_01"]])


func test_bury_refusals() -> void:
	var r := _corpse()
	graveyard.dig("plot_01")
	graveyard.dig("plot_02")
	assert_false(graveyard.bury("plot_01", "corpse_9999"), "unknown corpse")
	assert_true(graveyard.bury("plot_01", r.id))
	assert_false(graveyard.bury("plot_02", r.id), "corpse already buried")
	assert_false(graveyard.bury("plot_01", _corpse().id), "grave already filled")
	assert_false(graveyard.bury("old_01", r.id), "old grave")
	assert_false(graveyard.bury("plot_99", r.id), "unknown grave")
	assert_eq(GameState.get_stat(&"burials"), 1)
	assert_eq(graveyard.get_grave("plot_02").state, DUG)


func test_bury_without_corpse_manager() -> void:
	corpses.remove_from_group(&"corpse_manager")
	graveyard.dig("plot_01")
	assert_false(graveyard.bury("plot_01", "corpse_0001"))
	assert_eq(graveyard.get_grave("plot_01").state, DUG)


func test_place_marker_signal_order_and_payment() -> void:
	var r := _corpse(true, true)
	_fill("plot_01", r)
	inv.add_item(&"wooden_cross", 1)
	events.clear()
	var paid := graveyard.place_marker("plot_01", &"wooden_cross", inv)
	var quality := 2 + 2 + 1 + 1 + 1
	var expected_pay := 3 + floori(quality * 0.5)
	assert_eq(paid, expected_pay)
	assert_eq(quality, GraveQuality.compute(r, &"wooden_cross", economy))
	assert_eq(inv.count(&"wooden_cross"), 0, "marker consumed")
	assert_eq(inv.count(&"coin"), expected_pay)
	var g := graveyard.get_grave("plot_01")
	assert_eq(g.state, MARKED)
	assert_eq(g.marker_id, &"wooden_cross")
	assert_eq(g.quality, quality)
	var lines := GraveQuality.breakdown(r, &"wooden_cross", economy)
	assert_eq(g.breakdown, lines)
	assert_eq(events, [
		["state", "plot_01", MARKED],
		["completed", "plot_01", r.id, quality, lines],
		["payment", expected_pay, "Bestattung von Anna Moor"],
		["quality", quality, &"neglected"],
	])


func test_place_marker_gravestone_example() -> void:
	var r := _corpse(true, true)
	_fill("plot_02", r)
	inv.add_item(&"gravestone_simple", 1)
	inv.add_item(&"wooden_cross", 1)
	assert_eq(graveyard.place_marker("plot_02", &"gravestone_simple", inv), 7, "quality 9 -> 3 + 4")
	assert_eq(graveyard.get_grave("plot_02").quality, 9)
	assert_eq(inv.count(&"wooden_cross"), 1, "only the chosen marker is used")


func test_place_marker_refusals() -> void:
	inv.add_item(&"wooden_cross", 5)
	assert_eq(graveyard.place_marker("plot_01", &"wooden_cross", inv), 0, "EMPTY")
	graveyard.dig("plot_01")
	assert_eq(graveyard.place_marker("plot_01", &"wooden_cross", inv), 0, "DUG")
	assert_eq(graveyard.place_marker("old_01", &"wooden_cross", inv), 0, "OLD")
	assert_eq(graveyard.place_marker("plot_99", &"wooden_cross", inv), 0, "unknown")
	var r := _corpse()
	graveyard.bury("plot_01", r.id)
	assert_eq(graveyard.place_marker("plot_01", &"shroud", inv), 0, "not a marker")
	assert_eq(graveyard.place_marker("plot_01", &"gravestone_simple", inv), 0, "marker not in inventory")
	assert_eq(graveyard.place_marker("plot_01", &"wooden_cross", null), 0, "no inventory")
	assert_eq(graveyard.get_grave("plot_01").state, FILLED)
	assert_eq(inv.count(&"wooden_cross"), 5, "nothing consumed")
	assert_eq(inv.count(&"coin"), 0)
	assert_true(graveyard.place_marker("plot_01", &"wooden_cross", inv) > 0)
	assert_eq(graveyard.place_marker("plot_01", &"wooden_cross", inv), 0, "MARKED is final")
	assert_eq(inv.count(&"wooden_cross"), 4)


func test_marked_grave_is_final() -> void:
	var r := _corpse()
	_complete("plot_01", r)
	assert_false(graveyard.dig("plot_01"))
	assert_false(graveyard.bury("plot_01", _corpse().id))
	assert_eq(graveyard.get_grave("plot_01").state, MARKED)


func test_place_marker_without_corpse_record() -> void:
	var r := _corpse()
	_fill("plot_01", r)
	corpses.load_state({})
	inv.add_item(&"wooden_cross", 1)
	assert_eq(graveyard.place_marker("plot_01", &"wooden_cross", inv), 0)
	assert_eq(inv.count(&"wooden_cross"), 1)
	assert_eq(graveyard.get_grave("plot_01").state, FILLED)


func test_quality_uses_freshness_at_burial() -> void:
	var r := _corpse()
	_fill("plot_01", r)
	assert_almost(r.freshness_at_burial, 1.0)
	r.freshness = 0.1
	inv.add_item(&"wooden_cross", 1)
	graveyard.place_marker("plot_01", &"wooden_cross", inv)
	assert_eq(graveyard.get_grave("plot_01").quality, 2 + 1 + 1, "fresh at burial counts, not the current value")


func test_decayed_corpse_lowers_quality() -> void:
	var r := _corpse()
	EventBus.time_skipped.emit(390, 390 + 60 * 16)  # fever: 1 - 0.05 * 16 = 0.2
	_fill("plot_01", r)
	inv.add_item(&"wooden_cross", 1)
	graveyard.place_marker("plot_01", &"wooden_cross", inv)
	assert_eq(graveyard.get_grave("plot_01").quality, 2 + 1 - 1)
	assert_has(graveyard.get_grave("plot_01").breakdown, {"label": "Verwesend", "points": -1})


# --- totals ---

func test_total_quality_and_rating() -> void:
	_complete("plot_01", _corpse(true, true), &"gravestone_simple")  # 9
	_complete("plot_02", _corpse(true, true), &"wooden_cross")  # 7
	assert_eq(graveyard.total_quality(), 16)
	assert_eq(graveyard.rating(), &"orderly")
	assert_eq(events.back(), ["quality", 16, &"orderly"])


func test_old_graves_count_old_grave_quality() -> void:
	var custom := economy.duplicate() as EconomyConfig
	custom.old_grave_quality = 6
	graveyard.economy = custom
	assert_eq(graveyard.total_quality(), 6)
	_complete("plot_01", _corpse(true, true), &"gravestone_simple")
	assert_eq(graveyard.total_quality(), 15)
	assert_eq(graveyard.rating(), &"orderly")


func test_filled_and_dug_graves_count_nothing() -> void:
	graveyard.dig("plot_01")
	_fill("plot_02", _corpse(true, true))
	assert_eq(graveyard.total_quality(), 0)


# --- slice completion ---

func test_slice_complete_after_every_new_grave_is_marked() -> void:
	_complete("plot_01", _corpse(true, true))
	_complete("plot_02", _corpse(true, true))
	assert_false(GameState.has_flag(&"slice_complete"))
	assert_false(_has_event("slice_completed"))
	events.clear()
	_complete("plot_03", _corpse(true, true), &"gravestone_simple")
	assert_eq(GameState.get_flag(&"slice_complete"), true)
	var total := 7 + 7 + 9
	var tail := events.slice(events.size() - 3)
	assert_eq(tail, [
		["quality", total, &"orderly"],
		["slice_completed"],
		["panel", &"slice_summary", {"days": 1, "burials": 3, "total": total, "rating": &"orderly", "reputation": 0}],
	])


func test_slice_summary_context_values() -> void:
	TimeManager.load_state({"day": 4, "minute_of_day": 600})
	GameState.add_stat(&"reputation", -2)
	for id: String in ["plot_01", "plot_02", "plot_03"]:
		_complete(id, _corpse())
	var panel: Array = events.filter(func(e: Array) -> bool: return e[0] == "panel")
	assert_eq(panel.size(), 1)
	var context: Dictionary = panel[0][2]
	assert_eq(context.days, 4)
	assert_eq(context.burials, 3)
	assert_eq(context.total, graveyard.total_quality())
	assert_eq(context.rating, graveyard.rating())
	assert_eq(context.reputation, -2)


func test_slice_complete_only_once() -> void:
	GameState.set_flag(&"slice_complete", true)
	for id: String in ["plot_01", "plot_02", "plot_03"]:
		_complete(id, _corpse())
	assert_false(_has_event("slice_completed"))
	assert_false(_has_event("panel"))


func test_no_slice_complete_without_new_graves() -> void:
	_leave_plot_group()
	var other := Node3D.new()
	other.add_child(_plot("old_09", true))
	var lonely := _new_graveyard()
	other.add_child(lonely)
	tree.root.add_child(other)
	assert_eq(lonely.graves().size(), 1)
	lonely._check_slice_complete()
	assert_false(GameState.has_flag(&"slice_complete"))


# --- broadcast ---

func test_broadcast_state() -> void:
	graveyard.dig("plot_02")
	events.clear()
	graveyard.broadcast_state()
	assert_eq(events, [
		["state", "plot_01", EMPTY],
		["state", "plot_02", DUG],
		["state", "old_01", OLD],
		["state", "plot_03", EMPTY],
		["quality", 0, &"neglected"],
	])


func test_world_ready_broadcasts_for_own_world_only() -> void:
	var foreign := Node.new()
	EventBus.world_ready.emit(foreign)
	foreign.free()
	assert_eq(events, [], "foreign world")
	EventBus.world_ready.emit(world)
	assert_eq(events.size(), 5)


# --- save / load ---

func test_save_load_round_trip() -> void:
	_build_mixed_state()
	var before := graveyard.save_state()
	graveyard.load_state(_json_round_trip(before))
	assert_eq(graveyard.save_state(), before)
	var g := graveyard.get_grave("plot_01")
	assert_eq(g.state, MARKED)
	assert_true(g.marker_id is StringName)
	assert_eq(typeof(g.quality), TYPE_INT)
	assert_eq(graveyard.total_quality(), 7)


func test_collect_state_round_trip_of_both_managers() -> void:
	_build_mixed_state()
	var a := SaveManager.collect_state()
	assert_true(a.nodes.has("graveyard") and a.nodes.has("corpse_manager"))
	SaveManager.apply_state(_json_round_trip(a))
	assert_eq(SaveManager.collect_state(), a)
	assert_eq(graveyard.get_grave("plot_02").state, FILLED)
	assert_eq(corpses.get_record(graveyard.get_grave("plot_02").corpse_id).location, &"buried")


func test_load_state_replaces_everything() -> void:
	_build_mixed_state()
	graveyard.load_state({})
	var states: Array = []
	for g: GraveRecord in graveyard.graves():
		states.append(g.state)
	assert_eq(states, [EMPTY, EMPTY, OLD, EMPTY], "defaults from the plots")
	assert_eq(graveyard.get_grave("plot_01").quality, 0)
	assert_eq(events.filter(func(e: Array) -> bool: return e[0] == "state").size(), 6, "loading is silent")


func test_load_state_is_idempotent_and_tolerant() -> void:
	_build_mixed_state()
	var saved := graveyard.save_state()
	var list: Array = (saved.graves as Array).duplicate()
	list.append("junk")
	list.append({"state": 2})
	list.append({"id": "plot_77", "state": 1})
	graveyard.load_state({"graves": list})
	graveyard.load_state({"graves": list})
	assert_eq(graveyard.graves().size(), 5, "unknown saved grave kept, bad entries skipped")
	assert_eq(graveyard.get_grave("plot_77").state, DUG)
	graveyard.load_state({"graves": "nonsense"})
	assert_eq(graveyard.graves().size(), 4)


func test_grave_record_dict_round_trip() -> void:
	var g := GraveRecord.new()
	g.id = "plot_05"
	g.state = MARKED
	g.corpse_id = "corpse_0003"
	g.marker_id = &"gravestone_simple"
	g.quality = 8
	g.breakdown = [{"label": "Bestattet", "points": 2}, {"label": "Wertsachen genommen", "points": -2}]
	var d := g.to_dict()
	assert_eq(d, {"id": "plot_05", "state": 3, "corpse_id": "corpse_0003", "marker_id": &"gravestone_simple", "quality": 8,
			"breakdown": [{"label": "Bestattet", "points": 2}, {"label": "Wertsachen genommen", "points": -2}]})
	assert_eq(GraveRecord.from_dict(d).to_dict(), d)
	var plain: Dictionary = JSON.parse_string(JSON.stringify(d))
	var back := GraveRecord.from_dict(plain)
	assert_eq(back.to_dict(), d)
	assert_eq(back.state, MARKED)
	assert_true(back.marker_id is StringName)
	assert_eq(typeof(back.quality), TYPE_INT)
	assert_eq(typeof(back.breakdown[1].points), TYPE_INT)
	(d.breakdown as Array).clear()
	assert_eq(g.breakdown.size(), 2, "to_dict copies the breakdown")


func test_grave_record_from_dict_state_values() -> void:
	assert_eq(GraveRecord.from_dict({"state": "FILLED"}).state, FILLED)
	assert_eq(GraveRecord.from_dict({"state": "4"}).state, OLD)
	assert_eq(GraveRecord.from_dict({"state": 9}).state, EMPTY, "out of range")
	assert_eq(GraveRecord.from_dict({"state": "sunken"}).state, EMPTY)
	assert_eq(GraveRecord.from_dict({}).to_dict(), GraveRecord.new().to_dict())


# --- helpers ---

## plot_01 MARKED (cross, quality 7), plot_02 FILLED, plot_03 DUG, old_01 OLD.
func _build_mixed_state() -> void:
	_complete("plot_01", _corpse(true, true))
	_fill("plot_02", _corpse())
	graveyard.dig("plot_03")
	_corpse()


func _complete(grave_id: String, corpse: CorpseRecord, marker: StringName = &"wooden_cross") -> int:
	_fill(grave_id, corpse)
	inv.add_item(marker, 1)
	return graveyard.place_marker(grave_id, marker, inv)


func _fill(grave_id: String, corpse: CorpseRecord) -> void:
	assert_true(graveyard.dig(grave_id), "dig " + grave_id)
	assert_true(graveyard.bury(grave_id, corpse.id), "bury " + grave_id)


## Fresh fever corpse (base payment 3); optionally examined and shrouded.
func _corpse(examined: bool = false, shrouded: bool = false) -> CorpseRecord:
	var r := CorpseRecord.new()
	r.display_name = "Anna Moor"
	r.cause_id = &"fever"
	r.examined = examined
	r.shrouded = shrouded
	return corpses.spawn_corpse(r, Transform3D.IDENTITY, &"ground")


func _plot(id: String, old: bool) -> PlotDouble:
	var plot := PlotDouble.new()
	plot.grave_id = id
	plot.is_old = old
	plot.add_to_group(&"grave_plot")
	return plot


func _new_graveyard() -> Graveyard:
	var g := Graveyard.new()
	g.economy = economy
	g.tables = tables
	return g


func _leave_plot_group() -> void:
	for plot: Node in tree.get_nodes_in_group(&"grave_plot"):
		plot.remove_from_group(&"grave_plot")


func _has_event(kind: String) -> bool:
	for e: Array in events:
		if e[0] == kind:
			return true
	return false


func _json_round_trip(data: Dictionary) -> Dictionary:
	return JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(data))))


func _on_state(id: String, state: int) -> void:
	events.append(["state", id, state])


func _on_completed(grave_id: String, corpse_id: String, quality: int, breakdown: Array) -> void:
	events.append(["completed", grave_id, corpse_id, quality, breakdown])


func _on_payment(amount: int, reason: String) -> void:
	events.append(["payment", amount, reason])


func _on_quality(total: int, rating: StringName) -> void:
	events.append(["quality", total, rating])


func _on_buried(corpse_id: String, grave_id: String) -> void:
	events.append(["buried", corpse_id, grave_id])


func _on_corpse_updated(id: String) -> void:
	events.append(["corpse_updated", id])


func _on_slice() -> void:
	events.append(["slice_completed"])


func _on_panel(panel: StringName, context: Dictionary) -> void:
	events.append(["panel", panel, context])

extends TestCase
## P1 (docs/PHASE6_DESIGN.md §2.5, §3.4, §10): ShedStore, Inventory.stack_multiplier and ShedSupply –
## slots 24 / 32 / 40, stacks × 2 only for RESOURCE / MATERIAL from level 3, an upgrade never shrinks,
## fetching is atomic (all or nothing, room check), 10 / 0 minutes, storing without tools / coins /
## excluded items, shed_supply_moved, and fetching at the workbench / a build site / a building site /
## the stone panel leaves the stations' own checks unchanged.

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const STORE_SCENE := "res://src/entities/shed_store/shed_store.tscn"
const WORKBENCH_SCENE := "res://src/entities/workbench/workbench.tscn"
const BUILD_SITE_SCENE := "res://src/entities/build_site/build_site.tscn"
const SITE_SCENE := "res://src/entities/building_site/building_site.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"

var world: Node3D
var b: Buildings
var store: ShedStore
var player: Player
var events: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	events.clear()
	world = Node3D.new()
	world.name = "ShedWorld"
	tree.root.add_child(world)
	b = Buildings.new()
	b.name = "Buildings"
	b.config = Phase6Fixtures.buildings_config()
	for data: BuildingData in Phase6Fixtures.buildings():
		b.building_table[data.id] = data
	world.add_child(b)
	store = (load(STORE_SCENE) as PackedScene).instantiate() as ShedStore
	store.config = Phase6Fixtures.shed_config()
	world.add_child(store)
	player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	world.add_child(player)
	player.instant_actions = true
	player.inventory.clear()
	player.inventory.slot_count = 4
	GameState.set_flag(&"buildings_open", true)
	EventBus.shed_supply_moved.connect(_on_moved)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.shed_supply_moved.disconnect(_on_moved)
	EventBus.notification_requested.disconnect(_on_note)
	world.free()
	GameState.reset()
	TimeManager.reset()


func _on_moved(items: Dictionary, direction: StringName) -> void:
	events.append(["moved", items, direction])


func _on_note(text: String, kind: StringName) -> void:
	events.append(["note", text, kind])


func _events(kind: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == kind)


func _shed_at(level: int) -> void:
	b.load_state({"levels": {"shed": level}})
	b.apply_levels()


func _fill(target: Inventory, items: Dictionary) -> void:
	for id: Variant in items:
		assert_eq(target.add_item(StringName(str(id)), int(items[id])), 0, "fill %s" % id)


# --- ShedStore / Inventory ------------------------------------------------------------------------

func test_slots_by_level_and_never_shrinking() -> void:
	assert_true(store.is_in_group(ShedStore.GROUP))
	assert_true(ShedStore.find(tree) == store)
	assert_eq(store.store().slot_count, 0, "level 0: a site")
	var slots := []
	for level: int in [1, 2, 3]:
		_shed_at(level)
		slots.append(store.store().slot_count)
	assert_eq(slots, [24, 32, 40], "§2.5")
	assert_eq(store.store().stack_multiplier, 2)
	store.apply_level(1)
	assert_eq([store.store().slot_count, store.store().stack_multiplier], [40, 2], "never shrinks")
	assert_eq(store.get_interaction_prompt(player), "[E] Lager öffnen")
	var panels: Array = []
	var on_panel := func(panel: StringName, context: Dictionary) -> void: panels.append([panel, context])
	EventBus.ui_panel_requested.connect(on_panel)
	store.interact(player)
	EventBus.ui_panel_requested.disconnect(on_panel)
	assert_eq(panels, [[&"chest", {"storage": store.store(), "inventory": player.inventory, "chest": store}]])


func test_stacks_double_only_for_resource_and_material_from_level_three() -> void:
	_shed_at(2)
	var inv := store.store()
	assert_eq(inv.add_item(&"wood", 50), 0)
	assert_eq(inv.get_slots()[0].amount, 50, "level 2: plain stacks")
	_shed_at(3)
	assert_eq(inv.add_item(&"wood", 50), 0)
	assert_eq(inv.get_slots()[0].amount, 100, "RESOURCE × 2")
	inv.add_item(&"workstone", 20)
	assert_eq(inv.get_slots()[1], {"id": &"workstone", "amount": 20}, "MATERIAL × 2 (max_stack 10)")
	inv.add_item(&"wooden_cross", 10)
	assert_eq([inv.get_slots()[2].amount, inv.get_slots()[3].amount], [5, 5], "CRAFTED keeps its stack size")
	# The player's inventory is unaffected.
	assert_eq(player.inventory.stack_multiplier, 1)
	player.inventory.add_item(&"wood", 60)
	assert_eq(player.inventory.get_slots()[0].amount, 50)
	# Inventory rule: empty stack_categories = all categories.
	var any := Inventory.new()
	any.stack_multiplier = 3
	any.add_item(&"wooden_cross", 15)
	assert_eq(any.get_slots()[0].amount, 15)
	any.free()


func test_store_save_load_keeps_everything() -> void:
	_shed_at(3)
	store.store().add_item(&"stone", 100)
	store.store().add_item(&"iron_bar", 40)
	var state := store.save_state()
	assert_eq(state.keys(), ["storage"])
	var other := (load(STORE_SCENE) as PackedScene).instantiate() as ShedStore
	other.config = Phase6Fixtures.shed_config()
	world.add_child(other)
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq([other.store().slot_count, other.store().count(&"stone"), other.store().count(&"iron_bar")], [40, 100, 40])
	assert_eq(other.save_state(), store.save_state(), "roundtrip")
	# A lower level at load time never cuts the saved slots.
	_shed_at(1)
	var third := (load(STORE_SCENE) as PackedScene).instantiate() as ShedStore
	third.config = Phase6Fixtures.shed_config()
	world.add_child(third)
	third.load_state({"storage": {"slots": [{}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {},
			{}, {}, {}, {}, {}, {"id": "wood", "amount": 5}], "currency": {}}})
	assert_eq([third.store().slot_count, third.store().count(&"wood")], [30, 5], "nothing lost")


# --- ShedSupply rules -----------------------------------------------------------------------------

func test_shortfall_available_and_block_reasons() -> void:
	var cfg := Phase6Fixtures.shed_config()
	var needs := {&"workstone": 4, &"stone": 8, &"coin": 30}
	var shed := FakeInventory.new()
	var inv := FakeInventory.new()
	inv.add_item(&"stone", 8)
	inv.add_item(&"workstone", 1)
	assert_eq(ShedSupply.shortfall(needs, inv), {&"workstone": 3}, "coins excluded")
	assert_eq(ShedSupply.available(needs, shed), {&"workstone": 0, &"stone": 0})
	assert_eq(ShedSupply.fetch_block_reason(needs, inv, shed, 1, cfg), ShedSupply.TEXT_NO_SHED, "shed 1: no fetching")
	assert_eq(ShedSupply.fetch_block_reason(needs, inv, null, 2, cfg), ShedSupply.TEXT_NO_SHED)
	shed.add_item(&"workstone", 1)
	assert_eq(ShedSupply.fetch_block_reason(needs, inv, shed, 2, cfg), "Im Schuppen fehlt: 2 Werkstein")
	shed.add_item(&"workstone", 5)
	assert_eq(ShedSupply.available(needs, shed), {&"workstone": 6, &"stone": 0}, "„im Schuppen: 6\"")
	assert_eq(ShedSupply.fetch_block_reason(needs, inv, shed, 2, cfg), "")
	inv.add_item(&"workstone", 3)
	assert_eq(ShedSupply.fetch_block_reason(needs, inv, shed, 3, cfg), ShedSupply.TEXT_NOTHING_MISSING)
	assert_eq([ShedSupply.fetch_minutes(1, cfg), ShedSupply.fetch_minutes(2, cfg), ShedSupply.fetch_minutes(3, cfg)], [0, 10, 0])
	shed.free()
	inv.free()


func test_fetch_is_atomic_with_room_check() -> void:
	_shed_at(2)
	var shed := store.store()
	var inv := player.inventory
	inv.slot_count = 2
	_fill(inv, {&"wood": 50, &"clay": 1})
	_fill(shed, {&"clay": 10, &"workstone": 1})
	var needs := {&"clay": 4, &"workstone": 3}
	var shed_before := shed.save_state()
	var inv_before := inv.save_state()
	assert_eq(ShedSupply.fetch(needs, inv, shed), {}, "shed lacks 2 workstone → nothing")
	assert_eq([shed.save_state(), inv.save_state()], [shed_before, inv_before])
	shed.add_item(&"workstone", 5)
	assert_eq(ShedSupply.fetch_block_reason(needs, inv, shed, 2, Phase6Fixtures.shed_config()), "Kein Platz im Inventar")
	shed_before = shed.save_state()
	assert_eq(ShedSupply.fetch(needs, inv, shed), {}, "clay fits, workstone does not → nothing")
	assert_eq([shed.save_state(), inv.save_state()], [shed_before, inv_before])
	inv.slot_count = 3
	assert_eq(ShedSupply.fetch(needs, inv, shed), {&"clay": 3, &"workstone": 3}, "exactly the missing amounts")
	assert_eq([inv.count(&"clay"), inv.count(&"workstone"), shed.count(&"clay"), shed.count(&"workstone")], [4, 3, 7, 3])
	assert_eq(ShedSupply.fetch(needs, inv, shed), {}, "nothing missing any more")


func test_store_surplus_skips_tools_coins_and_excluded() -> void:
	_shed_at(3)
	var inv := player.inventory
	inv.slot_count = 8
	_fill(inv, {&"wood": 20, &"workstone": 5, &"wooden_cross": 1, &"shovel_iron": 1, &"coin": 9, &"linen": 2})
	var cfg := Phase6Fixtures.shed_config()
	assert_true(cfg.excluded_items.has(&"bone_box_full"), "§2.5")
	assert_false(ShedSupply.storable(&"bone_box_full", cfg))
	var custom := cfg.duplicate() as ShedConfig
	custom.excluded_items = [&"linen"] as Array[StringName]
	var moved := ShedSupply.store_surplus(inv, store.store(), custom)
	assert_eq(moved, {&"wood": 20, &"workstone": 5})
	assert_eq([inv.count(&"wooden_cross"), inv.count(&"shovel_iron"), inv.count(&"coin"), inv.count(&"linen")], [1, 1, 9, 2],
			"crafted, tools, coins and excluded stay")
	assert_eq([store.store().count(&"wood"), store.store().count(&"workstone")], [20, 5])
	# Only what fits moves; the rest stays with the player.
	var small := Inventory.new()
	small.slot_count = 1
	small.stack_categories = cfg.stack_categories
	inv.remove_item(&"linen", 2)
	inv.add_item(&"stone", 60)
	assert_eq(ShedSupply.store_surplus(inv, small, cfg), {&"stone": 50})
	assert_eq(inv.count(&"stone"), 10)
	small.free()


# --- request flow at the entities -----------------------------------------------------------------

func test_workbench_fetch_takes_ten_minutes_then_crafts_unchanged() -> void:
	var bench := (load(WORKBENCH_SCENE) as PackedScene).instantiate() as Workbench
	world.add_child(bench)
	await tree.process_frame
	bench.interact(player)
	_shed_at(1)
	_fill(store.store(), {&"wood": 10})
	bench.request_fetch({&"wood": 3})
	assert_eq(_events("note")[-1], ["note", ShedSupply.TEXT_NO_SHED, &"warning"], "shed 1: refused")
	assert_eq(player.inventory.count(&"wood"), 0)
	_shed_at(2)
	var start := TimeManager.total_minutes()
	bench.request_fetch({&"wood": 3})
	assert_eq(TimeManager.total_minutes() - start, 10, "shed 2: 10 minutes")
	assert_eq([player.inventory.count(&"wood"), store.store().count(&"wood")], [3, 7])
	assert_eq(_events("moved"), [["moved", {&"wood": 3}, &"fetch"]])
	bench.request_craft(&"wooden_cross")
	assert_eq([player.inventory.count(&"wooden_cross"), player.inventory.count(&"wood")], [1, 0], "the recipe check is unchanged")
	_shed_at(3)
	start = TimeManager.total_minutes()
	bench.request_fetch({&"wood": 2, &"coin": 5})
	assert_eq(TimeManager.total_minutes() - start, 0, "shed 3: at once")
	assert_eq(player.inventory.count(&"wood"), 2)
	# The stone panel calls bench.request_fetch(design_inputs) – same path.
	bench.request_fetch({&"wood": 2})
	assert_eq(_events("note")[-1], ["note", ShedSupply.TEXT_NOTHING_MISSING, &"warning"])


func test_request_store_at_level_three_only() -> void:
	var bench := (load(WORKBENCH_SCENE) as PackedScene).instantiate() as Workbench
	world.add_child(bench)
	await tree.process_frame
	bench.interact(player)
	_fill(player.inventory, {&"stone": 12, &"wooden_cross": 1})
	_shed_at(2)
	bench.request_store()
	assert_eq(player.inventory.count(&"stone"), 12, "shed 2: no storing")
	assert_eq(_events("moved"), [])
	_shed_at(3)
	bench.request_store()
	assert_eq([player.inventory.count(&"stone"), store.store().count(&"stone"), player.inventory.count(&"wooden_cross")], [0, 12, 1])
	assert_eq(_events("moved"), [["moved", {&"stone": 12}, &"store"]])
	bench.request_store()
	assert_eq(_events("note")[-1], ["note", ShedSupply.TEXT_NOTHING_TO_STORE, &"info"])


func test_build_site_fetch_then_workshop_check_unchanged() -> void:
	var shop := Workshop.new()
	shop.name = "Workshop"
	shop.config = Phase5Fixtures.workshop_config()
	for s: StationData in Phase5Fixtures.stations():
		shop.station_table[s.id] = s
	world.add_child(shop)
	GameState.set_flag(&"workshop_open", true)
	var site := (load(BUILD_SITE_SCENE) as PackedScene).instantiate() as BuildSite
	site.station_id = &"loom"
	world.add_child(site)
	await tree.process_frame
	site.interact(player)
	_fill(player.inventory, {&"coin": 10})
	_shed_at(2)
	_fill(store.store(), {&"wood": 20, &"iron_fittings": 5})
	assert_eq(site.block_reason(player.inventory), "Es fehlt: 8 Holz, 2 Eisenbeschlag")
	site.request_fetch({&"wood": 8, &"iron_fittings": 2, &"coin": 10})
	assert_eq(_events("moved"), [["moved", {&"wood": 8, &"iron_fittings": 2}, &"fetch"]])
	assert_eq(site.block_reason(player.inventory), "", "Workshop check unchanged, now satisfied")


func test_building_site_fetches_the_next_level() -> void:
	var site := (load(SITE_SCENE) as PackedScene).instantiate() as BuildingSite
	site.building_id = &"chapel"
	world.add_child(site)
	await tree.process_frame
	player.inventory.slot_count = 8
	_fill(player.inventory, {&"coin": 25, &"wood": 4})
	_shed_at(2)
	_fill(store.store(), {&"wood": 20, &"stone": 10, &"clay": 5, &"linen": 5, &"iron_fittings": 5})
	site.interact(player)
	var start := TimeManager.total_minutes()
	site.request_fetch()
	assert_eq(TimeManager.total_minutes() - start, 10)
	assert_eq(_events("moved"), [["moved", {&"wood": 6, &"stone": 8, &"clay": 2, &"linen": 2, &"iron_fittings": 2}, &"fetch"]])
	assert_eq(b.upgrade_block_reason(&"chapel", player.inventory), "")
	site.request_upgrade()
	assert_eq(b.level(&"chapel"), 1)

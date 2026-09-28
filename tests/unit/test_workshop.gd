extends TestCase
## P1 (docs/PHASE5_DESIGN.md §1.2, §1.5, §2.1, §3.4, §5.1, §5.2, §10): WorkshopRules, Workshop,
## BuildSite, Workbench.requires_built and DecorationManager.evict_rects – the workyard clearing
## (chest → player → pending until there is room, once, nothing lost), the atomic build (items +
## coins; one missing → nothing taken), block reasons, station_built / coins_spent, the station
## visible / usable only after the build, the charcoal kiln (start, end from minutes, loading
## mid-burn, collecting with a full inventory), workshop_open (morning / load, idempotent), the
## chapter exactly once, save / load. Fixtures: tests/fixtures/phase5 (Phase5Fixtures).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const WORKBENCH_SCENE := "res://src/entities/workbench/workbench.tscn"
const BUILD_SITE_SCENE := "res://src/entities/build_site/build_site.tscn"


## Holds at most `capacity` items in total; add_item returns what did not fit.
class LimitedInventory extends "res://tests/fixtures/fake_inventory.gd":
	var capacity: int = 0

	func _total() -> int:
		var n := 0
		for id: Variant in items:
			n += int(items[id])
		return n

	func can_add(_id: StringName, amount: int) -> bool:
		return _total() + amount <= capacity

	func add_item(id: StringName, amount: int) -> int:
		var fit := clampi(capacity - _total(), 0, amount)
		if fit > 0:
			super.add_item(id, fit)
		return amount - fit


class FakePlayer extends Node:
	var inventory: Inventory

	func _init() -> void:
		add_to_group(&"player")


## The hut chest as SaveStateCollector sees it (group saveable, save_id hut_chest, storage).
class FakeChest extends Node:
	var save_id: String = "hut_chest"
	var storage: Inventory

	func _init() -> void:
		add_to_group(&"saveable")


class FakeGraveyard extends Node:
	var list: Array[GraveRecord] = []

	func _init() -> void:
		add_to_group(&"graveyard")

	func graves() -> Array[GraveRecord]:
		return list

	func summary_context() -> Dictionary:
		return {"days": TimeManager.day, "content_ghosts": 2}


var world: Node3D
var shop: Workshop
var inv: Inventory
var events: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	events.clear()
	world = Node3D.new()
	world.name = "WorkshopWorld"
	tree.root.add_child(world)
	shop = _workshop()
	world.add_child(shop)
	inv = FakeInventory.new()
	EventBus.station_built.connect(_on_station_built)
	EventBus.coins_spent.connect(_on_coins_spent)
	EventBus.workshop_job_changed.connect(_on_job_changed)
	EventBus.chapter_completed.connect(_on_chapter)
	EventBus.ui_panel_requested.connect(_on_panel)
	EventBus.decor_changed.connect(_on_decor_changed)


func after_each() -> void:
	EventBus.station_built.disconnect(_on_station_built)
	EventBus.coins_spent.disconnect(_on_coins_spent)
	EventBus.workshop_job_changed.disconnect(_on_job_changed)
	EventBus.chapter_completed.disconnect(_on_chapter)
	EventBus.ui_panel_requested.disconnect(_on_panel)
	EventBus.decor_changed.disconnect(_on_decor_changed)
	world.free()
	if is_instance_valid(inv):
		inv.free()
	GameState.reset()
	TimeManager.reset()


func _workshop() -> Workshop:
	var w := Workshop.new()
	w.name = "Workshop"
	w.config = Phase5Fixtures.workshop_config()
	for s: StationData in Phase5Fixtures.stations():
		w.station_table[s.id] = s
	for r: RecipeData in Phase5Fixtures.recipes():
		w.recipe_table[r.id] = r
	for id: StringName in Phase5Fixtures.TOOL_IDS:
		w.item_table[id] = Phase5Fixtures.item(id)
	return w


func _on_station_built(id: StringName) -> void:
	events.append(["built", id])


func _on_coins_spent(amount: int, reason: StringName) -> void:
	events.append(["coins", amount, reason])


func _on_job_changed(station_id: StringName, recipe_id: StringName, state: StringName) -> void:
	events.append(["job", station_id, recipe_id, state])


func _on_chapter(id: StringName) -> void:
	events.append(["chapter", id])


func _on_panel(panel: StringName, context: Dictionary) -> void:
	events.append(["panel", panel, context])


func _on_decor_changed(uid: String, decor_id: StringName, placed: bool) -> void:
	events.append(["decor", uid, decor_id, placed])


func _events(kind: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == kind)


func _open() -> void:
	GameState.set_flag(&"workshop_open", true)


func _fill(target: Inventory, items: Dictionary) -> void:
	for id: Variant in items:
		target.add_item(StringName(str(id)), int(items[id]))


# --- WorkshopRules ----------------------------------------------------------------------------

func test_rules_missing_and_block_reasons() -> void:
	var mason := Phase5Fixtures.station(&"mason")
	assert_eq(WorkshopRules.missing(mason, inv), {&"stone": 6, &"wood": 3, &"coin": 15})
	_fill(inv, {&"stone": 4, &"wood": 5, &"coin": 10})
	var gaps := WorkshopRules.missing(mason, inv)
	assert_eq(gaps, {&"stone": 2, &"coin": 5}, "surplus not listed, coins last")
	assert_eq(WorkshopRules.build_block_reason(mason, inv, false, true), "Es fehlt: 2 Stein, 5 Münzen", "§2.1 text")
	assert_eq(WorkshopRules.build_block_reason(mason, inv, true, true), WorkshopRules.TEXT_BUILT)
	assert_eq(WorkshopRules.build_block_reason(mason, inv, false, false), WorkshopRules.TEXT_CLOSED)
	assert_eq(WorkshopRules.build_block_reason(Phase5Fixtures.station(&"workbench"), inv, false, true), WorkshopRules.TEXT_BUILT, "prebuilt")
	_fill(inv, {&"stone": 2, &"coin": 5})
	assert_eq(WorkshopRules.missing(mason, inv), {})
	assert_eq(WorkshopRules.build_block_reason(mason, inv, false, true), "")
	assert_eq(WorkshopRules.describe({&"coin": 1}), "1 Münze")


func test_rules_goal_progress() -> void:
	var cfg := Phase5Fixtures.workshop_config()
	var none := WorkshopRules.goal_progress([] as Array[StringName], {}, 0, cfg)
	assert_eq([none.done, none.total], [0, 7])
	assert_eq(none.missing, PackedStringArray(["mason", "loom", "forge", "shovel", "axe", "pickaxe", "stone_master"]))
	var part := WorkshopRules.goal_progress([&"mason", &"loom"] as Array[StringName], {&"shovel": 1, &"axe": 2, &"pickaxe": 1}, 0, cfg)
	assert_eq([part.done, part.stations, part.tools, part.master], [4, [2, 3], [2, 3], [0, 1]])
	assert_eq(part.missing, PackedStringArray(["forge", "pickaxe", "stone_master"]))
	var all := WorkshopRules.goal_progress([&"forge", &"mason", &"loom"] as Array[StringName], {&"shovel": 2, &"axe": 1, &"pickaxe": 2}, 2, cfg)
	assert_eq([all.done, all.total, all.missing], [7, 7, PackedStringArray()])


# --- build ------------------------------------------------------------------------------------

func test_build_is_atomic_with_items_and_coins() -> void:
	_open()
	_fill(inv, {&"stone": 6, &"wood": 3, &"coin": 14})
	assert_false(shop.build(&"mason", inv), "one coin short")
	assert_eq([inv.count(&"stone"), inv.count(&"wood"), inv.count(&"coin")], [6, 3, 14], "nothing taken")
	assert_eq(events, [])
	inv.add_item(&"coin", 3)
	assert_true(shop.build(&"mason", inv))
	assert_eq([inv.count(&"stone"), inv.count(&"wood"), inv.count(&"coin")], [0, 0, 2])
	assert_eq(events, [["coins", 15, &"build"], ["built", &"mason"]])
	assert_eq(GameState.get_stat(&"coins_spent"), 15, "stats.coins_spent in the sender")
	assert_true(shop.is_built(&"mason"))
	assert_eq(shop.built(), [&"mason"] as Array[StringName])
	assert_eq(shop.build_block_reason(&"mason", inv), WorkshopRules.TEXT_BUILT)
	assert_false(shop.build(&"mason", inv), "only once")
	assert_true(shop.is_built(&"workbench"), "prebuilt")
	assert_false(shop.is_built(&"loom"))


func test_build_refused_while_closed_or_unknown() -> void:
	_fill(inv, {&"stone": 20, &"wood": 20, &"clay": 10, &"iron_fittings": 4, &"coin": 100})
	assert_eq(shop.build_block_reason(&"loom", inv), WorkshopRules.TEXT_CLOSED)
	assert_false(shop.build(&"loom", inv), "workshop not open")
	assert_false(shop.build(&"nope", inv))
	assert_eq(inv.count(&"coin"), 100)
	_open()
	assert_true(shop.build(&"forge", inv))
	assert_eq([inv.count(&"stone"), inv.count(&"clay"), inv.count(&"iron_fittings"), inv.count(&"coin")], [10, 4, 2, 75])


# --- stations and build sites in the world --------------------------------------------------------

func test_station_visible_and_usable_only_after_the_build() -> void:
	var bench := (load(WORKBENCH_SCENE) as PackedScene).instantiate() as Workbench
	bench.station = &"loom"
	bench.requires_built = true
	world.add_child(bench)
	var site := (load(BUILD_SITE_SCENE) as PackedScene).instantiate() as BuildSite
	site.station_id = &"loom"
	world.add_child(site)
	assert_false(bench.visible, "station hidden before the build")
	assert_eq(bench.process_mode, Node.PROCESS_MODE_DISABLED, "no collision / interaction")
	assert_false(bench.is_available())
	assert_eq(bench.get_interaction_prompt(null), "")
	assert_false(site.visible, "site hidden before workshop_open")
	assert_eq(site.get_interaction_prompt(null), "")
	_open()
	site.refresh()
	assert_true(site.visible, "site from workshop_open")
	assert_eq(site.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(site.get_interaction_prompt(null), "[E] Bauplatz: Webstuhl")
	assert_eq(site.block_reason(inv), "Es fehlt: 8 Holz, 2 Eisenbeschlag, 10 Münzen")
	_fill(inv, {&"wood": 8, &"iron_fittings": 2, &"coin": 10})
	assert_true(shop.build(&"loom", inv))
	assert_true(bench.visible, "station replaces the site")
	assert_eq(bench.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_eq(bench.get_interaction_prompt(null), "[E] Webstuhl benutzen")
	assert_false(site.visible, "site gone")
	assert_eq(site.process_mode, Node.PROCESS_MODE_DISABLED)
	var old := (load(WORKBENCH_SCENE) as PackedScene).instantiate() as Workbench
	world.add_child(old)
	assert_true(old.visible and old.is_available(), "the old workbench is unaffected")
	assert_eq(old.get_interaction_prompt(null), Workbench.PROMPT_USE)


# --- charcoal kiln --------------------------------------------------------------------------------

func test_kiln_start_end_and_collect() -> void:
	var kiln := Phase5Fixtures.recipe(&"charcoal")
	_fill(inv, {&"wood": 9})
	assert_false(shop.start_job(&"forge", kiln, inv), "forge not built")
	shop.load_state({"built": ["forge"]})
	assert_false(shop.start_job(&"forge", Phase5Fixtures.recipe(&"iron_bar"), inv), "only background recipes")
	assert_false(shop.start_job(&"loom", kiln, inv), "wrong station")
	var start := TimeManager.total_minutes()
	assert_true(shop.start_job(&"forge", kiln, inv))
	assert_eq(inv.count(&"wood"), 5, "ingredients at once")
	assert_eq(events, [["job", &"forge", &"charcoal", &"started"]])
	var job := shop.job_of(&"forge")
	assert_eq([job.recipe, job.end_total, job.ready, job.output_id, job.amount], [&"charcoal", start + 480, false, &"charcoal", 3])
	assert_false(shop.start_job(&"forge", kiln, inv), "one job per station")
	assert_eq(inv.count(&"wood"), 5)
	assert_eq(shop.collect(&"forge", inv), 0, "not ready")
	TimeManager.advance(479)
	assert_false(shop.job_of(&"forge").ready)
	TimeManager.advance(1)
	assert_true(shop.job_of(&"forge").ready)
	assert_eq(_events("job").back(), ["job", &"forge", &"charcoal", &"ready"], "ready announced on the tick")
	TimeManager.advance(10)
	assert_eq(_events("job").size(), 2, "announced once")
	var full := LimitedInventory.new()
	full.capacity = 2
	assert_eq(shop.collect(&"forge", full), 0, "full inventory → nothing")
	assert_eq(full.count(&"charcoal"), 0)
	assert_false(shop.job_of(&"forge").is_empty(), "job stays")
	full.free()
	assert_eq(shop.collect(&"forge", inv), 3)
	assert_eq(inv.count(&"charcoal"), 3)
	assert_eq(shop.job_of(&"forge"), {})
	assert_eq(_events("job").back(), ["job", &"forge", &"charcoal", &"collected"])
	assert_eq(GameState.get_stat(&"crafted"), 1)
	assert_true(shop.start_job(&"forge", kiln, inv), "a new job after collecting")


func test_kiln_survives_a_load_mid_burn() -> void:
	shop.load_state({"built": ["forge", "mason"]})
	_fill(inv, {&"wood": 4})
	assert_true(shop.start_job(&"forge", Phase5Fixtures.recipe(&"charcoal"), inv))
	TimeManager.advance(200)
	var state := shop.save_state()
	var end := TimeManager.total_minutes() + 280
	assert_eq(state.jobs, {"forge": {"recipe": "charcoal", "end_total": end}})
	var other := _workshop()
	world.add_child(other)
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.save_state(), state, "roundtrip identical (also through JSON)")
	var job := other.job_of(&"forge")
	assert_eq([job.end_total, job.ready], [end, false])
	TimeManager.advance(280)
	assert_true(other.job_of(&"forge").ready)
	assert_eq(other.collect(&"forge", inv), 3)


# --- unlock ---------------------------------------------------------------------------------------

func test_workshop_opens_the_first_morning_after_unlock() -> void:
	TimeManager.day = 12
	TimeManager.minute_of_day = 14 * 60
	shop.apply_morning(12)
	assert_false(shop.is_open(), "no unlock flag")
	GameState.set_flag(&"cemetery_complete", true)
	shop.apply_morning(12)
	assert_false(shop.is_open(), "not the same afternoon")
	TimeManager.advance(15 * 60 + 59)  # day 13, 05:59
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [13, 359])
	assert_false(shop.is_open(), "before 06:00")
	TimeManager.advance(1)
	assert_true(shop.is_open(), "first minute ≥ 06:00 of the next morning")
	shop.apply_morning(13)
	shop.apply_morning(14)
	assert_eq(GameState.get_flag(&"workshop_open"), true, "idempotent")
	assert_eq(shop.save_state().open_day, 13)


func test_unlock_before_six_opens_the_same_morning() -> void:
	TimeManager.day = 12
	TimeManager.minute_of_day = 3 * 60
	GameState.set_flag(&"cemetery_complete", true)
	EventBus.cemetery_completed.emit()
	TimeManager.advance(3 * 60 - 1)
	assert_false(shop.is_open())
	TimeManager.advance(1)
	assert_true(shop.is_open(), "06:00 is the first morning after a night unlock")


func test_post_load_opens_at_once() -> void:
	TimeManager.day = 20
	TimeManager.minute_of_day = 20 * 60
	shop.post_load()
	assert_false(shop.is_open(), "no unlock flag, nothing")
	GameState.set_flag(&"cemetery_complete", true)
	shop.post_load()
	assert_true(shop.is_open(), "migrated save: open at once, also after 06:00")
	shop.post_load()
	assert_eq(shop.save_state().open_day, 20)


# --- chapter --------------------------------------------------------------------------------------

func test_chapter_exactly_once() -> void:
	var graveyard := FakeGraveyard.new()
	world.add_child(graveyard)
	var tools := Phase5Fixtures.inv_with_tools({&"shovel": 1, &"axe": 1, &"pickaxe": 1})
	shop.tool_inventory = tools
	shop.load_state({"built": ["mason", "loom", "forge"]})
	_open()
	var corpse := Phase5Fixtures.corpse(72, &"fever")
	graveyard.list.append(Phase5Fixtures.grave_with(corpse, &"", Phase5Fixtures.design(&"stone_master")))
	shop.check_goal()
	assert_eq(shop.goal_progress().missing, PackedStringArray(["pickaxe", "stone_master"]), "master stone without inscription")
	assert_eq(_events("chapter"), [])
	(tools.get(&"belt") as Dictionary)[&"pickaxe_master"] = 1
	assert_eq(shop.tiers(), {&"shovel": 1, &"axe": 1, &"pickaxe": 2})
	graveyard.list.append(Phase5Fixtures.grave_with(corpse, &"", Phase5Fixtures.design(&"stone_master", &"i_rest")))
	assert_eq(shop.master_stones(), 1)
	shop.check_goal()
	assert_eq(_events("chapter"), [["chapter", &"names_in_stone"]])
	assert_true(GameState.get_flag(&"names_in_stone_complete"))
	var panels := _events("panel")
	assert_eq(panels.size(), 1)
	var context: Dictionary = panels[0][2]
	assert_eq([panels[0][1], context.variant, context.master_stones, context.named_graves, context.graves_total],
			[&"slice_summary", &"names_in_stone", 1, 1, 2])
	assert_eq(context.final_line, Workshop.TEXT_FINAL_LINE)
	shop.check_goal()
	assert_eq(_events("chapter").size(), 1, "once")
	assert_true(shop.save_state().goal_done)
	var other := _workshop()
	world.add_child(other)
	other.tool_inventory = tools
	other.load_state(shop.save_state())
	other.check_goal()
	assert_eq(_events("chapter").size(), 1, "not again after loading")
	tools.free()


func test_build_checks_the_goal() -> void:
	var graveyard := FakeGraveyard.new()
	world.add_child(graveyard)
	var tools := Phase5Fixtures.inv_with_tools({&"shovel": 1, &"axe": 1, &"pickaxe": 2})
	shop.tool_inventory = tools
	graveyard.list.append(Phase5Fixtures.grave_with(Phase5Fixtures.corpse(), &"", Phase5Fixtures.design(&"stone_master", &"i_rest")))
	shop.load_state({"built": ["mason", "loom"]})
	_open()
	_fill(inv, {&"stone": 10, &"clay": 6, &"iron_fittings": 2, &"coin": 25})
	assert_true(shop.build(&"forge", inv))
	assert_eq(_events("chapter"), [["chapter", &"names_in_stone"]], "the last station completes the chapter")
	tools.free()


# --- save / load ---------------------------------------------------------------------------------

func test_save_load_roundtrip_and_tolerance() -> void:
	assert_eq(shop.save_state(), {"built": [], "jobs": {}, "goal_done": false, "evict_pending": {}, "open_day": 0, "spent": {},
			"content_before": -1})
	_open()
	_fill(inv, {&"stone": 6, &"wood": 3, &"coin": 20})
	shop.build(&"mason", inv)
	EventBus.coins_spent.emit(3, &"osric")
	var state := shop.save_state()
	assert_eq(state.built, ["mason"])
	assert_eq(state.spent, {"build": 15, "osric": 3})
	var other := _workshop()
	world.add_child(other)
	other.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(other.save_state(), state)
	other.load_state({})
	assert_eq(other.built(), [] as Array[StringName], "{} = nothing built")
	other.load_state({"built": ["mason", 5, "nope", "mason"], "jobs": {"forge": {"recipe": "nope", "end_total": 3}, "loom": 7},
			"goal_done": "yes", "evict_pending": {"decor_lantern": -2, "decor_flowerbed": 1}, "open_day": "x"})
	assert_eq(other.built(), [&"mason"] as Array[StringName], "unknown / duplicate stations dropped")
	assert_eq(other.job_of(&"forge"), {})
	assert_eq(other.pending_returns(), {&"decor_flowerbed": 1})
	assert_eq(other.save_state().goal_done, false)


# --- workyard clearing (§5.2 step 5) ---------------------------------------------------------------

func _decor_manager() -> DecorationManager:
	var container := Node3D.new()
	container.name = "Placed"
	world.add_child(container)
	var m := DecorationManager.new()
	m.name = "Decorations"
	m.mask = Phase3Fixtures.build_mask()
	m.config = Phase3Fixtures.decor_config().duplicate()
	for id: StringName in Phase3Fixtures.DECOR_IDS:
		m.decor_table[id] = Phase3Fixtures.decor(id)
	m.section_list = Phase3Fixtures.sections()
	m.fallback_unlocked = PackedInt32Array([1, 2])
	m.container_path = NodePath("../Placed")
	world.add_child(m)
	return m


func test_evict_rects_removes_only_overlapping_pieces() -> void:
	var decor := _decor_manager()
	var bench := decor.place(&"decor_bench_wood", Vector2i(1, 1), 0, null)  # x 0.5…2.0, z 0.5…1.0
	var bed := decor.place(&"decor_flowerbed", Vector2i(6, 1), 0, null)
	assert_ne(bench, "")
	assert_ne(bed, "")
	events.clear()
	assert_eq(decor.evict_rects([] as Array[Rect2]), {})
	assert_eq(decor.evict_rects([Rect2(2.0, 0.0, 0.5, 2.0)] as Array[Rect2]), {}, "touching an edge is not overlapping")
	var removed := decor.evict_rects([Rect2(1.8, 0.8, 0.5, 0.5), Rect2(-5.0, -5.0, 1.0, 1.0)] as Array[Rect2])
	assert_eq(removed, {&"decor_bench_wood": 1})
	assert_eq(events, [["decor", bench, &"decor_bench_wood", false]])
	assert_null(decor.get_placement(bench))
	assert_not_null(decor.get_placement(bed), "outside stays")


func test_workyard_decor_goes_to_chest_then_player_then_waits() -> void:
	var decor := _decor_manager()
	decor.place(&"decor_bench_wood", Vector2i(1, 1), 0, null)
	decor.place(&"decor_grave_vase", Vector2i(1, 3), 0, null)
	decor.place(&"decor_flowerbed", Vector2i(6, 1), 0, null)
	var chest := FakeChest.new()
	chest.storage = LimitedInventory.new()
	(chest.storage as LimitedInventory).capacity = 1
	world.add_child(chest)
	var player := FakePlayer.new()
	player.inventory = LimitedInventory.new()
	world.add_child(player)
	shop.workyard_rects = [Rect2(0.0, 0.0, 2.9, 4.0)] as Array[Rect2]
	var notes: Array = []
	var on_note := func(text: String, _kind: StringName) -> void: notes.append(text)
	EventBus.notification_requested.connect(on_note)
	shop.post_load()
	assert_eq(decor.placements().size(), 1, "only the flower bed outside is left")
	assert_eq(chest.storage.count(&"decor_bench_wood") + chest.storage.count(&"decor_grave_vase"), 1, "chest first")
	assert_eq(shop.pending_returns().values(), [1], "the rest waits (player full)")
	assert_eq(notes, [Workshop.TEXT_EVICTED])
	assert_true(GameState.get_flag(&"workyard_cleared"))
	# Pending returns survive a save and are handed out once there is room.
	var state := shop.save_state()
	assert_eq((state.evict_pending as Dictionary).size(), 1)
	(player.inventory as LimitedInventory).capacity = 5
	TimeManager.advance(1)
	assert_eq(shop.pending_returns(), {})
	var total := 0
	for id: StringName in [&"decor_bench_wood", &"decor_grave_vase"]:
		total += chest.storage.count(id) + player.inventory.count(id)
	assert_eq(total, 2, "nothing lost")
	# Once: new decor in the rects after the clearing stays.
	decor.place(&"decor_bench_wood", Vector2i(1, 1), 0, null)
	shop.post_load()
	assert_eq(decor.placements().size(), 2)
	assert_eq(notes.size(), 1, "one notification")
	EventBus.notification_requested.disconnect(on_note)
	chest.storage.free()
	player.inventory.free()


func test_workyard_clearing_waits_for_the_world() -> void:
	var decor := _decor_manager()
	decor.place(&"decor_bench_wood", Vector2i(1, 1), 0, null)
	shop.post_load()
	assert_eq(decor.placements().size(), 1, "no rects yet → nothing")
	assert_false(GameState.has_flag(&"workyard_cleared"))
	shop.workyard_rects = [Rect2(0.0, 0.0, 1.0, 1.0)] as Array[Rect2]
	shop.post_load()
	assert_eq(decor.placements().size(), 0)
	assert_eq(shop.pending_returns(), {&"decor_bench_wood": 1}, "no chest, no player → pending, not lost")
	assert_true(GameState.get_flag(&"workyard_cleared"))

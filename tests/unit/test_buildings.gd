extends TestCase
## P1 (docs/PHASE6_DESIGN.md §1.2, §1.5, §2.1, §3.3, §3.4, §5.1, §5.2, §10): BuildingRules, Buildings,
## BuildingSite – level order (no skipping, no demolition), the atomic upgrade (one missing → nothing
## taken), block reasons, building_upgraded / coins_spent(&"building") in the coin ledger, the crypt
## hooks (restart_cold, relocate_table_corpse on level 1, Ossuary.on_crypt_level), buildings_open
## (morning / load v4 / v5, idempotent), the chapter exactly once (all three conditions, every order),
## the clearing of the site_rects (chest, overflow, pending until there is room, once), save / load.
## Fixtures: tests/fixtures/phase6 (Phase6Fixtures).

const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const SITE_SCENE := "res://src/entities/building_site/building_site.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"


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


class FakeChest extends Node:
	var save_id: String = "hut_chest"
	var storage: Inventory

	func _init() -> void:
		add_to_group(&"saveable")


class FakeCorpseManager extends Node:
	var calls: Array = []

	func _init() -> void:
		add_to_group(&"corpse_manager")

	func restart_cold(now_total: int) -> void:
		calls.append(["restart_cold", now_total])

	func relocate_table_corpse(_xform: Transform3D, _parent: Node3D, room: StringName) -> String:
		calls.append(["relocate", room])
		return ""


class FakeOssuary extends Node:
	var list: PackedStringArray = []
	var levels: Array = []

	func _init() -> void:
		add_to_group(&"ossuary")

	func reinterred() -> PackedStringArray:
		return list

	func on_crypt_level(level: int) -> void:
		levels.append(level)


class FakeRites extends Node:
	var buried: int = 0

	func _init() -> void:
		add_to_group(&"chapel_rites")

	func services_buried() -> int:
		return buried


class FakeGraveyard extends Node:
	func _init() -> void:
		add_to_group(&"graveyard")

	func summary_context() -> Dictionary:
		return {"days": TimeManager.day, "content_ghosts": 3}


const L1_CRYPT := {&"stone": 12, &"wood": 6, &"clay": 4, &"iron_fittings": 2, &"coin": 20}
const L2_CRYPT := {&"workstone": 4, &"stone": 8, &"clay": 4, &"iron_bar": 1, &"coin": 30}
const L3_CRYPT := {&"workstone": 6, &"stone": 6, &"iron_bar": 2, &"coin": 35}

var world: Node3D
var b: Buildings
var inv: Inventory
var events: Array = []


func before_each() -> void:
	GameState.reset()
	TimeManager.reset()
	events.clear()
	world = Node3D.new()
	world.name = "BuildingsWorld"
	tree.root.add_child(world)
	b = _buildings()
	world.add_child(b)
	inv = FakeInventory.new()
	EventBus.building_upgraded.connect(_on_upgraded)
	EventBus.coins_spent.connect(_on_coins_spent)
	EventBus.chapter_completed.connect(_on_chapter)
	EventBus.ui_panel_requested.connect(_on_panel)
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.building_upgraded.disconnect(_on_upgraded)
	EventBus.coins_spent.disconnect(_on_coins_spent)
	EventBus.chapter_completed.disconnect(_on_chapter)
	EventBus.ui_panel_requested.disconnect(_on_panel)
	EventBus.notification_requested.disconnect(_on_note)
	world.free()
	if is_instance_valid(inv):
		inv.free()
	GameState.reset()
	TimeManager.reset()


func _buildings() -> Buildings:
	var n := Buildings.new()
	n.name = "Buildings"
	n.config = Phase6Fixtures.buildings_config()
	for data: BuildingData in Phase6Fixtures.buildings():
		n.building_table[data.id] = data
	return n


func _on_upgraded(id: StringName, level: int) -> void:
	events.append(["upgraded", id, level])


func _on_coins_spent(amount: int, reason: StringName) -> void:
	events.append(["coins", amount, reason])


func _on_chapter(id: StringName) -> void:
	events.append(["chapter", id])


func _on_panel(panel: StringName, context: Dictionary) -> void:
	events.append(["panel", panel, context])


func _on_note(text: String, kind: StringName) -> void:
	events.append(["note", text, kind])


func _events(kind: String) -> Array:
	return events.filter(func(e: Array) -> bool: return e[0] == kind)


func _open() -> void:
	GameState.set_flag(&"buildings_open", true)


func _fill(target: Inventory, items: Dictionary) -> void:
	for id: Variant in items:
		target.add_item(StringName(str(id)), int(items[id]))


# --- BuildingRules --------------------------------------------------------------------------------

func test_rules_next_level_missing_and_block_reasons() -> void:
	var crypt := Phase6Fixtures.building(&"crypt")
	assert_eq(BuildingRules.next_level(crypt, 0).level, 1)
	assert_eq(BuildingRules.next_level(crypt, 2).level, 3)
	assert_null(BuildingRules.next_level(crypt, 3), "fully built")
	assert_null(BuildingRules.next_level(null, 0))
	var l1 := crypt.level_data(1)
	assert_eq(BuildingRules.missing(l1, inv), L1_CRYPT, "inputs order, coins last")
	assert_eq(BuildingRules.cost(l1), L1_CRYPT)
	_fill(inv, {&"stone": 12, &"wood": 6, &"clay": 3, &"iron_fittings": 2, &"coin": 15})
	assert_eq(BuildingRules.missing(l1, inv), {&"clay": 1, &"coin": 5})
	assert_eq(BuildingRules.upgrade_block_reason(crypt, 0, inv, true), "Es fehlt: 1 Lehm, 5 Münzen", "§2.1 text")
	assert_eq(BuildingRules.upgrade_block_reason(crypt, 0, inv, false), BuildingRules.TEXT_CLOSED)
	assert_eq(BuildingRules.upgrade_block_reason(crypt, 3, inv, true), "Voll ausgebaut.")
	assert_eq(BuildingRules.upgrade_block_reason(null, 0, inv, true), BuildingRules.TEXT_CLOSED)
	_fill(inv, {&"clay": 1, &"coin": 5})
	assert_eq(BuildingRules.upgrade_block_reason(crypt, 0, inv, true), "")
	assert_eq(BuildingRules.missing(l1, null), L1_CRYPT, "no inventory: everything missing")


func test_rules_goal_progress() -> void:
	var cfg := Phase6Fixtures.buildings_config()
	var none := BuildingRules.goal_progress({}, 0, 0, cfg)
	assert_eq([none.done, none.total], [0, 5])
	assert_eq(none.missing, PackedStringArray(["crypt", "chapel", "shed", "services", "reinterred"]))
	var part := BuildingRules.goal_progress({&"crypt": 3, &"chapel": 1, &"shed": 2}, 1, 0, cfg)
	assert_eq([part.done, part.missing], [3, PackedStringArray(["chapel", "reinterred"])])
	assert_eq(part.levels, {&"crypt": [3, 2], &"chapel": [1, 2], &"shed": [2, 2]}, "tooltip Gruft 3/2 …")
	assert_eq([part.services, part.reinterred], [[1, 1], [0, 1]])
	var all := BuildingRules.goal_progress({"crypt": 2, "chapel": 2, "shed": 2}, 2, 3, cfg)
	assert_eq([all.done, all.total, all.missing], [5, 5, PackedStringArray()], "string keys work too")
	assert_eq(BuildingRules.goal_progress({}, 0, 0, null).total, 0)


# --- upgrade --------------------------------------------------------------------------------------

func test_upgrade_is_atomic_in_order_and_never_skips() -> void:
	_open()
	_fill(inv, L1_CRYPT)
	inv.remove_item(&"iron_fittings", 1)
	var before := (inv as FakeInventory).items.duplicate()
	assert_false(b.upgrade(&"crypt", inv), "one missing → nothing")
	assert_eq((inv as FakeInventory).items, before, "nothing taken")
	assert_eq(b.level(&"crypt"), 0)
	assert_eq(events, [])
	inv.add_item(&"iron_fittings", 1)
	# Materials of level 2 do not skip level 1.
	_fill(inv, L2_CRYPT)
	assert_true(b.upgrade(&"crypt", inv))
	assert_eq(b.level(&"crypt"), 1)
	for id: StringName in L1_CRYPT:
		assert_eq(inv.count(id), int(L2_CRYPT.get(id, 0)), "level 1 took exactly its inputs: %s" % id)
	assert_true(b.upgrade(&"crypt", inv))
	assert_eq(b.level(&"crypt"), 2)
	assert_eq((inv as FakeInventory).items, {}, "level 2 took the rest")
	_fill(inv, L3_CRYPT)
	assert_true(b.upgrade(&"crypt", inv))
	assert_eq(b.level(&"crypt"), 3)
	_fill(inv, L3_CRYPT)
	assert_false(b.upgrade(&"crypt", inv), "fully built: no level 4")
	assert_eq(b.upgrade_block_reason(&"crypt", inv), "Voll ausgebaut.")
	assert_eq(inv.count(&"coin"), 35, "nothing taken when maxed")
	assert_eq(_events("upgraded"), [["upgraded", &"crypt", 1], ["upgraded", &"crypt", 2], ["upgraded", &"crypt", 3]])
	assert_eq(_events("coins"), [["coins", 20, &"building"], ["coins", 30, &"building"], ["coins", 35, &"building"]])
	assert_eq(GameState.get_stat(&"coins_spent"), 85, "QA5-01: stats.coins_spent in the sender")
	assert_eq(GameState.get_stat(GameState.coin_ledger_stat(&"building")), 85, "ledger coins_spent_building")
	assert_eq(b.levels(), {&"crypt": 3, &"chapel": 0, &"shed": 0} as Dictionary[StringName, int])
	assert_false(b.upgrade(&"nope", inv))


func test_upgrade_refused_while_closed() -> void:
	_fill(inv, L1_CRYPT)
	assert_false(b.is_open())
	assert_eq(b.upgrade_block_reason(&"crypt", inv), BuildingRules.TEXT_CLOSED)
	assert_false(b.upgrade(&"crypt", inv))
	assert_eq(inv.count(&"coin"), 20)
	_open()
	assert_eq(b.upgrade_block_reason(&"crypt", inv), "")
	assert_false(b.upgrade(&"crypt", null))


func test_crypt_upgrade_hooks() -> void:
	var manager := FakeCorpseManager.new()
	world.add_child(manager)
	var ossuary := FakeOssuary.new()
	world.add_child(ossuary)
	_open()
	TimeManager.day = 31
	TimeManager.minute_of_day = 600
	_fill(inv, L1_CRYPT)
	assert_true(b.upgrade(&"crypt", inv))
	assert_eq(manager.calls, [["restart_cold", TimeManager.total_minutes()], ["relocate", &"crypt"]], "crypt 1: cold + table move")
	assert_eq(ossuary.levels, [1])
	_fill(inv, L2_CRYPT)
	assert_true(b.upgrade(&"crypt", inv))
	assert_eq(manager.calls.size(), 3, "crypt 2: no second table move")
	assert_eq(manager.calls[2][0], "restart_cold")
	assert_eq(ossuary.levels, [1, 2])
	_fill(inv, {&"wood": 12, &"stone": 4, &"iron_fittings": 2, &"coin": 10})
	assert_true(b.upgrade(&"shed", inv))
	assert_eq([manager.calls.size(), ossuary.levels], [3, [1, 2]], "other buildings do not touch the crypt")


func test_upgrade_applies_levels_to_the_shed_store() -> void:
	var store := (load("res://src/entities/shed_store/shed_store.tscn") as PackedScene).instantiate() as ShedStore
	store.config = Phase6Fixtures.shed_config()
	world.add_child(store)
	assert_eq(store.store().slot_count, 0, "a site has no store")
	_open()
	_fill(inv, {&"wood": 12, &"stone": 4, &"iron_fittings": 2, &"coin": 10})
	assert_true(b.upgrade(&"shed", inv))
	assert_eq(store.store().slot_count, 24)


# --- buildings_open -------------------------------------------------------------------------------

func test_buildings_open_the_first_morning_after_unlock() -> void:
	TimeManager.day = 20
	TimeManager.minute_of_day = 20 * 60
	b.apply_morning(20)
	assert_false(b.is_open(), "no unlock flag")
	GameState.set_flag(&"names_in_stone_complete", true)
	EventBus.chapter_completed.emit(&"names_in_stone")
	TimeManager.advance(9 * 60 + 59)  # 05:59 day 21
	assert_false(b.is_open())
	TimeManager.advance(1)
	assert_true(b.is_open(), "06:00 the next morning")
	assert_eq(b.save_state().open_day, 21)
	b.apply_morning(21)
	b.apply_morning(22)
	assert_true(b.is_open(), "idempotent")
	assert_eq(b.save_state().open_day, 21)


func test_unlock_before_six_opens_the_same_morning() -> void:
	TimeManager.day = 20
	TimeManager.minute_of_day = 3 * 60
	GameState.set_flag(&"names_in_stone_complete", true)
	EventBus.chapter_completed.emit(&"names_in_stone")
	TimeManager.advance(3 * 60 - 1)
	assert_false(b.is_open())
	TimeManager.advance(1)
	assert_true(b.is_open())


func test_post_load_v4_opens_at_once_v5_waits_for_the_morning() -> void:
	TimeManager.day = 30
	TimeManager.minute_of_day = 7 * 60
	b.load_state({})
	b.post_load()
	assert_false(b.is_open(), "no unlock flag, nothing")
	GameState.set_flag(&"names_in_stone_complete", true)
	b.load_state({})
	b.post_load()
	assert_true(b.is_open(), "migrated v4 save: open at once, also after 06:00")
	assert_eq(b.save_state().open_day, 30)
	b.post_load()
	assert_eq(b.save_state().open_day, 30, "idempotent")
	# A v5 state saved before its morning keeps waiting (save → load identical).
	GameState.set_flag(&"buildings_open", false)
	TimeManager.day = 20
	TimeManager.minute_of_day = 23 * 60
	b.load_state({"levels": {}, "goal_done": false, "open_day": 0, "spent": {}, "evict_pending": {}})
	b.post_load()
	assert_false(b.is_open(), "v5: the morning rule")
	TimeManager.advance(60)
	assert_false(b.is_open())
	TimeManager.advance(6 * 60)
	assert_true(b.is_open(), "06:00")


# --- chapter --------------------------------------------------------------------------------------

func test_chapter_exactly_once_in_every_order() -> void:
	var orders := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for order: Array in orders:
		GameState.reset()
		events.clear()
		var rites := FakeRites.new()
		var ossuary := FakeOssuary.new()
		world.add_child(rites)
		world.add_child(ossuary)
		b.load_state({})
		_open()
		for step: int in order:
			match step:
				0:
					b.load_state({"levels": {"crypt": 2, "chapel": 2, "shed": 2}})
				1:
					rites.buried = 1
				2:
					ossuary.list = PackedStringArray(["old_04"])
			b.check_goal()
			b.check_goal()
		assert_eq(_events("chapter"), [["chapter", &"roof_and_earth"]], "once, order %s" % [order])
		assert_true(GameState.get_flag(&"roof_and_earth_complete"))
		b.check_goal()
		assert_eq(_events("chapter").size(), 1)
		world.remove_child(rites)
		world.remove_child(ossuary)
		rites.free()
		ossuary.free()


func test_chapter_context_and_goal_via_upgrade() -> void:
	var rites := FakeRites.new()
	rites.buried = 1
	var ossuary := FakeOssuary.new()
	ossuary.list = PackedStringArray(["old_04", "old_06"])
	var graveyard := FakeGraveyard.new()
	for n: Node in [rites, ossuary, graveyard]:
		world.add_child(n)
	TimeManager.day = 30
	GameState.set_flag(&"names_in_stone_complete", true)
	b.load_state({})
	b.post_load()
	b.load_state({"levels": {"crypt": 2, "chapel": 2, "shed": 1}, "open_day": 30, "content_before": 3})
	GameState.add_stat(&"services_held", 4)
	b.check_goal()
	assert_eq(_events("chapter"), [], "shed only 1")
	assert_eq(b.goal_progress().missing, PackedStringArray(["shed"]))
	TimeManager.day = 35
	_fill(inv, {&"wood": 10, &"iron_fittings": 2, &"coin": 15})
	assert_true(b.upgrade(&"shed", inv), "the upgrade checks the goal")
	assert_eq(_events("chapter"), [["chapter", &"roof_and_earth"]])
	var panels := _events("panel")
	assert_eq(panels.size(), 1)
	var context: Dictionary = panels[0][2]
	assert_eq([panels[0][1], context.variant, context.chapter], [&"slice_summary", &"roof_and_earth", &"roof_and_earth"])
	assert_eq(context.buildings_days, 5)
	assert_eq(context.levels, {&"crypt": 2, &"chapel": 2, &"shed": 2} as Dictionary[StringName, int])
	assert_eq([context.services_held, context.services_buried], [4, 1])
	assert_eq(context.reinterred.size(), 2)
	assert_eq(context.coins_spent, {&"building": 15}, "coins after buildings_open by reason")
	assert_eq([context.content_before, context.content_now], [3, 3])
	assert_eq(context.final_line, "Die Toten warten jetzt nicht mehr im Regen.")


# --- site rects -----------------------------------------------------------------------------------

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


func test_site_decor_goes_to_chest_then_player_then_waits() -> void:
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
	b.site_rects = [Rect2(0.0, 0.0, 2.9, 4.0)] as Array[Rect2]
	b.post_load()
	assert_eq(decor.placements().size(), 1, "only the flower bed outside is left")
	assert_eq(chest.storage.count(&"decor_bench_wood") + chest.storage.count(&"decor_grave_vase"), 1, "chest first")
	assert_eq(b.pending_returns().values(), [1], "the rest waits (player full)")
	assert_eq(_events("note"), [["note", Buildings.TEXT_EVICTED, &"info"]])
	assert_true(GameState.get_flag(&"building_sites_cleared"))
	var state := b.save_state()
	assert_eq((state.evict_pending as Dictionary).size(), 1, "pending is saved")
	(player.inventory as LimitedInventory).capacity = 5
	TimeManager.advance(1)
	assert_eq(b.pending_returns(), {})
	var total := 0
	for id: StringName in [&"decor_bench_wood", &"decor_grave_vase"]:
		total += chest.storage.count(id) + player.inventory.count(id)
	assert_eq(total, 2, "nothing lost")
	decor.place(&"decor_bench_wood", Vector2i(1, 1), 0, null)
	b.post_load()
	assert_eq(decor.placements().size(), 2, "once: new decor after the clearing stays")
	assert_eq(_events("note").size(), 1, "one notification")
	chest.storage.free()
	player.inventory.free()


func test_site_clearing_waits_for_rects_and_new_game_counts_as_cleared() -> void:
	var decor := _decor_manager()
	decor.place(&"decor_bench_wood", Vector2i(1, 1), 0, null)
	b.post_load()
	assert_eq(decor.placements().size(), 1, "no rects yet → nothing")
	assert_false(GameState.has_flag(&"building_sites_cleared"))
	b.site_rects = [Rect2(0.0, 0.0, 1.0, 1.0)] as Array[Rect2]
	b.post_load()
	assert_eq(decor.placements().size(), 0)
	assert_eq(b.pending_returns(), {&"decor_bench_wood": 1}, "no chest, no player → pending, not lost")
	GameState.reset()
	EventBus.new_game_started.emit()
	assert_true(GameState.get_flag(&"building_sites_cleared"), "a new game has nothing to clear")


# --- save / load ----------------------------------------------------------------------------------

func test_save_load_roundtrip_and_tolerance() -> void:
	_open()
	b.load_state({"levels": {"crypt": 2, "chapel": 1}, "goal_done": false, "open_day": 30, "spent": {"building": 75},
			"evict_pending": {"decor_bench_wood": 1}, "content_before": 4})
	var state := b.save_state()
	assert_eq(state, {"levels": {"crypt": 2, "chapel": 1, "shed": 0}, "goal_done": false, "open_day": 30,
			"spent": {"building": 75}, "evict_pending": {"decor_bench_wood": 1}, "content_before": 4}, "§5.1")
	var copy := _buildings()
	world.add_child(copy)
	copy.load_state(JSON.parse_string(JSON.stringify(state)))
	assert_eq(copy.save_state(), state, "roundtrip through JSON")
	assert_eq(copy.level(&"crypt"), 2)
	copy.load_state({"levels": {"crypt": 7, "chapel": "x", "tower": 1}, "goal_done": "yes", "open_day": "x", "spent": [], "evict_pending": 3})
	assert_eq(copy.levels(), {&"crypt": 3, &"chapel": 0, &"shed": 0} as Dictionary[StringName, int], "clamped, damaged dropped")
	assert_eq(copy.save_state().goal_done, false)
	assert_eq(copy.save_state().open_day, 0)
	copy.load_state({})
	assert_eq(copy.levels(), {&"crypt": 0, &"chapel": 0, &"shed": 0} as Dictionary[StringName, int], "{} = all sites (v4)")


func test_phase6_fixture_helpers_use_the_w0_format() -> void:
	var fixture := Phase6Fixtures.crypt_at(2, tree)
	assert_eq([fixture.level(&"crypt"), fixture.level(&"chapel")], [2, 0])
	assert_true(tree.get_first_node_in_group(&"buildings") != null)
	fixture.free()


# --- BuildingSite ---------------------------------------------------------------------------------

func _player() -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	var old_inv := player.get_node("Inventory")
	player.remove_child(old_inv)
	old_inv.free()
	var fake := FakeInventory.new()
	fake.name = "Inventory"
	player.add_child(fake)
	world.add_child(player)
	player.instant_actions = true
	return player


func test_building_site_prompts_panel_and_timed_upgrade() -> void:
	var site := (load(SITE_SCENE) as PackedScene).instantiate() as BuildingSite
	site.building_id = &"crypt"
	world.add_child(site)
	var player := _player()
	await tree.process_frame
	assert_true(site.is_in_group(&"building_site"))
	assert_false(site.visible, "hidden before buildings_open")
	assert_eq(site.process_mode, Node.PROCESS_MODE_DISABLED)
	assert_eq(site.get_interaction_prompt(player), "")
	assert_false(site.can_interact(player))
	_open()
	site.refresh()
	assert_true(site.visible)
	assert_eq(site.get_interaction_prompt(player), "[E] Bauplatz: Gruft")
	assert_true(site.can_interact(player))
	site.interact(player)
	var panels := _events("panel")
	assert_eq(panels.size(), 1)
	assert_eq(panels[0][1], &"building")
	assert_eq(panels[0][2].building, &"crypt")
	assert_eq([panels[0][2].level, panels[0][2].site, panels[0][2].inventory, panels[0][2].player],
			[0, site, player.inventory, player])
	assert_eq((panels[0][2].data as BuildingData).id, &"crypt")
	site.request_upgrade()
	assert_eq(b.level(&"crypt"), 0)
	assert_eq(_events("note")[-1], ["note", "Es fehlt: 12 Stein, 6 Holz, 4 Lehm, 2 Eisenbeschlag, 20 Münzen", &"warning"])
	_fill(player.inventory, L1_CRYPT)
	var start := TimeManager.total_minutes()
	site.request_upgrade()
	assert_eq(b.level(&"crypt"), 1)
	assert_eq(TimeManager.total_minutes() - start, 180, "TimedAction of the level's minutes")
	assert_eq(_events("note")[-1], ["note", "Gruft: Stufe 1 steht.", &"reward"])
	assert_eq(site.get_interaction_prompt(player), "[E] Gruft ausbauen (Stufe 2)")
	assert_eq(site.needs(), L2_CRYPT)
	b.load_state({"levels": {"crypt": 3}})
	site.refresh()
	assert_eq(site.get_interaction_prompt(player), "", "fully built: no prompt")
	assert_false(site.can_interact(player))

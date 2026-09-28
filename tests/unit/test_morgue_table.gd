extends TestCase
## P2 (docs/PHASE6_DESIGN.md §2.2, §3.4, §4.4, §10): MorgueTable in Phase 6 – is_active per crypt
## level (the old table retires at crypt 1, the crypt table starts there: exactly one is active),
## the inactive table without visibility / collision / prompt / corpse, props that follow it, the
## panel title „Gruft-Tisch", put down with the room, and the Phase-4 handling (exam, prep,
## juniper, harvest) on the crypt table after the move from the old table.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const FakeInventory := preload("res://tests/fixtures/fake_inventory.gd")
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const TABLE_SCENE := "res://src/entities/morgue_table/morgue_table.tscn"


class PietyDouble extends Piety:
	func event(_kind: StringName, _reason: String) -> void:
		pass


class ReputationDouble extends Reputation:
	func _ready() -> void:
		pass

	func event(_kind: StringName, _reason: String) -> void:
		pass

	func change(_delta: int, _reason: String) -> void:
		pass


var world: Node3D
var manager: CorpseManager
var buildings: Buildings
var old_table: MorgueTable
var crypt_table: MorgueTable
var basin: StaticBody3D
var notes: Array = []
var panels: Array = []


func before_each() -> void:
	TimeManager.load_state({"day": 2, "minute_of_day": 600})
	world = Node3D.new()
	world.name = "World"
	var corpses := Node3D.new()
	corpses.name = "Corpses"
	world.add_child(corpses)
	manager = CorpseManager.new()
	manager.name = "CorpseManager"
	manager.tables = load(FIXTURE_TABLES) as CorpseTables
	manager.economy = load(FIXTURE_ECONOMY) as EconomyConfig
	manager.crypt_config = Phase6Fixtures.crypt_config()
	manager.prep_config = Phase4Fixtures.prep_config()
	manager.container_path = ^"../Corpses"
	world.add_child(manager)
	buildings = Phase6Fixtures.crypt_at(0)
	world.add_child(buildings)
	old_table = _table("morgue_table", &"", 0, 1, Vector3(-2, 0, -5))
	crypt_table = _table("crypt_table", &"crypt", 1, 0, Vector3(60, 0, -200))
	# The wash basin of the old table stands in the world (§4.4: it goes with the table).
	basin = StaticBody3D.new()
	basin.name = "wash_basin"
	basin.set_meta(&"follows_table", "morgue_table")
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	basin.add_child(shape)
	world.add_child(basin)
	tree.root.add_child(world)
	manager._last_delivery_day = 99
	notes.clear()
	panels.clear()
	EventBus.notification_requested.connect(_on_note)
	EventBus.ui_panel_requested.connect(_on_panel)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.ui_panel_requested.disconnect(_on_panel)
	if is_instance_valid(world):
		world.free()


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _on_panel(panel: StringName, context: Dictionary) -> void:
	panels.append([panel, context])


func _table(table_name: String, room: StringName, requires: int, retire: int, at: Vector3) -> MorgueTable:
	var table := (load(TABLE_SCENE) as PackedScene).instantiate() as MorgueTable
	table.name = table_name
	table.room = room
	table.requires_level = requires
	table.retire_at_level = retire
	table.position = at
	var bowl := Node3D.new()
	bowl.name = "smoke_bowl"
	bowl.set_meta(&"follows_table", true)
	table.add_child(bowl)
	world.add_child(table)
	return table


## Crypt level `level` + building_upgraded (what Buildings.upgrade sends).
func _upgrade(level: int) -> void:
	buildings.load_state({"levels": {"crypt": level}})
	EventBus.building_upgraded.emit(&"crypt", level)


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


func _spawn_on_old_table(traits: Array[StringName] = []) -> CorpseRecord:
	var r := Phase4Fixtures.corpse(traits, &"fever", 1.0, TimeManager.total_minutes())
	r.id = ""
	var out := manager.spawn_corpse(r, old_table.slot_transform(), &"ground")
	manager.put_down(out.id, &"table", old_table.slot_transform(), old_table.slot_node(), old_table.room)
	return out


func _shapes_disabled(root: Node) -> Array:
	var out: Array = []
	for shape: Node in root.find_children("*", "CollisionShape3D", true, false):
		out.append((shape as CollisionShape3D).disabled)
	return out


func test_exactly_one_table_is_active_per_level() -> void:
	await wait_frames(1)
	for level: int in 4:
		_upgrade(level)
		assert_eq([old_table.is_active(), crypt_table.is_active()], [level == 0, level >= 1], "level %d" % level)
	var alone := MorgueTable.new()
	assert_true(alone.is_active(), "outside a tree: crypt 0, the old table")
	alone.retire_at_level = 1
	alone.requires_level = 1
	assert_false(alone.is_active(), "the crypt table needs crypt 1")
	alone.free()
	buildings.free()
	assert_eq([old_table.is_active(), crypt_table.is_active()], [true, false], "no Buildings node = level 0")


func test_the_inactive_table_has_no_body_no_prompt_no_corpse() -> void:
	await wait_frames(1)
	assert_eq([old_table.visible, crypt_table.visible], [true, false], "ready: crypt 0")
	var r := _spawn_on_old_table()
	assert_eq(old_table.corpse_id, r.id)
	assert_eq(crypt_table.corpse_id, "", "the inactive table sees no corpse")
	var player := _player()
	await wait_frames(1)
	assert_eq(crypt_table.get_interaction_prompt(player), "")
	assert_false(crypt_table.can_interact(player))
	_upgrade(1)
	await wait_frames(1)
	assert_eq([old_table.visible, old_table.interactable.enabled], [false, false], "old table retired")
	assert_true(_shapes_disabled(old_table).all(func(d: bool) -> bool: return d), "no collision")
	assert_eq(old_table.get_interaction_prompt(player), "")
	assert_false(old_table.can_interact(player))
	assert_eq(old_table.corpse_id, "")
	assert_false((old_table.get_node("smoke_bowl") as Node3D).visible, "own follower")
	assert_eq([basin.visible, _shapes_disabled(basin)], [false, [true]], "the wash basin follows")
	assert_eq([crypt_table.visible, crypt_table.interactable.enabled], [true, true], "crypt table active")
	assert_true(_shapes_disabled(crypt_table).all(func(d: bool) -> bool: return not d))
	_upgrade(0)
	await wait_frames(1)
	assert_eq([old_table.visible, basin.visible, _shapes_disabled(basin), crypt_table.visible], [true, true, [false], false],
			"back (debug): everything returns")


func test_refresh_after_load_and_idempotent() -> void:
	await wait_frames(1)
	buildings.load_state({"levels": {"crypt": 2}})
	EventBus.game_loaded.emit(1)
	await wait_frames(1)
	assert_eq([old_table.visible, crypt_table.visible], [false, true], "game_loaded")
	old_table.refresh_active()
	crypt_table.refresh_active()
	assert_eq([old_table.visible, crypt_table.visible], [false, true])


func test_panel_title_and_put_down_with_room() -> void:
	await wait_frames(1)
	assert_eq([old_table.panel_title(), crypt_table.panel_title()], [MorgueTable.TITLE_DEFAULT, "Gruft-Tisch"])
	_upgrade(1)
	var player := _player()
	await wait_frames(1)
	var r := Phase4Fixtures.corpse([], &"fever", 1.0, TimeManager.total_minutes())
	r.id = ""
	var rec := manager.spawn_corpse(r, Transform3D.IDENTITY, &"ground")
	manager.pick_up(rec.id, player)
	assert_eq(crypt_table.get_interaction_prompt(player), MorgueTable.PROMPT_PUT_DOWN)
	crypt_table.interact(player)
	assert_eq([rec.location, rec.room], [&"table", &"crypt"])
	assert_eq(rec.cold_windows, PackedInt32Array([TimeManager.total_minutes(), -1, 800]), "room cold")
	assert_eq(crypt_table.corpse_id, rec.id)
	crypt_table.interact(player)
	assert_eq(panels.back()[0], MorgueTable.EXAM_PANEL)
	assert_eq((panels.back()[1].get("table") as MorgueTable).panel_title(), "Gruft-Tisch", "the panel asks its table")


func test_phase4_work_on_the_crypt_table_after_the_move() -> void:
	var care := CorpseCare.new()
	care.exam_config = Phase4Fixtures.exam_config()
	care.prep_config = Phase4Fixtures.prep_config()
	care.utilization_config = Phase4Fixtures.utilization_config()
	care.tables = load(FIXTURE_TABLES) as CorpseTables
	care.finds = Phase4Fixtures.finds()
	care.harvest_rule = func(_r: CorpseRecord, _k: StringName, i: Inventory, _c: UtilizationConfig, _known: bool) -> String:
		return "" if i != null and i.has(&"shears") else "Werkzeug fehlt"
	world.add_child(care)
	world.add_child(PietyDouble.new())
	world.add_child(ReputationDouble.new())
	var player := _player()
	await wait_frames(1)
	# On the old table: two steps, the braid and a running juniper window (like slot_p5_day16_table).
	var r := _spawn_on_old_table([&"tattoo"])
	player.inventory.add_item(&"juniper", 1)
	player.inventory.add_item(&"scrub_brush", 1)
	player.inventory.add_item(&"comb", 1)
	player.inventory.add_item(&"shears", 1)
	player.inventory.add_item(&"shroud", 1)
	old_table.interact(player)
	old_table.request_exam_step(&"clothing")
	old_table.request_exam_step(&"hands")
	old_table.request_harvest(&"hair")
	old_table.request_balm()
	var kept := [r.exam_done.duplicate(), r.traits_revealed.duplicate(), r.harvested.duplicate(), r.balm_windows.duplicate()]
	assert_eq(r.exam_done.size(), 2)
	assert_eq(r.harvested, [&"hair"] as Array[StringName])
	# Crypt 1: the table goes down (Buildings.upgrade does both in one call).
	_upgrade(1)
	assert_eq(manager.relocate_table_corpse(crypt_table.slot_transform(), crypt_table.slot_node(), &"crypt"), r.id)
	assert_eq([r.exam_done, r.traits_revealed, r.harvested, r.balm_windows], kept, "all state kept")
	assert_eq(crypt_table.corpse_id, r.id)
	assert_eq(old_table.corpse_id, "")
	# The rest happens downstairs, unchanged.
	crypt_table.interact(player)
	assert_eq(panels.back()[1].get("corpse_id"), r.id)
	assert_eq(crypt_table.panel_state().get("corpse_id"), r.id, "panel state from the crypt table")
	crypt_table.request_exam_all()
	assert_true(r.is_fully_examined())
	crypt_table.request_wash()
	crypt_table.request_dress(CorpseRecord.DRESS_SHROUD)
	crypt_table.request_lay_out()
	assert_eq([r.washed, r.dress, r.laid_out], [true, &"shroud", true])
	# The juniper (× 0.25) beats the crypt's room cold (× 0.8) while it runs.
	var moved_at := r.cold_windows[0]
	assert_true(CorpseDecay.is_balm_active(r, moved_at), "the juniper still ran when the table went down")
	assert_almost(CorpseDecay.rate_at(r, moved_at, manager.prep_config.balm_factor), manager.prep_config.balm_factor)
	assert_almost(CorpseDecay.rate_at(r, r.balm_windows[1] + 5, manager.prep_config.balm_factor), 0.8, 0.000001, "then the cold")
	crypt_table.request_pick_up()
	assert_eq([r.location, r.room], [&"carried", &""])

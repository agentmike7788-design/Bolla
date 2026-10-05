extends TestCase
## P2 (docs/PHASE6_DESIGN.md §2.2, §3.4, §10): the crypt in CorpseManager and CryptNiche – cold
## factors per place and crypt level, cold windows opened / closed on put down, pick up, burial and
## level change (restart_cold), niches open / sealed per level with one corpse each, the table move
## at crypt 1 (relocate_table_corpse keeps every state), the stench exemption, stats.niche_waits,
## mark_service, save / load in the middle of a window and the decay picture in a niche.
## Levels come from Phase6Fixtures.crypt_at (Buildings.load_state) – no world.

const FIXTURE_TABLES := "res://tests/fixtures/corpse_tables_fixture.tres"
const FIXTURE_ECONOMY := "res://tests/fixtures/economy_config_fixture.tres"
const NICHE_SCENE := "res://src/entities/crypt_niche/crypt_niche.tscn"


## Player stand-in (kept out of the tree): attach / detach like a carry socket, interior_id set.
class PlayerDouble extends Player:
	func attach_carried(node: Node3D, id: String) -> void:
		if node.get_parent() != null:
			node.get_parent().remove_child(node)
		add_child(node)
		carried = node
		carried_id = id

	func detach_carried() -> Node3D:
		var node := carried
		if node != null and node.get_parent() == self:
			remove_child(node)
		carried = null
		carried_id = ""
		return node


class ReputationDouble extends Reputation:
	var calls: Array = []

	func _ready() -> void:
		pass

	func tier() -> StringName:
		return &""

	func change(delta: int, reason: String) -> void:
		calls.append(["change", delta, reason])

	func event(kind: StringName, reason: String) -> void:
		calls.append(["event", kind, reason])


var world: Node3D
var container: Node3D
var manager: CorpseManager
var buildings: Buildings
var notes: Array = []
var _orphans: Array[Node] = []


func before_each() -> void:
	TimeManager.load_state({"day": 2, "minute_of_day": 600})
	world = Node3D.new()
	world.name = "World"
	container = Node3D.new()
	container.name = "Corpses"
	world.add_child(container)
	manager = CorpseManager.new()
	manager.name = "CorpseManager"
	manager.tables = load(FIXTURE_TABLES) as CorpseTables
	manager.economy = load(FIXTURE_ECONOMY) as EconomyConfig
	manager.crypt_config = Phase6Fixtures.crypt_config()
	manager.container_path = ^"../Corpses"
	world.add_child(manager)
	tree.root.add_child(world)
	manager._last_delivery_day = 99  # no delivery attempts while the clock runs
	buildings = Phase6Fixtures.crypt_at(1, tree)
	notes.clear()
	EventBus.notification_requested.connect(_on_note)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	for node: Node in _orphans:
		if is_instance_valid(node):
			node.free()
	_orphans.clear()
	if is_instance_valid(buildings):
		buildings.free()
	world.free()


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _now() -> int:
	return TimeManager.total_minutes()


func _set_level(level: int) -> void:
	buildings.load_state({"levels": {"crypt": level}})


func _spawn(location: StringName = &"ground", freshness: float = 1.0) -> CorpseRecord:
	var r := Phase5Fixtures.corpse(50, &"fever", &"", _now())
	r.id = ""
	var out := manager.spawn_corpse(r, Transform3D.IDENTITY, location)
	out.freshness = freshness
	return out


func _player(room: StringName = &"crypt") -> PlayerDouble:
	var p := PlayerDouble.new()
	p.interior_id = room
	_orphans.append(p)
	return p


func _niche(slot: String, min_level: int) -> CryptNiche:
	var niche := (load(NICHE_SCENE) as PackedScene).instantiate() as CryptNiche
	niche.slot_id = slot
	niche.min_level = min_level
	var marker := Node3D.new()
	marker.name = "slot_corpse"
	marker.position = Vector3(0, 0.6, 0)
	niche.add_child(marker)
	var chill := Node3D.new()
	chill.name = "chill"
	chill.position = Vector3(0, 0.2, 0.3)
	niche.add_child(chill)
	niche.position = Vector3(60, 0, -200)
	world.add_child(niche)
	return niche


# --- factors ---

func test_cold_factor_per_place_and_level() -> void:
	var expected := {0: [1.0, 1.0], 1: [0.5, 0.8], 2: [0.4, 0.7], 3: [0.3, 0.6]}
	for level: int in expected:
		_set_level(level)
		var niche: float = expected[level][0]
		var room: float = expected[level][1]
		assert_almost(manager.cold_factor_for(&"niche", &"crypt"), niche, 0.000001, "niche L%d" % level)
		assert_almost(manager.cold_factor_for(&"table", &"crypt"), room, 0.000001, "table L%d" % level)
		assert_almost(manager.cold_factor_for(&"ground", &"crypt"), room, 0.000001, "floor L%d" % level)
		assert_eq(manager.cold_factor_for(&"table", &""), 1.0, "outside")
		assert_eq(manager.cold_factor_for(&"catafalque", &"chapel"), 1.0, "chapel")
		assert_eq(manager.cold_factor_for(&"ground", &"chapel"), 1.0)
		assert_eq(manager.cold_factor_for(&"carried", &"crypt"), 1.0, "carried")
	buildings.free()
	assert_eq(manager.cold_factor_for(&"niche", &"crypt"), 1.0, "no Buildings node = level 0")


# --- cold windows ---

func test_put_down_in_a_niche_opens_and_pick_up_closes() -> void:
	var r := _spawn()
	var p := _player()
	var t0 := _now()
	assert_true(manager.pick_up(r.id, p))
	assert_true(manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1"))
	assert_eq([r.location, r.room, r.slot_id], [&"niche", &"crypt", "niche_1"])
	assert_eq(r.cold_windows, PackedInt32Array([t0, -1, 500]))
	assert_eq(manager.corpse_in_slot(&"niche", "niche_1"), r.id)
	assert_eq(manager.corpse_in_slot(&"niche", "niche_2"), "")
	TimeManager.advance(30)
	assert_true(manager.pick_up(r.id, p))
	assert_eq(r.cold_windows, PackedInt32Array([t0, t0 + 30, 500]))
	assert_eq([r.location, r.room, r.slot_id], [&"carried", &"", ""])
	assert_eq(manager.corpse_in_slot(&"niche", "niche_1"), "", "free again")


func test_crypt_floor_and_table_use_the_room_factor() -> void:
	var r := _spawn()
	var p := _player(&"crypt")
	manager.pick_up(r.id, p)
	var t0 := _now()
	assert_true(manager.put_down(r.id, &"ground", Transform3D.IDENTITY))
	assert_eq(r.room, &"crypt", "the carrier's room: the crypt floor")
	assert_eq(r.cold_windows, PackedInt32Array([t0, -1, 800]))
	TimeManager.advance(10)
	manager.put_down(r.id, &"table", Transform3D.IDENTITY, null, &"crypt")
	assert_eq(r.cold_windows, PackedInt32Array([t0, t0 + 10, 800, t0 + 10, -1, 800]), "moved: closed and reopened")
	var outside := _spawn()
	manager.pick_up(outside.id, _player(&""))
	manager.put_down(outside.id, &"ground", Transform3D.IDENTITY)
	assert_eq([outside.room, outside.cold_windows], [&"", PackedInt32Array()], "outside: no cold")


func test_same_minute_moves_leave_no_empty_window() -> void:
	var r := _spawn()
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_2")
	assert_eq(r.cold_windows, PackedInt32Array([_now(), -1, 500]), "the zero-length window is dropped")
	assert_eq(r.slot_id, "niche_2")


func test_burial_closes_the_window() -> void:
	var r := _spawn()
	var t0 := _now()
	manager.put_down(r.id, &"table", Transform3D.IDENTITY, null, &"crypt")
	TimeManager.advance(45)
	manager.mark_buried(r.id, "plot_01")
	assert_eq(r.cold_windows, PackedInt32Array([t0, t0 + 45, 800]))
	assert_eq([r.room, r.slot_id], [&"", ""])


func test_restart_cold_on_a_level_change() -> void:
	var niche := _spawn()
	var table := _spawn()
	var out := _spawn()
	var t0 := _now()
	manager.put_down(niche.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	manager.put_down(table.id, &"table", Transform3D.IDENTITY, null, &"crypt")
	TimeManager.advance(120)
	_set_level(2)
	manager.restart_cold(_now())
	assert_eq(niche.cold_windows, PackedInt32Array([t0, t0 + 120, 500, t0 + 120, -1, 400]))
	assert_eq(table.cold_windows, PackedInt32Array([t0, t0 + 120, 800, t0 + 120, -1, 700]))
	assert_eq(out.cold_windows, PackedInt32Array(), "outside untouched")
	var before := niche.cold_windows.duplicate()
	manager.restart_cold(_now())
	assert_eq(niche.cold_windows, before, "idempotent")
	_set_level(3)
	manager.restart_cold(_now())
	assert_eq(niche.cold_windows, PackedInt32Array([t0, t0 + 120, 500, t0 + 120, -1, 300]), "same minute: replaced")
	# A corpse that lay in the crypt at level 0 (no window) gets one when the crypt opens.
	_set_level(0)
	manager.restart_cold(_now())
	assert_eq(table.cold_windows, PackedInt32Array([t0, t0 + 120, 800]), "level 0: closed")
	TimeManager.advance(5)
	_set_level(1)
	manager.restart_cold(_now())
	assert_eq(table.cold_windows, PackedInt32Array([t0, t0 + 120, 800, t0 + 125, -1, 800]))


func test_freshness_follows_the_windows_and_survives_save_load() -> void:
	var r := _spawn()
	r.freshness = 1.0
	var t0 := _now()
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	var rate := CorpseDecay.decay_per_hour(r, manager.tables)
	EventBus.time_skipped.emit(t0, t0 + 600)
	assert_almost(r.freshness, 1.0 - rate * 5.0, 0.000001, "10 h × 0.5 = 5 effective hours")
	var data: Dictionary = JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(manager.save_state()))))
	manager.load_state(data)
	var loaded := manager.get_record(r.id)
	assert_eq(loaded.cold_windows, PackedInt32Array([t0, -1, 500]), "open window saved")
	EventBus.time_skipped.emit(t0 + 600, t0 + 1200)
	assert_almost(loaded.freshness, 1.0 - rate * 10.0, 0.000001, "the window runs on after loading")
	assert_eq(manager.corpse_in_slot(&"niche", "niche_1"), r.id, "occupancy from the records")


# --- niches ---

func test_niches_open_per_level() -> void:
	var niches: Array[CryptNiche] = []
	for slot: String in Phase6Fixtures.NICHES:
		niches.append(_niche(slot, int(Phase6Fixtures.NICHES[slot])))
	var cfg := Phase6Fixtures.crypt_config()
	for level: int in 4:
		_set_level(level)
		var open := niches.filter(func(n: CryptNiche) -> bool: return n.is_open()).size()
		assert_eq(open, cfg.niches_by_level[level], "level %d" % level)
	_set_level(1)
	var p := _player()
	var sealed := niches[2]
	assert_eq(sealed.get_interaction_prompt(p), CryptNiche.TEXT_SEALED)
	assert_false(sealed.can_interact(p))
	assert_eq(niches[0].get_interaction_prompt(p), "", "empty hands, empty niche")


func test_niche_put_and_take_through_the_entity() -> void:
	var niche := _niche("niche_1", 1)
	var r := _spawn()
	var p := _player()
	manager.pick_up(r.id, p)
	assert_eq(niche.get_interaction_prompt(p), CryptNiche.PROMPT_PUT)
	assert_true(niche.can_interact(p))
	niche.interact(p)
	assert_eq([r.location, r.room, r.slot_id], [&"niche", &"crypt", "niche_1"])
	assert_eq(niche.occupant(), r.id)
	assert_eq(manager.get_corpse_node(r.id).get_parent(), niche.slot_node(), "on the slot marker")
	assert_eq(niche.get_interaction_prompt(p), CryptNiche.PROMPT_TAKE)
	niche.interact(p)
	assert_eq(r.location, &"carried")
	assert_eq(niche.occupant(), "")


func test_one_corpse_per_niche() -> void:
	var niche := _niche("niche_1", 1)
	var a := _spawn()
	var b := _spawn()
	manager.put_down(a.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	var p := _player()
	manager.pick_up(b.id, p)
	assert_eq(niche.get_interaction_prompt(p), CryptNiche.TEXT_OCCUPIED)
	assert_false(niche.can_interact(p))
	assert_false(manager.put_down(b.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1"), "manager refuses too")
	assert_false(manager.put_down(b.id, &"niche", Transform3D.IDENTITY, null, &"crypt", ""), "a niche needs a slot")
	assert_eq(b.location, &"carried")
	assert_true(manager.put_down(b.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_2"))


func test_niche_waits_once_per_corpse() -> void:
	var r := _spawn()
	var p := _player()
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	TimeManager.advance(59)
	manager.pick_up(r.id, p)
	assert_eq(GameState.get_stat(&"niche_waits"), 0, "59 min is no wait")
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	TimeManager.advance(30)
	_set_level(2)
	manager.restart_cold(_now())
	TimeManager.advance(30)
	manager.pick_up(r.id, p)
	assert_eq(GameState.get_stat(&"niche_waits"), 1, "30 + 30 min across a level change")
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	TimeManager.advance(120)
	manager.pick_up(r.id, p)
	assert_eq(GameState.get_stat(&"niche_waits"), 1, "once per corpse")
	manager.put_down(r.id, &"ground", Transform3D.IDENTITY, null, &"crypt")
	var data := manager.save_state()
	assert_eq(data.get("niche_waited"), [r.id])
	manager.load_state(data)
	manager.post_load()
	var again := manager.get_record(r.id)
	manager.put_down(again.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	TimeManager.advance(120)
	manager.pick_up(again.id, _player())
	assert_eq(GameState.get_stat(&"niche_waits"), 1, "also after a reload")
	var fresh := CorpseManager.new()
	_orphans.append(fresh)
	assert_false(fresh.save_state().has("niche_waited"), "not written while empty")


# --- table move, stench, service ---

func test_relocate_table_corpse_keeps_every_state() -> void:
	var r := _spawn()
	manager.put_down(r.id, &"table", Transform3D(Basis(), Vector3(-2, 1, -5)))
	r.exam_done.assign([&"clothing", &"hands"])
	r.traits_revealed.assign([&"tattoo"])
	r.harvested.assign([&"hair"])
	r.balm_windows = PackedInt32Array([_now() - 30, _now() + 90])
	r.washed = true
	r.dress = CorpseRecord.DRESS_SHROUD
	r.shrouded = true
	var before := r.to_dict()
	var slot := Node3D.new()
	slot.position = Vector3(60, 0.9, -200)
	world.add_child(slot)
	var t0 := _now()
	assert_eq(manager.relocate_table_corpse(slot.global_transform, slot, &"crypt"), r.id)
	var after := r.to_dict()
	for key: String in before:
		if key in ["room", "cold_windows", "position", "rot_y"]:
			continue
		assert_eq(after[key], before[key], key)
	assert_eq([r.location, r.room, r.cold_windows], [&"table", &"crypt", PackedInt32Array([t0, -1, 800])])
	assert_eq(manager.get_corpse_node(r.id).get_parent(), slot)
	assert_true(r.position.is_equal_approx(Vector3(60, 0.9, -200)))
	assert_eq(notes, [[CorpseManager.NOTE_RELOCATED, &"info"]], "one note")
	assert_eq(manager.relocate_table_corpse(slot.global_transform, slot, &"crypt"), "", "nothing left on the old table")
	assert_eq(notes.size(), 1)
	# While the juniper runs it is the stronger factor; afterwards the cold.
	assert_almost(CorpseDecay.rate_at(r, t0 + 10, 0.25), 0.25)
	assert_almost(CorpseDecay.rate_at(r, t0 + 100, 0.25), 0.8)


func test_relocate_without_a_table_corpse() -> void:
	_spawn(&"ground")
	assert_eq(manager.relocate_table_corpse(Transform3D.IDENTITY, null, &"crypt"), "")
	assert_eq(notes, [])


func test_no_stench_from_the_crypt() -> void:
	var rep := ReputationDouble.new()
	rep.add_to_group(&"reputation")
	world.add_child(rep)
	manager.reputation_config = Phase4Fixtures.reputation_config()
	var r := _spawn(&"ground", 0.05)
	r.freshness = 0.05
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	# 48 h later: 24 effective hours × 0.05 – rotten even in the niche.
	assert_true(CorpseDecay.freshness_at(r, _now() + 48 * 60, 0.05, 0.25) < 0.1)
	# 05.10.2026 (user decision): the crypt keeps the smell in only from stench_exempt_min_level on.
	var cfg := manager.crypt_config.duplicate() as CryptConfig
	cfg.stench_exempt_min_level = manager.crypt_level()
	manager.crypt_config = cfg
	manager._check_stench(3, _now() + 48 * 60)
	assert_eq(rep.calls, [], "the crypt keeps the smell in")
	manager.put_down(r.id, &"ground", Transform3D.IDENTITY, null, &"")
	manager._check_stench(3, _now() + 48 * 60)
	assert_eq(rep.calls.filter(func(c: Array) -> bool: return c[1] == &"stench").size(), 1, "outside it stinks")
	manager.crypt_config = CryptConfig.new()
	manager.crypt_config.stench_exempt = false
	manager.put_down(r.id, &"niche", Transform3D.IDENTITY, null, &"crypt", "niche_1")
	manager._check_stench(4, _now() + 72 * 60)
	assert_eq(rep.calls.filter(func(c: Array) -> bool: return c[1] == &"stench").size(), 2, "stench_exempt false")
	manager.crypt_config = cfg.duplicate() as CryptConfig
	manager.crypt_config.stench_exempt_min_level = manager.crypt_level() + 1
	manager._check_stench(5, _now() + 96 * 60)
	assert_eq(rep.calls.filter(func(c: Array) -> bool: return c[1] == &"stench").size(), 3, "below stench_exempt_min_level the crypt still stinks")


func test_mark_service() -> void:
	var r := _spawn()
	var updated: Array = []
	var on_updated := func(id: String) -> void: updated.append(id)
	EventBus.corpse_updated.connect(on_updated)
	manager.mark_service(r.id, 32)
	EventBus.corpse_updated.disconnect(on_updated)
	assert_eq([r.service_held, r.service_day], [true, 32])
	assert_eq(updated, [r.id])
	var copy := CorpseRecord.from_dict(r.to_dict())
	assert_eq([copy.service_held, copy.service_day], [true, 32], "saved")


func test_place_locations_include_niche_and_catafalque() -> void:
	assert_true(CorpseRecord.LOCATION_NICHE in CorpseManager.PLACE_LOCATIONS)
	assert_true(CorpseRecord.LOCATION_CATAFALQUE in CorpseManager.PLACE_LOCATIONS)
	var r := _spawn()
	assert_true(manager.put_down(r.id, &"catafalque", Transform3D.IDENTITY, null, &"chapel"))
	assert_eq([r.location, r.room, r.slot_id, r.cold_windows], [&"catafalque", &"chapel", "", PackedInt32Array()])


# --- decay picture ---

func test_decay_visual_in_a_niche() -> void:
	var niche := _niche("niche_1", 1)
	var r := _spawn(&"ground", 0.2)
	var visual := manager.get_corpse_node(r.id).decay_visual
	var cfg := visual._config()
	visual.apply(0.2, &"decaying", false, false)
	assert_eq([visual.flies(), visual.wisps(), visual.chill(), visual.in_niche()], [8, 3, 0, false], "outside")
	var p := _player()
	manager.pick_up(r.id, p)
	niche.interact(p)
	await wait_frames(1)
	assert_eq(visual.in_niche(), true)
	assert_eq(visual.flies(), roundi(8 * cfg.niche_fly_scale), "the flies rest")
	assert_eq(visual.wisps(), roundi(3 * cfg.niche_wisp_scale), "wisps × 0.5")
	assert_eq(visual.chill(), cfg.niche_chill_particles, "cold breath")
	assert_almost(visual.overlay_amount(), CorpseDecayVisual.overlay_for(0.2, cfg, EconomyConfig.resolve()), 0.000001,
			"the colour stays honest")
	assert_true(visual.chill_node.transform.origin.is_equal_approx(niche.chill_node().global_position), "at the chill marker")
	niche.interact(p)
	manager.put_down(r.id, &"ground", Transform3D.IDENTITY, null, &"")
	await wait_frames(1)
	assert_eq([visual.chill(), visual.in_niche(), visual.flies()], [0, false, 8], "taken out")

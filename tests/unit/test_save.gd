extends TestCase
## M2: SaveManager – file format, typed round-trip, slots, can_save, load/new-game sequence (§5).
## Uses the fixture world tests/fixtures/save_world/ (saveable probes with different save_order).

const WORLD := "res://tests/fixtures/save_world/save_world.tscn"
const SILENT_WORLD := "res://tests/fixtures/save_world/silent_world.tscn"
const TEST_DIR := "user://test_saves"
const Probe := preload("res://tests/fixtures/save_world/saveable_probe.gd")
const READY_EVENTS: Array[String] = ["player:ready", "graveyard:ready", "early:ready", "world:ready", "world:world_ready"]

var notes: Array = []
var signals: Array = []


func before_each() -> void:
	SaveManager.save_dir = TEST_DIR
	_remove_test_dir()
	notes.clear()
	signals.clear()
	EventBus.notification_requested.connect(_on_note)
	EventBus.new_game_started.connect(_on_new_game_started)
	EventBus.game_loaded.connect(_on_game_loaded)
	EventBus.game_saved.connect(_on_game_saved)
	EventBus.time_tick.connect(_on_tick)


func after_each() -> void:
	EventBus.notification_requested.disconnect(_on_note)
	EventBus.new_game_started.disconnect(_on_new_game_started)
	EventBus.game_loaded.disconnect(_on_game_loaded)
	EventBus.game_saved.disconnect(_on_game_saved)
	EventBus.time_tick.disconnect(_on_tick)
	_remove_test_dir()
	tree.paused = false


# --- basics ---

func test_process_mode_always() -> void:
	assert_eq(SaveManager.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_reset_restores_defaults() -> void:
	SaveManager.is_loading = true
	SaveManager.world_ready_timeout_sec = 1.0
	SaveManager.reset()
	assert_eq(SaveManager.save_dir, "user://saves")
	assert_false(SaveManager.is_loading)
	assert_almost(SaveManager.world_ready_timeout_sec, 10.0)


# --- new game ---

func test_new_game_sequence() -> void:
	TimeManager.advance(3000)
	GameState.set_flag(&"old_run")
	GameState.add_stat(&"burials", 3)
	signals.clear()
	var world := await _start_world()
	assert_eq(world.scene_file_path, WORLD)
	var expected: Array[String] = READY_EVENTS.duplicate()
	expected.append_array(["player:new_game", "graveyard:new_game", "early:new_game"])
	assert_eq(_events(world), expected, "start content only after world_ready")
	assert_eq(signals, ["new_game_started", ["tick", 1, 390]], "new_game_started, then one refresh tick")
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 390])
	assert_true(TimeManager.running)
	assert_false(TimeManager.paused)
	assert_eq(GameState.flags, {})
	assert_eq(GameState.get_stat(&"burials"), 0)
	var player := _probe(world, "Player")
	assert_eq(player.count, 5, "start content applied")
	assert_eq(player.ready_state.count, 0, "world _ready saw only the default state")
	assert_false(SaveManager.is_loading)
	assert_true(SaveManager.can_save())


func test_new_game_clears_ui_and_pause() -> void:
	UIState.push_modal(&"pause")
	tree.paused = true
	await _start_world()
	assert_false(UIState.is_modal())
	assert_false(tree.paused)
	assert_true(TimeManager.running)


func test_new_game_with_missing_scene_warns() -> void:
	await SaveManager.new_game("res://does/not/exist.tscn")
	assert_eq(notes, [["Die Welt konnte nicht geladen werden.", &"warning"]])
	assert_eq(signals, [])
	await _start_world()
	assert_has(signals, "new_game_started", "SaveManager still usable")


func test_new_game_times_out_without_world_ready() -> void:
	SaveManager.world_ready_timeout_sec = 0.2
	await SaveManager.new_game(SILENT_WORLD)
	assert_eq(notes, [["Die Welt konnte nicht geladen werden.", &"warning"]])
	assert_false(signals.has("new_game_started"))
	assert_false(TimeManager.running)
	await _start_world()
	assert_has(signals, "new_game_started", "recovered after the timeout")


func test_stale_new_game_is_dropped_after_reset() -> void:
	SaveManager.new_game(SILENT_WORLD)  # waits (10 s timeout) – abandoned by reset()
	SaveManager.reset()
	SaveManager.save_dir = TEST_DIR
	await _start_world()
	_freeze_clock()
	await wait_frames(2)
	assert_eq(signals.count("new_game_started"), 1, "the stale coroutine does not finish a second new game")


# --- save file ---

func test_save_file_format() -> void:
	await _start_world()
	TimeManager.advance(100)
	var before_unix := int(Time.get_unix_time_from_system())
	assert_eq(SaveManager.save_game(3), OK)
	var path := TEST_DIR.path_join("slot_3.json")
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".tmp"), "temp file renamed")
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(_sorted_keys(doc), ["data", "format_version", "meta"])
	assert_eq(doc.format_version, SaveFileIO.FORMAT_VERSION)
	var meta: Dictionary = doc.meta
	assert_eq(_sorted_keys(meta), ["day", "game_version", "minute_of_day", "saved_unix", "scene"])
	assert_eq(meta.game_version, ProjectSettings.get_setting("application/config/version"))
	assert_eq(meta.day, 1)
	assert_eq(meta.minute_of_day, 490)
	assert_eq(meta.scene, WORLD)
	assert_true(int(meta.saved_unix) >= before_unix and int(meta.saved_unix) <= before_unix + 5, "saved_unix")
	assert_eq(JSON.to_native(doc.data), SaveManager.collect_state(), "data = JSON.from_native(state)")
	assert_eq(signals.back(), ["game_saved", 3])


func test_collect_state_structure() -> void:
	var world := await _start_world()
	var state := SaveManager.collect_state()
	assert_eq(_sorted_keys(state), ["autoloads", "nodes"])
	assert_eq(_sorted_keys(state.autoloads), ["GameState", "TimeManager"])
	assert_eq(state.autoloads.TimeManager, TimeManager.save_state())
	assert_eq(state.autoloads.GameState, GameState.save_state())
	assert_eq(_sorted_keys(state.nodes), ["early", "graveyard", "player"])
	assert_eq(state.nodes.player, _probe(world, "Player").save_state())


func test_collect_state_skips_duplicate_and_empty_ids() -> void:
	var world := await _start_world()
	var dup := Probe.new()
	dup.save_id = "early"
	dup.count = 99
	world.add_child(dup)
	dup.add_to_group(&"saveable")
	var nameless := Probe.new()
	world.add_child(nameless)
	nameless.add_to_group(&"saveable")
	var state := SaveManager.collect_state()  # warns twice
	assert_eq(_sorted_keys(state.nodes), ["early", "graveyard", "player"])
	assert_eq(state.nodes.early.count, 2, "first node (by save_order, then tree order) wins")


func test_typed_round_trip_through_file() -> void:
	var world := await _start_world()
	var player := _probe(world, "Player")
	player.pos = Vector3(1.5, -2.25, 3.1)
	player.count = 42
	player.tag = &"carrying"
	player.tags = [&"letter", &"valuables"]
	player.ratio = 0.75
	player.stock = {&"wood": 3, &"linen": 1}
	GameState.set_flag(&"met_carter")
	GameState.set_flag(&"delivery_skipped", 2)
	GameState.add_stat(&"reputation", -1)
	TimeManager.advance(1000)
	var before := SaveManager.collect_state()
	assert_eq(SaveManager.save_game(1), OK)
	player.pos = Vector3.ZERO
	player.tags = []
	GameState.clear_flags()
	TimeManager.advance(77)
	var err: Error = await SaveManager.load_game(1)
	assert_eq(err, OK)
	assert_eq(SaveManager.collect_state(), before, "state identical after save + load")
	var loaded := _probe(tree.current_scene, "Player")
	assert_eq(loaded.pos, Vector3(1.5, -2.25, 3.1))
	assert_eq(loaded.tags, [&"letter", &"valuables"])
	# Raw decoded file data keeps the Variant types (no String/float degradation).
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR.path_join("slot_1.json")))
	var data: Dictionary = JSON.to_native(doc.data)
	var p: Dictionary = data.nodes.player
	assert_eq(typeof(p.pos), TYPE_VECTOR3)
	assert_eq(typeof(p.count), TYPE_INT)
	assert_eq(typeof(p.tag), TYPE_STRING_NAME)
	assert_eq((p.tags as Array).get_typed_builtin(), TYPE_STRING_NAME)
	assert_eq(typeof(p.ratio), TYPE_FLOAT)
	assert_eq(typeof((p.stock as Dictionary).keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(data.autoloads.TimeManager.day), TYPE_INT)
	assert_eq(typeof(data.autoloads.GameState.flags.delivery_skipped), TYPE_INT)
	assert_eq(typeof((data.autoloads.GameState.flags as Dictionary).keys()[0]), TYPE_STRING_NAME)


func test_save_refused_during_scene_change() -> void:
	await _start_world()
	_freeze_clock()
	assert_eq(SaveManager.save_game(1), OK)
	SaveManager.load_game(1)  # not awaited: the scene change is now pending
	assert_true(SaveManager.is_loading)
	assert_false(SaveManager.can_save())
	assert_eq(SaveManager.save_game(2), ERR_BUSY)
	assert_eq(await SaveManager.load_game(1), ERR_BUSY)
	assert_true(await wait_for_signal(EventBus.game_loaded, 5.0))
	assert_false(SaveManager.has_save(2))
	assert_eq(SaveManager.save_game(2), OK, "saving works again after loading")


# --- slots ---

func test_slot_info_has_and_delete() -> void:
	var empty := {"exists": false, "day": 0, "minute_of_day": 0, "saved_unix": 0, "game_version": ""}
	assert_false(SaveManager.has_save(1))
	assert_eq(SaveManager.get_slot_info(1), empty)
	await _start_world()
	TimeManager.advance(70 + 1440)
	var now := int(Time.get_unix_time_from_system())
	assert_eq(SaveManager.save_game(1), OK)
	assert_true(SaveManager.has_save(1))
	var info := SaveManager.get_slot_info(1)
	assert_eq(_sorted_keys(info), ["day", "exists", "game_version", "minute_of_day", "saved_unix"])
	assert_eq(info.exists, true)
	assert_eq(info.day, 2)
	assert_eq(info.minute_of_day, 460)
	assert_true(info.day is int and info.minute_of_day is int and info.saved_unix is int, "ints, not JSON floats")
	assert_true(absi(int(info.saved_unix) - now) <= 5)
	assert_eq(info.game_version, ProjectSettings.get_setting("application/config/version"))
	SaveManager.delete_save(1)
	assert_false(SaveManager.has_save(1))
	SaveManager.delete_save(1)  # deleting a missing save is a no-op
	assert_eq(SaveManager.get_slot_info(1), empty)


func test_invalid_slot_numbers() -> void:
	assert_false(SaveManager.has_save(-1))
	assert_eq(SaveManager.save_game(-1), ERR_INVALID_PARAMETER)
	assert_eq(SaveManager.get_slot_info(-1).exists, false)


func test_newest_slot() -> void:
	assert_eq(SaveManager.newest_slot(), -1, "no save dir")
	await _start_world()
	for slot: int in [0, 1, 2]:
		assert_eq(SaveManager.save_game(slot), OK)
	_patch_meta(0, "saved_unix", 100)
	_patch_meta(1, "saved_unix", 300)
	_patch_meta(2, "saved_unix", 200)
	assert_eq(SaveManager.newest_slot(), 1)
	_patch_meta(2, "saved_unix", 300)
	assert_eq(SaveManager.newest_slot(), 2, "tie -> higher slot")
	_write_file("slot_9.json", "{ kaputt")
	_write_file("slot_x.json", "{}")
	_write_file("slot_05.json", "{}")
	_write_file("notes.txt", "hallo")
	_patch_meta(0, "saved_unix", 900)
	assert_eq(SaveManager.newest_slot(), 0, "corrupt and foreign files are ignored")


func test_newest_slot_empty_dir() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	assert_eq(SaveManager.newest_slot(), -1)


# --- can_save & quick save/load ---

func test_can_save_conditions() -> void:
	assert_false(SaveManager.can_save(), "no world loaded")
	var world := await _start_world()
	assert_true(SaveManager.can_save())
	UIState.push_modal(&"pause")
	assert_true(SaveManager.can_save(), "pause menu allows saving")
	UIState.push_modal(&"inventory")
	assert_false(SaveManager.can_save(), "panel on top")
	UIState.pop_modal(&"inventory")
	assert_true(SaveManager.can_save())
	UIState.pop_modal(&"pause")
	UIState.push_modal(&"dialogue")
	assert_false(SaveManager.can_save(), "dialogue open")
	UIState.pop_modal(&"dialogue")
	var player := _probe(world, "Player")
	player.set("busy", true)
	assert_false(SaveManager.can_save(), "timed action running")
	player.set("busy", false)
	SaveManager.is_loading = true
	assert_false(SaveManager.can_save(), "loading")
	SaveManager.is_loading = false
	assert_true(SaveManager.can_save())


func test_quick_save_input() -> void:
	var world := await _start_world()
	SaveManager._unhandled_input(_action(&"quick_save"))
	assert_eq(notes, [["Gespeichert.", &"info"]])
	assert_true(SaveManager.has_save(1))
	notes.clear()
	SaveManager.delete_save(1)
	_probe(world, "Player").set("busy", true)
	SaveManager._unhandled_input(_action(&"quick_save"))
	assert_eq(notes, [["Speichern gerade nicht möglich.", &"warning"]])
	assert_false(SaveManager.has_save(1))


func test_quick_load_input() -> void:
	await _start_world()
	_freeze_clock()
	SaveManager._unhandled_input(_action(&"quick_load"))
	assert_eq(notes, [["Kein Schnellspeicherstand.", &"warning"]])
	notes.clear()
	SaveManager._unhandled_input(_action(&"quick_save"))
	TimeManager.advance(45)
	SaveManager._unhandled_input(_action(&"quick_load"))
	assert_true(SaveManager.is_loading)
	assert_true(await wait_for_signal(EventBus.game_loaded, 5.0))
	assert_eq(signals.back(), ["game_loaded", 1])
	assert_eq(TimeManager.minute_of_day, 390)
	assert_eq(notes, [["Gespeichert.", &"info"]])


func test_other_input_is_ignored() -> void:
	await _start_world()
	SaveManager._unhandled_input(_action(&"interact"))
	assert_eq(notes, [])
	assert_false(SaveManager.has_save(1))


# --- load ---

func test_full_load_sequence() -> void:
	var world := await _start_world()
	_freeze_clock()
	var old_world_id := world.get_instance_id()
	_probe(world, "Early").count = 11
	TimeManager.advance(200)
	GameState.set_flag(&"met_carter")
	assert_eq(SaveManager.save_game(2), OK)
	TimeManager.advance(300)
	GameState.clear_flags()
	UIState.push_modal(&"inventory")
	TimeManager.push_pause(&"action")
	tree.paused = true
	signals.clear()
	SaveManager.load_game(2)  # coroutine, caller does not need to wait
	assert_true(SaveManager.is_loading)
	assert_eq([TimeManager.day, TimeManager.minute_of_day], [1, 590], "autoloads applied before the scene change")
	assert_true(GameState.has_flag(&"met_carter"))
	assert_false(TimeManager.running)
	assert_false(UIState.is_modal())
	assert_false(TimeManager.paused)
	assert_false(tree.paused)
	assert_eq(signals, [], "autoload state applied silently")
	assert_true(await wait_for_signal(EventBus.game_loaded, 5.0))
	var loaded := tree.current_scene
	assert_ne(loaded.get_instance_id(), old_world_id, "fresh world instance")
	var expected: Array[String] = READY_EVENTS.duplicate()
	expected.append_array(["early:load", "graveyard:load", "player:load",
			"early:post_load", "graveyard:post_load", "player:post_load", "graveyard:broadcast"])
	assert_eq(_events(loaded), expected, "load by save_order, then post_load, then broadcast")
	assert_eq(signals, [["tick", 1, 590], ["game_loaded", 2]], "one refresh tick, then game_loaded")
	for node_name: String in ["Player", "Graveyard", "Early"]:
		var probe := _probe(loaded, node_name)
		assert_true(probe.loaded_after_world_ready, node_name + " loaded after world_ready")
		assert_eq(probe.ready_state.count, 0, node_name + " _ready saw the default state")
	assert_eq(_probe(loaded, "Early").count, 11)
	assert_false(SaveManager.is_loading)
	assert_true(TimeManager.running)
	assert_true(SaveManager.can_save())


func test_load_replaces_world_added_without_scene_change() -> void:
	var world := await add_scene(WORLD)  # like an integration test that instantiates the world
	await wait_frames(1)
	assert_true(SaveManager.can_save(), "world_ready registers the world")
	assert_eq(SaveManager.save_game(1), OK)
	var err: Error = await SaveManager.load_game(1)
	assert_eq(err, OK)
	assert_false(is_instance_valid(world) and world.is_inside_tree(), "old world left the tree")
	assert_eq(tree.get_nodes_in_group(&"saveable").size(), 3, "no duplicate saveables")
	assert_eq(tree.current_scene.scene_file_path, WORLD)


func test_load_missing_file() -> void:
	var err: Error = await SaveManager.load_game(7)
	assert_eq(err, ERR_FILE_NOT_FOUND)
	assert_eq(notes, [["Kein Spielstand vorhanden.", &"warning"]])
	assert_false(SaveManager.is_loading)
	assert_null(tree.current_scene, "no scene change")


func test_load_rejects_bad_files() -> void:
	await _start_world()
	assert_eq(SaveManager.save_game(1), OK)
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR.path_join("slot_1.json")))
	var world := tree.current_scene
	var cases: Array = [
		["{ not json", ERR_PARSE_ERROR],
		["[1, 2]", ERR_PARSE_ERROR],
		[_with(good, "format_version", SaveFileIO.FORMAT_VERSION + 1), ERR_FILE_UNRECOGNIZED],
		[_with(good, "format_version", "1"), ERR_FILE_UNRECOGNIZED],
		[_with(good, "meta", null), ERR_FILE_CORRUPT],
		[_with(good, "meta", _with(good.meta, "day", "eins")), ERR_FILE_CORRUPT],
		[_with(good, "data", {"autoloads": {}, "nodes": {}}), ERR_FILE_CORRUPT],
		[_with(good, "data", JSON.from_native({"autoloads": {}})), ERR_FILE_CORRUPT],
		[_with(good, "meta", _with(good.meta, "scene", "res://missing_world.tscn")), ERR_FILE_MISSING_DEPENDENCIES],
	]
	TimeManager.advance(10)
	for c: Array in cases:
		notes.clear()
		_write_file("slot_4.json", c[0] if c[0] is String else JSON.stringify(c[0]))
		var err: Error = await SaveManager.load_game(4)
		assert_eq(err, c[1], "case %s" % str(c[0]).left(60))
		assert_eq(notes, [["Spielstand ist beschädigt.", &"warning"]])
		assert_false(SaveManager.is_loading)
	assert_eq(tree.current_scene, world, "world untouched")
	assert_eq(TimeManager.minute_of_day, 400, "state untouched")


func test_load_times_out_without_world_ready() -> void:
	await _start_world()
	assert_eq(SaveManager.save_game(1), OK)
	_patch_meta(1, "scene", SILENT_WORLD)
	SaveManager.world_ready_timeout_sec = 0.2
	var err: Error = await SaveManager.load_game(1)
	assert_eq(err, ERR_TIMEOUT)
	assert_false(SaveManager.is_loading)
	assert_eq(notes, [["Die Welt konnte nicht geladen werden.", &"warning"]])
	assert_false(signals.has(["game_loaded", 1]))


# --- apply_state ---

func test_apply_state_on_current_world() -> void:
	var world := await _start_world()
	var state := SaveManager.collect_state()
	var player := _probe(world, "Player")
	player.count = 77
	GameState.set_flag(&"later")
	TimeManager.advance(5)
	signals.clear()
	var start := _events(world).size()
	SaveManager.apply_state(state)
	assert_eq(_events(world).slice(start), ["early:load", "graveyard:load", "player:load",
			"early:post_load", "graveyard:post_load", "player:post_load"])
	assert_eq(player.count, 5)
	assert_false(GameState.has_flag(&"later"))
	assert_eq(TimeManager.minute_of_day, 390)
	assert_eq(signals, [], "no signals from apply_state")


func test_apply_state_unknown_and_missing_ids_only_warn() -> void:
	var world := await _start_world()
	var state := SaveManager.collect_state()
	state.nodes.erase("early")
	state.nodes["ghost"] = {"count": 1}
	state.autoloads.erase("GameState")
	_probe(world, "Early").count = 8
	GameState.set_flag(&"kept")
	var start := _events(world).size()
	SaveManager.apply_state(state)  # warnings only, never errors
	assert_eq(_events(world).slice(start), ["graveyard:load", "player:load",
			"early:post_load", "graveyard:post_load", "player:post_load"])
	assert_eq(_probe(world, "Early").count, 8, "missing id keeps its state")
	assert_true(GameState.has_flag(&"kept"), "missing autoload state keeps it")
	SaveManager.apply_state({})
	assert_eq(_probe(world, "Early").count, 8)


# --- helpers ---

func _start_world() -> Node:
	await SaveManager.new_game(WORLD)
	return tree.current_scene


## The world's event log as an Array (PackedStringArray is copied on read).
func _events(world: Node) -> Array:
	return Array(world.get("events") as PackedStringArray)


## Real frames must not advance the clock in tests that wait for signals.
func _freeze_clock() -> void:
	var cfg := TimeManager.config.duplicate() as TimeConfig
	cfg.seconds_per_game_minute = 1000.0
	TimeManager.config = cfg


func _probe(world: Node, node_name: String) -> Probe:
	return world.get_node(node_name) as Probe


func _action(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func _sorted_keys(d: Dictionary) -> Array:
	var keys: Array = []
	for k: Variant in d:
		keys.append(String(k))
	keys.sort()
	return keys


func _with(d: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := d.duplicate(true)
	out[key] = value
	return out


func _patch_meta(slot: int, key: String, value: Variant) -> void:
	var file_name := "slot_%d.json" % slot
	var doc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_DIR.path_join(file_name)))
	(doc.meta as Dictionary)[key] = value
	_write_file(file_name, JSON.stringify(doc))


func _write_file(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var f := FileAccess.open(TEST_DIR.path_join(file_name), FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _remove_test_dir() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for f: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(f))
	DirAccess.remove_absolute(TEST_DIR)


func _on_note(text: String, kind: StringName) -> void:
	notes.append([text, kind])


func _on_new_game_started() -> void:
	signals.append("new_game_started")


func _on_game_loaded(slot: int) -> void:
	signals.append(["game_loaded", slot])


func _on_game_saved(slot: int) -> void:
	signals.append(["game_saved", slot])


func _on_tick(d: int, m: int) -> void:
	signals.append(["tick", d, m])

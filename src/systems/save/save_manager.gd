extends Node
## Autoload SaveManager – new game, save, load (docs/VERTICAL_SLICE_DESIGN.md §5).
## File <save_dir>/slot_<n>.json = {"format_version", "meta", "data": JSON.from_native(state)},
## state = {autoloads: {TimeManager, GameState}, nodes: {<save_id>: {...}}} from group "saveable".
## Handles the quick_save / quick_load actions itself (slot 1). PROCESS_MODE_ALWAYS.
## Owns the world transition; file IO + validation: SaveFileIO, state gathering: SaveStateCollector.

## Internal: the world announced itself (EventBus.world_ready) or waiting timed out (null).
signal _world_arrived(world: Node)

const WORLD_SCENE := "res://src/world/graveyard/graveyard.tscn"
const FORMAT_VERSION := SaveFileIO.FORMAT_VERSION
const DEFAULT_SAVE_DIR := "user://saves"
const AUTOSAVE_SLOT := 0
const QUICK_SLOT := 1
const SAVEABLE_GROUP := SaveStateCollector.SAVEABLE_GROUP
## Autoload states in the save, applied in this order.
const AUTOLOADS: PackedStringArray = SaveStateCollector.AUTOLOADS
const PAUSE_MENU := &"pause"
const DEFAULT_WORLD_TIMEOUT_SEC := 10.0
## A Phase-4 TOOL item that probes the Inventory for the Phase-5 tool belt (belt_supported).
const BELT_PROBE_ITEM := &"rake"

const TEXT_SAVED := "Gespeichert."
const TEXT_CANNOT_SAVE := "Speichern gerade nicht möglich."
const TEXT_SAVE_FAILED := "Speichern fehlgeschlagen."
const TEXT_NO_QUICKSAVE := "Kein Schnellspeicherstand."
const TEXT_NO_SAVE := "Kein Spielstand vorhanden."
const TEXT_CORRUPT := "Spielstand ist beschädigt."
const TEXT_NEWER_VERSION := "Spielstand aus einer neueren Version."
const TEXT_WORLD_FAILED := "Die Welt konnte nicht geladen werden."

var save_dir: String = DEFAULT_SAVE_DIR
var is_loading: bool = false
## Real seconds a scene change may take until EventBus.world_ready (tests lower it).
var world_ready_timeout_sec: float = DEFAULT_WORLD_TIMEOUT_SEC

## Last world announced via EventBus.world_ready (may be freed – check is_instance_valid).
var _world: Node
## True from the scene change of new_game()/load_game() until the world is set up.
var _transition: bool = false
## Bumped by reset(): coroutines of an older generation stop after their await.
var _generation: int = 0
## Identifies the current world wait so a stale timeout cannot end a newer wait.
var _wait_token: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.world_ready.connect(_on_world_ready)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quick_save"):
		get_viewport().set_input_as_handled()
		_quick_save()
	elif event.is_action_pressed(&"quick_load"):
		get_viewport().set_input_as_handled()
		_quick_load()


## Coroutine: reset autoloads → change scene → world_ready → new_game_started → clock runs.
func new_game(scene_path: String = WORLD_SCENE) -> void:
	if _transition:
		push_warning("[SaveManager] new_game ignored – a scene change is already running")
		return
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("[SaveManager] new_game: scene '%s' not found" % scene_path)
		_notify(TEXT_WORLD_FAILED)
		return
	var generation := _generation
	_begin_transition()
	TimeManager.reset()
	GameState.reset()
	var world := await _change_world(scene_path)
	if generation != _generation:
		return
	_transition = false
	if world == null:
		_notify(TEXT_WORLD_FAILED)
		return
	EventBus.new_game_started.emit()
	TimeManager.running = true
	TimeManager.emit_refresh()


func save_game(slot: int) -> Error:
	if slot < 0:
		push_warning("[SaveManager] invalid slot %d" % slot)
		return ERR_INVALID_PARAMETER
	if _transition or is_loading:
		push_warning("[SaveManager] save_game(%d) refused during a scene change" % slot)
		return ERR_BUSY
	var err := SaveFileIO.ensure_dir(save_dir)
	if err != OK:
		return err
	var doc := SaveFileIO.make_doc(SaveFileIO.make_meta(_world_scene_path()), collect_state())
	err = SaveFileIO.write_doc(save_dir, slot, doc)
	if err != OK:
		return err
	EventBus.game_saved.emit(slot)
	return OK


## Coroutine (callers need not await). Invalid/missing file → warning + notification, no change.
func load_game(slot: int) -> Error:
	if _transition:
		push_warning("[SaveManager] load_game(%d) ignored – a scene change is already running" % slot)
		return ERR_BUSY
	var doc := {}
	var err := SaveFileIO.read_doc(save_dir, slot, doc)
	var scene_path := ""
	if err == OK:
		scene_path = (doc.meta as Dictionary).scene
		if not ResourceLoader.exists(scene_path, "PackedScene"):
			err = ERR_FILE_MISSING_DEPENDENCIES
	if err != OK:
		push_warning("[SaveManager] cannot load slot %d: %s" % [slot, error_string(err)])
		_notify(_load_error_text(err, slot))
		return err
	var state: Dictionary = doc.state
	var generation := _generation
	is_loading = true
	_begin_transition()
	SaveStateCollector.apply_autoloads(get_tree(), state.autoloads)
	var world := await _change_world(scene_path)
	if generation != _generation:
		return ERR_BUSY
	if world == null:
		is_loading = false
		_transition = false
		_notify(TEXT_WORLD_FAILED)
		return ERR_TIMEOUT
	SaveStateCollector.apply_nodes(get_tree(), without_absent_defaults(get_tree(), state.nodes))
	SaveStateCollector.post_load(get_tree())
	is_loading = false
	_transition = false
	TimeManager.running = true
	TimeManager.emit_refresh()
	var graveyard := get_tree().get_first_node_in_group(&"graveyard")
	if graveyard != null and graveyard.has_method("broadcast_state"):
		graveyard.call("broadcast_state")
	EventBus.game_loaded.emit(slot)
	return OK


## False while loading, while a modal other than the pause menu is open, while the player
## is busy (timed action) and when no world is loaded.
func can_save() -> bool:
	if is_loading or _transition:
		return false
	if not is_instance_valid(_world) or not _world.is_inside_tree():
		return false
	if UIState.is_modal() and UIState.top() != PAUSE_MENU:
		return false
	var player := get_tree().get_first_node_in_group(&"player")
	if player != null and player.has_method("is_busy") and bool(player.call("is_busy")):
		return false
	return true


func has_save(slot: int) -> bool:
	return slot >= 0 and FileAccess.file_exists(SaveFileIO.slot_path(save_dir, slot))


func delete_save(slot: int) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(SaveFileIO.slot_path(save_dir, slot))


## {exists, day, minute_of_day, saved_unix, game_version}; exists = readable save of this format.
func get_slot_info(slot: int) -> Dictionary:
	var info := {"exists": false, "day": 0, "minute_of_day": 0, "saved_unix": 0, "game_version": ""}
	var doc := {}
	if SaveFileIO.read_doc(save_dir, slot, doc, false) != OK:
		return info
	var meta: Dictionary = doc.meta
	info.exists = true
	info.day = int(meta.day)
	info.minute_of_day = int(meta.minute_of_day)
	info.saved_unix = int(meta.saved_unix)
	info.game_version = String(meta.game_version)
	return info


## Slot with the latest saved_unix (ties → higher slot), -1 if there is none.
func newest_slot() -> int:
	var best := -1
	var best_time := -1
	for slot: int in SaveFileIO.slots_on_disk(save_dir):
		var info := get_slot_info(slot)
		if not info.exists:
			continue
		var saved: int = info.saved_unix
		if saved > best_time or (saved == best_time and slot > best):
			best = slot
			best_time = saved
	return best


## Exactly the "data" part of a save file (before JSON.from_native).
func collect_state() -> Dictionary:
	return SaveStateCollector.collect(get_tree())


## Applies a collected state to the current world (no file, no scene change):
## autoloads silently, then load_state() by save_order, then post_load() for all.
func apply_state(data: Dictionary) -> void:
	SaveStateCollector.apply_autoloads(get_tree(), SaveStateCollector.sub_dict(data, "autoloads"))
	SaveStateCollector.apply_nodes(get_tree(), SaveStateCollector.sub_dict(data, "nodes"))
	SaveStateCollector.post_load(get_tree())


## The node states without the empty ones SaveMigration inserted for Phase-4 / Phase-5 system
## nodes (SaveMigration.V3_EMPTY_NODES, V4_EMPTY_NODES, V5_EMPTY_NODES, V6_EMPTY_NODES) that this world does not have (yet): {} is
## their default state, so nothing is lost and no "unknown save_id" warning appears. Non-empty
## states stay (and warn). Phase 5 (§5.2 step 1): while the player's Inventory has no tool belt
## yet (belt_supported), the migrated belt goes back into free slots (with_belt_fallback).
static func without_absent_defaults(tree: SceneTree, nodes: Dictionary) -> Dictionary:
	var present := {}
	for node: Node in SaveStateCollector.saveables(tree):
		present[SaveStateCollector.save_id(node)] = true
	var out := {}
	for key: Variant in nodes:
		var id := str(key)
		var value: Variant = nodes[key]
		var migrated_empty := id in SaveMigration.V3_EMPTY_NODES or id in SaveMigration.V4_EMPTY_NODES \
				or id in SaveMigration.V5_EMPTY_NODES or id in SaveMigration.V6_EMPTY_NODES
		if migrated_empty and not present.has(id) and value is Dictionary and (value as Dictionary).is_empty():
			continue
		out[key] = value
	return with_belt_fallback(out, belt_supported())


## Phase 5 §5.2 step 1, runtime side: with `supported` false (an Inventory without the tool belt,
## before P3's belt) the player's inventory.tools go back into the first free slots so no tool is
## lost; with true (or without "tools") the states are returned unchanged. Never changes `nodes`.
static func with_belt_fallback(nodes: Dictionary, supported: bool) -> Dictionary:
	if supported:
		return nodes
	var player: Variant = nodes.get(SaveMigration.PLAYER_SAVE_ID)
	if not player is Dictionary or not (player as Dictionary).get("inventory") is Dictionary:
		return nodes
	var inv: Dictionary = (player as Dictionary).inventory
	if not inv.get("tools") is Dictionary:
		return nodes
	var state := inv.duplicate(true)
	var belt: Dictionary = state.tools
	state.erase("tools")
	var slots: Array = state.get("slots") if state.get("slots") is Array else []
	for id: Variant in belt:
		var amount: int = int(belt[id]) if (belt[id] is int or belt[id] is float) else 1
		if amount <= 0:
			continue
		var entry := {"id": StringName(str(id)), "amount": amount}
		var free := -1
		for i: int in slots.size():
			if slots[i] is Dictionary and (slots[i] as Dictionary).is_empty():
				free = i
				break
		if free >= 0:
			slots[free] = entry
		else:
			slots.append(entry)
	state["slots"] = slots
	var p := (player as Dictionary).duplicate()
	p["inventory"] = state
	var out := nodes.duplicate()
	out[SaveMigration.PLAYER_SAVE_ID] = p
	return out


## The Inventory keeps tools on its belt (P3, Phase 5 §3.4): a probe inventory with tool_belt
## loads {"tools": {rake: 1}} and counts the rake. False with the W0 stub (no belt yet).
static func belt_supported() -> bool:
	if not Database.has_item(BELT_PROBE_ITEM):
		return false
	var probe := Inventory.new()
	probe.tool_belt = true
	probe.load_state({"slots": [], "currency": {}, "tools": {BELT_PROBE_ITEM: 1}})
	var ok := probe.count(BELT_PROBE_ITEM) == 1
	probe.free()
	return ok


func reset() -> void:
	save_dir = DEFAULT_SAVE_DIR
	is_loading = false
	world_ready_timeout_sec = DEFAULT_WORLD_TIMEOUT_SEC
	_transition = false
	_world = null
	_generation += 1
	_wait_token += 1


func _quick_save() -> void:
	if not can_save():
		_notify(TEXT_CANNOT_SAVE)
		return
	if save_game(QUICK_SLOT) == OK:
		_notify(TEXT_SAVED, &"info")
	else:
		_notify(TEXT_SAVE_FAILED)


func _quick_load() -> void:
	if _transition:
		return
	if not has_save(QUICK_SLOT):
		_notify(TEXT_NO_QUICKSAVE)
		return
	load_game(QUICK_SLOT)


func _on_world_ready(world: Node) -> void:
	_world = world
	_world_arrived.emit(world)


## Closes UI, lifts every pause and stops the clock before a scene change.
func _begin_transition() -> void:
	_transition = true
	UIState.clear()
	TimeManager.clear_pauses()
	TimeManager.running = false
	get_tree().paused = false


## Changes the scene and waits for its EventBus.world_ready. Returns null on failure/timeout.
func _change_world(scene_path: String) -> Node:
	_wait_token += 1
	var token := _wait_token
	var old_world := _world if is_instance_valid(_world) and _world.is_inside_tree() else null
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_warning("[SaveManager] cannot change scene to '%s': %s" % [scene_path, error_string(err)])
		return null
	# A world added without change_scene (e.g. in tests) would survive the scene change
	# and duplicate every save_id – take it out of the tree right away.
	if old_world != null and old_world.is_inside_tree():
		old_world.get_parent().remove_child(old_world)
		old_world.queue_free()
	_world = null
	get_tree().create_timer(world_ready_timeout_sec, true).timeout.connect(func() -> void:
		if token == _wait_token:
			_world_arrived.emit(null))
	var world: Node = await _world_arrived
	if token == _wait_token:
		_wait_token += 1
	if world == null:
		push_warning("[SaveManager] '%s' sent no world_ready within %.1f s" % [scene_path, world_ready_timeout_sec])
	return world


func _world_scene_path() -> String:
	if is_instance_valid(_world) and _world.scene_file_path != "":
		return _world.scene_file_path
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path != "":
		return scene.scene_file_path
	return WORLD_SCENE


## Notification for a failed load: missing, from a newer build (docs/PHASE3_DESIGN.md §3.4) or corrupt.
func _load_error_text(err: Error, slot: int) -> String:
	if err == ERR_FILE_NOT_FOUND:
		return TEXT_NO_SAVE
	if err == ERR_FILE_UNRECOGNIZED and SaveFileIO.is_newer_version(save_dir, slot):
		return TEXT_NEWER_VERSION
	return TEXT_CORRUPT


func _notify(text: String, kind: StringName = &"warning") -> void:
	EventBus.notification_requested.emit(text, kind)

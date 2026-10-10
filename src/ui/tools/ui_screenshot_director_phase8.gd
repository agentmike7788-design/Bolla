extends Node
## QA director, Phase-8 UI (docs/PHASE8_DESIGN.md §7, §11): started by ui_screenshots.gd with --phase8. Starts a new
## game in the real world and stages the Phase-8 states through the public APIs of the systems (and their own
## save_state/load_state where a debug shortcut is needed). The Phase-8 system nodes the world does not have yet
## (W-Welt's builder adds them) are added at runtime from their own scripts; nothing is written to the world files.
## Shots (1280×720, <out>/ui_p8_<name>.jpg), the §11 number in brackets:
##   board (11) · wish_card (05) · bubbles (14) · listen (15) · shop_peddler (17) · journal_kin, journal_village,
##   journal_faces (29) · journal_underlined (30) · map_friedhof, map_dorf (32) · chapter (33) ·
##   fest_lights · hud_p8 · favor · day_summary · register · box_tin · stone_plate
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase8 --out=/abs/dir [--shots=board,chapter]

const SAVE_DIR := "user://ui_shot_saves_p8"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
## A peddler day (day % 6 == 1) after the opening (53, B1) – Jakob works (55 % 7 != 2).
const DAY := 55
const OPEN_DAY := 53
const MORNING := 470
const SYSTEMS: Dictionary[String, Script] = {
	"NpcLife": preload("res://src/systems/npc_life/npc_life.gd"),
	"ChatterRunner": preload("res://src/systems/npc_life/chatter_runner.gd"),
	"Visitors": preload("res://src/systems/visitors/visitors.gd"),
	"GraveCare": preload("res://src/systems/grave_care/grave_care.gd"),
	"Apprentice": preload("res://src/systems/apprentice/apprentice.gd"),
	"Friendship": preload("res://src/systems/friendship/friendship.gd"),
	"Festivals": preload("res://src/systems/festivals/festivals.gd"),
	"Wanderers": preload("res://src/systems/village/wanderers.gd"),
	"NightRobber": preload("res://src/systems/night/night_robber.gd"),
	"NightPaths": preload("res://src/systems/night/night_paths.gd"),
}
const GROUPS: Dictionary[String, StringName] = {"NpcLife": &"npc_life", "ChatterRunner": &"chatter", "Visitors": &"visitors",
		"GraveCare": &"grave_care", "Apprentice": &"apprentice", "Friendship": &"friendship", "Festivals": &"festivals",
		"Wanderers": &"wanderers", "NightRobber": &"night_robber", "NightPaths": &"night_paths"}
const BOX_SCENE := "res://src/entities/apprentice_box/apprentice_box.tscn"
const HIDDEN_AT := Vector3(60.0, -30.0, -200.0)
## plot, name, age, cause, marker, house
const GRAVES: Array = [
	["plot_01", "Hedwig Lamprecht", 64, &"old_age", &"gravestone_simple", &"house_kehr"],
	["plot_02", "Paul Kehr", 44, &"fever", &"wooden_cross", &"house_kehr"],
	["plot_03", "Anna Brandt", 31, &"fever", &"wooden_cross", &"house_brandt"],
	["plot_04", "Grete Sieber", 69, &"old_age", &"gravestone_simple", &"house_sieber"],
	["plot_05", "Jost Ott", 58, &"coach_accident", &"wooden_cross", &"house_ott"],
]
const RELATIONS: Dictionary[StringName, int] = {&"innkeeper": 72, &"smith": 61, &"grocer": 74, &"priest": 70, &"mayor": 58,
		&"surgeon": 44, &"washer": 66, &"oldwoman": 40}
const STEPS: Dictionary[String, int] = {"innkeeper": 2, "priest": 3, "smith": 1, "grocer": 1, "washer": 1}

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _corpses: CorpseManager
var _graveyard: Graveyard
var _life: NpcLife
var _visitors: Visitors
var _care: GraveCare
var _apprentice: Apprentice
var _box: ApprenticeBox
var _friendship: Friendship
var _festivals: Festivals
var _wanderers: Wanderers
var _rel: Relationships
var _anchor: Node3D
var _bounds_were: bool = true


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP8] --out=<dir> missing")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	SaveManager.save_dir = SAVE_DIR
	SaveManager.new_game()
	await EventBus.new_game_started
	await get_tree().process_frame
	TimeManager.running = false
	_world = get_tree().current_scene as WorldRoot
	_ui = _world.get_node(^"UI") as UIRoot
	_player = _world.get_player()
	_player.instant_actions = true
	_corpses = _world.corpse_manager
	_graveyard = _world.graveyard
	_ensure_nodes()
	await get_tree().process_frame
	_stage()
	await get_tree().process_frame
	# In clock order: setting an earlier minute would start the next day (DAY stays a peddler day).
	await _shot("board", _board_shot)
	await _shot("wish_card", _wish_shot)
	await _shot("favor", _favor_shot)
	await _shot("box_tin", _box_shot)
	await _shot("stone_plate", _stone_shot)
	await _shot("journal_village", _journal_village_shot)
	await _shot("journal_faces", _journal_faces_shot)
	await _shot("journal_underlined", _journal_underlined_shot)
	await _shot("register", _register_shot)
	await _shot("day_summary", _day_summary_shot)
	await _shot("map_friedhof", _map_graveyard_shot)
	await _shot("listen", _listen_shot)
	await _shot("journal_kin", _journal_kin_shot)
	await _shot("shop_peddler", _shop_peddler_shot)
	await _shot("fest_lights", _fest_shot)
	await _shot("hud_p8", _hud_shot)
	await _shot("chapter", _chapter_shot)
	await _shot("map_dorf", _map_village_shot)
	await _shot("bubbles", _bubbles_shot)
	for slot: int in [0, 1]:
		SaveManager.delete_save(slot)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
	get_tree().quit()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not shot_name in _only:
		return
	await setup.call()
	_ui.hud.refresh_all()
	_ui.notifications.clear()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join("ui_p8_%s.jpg" % shot_name)
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP8] ", path)
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	_ui.remark_bubbles.clear()
	_ui.chatter_bubbles.clear()
	_ui.fest_banner.hide()
	_ui.region_label.hide()
	if _ui.dialogue_box.is_active():
		_ui.dialogue_box.abort()
	_unframe()
	await get_tree().process_frame


## Missing Phase-8 nodes (a no-op once the builder adds them) – same classes and groups.
func _ensure_nodes() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
	_life = get_tree().get_first_node_in_group(&"npc_life") as NpcLife
	_visitors = get_tree().get_first_node_in_group(&"visitors") as Visitors
	_care = get_tree().get_first_node_in_group(&"grave_care") as GraveCare
	_apprentice = get_tree().get_first_node_in_group(&"apprentice") as Apprentice
	_friendship = get_tree().get_first_node_in_group(&"friendship") as Friendship
	_festivals = get_tree().get_first_node_in_group(&"festivals") as Festivals
	_wanderers = get_tree().get_first_node_in_group(&"wanderers") as Wanderers
	_rel = get_tree().get_first_node_in_group(&"relationships") as Relationships
	_box = get_tree().get_first_node_in_group(ApprenticeBox.GROUP) as ApprenticeBox
	if _box == null:
		_box = (load(BOX_SCENE) as PackedScene).instantiate() as ApprenticeBox
		_box.name = "ShotApprenticeBox"
		_world.add_child(_box)
		_box.global_position = HIDDEN_AT


# --- staging -------------------------------------------------------------------------------------

func _stage() -> void:
	TimeManager.set_time(DAY, MORNING)
	for flag: StringName in [&"cemetery_complete", &"workshop_open", &"names_in_stone_complete", &"p6_intro", &"buildings_open",
			&"roof_and_earth_complete", &"p7_intro", &"linden_granted", &"village_open", &"name_in_village_complete", &"p8_intro",
			&"p8_veit_met", &"consecrated"]:
		GameState.set_flag(flag, true)
	GameState.set_flag(&"village_open_day", OPEN_DAY - 12)
	GameState.stats[&"reputation"] = maxi(GameState.get_stat(&"reputation"), 84)
	var buildings := get_tree().get_first_node_in_group(&"buildings") as Buildings
	if buildings != null and not buildings.is_open():
		buildings.open()
	GameState.set_flag(&"p8_open", true)
	GameState.set_flag(&"p8_open_day", OPEN_DAY)
	if _rel != null:
		for id: StringName in RELATIONS:
			_rel.meet(id)
			_rel.add(id, RELATIONS[id] - _rel.value(id), "Bogen")
	for i: int in GRAVES.size():
		var spec: Array = GRAVES[i]
		_bury(spec[0], spec[1], int(spec[2]), spec[3], spec[4], spec[5], OPEN_DAY - 8 + i)
	_friendship.load_state({"steps": STEPS})
	for npc: String in STEPS:
		for n: int in range(1, STEPS[npc] + 1):
			GameState.set_flag(StringName("friend_%s_%d" % [npc, n]), true)
	_apprentice.load_state({"hired": true, "hire_day": OPEN_DAY, "levels": {"rake": 2, "weed": 1, "water": 1}, "jobs": {"rake": 14, "weed": 8, "water": 3},
			"board": [{"task": "rake", "area": "yard"}, {"task": "weed", "area": "all"}, {"task": "water", "area": "wished"}], "morale": 4, "unpaid": 0})
	_box.coins = 9
	_wanderers.load_state({"alms": 2, "alms_day": DAY - 1, "listened": false, "talks": {"beggar": 2}})
	_visitors.add_goodwill(&"kin_kehr", 2)
	_visitors.add_goodwill(&"kin_ott", -2)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()
	_ui.reward_card.visible = false


func _bury(plot_id: String, name: String, age: int, cause: StringName, marker: StringName, house: StringName, day: int) -> void:
	if _graveyard.get_grave(plot_id) == null or _graveyard.get_grave(plot_id).state != GraveRecord.State.EMPTY:
		return
	var plot := _world.get_node_by_layout_id(plot_id) as Node3D
	var rec := CorpseRecord.new()
	rec.display_name = name
	rec.age = age
	rec.cause_id = cause
	var spawned := _corpses.spawn_corpse(rec, plot.global_transform, &"ground")
	spawned.arrival_total_minutes = (day - 1) * 1440 + 460
	spawned.examined = true
	spawned.exam_done.assign(CorpseRecord.STEPS)
	if spawned.needs_valuables_decision():
		spawned.valuables_decision = CorpseRecord.DECISION_LEFT
	spawned.washed = true
	spawned.shrouded = true
	spawned.dress = CorpseRecord.DRESS_SHROUD
	spawned.kin_house = house
	_graveyard.dig(plot_id)
	_graveyard.bury(plot_id, spawned.id)
	spawned.buried_day = day
	_graveyard.get_grave(plot_id).completed_day = day
	var purse := Inventory.new()
	purse.add_item(marker, 1)
	_graveyard.place_marker(plot_id, marker, purse)
	purse.free()


func _pack(items: Dictionary) -> void:
	var inv := _player.inventory
	inv.remove_item(&"coin", inv.count(&"coin"))
	for slot: Dictionary in inv.get_slots():
		if not slot.is_empty():
			inv.remove_item(StringName(slot.id), int(slot.amount))
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))


## A visit of `kin` at `graves` today in `phase` (the plan entry with the fixture key "phase").
func _visit(kin: StringName, graves: Array, phase: StringName) -> String:
	var state := _visitors.save_state()
	var plan: Array = state.get("plan", []) if int(state.get("plan_day", -1)) == TimeManager.day else []
	var id := "v_%d_s%d" % [TimeManager.day, plan.size() + 1]
	plan.append({"visit_id": id, "kin_id": String(kin), "graves": graves, "slot": TimeManager.minute_of_day - 20,
			"start": TimeManager.minute_of_day - 20, "travel": 13, "day": TimeManager.day, "flowers": true, "laid": 1, "viewed": 1,
			"waits": true, "tip": 2, "ended": false, "noise": false, "offered": "", "phase": String(phase)})
	state["plan"] = plan
	state["plan_day"] = TimeManager.day
	state["plan_open"] = true
	_visitors.load_state(state)
	return id


func _wish(kind: String, grave: String, kin: String, state_name: String, template: String) -> void:
	var state := _visitors.save_state()
	var wishes: Array = state.get("wishes", [])
	var next := int(state.get("next_wish", 1))
	wishes.append({"wish_id": "w_%04d" % next, "kind": kind, "grave_id": grave, "kin_id": kin, "state": state_name, "day": TimeManager.day,
			"candle_seen": false, "template": template})
	state["wishes"] = wishes
	state["next_wish"] = next + 1
	_visitors.load_state(state)


func _frame(focus: Vector3, distance: float) -> void:
	var rig := _world.get_node(^"CameraRig")
	if _anchor == null:
		_anchor = Node3D.new()
		_anchor.name = "ShotAnchor"
		_world.add_child(_anchor)
	_anchor.global_position = Vector3(focus.x, 0.0, focus.z)
	if rig.get(&"target") != _anchor:
		_bounds_were = bool(rig.get(&"bounds_enabled"))
	rig.set("bounds_enabled", false)
	rig.set("zoom_min", minf(float(rig.get(&"zoom_min")), 5.0))
	rig.set("target", _anchor)
	rig.call(&"set_distance", distance)
	rig.call(&"snap")


func _unframe() -> void:
	if _anchor == null:
		return
	var rig := _world.get_node(^"CameraRig")
	rig.set("bounds_enabled", _bounds_were)
	rig.set("target", _player)
	rig.call(&"set_distance", 22.0)
	rig.call(&"snap")


func _place_player(at: Vector3, facing: float = PI) -> void:
	at.y = _world.ground_height(Vector2(at.x, at.z))
	_player.global_transform = Transform3D(Basis(Vector3.UP, facing), at)
	_player.velocity = Vector3.ZERO
	_world.get_node(^"CameraRig").call(&"snap")


func _to_graveyard() -> void:
	if _player.region_id == &"graveyard":
		return
	if _player.in_interior:
		HutPortal.arrive(_player, Transform3D(Basis.IDENTITY, _player.global_position), false)
	var gate := _world.get_waypoint(&"dropoff")
	RegionTravel.arrive(_player, &"graveyard", Transform3D(Basis(Vector3.UP, PI), gate + Vector3(1.2, 0.0, 2.6)), 0)


func _at_gate() -> void:
	if _player.in_interior:
		HutPortal.arrive(_player, Transform3D(Basis.IDENTITY, _world.get_waypoint(&"dropoff") + Vector3(0.0, 0.0, -2.0)), false)
	_to_graveyard()
	_place_player(_world.get_waypoint(&"dropoff") + Vector3(1.2, 0.0, 2.6))


func _at_plot(plot_id: String) -> void:
	_at_gate()
	var plot := _world.get_node_by_layout_id(plot_id) as Node3D
	if plot != null:
		_place_player(plot.global_position + Vector3(1.4, 0.0, 1.8), deg_to_rad(210.0))


func _in_village(local: Vector2, facing: float = PI) -> void:
	_unframe()
	if _player.in_interior:
		HutPortal.arrive(_player, Transform3D(Basis.IDENTITY, _player.global_position), false)
	var v := RegionRoot.find(get_tree(), &"village")
	var at := v.global_position + Vector3(local.x, 0.0, local.y)
	at.y = v.ground_height(Vector2(at.x, at.z))
	RegionTravel.arrive(_player, &"village", Transform3D(Basis(Vector3.UP, facing), at), 0)
	for npc: Node in get_tree().get_nodes_in_group(&"npc"):
		if npc.has_method(&"refresh"):
			npc.call(&"refresh")
	if _rel != null:
		for id: StringName in DialogueActions.VILLAGERS:
			_rel.remark(id)
	_ui.remark_bubbles.clear()
	_world.get_node(^"CameraRig").call(&"snap")
	await get_tree().process_frame


# --- shots -----------------------------------------------------------------------------------------

## p8_11: the chalk board with three lines, the chalk strokes and the tin.
func _board_shot() -> void:
	_at_time(480)
	_at_gate()
	_pack({&"coin": 14})
	var board := _find(func(n: Node) -> bool: return n is ApprenticeBoard) as ApprenticeBoard
	var ctx := board.context() if board != null else {"apprentice": _apprentice, "box": _box}
	ctx["inventory"] = _player.inventory
	ctx["player"] = _player
	_ui.open_panel(&"apprentice_board", ctx)
	await get_tree().process_frame


## p8_05: Martha Kehr's wish at her husband's grave.
func _wish_shot() -> void:
	_at_time(600)
	_at_plot("plot_02")
	var visit := _visit(&"kin_kehr", ["plot_02", "plot_01"], &"waiting")
	var offer := _visitors.offer_wish(visit)
	if offer.is_empty():
		_wish("flowers", "plot_02", "kin_kehr", "offered", "w_flowers")
		var data := Database.wish(&"w_flowers") as WishData
		offer = {"wish_id": str(_visitors.open_wishes().back().wish_id), "kind": &"flowers", "grave_id": "plot_02",
				"text": data.ask_text if data != null else ""}
	_ui.open_panel(&"wish_card", {"offer": offer, "kin_id": &"kin_kehr", "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


## Lenz' Fürbitte: whom to pray for.
func _favor_shot() -> void:
	_at_gate()
	_ui.open_panel(&"favor", {"npc_id": &"priest", "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


func _box_shot() -> void:
	_at_gate()
	_pack({&"coin": 11, &"grave_candle": 4})
	_box.storage.add_item(&"apprentice_rake", 1)
	_box.storage.add_item(&"watering_can", 1)
	_box.storage.add_item(&"grave_candle", 6)
	_ui.open_panel(&"chest", {"storage": _box.storage, "inventory": _player.inventory, "chest": _box, "coins_box": _box})
	await get_tree().process_frame


## The memorial plate at the mason's bench (after Rosine 2).
func _stone_shot() -> void:
	_at_gate()
	_pack({&"coin": 6, &"gold_leaf": 1, &"ink": 2, &"workstone": 2, &"stone": 4})
	var bench := _find(func(n: Node) -> bool: return n is Workbench and (n as Workbench).station == &"mason") as Workbench
	_ui.open_panel(&"stone_design", {"inventory": _player.inventory, "player": _player, "bench": bench, "workbench": bench, "station": &"mason"})
	await get_tree().process_frame


func _journal_kin_shot() -> void:
	_at_time(645)
	_at_gate()
	_wish("flowers", "plot_02", "kin_kehr", "accepted", "w_flowers")
	_wish("candle", "plot_03", "kin_brandt", "accepted", "w_candle")
	var now := TimeManager.total_minutes()
	_care.load_state(_care.save_state().merged({"flowers": {"plot_02": {"planted": now - 300, "watered": now - 300, "wreath": false}}}, true))
	var state := _visitors.save_state()
	state["last_visit"] = {"plot_01": DAY - 2, "plot_02": DAY - 2, "plot_03": DAY - 4, "plot_04": DAY - 5}
	_visitors.load_state(state)
	_ui.open_journal(&"kin")
	await get_tree().process_frame


func _journal_village_shot() -> void:
	_at_gate()
	_life.set_mood(&"priest", &"low")
	_life.set_mood(&"grocer", &"cheerful")
	_life.set_mood(&"smith", &"cross")
	_ui.open_journal(&"village")
	await get_tree().process_frame


func _journal_faces_shot() -> void:
	_at_gate()
	_ui.open_journal(&"village")
	var panel := _ui.get_panel(&"journal") as JournalPanel
	panel.toggle_village_sheet()
	await get_tree().process_frame


## p8_30: „Der unterstrichene Name" – the required group and two of four.
func _journal_underlined_shot() -> void:
	_at_gate()
	var journal := get_tree().get_first_node_in_group(&"journal") as JournalManager
	for id: StringName in [&"c_n_veit", &"c_n_kladde", &"c_n_quast_visit"]:
		journal.add_clue(id, "", true)
	_ui.notifications.clear()
	_ui.open_journal(&"clues")
	var panel := _ui.get_panel(&"journal") as JournalPanel
	for id: StringName in [&"c_n_veit", &"c_n_kladde", &"c_n_quast_visit"]:
		panel.toggle_clue(id)
	await get_tree().process_frame


func _register_shot() -> void:
	_at_gate()
	var now := TimeManager.total_minutes()
	_care.load_state(_care.save_state().merged({"flowers": {"plot_01": {"planted": now, "watered": now, "wreath": false}},
			"mortsafes": {"plot_05": now - 2 * 1440}}, true))
	_care.light_free("plot_04")
	var entries: Array = Desk.register_entries(_graveyard, _corpses)
	var score := get_tree().get_first_node_in_group(&"cemetery_score") as CemeteryScore
	_ui.open_panel(&"grave_register", {"entries": entries, "total": score.total() if score != null else _graveyard.total_quality(),
			"rating": score.rating() if score != null else _graveyard.rating()})
	await get_tree().process_frame


func _day_summary_shot() -> void:
	_at_gate()
	_ui.day_log8.reset()
	_ui.day_log.reset()
	EventBus.grave_viewed.emit("plot_02", &"kin_kehr", &"kept")
	EventBus.grave_viewed.emit("plot_03", &"kin_brandt", &"bare")
	EventBus.wish_changed.emit("w_0003", &"done")
	EventBus.wish_changed.emit("w_0004", &"offered")
	EventBus.payment_received.emit(2, "Trinkgeld")
	for i: int in 9:
		EventBus.apprentice_job_done.emit(&"rake", "plot_0%d" % (i % 5 + 1), false)
	EventBus.apprentice_job_done.emit(&"weed", "plot_04", true)
	EventBus.coins_spent.emit(3, &"apprentice")
	EventBus.robber_event.emit(&"seen", "plot_05")
	EventBus.robber_event.emit(&"fled", "plot_05")
	_ui.open_panel(&"day_summary", {"day": TimeManager.day, "burials_today": 0, "coins_today": 2, "total": 164, "rating": &"venerable"})
	await get_tree().process_frame


## p8_32 (graveyard): a visitor, Jakob at work, a wish, coins on the stone, a disturbed grave.
func _map_graveyard_shot() -> void:
	_at_time(610)
	_at_gate()
	_visit(&"kin_kehr", ["plot_02"], &"mourning")
	_visit(&"kin_sieber", ["plot_04"], &"mourning")
	_wish("candle", "plot_03", "kin_brandt", "accepted", "w_candle")
	var state := _visitors.save_state()
	state["tips_on_stone"] = {"plot_01": [2, "kin_kehr"]}
	_visitors.load_state(state)
	_care.set_disturbed("plot_05")
	_jakob_working()
	_place_player(Vector3(-3.4, 0.0, -1.2), deg_to_rad(60.0))
	_ui.open_map()
	await get_tree().process_frame


## Jakob's plan of today with a running place (the planner, else one staged place at plot_01).
func _jakob_working() -> void:
	var state := _apprentice.save_state()
	if (state.get("plan", []) as Array).is_empty() or int(state.get("plan_day", -1)) != TimeManager.day:
		state["plan_day"] = TimeManager.day
		state["progress"] = 0
		state["plan"] = [{"task": "rake", "spot_id": "", "grave_id": "plot_01", "start": TimeManager.minute_of_day - 5,
				"walk_minutes": 0, "work_start": TimeManager.minute_of_day - 5, "work_minutes": 15, "end": TimeManager.minute_of_day + 10,
				"path": [], "mistake": false, "kind": "leaves", "consumes": ""}]
		_apprentice.load_state(state)


## p8_14: Theres and Liesel at the well (16:15 on DAY + 2, when both stand there), two bubbles – run last.
func _bubbles_shot() -> void:
	TimeManager.set_time(DAY + 2, 975)
	await _in_village(Vector2(1.6, 0.4), deg_to_rad(200.0))
	var theres := _ui.chatter_bubbles.find_npc(&"grocer")
	var liesel := _ui.chatter_bubbles.find_npc(&"washer")
	if theres != null:
		var focus := theres.global_position if liesel == null else theres.global_position.lerp(liesel.global_position, 0.5)
		_frame(focus, 11.0)
	await get_tree().process_frame
	var data := Database.chatter(&"ch_well_spin") as ChatterData
	EventBus.chatter_line.emit(&"ch_well_spin", &"grocer", data.lines[0] if data != null else "…")
	EventBus.chatter_line.emit(&"ch_well_spin", &"washer", data.lines[1] if data != null else "…")
	for id: StringName in _ui.chatter_bubbles.bubbles:
		_ui.chatter_bubbles.bubbles[id].left = 600.0


## p8_15: Lenz low at the church door, the dialogue with „[Zuhören]".
func _listen_shot() -> void:
	_at_time(640)
	await _in_village(Vector2(-6.0, -10.0), PI)
	_life.set_mood(&"priest", &"low")
	var lenz := _ui.chatter_bubbles.find_npc(&"priest")
	if lenz != null:
		_frame(lenz.global_position, 9.0)
		_ui.open_dialogue(&"v_priest", lenz)
		# The greeting first, then the menu with „[Zuhören]".
		for i: int in 2:
			if _ui.dialogue_box.is_active() and not Array(_ui.dialogue_box.choice_texts()).any(func(t: String) -> bool: return t.begins_with("[Zuhören]")):
				_ui.dialogue_box.choose(0)
	await get_tree().process_frame


## p8_17: Hanne at the well, her shop panel.
func _shop_peddler_shot() -> void:
	_at_time(660)
	await _in_village(Vector2(1.6, 0.4), deg_to_rad(200.0))
	_pack({&"coin": 17, &"herbs": 4, &"elderberries": 6})
	_ui.open_panel(&"shop", {"shop_id": &"peddler", "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


## The festival card of the Lichtgang, the candles counted.
func _fest_shot() -> void:
	_at_time(880)
	_lights_today()
	_care.light_free("plot_01")
	_care.light_free("plot_02")
	_at_gate()
	_ui.open_panel(&"fest", {})
	await get_tree().process_frame


## The HUD on the Lichtgang afternoon: the banner and „Kein Grab ohne Licht: 3/5".
func _hud_shot() -> void:
	_lights_today()
	_at_time(899)
	_care.light_free("plot_03")
	_at_gate()
	_place_player(Vector3(-2.6, 0.0, -2.4), deg_to_rad(120.0))
	_at_time(900)
	_ui.fest_banner._on_time_tick(DAY, 900)
	_ui.fest_banner.call(&"_hold_for_shot")
	await get_tree().process_frame


func _lights_today() -> void:
	var state := _festivals.save_state()
	var days: Dictionary = state.get("days", {})
	days["fest_lights"] = TimeManager.day
	state["days"] = days
	_festivals.load_state(state)
	GameState.set_flag(&"fest_lights_day", TimeManager.day)


## p8_33: the chapter panel „Wer heraufkommt" as at the end of arc A (§1.4).
func _chapter_shot() -> void:
	_at_gate()
	var context := _life.chapter_context()
	context["days_open"] = 9
	context["visits_seen"] = 14
	context["visits_by_kin"] = {"kin_kehr": 4, "kin_brandt": 3, "kin_sieber": 3, "kin_ott": 2, "kin_washer": 2}
	context["wishes_done"] = 7
	context["wishes_failed"] = 1
	context["tips_coins"] = 19
	context["apprentice_levels"] = {"rake": 2, "weed": 2, "water": 1, "candle": 1}
	context["apprentice_jobs"] = 96
	context["apprentice_mistakes"] = 3
	context["apprentice_wage"] = 21
	context["favors_used"] = 2
	context["favors_returned"] = 2
	context["dances"] = 2
	context["robber_encounters"] = 2
	context["night_visits_observed"] = 3
	context["steps_by_npc"] = {"innkeeper": 3, "smith": 2, "grocer": 1, "priest": 3, "mayor": 2, "surgeon": 1, "washer": 2}
	context["lights_result"] = &"lights_all"
	context["robber_fate"] = &"let_go"
	context["insights"] = ["i_underlined"]
	_ui.open_panel(&"slice_summary", context)
	await get_tree().process_frame


## p8_32 (village): the sick light at the Otts (after c_n_veit) and Hanne – run last (moves p8_open_day).
func _map_village_shot() -> void:
	var journal := get_tree().get_first_node_in_group(&"journal") as JournalManager
	journal.add_clue(&"c_n_veit", "", true)
	var path := Database.night_path(&"np_ott") as NightPathData
	if path != null:
		GameState.set_flag(&"p8_open_day", DAY - path.start_offset)
	_at_time(1330)
	await _in_village(Vector2(1.6, 0.4), deg_to_rad(200.0))
	_ui.notifications.clear()
	_ui.open_map()
	await get_tree().process_frame


## The clock forward to `minute` of DAY (never back – that would be the next day).
func _at_time(minute: int) -> void:
	if TimeManager.day == DAY and TimeManager.minute_of_day < minute:
		TimeManager.set_time(DAY, minute)


func _find(pred: Callable) -> Node:
	for node: Node in get_tree().root.find_children("*", "", true, false):
		if pred.call(node):
			return node
	return null

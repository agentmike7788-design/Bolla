extends Node
## QA director, Phase-7 UI (docs/PHASE7_DESIGN.md §7, §11): started by ui_screenshots.gd with --phase7.
## Starts a new game in the real graveyard world and stages every state through the public APIs of the
## systems. The Phase-7 systems the world does not have yet (Systems/Village, Relationships,
## VillageShops, Orders, Specimens, Lectures, Deductions; the pult's cold box and the collection shelf –
## W-Welt's builder adds them) are added at runtime from their own scripts / scenes; nothing is written to
## the world files. Without the village scene (W-Welt, W2) the village panels are shot over the
## graveyard and Rosine's remark over a stand-in of her model at the gate – the final series with the
## village is the lead's / QA's (§11).
## Shots (1280×720, <out>/ui_<name>.jpg), the §11 number in brackets:
##   organs_armed (17) · organ_veil (18) · shop (19) · anatomist (20) · board (21) · journal_village,
##   journal_orders (22) · remark (23) · insight_deathbook (27) · chapter_name_in_village (28) ·
##   collection (29) · lecture_veil (30) · deduction (31) · pult_medicines (32) · organs_eyes (33) ·
##   gift · lecture · hud_village · day_summary · register
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase7 --out=/abs/dir [--shots=shop,gift]

const SAVE_DIR := "user://ui_shot_saves_p7"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY := 42
const MORNING := 600
const SYSTEMS: Dictionary[String, Script] = {
	"Village": preload("res://src/systems/village/village.gd"),
	"Relationships": preload("res://src/systems/village/relationships.gd"),
	"VillageShops": preload("res://src/systems/village/village_shops.gd"),
	"Orders": preload("res://src/systems/village/orders.gd"),
	"Specimens": preload("res://src/systems/anatomy/specimens.gd"),
	"Lectures": preload("res://src/systems/anatomy/lectures.gd"),
	"Deductions": preload("res://src/systems/anatomy/deductions.gd"),
}
const GROUPS: Dictionary[String, StringName] = {"Village": &"village", "Relationships": &"relationships",
		"VillageShops": &"village_shops", "Orders": &"orders", "Specimens": &"specimens", "Lectures": &"lectures",
		"Deductions": &"deductions"}
const TABLE_SCENE := "res://src/entities/morgue_table/morgue_table.tscn"
const STORE_SCENE := "res://src/entities/pult_store/pult_store.tscn"
const SHELF_SCENE := "res://src/entities/collection_shelf/collection_shelf.tscn"
const INNKEEPER_MODEL := "res://assets/models/characters/ph_chr_v_innkeeper.glb"
const HIDDEN_AT := Vector3(60.0, -30.0, -200.0)
## plot, name, age, cause, marker
const GRAVES: Array = [
	["plot_01", "Egbert Kornblum", 71, &"fever", &"gravestone_simple"],
	["plot_02", "Hedwig Rabenstein", 67, &"drowned_millpond", &"gravestone_simple"],
	["plot_03", "Konrad Bleich", 29, &"coach_accident", &"wooden_cross"],
	["plot_04", "Ida Wendt", 48, &"fever", &"wooden_cross"],
]
## Relationship values of the staged arc (§1.4, around B9).
const RELATIONS: Dictionary[StringName, int] = {&"innkeeper": 46, &"smith": 38, &"grocer": 72, &"priest": 31, &"mayor": 52,
		&"surgeon": 28, &"washer": 12}

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _corpses: CorpseManager
var _graveyard: Graveyard
var _buildings: Buildings
var _specimens: Specimens
var _rel: Relationships
var _orders: Orders
var _lectures: Lectures
var _deductions: Deductions
var _village: Village
var _crypt_table: MorgueTable
var _store: PultStore
var _shelf: CollectionShelf
var _anchor: Node3D
var _bounds_were: bool = true


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP7] --out=<dir> missing")
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
	await _shot("hud_village", _hud_village_shot)
	await _shot("shop", _shop_shot)
	await _shot("gift", _gift_shot)
	await _shot("board", _board_shot)
	await _shot("remark", _remark_shot)
	await _shot("journal_village", _journal_village_shot)
	await _shot("journal_orders", _journal_orders_shot)
	await _shot("organs_armed", _organs_armed_shot)
	await _shot("organs_eyes", _organs_eyes_shot)
	await _shot("organ_veil", _organ_veil_shot)
	await _shot("anatomist", _anatomist_shot)
	await _shot("pult_medicines", _pult_shot)
	await _shot("collection", _collection_shot)
	await _shot("deduction", _deduction_shot)
	await _shot("lecture", _lecture_shot)
	await _shot("lecture_veil", _lecture_veil_shot)
	await _shot("insight_deathbook", _insight_shot)
	await _shot("register", _register_shot)
	await _shot("day_summary", _day_summary_shot)
	await _shot("chapter_name_in_village", _chapter_shot)
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
	var path := _out.path_join("ui_%s.jpg" % shot_name)
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP7] ", path)
	await _finish_actions()
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	_ui.veil.close()
	_ui.remark_bubbles.clear()
	_ui.region_label.hide()
	_unframe()
	await get_tree().process_frame


## Missing Phase-7 nodes (a no-op once the builder adds them) – same classes, scenes and groups.
func _ensure_nodes() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
	_village = get_tree().get_first_node_in_group(&"village") as Village
	_rel = get_tree().get_first_node_in_group(&"relationships") as Relationships
	_orders = get_tree().get_first_node_in_group(&"orders") as Orders
	_specimens = get_tree().get_first_node_in_group(&"specimens") as Specimens
	_lectures = get_tree().get_first_node_in_group(&"lectures") as Lectures
	_deductions = get_tree().get_first_node_in_group(&"deductions") as Deductions
	_buildings = get_tree().get_first_node_in_group(&"buildings") as Buildings
	for node: Node in get_tree().get_nodes_in_group(&"morgue_table"):
		if node.get(&"room") == &"crypt":
			_crypt_table = node as MorgueTable
	if _crypt_table == null:
		_crypt_table = (load(TABLE_SCENE) as PackedScene).instantiate() as MorgueTable
		_crypt_table.name = "ShotCryptTable"
		_crypt_table.room = &"crypt"
		_crypt_table.requires_level = 1
		_world.add_child(_crypt_table)
		_crypt_table.global_position = HIDDEN_AT
	_store = PultPanel.find_store(get_tree())
	if _store == null:
		_store = (load(STORE_SCENE) as PackedScene).instantiate() as PultStore
		_store.name = "ShotPultStore"
		_world.add_child(_store)
		_store.global_position = HIDDEN_AT + Vector3(2.0, 0.0, 0.0)
	for node: Node in get_tree().get_nodes_in_group(&"saveable"):
		if node is CollectionShelf:
			_shelf = node as CollectionShelf
	if _shelf == null:
		_shelf = (load(SHELF_SCENE) as PackedScene).instantiate() as CollectionShelf
		_shelf.name = "ShotCollectionShelf"
		_world.add_child(_shelf)
		_shelf.global_position = HIDDEN_AT + Vector3(4.0, 0.0, 0.0)


# --- staging (real systems only) ----------------------------------------------------------

func _stage() -> void:
	TimeManager.set_time(DAY, MORNING)
	for flag: StringName in [&"cemetery_complete", &"workshop_open", &"names_in_stone_complete", &"p6_intro", &"buildings_open",
			&"roof_and_earth_complete", &"p7_intro", &"linden_granted"]:
		GameState.set_flag(flag, true)
	if not _buildings.is_open():
		_buildings.open()
	_levels({&"crypt": 2, &"chapel": 2, &"shed": 2})
	_village.open()
	GameState.set_flag(&"village_open_day", DAY - 2)
	GameState.add_stat(&"village_trips", 3)
	GameState.stats[&"reputation"] = maxi(GameState.get_stat(&"reputation"), 62)
	for id: StringName in RELATIONS:
		_rel.meet(id)
		_rel.add(id, RELATIONS[id] - _rel.value(id), "Bogen")
	for i: int in GRAVES.size():
		var spec: Array = GRAVES[i]
		_bury(spec[0], spec[1], int(spec[2]), spec[3], spec[4], 30 + i)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()
	_ui.reward_card.visible = false


func _bury(plot_id: String, name: String, age: int, cause: StringName, marker: StringName, day: int) -> void:
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
	_graveyard.dig(plot_id)
	_graveyard.bury(plot_id, spawned.id)
	var purse := Inventory.new()
	purse.add_item(marker, 1)
	_graveyard.place_marker(plot_id, marker, purse)
	purse.free()


func _levels(levels: Dictionary) -> void:
	var state := _buildings.save_state()
	var saved: Dictionary = state.get("levels", {})
	for id: Variant in levels:
		saved[String(id)] = int(levels[id])
	state["levels"] = saved
	_buildings.load_state(state)
	_buildings.apply_levels()


func _pack(items: Dictionary) -> void:
	var inv := _player.inventory
	inv.remove_item(&"coin", inv.count(&"coin"))
	for uid: String in inv.uids():
		inv.remove_uid(uid)
	for slot: Dictionary in inv.get_slots():
		if not slot.is_empty():
			inv.remove_item(StringName(slot.id), int(slot.amount))
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))


## A dead of today on the crypt table (crypt 2), fresh, undressed.
func _on_table(name: String, age: int, cause: StringName, hidden: StringName = &"") -> CorpseRecord:
	_crypt_table.refresh_active()
	for r: CorpseRecord in _corpses.records():
		if r.location == CorpseRecord.LOCATION_TABLE:
			_corpses.put_down(r.id, CorpseRecord.LOCATION_GROUND, Transform3D(Basis.IDENTITY, HIDDEN_AT + Vector3(6.0, 0.0, 0.0)))
	var rec := CorpseRecord.new()
	rec.display_name = name
	rec.age = age
	rec.cause_id = cause
	var spawned := _corpses.spawn_corpse(rec, _crypt_table.slot_transform(), &"ground")
	spawned.hidden_cause = hidden
	spawned.freshness = 0.92
	_corpses.put_down(spawned.id, CorpseRecord.LOCATION_TABLE, _crypt_table.slot_transform(), null, &"crypt")
	return spawned


## A real piece of `record` into the pack (Specimens.harvest takes the inputs it needs).
func _piece(record: CorpseRecord, organ: StringName, container: StringName) -> String:
	var inv := _player.inventory
	var inputs := SpecimenRules.harvest_inputs(organ, container, _specimens.get_config())
	for id: StringName in inputs:
		inv.add_item(id, inputs[id])
	return _specimens.harvest(record.id, organ, container, inv)


func _anatomy() -> void:
	GameState.set_flag(&"anatomy_known", true)
	GameState.set_flag(&"quast_recipes", true)
	for t: StringName in _specimens.get_config().basic_teachings:
		_lectures.learn(t)


## Camera on `focus` (ground) at `distance` instead of the player.
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


func _at_gate() -> void:
	_out_of_rooms()
	var gate := _world.get_waypoint(&"dropoff")
	_place_player(gate + Vector3(1.2, 0.0, 2.6))


func _in_crypt() -> void:
	_unframe()
	var room := InteriorRoom.find(get_tree(), &"crypt")
	if room == null:
		push_error("[UiShotsP7] no crypt room")
		return
	HutPortal.arrive(_player, room.spawn_transform(), true, &"crypt")
	if _crypt_table.is_inside_tree():
		var at := _crypt_table.global_position + room.global_basis.z * 1.1
		at.y = room.global_position.y
		_player.global_transform = Transform3D(Basis(Vector3.UP, PI), at)
	_world.get_node(^"CameraRig").call(&"snap")
	await get_tree().process_frame


func _out_of_rooms() -> void:
	if _player.in_interior:
		HutPortal.arrive(_player, Transform3D(Basis.IDENTITY, _world.get_waypoint(&"dropoff") + Vector3(0.0, 0.0, -2.0)), false)


## A running TimedAction (veil shots) holds still for the picture: the player stops processing once
## the veil is down; afterwards it runs to its end.
func _hold_action(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout
	_player.process_mode = Node.PROCESS_MODE_DISABLED


func _finish_actions() -> void:
	_player.process_mode = Node.PROCESS_MODE_INHERIT
	var waited := 0.0
	while _player.is_busy() and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_player.instant_actions = true


# --- village shots ------------------------------------------------------------------------------

## Arriving: the place name bottom left and the objective line of the arc.
func _hud_village_shot() -> void:
	_at_gate()
	TimeManager.set_time(DAY, 640)
	GameState.set_flag(&"linden_granted", false)
	_ui.hud.refresh_all()
	_ui.region_label.show_region(&"village")
	# Hold the name for the picture (it fades after 3 s; the capture settles longer under lavapipe).
	_ui.region_label.call(&"_hold_for_shot")
	await get_tree().process_frame
	GameState.set_flag(&"linden_granted", true)


## Theres at her shop window, „Befreundet": gold leaf, one coin less from 4 up.
func _shop_shot() -> void:
	_at_gate()
	TimeManager.set_time(DAY, 600)
	_pack({&"coin": 23, &"herbs": 6, &"elderberries": 9, &"yarn": 3, &"shovel_iron": 1})
	_ui.open_panel(&"shop", {"shop_id": &"grocer", "inventory": _player.inventory, "player": _player})
	var panel := _ui.get_panel(&"shop") as ShopPanel
	panel.buy(&"prep_jar", 1)
	await get_tree().process_frame


func _gift_shot() -> void:
	_at_gate()
	_pack({&"coin": 12, &"honey_cake": 2, &"herb_bundle": 1, &"wood": 4, &"elderberries": 3, &"shovel_iron": 1})
	GameState.set_flag(&"gifts_known_innkeeper", true)
	_ui.open_panel(&"gift", {"npc_id": &"innkeeper", "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


func _board_shot() -> void:
	_at_gate()
	_pack({&"coin": 18, &"wood": 6, &"stone": 3, &"shovel_iron": 1})
	_orders.apply_morning(TimeManager.day)
	var ids: Array[StringName] = _orders.board()
	if ids.size() < 2:
		ids = [&"ob_wood", &"ob_herbs"]
	_ui.open_panel(&"orders", {"board": true, "orders": ids, "header": VillageBoard.header_text(), "inventory": _player.inventory,
			"player": _player})
	await get_tree().process_frame


## Rosine's remark – over a stand-in of her model at the gate (the village scene is W-Welt's).
func _remark_shot() -> void:
	_at_gate()
	TimeManager.set_time(DAY, 680)
	var stand := (preload("res://src/ui/tools/ui_shot_npc_stand_in.gd") as GDScript).new() as Node3D
	stand.name = "ShotRosine"
	stand.set(&"npc_id", &"innkeeper")
	_world.add_child(stand)
	var model := (load(INNKEEPER_MODEL) as PackedScene).instantiate() as Node3D
	stand.add_child(model)
	var at := _player.global_position + Vector3(-1.6, 0.0, -0.6)
	at.y = _world.ground_height(Vector2(at.x, at.z))
	stand.global_transform = Transform3D(Basis(Vector3.UP, 0.6), at)
	_frame(at + Vector3(0.8, 0.0, 0.0), 9.0)
	await get_tree().process_frame
	EventBus.villager_remarked.emit(&"innkeeper", "Wackernagel hat für dich einen Stuhl am Ofen frei. Den kriegt sonst nur der Pfarrer.")


func _journal_village_shot() -> void:
	_at_gate()
	GameState.set_flag(&"gifts_known_grocer", true)
	_rel.note_talk(&"grocer")
	_ui.open_journal(&"people")
	var panel := _ui.get_panel(&"journal") as JournalPanel
	panel.show_page(&"village")
	await get_tree().process_frame


func _journal_orders_shot() -> void:
	_at_gate()
	_pack({&"coin": 18, &"elderberries": 5, &"charcoal": 6, &"shovel_iron": 1})
	for id: StringName in [&"o_fenner_well", &"o_rosine_berries", &"o_esch_charcoal"]:
		_orders.accept(id)
	_orders.complete(&"o_esch_charcoal")
	_ui.open_journal(&"people")
	var panel := _ui.get_panel(&"journal") as JournalPanel
	panel.show_page(&"orders")
	await get_tree().process_frame


# --- anatomy shots --------------------------------------------------------------------------------

func _organ_pack() -> void:
	_pack({&"coin": 14, &"anatomy_case": 1, &"prep_jar": 3, &"prep_jar_small": 1, &"spirits": 4, &"linen": 3, &"beeswax": 2,
			&"shovel_iron": 1})


## The specimen card, the heart row armed („Wirklich? Noch einmal drücken.").
func _organs_armed_shot() -> void:
	_anatomy()
	_organ_pack()
	var dead := _on_table("Hedwig Lamprecht", 58, &"fever")
	await _in_crypt()
	_ui.open_panel(&"corpse_exam", {"corpse_id": dead.id, "table": _crypt_table, "player": _player})
	var panel := _ui.get_panel(&"corpse_exam") as CorpseExamPanel
	panel.tabs.select_tab(CorpseExamTabs.TAB_ORGANS)
	panel.tabs.confirm_seconds = 60.0
	panel.tabs.press_organ(&"heart")
	await get_tree().process_frame


## Two of three taken, the eyes armed with the longer line.
func _organs_eyes_shot() -> void:
	_anatomy()
	_organ_pack()
	var dead := _on_table("Jakob Brandt", 63, &"moor_cold")
	var care := get_tree().get_first_node_in_group(&"corpse_care") as CorpseCare
	care.harvest_organ(dead.id, &"heart", SpecimenRecord.CONTAINER_JAR, _player.inventory)
	care.harvest_organ(dead.id, &"lung", SpecimenRecord.CONTAINER_BUNDLE, _player.inventory)
	_ui.notifications.clear()
	await _in_crypt()
	_ui.open_panel(&"corpse_exam", {"corpse_id": dead.id, "table": _crypt_table, "player": _player})
	var panel := _ui.get_panel(&"corpse_exam") as CorpseExamPanel
	panel.tabs.select_tab(CorpseExamTabs.TAB_ORGANS)
	panel.tabs.confirm_seconds = 60.0
	panel.tabs.press_organ(&"eyes")
	await get_tree().process_frame


## While the piece is taken: the cloth, the veil, the bar and the one line.
func _organ_veil_shot() -> void:
	_anatomy()
	_organ_pack()
	var dead := _on_table("Marthe Quendel", 71, &"old_age")
	await _in_crypt()
	_ui.open_panel(&"corpse_exam", {"corpse_id": dead.id, "table": _crypt_table, "player": _player})
	(_ui.get_panel(&"corpse_exam") as CorpseExamPanel).tabs.select_tab(CorpseExamTabs.TAB_ORGANS)
	_player.instant_actions = false
	_crypt_table.request_organ(&"hand", SpecimenRecord.CONTAINER_BUNDLE)
	await _hold_action(1.4)


## Quast's panel: a jar, a bundle that spoils, a display specimen.
func _anatomist_shot() -> void:
	_anatomy()
	_out_of_rooms()
	_organ_pack()
	_player.inventory.add_item(&"ink", 1)
	var a := _on_table("Hedwig Lamprecht", 58, &"fever")
	_piece(a, &"heart", SpecimenRecord.CONTAINER_JAR)
	var bundle := _piece(a, &"liver", SpecimenRecord.CONTAINER_BUNDLE)
	_specimens.get_record(bundle).harvest_total = TimeManager.total_minutes() - 340
	var b := _on_table("Paul Egger", 44, &"drowned_millpond")
	var display := _piece(b, &"stomach", SpecimenRecord.CONTAINER_JAR)
	_specimens.make_display(display, _player.inventory)
	GameState.stats[&"university_standing"] = 1
	_at_gate()
	_ui.open_panel(&"anatomist", {"speaker": _player, "inventory": _player.inventory})
	await get_tree().process_frame


## The pult: a liver jar chosen, Quast's book with the three medicines.
func _pult_shot() -> void:
	_anatomy()
	_organ_pack()
	_player.inventory.add_item(&"herbs", 3)
	_player.inventory.add_item(&"herb_bundle", 1)
	var a := _on_table("Hedwig Lamprecht", 58, &"fever")
	var liver := _piece(a, &"liver", SpecimenRecord.CONTAINER_JAR)
	var bundle := _piece(a, &"kidneys", SpecimenRecord.CONTAINER_BUNDLE)
	_player.inventory.remove_uid(bundle)
	_store.store().add_unique(&"specimen_bundle", bundle)
	await _in_crypt()
	_ui.open_panel(&"pult", {"station": &"pult", "inventory": _player.inventory, "player": _player})
	var panel := _ui.get_panel(&"pult") as PultPanel
	panel.select(liver)
	await get_tree().process_frame


## The collection: „Brustraum" and „Sinne und Hand" complete, the hint.
func _collection_shot() -> void:
	_anatomy()
	_organ_pack()
	var a := _on_table("Hedwig Lamprecht", 58, &"fever")
	var b := _on_table("Jakob Brandt", 63, &"moor_cold")
	var inv := _player.inventory
	for pair: Array in [[a, &"heart", SpecimenRecord.CONTAINER_JAR], [a, &"lung", SpecimenRecord.CONTAINER_JAR],
			[b, &"eyes", SpecimenRecord.CONTAINER_JAR], [b, &"hand", SpecimenRecord.CONTAINER_BUNDLE]]:
		var uid := _piece(pair[0], pair[1], pair[2])
		if pair[1] == &"hand":
			inv.add_item(&"beeswax", 1)
			inv.add_item(&"linen", 1)
			_specimens.make_bone(uid, inv)
		_shelf.place(uid, inv)
	_piece(b, &"liver", SpecimenRecord.CONTAINER_JAR)
	_ui.notifications.clear()
	await _in_crypt()
	_ui.open_panel(&"collection", {"shelf": _shelf, "storage": _shelf.storage, "inventory": inv, "player": _player})
	await get_tree().process_frame


## „Ursache deuten": a white coat in the stomach, the teaching, arsenic chosen – the result.
func _deduction_shot() -> void:
	_anatomy()
	_lectures.learn(&"l_stomach")
	_organ_pack()
	var dead := _on_table("Grete Vollmer", 52, &"fever", &"arsenic")
	var uid := _piece(dead, &"stomach", SpecimenRecord.CONTAINER_JAR)
	_specimens.inspect(uid)
	_out_of_rooms()
	_at_gate()
	_ui.open_panel(&"deduction", {"corpse_id": dead.id})
	var panel := _ui.get_panel(&"deduction") as DeductionPanel
	panel.toggle_card("b_white_stomach")
	panel.toggle_card("l_stomach")
	panel.choose_cause(&"arsenic")
	panel.deduce()
	await get_tree().process_frame


func _lecture_night() -> void:
	_lectures.invite()
	var day := TimeManager.day
	while day % 3 != 0:
		day += 1
	TimeManager.set_time(day, 1390)


## The lecture panel: the fee preview and Quast's line about the night.
func _lecture_shot() -> void:
	_anatomy()
	_organ_pack()
	var a := _on_table("Hedwig Lamprecht", 58, &"fever")
	_piece(a, &"heart", SpecimenRecord.CONTAINER_JAR)
	_piece(a, &"liver", SpecimenRecord.CONTAINER_JAR)
	_lecture_night()
	_at_gate()
	_ui.open_panel(&"lecture", {"speaker": _player, "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


## During the lecture: the veil at 60 %, Quast's talk, the bar.
func _lecture_veil_shot() -> void:
	_anatomy()
	_organ_pack()
	var a := _on_table("Hedwig Lamprecht", 58, &"fever")
	_piece(a, &"heart", SpecimenRecord.CONTAINER_JAR)
	_lecture_night()
	_at_gate()
	_ui.open_panel(&"lecture", {"speaker": _player, "inventory": _player.inventory, "player": _player})
	var panel := _ui.get_panel(&"lecture") as LecturePanel
	_player.instant_actions = false
	panel.request_hold()
	await _hold_action(1.4)


## The Merkbuch: „Vorher eingetragen" linked.
func _insight_shot() -> void:
	_at_gate()
	var journal := get_tree().get_first_node_in_group(&"journal") as JournalManager
	var ids: Array[StringName] = [&"c_v_deathbook", &"c_v_washing", &"c_v_three_visitors"]
	for id: StringName in ids:
		journal.add_clue(id, "", true)
	journal.try_link(ids)
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	_ui.open_journal(&"insights")
	await get_tree().process_frame


func _register_shot() -> void:
	_anatomy()
	_at_gate()
	var entries: Array = Desk.register_entries(_graveyard, _corpses)
	var ctx := {"entries": entries, "total": _graveyard.total_quality(), "rating": _graveyard.rating()}
	if not entries.is_empty():
		(entries[0] as Dictionary)["specimens"] = {"taken": 2, "returned": 1}
		(entries[1] as Dictionary)["deduced"] = true
	_ui.open_panel(&"grave_register", ctx)
	await get_tree().process_frame


func _day_summary_shot() -> void:
	_at_gate()
	_ui.day_log.reset()
	EventBus.payment_received.emit(8, "Verkauf im Dorf")
	EventBus.payment_received.emit(6, "Auftrag: Holunderbeeren")
	EventBus.coins_spent.emit(5, &"round")
	EventBus.coins_spent.emit(4, &"village")
	EventBus.order_changed.emit(&"o_rosine_berries", &"completed")
	EventBus.relationship_changed.emit(&"innkeeper", 48, &"trusted", 10, "Auftrag: Holunderbeeren")
	EventBus.relationship_changed.emit(&"mayor", 53, &"trusted", 1, "Gespräch")
	EventBus.relationship_changed.emit(&"washer", 9, &"stranger", -3, "Im Dorf redet man.")
	EventBus.specimen_changed.emit("sp_9001", &"taken")
	EventBus.specimen_changed.emit("sp_9001", &"returned")
	_ui.open_panel(&"day_summary", {"day": TimeManager.day, "burials_today": 1, "coins_today": 9, "total": 176, "rating": &"venerable"})
	await get_tree().process_frame


func _chapter_shot() -> void:
	_at_gate()
	var context := _village.chapter_context()
	# The staged world has no bot history; the panel is shown as at the end of arc A (§1.4).
	context["village_days"] = 12
	context["village_trips"] = 14
	context["orders_done"] = 9
	context["orders_by_giver"] = {&"mayor": 3, &"innkeeper": 2, &"smith": 2, &"priest": 1, &"council": 1}
	context["relationships"] = {&"innkeeper": "Vertraut", &"smith": "Vertraut", &"grocer": "Befreundet", &"priest": "Vertraut",
			&"mayor": "Vertraut", &"surgeon": "Bekannt", &"washer": "Bekannt", &"oldwoman": "Vertraut"}
	context["linden_burials"] = 8
	context["specimens"] = {"specimens_taken": 0}
	context["coins_earned_village"] = {"Aufträge": 65, "Verkäufe": 12}
	context["coins_spent_village"] = {&"village": 14, &"donation": 32, &"round": 10, &"consecration": 10}
	context["insights_phase7"] = PackedStringArray(["i_deathbook"])
	_ui.open_panel(&"slice_summary", context)
	await get_tree().process_frame

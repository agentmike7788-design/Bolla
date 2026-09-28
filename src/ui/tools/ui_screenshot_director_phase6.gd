extends Node
## QA director, Phase-6 UI (docs/PHASE6_DESIGN.md §7, §11): started by ui_screenshots.gd with
## --phase6. Starts a new game in the real graveyard world and stages every state through the
## public APIs of the systems. Phase-6 nodes the world does not have yet (Systems/Buildings,
## Ossuary, Chapel; the three building sites, the shed store, a crypt table and the catafalque –
## W-Welt's builder adds them) are added at runtime from their own scripts / scenes; nothing is
## written to the world files. Where no interior is built yet the panels stand over the outdoor
## world at the building's site.
## Staging: names_in_stone_complete → buildings_open; seven graves in the Alter Hof buried and
## marked (two of them robbed of hair and teeth); materials in the pack.
## Shots (1280×720, <out>/ui_<name>.jpg):
##   building_crypt · building_fetch · chapel · devotion · shed_chest · exam_crypt · hud_chapter ·
##   chapter_roof_and_earth · osric_p6
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase6 --out=/abs/dir [--shots=chapel,devotion]

const SAVE_DIR := "user://ui_shot_saves_p6"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY := 31
const MORNING := 600
const SYSTEMS: Dictionary[String, Script] = {
	"Buildings": preload("res://src/systems/buildings/buildings.gd"),
	"Ossuary": preload("res://src/systems/ossuary/ossuary.gd"),
	"Chapel": preload("res://src/systems/chapel/chapel_rites.gd"),
}
const GROUPS: Dictionary[String, StringName] = {"Buildings": &"buildings", "Ossuary": &"ossuary", "Chapel": &"chapel_rites"}
const SITE_SCENE := "res://src/entities/building_site/building_site.tscn"
const SHED_SCENE := "res://src/entities/shed_store/shed_store.tscn"
const TABLE_SCENE := "res://src/entities/morgue_table/morgue_table.tscn"
const CATAFALQUE_SCENE := "res://src/entities/catafalque/catafalque.tscn"
## Contract positions of the sites (§4.1–§4.3), used when the world has no site yet.
const SITES: Dictionary[StringName, Vector3] = {&"crypt": Vector3(-9.0, 0.0, 6.9), &"chapel": Vector3(4.5, 0.0, -25.5),
		&"shed": Vector3(-12.9, 0.0, -9.0)}
## Far away (like the interiors, §4.7): the stand-in crypt table and catafalque.
const HIDDEN_AT := Vector3(60.0, -30.0, -200.0)
## plot, name, age, cause, marker, robbed
const GRAVES: Array = [
	["plot_01", "Egbert Kornblum", 71, &"fever", &"gravestone_simple", false],
	["plot_02", "Hedwig Rabenstein", 67, &"drowned_millpond", &"gravestone_simple", false],
	["plot_03", "Konrad Bleich", 29, &"coach_accident", &"wooden_cross", true],
	["plot_04", "Ida Wendt", 48, &"fever", &"wooden_cross", false],
	["plot_05", "Johann Seeger", 55, &"fall_hayloft", &"wooden_cross", true],
	["plot_06", "Grete Vollmer", 83, &"fever", &"gravestone_simple", false],
	["plot_07", "Anna Fessler", 39, &"fever", &"wooden_cross", false],
]

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _corpses: CorpseManager
var _graveyard: Graveyard
var _buildings: Buildings
var _rites: ChapelRites
var _shed: ShedStore
var _sites: Dictionary[StringName, BuildingSite] = {}
var _crypt_table: MorgueTable
var _catafalque: Catafalque
var _anchor: Node3D
var _bounds_were: bool = true


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP6] --out=<dir> missing")
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
	await _shot("building_crypt", _building_crypt_shot)
	await _shot("building_fetch", _building_fetch_shot)
	await _shot("shed_chest", _shed_chest_shot)
	await _shot("exam_crypt", _exam_shot)
	await _shot("chapel", _chapel_shot)
	await _shot("devotion", _devotion_shot)
	await _shot("hud_chapter", _hud_chapter_shot)
	await _shot("chapter_roof_and_earth", _chapter_shot)
	await _shot("osric_p6", _osric_shot)
	for slot: int in [0, 1]:
		SaveManager.delete_save(slot)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
	get_tree().quit()


func _shot(shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not shot_name in _only:
		return
	await setup.call()
	_ui.hud.refresh_all()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join("ui_%s.jpg" % shot_name)
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP6] ", path)
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	_unframe()
	_hover_off()
	await get_tree().process_frame


## Missing Phase-6 nodes (a no-op once the builder adds them) – same classes, scenes and groups.
func _ensure_nodes() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
	_buildings = get_tree().get_first_node_in_group(&"buildings") as Buildings
	_rites = get_tree().get_first_node_in_group(&"chapel_rites") as ChapelRites
	var entities := _world.get_node(^"Entities")
	for id: StringName in SITES:
		var site := entities.get_node_or_null(NodePath("site_%s" % id)) as BuildingSite
		if site == null:
			site = (load(SITE_SCENE) as PackedScene).instantiate() as BuildingSite
			site.name = "ShotSite_%s" % id
			site.building_id = id
			entities.add_child(site)
			var at := SITES[id]
			at.y = _world.ground_height(Vector2(at.x, at.z))
			site.global_position = at
		_sites[id] = site
	_shed = ShedStore.find(get_tree())
	if _shed == null:
		_shed = (load(SHED_SCENE) as PackedScene).instantiate() as ShedStore
		_shed.name = "ShotShedStore"
		_world.add_child(_shed)
		_shed.global_position = HIDDEN_AT
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
	_catafalque = get_tree().get_first_node_in_group(&"catafalque") as Catafalque
	if _catafalque == null:
		_catafalque = (load(CATAFALQUE_SCENE) as PackedScene).instantiate() as Catafalque
		_catafalque.name = "ShotCatafalque"
		_world.add_child(_catafalque)
		_catafalque.global_position = HIDDEN_AT + Vector3(6.0, 0.0, 0.0)


# --- staging (real systems only) ----------------------------------------------------------

func _stage() -> void:
	TimeManager.set_time(DAY, MORNING)
	for flag: StringName in [&"cemetery_complete", &"workshop_open", &"names_in_stone_complete", &"p6_intro"]:
		GameState.set_flag(flag, true)
	_buildings.post_load()  # buildings_open at once (§1.2, like a migrated save)
	if not _buildings.is_open():
		_buildings.call(&"_open")
	for i: int in GRAVES.size():
		var spec: Array = GRAVES[i]
		_bury(spec[0], spec[1], int(spec[2]), spec[3], spec[4], bool(spec[5]), 12 + i)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()
	_ui.reward_card.visible = false


func _bury(plot_id: String, name: String, age: int, cause: StringName, marker: StringName, robbed: bool, day: int) -> void:
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
	if robbed:
		spawned.harvested.assign([CorpseRecord.HARVEST_HAIR, CorpseRecord.HARVEST_TEETH])
	_graveyard.dig(plot_id)
	_graveyard.bury(plot_id, spawned.id)
	var purse := Inventory.new()
	purse.add_item(marker, 1)
	_graveyard.place_marker(plot_id, marker, purse)
	purse.free()


## Levels through the saved format (§5.1) and apply_levels (sites, shed store, tables).
func _levels(levels: Dictionary) -> void:
	var state := _buildings.save_state()
	var saved: Dictionary = state.get("levels", {})
	for id: Variant in levels:
		saved[String(id)] = int(levels[id])
	state["levels"] = saved
	_buildings.load_state(state)
	_buildings.apply_levels()
	for site: BuildingSite in _sites.values():
		site.refresh()


func _pack(items: Dictionary) -> void:
	var inv := _player.inventory
	inv.remove_item(&"coin", inv.count(&"coin"))
	for slot: Dictionary in inv.get_slots():
		if not slot.is_empty():
			inv.remove_item(StringName(slot.id), int(slot.amount))
	for id: Variant in items:
		inv.add_item(StringName(str(id)), int(items[id]))


func _open_building(id: StringName) -> void:
	var site := _sites[id]
	_place_player(site.global_position + Vector3(1.6, 0.0, 3.2), 0.4)
	_frame(site.global_position + Vector3(0.0, 0.0, 1.0), 13.0)
	_ui.open_panel(&"building", {"building": id, "data": site.building_data(), "level": site.level(), "site": site,
			"inventory": _player.inventory, "player": _player})


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


func _hover(control: Control) -> void:
	var at := control.get_global_rect().get_center()
	var window_pos := get_viewport().get_screen_transform() * at
	Input.warp_mouse(window_pos)
	var motion := InputEventMouseMotion.new()
	motion.position = window_pos
	motion.global_position = window_pos
	Input.parse_input_event(motion)
	await get_tree().create_timer(1.6, true, false, true).timeout


func _hover_off() -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(4, 4)
	motion.global_position = Vector2(4, 4)
	Input.warp_mouse(Vector2(4, 4))
	Input.parse_input_event(motion)


## A fresh dead of today (`location` ground), examined and dressed.
func _dead(name: String, age: int, dress: StringName) -> CorpseRecord:
	var rec := CorpseRecord.new()
	rec.display_name = name
	rec.age = age
	rec.cause_id = &"fever"
	var spawned := _corpses.spawn_corpse(rec, Transform3D(Basis.IDENTITY, HIDDEN_AT + Vector3(3.0, 0.0, 0.0)), &"ground")
	spawned.examined = true
	spawned.exam_done.assign(CorpseRecord.STEPS)
	if spawned.needs_valuables_decision():
		spawned.valuables_decision = CorpseRecord.DECISION_LEFT
	spawned.washed = true
	spawned.dress = dress
	spawned.shrouded = dress != CorpseRecord.DRESS_NONE
	return spawned


# --- shots ------------------------------------------------------------------------------------

## Crypt 1 → 2: stone and clay there, workstone half, iron and coins short.
func _building_crypt_shot() -> void:
	_levels({&"crypt": 1, &"chapel": 0, &"shed": 0})
	_pack({&"coin": 24, &"stone": 9, &"clay": 4, &"workstone": 2, &"wood": 6, &"shovel_iron": 1})
	_open_building(&"crypt")
	await get_tree().process_frame


## Shed 2: what the pack lacks lies in the shed – „Fehlendes aus dem Schuppen holen (10 Min)".
func _building_fetch_shot() -> void:
	_levels({&"crypt": 1, &"chapel": 1, &"shed": 2})
	_pack({&"coin": 41, &"stone": 3, &"clay": 4, &"shovel_iron": 1})
	var store := _shed.store()
	for entry: Array in [[&"workstone", 6], [&"stone", 14], [&"iron_bar", 2], [&"wood", 22], [&"clay", 3]]:
		store.add_item(entry[0], entry[1])
	_open_building(&"crypt")
	await get_tree().process_frame


## Shed 3: 40 places, double stacks of resources and materials.
func _shed_chest_shot() -> void:
	_levels({&"crypt": 1, &"chapel": 1, &"shed": 3})
	var store := _shed.store()
	for entry: Array in [[&"stone", 38], [&"wood", 40], [&"clay", 12], [&"iron_ore", 6], [&"charcoal", 4], [&"bone_box", 2],
			[&"altar_candle", 3], [&"flax", 9], [&"linen", 4], [&"gold_leaf", 1], [&"ink", 2]]:
		store.add_item(entry[0], entry[1])
	_pack({&"coin": 18, &"stone": 6, &"wood": 3, &"shovel_iron": 1, &"pickaxe_iron": 1, &"bone_box_full": 1})
	var site := _sites[&"shed"]
	_place_player(site.global_position + Vector3(1.4, 0.0, 3.4), 0.3)
	_frame(site.global_position + Vector3(0.0, 0.0, 1.2), 12.0)
	_ui.open_panel(&"chest", {"storage": store, "inventory": _player.inventory, "chest": _shed})
	await get_tree().process_frame


## The crypt table (crypt 2): a dead of this morning, clothing and hands examined.
func _exam_shot() -> void:
	_levels({&"crypt": 2, &"chapel": 1, &"shed": 3})
	_crypt_table.refresh_active()
	TimeManager.set_time(DAY + 1, 470)
	var rec := CorpseRecord.new()
	rec.display_name = "Lene Hartwig"
	rec.age = 57
	rec.cause_id = &"fever"
	var spawned := _corpses.spawn_corpse(rec, _crypt_table.slot_transform(), &"ground")
	_corpses.put_down(spawned.id, CorpseRecord.LOCATION_TABLE, _crypt_table.slot_transform(), null, &"crypt")
	TimeManager.set_time(DAY + 1, 640)
	var care := get_tree().get_first_node_in_group(&"corpse_care")
	if care != null and care.has_method(&"exam_step"):
		for step: StringName in [CorpseRecord.STEP_CLOTHING, CorpseRecord.STEP_HANDS]:
			care.call(&"exam_step", spawned.id, step)
	_ui.notifications.clear()
	var site := _sites[&"crypt"]
	_place_player(site.global_position + Vector3(1.4, 0.0, 3.2), 0.3)
	_frame(site.global_position + Vector3(0.0, 0.0, 1.0), 11.0)
	_ui.open_panel(&"corpse_exam", {"corpse_id": spawned.id, "table": _crypt_table, "player": _player})
	await get_tree().process_frame


## The service on chapel level 2: Marthe on the catafalque in her gown, one candle, 10:30.
func _chapel_shot() -> void:
	_levels({&"crypt": 2, &"chapel": 2, &"shed": 3})
	TimeManager.set_time(DAY + 2, 560)
	var dead := _dead("Marthe Albrecht", 64, CorpseRecord.DRESS_GOWN)
	_corpses.put_down(dead.id, CorpseRecord.LOCATION_CATAFALQUE, _catafalque.slot_node().global_transform, null, &"chapel")
	TimeManager.set_time(DAY + 2, 630)
	_pack({&"coin": 17, &"altar_candle": 1, &"shovel_iron": 1})
	var site := _sites[&"chapel"]
	_place_player(site.global_position + Vector3(0.6, 0.0, 5.0), 0.0)
	_frame(site.global_position + Vector3(0.0, 0.0, 2.5), 16.0)
	_ui.notifications.clear()
	_ui.open_panel(&"chapel", {"corpse_id": dead.id, "altar": null, "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


## Night at the altar: the graves, two robbed souls, one light already burning.
func _devotion_shot() -> void:
	_levels({&"crypt": 2, &"chapel": 1, &"shed": 3})
	_pack({&"coin": 9, &"altar_candle": 3, &"shovel_iron": 1})
	_rites.hold_devotion("plot_02", _player.inventory)
	TimeManager.set_time(DAY + 2, 1330)
	var site := _sites[&"chapel"]
	_place_player(site.global_position + Vector3(0.6, 0.0, 5.0), 0.0)
	_frame(site.global_position + Vector3(0.0, 0.0, 2.5), 16.0)
	_ui.notifications.clear()
	_ui.open_panel(&"devotion", {"altar": null, "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame
	var panel := _ui.get_panel(&"devotion") as DevotionPanel
	for row: Dictionary in panel.rows:
		if bool(row.get("capped", false)):
			panel.select(str(row.grave_id))
			break


func _hud_chapter_shot() -> void:
	_levels({&"crypt": 2, &"chapel": 1, &"shed": 2})
	TimeManager.set_time(DAY + 3, 640)
	var table := _world.get_node_by_layout_id("morgue_table") as Node3D
	_place_player(table.global_position + table.global_basis.z * 1.6)
	_ui.hud.refresh_all()
	await get_tree().process_frame
	await _hover(_ui.hud.quality_row)


func _chapter_shot() -> void:
	_levels({&"crypt": 2, &"chapel": 2, &"shed": 2})
	for reason: Array in [[&"building", 130], [&"osric", 12]]:
		EventBus.coins_spent.emit(reason[1], reason[0])
	var context := _buildings.chapter_context()
	# The staged yard has no bot history; the panel is shown as at the end of arc A (§1.4).
	context["buildings_days"] = 6
	context["services_held"] = 5
	context["devotions_held"] = 2
	context["reinterred"] = PackedStringArray(["Barbe Lindt", "Hanne Sörgel", "Elias Brand, Totengräber", "Agnes Hollweg", "Mattheis Korb"])
	context["reinterred_total"] = 6
	context["niche_waits"] = 2
	context["coins_spent"] = {&"building": 130, &"osric": 12}
	context["content_before"] = 11
	context["content_now"] = 14
	_ui.open_panel(&"slice_summary", context)


## Morning at the gate: Osric sells altar candles.
func _osric_shot() -> void:
	TimeManager.set_time(DAY + 4, 480)
	UIState.clear()
	_ui.close_all()
	_pack({&"coin": 14, &"shovel_iron": 1})
	var npc := _world.get_node_by_layout_id("npc_carter") as Node3D
	for i: int in 5:
		await get_tree().process_frame
	for flag: StringName in [&"met_carter", &"p3_intro", &"p4_intro", &"p5_intro", &"vs_finished", &"cemetery_praised", &"p6_intro"]:
		GameState.set_flag(flag, true)
	_place_player(npc.global_position + Vector3(-1.2, 0.0, -1.0), PI * 0.75)
	_frame(npc.global_position, 10.0)
	await get_tree().process_frame
	_ui.open_dialogue(&"carter", npc)
	for i: int in 12:
		if _ui.dialogue_box.current_text().contains("Altarkerzen aus der Stadt") or not _ui.dialogue_box.is_active():
			break
		var pick := 0
		var texts := _ui.dialogue_box.choice_texts()
		for c: int in texts.size():
			if texts[c].contains("Altarkerzen"):
				pick = c
				break
		_ui.dialogue_box.choose(pick)
	_ui.dialogue_box.text_label.visible_ratio = 1.0
	_ui.dialogue_box.chars_per_second = 0.0

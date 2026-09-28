extends Node
## QA director, Phase-5 UI (docs/PHASE5_DESIGN.md §7, §11): started by ui_screenshots.gd with
## --phase5. Starts a new game in the real graveyard world and stages every state through the
## public APIs of the systems. Phase-5 system nodes the world does not have yet (Workshop,
## Gathering, Stonemasonry – W-Welt's builder adds them) are added under Systems first, a build
## site node for the panel as well; nothing is written to the world files.
## Staging: cemetery_complete → Workshop.post_load opens the workyard; seven graves in the Alter
## Hof with the dead buried and marked (Marthe Quendel, S1, with a plain gravestone); materials in
## the pack for a gilded master stone.
## Shots (1280×720, <out>/ui_<name>.jpg):
##   build_site · stone_design · stone_rack · loom · forge_kiln · tool_belt · hud_chapter ·
##   chapter_names_in_stone · osric_p5 · trade_gold · stone_zoom10 (a gilded master stone and an
##   ink stele at the graves, camera 10 m – the readability check)
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase5 --out=/abs/dir [--shots=stone_design,forge_kiln]

const SAVE_DIR := "user://ui_shot_saves_p5"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY := 14
const MORNING := 600
const NIGHT := 1410
const STORY := &"s1_quendel"
const SYSTEMS: Dictionary[String, Script] = {
	"Workshop": preload("res://src/systems/workshop/workshop.gd"),
	"Gathering": preload("res://src/systems/gathering/gather_manager.gd"),
	"Stonemasonry": preload("res://src/systems/stone/stonemasonry.gd"),
}
const GROUPS: Dictionary[String, StringName] = {"Workshop": &"workshop", "Gathering": &"gathering", "Stonemasonry": &"stonemasonry"}
## plot, name, age, cause, marker
const GRAVES: Array = [
	["plot_01", "", 0, &"", &"gravestone_simple"],
	["plot_02", "Egbert Kornblum", 71, &"fever", &"wooden_cross"],
	["plot_03", "Hedwig Rabenstein", 67, &"drowned_millpond", &"gravestone_simple"],
	["plot_04", "Konrad Bleich", 29, &"coach_accident", &"wooden_cross"],
	["plot_05", "Ida Wendt", 48, &"fever", &""],
	["plot_06", "Johann Seeger", 55, &"fall_hayloft", &"wooden_cross"],
	["plot_07", "Grete Vollmer", 83, &"fever", &"gravestone_simple"],
]

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _corpses: CorpseManager
var _graveyard: Graveyard
var _shop: Workshop
var _masonry: Stonemasonry
var _site: BuildSite
var _anchor: Node3D
var _bounds_were: bool = true
var _extra: Array[Node] = []
## Coins set aside for the build-site shot (given back in the next one).
var _coin_stash: int = 0


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP5] --out=<dir> missing")
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
	_ensure_systems()
	await get_tree().process_frame
	_stage()
	await get_tree().process_frame
	await _shot("build_site", _build_site_shot)
	await _shot("loom", _loom_shot)
	await _shot("forge_kiln", _forge_shot)
	await _shot("forge_tools", _forge_tools_shot)
	await _shot("stone_design", _stone_design_shot)
	await _shot("stone_rack", _stone_rack_shot)
	await _shot("tool_belt", _tool_belt_shot)
	await _shot("hud_chapter", _hud_chapter_shot)
	await _shot("stone_zoom10", _zoom_shot)
	await _shot("chapter_names_in_stone", _chapter_shot)
	await _shot("osric_p5", _osric_shot)
	await _shot("trade_gold", _trade_shot)
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
	print("[UiShotsP5] ", path)
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	_unframe()
	_hover_off()
	await get_tree().process_frame


## Missing Phase-5 system nodes (a no-op once the builder adds them) – same classes and groups.
func _ensure_systems() -> void:
	var systems := _world.get_node(^"Systems")
	for node_name: String in SYSTEMS:
		if get_tree().get_first_node_in_group(GROUPS[node_name]) != null:
			continue
		var node := (SYSTEMS[node_name] as GDScript).new() as Node
		node.name = node_name
		systems.add_child(node)
	_shop = get_tree().get_first_node_in_group(&"workshop") as Workshop
	_masonry = get_tree().get_first_node_in_group(&"stonemasonry") as Stonemasonry
	# W3 (G5): the real forge build site of the workyard (a stand-in only for a world without it).
	_site = _world.get_node_or_null(^"Entities/site_forge") as BuildSite
	if _site == null:
		_site = BuildSite.new()
		_site.name = "ShotSiteForge"
		_site.station_id = &"forge"
		_world.add_child(_site)


# --- staging (real systems only) ----------------------------------------------------------

func _stage() -> void:
	TimeManager.set_time(DAY, MORNING)
	GameState.set_flag(&"cemetery_complete", true)
	_shop.post_load()  # workshop_open at once (§1.2, like a migrated save)
	for i: int in GRAVES.size():
		var spec: Array = GRAVES[i]
		_bury(spec[0], spec[1], int(spec[2]), spec[3], spec[4], 2 + i)
	var inv := _player.inventory
	for entry: Array in [[&"coin", 38], [&"stone", 7], [&"wood", 6], [&"clay", 4], [&"iron_fittings", 2], [&"workstone", 3],
			[&"ink", 2], [&"gold_leaf", 2], [&"flax", 7], [&"yarn", 2], [&"linen", 1], [&"iron_ore", 3], [&"charcoal", 1]]:
		inv.add_item(entry[0], entry[1])
	for tool: StringName in [&"shovel_iron", &"pickaxe_iron", &"rake", &"scrub_brush", &"comb", &"shears", &"pliers"]:
		inv.add_item(tool, 1)
	var table := _world.get_node_by_layout_id("morgue_table") as Node3D
	_place_player(table.global_position + table.global_basis.z * 1.6)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()


## A dead in `plot_id`, buried and (with `marker`) marked; plot_01 gets Marthe Quendel (S1).
func _bury(plot_id: String, name: String, age: int, cause: StringName, marker: StringName, day: int) -> void:
	if _graveyard.get_grave(plot_id) == null or _graveyard.get_grave(plot_id).state != GraveRecord.State.EMPTY:
		return
	var plot := _world.get_node_by_layout_id(plot_id) as Node3D
	var rec: CorpseRecord
	if name == "":
		rec = StoryDirector.make_record(Database.story_corpse(STORY) as StoryCorpseData, 7)
	else:
		rec = CorpseRecord.new()
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
	_graveyard.dig(plot_id)
	_graveyard.bury(plot_id, spawned.id)
	if marker != &"":
		var purse := Inventory.new()
		purse.add_item(marker, 1)
		_graveyard.place_marker(plot_id, marker, purse)
		purse.free()


## Every FILLED grave gets `marker` (so the objective line shows the workyard, not the marker).
func _mark_filled(marker: StringName) -> void:
	for g: GraveRecord in _graveyard.graves():
		if g.state == GraveRecord.State.FILLED:
			var purse := Inventory.new()
			purse.add_item(marker, 1)
			_graveyard.place_marker(g.id, marker, purse)
			purse.free()
	_ui.notifications.clear()
	_ui.reward_card.visible = false


func _built(ids: Array) -> void:
	var state := _shop.save_state()
	var list: Array = state.get("built", [])
	for id: Variant in ids:
		if not String(id) in list:
			list.append(String(id))
	state["built"] = list
	_shop.load_state(state)
	# W3 (G5): the real world shows what is built – the stations stand, their sites are gone.
	for node: Node in _world.get_node(^"Entities").get_children():
		if node is Workbench:
			(node as Workbench).refresh_built()
		elif node is BuildSite:
			(node as BuildSite).refresh()


## The camera on `focus` (ground) at `distance` instead of the player.
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
	for node: Node in _extra:
		if is_instance_valid(node):
			node.queue_free()
	_extra.clear()
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


## Moves the mouse over `control` and waits for its tooltip (drawn inside the window).
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


# --- shots ------------------------------------------------------------------------------------

## The forge site: the fittings there, stone, clay and 5 coins short.
func _build_site_shot() -> void:
	var inv := _player.inventory
	_coin_stash = inv.count(&"coin") - 20
	inv.remove_item(&"coin", _coin_stash)
	_site.refresh()
	# In front of the real site, as the player opens it ([E] Bauplatz: Esse).
	_place_player(_site.global_position + _site.global_basis.z * 1.6, 0.0)
	_frame(_site.global_position, 12.0)
	_ui.open_panel(&"build_site", {"station": &"forge", "station_data": Database.station(&"forge"), "site": _site,
			"inventory": inv, "player": _player})
	await get_tree().process_frame


func _loom_shot() -> void:
	_built([&"mason", &"loom"])
	_player.inventory.add_item(&"coin", maxi(_coin_stash, 0))
	_coin_stash = 0
	_ui.open_panel(&"crafting", {"station": &"loom", "inventory": _player.inventory, "player": _player})


## Forge built, the kiln stacked at 06:20 – now 10:00, it burns until 14:20.
func _forge_shot() -> void:
	_built([&"mason", &"loom", &"forge"])
	TimeManager.set_time(DAY + 1, 380)
	_shop.start_job(&"forge", Database.recipe(&"charcoal") as RecipeData, _player.inventory)
	_player.inventory.add_item(&"wood", 4)
	TimeManager.set_time(DAY + 1, 600)
	_ui.notifications.clear()
	_ui.open_panel(&"crafting", {"station": &"forge", "inventory": _player.inventory, "player": _player})
	await get_tree().process_frame


## The forge's tool recipes (scrolled down): what each replaces and what it speeds up.
func _forge_tools_shot() -> void:
	_built([&"mason", &"loom", &"forge"])
	var inv := _player.inventory
	for entry: Array in [[&"iron_bar", 2], [&"steel_rod", 1], [&"iron_fittings", 2]]:
		inv.add_item(entry[0], entry[1])
	TimeManager.set_time(DAY + 1, 600)
	_ui.notifications.clear()
	_ui.open_panel(&"crafting", {"station": &"forge", "inventory": inv, "player": _player})
	for i: int in 3:
		await get_tree().process_frame
	var panel := _ui.get_panel(&"crafting") as CraftingPanel
	panel._scroll.scroll_vertical = int(panel._list.get_combined_minimum_size().y)


## Marthe Quendel chosen: master stone, „Was du gesät hast“ (fits her story), gilded, elder.
func _stone_design_shot() -> void:
	_ui.open_panel(&"stone_design", {"inventory": _player.inventory, "player": _player})
	await get_tree().process_frame
	var panel := _ui.get_panel(&"stone_design") as StoneDesignPanel
	panel.select_grave("plot_01", false)
	panel.select_shape(&"stone_master")
	panel.select_inscription(&"i_garden")
	panel.set_gilded(true)
	panel.select_ornament(&"orn_elder")
	await get_tree().process_frame


## Two stones in the rack, one of them outdated (the grave got a better stone meanwhile), the
## discard waiting for its second press.
func _stone_rack_shot() -> void:
	var inv := _player.inventory
	for entry: Array in [[&"stone", 14], [&"clay", 2], [&"ink", 2]]:
		inv.add_item(entry[0], entry[1])
	_masonry.carve("plot_02", _design(&"stone_arch", &"i_long_road", &"orn_ivy"), inv)
	_masonry.carve("plot_04", _design(&"stone_stele", &"i_road"), inv)
	# plot_04 meanwhile got a better stone from elsewhere (debug path, same rules).
	var better := _design(&"stone_arch", &"i_too_soon", &"orn_torch")
	better.text = StoneDesignRules.render_text(Database.inscription(&"i_too_soon") as InscriptionData,
			_corpses.get_record(_graveyard.get_grave("plot_04").corpse_id), Database.config(&"stone_config") as StoneConfig)
	_graveyard.set_designed_stone("plot_04", better, inv)
	_ui.open_panel(&"stone_design", {"inventory": inv, "player": _player})
	await get_tree().process_frame
	var panel := _ui.get_panel(&"stone_design") as StoneDesignPanel
	panel.select_grave("plot_03", false)
	panel.select_shape(&"stone_arch")
	panel.select_ornament(&"orn_poppy")
	for s: Dictionary in _masonry.ready_stones():
		if not bool(s.fits_still):
			panel.press_discard(String(s.id))


func _design(shape: StringName, ins: StringName = &"", orn: StringName = &"", gold: bool = false) -> StoneDesign:
	var d := StoneDesign.new()
	d.shape = shape
	d.inscription = ins
	d.ornament = orn
	d.gilded = gold
	return d


func _tool_belt_shot() -> void:
	_ui.toggle_inventory()
	await get_tree().process_frame
	await get_tree().process_frame
	var panel := _ui.get_panel(&"inventory") as InventoryPanel
	var cell := panel.belt_cells.get(&"shovel") as Control
	if cell != null:
		await _hover(cell)


func _hud_chapter_shot() -> void:
	_built([&"mason", &"loom"])
	_mark_filled(&"wooden_cross")
	_ui.hud.refresh_all()
	await get_tree().process_frame
	await _hover(_ui.hud.quality_row)


## Marthe's gilded master stone and an ink stele side by side at the graves, camera 10 m.
func _zoom_shot() -> void:
	var cfg := Database.config(&"stone_config") as StoneConfig
	var master := _design(&"stone_master", &"i_garden", &"orn_elder", true)
	master.text = StoneDesignRules.render_text(Database.inscription(&"i_garden") as InscriptionData,
			_corpses.get_record(_graveyard.get_grave("plot_01").corpse_id), cfg)
	_graveyard.set_designed_stone("plot_01", master, _player.inventory)
	var stele := _design(&"stone_stele", &"i_fever")
	stele.text = StoneDesignRules.render_text(Database.inscription(&"i_fever") as InscriptionData,
			_corpses.get_record(_graveyard.get_grave("plot_02").corpse_id), cfg)
	_graveyard.set_designed_stone("plot_02", stele, _player.inventory)
	TimeManager.set_time(DAY + 1, 660)
	var a := _world.get_node_by_layout_id("plot_01") as Node3D
	var b := _world.get_node_by_layout_id("plot_02") as Node3D
	var mid := (a.global_position + b.global_position) * 0.5
	_place_player(mid + Vector3(3.4, 0.0, 5.0), PI)
	_frame(mid + Vector3(0.0, 0.0, 0.8), 10.0)
	await get_tree().process_frame
	_ui.notifications.clear()
	_ui.reward_card.visible = false


func _chapter_shot() -> void:
	_built([&"mason", &"loom", &"forge"])
	var inv := _player.inventory
	for id: StringName in [&"shovel_iron", &"pickaxe_iron"]:
		inv.remove_item(id, 1)
	for id: StringName in [&"shovel_master", &"axe_iron", &"pickaxe_master"]:
		inv.add_item(id, 1)
	GameState.stats[&"stones_set"] = 6
	for reason: Array in [[&"license", 20], [&"build", 50], [&"osric", 32], [&"ilse", 12]]:
		EventBus.coins_spent.emit(reason[1], reason[0])
	var context := _shop.chapter_context()
	# The staged yard has 7 graves; the panel is shown as at the end of arc A (§1.4, 18 graves).
	context["workshop_days"] = 7
	context["named_graves"] = 7
	context["graves_total"] = 18
	context["content_before"] = 4
	context["content_now"] = 9
	_ui.open_panel(&"slice_summary", context)


## Morning at the gate: Osric's Phase-5 introduction with Lorenz' old work place.
func _osric_shot() -> void:
	TimeManager.set_time(TimeManager.day + 1, 480)
	UIState.clear()
	_ui.close_all()
	var npc := _world.get_node_by_layout_id("npc_carter") as Node3D
	for i: int in 5:
		await get_tree().process_frame
	for flag: StringName in [&"met_carter", &"p3_intro", &"p4_intro", &"vs_finished", &"cemetery_praised"]:
		GameState.set_flag(flag, true)
	GameState.flags.erase(&"p5_intro")
	_place_player(npc.global_position + Vector3(-1.2, 0.0, -1.0), PI * 0.75)
	_frame(npc.global_position, 10.0)
	await get_tree().process_frame
	_ui.open_dialogue(&"carter", npc)
	for i: int in 10:
		if _ui.dialogue_box.current_text().contains("Lorenz") or not _ui.dialogue_box.is_active():
			break
		_ui.dialogue_box.choose(0)
	_ui.dialogue_box.text_label.visible_ratio = 1.0
	_ui.dialogue_box.chars_per_second = 0.0


## 23:30 at the west wall: Ilse's shop with the gold leaf (workshop_open).
func _trade_shot() -> void:
	_ui.dialogue_box.chars_per_second = 110.0
	TimeManager.set_time(TimeManager.day, NIGHT)
	for flag: StringName in [&"trader_known", &"trader_met", &"trader_tools_given"]:
		GameState.set_flag(flag, true)
	var inv := _player.inventory
	inv.add_item(&"hair_braid", 1)
	var ilse := _world.get_node_by_layout_id("npc_trader") as Npc
	for i: int in 5:
		await get_tree().process_frame
	var spot: Vector3 = _world.get_waypoint(&"trader_spot")
	_place_player(spot + Vector3(1.35, 0.0, 0.3), -PI * 0.5)
	_frame(ilse.global_position + Vector3(3.2, 0.0, -1.2), 8.0)
	await get_tree().process_frame
	_ui.notifications.clear()
	_ui.open_panel(&"trader", {"speaker": ilse, "inventory": inv})
	await get_tree().process_frame
	var panel := _ui.get_panel(&"trader") as TraderPanel
	panel.buy(&"gold_leaf")

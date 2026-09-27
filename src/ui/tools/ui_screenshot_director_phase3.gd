extends Node
## QA director, Phase-3 UI (docs/PHASE3_DESIGN.md §7, §11): started by ui_screenshots.gd with
## --phase3. Starts a new game in the REAL Phase-3 graveyard world (W3: no more staging over the
## old world) and stages every state through the public APIs of the systems and entities:
## graves dug / buried / marked through Graveyard, the Ostwiese unlocked through
## ExpansionManager, decor placed on valid cells of the baked build mask, real tending spots,
## heard ghosts, reputation „Geachtet“. Shots (1280×720, <out>/ui_p3_<nn>_<name>.jpg):
##   05 build valid (mouse cursor) · 06 build invalid with reason · 13a HUD + quality tooltip ·
##   13b HUD + reputation tooltip · 14 cemetery overview · 15 workbench (Zier / Werkzeug) ·
##   16a reward card with the reputation lines · 16b day summary after sleeping (hut) ·
##   17 Osric's Phase-3 introduction · 18 notice board + „Der Friedhof ist vollendet“.
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://src/ui/tools/ui_screenshots.gd -- --phase3 --out=/abs/dir [--shots=05,14]

const SAVE_DIR := "user://ui_shot_saves_p3"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY_MINUTE := 630
const SEARCH_RADIUS := 2.5
## Where the gravekeeper builds: open yard grass east of the old graves.
const BUILD_SPOT := Vector3(8.6, 0.0, 1.6)
const VALID_WISH := Vector2(8.8, 0.2)
const INVALID_WISH := Vector2(6.4, 3.5)
const INVALID_REASONS: Array[StringName] = [&"grave_ring", &"route", &"dirt_spot"]
## Graves finished through the real API: [plot, marker, examined, shrouded].
const GRAVES := [
	["plot_01", &"gravestone_simple", true, true], ["plot_02", &"gravestone_simple", true, true],
	["plot_03", &"wooden_cross", true, true], ["plot_04", &"gravestone_simple", true, true],
	["plot_05", &"wooden_cross", false, true],
]
## Decor wishes [id, world XZ, rot] – the nearest valid cell is used.
const DECOR := [
	[&"decor_flowerbed", Vector2(10.2, 0.8), 0], [&"decor_bench_wood", Vector2(7.6, 2.6), 0],
	[&"decor_lantern", Vector2(5.2, 3.6), 0], [&"decor_lantern", Vector2(7.6, 3.6), 0],
	[&"decor_grave_vase", Vector2(4.0, 3.7), 0], [&"decor_grave_vase", Vector2(3.6, -9.7), 0],
	[&"decor_lantern", Vector2(6.0, -9.9), 0],
]
## Real tending spots of the layout and their progress (levels 1–3, leaves under the oak).
const SPOTS := {"dirt_y06": 2.4, "dirt_y05": 1.3, "dirt_y03": 3.2, "dirt_y09": 2.2, "dirt_y10": 1.4, "dirt_plot_05": 2.1}

var _out: String = ""
var _only: PackedStringArray = []
var _world: WorldRoot
var _ui: UIRoot
var _player: Player
var _expansion: ExpansionManager
var _decorations: DecorationManager
var _build: BuildMode
var _clean: CleanlinessManager
var _score: CemeteryScore
var _rep: Reputation
var _ghosts: GhostManager
var _graveyard: Graveyard
var _corpses: CorpseManager
## Extra node of the current shot (freed afterwards).
var _extra: Node


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		push_error("[UiShotsP3] --out=<dir> missing")
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
	_graveyard = _world.graveyard
	_corpses = _world.corpse_manager
	_expansion = _system("Expansion") as ExpansionManager
	_decorations = _system("Decorations") as DecorationManager
	_build = _system("BuildMode") as BuildMode
	_clean = _system("Cleanliness") as CleanlinessManager
	_score = _system("CemeteryScore") as CemeteryScore
	_rep = _system("Reputation") as Reputation
	_ghosts = _system("Ghosts") as GhostManager
	_stage()
	await get_tree().process_frame
	await _shot("05", "build_valid", _build_shot.bind(true))
	await _shot("06", "build_invalid", _build_shot.bind(false))
	await _shot("13a", "hud_quality_tooltip", _tooltip_shot.bind(true))
	await _shot("13b", "hud_reputation_tooltip", _tooltip_shot.bind(false))
	await _shot("14", "overview", _overview_shot)
	await _shot("15", "workbench", _workbench_shot)
	await _shot("16a", "reward_card", _reward_shot)
	await _shot("17", "osric_phase3", _osric_shot)
	await _shot("16b", "day_summary", _day_summary_shot)
	await _shot("18", "cemetery_complete", _complete_shot)
	for slot: int in [0, 1]:
		SaveManager.delete_save(slot)
	SaveManager.save_dir = SaveManager.DEFAULT_SAVE_DIR
	get_tree().quit()


func _shot(index: String, shot_name: String, setup: Callable) -> void:
	if not _only.is_empty() and not index in _only:
		return
	await setup.call()
	_ui.hud.refresh_objective()
	for i: int in SETTLE_FRAMES:
		await get_tree().process_frame
	var path := _out.path_join("ui_p3_%s_%s.jpg" % [index, shot_name])
	get_viewport().get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[UiShotsP3] ", path)
	_build.exit()
	_ui.close_all()
	UIState.clear()
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	if is_instance_valid(_extra):
		_extra.queue_free()
	_extra = null
	await get_tree().process_frame


# --- staging (real systems only) ----------------------------------------------------------

## Day 5, 10:30: five finished graves, the Ostwiese unlocked, decor, weeds and leaves, heard
## ghosts, reputation „Geachtet“, decor pieces and resources in the pack.
func _stage() -> void:
	TimeManager.set_time(5, DAY_MINUTE)
	# Today's corpse is already buried (no body on the bier in the shots).
	_corpses.load_state({"last_delivery_day": 5})
	for spec: Array in GRAVES:
		_finish_grave(spec[0], spec[1], spec[2], spec[3], TimeManager.day - 2)
	GameState.stats[&"burials"] = GRAVES.size()
	_expansion.unlock(&"east")
	_decorations.free_build = true
	for spec: Array in DECOR:
		_place_near(spec[0], spec[1], int(spec[2]))
	_decorations.free_build = false
	_clean.load_state({"last_total": TimeManager.total_minutes(), "spots": SPOTS})
	_ghosts.load_state({"heard": {"plot_01": 4, "plot_02": 4, "plot_03": 4, "plot_05": 4}, "gifts": {"plot_01": 4}})
	_rep.change(38 - _rep.value(), "Aufnahme")
	var inv := _player.inventory
	for entry: Array in [[&"decor_bench_wood", 2], [&"decor_bench_stone", 1], [&"decor_flowerbed", 1],
			[&"decor_grave_vase", 3], [&"decor_lantern", 2], [&"decor_path_gravel", 8], [&"coin", 23], [&"wood", 6],
			[&"stone", 4], [&"seeds", 3], [&"iron_fittings", 1]]:
		inv.add_item(entry[0], entry[1])
	_score.refresh(true)
	_ui.hud.refresh_all()
	UIState.clear()
	_ui.close_all()
	_ui.notifications.clear()
	_ui.reward_card.visible = false


## A fresh corpse buried in `plot` with `marker` through the real Graveyard API.
func _finish_grave(plot_id: String, marker: StringName, examined: bool, shrouded: bool, _day: int) -> void:
	var grave := _graveyard.get_grave(plot_id)
	if grave == null or grave.state != GraveRecord.State.EMPTY:
		return
	var plot := _world.get_node_by_layout_id(plot_id) as Node3D
	var record := _corpses.spawn_corpse(null, plot.global_transform, &"ground")
	record.examined = examined
	record.shrouded = shrouded
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	_graveyard.dig(plot_id)
	_graveyard.bury(plot_id, record.id)
	_player.inventory.add_item(marker, 1)
	_graveyard.place_marker(plot_id, marker, _player.inventory)


func _place_near(id: StringName, wish: Vector2, rot: int) -> void:
	var cell: Variant = _find_cell(id, wish, rot, [BuildGrid.REASON_OK])
	if cell == null or _decorations.place(id, cell, rot, null) == "":
		push_warning("[UiShotsP3] no valid cell for %s near %s" % [id, wish])


## Nearest cell to `wish` whose can_place reason is one of `reasons` (null = none).
func _find_cell(id: StringName, wish: Vector2, rot: int, reasons: Array) -> Variant:
	var mask := _decorations.mask
	var centre := mask.world_to_cell(wish)
	var reach := ceili(SEARCH_RADIUS / mask.cell)
	var best: Variant = null
	var best_d := INF
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var c := centre + Vector2i(dx, dz)
			var d := Vector2(dx, dz).length()
			if d < best_d and _decorations.can_place(id, c, rot, _player.inventory, _player) in reasons:
				best = c
				best_d = d
	return best


func _place_player(at: Vector3, facing: float = 0.0) -> void:
	at.y = _world.ground_height(Vector2(at.x, at.z))
	_player.global_transform = Transform3D(Basis(Vector3.UP, facing), at)
	_player.velocity = Vector3.ZERO
	_world.get_node(^"CameraRig").call(&"snap")


func _system(node_name: String) -> Node:
	return _world.get_node(NodePath("Systems/" + node_name))


# --- shots ------------------------------------------------------------------------------------

## Build mode with the mouse over a valid / invalid cell for the wooden bench.
func _build_shot(valid: bool) -> void:
	_place_player(BUILD_SPOT)
	await get_tree().process_frame
	_build.enter()
	_build.select(&"decor_bench_wood")
	var reasons: Array = [BuildGrid.REASON_OK] if valid else INVALID_REASONS
	var anchor: Variant = _find_cell(&"decor_bench_wood", VALID_WISH if valid else INVALID_WISH, 0, reasons)
	if anchor == null:
		push_warning("[UiShotsP3] no %s cell for the build shot" % ("valid" if valid else "invalid"))
		return
	var size := BuildGrid.rotated_size(Vector2i(3, 1), 0)
	var cursor: Vector2i = anchor + Vector2i((size.x - 1) / 2, (size.y - 1) / 2)
	var at := _decorations.mask.cell_to_world(cursor)
	var cam := get_viewport().get_camera_3d()
	_build.mouse_active = true
	_build.mouse_position = cam.unproject_position(Vector3(at.x, _world.ground_height(at), at.y))
	_build.call(&"_update_cursor")


## The engine only opens tooltips for a real pointer (none under xvfb), so the shot draws the
## same popup the engine would: TooltipPanel + TooltipLabel of the theme with the row's
## tooltip_text, just below the hovered HUD line.
func _tooltip_shot(quality: bool) -> void:
	_place_player(BUILD_SPOT)
	await get_tree().process_frame
	var row: Control = _ui.hud.quality_row if quality else _ui.hud.reputation_row
	var tip := PanelContainer.new()
	tip.name = "ShotTooltip"
	tip.theme_type_variation = &"TooltipPanel"
	var label := UIKit.label(row.tooltip_text, &"TooltipLabel")
	tip.add_child(label)
	_ui.root_control.add_child(tip)
	await get_tree().process_frame
	var r := row.get_global_rect()
	tip.position = Vector2(r.end.x - tip.size.x, r.end.y + 18.0)
	_extra = tip


func _overview_shot() -> void:
	_place_player(BUILD_SPOT)
	_ui.open_overview()


func _workbench_shot() -> void:
	var bench := _world.get_node_by_layout_id("workbench") as Workbench
	_place_player(bench.global_position + Vector3(0.6, 0.0, 1.4), PI)
	await get_tree().process_frame
	bench.interact(_player)


## plot_07 (Ostwiese) finished through its GravePlot like a player (examined, shrouded, gravestone):
## the reward card shows the reputation bonus and the reputation event.
func _reward_shot() -> void:
	var plot := _world.get_node_by_layout_id("plot_07") as GravePlot
	# In front of the plot (the oak crowns south of the old yard would hide plot_06).
	_place_player(plot.global_position + Vector3(0.0, 0.0, 1.6), PI)
	await get_tree().process_frame
	var record := _corpses.spawn_corpse(null, plot.global_transform.translated(Vector3(1.4, 0.0, 1.2)), &"ground")
	record.examined = true
	record.shrouded = true
	if record.needs_valuables_decision():
		record.valuables_decision = CorpseRecord.DECISION_LEFT
	_graveyard.dig("plot_07")
	_graveyard.bury("plot_07", record.id)
	_player.inventory.add_item(&"gravestone_simple", 1)
	if _player.inventory.has(&"wooden_cross"):
		plot.interact(_player)
		plot.request_marker(&"gravestone_simple")
	else:
		plot.interact(_player)


## Morning: Osric at the gate starts his Phase-3 introduction (p3_intro, day ≥ 2).
func _osric_shot() -> void:
	TimeManager.set_time(TimeManager.day + 1, 480)
	UIState.clear()
	_ui.close_all()
	var npc := _world.get_node_by_layout_id("npc_carter") as Node3D
	for i: int in 5:
		await get_tree().process_frame
	GameState.set_flag(&"met_carter", true)
	_place_player(npc.global_position + Vector3(-1.2, 0.0, -1.0), PI * 0.75)
	await get_tree().process_frame
	_ui.open_dialogue(&"carter", npc)
	# Greeting → (remarks) → the Phase-3 introduction: the first choice until Osric talks about
	# the Ostwiese.
	for i: int in 6:
		if _ui.dialogue_box.current_text().contains("Ostwiese") or not _ui.dialogue_box.is_active():
			break
		_ui.dialogue_box.choose(0)
	_ui.dialogue_box.text_label.visible_ratio = 1.0
	_ui.dialogue_box.chars_per_second = 0.0


## Sleeping in the hut: the day summary with stipend, reputation change and weedy spots.
func _day_summary_shot() -> void:
	_ui.dialogue_box.chars_per_second = 110.0
	UIState.clear()
	_ui.close_all()
	TimeManager.set_time(TimeManager.day, 1290)
	var interior := get_tree().get_first_node_in_group(HutInterior.GROUP) as HutInterior
	HutPortal.arrive(_player, interior.spawn_transform(), true)
	await get_tree().process_frame
	var bed := interior.get_node(^"Entities/bed") as Bed
	_player.global_position = bed.global_position + Vector3(0.9, 0.0, 0.4)
	# "Today" = since the last sleep: one burial (the reward shot) and its payment.
	GameState.set_flag(&"day_burials_base", GameState.get_stat(&"burials") - 1)
	GameState.set_flag(&"day_coins_base", _player.inventory.count(&"coin") - 11)
	bed.interact(_player)


## All sections unlocked, every free plot finished through the Graveyard → the completion
## panel over the notice board at the gate.
func _complete_shot() -> void:
	UIState.clear()
	_ui.close_all()
	HutPortal.arrive(_player, (_world.get_node_by_layout_id("hut_door") as HutDoor).exit_transform(), false)
	_expansion.unlock(&"north")
	# The corpse still on the bier (Osric's morning) goes into the first free plot, then every
	# other free plot is finished – the clock stays at 06:00 (no new delivery in the shot).
	for r: CorpseRecord in _corpses.records():
		if r.location != CorpseRecord.LOCATION_BURIED:
			for g: GraveRecord in _graveyard.graves():
				if g.state == GraveRecord.State.EMPTY:
					r.examined = true
					r.shrouded = true
					if r.needs_valuables_decision():
						r.valuables_decision = CorpseRecord.DECISION_LEFT
					_graveyard.dig(g.id)
					_graveyard.bury(g.id, r.id)
					_player.inventory.add_item(&"gravestone_simple", 1)
					_graveyard.place_marker(g.id, &"gravestone_simple", _player.inventory)
					break
	for g: GraveRecord in _graveyard.graves():
		if g.state == GraveRecord.State.EMPTY:
			_finish_grave(g.id, &"gravestone_simple", true, true, TimeManager.day)
	var board := _world.get_node_by_layout_id("notice_board") as Node3D
	# South-east of the board: it shows above the panel, left of the gate.
	_place_player(board.global_position + Vector3(4.5, 0.0, 2.6), PI)

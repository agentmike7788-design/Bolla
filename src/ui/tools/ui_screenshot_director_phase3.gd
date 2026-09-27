extends Node
## QA director, Phase-3 UI (docs/PHASE3_DESIGN.md §7, §11): started by ui_screenshots.gd with
## --phase3. Starts a new game in the graveyard world and stages the state only through the
## public APIs of the Phase-3 systems. Where the world does not have them yet (the W-Welt
## package adds them to the builder), the director adds the system nodes, a simple build mask
## over the old yard, a few tending spots and off-screen obstacles at runtime – the world files
## stay untouched. Shots (1280×720, <out>/ui_p3_<nn>_<name>.jpg):
##   01 build bar valid · 02 build bar invalid with reason · 03 reputation tooltip ·
##   04 cemetery overview · 05 day summary · 06 cemetery-complete summary.

const SAVE_DIR := "user://ui_shot_saves_p3"
const SETTLE_FRAMES := 30
const JPG_QUALITY := 0.9
const DAY_MINUTE := 630
## Yard build mask (world XZ): inside the fence, cell 0.5 m.
const MASK_ORIGIN := Vector2(-11.5, -12.0)
const MASK_SIZE := Vector2i(46, 43)
const PLOT_BLOCK := Vector2(0.6, 1.1)
const PLOT_RING := 0.5
## The yard path (layout "path", ROUTE flag = "Weg freihalten") and its half width.
const ROUTE_POINTS: PackedVector2Array = [Vector2(1.2, 13.0), Vector2(0.8, 8.0), Vector2(0.0, 4.0), Vector2(-0.8, 0.5),
		Vector2(-2.2, -2.8), Vector2(-4.2, -4.6)]
const ROUTE_HALF := 0.85
const HUT_RECT := Rect2(-8.5, -10.0, 6.5, 5.3)
const OAK := Vector2(-7.6, 3.2)
const OAK_RADIUS := 0.9
## Where the gravekeeper builds: the open grass along the east fence, north of plot_06.
const BUILD_SPOT := Vector3(9.4, 0.0, -1.2)
const VALID_CURSOR := Vector3(9.4, 0.0, 0.6)
const INVALID_CURSOR := Vector3(8.3, 0.0, 0.9)
const GRAVES := [
	["plot_01", 9, &"gravestone_simple"], ["plot_02", 9, &"gravestone_simple"], ["plot_03", 8, &"wooden_cross"],
	["plot_04", 9, &"gravestone_simple"], ["plot_05", 7, &"wooden_cross"],
]
const DECOR := [
	[&"decor_flowerbed", Vector2(10.2, 0.4), 0], [&"decor_bench_wood", Vector2(8.3, 2.4), 0],
	[&"decor_lantern", Vector2(5.2, 3.8), 0], [&"decor_lantern", Vector2(7.6, 3.8), 0],
	[&"decor_grave_vase", Vector2(4.0, 3.5), 0],
	[&"decor_path_gravel", Vector2(0.4, 6.0), 0], [&"decor_path_gravel", Vector2(0.3, 5.5), 0],
	[&"decor_path_gravel", Vector2(0.2, 5.0), 0], [&"decor_path_gravel", Vector2(0.1, 4.5), 0],
]
## Tending spots near the plots: [id, kind, x, z, level, grave_id].
const SPOTS := [
	["yard_w01", &"weeds", 10.6, -1.0, 2.4, ""], ["yard_w02", &"weeds", 7.8, 0.2, 1.3, ""],
	["yard_l01", &"leaves", -8.6, 1.6, 2.2, ""], ["yard_w03", &"weeds", -3.0, 6.8, 0.4, ""],
	["dirt_plot_04", &"weeds", 4.0, 5.9, 1.1, "plot_04"], ["dirt_plot_05", &"weeds", 6.4, 6.0, 0.0, "plot_05"],
	["dirt_plot_06", &"weeds", 8.8, 5.9, 0.0, "plot_06"],
]
## Off-screen obstacles of the new sections (east of the fence).
const OBSTACLES := [
	["east_bramble_01", &"east", &"bramble"], ["east_bramble_02", &"east", &"bramble"], ["east_rubble_01", &"east", &"rubble"],
	["east_gap_01", &"east", &"fence_gap"], ["east_gap_02", &"east", &"fence_gap"],
	["north_hedge", &"north", &"hedge"], ["north_stump_01", &"north", &"stump"], ["north_gap_01", &"north", &"fence_gap"],
]

var _out: String = ""
var _only: PackedStringArray = []
var _world: Node3D
var _ui: UIRoot
var _player: Player
var _systems: Node
var _expansion: ExpansionManager
var _decorations: DecorationManager
var _build: BuildMode
var _clean: CleanlinessManager
var _score: CemeteryScore
var _rep: Reputation
var _ghosts: GhostManager
var _graveyard: Graveyard
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
	_world = get_tree().current_scene as Node3D
	_ui = _world.get_node(^"UI") as UIRoot
	_player = _world.get_node(^"Player") as Player
	_graveyard = _world.get_node(^"Systems/Graveyard") as Graveyard
	_systems = _world.get_node(^"Systems")
	_add_systems()
	await get_tree().process_frame
	_stage()
	await _shot("01", "build_valid", _build_shot.bind(VALID_CURSOR))
	await _shot("02", "build_invalid", _build_shot.bind(INVALID_CURSOR))
	await _shot("03", "reputation_tooltip", _tooltip_shot)
	await _shot("04", "overview", _overview_shot)
	await _shot("05", "day_summary", _day_summary_shot)
	await _shot("06", "cemetery_complete", _complete_shot)
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
	_ui.notifications.clear()
	_ui.reward_card.visible = false
	if is_instance_valid(_extra):
		_extra.queue_free()
	_extra = null
	await get_tree().process_frame


# --- staging ----------------------------------------------------------------------------------

## Adds every Phase-3 system the world does not have yet (same node names as §3.1).
func _add_systems() -> void:
	var decor := _world.get_node(^"Decor") as Node3D
	var p3 := Node3D.new()
	p3.name = "Phase3Shots"
	decor.add_child(p3)
	if _first(&"expansion") == null:
		for spec: Array in OBSTACLES:
			var o := ClearableObstacle.new()
			o.name = spec[0]
			o.obstacle_id = spec[0]
			o.section_id = spec[1]
			o.kind = spec[2]
			o.position = Vector3(40.0 + p3.get_child_count() * 3.0, 0.0, -40.0)
			p3.add_child(o)
		_add(ExpansionManager.new(), "Expansion")
	_expansion = _first(&"expansion") as ExpansionManager
	if _first(&"reputation") == null:
		_add(Reputation.new(), "Reputation")
	_rep = _first(&"reputation") as Reputation
	if _first(&"decorations") == null:
		var placed := Node3D.new()
		placed.name = "Placed"
		p3.add_child(placed)
		var d := DecorationManager.new()
		d.mask = _yard_mask()
		_add(d, "Decorations")
		d.container_path = d.get_path_to(placed)
	_decorations = _first(&"decorations") as DecorationManager
	if _first(&"build_mode") == null:
		_add(BuildMode.new(), "BuildMode")
	_build = _first(&"build_mode") as BuildMode
	if _first(&"cleanliness") == null:
		for spec: Array in SPOTS:
			var s := DirtSpot.new()
			s.name = spec[0]
			s.spot_id = spec[0]
			s.kind = spec[1]
			s.section_id = &"yard"
			s.grave_id = spec[5]
			s.position = Vector3(spec[2], 0.0, spec[3])
			p3.add_child(s)
		_add(CleanlinessManager.new(), "Cleanliness")
	_clean = _first(&"cleanliness") as CleanlinessManager
	if _first(&"ghosts") == null:
		var container := Node3D.new()
		container.name = "Ghosts"
		p3.add_child(container)
		var g := GhostManager.new()
		_add(g, "Ghosts")
		g.container_path = g.get_path_to(container)
	_ghosts = _first(&"ghosts") as GhostManager
	if _first(&"cemetery_score") == null:
		_add(CemeteryScore.new(), "CemeteryScore")
	_score = _first(&"cemetery_score") as CemeteryScore


func _add(node: Node, node_name: String) -> void:
	node.name = node_name
	_systems.add_child(node)


## Section 1 inside the fence; plots BLOCKED with a grave ring; the gate path ROUTE; the hut
## corner BLOCKED.
func _yard_mask() -> BuildMask:
	var mask := BuildMask.new()
	mask.origin = MASK_ORIGIN
	mask.cell = 0.5
	mask.size = MASK_SIZE
	var cells := PackedByteArray()
	cells.resize(MASK_SIZE.x * MASK_SIZE.y)
	var plots: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(&"grave_plot"):
		if node is Node3D:
			plots.append(Vector2((node as Node3D).global_position.x, (node as Node3D).global_position.z))
	for z: int in MASK_SIZE.y:
		for x: int in MASK_SIZE.x:
			var p := mask.cell_to_world(Vector2i(x, z))
			var flags := 1
			if HUT_RECT.has_point(p) or p.distance_to(OAK) <= OAK_RADIUS:
				flags = BuildMask.BLOCKED
			elif _route_distance(p) <= ROUTE_HALF:
				flags |= BuildMask.ROUTE
			for c: Vector2 in plots:
				var off := (p - c).abs()
				if off.x <= PLOT_BLOCK.x and off.y <= PLOT_BLOCK.y:
					flags = BuildMask.BLOCKED
					break
				if off.x <= PLOT_BLOCK.x + PLOT_RING and off.y <= PLOT_BLOCK.y + PLOT_RING:
					flags |= BuildMask.GRAVE_RING
			cells[z * MASK_SIZE.x + x] = flags
	mask.cells = cells
	return mask


static func _route_distance(p: Vector2) -> float:
	var best := INF
	for i: int in ROUTE_POINTS.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ROUTE_POINTS[i], ROUTE_POINTS[i + 1])))
	return best


## Five finished graves, decor, some weeds, heard ghosts, reputation „Geachtet“ – day 5.
func _stage() -> void:
	TimeManager.set_time(5, DAY_MINUTE)
	# Today's corpse is already buried (no body on the bier in the shots).
	(_world.get_node(^"Systems/CorpseManager") as CorpseManager).load_state({"last_delivery_day": 5})
	GameState.stats[&"burials"] = 5
	var list: Array = []
	for i: int in GRAVES.size():
		var spec: Array = GRAVES[i]
		list.append({"id": spec[0], "state": int(GraveRecord.State.MARKED), "marker_id": spec[2], "quality": spec[1],
				"completed_day": i + 1})
	_graveyard.load_state({"graves": list})
	_graveyard.broadcast_state()
	_decorations.free_build = true
	for spec: Array in DECOR:
		var cell := _decorations.mask.world_to_cell(spec[1])
		if _decorations.place(spec[0], cell, spec[2], null) == "":
			push_warning("[UiShotsP3] could not place %s at %s (%s)" % [spec[0], spec[1],
					_decorations.can_place(spec[0], cell, spec[2])])
	_decorations.free_build = false
	var spots := {}
	for spec: Array in SPOTS:
		spots[spec[0]] = spec[4]
	_clean.load_state({"last_total": TimeManager.total_minutes(), "spots": spots})
	_ghosts.load_state({"heard": {"plot_01": 4, "plot_02": 4, "plot_03": 4, "plot_05": 4}, "gifts": {"plot_01": 4}})
	_rep.change(38 - _rep.value(), "Aufnahme")
	var inv := _player.inventory
	for entry: Array in [[&"decor_bench_wood", 2], [&"decor_bench_stone", 1], [&"decor_flowerbed", 1],
			[&"decor_grave_vase", 3], [&"decor_lantern", 2], [&"decor_path_gravel", 8], [&"coin", 23], [&"wood", 6], [&"stone", 4]]:
		inv.add_item(entry[0], entry[1])
	_score.refresh(true)
	_ui.hud.refresh_all()
	_ui.notifications.clear()


func _place_player(at: Vector3, facing: float = 0.0) -> void:
	_player.global_transform = Transform3D(Basis(Vector3.UP, facing), at)
	_player.velocity = Vector3.ZERO
	var rig := _world.get_node(^"CameraRig")
	rig.call(&"snap")


# --- shots ------------------------------------------------------------------------------------

func _build_shot(cursor_at: Vector3) -> void:
	_place_player(BUILD_SPOT)
	await get_tree().process_frame
	_build.enter()
	_build.select(&"decor_bench_wood")
	var cam := get_viewport().get_camera_3d()
	_build.mouse_active = true
	_build.mouse_position = cam.unproject_position(cursor_at)


## The engine only opens tooltips for a real pointer (none under xvfb), so the shot draws the
## same popup the engine would: TooltipPanel + TooltipLabel of the theme with the row's
## tooltip_text, just below the hovered reputation line.
func _tooltip_shot() -> void:
	_place_player(BUILD_SPOT)
	await get_tree().process_frame
	var row := _ui.hud.reputation_row
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
	_ui.open_overview()


func _day_summary_shot() -> void:
	_expansion.unlock(&"east")
	_rep.apply_daily(TimeManager.day + 1)
	EventBus.ui_panel_requested.emit(&"day_summary", {"day": 5, "burials_today": 1, "coins_today": 11, "total": 0, "rating": &"neglected"})


func _complete_shot() -> void:
	var list: Array = []
	for g: GraveRecord in _graveyard.graves():
		var d := g.to_dict()
		if g.state != GraveRecord.State.OLD and g.state != GraveRecord.State.LOCKED:
			d.state = int(GraveRecord.State.MARKED)
			d.quality = 9 if int(d.quality) == 0 else d.quality
			d.marker_id = &"gravestone_simple" if StringName(d.marker_id) == &"" else d.marker_id
		list.append(d)
	_graveyard.load_state({"graves": list})
	_graveyard.broadcast_state()
	_ghosts.load_state({"heard": {"plot_01": 9, "plot_02": 9, "plot_03": 9, "plot_04": 9, "plot_06": 9}, "gifts": {}})
	GameState.stats[&"burials"] = 6
	_score.refresh(true)
	_ui.open_panel(&"slice_summary", _graveyard.summary_context())


func _first(group: StringName) -> Node:
	return get_tree().get_first_node_in_group(group)

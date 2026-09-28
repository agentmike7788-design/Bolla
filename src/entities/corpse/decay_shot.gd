extends SceneTree
## P4 review shot (not part of the game): one corpse on the morgue table in the vertical-slice
## world in the four decay stages plus a juniper-smoked one, composed side by side into one
## image (docs/PHASE4_DESIGN.md §2.5, §8). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/entities/corpse/decay_shot.gd \
##       -- --out=/abs/file.jpg [--minute=600] [--distance=4.2] [--overview=/abs/file.jpg] [--layout]
## Real systems for the corpse (CorpseManager.spawn_corpse on the table slot); the stages are
## shown by writing the record's freshness and refreshing the node (smoke: DecayVisual.apply
## with balm_active, since CorpsePrep.is_balm_active is still P2's stub).

const SETTLE_FRAMES := 40
const STATE_FRAMES := 45
const CROP := Vector2i(560, 380)
## [label, freshness, balm]
const STATES := [
	["Frisch", 0.9, false], ["Welk", 0.45, false], ["Verwesend", 0.2, false], ["Verfallen", 0.04, false],
	["Verwesend + Wacholder", 0.2, true],
]

var _out: String = ""
var _overview: String = ""
var _minute: int = 600
var _distance: float = 4.2
## --layout: one more crop, dressed in the gown and laid out (sprig + candle stub).
var _layout: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--overview="):
			_overview = arg.trim_prefix("--overview=")
		elif arg.begins_with("--minute="):
			_minute = arg.trim_prefix("--minute=").to_int()
		elif arg == "--layout":
			_layout = true
		elif arg.begins_with("--distance="):
			_distance = arg.trim_prefix("--distance=").to_float()
	if _out == "":
		printerr("usage: -- --out=/abs/file.jpg")
		quit(2)
		return
	var saves := root.get_node(^"SaveManager")
	var bus := root.get_node(^"EventBus")
	saves.set("save_dir", "user://shot_saves")
	saves.call(&"new_game")
	await Signal(bus, &"new_game_started")
	await process_frame
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	clock.call(&"load_state", {"day": 2, "minute_of_day": _minute})
	(world.get_node(^"UI") as CanvasLayer).visible = false
	var manager := world.get_node(^"Systems/CorpseManager")
	var table := world.get_node(^"Entities/morgue_table") as Node3D
	var record: RefCounted = manager.call(&"spawn_corpse", null, table.call(&"slot_transform"), &"table")
	var player := world.get_node(^"Player") as Node3D
	player.global_position = table.global_position + Vector3(2.4, 0.0, 1.6)
	var node: Node3D = manager.call(&"get_corpse_node", record.get("id"))
	var visual: Node = node.get_node(^"DecayVisual")
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	world.add_child(anchor)
	anchor.global_position = node.global_position + Vector3(0, -0.55, 0)
	rig.set("target", anchor)
	rig.set("zoom_min", 2.0)
	rig.call(&"set_distance", _distance)
	rig.call(&"snap")
	for i: int in SETTLE_FRAMES:
		await process_frame
	var world_centre := node.global_position + Vector3(0, 0.2, 0)
	var states: Array = STATES.duplicate()
	if _layout:
		states.append(["Hergerichtet", 0.9, false])
	var sheet := Image.create(CROP.x * states.size(), CROP.y, false, Image.FORMAT_RGB8)
	for i: int in states.size():
		var state: Array = states[i]
		if state[0] == "Hergerichtet":
			record.set("dress", &"gown")
			record.set("shrouded", true)
			record.set("washed", true)
			record.set("laid_out", true)
		record.set("freshness", state[1])
		node.call(&"refresh")
		if state[2]:
			var stage: StringName = node.get_script().call(&"stage_of", state[1], null)
			visual.call(&"apply", state[1], stage, true, false)
		for f: int in STATE_FRAMES:
			await process_frame
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		var vis := root.get_visible_rect().size
		var centre := root.get_camera_3d().unproject_position(world_centre) / vis * Vector2(img.get_size())
		var origin := (Vector2i(centre) - CROP / 2).clamp(Vector2i.ZERO, img.get_size() - CROP)
		var crop := Rect2i(origin, CROP)
		sheet.blit_rect(img, crop, Vector2i(CROP.x * i, 0))
		print("[DecayShot] %s: overlay %.2f flies %d wisps %d smoke %s" % [state[0], visual.call(&"overlay_amount"),
				visual.call(&"flies"), visual.call(&"wisps"), visual.call(&"smoke_on")])
		if _overview != "" and i == 3:
			_save(img, _overview)
	_save(sheet, _out)
	quit()


func _save(img: Image, path: String) -> void:
	if path.ends_with(".jpg"):
		img.save_jpg(path, 0.9)
	else:
		img.save_png(path)

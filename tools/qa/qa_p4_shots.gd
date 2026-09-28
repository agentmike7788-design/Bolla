extends "res://src/world/graveyard/graveyard_shots_phase4.gd"
## QA (W3, Phase 4) readability shots at the default gameplay camera distance (CameraRig 22 m)
## plus close checks: decaying corpses (flies, smell wisps) day / night, juniper smoke, Ilse at
## the west wall at night, grass under a corpse lying on the ground. Stages through the real
## systems like graveyard_shots_phase4.gd. Needs a real renderer:
##   GODOT=… tools/godot_run.sh --resolution 1280x720 -s res://tools/qa/qa_p4_shots.gd -- --out=/abs/dir [--shots=a,b]

const QA_SHOTS: Array[Dictionary] = [
	{"name": "qa_decay_day_22m", "day": 6, "minute": 700, "focus": Vector2(-1.8, -4.4), "distance": 22.0, "player": Vector2(1.2, -2.8)},
	{"name": "qa_decay_night_22m", "day": 6, "minute": 1350, "focus": Vector2(-1.8, -4.4), "distance": 22.0, "player": Vector2(1.2, -2.8)},
	{"name": "qa_decay_day_12m", "day": 6, "minute": 700, "focus": Vector2(-1.8, -4.4), "distance": 12.0, "player": Vector2(1.2, -2.8)},
	{"name": "qa_smoke_day_22m", "day": 6, "minute": 610, "focus": Vector2(-1.8, -5.0), "distance": 22.0, "player": Vector2(1.2, -2.8), "balm": true},
	{"name": "qa_smoke_day_12m", "day": 6, "minute": 610, "focus": Vector2(-1.8, -5.0), "distance": 12.0, "player": Vector2(1.2, -2.8), "balm": true},
	{"name": "qa_ilse_night_22m", "day": 8, "minute": 1410, "focus": Vector2(-10.0, -3.5), "distance": 22.0, "player": Vector2(-7.5, -1.0)},
	{"name": "qa_ilse_night_12m", "day": 8, "minute": 1410, "focus": Vector2(-11.2, -3.0), "distance": 12.0, "player": Vector2(-8.5, -1.5), "hide": ["Decor/Tree"]},
	{"name": "qa_grass_corpse_8m", "day": 6, "minute": 700, "focus": Vector2(-1.2, -3.6), "distance": 8.0, "player": Vector2(1.6, -2.4)},
]


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=…]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	var saves := root.get_node(^"SaveManager")
	var bus := root.get_node(^"EventBus")
	saves.set("save_dir", "user://qa_p4_shot_saves")
	saves.call(&"new_game")
	await Signal(bus, &"new_game_started")
	await process_frame
	var world := current_scene as Node3D
	var clock := root.get_node(^"TimeManager")
	clock.set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var anchor := Node3D.new()
	anchor.name = "ShotAnchor"
	world.add_child(anchor)
	rig.set("target", anchor)
	rig.set("zoom_min", 3.0)
	for stage: String in ["start", "story_table", "decay", "trader"]:
		clock.call(&"load_state", {"day": 6, "minute_of_day": 500})
		await _apply_p4_stage(world, stage)
	var manager := _system(world, "CorpseManager")
	for shot: Dictionary in QA_SHOTS:
		if not _only.is_empty() and not Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p)):
			continue
		clock.call(&"load_state", {"day": int(shot.day), "minute_of_day": int(shot.minute)})
		var rec: RefCounted = manager.call(&"get_record", _table_corpse)
		var now := (int(shot.day) - 1) * 1440 + int(shot.minute)
		rec.set("balm_windows", PackedInt32Array([now - 5, now + 600]) if bool(shot.get("balm", false)) else PackedInt32Array())
		_refresh_npcs(world)
		_refresh_corpses(world)
		var focus: Vector2 = shot.focus
		var stand: Vector2 = shot.get("player", focus + Vector2(1.5, 2.5))
		player.global_position = Vector3(stand.x, _ground(world, stand), stand.y)
		player.rotation.y = PI
		anchor.global_position = Vector3(focus.x, 0.0, focus.y)
		rig.call(&"set_distance", float(shot.distance))
		rig.call(&"snap")
		var hidden: Array[Node3D] = []
		for path: String in shot.get("hide", []):
			var node := world.get_node(NodePath(path)) as Node3D
			node.visible = false
			hidden.append(node)
		for i: int in SETTLE_FRAMES + 20:
			await process_frame
		var image := root.get_texture().get_image()
		image.save_png(_out.path_join("%s.png" % shot.name))
		print("[QAShots] ", shot.name, " particles=", int(load(DECAY_PLAIN_SCRIPT).call(&"total_live_particles")))
		for node: Node3D in hidden:
			node.visible = true
	quit()

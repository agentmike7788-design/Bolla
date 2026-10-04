extends RefCounted
## G7 Runde 2 shovel series of graveyard_shots.gd (--shovel): the gravekeeper digs plot_01 through
## the real GravePlot.interact (a real timed action) – drawing the shovel from his back, digging
## with it in both hands, putting it back. The player and his AnimationPlayer are stepped by hand
## in fixed steps (the software renderer is far slower than real time), each moment is shot through
## the in-game camera rig and through a closer camera. Writes <out>/shovel_<NN>_<moment>_<cam>.jpg.

const PLOT := "plot_01"
## Where the gravekeeper stands (world offset from the plot centre) and his yaw: at the plot's
## west end facing east (+X), so the camera (looking north, -Z) sees him from the side.
const STAND := Vector3(-1.05, 0.0, 0.45)
const YAW_DEG := 90.0
const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 6
const JPG_QUALITY := 0.9
const GAME_DISTANCE := 14.0
## Close camera: offset from the gravekeeper (world; he faces +X) and look height.
const CLOSE_OFFSET := Vector3(1.9, 1.5, 3.0)
const CLOSE_LOOK := 0.8
## Seconds after the [E] press: drawing (reach, swing), digging (jab, tread, lift, throw); negative =
## seconds after the action has finished (ActionConfig.real_seconds_for): putting it back.
const MOMENTS: Array[Array] = [
	["01_reach", 0.16], ["02_swing", 0.33], ["03_jab", 0.72], ["04_tread", 0.92], ["05_lift", 1.28],
	["06_throw", 1.56], ["07_stow", -0.18], ["08_back", -0.5],
]


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray) -> void:
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var plot := world.get_node(NodePath("Entities/" + PLOT)) as Node3D
	var clock := tree.root.get_node(^"TimeManager")
	clock.call(&"load_state", {"day": 1, "minute_of_day": 640})
	clock.call(&"emit_refresh")
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(YAW_DEG)), plot.global_position + STAND)
	rig.set("target", player)
	rig.call(&"set_distance", GAME_DISTANCE)
	rig.call(&"snap")
	var game_cam := tree.root.get_camera_3d()
	var close := Camera3D.new()
	close.fov = 32.0
	world.add_child(close)
	for i: int in 20:
		await tree.process_frame
	plot.call(&"interact", player)
	var duration := float(player.get(&"_action").get(&"duration"))
	var t := 0.0
	for m: Array in MOMENTS:
		var at := float(m[1]) if float(m[1]) >= 0.0 else duration - float(m[1])
		while t < at:
			player.call(&"_physics_process", STEP)
			anim.advance(STEP)
			t += STEP
			if _emitted_at < 0.0 and player.get_node_or_null(^"EarthClods") != null:
				_emitted_at = t
		_freeze_clods(player, t)
		if not only.is_empty() and not String(m[0]).left(2) in only:
			continue
		for cam_name: String in ["game", "close"]:
			if cam_name == "game":
				game_cam.make_current()
				rig.call(&"snap")
			else:
				close.global_position = player.global_position + CLOSE_OFFSET
				close.look_at(player.global_position + Vector3(0.0, CLOSE_LOOK, 0.0))
				close.make_current()
			for i: int in SETTLE_FRAMES:
				await tree.process_frame
			var path := out.path_join("shovel_%s_%s.jpg" % [m[0], cam_name])
			tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
			print("[Shots] ", path, "  phase=", player.get(&"_animator").get(&"phase"), " clip=", anim.current_animation)
	await _bury(tree, world, player, anim, plot, out, only, game_cam, close, rig)
	game_cam.make_current()
	close.queue_free()
	player.set_physics_process(true)


## 09: burying with a corpse in the arms – the corpse is laid aside while the shovel is out.
static func _bury(tree: SceneTree, world: Node3D, player: CharacterBody3D, anim: AnimationPlayer, plot: Node3D,
		out: String, only: PackedStringArray, game_cam: Camera3D, close: Camera3D, rig: Node3D) -> void:
	if not only.is_empty() and not "09" in only:
		return
	var manager := world.get_node(^"Systems/CorpseManager")
	player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(YAW_DEG)), plot.global_position + STAND)
	var record: RefCounted = manager.call(&"spawn_corpse", null, player.global_transform, &"ground")
	manager.call(&"pick_up", record.get(&"id"), player)
	player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(YAW_DEG)), plot.global_position + STAND)
	if not bool(plot.call(&"can_interact", player)):
		print("[Shots] 09_bury skipped: ", plot.call(&"get_interaction_prompt", player))
		return
	plot.call(&"interact", player)
	var t := 0.0
	while t < 1.3:
		player.call(&"_physics_process", STEP)
		anim.advance(STEP)
		t += STEP
	for cam_name: String in ["game", "close"]:
		if cam_name == "game":
			game_cam.make_current()
			rig.call(&"snap")
		else:
			close.global_position = player.global_position + CLOSE_OFFSET
			close.look_at(player.global_position + Vector3(0.0, CLOSE_LOOK, 0.0))
			close.make_current()
		for i: int in SETTLE_FRAMES:
			await tree.process_frame
		var path := out.path_join("shovel_09_bury_%s.jpg" % cam_name)
		tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
		print("[Shots] ", path, "  clip=", anim.current_animation)
	player.call(&"cancel_timed_action")


## The earth clods are CPU particles running on the real frame time: show them as they are `t` −
## emission seconds into their flight (preprocess) and hold them still while the frame renders.
static var _emitted_at: float = -1.0


static func _freeze_clods(player: Node3D, t: float) -> void:
	var clods := player.get_node_or_null(^"EarthClods") as CPUParticles3D
	if clods == null or _emitted_at < 0.0:
		return
	clods.speed_scale = 1.0
	clods.preprocess = maxf(0.0, t - _emitted_at)
	clods.restart()
	clods.speed_scale = 0.0

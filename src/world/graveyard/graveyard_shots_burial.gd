extends RefCounted
## G7 Runde 2 burial series of graveyard_shots.gd (--burial): the gravekeeper carries a shrouded
## dead to the open plot_01 and buries it through the real GravePlot.interact (the real timed
## action, PlayerBurial): steps to the pit's long side, lays the dead onto the pit floor, stands in
## silence, fills the grave in steps, the fresh mound. The player and his AnimationPlayer are
## stepped by hand in fixed steps (the software renderer is far slower than real time); each moment
## is shot through the in-game camera rig and a closer camera.
## Writes <out>/burial_<NN>_<moment>_<cam>.jpg.

const PLOT := "plot_01"
## Where he waits with the dead (plot-local): a little off the pit's foot end.
const START := Vector3(-1.5, 0.0, 1.1)
const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 6
const JPG_QUALITY := 0.9
const GAME_DISTANCE := 14.0
## Close camera (plot-local; the pit's long axis is Z, he stands at -X): from the foot end, raised,
## looking over the pit at him.
const CLOSE_OFFSET := Vector3(1.7, 2.1, 3.1)
const CLOSE_LOOK := Vector3(-0.3, 0.35, -0.1)
## Seconds after the [E] press (negative = seconds after the action ended).
const MOMENTS: Array[Array] = [
	["01_step", 0.3], ["02_lift", 1.25], ["03_lower", 1.85], ["04_laid", 2.25], ["05_silence", 2.95],
	["06_draw", 3.55], ["07_fill1", 5.35], ["08_fill2", 6.65], ["09_grave", -0.7],
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
	var graveyard := world.get_node(^"Systems/Graveyard")
	var manager := world.get_node(^"Systems/CorpseManager")
	graveyard.call(&"dig", PLOT)
	var start := Transform3D(Basis(Vector3.UP, plot.global_rotation.y + deg_to_rad(60.0)), plot.to_global(START))
	player.global_transform = start
	var record: RefCounted = manager.call(&"spawn_corpse", null, player.global_transform, &"ground")
	record.set(&"shrouded", true)
	tree.root.get_node(^"EventBus").emit_signal(&"corpse_updated", record.get(&"id"))
	manager.call(&"pick_up", record.get(&"id"), player)
	player.global_transform = start
	rig.set("target", player)
	rig.call(&"set_distance", GAME_DISTANCE)
	rig.call(&"snap")
	var game_cam := tree.root.get_camera_3d()
	var close := Camera3D.new()
	close.fov = 34.0
	world.add_child(close)
	for i: int in 20:
		await tree.process_frame
	if not bool(plot.call(&"can_interact", player)):
		print("[Shots] burial skipped: ", plot.call(&"get_interaction_prompt", player))
		return
	plot.call(&"interact", player)
	var duration := float(player.get(&"_action").get(&"duration"))
	var t := 0.0
	var emitted := -1.0
	for m: Array in MOMENTS:
		var at := float(m[1]) if float(m[1]) >= 0.0 else duration - float(m[1])
		while t < at:
			player.call(&"_physics_process", STEP)
			anim.advance(STEP)
			t += STEP
			var clods := player.get_node_or_null(^"EarthClods") as CPUParticles3D
			if clods != null and clods.emitting and emitted < 0.0:
				emitted = t
		_freeze_clods(player, t, emitted)
		if not only.is_empty() and not String(m[0]).left(2) in only:
			continue
		for cam_name: String in ["game", "close"]:
			if cam_name == "game":
				game_cam.make_current()
				rig.call(&"snap")
			else:
				close.global_position = plot.to_global(CLOSE_OFFSET)
				close.look_at(plot.to_global(CLOSE_LOOK))
				close.make_current()
			for i: int in SETTLE_FRAMES:
				await tree.process_frame
			var path := out.path_join("burial_%s_%s.jpg" % [m[0], cam_name])
			tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
			var burial: RefCounted = player.get(&"_animator").get(&"burial")
			print("[Shots] ", path, "  stage=", burial.get(&"stage"), " throws=", burial.get(&"throws"),
					" clip=", anim.current_animation)
	game_cam.make_current()
	close.queue_free()
	player.set_physics_process(true)


## Earth clods of the last throw shown `t` − emission seconds into their flight, held still.
static func _freeze_clods(player: Node3D, t: float, emitted: float) -> void:
	var clods := player.get_node_or_null(^"EarthClods") as CPUParticles3D
	if clods == null or emitted < 0.0:
		return
	clods.speed_scale = 1.0
	clods.preprocess = clampf(t - emitted, 0.0, clods.lifetime * 0.95)
	clods.restart()
	clods.speed_scale = 0.0

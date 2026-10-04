extends RefCounted
## G7 Runde 2 (Werkzeuge) series of graveyard_shots.gd (--tools): the gravekeeper draws, uses and
## stows the axe at a bramble (chop), the pickaxe at a quarry boulder (pick), the hammer at a grave
## plot (marker), the chisel and the saw at the workbench – each as the timed action with the clip
## of its data (clearable data / ToolAnimConfig.action_clips). The player and his AnimationPlayer are
## stepped by hand in fixed steps; every moment is shot through the in-game camera rig and a closer
## camera. Writes <out>/tools_<series>_<NN>_<moment>_<cam>.jpg.

const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 6
const JPG_QUALITY := 0.9
const GAME_DISTANCE := 14.0
const CLOSE_OFFSET := Vector3(1.6, 1.4, 3.2)
const CLOSE_LOOK := 0.85
## series -> [[entity, stand offset (world, from the entity), yaw (deg; 90 = facing +X), clip], ...]
## and its moments [name, clip, fraction] (fraction of the clip's first pass).
const SERIES := {
	"axe": {
		"at": [["Entities/obs_l_bramble_1", Vector3(-1.75, 0.0, 0.2), 90.0, &"chop"]],
		"moments": [["01_bag", &"axe_draw", 0.45], ["02_ready", &"chop", 0.1], ["03_over", &"chop", 0.34],
				["04_hit", &"chop", 0.44], ["05_follow", &"chop", 0.58], ["06_lift", &"chop", 0.8],
				["07_stow", &"axe_stow", 0.45], ["08_back", &"idle", 0.1]],
	},
	"pick": {
		"at": [["Entities/obs_q_boulder_1", Vector3(-1.5, 0.0, 0.2), 90.0, &"pick"]],
		"moments": [["01_bag", &"pick_draw", 0.45], ["02_ready", &"pick", 0.1], ["03_over", &"pick", 0.36],
				["04_hit", &"pick", 0.47], ["05_pry", &"pick", 0.6], ["06_lift", &"pick", 0.8],
				["07_stow", &"pick_stow", 0.45], ["08_back", &"idle", 0.1]],
	},
	"hammer": {
		"at": [["Entities/plot_02", Vector3(-1.05, 0.0, 0.45), 90.0, &"hammer"],
				["Entities/workbench", Vector3(-0.9, 0.0, 0.0), 90.0, &"chisel"],
				["Entities/workbench", Vector3(-0.9, 0.0, 0.0), 90.0, &"saw"]],
		"moments": [["01_bag", &"hammer_draw", 0.45], ["02_up", &"hammer", 0.15], ["03_hit", &"hammer", 0.52],
				["04_chisel_up", &"chisel", 0.15], ["05_chisel_hit", &"chisel", 0.52],
				["06_saw_push", &"saw", 0.1], ["07_saw_pull", &"saw", 0.55], ["08_stow", &"saw_stow", 0.45]],
	},
}


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray) -> void:
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var clock := tree.root.get_node(^"TimeManager")
	clock.call(&"load_state", {"day": 1, "minute_of_day": 640})
	clock.call(&"emit_refresh")
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	rig.set("target", player)
	rig.call(&"set_distance", GAME_DISTANCE)
	var game_cam := tree.root.get_camera_3d()
	var close := Camera3D.new()
	close.fov = 32.0
	world.add_child(close)
	for series: String in SERIES:
		if not only.is_empty() and not series in only:
			continue
		var spec: Dictionary = SERIES[series]
		var stations: Array = spec["at"]
		var station := 0
		await _start(tree, world, player, rig, stations[0])
		for m: Array in spec["moments"]:
			var clip: StringName = m[1]
			# the next station once a moment asks for its clip
			if station + 1 < stations.size() and stations[station + 1][3] == clip:
				station += 1
				player.call(&"cancel_timed_action")
				player.call(&"reset_tool")
				await _start(tree, world, player, rig, stations[station])
			if clip == &"idle" or String(clip).ends_with("_stow"):
				if player.get(&"_action") != null:
					player.call(&"cancel_timed_action")
			_step_until(player, anim, clip, float(m[2]))
			_freeze_bursts(player)
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
				var path := out.path_join("tools_%s_%s_%s.jpg" % [series, m[0], cam_name])
				tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
				print("[Shots] ", path, "  clip=", anim.current_animation, " tool=", player.call(&"held_tool"))
		player.call(&"cancel_timed_action")
		player.call(&"reset_tool")
	game_cam.make_current()
	close.queue_free()
	player.set_physics_process(true)


static func _start(tree: SceneTree, world: Node3D, player: CharacterBody3D, rig: Node3D, at: Array) -> void:
	var target := world.get_node(NodePath(String(at[0]))) as Node3D
	player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(at[2]))), target.global_position + (at[1] as Vector3))
	rig.call(&"snap")
	for i: int in 10:
		await tree.process_frame
	player.call(&"start_timed_action", "Arbeiten", 600, func() -> void: pass, true, at[3])


## Steps until `clip` plays at `fraction` of its length (at most 6 s).
static func _step_until(player: CharacterBody3D, anim: AnimationPlayer, clip: StringName, fraction: float) -> void:
	var t := 0.0
	while t < 6.0:
		if anim.current_animation == clip and anim.current_animation_length > 0.0 and \
				anim.current_animation_position / anim.current_animation_length >= fraction:
			return
		player.call(&"_physics_process", STEP)
		anim.advance(STEP)
		t += STEP
		_note_bursts(player, t)


## Chips / clods are CPU particles on the real frame time: show them as far into their flight as the
## stepped time says (preprocess) and hold them still while the frame renders.
static var _emitted: Dictionary = {}
static var _now: float = 0.0


static func _note_bursts(player: Node3D, t: float) -> void:
	_now += STEP
	for key: Variant in _emitted.keys():
		if _now - float(_emitted[key]) > 1.0:
			_emitted.erase(key)
	for c: Node in player.get_children():
		if c is CPUParticles3D and (c as CPUParticles3D).emitting and not _emitted.has(c.name):
			_emitted[c.name] = _now


static func _freeze_bursts(player: Node3D) -> void:
	for c: Node in player.get_children():
		if c is CPUParticles3D and _emitted.has(c.name):
			var p := c as CPUParticles3D
			var age := _now - float(_emitted[c.name])
			if age > p.lifetime:
				p.emitting = false
				_emitted.erase(c.name)
				continue
			p.speed_scale = 1.0
			p.preprocess = maxf(0.0, age)
			p.restart()
			p.speed_scale = 0.0

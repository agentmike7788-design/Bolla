extends RefCounted
## G8 round 3 screenshot set of graveyard_shots.gd (--delivery): the morning delivery at the gate (user: „ich dachte die neuen
## leichen werden mit dem holz wagen hergebracht"). New game, real systems only: the clock runs minute by minute through
## TimeManager.advance(1) (every time_tick like in play) from 06:30 to 08:10; at the shot minutes (fractions through the
## clock's accumulator) the frame settles and <out>/delivery_<hhmm>[_<tenth>]<suffix>.jpg is written. Every minute logs
## Osric's place, cart / cargo and the bier. --shots=0700,0754_2 picks shots; --suffix=_web (Compatibility renderer) /
## _before is appended; --before-set: the shot minutes of the old timing. --skip: the debug console's „time 07:25" right
## after the start (timed, with the frame times before and after it) and then the same series. The HUD stays on (clock).

const SETTLE_FRAMES := 30
const STEP_FRAMES := 2
const JPG_QUALITY := 0.88
const END_MINUTE := 490
## Shot minutes (minute of day, fractions allowed) and the camera: focus (x, z) or "carter" (half way between Osric and
## his cart), distance.
const SHOTS: Array[Dictionary] = [
	{"minute": 390.0, "focus": Vector2(2.6, 10.0), "distance": 15.0},
	{"minute": 425.0, "focus": "carter", "distance": 14.0},
	{"minute": 440.0, "focus": "carter", "distance": 13.0},
	{"minute": 448.0, "focus": "carter", "distance": 12.0},
	{"minute": 452.0, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 453.0, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 454.2, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 455.2, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 456.3, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 457.2, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 458.4, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 459.4, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 460.0, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 461.5, "focus": Vector2(3.0, 8.4), "distance": 10.0},
	{"minute": 470.0, "focus": Vector2(3.0, 8.6), "distance": 12.0},
]
## The old timing (before G8 round 3): the corpse appeared on the bier at 07:40 while Osric stood at the handles.
const SHOTS_BEFORE: Array[Dictionary] = [
	{"minute": 390.0, "focus": Vector2(2.6, 10.0), "distance": 15.0},
	{"minute": 448.0, "focus": Vector2(2.6, 12.0), "distance": 13.0},
	{"minute": 455.0, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 459.0, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 460.0, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 461.0, "focus": Vector2(2.8, 9.5), "distance": 10.0},
]
## Frames timed before and after the debug „time" jump (--skip).
const TIMED_FRAMES := 5


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String, skip: bool,
		before: bool = false) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var manager := world.get_node(^"Systems/CorpseManager")
	var npc := world.get_node(^"Entities/npc_carter") as Node3D
	ui.visible = true
	var anchor := Node3D.new()
	anchor.name = "DeliveryAnchor"
	world.add_child(anchor)
	rig.set(&"target", anchor)
	# The gravekeeper waits inside the gate, west of the path, looking at the bier.
	player.global_position = Vector3(-0.4, float(world.call(&"ground_height", Vector2(-0.4, 6.2))), 6.2)
	player.rotation.y = deg_to_rad(110.0)
	player.set_physics_process(false)
	_log(tree, world, manager, npc, "start")
	anchor.global_position = Vector3(2.6, 0.0, 10.0)
	rig.call(&"snap")
	var f0 := Time.get_ticks_usec()
	for i: int in TIMED_FRAMES:
		await tree.process_frame
	print("[ShotsDelivery] baseline at the gate: %.1f ms per frame" % ((Time.get_ticks_usec() - f0) / 1000.0 / TIMED_FRAMES))
	if skip:
		var console := tree.root.get_node(^"Debug")
		var cmds: Object = console.get(&"_commands")
		var t0 := Time.get_ticks_usec()
		var res: Dictionary = cmds.call(&"run", "time", PackedStringArray(["07:25"]))
		var t1 := Time.get_ticks_usec()
		for i: int in TIMED_FRAMES:
			await tree.process_frame
		var t2 := Time.get_ticks_usec()
		print("[ShotsDelivery] time 07:25 → %s · command %.1f ms · then %.1f ms per frame" % [
				res, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0 / TIMED_FRAMES])
		_log(tree, world, manager, npc, "after skip")
	var shots := SHOTS_BEFORE if before else SHOTS
	var spm := float((clock.get(&"config") as Resource).get(&"seconds_per_game_minute"))
	var minute: int = int(clock.get(&"minute_of_day"))
	while minute <= END_MINUTE:
		for shot: Dictionary in shots:
			if int(floor(float(shot.minute))) != minute or not (only.is_empty() or _name(float(shot.minute)) in only):
				continue
			clock.set(&"_accum", (float(shot.minute) - minute) * spm)
			npc.call(&"refresh")
			_frame(anchor, npc, shot)
			rig.call(&"set_distance", float(shot.distance))
			rig.call(&"snap")
			for i: int in SETTLE_FRAMES:
				await tree.process_frame
			rig.call(&"snap")
			await tree.process_frame
			var path := out.path_join("delivery_%s%s.jpg" % [_name(float(shot.minute)), suffix])
			tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
			_log(tree, world, manager, npc, "shot " + path.get_file())
			clock.set(&"_accum", 0.0)
		clock.call(&"advance", 1)
		minute = int(clock.get(&"minute_of_day"))
		for i: int in STEP_FRAMES:
			await tree.process_frame
		_log(tree, world, manager, npc, "")
	player.set_physics_process(true)
	anchor.queue_free()


## Camera focus of a shot: a fixed spot or half way between Osric and his cart.
static func _frame(anchor: Node3D, npc: Node3D, shot: Dictionary) -> void:
	if shot.focus is Vector2:
		var f: Vector2 = shot.focus
		anchor.global_position = Vector3(f.x, 0.0, f.y)
	else:
		var cart := npc.get_node(^"Cart") as Node3D
		anchor.global_position = (npc.global_position + cart.global_position) * 0.5


## hhmm, with the tenth of a minute for fractional shots (0754_2).
static func _name(minute: float) -> String:
	var m := int(floor(minute))
	var tenth := int(round((minute - m) * 10.0))
	@warning_ignore("integer_division")
	var base := "%02d%02d" % [m / 60, m % 60]
	return base if tenth == 0 else "%s_%d" % [base, tenth]


static func _log(tree: SceneTree, _world: Node3D, manager: Node, npc: Node3D, tag: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var on_bier: PackedStringArray = []
	for record: Object in manager.call(&"records"):
		if record.get(&"location") == &"dropoff":
			on_bier.append(String(record.get(&"id")))
	var cart := npc.get_node(^"Cart") as Node3D
	var pose: Dictionary = npc.call(&"unload_pose") if npc.has_method(&"unload_pose") else {}
	print("[ShotsDelivery] %s %s carter=%s visible=%s anim=%s cart=%s cargo=%d unload=%s bier=%s" % [
			clock.call(&"format_clock"), tag, npc.global_position.snapped(Vector3.ONE * 0.01), npc.visible,
			npc.call(&"current_animation"), cart.visible, int(npc.call(&"cargo_count")) if npc.has_method(&"cargo_count") else -1,
			"%s/%s" % [pose.get("anim", ""), pose.get("index", -1)] if bool(pose.get("active", false)) else "-", on_bier])

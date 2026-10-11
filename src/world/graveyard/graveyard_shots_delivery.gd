extends RefCounted
## G8 round 3 screenshot set of graveyard_shots.gd (--delivery): the morning delivery at the gate (user:
## „ich dachte die neuen leichen werden mit dem holz wagen hergebracht"). New game, real systems only: the
## clock runs minute by minute through TimeManager.advance(1) (every time_tick like in play) from 06:30 to
## 08:10; at the shot minutes the frame settles and <out>/delivery_<hhmm><suffix>.jpg is written. Every
## minute logs Osric's place, cart / cargo and the bier. --shots=0700,0740 picks shots; --suffix=_web
## (Compatibility renderer) / _before is appended. --skip: the debug console's „time 07:25" right after
## the start (timed) and then the same series. The HUD stays on (the clock).

const SETTLE_FRAMES := 30
const STEP_FRAMES := 2
const JPG_QUALITY := 0.88
const START_MINUTE := 390
const END_MINUTE := 490
## Shot minutes (minute of day) and the camera for each: focus (x, z) and distance.
const SHOTS: Array[Dictionary] = [
	{"minute": 390, "focus": Vector2(2.6, 10.0), "distance": 15.0},
	{"minute": 420, "focus": Vector2(9.0, 24.0), "distance": 18.0},
	{"minute": 430, "focus": Vector2(6.0, 21.0), "distance": 16.0},
	{"minute": 440, "focus": Vector2(3.5, 16.5), "distance": 15.0},
	{"minute": 448, "focus": Vector2(2.6, 12.0), "distance": 13.0},
	{"minute": 452, "focus": Vector2(2.8, 10.0), "distance": 11.0},
	{"minute": 455, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 457, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 459, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 460, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 461, "focus": Vector2(2.8, 9.5), "distance": 10.0},
	{"minute": 470, "focus": Vector2(2.8, 9.5), "distance": 11.0},
	{"minute": 490, "focus": Vector2(2.8, 9.8), "distance": 13.0},
]


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String, skip: bool) -> void:
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
	# The gravekeeper waits inside the gate, west of the bier, looking south to the road.
	player.global_position = Vector3(0.2, float(world.call(&"ground_height", Vector2(0.2, 7.2))), 7.2)
	player.rotation.y = 0.0
	player.set_physics_process(false)
	_log(tree, world, manager, npc, "start")
	if skip:
		var console := tree.root.get_node(^"Debug")
		var cmds: Object = console.get(&"_commands")
		var t0 := Time.get_ticks_usec()
		var res: Dictionary = cmds.call(&"run", "time", PackedStringArray(["07:25"]))
		var t1 := Time.get_ticks_usec()
		await tree.process_frame
		var t2 := Time.get_ticks_usec()
		await tree.process_frame
		var t3 := Time.get_ticks_usec()
		print("[ShotsDelivery] time 07:25 → %s · command %.1f ms · frame1 %.1f ms · frame2 %.1f ms" % [
				res, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
		_log(tree, world, manager, npc, "after skip")
	var minute: int = int(clock.get(&"minute_of_day"))
	while minute <= END_MINUTE:
		var shot := _shot_at(minute)
		if not shot.is_empty() and (only.is_empty() or _hhmm(minute) in only):
			anchor.global_position = Vector3(shot.focus.x, 0.0, shot.focus.y)
			rig.call(&"set_distance", float(shot.distance))
			rig.call(&"snap")
			for i: int in SETTLE_FRAMES:
				await tree.process_frame
			rig.call(&"snap")
			await tree.process_frame
			var path := out.path_join("delivery_%s%s.jpg" % [_hhmm(minute), suffix])
			tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
			_log(tree, world, manager, npc, "shot " + path.get_file())
		clock.call(&"advance", 1)
		minute = int(clock.get(&"minute_of_day"))
		for i: int in STEP_FRAMES:
			await tree.process_frame
		_log(tree, world, manager, npc, "")
	player.set_physics_process(true)
	anchor.queue_free()


static func _shot_at(minute: int) -> Dictionary:
	for s: Dictionary in SHOTS:
		if int(s.minute) == minute:
			return s
	return {}


static func _hhmm(minute: int) -> String:
	return "%02d%02d" % [minute / 60, minute % 60]


static func _log(tree: SceneTree, _world: Node3D, manager: Node, npc: Node3D, tag: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var on_bier: PackedStringArray = []
	for record: Object in manager.call(&"records"):
		if record.get(&"location") == &"dropoff":
			on_bier.append(String(record.get(&"id")))
	var cart := npc.get_node(^"Cart") as Node3D
	var cargo: Node3D = npc.get(&"cargo")
	print("[ShotsDelivery] %s %s carter=%s visible=%s anim=%s cart=%s cargo=%s bier=%s" % [
			clock.call(&"format_clock"), tag, npc.global_position.snapped(Vector3.ONE * 0.01), npc.visible,
			npc.call(&"current_animation"), cart.visible, cargo.is_visible_in_tree() if cargo != null else false, on_bier])

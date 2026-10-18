extends "res://src/world/village/village_shots_phase8.gd"
## G9 Gehtempo (docs/reviews/phase9_round1/tempo/tempo.md): a strip of one villager walking through Hollerbrück – the
## same camera, a frame every `--step` game minutes (= step × 0.5 s real) from the start of the walk, the clock and the
## AnimationPlayer RUNNING (the clip at its speed_scale, Engine.time_scale only slows the run so the frames fall on
## the beat). Before / after: the same script on the old and the new schedules. Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots_tempo.gd \
##       -- --out=/abs/dir --tag=vorher|nachher [--walk=osric|fenner] [--frames=8] [--step=<game minutes>]
## From the Phase-7 end state (saves_v6/slot_p7_day53_neighbor, real SaveManager), day 54. Per frame:
## <out>/<walk>_<tag>_<nn>.jpg; <out>/<walk>_<tag>.txt: per frame the game minute, the figure's position, its
## animation and speed_scale, the ground speed (m/s) and the distance since the last frame.

## walk -> {npc (node in the village), the walk's start minute before / after G9 (the frames start there), the
## camera focus (region-local x, z) and distance}
## Osric from the remise to the inn after noon (17.6 m: before 14:00–14:05, after 13:42–14:05), Fenner from the Amtshaus to
## the board (38.8 m: before 12:00–12:20, after 11:31–12:20).
const WALKS := {
	"osric": {"npc": "npc_carter_v", "day": 54, "vorher": 840, "nachher": 822, "focus": Vector2(14.0, 4.2), "distance": 26.0, "step": 1.0},
	"fenner": {"npc": "npc_mayor", "day": 54, "vorher": 720, "nachher": 691, "focus": Vector2(-6.5, -5.0), "distance": 22.0, "step": 2.0},
}
## The first frame half a minute after the start (the figure has stepped out of its door).
const LEAD := 0.5
const TIME_SCALE := 0.2

var _set_tag := "nachher"
var _walk_id := "osric"
var _frame_count := 8
var _step_minutes := -1.0


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--tag="):
			_set_tag = arg.trim_prefix("--tag=")
		elif arg.begins_with("--walk="):
			_walk_id = arg.trim_prefix("--walk=")
		elif arg.begins_with("--frames="):
			_frame_count = arg.trim_prefix("--frames=").to_int()
		elif arg.begins_with("--step="):
			_step_minutes = arg.trim_prefix("--step=").to_float()
	if _out == "" or not WALKS.has(_walk_id):
		printerr("usage: -- --out=/abs/dir --tag=vorher|nachher [--walk=osric|fenner] [--frames=8] [--step=1]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v6(FIXTURE_V6)
	var w: Dictionary = WALKS[_walk_id]
	if _step_minutes <= 0.0:
		_step_minutes = float(w.get("step", 1.0))
	var start := int(w.get(_set_tag, w.nachher))
	var day := int(w.day)
	_advance_to(world, day, start - 3)
	var clock := root.get_node(^"TimeManager")
	clock.call(&"load_state", {"day": day, "minute_of_day": start - 3})
	var player := world.get_node(^"Player") as Node3D
	if player.get(&"region_id") != VILLAGE:
		player.call(&"set_region", VILLAGE)
	if bool(player.get(&"in_interior")):
		player.call(&"set_in_interior", false)
	# The gravekeeper off the walk (south-west of the Anger, out of the frame), the camera on a fixed anchor.
	player.global_position = _vpos(world, Vector2(-26.0, 12.0))
	_free_camera(world, _vpos(world, w.focus), float(w.distance))
	var rig := world.get_node(^"CameraRig") as Node3D
	rig.call(&"snap")
	var npc := _village(world).find_child(String(w.npc), true, false) as Node3D
	for i: int in SETTLE_FRAMES:
		await process_frame
	var report := PackedStringArray(["frame\tminute\tclock\tx\tz\tanim\tspeed_scale\tground_m_s\tstep_m"])
	Engine.time_scale = TIME_SCALE
	clock.set(&"running", true)
	clock.call(&"clear_pauses")
	var prev := Vector3.INF
	for k: int in _frame_count:
		var target := float((day - 1) * 1440 + start) + LEAD + float(k) * _step_minutes
		while _now(clock) < target:
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_jpg(_out.path_join("%s_%s_%02d.jpg" % [_walk_id, _set_tag, k]), 0.9)
		var p := npc.global_position
		var anim := npc.call(&"animation_player") as AnimationPlayer
		var moved := 0.0 if prev == Vector3.INF else Vector2(p.x - prev.x, p.z - prev.z).length()
		prev = p
		var m := _now(clock) - float((day - 1) * 1440)
		report.append("%d\t%.2f\t%02d:%02d\t%.2f\t%.2f\t%s\t%.2f\t%.2f\t%.2f" % [k, m, int(m) / 60, int(m) % 60, p.x - ORIGIN.x,
				p.z - ORIGIN.z, npc.call(&"current_animation"), anim.speed_scale if anim != null else 0.0, float(npc.call(&"ground_speed")), moved])
	clock.set(&"running", false)
	Engine.time_scale = 1.0
	var f := FileAccess.open(_out.path_join("%s_%s.txt" % [_walk_id, _set_tag]), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	print("[ShotsTempo] ", "\n".join(report))
	quit()


func _now(clock: Node) -> float:
	return float(clock.call(&"total_minutes")) + clampf(float(clock.get(&"_accum")) / 0.5, 0.0, 0.999)

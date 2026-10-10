extends "res://src/world/village/village_shots.gd"
## Phase-8 village shots (docs/PHASE8_DESIGN.md §11 – the W-Welt part in the village: p8_14, p8_15, p8_17,
## p8_18, p8_19, p8_20, p8_28). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots_phase8.gd \
##       -- --out=/abs/dir [--shots=p8_18] [--jpg]
## Every shot starts from the Phase-7 end state (tests/fixtures/saves_v6/slot_p7_day53_neighbor through the real
## SaveManager: NpcLife.post_load opens Phase 8) and runs the days in order (the night paths, the festivals and
## the wanderers follow the clock: each shot ticks the systems at its minute, the Npc place themselves from their
## schedules). Staged ("stage") only what a frame cannot wait for: the Kathreintanz couples, the chat at the well,
## Lenz' low mood at the church door, the name plate after Rosine 2. The panels are W-UI's (p8_17 with the HUD).
## Per shot: <out>/<name>.png|jpg and a line in render_stats_p8_village.txt.

const FIXTURES_V6 := "res://tests/fixtures/saves_v6/%s.json"
const FIXTURE_V6 := "slot_p7_day53_neighbor"
const P8_SHOTS: Array[Dictionary] = [
	{"name": "p8_20_kathreintanz_inn", "day": 54, "minute": 1200, "room": "inn", "player": Vector2(-0.3, 0.6), "stage": "kathrein", "zoom": 13.0},
	{"name": "p8_17_hanne_well", "day": 55, "minute": 660, "player": Vector2(-0.4, 0.4), "facing": 210.0, "game": 16.0, "ui": true},
	{"name": "p8_14_theres_liesel_well", "day": 56, "minute": 615, "player": Vector2(3.6, 1.6), "facing": 240.0, "game": 18.0,
			"stage": "well_chat"},
	{"name": "p8_15_lenz_low_church", "day": 56, "minute": 560, "player": Vector2(1.0, -7.0), "facing": 0.0, "game": 16.0,
			"stage": "lenz_low"},
	# W3 (G8): Lenz comes out of the Otts' door at 21:40 (1300); the frame on the sick house, not the stone house.
	{"name": "p8_18_sick_light_night", "day": 57, "minute": 1300, "focus": Vector2(24.6, 2.2), "distance": 15.0, "player": Vector2(22.9, 0.4),
			"facing": 160.0},
	{"name": "p8_18b_sick_light_far", "day": 57, "minute": 1301, "focus": Vector2(22.5, 2.0), "distance": 22.0, "player": Vector2(22.9, 0.4),
			"facing": 160.0},
	{"name": "p8_19_liesel_vigil", "day": 58, "minute": 158, "focus": Vector2(24.2, 2.0), "distance": 15.0, "player": Vector2(22.9, 0.4),
			"facing": 160.0},
	{"name": "p8_28_parish_archive", "day": 59, "minute": 990, "room": "church", "player": Vector2(-2.05, -2.2), "stage": "archive"},
	{"name": "perf_p8_04_inn_kathrein", "day": 59, "minute": 1000, "room": "inn", "player": Vector2(-0.3, 0.6), "stage": "kathrein"},
	{"name": "perf_p8_05_village_sick_night", "day": 59, "minute": 1080, "player": Vector2(0.6, -0.4), "game": 26.0},
]

var _day_ticked := 0


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg == "--jpg":
			_jpg = true
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=p8_18] [--jpg]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v6(FIXTURE_V6)
	var report: PackedStringArray = []
	for shot: Dictionary in P8_SHOTS:
		var wanted := _only.is_empty() or Array(_only).any(func(p: String) -> bool: return String(shot.name).begins_with(p))
		_advance_to(world, int(shot.day), int(shot.minute))
		if wanted:
			await _shoot_village(world, shot, report)
	var f := FileAccess.open(_out.path_join("render_stats_p8_village.txt"), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _load_v6(fixture: String) -> Node3D:
	var saves := root.get_node(^"SaveManager")
	var dir := String(saves.get("save_dir"))
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir.path_join("slot_%d.json" % SHOT_SLOT), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURES_V6 % fixture))
	f.close()
	await saves.call(&"load_game", SHOT_SLOT)
	for i: int in 3:
		await process_frame
	var world := current_scene as Node3D
	root.get_node(^"TimeManager").set("running", false)
	(world.get_node(^"UI") as CanvasLayer).visible = false
	return world


## The real clock up to the shot (hour by hour – mornings, festivals, night paths and wanderers set their
## day flags as in play); the shot itself loads the exact minute.
func _advance_to(world: Node3D, day: int, minute: int) -> void:
	var clock := root.get_node(^"TimeManager")
	var target := (day - 1) * 1440 + minute
	while int(clock.call(&"total_minutes")) < target:
		clock.call(&"advance", mini(60, target - int(clock.call(&"total_minutes"))))


func _stage_village(world: Node3D, shot: Dictionary) -> void:
	match String(shot.get("stage", "")):
		"kathrein":
			_stage_kathrein(world, int(shot.day))
		"well_chat":
			_stage_npc(world, "npc_grocer", _vpos(world, Vector2(0.4, -0.3)), 110.0, &"talk", 0.3)
			_stage_npc(world, "npc_washer", _vpos(world, Vector2(1.6, -0.6)), 290.0, &"talk", 1.1)
		"lenz_low":
			_stage_npc(world, "npc_priest", _vpos(world, Vector2(-1.4, -9.5)), 25.0, &"idle_low", 0.6)
		"archive":
			root.get_node(^"GameState").call(&"set_flag", &"friend_innkeeper_2", true)
			var room := _room(&"church")
			for node: Node in room.find_children("*", "", true, false):
				if node.get_script() != null and String((node.get_script() as Script).resource_path).get_file() == "memorial_plate.gd":
					node.call(&"refresh")
			# The gravekeeper at the cabinet (facing west), Lenz beside him sorting the church accounts.
			var player := world.get_node(^"Player") as Node3D
			player.rotation.y = deg_to_rad(-90.0)
			var anim := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if anim != null and anim.has_animation(&"interact"):
				anim.play(&"interact")
				anim.seek(0.5, true)
			_stage_npc(world, "npc_priest", room.global_transform * Vector3(-1.75, 0.0, -1.2), 250.0, &"talk", 0.4)
		_:
			await super(world, shot)


## D6: the room on the festival day (decoration, the tables to the walls, the fiddler), two couples on the dance
## floor – the gravekeeper with Theres, Liesel with Esch.
func _stage_kathrein(world: Node3D, day: int) -> void:
	root.get_node(^"GameState").call(&"set_flag", &"fest_kathrein_day", day)
	var room := _room(&"inn")
	room.call(&"apply_fest")
	for node: Node in room.find_children("*", "", true, false):
		if node.has_method(&"refresh") and node.get_script() != null \
				and String((node.get_script() as Script).resource_path).get_file() in ["fest_decor.gd", "fiddler.gd"]:
			node.call(&"refresh")
	var t := room.global_transform
	_stage_npc(world, "npc_grocer", t * Vector3(0.65, 0.0, -0.3), 270.0, &"dance", 0.2)
	_stage_npc(world, "npc_washer", t * Vector3(1.3, 0.0, 1.0), 260.0, &"dance", 0.7)
	_stage_npc(world, "npc_smith", t * Vector3(0.2, 0.0, 0.95), 80.0, &"dance", 0.9)
	var player := world.get_node(^"Player") as Node3D
	player.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), t * Vector3(-0.15, 0.0, -0.25))
	var anim := player.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim != null and anim.has_animation(&"dance"):
		anim.play(&"dance")
		anim.seek(0.4, true)

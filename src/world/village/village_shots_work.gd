extends "res://src/world/village/village_shots_phase8.gd"
## G8 Runde 4 (user: „ja die sollen eigene arbeitsbewegungen bekommen"): one contact sheet per villager at work, at the
## real work place by the real schedule (docs/reviews/phase8_round4/dorf_arbeit.md). Needs a real renderer:
##   tools/godot_run.sh --resolution 1280x720 -s res://src/world/village/village_shots_work.gd \
##       -- --out=/abs/dir [--shots=wirtin,osric] [--suffix=_web]
## From the Phase-7 end state (saves_v6/slot_p7_day53_neighbor, real SaveManager) the clock runs forward to each
## sheet's minute (the systems tick, every Npc places itself from its schedule); the gravekeeper waits in the same
## region (village, room or graveyard) out of the work's pause range. Per sheet: columns = six moments of the clip
## the figure plays there (stepped by hand), the last column the gravekeeper stepped up to it (the work pauses, it
## turns to him); the upper row a closer camera from the game camera's side, the lower row the game camera itself
## (room / village profile) at 1:1 pixels around the figure. Jakob's evening in the inn and Liesel's corpse wash
## are runtime schedules (Apprentice / Friendship): staged through the same builders. Writes
## <out>/dorf_<sheet><suffix>.jpg and the clip per sheet in work_sheets<suffix>.txt.

const TILE := Vector2i(480, 270)
const JPG_QUALITY := 0.88
const MOMENTS: Array[float] = [0.0, 0.17, 0.33, 0.5, 0.67, 0.83]
const CLOSE_FOV := 30.0
## The close camera: from the game camera's side (+Z, up), a little to the right, looking at the chest.
const CLOSE_OFFSET := Vector3(1.0, 1.75, 3.3)
const CLOSE_LOOK := 1.0
## The gravekeeper waits this far from the figure (beyond NpcWorkConfig.pause_range), then steps up to NEAR.
const AWAY := 5.0
const NEAR := 1.6
const VILLAGE_ZOOM := 18.0
## sheet -> {npc (node name), day, minute, where: "village" | room id | "graveyard" | "crypt", stage}
const SHEETS: Array[Dictionary] = [
	{"name": "waescherin", "npc": "npc_washer", "day": 54, "minute": 480, "where": "village"},
	{"name": "buergermeister", "npc": "npc_mayor", "day": 54, "minute": 540, "where": "office"},
	{"name": "wundarzt", "npc": "npc_surgeon", "day": 54, "minute": 570, "where": "surgery"},
	{"name": "wirtin", "npc": "npc_innkeeper", "day": 54, "minute": 630, "where": "inn"},
	{"name": "buergermeister_brett", "npc": "npc_mayor", "day": 54, "minute": 760, "where": "village"},
	{"name": "wundarzt_mischen", "npc": "npc_surgeon", "day": 54, "minute": 900, "where": "surgery"},
	{"name": "pfarrer_altar", "npc": "npc_priest", "day": 54, "minute": 990, "where": "church"},
	{"name": "jakob", "npc": "npc_apprentice_v", "day": 54, "minute": 1050, "where": "inn", "stage": "jakob"},
	{"name": "osric", "npc": "npc_carter", "day": 54, "minute": 1120, "where": "graveyard"},
	{"name": "pfarrer_tuer", "npc": "npc_priest", "day": 55, "minute": 500, "where": "village", "stage": "no_chatter"},
	{"name": "waescherin_tisch", "npc": "npc_washer_g", "day": 55, "minute": 600, "where": "crypt", "stage": "wash"},
]



func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--shots="):
			_only = arg.trim_prefix("--shots=").split(",", false)
		elif arg.begins_with("--suffix="):
			_suffix = arg.trim_prefix("--suffix=")
	if _out == "":
		printerr("usage: -- --out=/abs/dir [--shots=wirtin,osric] [--suffix=_web]")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.get_node(^"SaveManager").set("save_dir", SHOT_SAVE_DIR)
	var world := await _load_v6(FIXTURE_V6)
	var report: PackedStringArray = []
	var close := Camera3D.new()
	close.fov = CLOSE_FOV
	world.add_child(close)
	for sheet: Dictionary in SHEETS:
		if not _only.is_empty() and not String(sheet.name) in _only:
			continue
		_advance_to(world, int(sheet.day), int(sheet.minute))
		var line := await _sheet_for(world, sheet, close)
		print("[ShotsWork] ", line)
		report.append(line)
	close.queue_free()
	var f := FileAccess.open(_out.path_join("work_sheets%s.txt" % _suffix), FileAccess.WRITE)
	f.store_string("\n".join(report) + "\n")
	f.close()
	quit()


func _sheet_for(world: Node3D, sheet: Dictionary, close: Camera3D) -> String:
	var clock := root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as Node3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var where := String(sheet.where)
	# the figure of the sheet's region (the graveyard has its own Lenz / Liesel figures of the same name)
	var home := world.get_node(^"Entities") if where in ["graveyard", "crypt"] else world.get_node(^"Regions/Village")
	var npc := home.find_child(String(sheet.npc), true, false) as Node3D
	if npc == null:
		return "%s: no %s" % [sheet.name, sheet.npc]
	# the gravekeeper into the figure's region / room first (the figure shows only in the gravekeeper's region)
	var room: Node3D = null
	var region := &"graveyard" if where in ["graveyard", "crypt"] else VILLAGE
	if player.get(&"region_id") != region:
		player.call(&"set_region", region)
	if where in ["village", "graveyard"]:
		if bool(player.get(&"in_interior")):
			player.call(&"set_in_interior", false)
	else:
		room = _room(StringName(where))
		player.global_transform = room.call(&"spawn_transform")
		player.call(&"set_in_interior", true, StringName(where))
	match String(sheet.get("stage", "")):
		"jakob":
			_w_stage_jakob(world, npc, int(sheet.minute))
		"wash":
			_w_stage_wash(world, int(sheet.day), int(sheet.minute))
	root.get_node(^"EventBus").emit_signal(&"time_tick", int(sheet.day), int(sheet.minute))
	npc.call(&"refresh")
	for i: int in 3:
		await process_frame
	if String(sheet.get("stage", "")) == "no_chatter":
		# a chat at the work place (Lenz and Veit at the church door) runs in real time: played to its end first
		for runner: Node in world.find_children("ChatterRunner", "", true, false):
			for i: int in 8:
				runner.call(&"advance", 60.0)
				await process_frame
			runner.call(&"stop", VILLAGE)
			runner.process_mode = Node.PROCESS_MODE_DISABLED   # no new chat for this sheet
		npc.call(&"set_chatter_target", null)
	npc.call(&"refresh")
	# the gravekeeper away from the work (camera side), the game camera on the figure
	player.global_position = _w_stand(npc, AWAY, room)
	npc.call(&"refresh")
	var anchor := _w_anchor(world, npc.global_position)
	rig.set(&"target", anchor)
	rig.call(&"set_distance", float(room.call(&"room_config").get(&"camera_distance")) if room != null else VILLAGE_ZOOM)
	rig.call(&"snap")
	for i: int in SETTLE_FRAMES:
		await process_frame
	var anim := npc.call(&"animation_player") as AnimationPlayer
	var clip := StringName(npc.call(&"current_animation"))
	var tiles: Array = []
	var game_cam := root.get_camera_3d()
	if anim != null and anim.has_animation(clip):
		npc.process_mode = Node.PROCESS_MODE_DISABLED
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var smoke := not (npc.call(&"_work_config").call(&"puffs", clip) as PackedFloat32Array).is_empty()
		var puffed := false
		for f: float in MOMENTS:
			anim.seek(anim.current_animation_length * f, true)
			if smoke and f >= 0.5:
				# the software renderer is far slower than the particles' clock: the puff is pre-run to its age at
				# this moment of the cycle (from the first puff moment on) and held there for the frame
				var puffs := npc.get_node_or_null(^"PipeSmoke") as CPUParticles3D
				if puffs == null:
					npc.call(&"_puff")
					puffs = npc.get_node_or_null(^"PipeSmoke") as CPUParticles3D
				if puffs != null:
					puffs.process_mode = Node.PROCESS_MODE_ALWAYS
					puffs.preprocess = maxf(0.05, (f - 0.48) * anim.current_animation_length)
					puffs.speed_scale = 0.02
					npc.call(&"_puff")
				puffed = true
			tiles.append(await _w_shoot(world, npc, rig, game_cam, close, smoke and f >= 0.5))
		anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
		npc.process_mode = Node.PROCESS_MODE_INHERIT
	# the gravekeeper steps up: the work pauses, the figure turns to him
	player.global_position = _w_stand(npc, NEAR, room)
	for i: int in 50:
		await process_frame
	var attending := bool(npc.call(&"is_attending"))
	var pause_clip := StringName(npc.call(&"current_animation"))
	tiles.append(await _w_shoot(world, npc, rig, game_cam, close, false))
	var path := _out.path_join("dorf_%s%s.jpg" % [sheet.name, _suffix])
	_w_sheet(tiles).save_jpg(path, JPG_QUALITY)
	player.global_position = _w_stand(npc, AWAY, room)
	rig.set(&"target", player)
	clock.call(&"emit_refresh")
	var local := room.to_local(npc.global_position) if room != null else npc.global_position
	var e: Resource = npc.get(&"entry")
	var info := "%d %s %s visible=%s runtime=%s" % [int(e.get(&"start_minute")), e.get(&"path"), e.get(&"region"), e.get(&"visible"),
			npc.call(&"runtime_schedule") != null] if e != null else "none"
	return "%s: %s clip=%s near=%s attending=%s at=%s yaw=%.0f entry=%s" % [path.get_file(), sheet.npc, clip, pause_clip, attending,
			local, rad_to_deg(npc.rotation.y), info]


## Where the gravekeeper stands: `distance` from the figure towards the camera (+Z), on the ground.
func _w_stand(npc: Node3D, distance: float, room: Node3D) -> Vector3:
	var p := npc.global_position + Vector3(0.25, 0.0, distance)
	if room == null:
		p.y = float(npc.call(&"_world").call(&"ground_height", Vector2(p.x, p.z))) if npc.call(&"_world") != null else p.y
	return p


func _w_anchor(world: Node3D, at: Vector3) -> Node3D:
	var anchor := world.get_node_or_null(^"ShotAnchor") as Node3D
	if anchor == null:
		anchor = Node3D.new()
		anchor.name = "ShotAnchor"
		world.add_child(anchor)
	anchor.global_position = at
	return anchor


## Both cameras: the close one (scaled to a tile) and the game camera (a tile at 1:1 around the figure).
func _w_shoot(world: Node3D, npc: Node3D, rig: Node3D, game_cam: Camera3D, close: Camera3D, wait_smoke: bool) -> Array:
	var out: Array = []
	var focus := npc.global_position + Vector3(0.0, CLOSE_LOOK, 0.0)
	close.global_position = focus + CLOSE_OFFSET
	close.look_at(focus)
	close.make_current()
	for i: int in (24 if wait_smoke else 8):
		await process_frame
	var img := root.get_texture().get_image()
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	out.append(img)
	game_cam.make_current()
	rig.call(&"snap")
	for i: int in 8:
		await process_frame
	var full := root.get_texture().get_image()
	var vp := root.get_visible_rect().size
	var p := game_cam.unproject_position(focus) * Vector2(full.get_width(), full.get_height()) / vp
	var x := clampi(int(p.x) - TILE.x / 2, 0, full.get_width() - TILE.x)
	var y := clampi(int(p.y) - TILE.y / 2, 0, full.get_height() - TILE.y)
	out.append(full.get_region(Rect2i(x, y, TILE.x, TILE.y)))
	return out


## Columns = moments, row 1 the close camera, row 2 the game camera.
static func _w_sheet(tiles: Array) -> Image:
	var gap := 4
	var sheet := Image.create(tiles.size() * (TILE.x + gap) - gap, 2 * TILE.y + gap, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i: int in tiles.size():
		for row: int in 2:
			var img: Image = tiles[i][row]
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(i * (TILE.x + gap), row * (TILE.y + gap)))
	return sheet


## Jakob's working evening in the inn (Apprentice.village_schedule while hired): the same entry, built the same way
## (no static types of the game classes here: a -s script compiles before the autoloads exist).
func _w_stage_jakob(world: Node3D, npc: Node3D, minute: int) -> void:
	var builder: GDScript = load("res://src/systems/npc/schedule_builder.gd")
	var cfg: Resource = root.get_node(^"Database").call(&"config", &"npc_work_config")
	var clip: StringName = cfg.call(&"clip_for", &"apprentice_inn", &"idle") if cfg != null else &"idle"
	var e: Resource = builder.call(&"stay", &"v_in_inn_jakob", 0, clip, &"v_apprentice")
	e.set(&"region", VILLAGE)
	var entries: Array[ScheduleEntry] = [e]
	npc.call(&"set_runtime_schedule", builder.call(&"build", entries))
	print("[ShotsWork] Jakob staged at v_in_inn_jakob (%s) from minute %d" % [clip, minute])


## Liesel's corpse wash at the crypt table (Friendship: favour corpse_wash) due now.
func _w_stage_wash(world: Node3D, day: int, minute: int) -> void:
	var friendship := world.find_child("Friendship", true, false)
	if friendship == null:
		for node: Node in world.get_tree().get_nodes_in_group(&"saveable"):
			if node.get(&"save_id") == "friendship":
				friendship = node
	if friendship == null:
		push_warning("[ShotsWork] no Friendship")
		return
	friendship.set(&"_wash", {"day": day, "minute": minute - 10, "minutes": 90, "corpse": ""})
	friendship.call(&"_show_wash")

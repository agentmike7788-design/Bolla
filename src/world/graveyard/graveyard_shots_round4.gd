extends RefCounted
## G8 Runde 4 screenshot sets of graveyard_shots.gd (docs/reviews/phase8_round4):
## --round4=ui (user: „das auswahl bild muss weg der verdekt den leichentisch"): new game, day 1, Osric's first dead
## carried down and laid on the crypt table, the HUD on; the table's panel opened the way the player opens it
## (MorgueTable.interact → corpse_exam), the „Herrichten" tab chosen and „Waschen" pressed (its button's pressed
## signal). Frames of the room camera at real-second marks of the work (the player and the clip stepped by hand at
## 60 Hz – the bar's real duration, the panel's hiding and coming back as in play): <out>/frames/ui_<tag>_<n>.png
## plus <out>/frames/ui_<tag>.json (labels); the panel open before the work as tisch_ui_<tag>_auswahl<suffix>.jpg,
## the frame in the middle of the work as tisch_ui_<tag><suffix>.jpg.
## --round4=delivery (user: „kannst du 8 sec machen"): Osric's unloading at the bier – the clock stepped minute by
## minute (TimeManager.advance, fractions through its accumulator) from shortly before the unloading to his return
## to the handles; frames at real-second marks: <out>/frames/osric_<n>.png + osric.json.
## tools/contact_sheet.py puts the frames into sheets with their time marks.

const Table := preload("res://src/world/graveyard/graveyard_shots_table.gd")
const PORTAL := "res://src/world/hut_interior/hut_portal.gd"
const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 10
const JPG_QUALITY := 0.9
const DAY := 1
const MINUTE := 520
## Where he waits before the panel opens (room-local, the camera side of the table, as in graveyard_shots_table.gd).
const START := Vector3(0.95, 0.0, 0.6)
## Real-second marks of the work (after the press); "end" marks are added: just after the bar, the panel back.
const UI_MARKS: Array[float] = [0.0, 0.25, 0.6, 1.2, 1.9, 2.6, 3.3]
const UI_AFTER := [0.35, 1.0]
## Work sheet: a frame every WORK_STEP real seconds.
const WORK_STEP := 0.4
## Delivery: real seconds relative to the start of the unloading.
const DELIVERY_BEFORE := -1.5
const DELIVERY_STEP := 0.75
const DELIVERY_FOCUS := Vector2(3.0, 8.4)
const DELIVERY_DISTANCE := 9.0


static func run_ui(tree: SceneTree, world: Node3D, out: String, suffix: String, tag: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var manager := world.get_node(^"Systems/CorpseManager")
	var portal: GDScript = load(PORTAL)
	var frames := out.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames)
	clock.call(&"load_state", {"day": DAY, "minute_of_day": 470})
	var record: Object = manager.call(&"try_daily_delivery", DAY)
	if record == null:
		var bier := world.get_node(^"Entities/dropoff")
		record = manager.call(&"spawn_corpse", null, bier.call(&"slot_transform"), &"dropoff")
	var id := String(record.get(&"id"))
	var room: Node3D = null
	for node: Node in tree.get_nodes_in_group(&"building_door"):
		if node.get(&"building_id") == &"crypt":
			room = node.call(&"room") as Node3D
	var table: Node3D = room.get_node(^"Entities/MorgueTable") as Node3D
	manager.call(&"pick_up", id, player)
	portal.call(&"arrive", player, room.call(&"spawn_transform"), true, &"crypt")
	player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.75), room.global_transform * START)
	table.call(&"interact", player)
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
	clock.call(&"emit_refresh")
	var cfg: Object = room.call(&"room_config")
	rig.set(&"target", player)
	rig.call(&"set_distance", float(cfg.get(&"camera_distance")))
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ui.visible = true
	tree.root.get_camera_3d().make_current()
	rig.call(&"snap")
	await _settle(tree)
	# the panel, as the player opens it (E at the table)
	table.call(&"interact", player)
	await _settle(tree)
	var root_ui: Object = ui
	var panel: Object = root_ui.call(&"get_panel", &"corpse_exam")
	_save(tree, out.path_join("tisch_ui_%s_auswahl%s.jpg" % [tag, suffix]))
	var tabs: Object = panel.get(&"tabs")
	# „Waschen" when it can be done (water and cloth), else the first examination step („Hände & Arme").
	var button := tabs.get(&"wash_button") as Button
	var what := "Herrichten · Waschen"
	tabs.call(&"select_tab", &"prep")
	await _settle(tree)
	if button.disabled:
		tabs.call(&"select_tab", &"exam")
		button = (tabs.get(&"step_buttons") as Dictionary).get(&"hands") as Button
		what = "Untersuchen · Hände & Arme"
		await _settle(tree)
	var labels: Array = []
	var shot := 0
	_save_png(tree, frames.path_join("ui_%s%s_%d.png" % [tag, suffix, shot]))
	labels.append({"file": "ui_%s%s_%d.png" % [tag, suffix, shot], "label": "Auswahl: " + what})
	shot += 1
	button.pressed.emit()
	var duration := 0.0
	var action: Object = player.get(&"_action")
	if action != null:
		duration = float(action.get(&"duration"))
	print("[ShotsR4] %s started: real %.2f s, clip %s" % [what, duration, anim.current_animation])
	var marks: Array[float] = []
	for mark: float in UI_MARKS:
		if mark < duration - 0.1:
			marks.append(mark)
	for extra: float in UI_AFTER:
		marks.append(duration + extra)
	var t := 0.0
	var middle_saved := false
	for mark: float in marks:
		while t + STEP * 0.5 < mark:
			_advance(player, anim)
			t += STEP
		await _settle(tree)
		var name := "ui_%s%s_%d.png" % [tag, suffix, shot]
		_save_png(tree, frames.path_join(name))
		var busy := bool(player.call(&"is_busy"))
		var text := "%+.1f s · %s" % [t, String(anim.current_animation)]
		if not busy:
			text += " · fertig"
		labels.append({"file": name, "label": text, "panel": bool(panel.get(&"visible")), "busy": busy})
		print("[ShotsR4] ", name, " ", text, " panel_visible=", panel.get(&"visible"))
		if not middle_saved and t >= duration * 0.5:
			middle_saved = true
			_save(tree, out.path_join("tisch_ui_%s%s.jpg" % [tag, suffix]))
		shot += 1
	var f := FileAccess.open(frames.path_join("ui_%s%s.json" % [tag, suffix]), FileAccess.WRITE)
	f.store_string(JSON.stringify({"duration": duration, "action": what, "frames": labels}, "  "))
	f.close()
	player.set_physics_process(true)


## --round4=work: one table work in its course (user: „ja soll etwas länger dauern") – „Waschen" started the way the
## panel starts it (MorgueTable._start_work with its real game minutes: the bar's real seconds from
## ToolAnimConfig.table_seconds), the player and the clip stepped at 60 Hz; per real-second mark the close camera
## above the room camera (graveyard_shots_table.gd's _shoot): <out>/frames/work<suffix>_<n>.png + work<suffix>.json.
static func run_work(tree: SceneTree, world: Node3D, out: String, suffix: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var manager := world.get_node(^"Systems/CorpseManager")
	var portal: GDScript = load(PORTAL)
	var frames := out.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames)
	clock.call(&"load_state", {"day": DAY, "minute_of_day": 470})
	var record: Object = manager.call(&"try_daily_delivery", DAY)
	if record == null:
		var bier := world.get_node(^"Entities/dropoff")
		record = manager.call(&"spawn_corpse", null, bier.call(&"slot_transform"), &"dropoff")
	var id := String(record.get(&"id"))
	var room: Node3D = null
	for node: Node in tree.get_nodes_in_group(&"building_door"):
		if node.get(&"building_id") == &"crypt":
			room = node.call(&"room") as Node3D
	var table: Node3D = room.get_node(^"Entities/MorgueTable") as Node3D
	manager.call(&"pick_up", id, player)
	portal.call(&"arrive", player, room.call(&"spawn_transform"), true, &"crypt")
	player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.75), room.global_transform * START)
	table.call(&"interact", player)
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})
	clock.call(&"emit_refresh")
	var cfg: Object = room.call(&"room_config")
	rig.set(&"target", player)
	rig.call(&"set_distance", float(cfg.get(&"camera_distance")))
	player.set_physics_process(false)
	var anim := player.get(&"_anim") as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var game_cam := tree.root.get_camera_3d()
	var close := Camera3D.new()
	close.fov = Table.CLOSE_FOV
	world.add_child(close)
	await Table._settle(tree, rig, game_cam)
	var prep := load("res://data/config/prep_config.tres") as Resource
	var minutes := int(prep.get(&"wash_minutes"))
	table.call(&"_start_work", player, "Waschen", minutes, func() -> void: pass, &"wash")
	var action: Object = player.get(&"_action")
	var duration := float(action.get(&"duration")) if action != null else 0.0
	print("[ShotsR4] Waschen: %d game minutes, real %.2f s" % [minutes, duration])
	var marks: Array[float] = []
	var m := 0.0
	while m < duration + 0.5:
		marks.append(m)
		m += WORK_STEP
	marks.append(duration + 0.1)
	marks.sort()
	var labels: Array = []
	var t := 0.0
	var shot := 0
	for mark: float in marks:
		while t + STEP * 0.5 < mark:
			_advance(player, anim)
			t += STEP
		var clip := String(anim.current_animation)
		var pos := anim.current_animation_position
		var tiles: Array = await Table._shoot(tree, world, player, rig, game_cam, close, clock)
		var img := Image.create(Table.TILE.x, Table.TILE.y * 2 + 4, false, Image.FORMAT_RGB8)
		img.fill(Color(0.1, 0.1, 0.1))
		for row: int in 2:
			var tile: Image = tiles[row]
			tile.convert(Image.FORMAT_RGB8)
			img.blit_rect(tile, Rect2i(Vector2i.ZERO, Table.TILE), Vector2i(0, row * (Table.TILE.y + 4)))
		var name := "work%s_%d.png" % [suffix, shot]
		img.save_png(frames.path_join(name))
		var text := "%.1f s · %s %.2f" % [t, clip, pos]
		if not bool(player.call(&"is_busy")):
			text = "%.1f s · fertig · %s" % [t, clip]
		labels.append({"file": name, "label": text})
		print("[ShotsR4] ", name, " ", text, " tool=", player.call(&"held_tool"))
		shot += 1
	var f := FileAccess.open(frames.path_join("work%s.json" % suffix), FileAccess.WRITE)
	f.store_string(JSON.stringify({"duration": duration, "minutes": minutes, "frames": labels}, "  "))
	f.close()
	game_cam.make_current()
	close.queue_free()
	player.set_physics_process(true)


static func run_delivery(tree: SceneTree, world: Node3D, out: String, suffix: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var npc := world.get_node(^"Entities/npc_carter") as Node3D
	var frames := out.path_join("frames")
	DirAccess.make_dir_recursive_absolute(frames)
	ui.visible = true
	var anchor := Node3D.new()
	world.add_child(anchor)
	rig.set(&"target", anchor)
	player.global_position = Vector3(-0.4, float(world.call(&"ground_height", Vector2(-0.4, 6.2))), 6.2)
	player.rotation.y = deg_to_rad(110.0)
	player.set_physics_process(false)
	anchor.global_position = Vector3(DELIVERY_FOCUS.x, 0.0, DELIVERY_FOCUS.y)
	rig.call(&"set_distance", DELIVERY_DISTANCE)
	var delivery_cfg := load("res://data/config/cart_delivery_config.tres") as Resource
	var tables: Object = tree.root.get_node(^"Database").call(&"corpse_tables")
	var delivery := int(tables.get(&"delivery_minute"))
	var start := float(delivery_cfg.call(&"unload_start", delivery))
	var after := float(delivery_cfg.call(&"after_minutes", true))
	var spm := float((clock.get(&"config") as Resource).get(&"seconds_per_game_minute"))
	var marks: Array[float] = []
	var s := DELIVERY_BEFORE
	var end_s := (delivery - start + after) * spm + 0.5
	while s <= end_s:
		marks.append(s)
		s += DELIVERY_STEP
	var from := int(floor(start + DELIVERY_BEFORE / spm)) - 1
	clock.call(&"set_time", DAY, from)
	var minute: int = int(clock.get(&"minute_of_day"))
	var labels: Array = []
	var shot := 0
	var k := 0
	while k < marks.size():
		var at := start + marks[k] / spm
		if at >= float(minute + 1):
			clock.call(&"advance", 1)
			minute = int(clock.get(&"minute_of_day"))
			for i: int in 2:
				await tree.process_frame
			continue
		clock.set(&"_accum", (at - minute) * spm)
		npc.call(&"refresh")
		rig.call(&"snap")
		await _settle(tree)
		rig.call(&"snap")
		await tree.process_frame
		var pose: Dictionary = npc.call(&"unload_pose")
		var name := "osric%s_%02d.png" % [suffix, shot]
		_save_png(tree, frames.path_join(name))
		@warning_ignore("integer_division")
		var hhmm := "%02d:%02d" % [int(floor(at)) / 60, int(floor(at)) % 60]
		var what := String(pose.get("anim", npc.call(&"current_animation"))) if bool(pose.get("active", false)) else String(npc.call(&"current_animation"))
		var text := "%+.2f s · %s · %s" % [marks[k], hhmm, what]
		labels.append({"file": name, "label": text})
		print("[ShotsR4] ", name, " ", text)
		clock.set(&"_accum", 0.0)
		shot += 1
		k += 1
	var f := FileAccess.open(frames.path_join("osric%s.json" % suffix), FileAccess.WRITE)
	f.store_string(JSON.stringify({"unload_start": start, "delivery": delivery, "frames": labels}, "  "))
	f.close()
	player.set_physics_process(true)
	anchor.queue_free()


static func _settle(tree: SceneTree) -> void:
	for i: int in SETTLE_FRAMES:
		await tree.process_frame


static func _save(tree: SceneTree, path: String) -> void:
	tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
	print("[ShotsR4] ", path)


static func _save_png(tree: SceneTree, path: String) -> void:
	tree.root.get_texture().get_image().save_png(path)


static func _advance(player: Node, anim: AnimationPlayer) -> void:
	player.call(&"_physics_process", STEP)
	anim.advance(STEP)

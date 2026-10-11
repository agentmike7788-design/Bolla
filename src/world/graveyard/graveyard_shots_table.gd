extends RefCounted
## G8 Runde 3 screenshot set of graveyard_shots.gd (--table): the gravekeeper's work at the crypt table (user:
## „annimationen fehlen", „die leichen preperation annimation fehlen auch"). New game, day 1, real systems: Osric's
## first dead carried down and laid on the crypt table (MorgueTable.interact); then every table action is started
## the way the panel starts it (MorgueTable._start_work: its clip from tool_anim_config, the step to the work spot,
## the small tool from the tool bag) and stepped by hand in fixed steps. Per action one contact sheet:
## the upper row a closer camera, the lower row the in-game room camera at 1:1 pixels around him – the step / the
## draw, five moments of the clip, the stow / the end. --shots=untersuchen,waschen,… picks sheets; --suffix=_web
## (Compatibility renderer) is appended. Writes <out>/tisch_<name><suffix>.jpg.
## --table-extra: the other hand work of the audit (ossuary, preparation desk, grave care, rain barrel, rake,
## chapel, desk) – Extra series, the same sheets as <out>/arbeit_<name><suffix>.jpg.

const PORTAL := "res://src/world/hut_interior/hut_portal.gd"
const STEP := 1.0 / 60.0
const SETTLE_FRAMES := 8
const JPG_QUALITY := 0.88
const DAY := 1
const MINUTE := 520
const TILE := Vector2i(480, 270)
const CLOSE_FOV := 30.0
const CLOSE_OFFSET := Vector3(1.5, 1.45, 2.6)
## The extras (benches against walls, barrels at the hut): from his left side instead of from the front.
const SIDE_OFFSET := Vector3(2.8, 1.5, 0.5)
const CLOSE_LOOK := 0.9
## Where he waits before an action (room-local, the camera side of the table, as he comes from the stair).
const START := Vector3(0.95, 0.0, 0.6)
## sheet name -> [table action key (MorgueTable "morgue_<key>"), the corpse under the cloth]
const SERIES := {
	"untersuchen": [&"exam_hands", false],
	"durchsuchen": [&"exam_pockets", false],
	"waschen": [&"wash", false],
	"organ": [&"organ", true],
	"aufbahren": [&"lay_out", false],
	"raeuchern": [&"balm", false],
	"leichentuch": [&"dress_shroud", false],
	"zopf": [&"harvest_hair", false],
	"zaehne": [&"harvest_teeth", false],
}
## The other hand work: sheet name -> [where ("crypt" = node of the crypt room, else of the world), node path,
## clip, stand (place-local offset Vector3 or distance in front along the place's +Z)].
const EXTRA := {
	"beinhaus": ["crypt", "Entities/OssuaryShelf", &"place_low", 0.9],
	"pult": ["world", "Entities/workbench", &"bench_work", 0.95],
	"schreiben": ["world", "Entities/workbench", &"write", 0.95],
	"blumen": ["world", "Entities/plot_02", &"kneel_place", Vector3(-1.05, 0.0, 0.45)],
	"unkraut": ["world", "Entities/plot_02", &"weed_pull", Vector3(-1.05, 0.0, 0.45)],
	"laub": ["world", "Entities/plot_02", &"rake", Vector3(-1.6, 0.0, 0.45)],
	"andacht": ["world", "Entities/plot_02", &"pray", Vector3(-1.05, 0.0, 0.45)],
	"regentonne": ["world", "Entities/rain_barrel", &"fill_can", 0.7],
}
const OUTSIDE_DISTANCE := 14.0
## The five moments of the clip (fractions of its first full cycle after the draw).
const MOMENTS: Array[float] = [0.05, 0.25, 0.45, 0.65, 0.85]


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var manager := world.get_node(^"Systems/CorpseManager")
	var portal: GDScript = load(PORTAL)
	clock.call(&"load_state", {"day": DAY, "minute_of_day": 470})
	var record: Object = manager.call(&"try_daily_delivery", DAY)
	if record == null:
		var bier := world.get_node(^"Entities/dropoff")
		record = manager.call(&"spawn_corpse", null, bier.call(&"slot_transform"), &"dropoff")
	var id := String(record.get(&"id"))
	var door: Node3D = null
	for node: Node in tree.get_nodes_in_group(&"building_door"):
		if node.get(&"building_id") == &"crypt":
			door = node as Node3D
	var room: Node3D = door.call(&"room") as Node3D
	var table: Node3D = room.get_node(^"Entities/MorgueTable") as Node3D
	manager.call(&"pick_up", id, player)
	portal.call(&"arrive", player, room.call(&"spawn_transform"), true, &"crypt")
	player.global_transform = Transform3D(Basis.IDENTITY, room.global_transform * START)
	table.call(&"interact", player)
	print("[ShotsTable] on the crypt table: '%s'" % table.get(&"corpse_id"))
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
	close.fov = CLOSE_FOV
	world.add_child(close)
	var corpse: Node = manager.call(&"get_corpse_node", id)
	for series: String in SERIES:
		if not only.is_empty() and not series in only:
			continue
		var key: StringName = SERIES[series][0]
		var clip: StringName = table.call(&"clip_for", key)
		corpse.call(&"set_covered", bool(SERIES[series][1]))
		player.call(&"cancel_timed_action")
		player.call(&"reset_tool")
		player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.75), room.global_transform * START)
		await _settle(tree, rig, game_cam)
		table.call(&"_start_work", player, "Arbeiten", 600, func() -> void: pass, key)
		var tiles: Array = await _frames(tree, world, player, anim, rig, game_cam, close, clock, clip)
		var path := out.path_join("tisch_%s%s.jpg" % [series, suffix])
		_sheet(tiles).save_jpg(path, JPG_QUALITY)
		print("[ShotsTable] ", path, "  clip=", clip, " stand=", room.to_local(player.global_position))
	corpse.call(&"set_covered", false)
	# the other hand work of the audit, at its place (crypt first, then the graveyard)
	for series: String in EXTRA:
		if not only.is_empty() and not series in only:
			continue
		var spec: Array = EXTRA[series]
		var clip: StringName = spec[2]
		var place: Node3D = (room if spec[0] == "crypt" else world).get_node(NodePath(String(spec[1]))) as Node3D
		player.call(&"cancel_timed_action")
		player.call(&"reset_tool")
		if spec[0] != "crypt" and bool(player.get(&"in_interior")):
			portal.call(&"arrive", player, place.global_transform, false, &"")
			rig.call(&"set_distance", OUTSIDE_DISTANCE)
		player.global_transform = _stand(place, spec[3])
		await _settle(tree, rig, game_cam)
		player.call(&"start_timed_action", "Arbeiten", 600, func() -> void: pass, false, clip)
		var tiles: Array = await _frames(tree, world, player, anim, rig, game_cam, close, clock, clip, SIDE_OFFSET)
		var path := out.path_join("arbeit_%s%s.jpg" % [series, suffix])
		_sheet(tiles).save_jpg(path, JPG_QUALITY)
		print("[ShotsTable] ", path, "  clip=", clip)
	player.call(&"cancel_timed_action")
	player.call(&"reset_tool")
	game_cam.make_current()
	close.queue_free()
	player.set_physics_process(true)


## The step / the draw, five moments of the clip's first cycle, the stow / the end.
static func _frames(tree: SceneTree, world: Node3D, player: Node3D, anim: AnimationPlayer, rig: Node3D, game_cam: Camera3D,
		close: Camera3D, clock: Node, clip: StringName, offset: Vector3 = CLOSE_OFFSET) -> Array:
	var tiles: Array = []
	var draw: StringName = _draw_clip(player, clip)
	if draw != &"":
		_step_until(player, anim, draw, 0.55)
	else:
		_step_seconds(player, anim, 0.15)
	tiles.append(await _shoot(tree, world, player, rig, game_cam, close, clock, offset))
	_step_until(player, anim, clip, 0.0)
	for f: float in MOMENTS:
		_step_until(player, anim, clip, f)
		tiles.append(await _shoot(tree, world, player, rig, game_cam, close, clock, offset))
	player.call(&"cancel_timed_action")
	var stow := _stow_clip(player, clip)
	if stow != &"":
		_step_until(player, anim, stow, 0.5)
	else:
		_step_seconds(player, anim, 0.3)
	tiles.append(await _shoot(tree, world, player, rig, game_cam, close, clock, offset))
	return tiles


## Where he stands for an extra series: `at` = Vector3 (place-local offset; he faces the place's origin) or a
## float (that far in front of the place along its +Z, facing it).
static func _stand(place: Node3D, at: Variant) -> Transform3D:
	var spot: Vector3
	if at is Vector3:
		spot = place.global_transform * (at as Vector3)
	else:
		spot = place.global_position + place.global_basis.z.normalized() * float(at)
	var d := place.global_position - spot
	d.y = 0.0
	spot.y = place.global_position.y
	return Transform3D(Basis(Vector3.UP, atan2(d.x, d.z)), spot)


static func _draw_clip(player: Node, clip: StringName) -> StringName:
	var cfg := _tool_cfg(player)
	var kind: StringName = (cfg.get(&"held_tools") as Dictionary).get(clip, &"")
	return (cfg.get(&"draw_clips") as Dictionary).get(kind, &"") if kind != &"" else &""


static func _stow_clip(player: Node, clip: StringName) -> StringName:
	var cfg := _tool_cfg(player)
	var kind: StringName = (cfg.get(&"held_tools") as Dictionary).get(clip, &"")
	return (cfg.get(&"stow_clips") as Dictionary).get(kind, &"") if kind != &"" else &""


static func _tool_cfg(player: Node) -> Resource:
	var animator: Object = player.get(&"_animator")
	return animator.get(&"tools") as Resource


static func _settle(tree: SceneTree, rig: Node3D, game_cam: Camera3D) -> void:
	game_cam.make_current()
	rig.call(&"snap")
	for i: int in SETTLE_FRAMES:
		await tree.process_frame


## Both cameras: the close one (scaled to a tile) and the room camera (a tile at 1:1 around him).
static func _shoot(tree: SceneTree, world: Node3D, player: Node3D, rig: Node3D, game_cam: Camera3D, close: Camera3D,
		clock: Node, offset: Vector3 = CLOSE_OFFSET) -> Array:
	clock.call(&"load_state", {"day": DAY, "minute_of_day": MINUTE})  # the long action ran the clock on
	clock.call(&"emit_refresh")
	var out: Array = []
	var focus := player.global_position + Vector3(0.0, CLOSE_LOOK, 0.0) + player.global_basis.z * 0.35
	close.global_position = focus + player.global_basis * offset  # in front of him, a little to his left
	close.look_at(focus)
	close.make_current()
	for i: int in SETTLE_FRAMES:
		await tree.process_frame
	var img := tree.root.get_texture().get_image()
	img.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
	out.append(img)
	game_cam.make_current()
	rig.call(&"snap")
	for i: int in SETTLE_FRAMES:
		await tree.process_frame
	var full := tree.root.get_texture().get_image()
	# unproject works in the viewport's own size; the captured image may differ (window stretch)
	var vp := tree.root.get_visible_rect().size
	var p := game_cam.unproject_position(focus) * Vector2(full.get_width(), full.get_height()) / vp
	var x := clampi(int(p.x) - TILE.x / 2, 0, full.get_width() - TILE.x)
	var y := clampi(int(p.y) - TILE.y / 2, 0, full.get_height() - TILE.y)
	out.append(full.get_region(Rect2i(x, y, TILE.x, TILE.y)))
	return out


## Columns = moments, row 1 the close camera, row 2 the room camera.
static func _sheet(tiles: Array) -> Image:
	var gap := 4
	var sheet := Image.create(tiles.size() * (TILE.x + gap) - gap, 2 * TILE.y + gap, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i: int in tiles.size():
		for row: int in 2:
			var img: Image = tiles[i][row]
			img.convert(Image.FORMAT_RGB8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(i * (TILE.x + gap), row * (TILE.y + gap)))
	return sheet


## Steps until `clip` plays at `fraction` of its length (at most 6 s).
static func _step_until(player: Node, anim: AnimationPlayer, clip: StringName, fraction: float) -> void:
	var t := 0.0
	while t < 6.0:
		if anim.current_animation == clip and anim.current_animation_length > 0.0 and \
				anim.current_animation_position / anim.current_animation_length >= fraction:
			return
		_advance(player, anim)
		t += STEP


static func _step_seconds(player: Node, anim: AnimationPlayer, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		_advance(player, anim)
		t += STEP


static func _advance(player: Node, anim: AnimationPlayer) -> void:
	player.call(&"_physics_process", STEP)
	anim.advance(STEP)

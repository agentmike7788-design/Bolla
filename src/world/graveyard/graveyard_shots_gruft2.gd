extends RefCounted
## G8 round 2 screenshot set of graveyard_shots.gd (--gruft2): the new crypt entrance (user: „der
## Eingang soll zum Weg zeigen", bigger portal, open stair, paved forecourt, old and mossy). New game,
## real systems only; every spot is derived from data/world/graveyard_layout.json (site, access,
## stair), so the same set runs on the old and the new entrance. --shots=eingang,l1,l2,l3,abend,abstieg
## picks shots; --suffix=_web (Compatibility renderer) or --suffix=_before is appended to every name.
## Writes <out>/gruft_<shot><suffix>.jpg.

const LAYOUT := "res://data/world/graveyard_layout.json"
const SETTLE_FRAMES := 60
const JPG_QUALITY := 0.9
const DAY := 30
## name, levels (crypt), minute, where the gravekeeper stands ("access" = stair head, "stair" = half
## way down carrying the dead, "path" = on the main path near the gate), camera focus (site-local
## offset or "player"), distance. The shots that carry the dead come last.
const SHOTS: Array[Dictionary] = [
	{"name": "l1", "level": 1, "minute": 660, "where": "access", "distance": 14.0},
	{"name": "l2", "level": 2, "minute": 660, "where": "access", "distance": 14.0},
	{"name": "l3", "level": 3, "minute": 660, "where": "access", "distance": 14.0},
	{"name": "abend", "level": 3, "minute": 1190, "where": "access", "distance": 16.0},
	{"name": "nacht", "level": 1, "minute": 1330, "where": "access", "distance": 16.0},
	{"name": "eingang", "level": 1, "minute": 660, "where": "path", "distance": 22.0},
	{"name": "abstieg", "level": 1, "minute": 600, "where": "stair", "distance": 11.0},
]


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray, suffix: String) -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var site_cfg: Dictionary = {}
	for s: Dictionary in layout.buildings.sites:
		if s.building == "crypt":
			site_cfg = s
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var manager := world.get_node(^"Systems/CorpseManager")
	var buildings := world.get_node(^"Systems/Buildings")
	var site := world.get_node(^"Entities/site_crypt") as Node3D
	var anchor := Node3D.new()
	anchor.name = "Gruft2Anchor"
	world.add_child(anchor)
	var rot := deg_to_rad(float(site_cfg.rot_y))
	var access := Vector2(float(site_cfg.access[0]), float(site_cfg.access[1]))
	var st: Dictionary = site_cfg.stair
	var mid_z := (float(st.top_z) + float(st.bottom_z)) * 0.5
	var on_stair := site.to_global(Vector3(0.0, -float(st.depth) * 0.5 + 0.1, mid_z))
	var gate := Vector2(float(layout.waypoints.gate_inside[0]), float(layout.waypoints.gate_inside[1]))
	clock.call(&"load_state", {"day": DAY, "minute_of_day": 470})
	var bier := world.get_node(^"Entities/dropoff")
	var record: Object = manager.call(&"spawn_corpse", null, bier.call(&"slot_transform"), &"dropoff")
	for shot: Dictionary in SHOTS:
		if not only.is_empty() and not String(shot.name) in only:
			continue
		buildings.call(&"load_state", {"levels": {"crypt": int(shot.level)}})
		buildings.call(&"apply_levels")
		clock.call(&"load_state", {"day": DAY, "minute_of_day": int(shot.minute)})
		clock.call(&"emit_refresh")
		match String(shot.where):
			"path":
				if String(player.get(&"carried_id")) == "":
					manager.call(&"pick_up", String(record.get(&"id")), player)
				var p := gate.lerp(access, 0.5)
				player.global_position = _ground(world, p)
				var d := access - p
				player.rotation.y = atan2(d.x, d.y)
				anchor.global_position = player.global_position
			"access":
				var p := access + Vector2(sin(rot), cos(rot)) * 0.6 + Vector2(cos(rot), -sin(rot)) * 1.2
				player.global_position = _ground(world, p)
				player.rotation.y = rot + PI * 0.75
				anchor.global_position = site.to_global(Vector3(0.0, 0.0, 0.6))
			"stair":
				if String(player.get(&"carried_id")) == "":
					manager.call(&"pick_up", String(record.get(&"id")), player)
				player.global_position = on_stair
				player.rotation.y = rot + PI
				anchor.global_position = site.to_global(Vector3(0.0, 0.0, mid_z * 0.6))
		rig.set(&"target", anchor)
		rig.call(&"set_distance", float(shot.distance))
		ui.visible = bool(shot.get("ui", false))
		player.set_physics_process(false)
		for i: int in 3:
			await tree.process_frame
		rig.call(&"snap")
		for i: int in SETTLE_FRAMES:
			await tree.process_frame
		rig.call(&"snap")
		await tree.process_frame
		var path := out.path_join("gruft_%s%s.jpg" % [shot.name, suffix])
		tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
		player.set_physics_process(true)
		print("[ShotsGruft2] ", path, "  level ", buildings.call(&"level", &"crypt"), "  carried '", player.get(&"carried_id"), "'")
	anchor.queue_free()


static func _ground(world: Node3D, p: Vector2) -> Vector3:
	return Vector3(p.x, float(world.call(&"ground_height", p)), p.y)

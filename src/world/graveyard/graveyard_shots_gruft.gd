extends RefCounted
## P8-pre screenshot set of graveyard_shots.gd (--gruft): the crypt from the start of a game
## (04.10.2026, user's wish „Gruft von Beginn an“). New game, day 1, real systems only: Osric's first
## dead on the bier, the stair under the old oak open, the gravekeeper carrying the dead down
## (CorpseManager.pick_up, BuildingDoor → HutPortal) and laying it on the crypt table
## (MorgueTable.interact). The HUD stays on (objective line). Writes <out>/gruft_start_0N_*.jpg.
## Autoload-using classes are loaded by path (see graveyard_shots.gd).

const PORTAL := "res://src/world/hut_interior/hut_portal.gd"
const SETTLE_FRAMES := 60
const JPG_QUALITY := 0.9
const DAY := 1
const SHOTS: Array[Dictionary] = [
	# The stair under the oak in the south-west corner of the Alter Hof, the dead on the bier at the gate.
	{"name": "gruft_start_01_treppe", "minute": 480, "where": "bier", "focus": Vector2(-3.2, 6.6), "distance": 20.0},
	# The gravekeeper carries the dead down the stair.
	{"name": "gruft_start_02_hinab", "minute": 490, "where": "stair", "focus": Vector2(-9.0, 8.2), "distance": 11.0},
	# Below: the dead on the crypt table, the gravekeeper beside it (room camera profile).
	{"name": "gruft_start_03_gruft_tisch", "minute": 500, "where": "crypt"},
]
## Where the gravekeeper stands: at the bier, on the stair (x, z), in the crypt next to the table (room-local).
const AT_BIER := Vector2(3.6, 7.4)
const ON_STAIR := Vector2(-9.0, 8.7)
const AT_TABLE := Vector2(0.95, 0.55)


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var manager := world.get_node(^"Systems/CorpseManager")
	var buildings := world.get_node(^"Systems/Buildings")
	var portal: GDScript = load(PORTAL)
	var anchor := Node3D.new()
	anchor.name = "GruftAnchor"
	world.add_child(anchor)
	print("[ShotsGruft] crypt level %d, open %s" % [int(buildings.call(&"level", &"crypt")), str(buildings.call(&"is_open"))])
	# Osric's first dead of the day on the bier (the real delivery of day 1).
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
	var table: Node = room.get_node(^"Entities/MorgueTable")
	for shot: Dictionary in SHOTS:
		if not only.is_empty() and not String(shot.name).right(-12).left(2) in only:
			continue
		clock.call(&"load_state", {"day": DAY, "minute_of_day": int(shot.minute)})
		clock.call(&"emit_refresh")
		match String(shot.where):
			"bier":
				player.global_position = _ground_point(world, AT_BIER)
				player.rotation.y = PI * 0.5
				anchor.global_position = _ground_point(world, shot.focus)
				rig.set(&"target", anchor)
				rig.call(&"set_distance", float(shot.distance))
			"stair":
				manager.call(&"pick_up", id, player)
				player.global_position = _ground_point(world, ON_STAIR) + Vector3(0.0, 0.3, 0.0)
				# Turned half towards the stair (north-west), so the dead in his arms shows.
				player.rotation.y = -PI * 0.8
				print("[ShotsGruft] carried: '%s'" % player.get(&"carried_id"))
				anchor.global_position = _ground_point(world, shot.focus)
				rig.set(&"target", anchor)
				rig.call(&"set_distance", float(shot.distance))
			"crypt":
				if not bool(door.call(&"can_interact", player)):
					printerr("[ShotsGruft] the crypt door refuses: ", door.call(&"get_interaction_prompt", player))
				portal.call(&"arrive", player, room.call(&"spawn_transform"), true, &"crypt")
				table.call(&"interact", player)
				print("[ShotsGruft] on the crypt table: '%s' (location %s, room %s)" % [table.get(&"corpse_id"),
						record.get(&"location"), record.get(&"room")])
				player.global_transform = Transform3D(Basis(Vector3.UP, PI * 0.75), room.global_transform * Vector3(AT_TABLE.x, 0.0, AT_TABLE.y))
				rig.set(&"target", player)
				var cfg: Object = room.call(&"room_config")
				rig.call(&"set_distance", float(cfg.get(&"camera_distance")))
		ui.visible = true
		for i: int in 3:
			await tree.process_frame
		rig.call(&"snap")
		for i: int in SETTLE_FRAMES:
			await tree.process_frame
		rig.call(&"snap")
		await tree.process_frame
		var path := out.path_join("%s.jpg" % shot.name)
		tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
		print("[ShotsGruft] ", path, "  objective: ", _objective(ui))
	anchor.queue_free()


static func _ground_point(world: Node3D, p: Vector2) -> Vector3:
	return Vector3(p.x, float(world.call(&"ground_height", p)), p.y)


static func _objective(ui: Node) -> String:
	var hud: Node = ui.get(&"hud")
	return str(hud.call(&"objective_text")) if hud != null and hud.has_method(&"objective_text") else "?"

extends RefCounted
## Change-round-2 screenshot set of graveyard_shots.gd (--round2, docs §11): the bigger hut in
## the world by day / night, the interior through the in-game camera with the gravekeeper
## inside (portal + interior profile), and the chest / grave register panels over the room.
## Writes <out>/world_0N_*.jpg. Autoload-using classes are loaded by path (see graveyard_shots.gd).

const PORTAL := "res://src/world/hut_interior/hut_portal.gd"
const SETTLE_FRAMES := 40
const JPG_QUALITY := 0.9
## Player spot in front of the hut door (door-local, the door faces +Z).
const DOOR_FRONT := Vector3(0.35, 0.0, 1.1)
## Where the gravekeeper stands in the room for the interior shots (room-local x, z) and his yaw.
const ROOM_SPOT := Vector2(-0.35, 0.35)
const ROOM_YAW_DEG := 20.0
const CHEST_ITEMS := {&"wood": 8, &"stone": 5, &"linen": 3, &"shroud": 1, &"wooden_cross": 1}
## Extra burials for the register shot, through the real systems: [plot, day, marker or &""].
const REGISTER_BURIALS: Array[Array] = [["plot_01", 2, &"gravestone_simple"], ["plot_02", 3, &"wooden_cross"], ["plot_03", 3, &""]]
## Day shown in the shots (after the extra burials).
const SHOT_DAY := 3
const SHOTS: Array[Dictionary] = [
	{"name": "world_01_exterior_day", "minute": 660, "where": "outside", "focus": Vector2(-4.4, -6.5), "distance": 15.0},
	{"name": "world_02_exterior_night", "minute": 1350, "where": "outside", "focus": Vector2(-4.4, -6.5), "distance": 15.0},
	{"name": "world_03_interior_day", "minute": 660, "where": "inside"},
	{"name": "world_04_interior_night", "minute": 1350, "where": "inside"},
	{"name": "world_05_chest_open", "minute": 1290, "where": "inside", "panel": "chest"},
	{"name": "world_06_register_open", "minute": 1290, "where": "inside", "panel": "desk"},
]


static func run(tree: SceneTree, world: Node3D, out: String, only: PackedStringArray) -> void:
	var clock := tree.root.get_node(^"TimeManager")
	var player := world.get_node(^"Player") as CharacterBody3D
	var rig := world.get_node(^"CameraRig") as Node3D
	var ui := world.get_node(^"UI") as CanvasLayer
	var interior := world.get_node(^"HutInterior") as Node3D
	var door := world.get_node(^"Entities/hut_door") as Node3D
	var portal: GDScript = load(PORTAL)
	var anchor := Node3D.new()
	anchor.name = "Round2Anchor"
	world.add_child(anchor)
	var chest := interior.get_node(^"Entities/chest")
	var storage: Node = chest.get(&"storage")
	for id: StringName in CHEST_ITEMS:
		storage.call(&"add_item", id, CHEST_ITEMS[id])
	for shot: Dictionary in SHOTS:
		if not only.is_empty() and not String(shot.name).right(-6).left(2) in only:
			continue
		ui.call(&"close_all")
		if shot.get("panel", "") == "desk":
			_bury_more(world, clock)
		clock.call(&"load_state", {"day": SHOT_DAY, "minute_of_day": shot.minute})
		clock.call(&"emit_refresh")
		if shot.where == "inside":
			var at := interior.global_transform * Vector3(ROOM_SPOT.x, 0.0, ROOM_SPOT.y)
			portal.call(&"arrive", player, Transform3D(Basis(Vector3.UP, deg_to_rad(ROOM_YAW_DEG)), at), true)
			rig.set("target", player)
		else:
			var front := Transform3D(door.global_basis, door.global_transform * DOOR_FRONT)
			portal.call(&"arrive", player, front, false)
			anchor.global_position = Vector3(shot.focus.x, 0.0, shot.focus.y)
			rig.set("target", anchor)
			rig.call(&"set_distance", float(shot.distance))
		rig.call(&"snap")
		ui.visible = shot.has("panel")
		match String(shot.get("panel", "")):
			"chest":
				chest.call(&"interact", player)
			"desk":
				interior.get_node(^"Entities/desk").call(&"interact", player)
		for i: int in SETTLE_FRAMES:
			await tree.process_frame
		rig.call(&"snap")
		await tree.process_frame
		var path := out.path_join("%s.jpg" % shot.name)
		tree.root.get_texture().get_image().save_jpg(path, JPG_QUALITY)
		print("[Shots] ", path)
	ui.call(&"close_all")


## More real burials (dig, bury, marker) on given days, so the register shows several lines.
static func _bury_more(world: Node3D, clock: Node) -> void:
	var manager := world.get_node(^"Systems/CorpseManager")
	var graveyard := world.get_node(^"Systems/Graveyard")
	var inv: Node = world.get_node(^"Player/Inventory")
	for entry: Array in REGISTER_BURIALS:
		var grave: RefCounted = graveyard.call(&"get_grave", entry[0])
		if grave == null or int(grave.get(&"state")) != 0:
			continue
		clock.call(&"load_state", {"day": entry[1], "minute_of_day": 600})
		graveyard.call(&"dig", entry[0])
		var plot := world.get_node(NodePath("Entities/" + String(entry[0]))) as Node3D
		var record: RefCounted = manager.call(&"spawn_corpse", null, plot.global_transform, &"ground")
		graveyard.call(&"bury", entry[0], record.get("id"))
		if entry[2] != &"":
			inv.call(&"add_item", entry[2], 1)
			graveyard.call(&"place_marker", entry[0], entry[2], inv)

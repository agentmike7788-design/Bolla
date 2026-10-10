extends SceneTree
## Re-bakes only the Phase-8 walking net of the built graveyard.tscn (docs/PHASE8_DESIGN.md §4.2, §4.8): loads the
## scene, drops the baked markers gv_* / vw_*, runs graveyard_build_phase8.gd's bake_nav on it and saves the scene,
## the GraveyardNav and the layout keys again – after a change of the layout's phase8.nav / visitor_spot values
## without the full world build (the colliders must be those of the current scene; moved layout waypoints
## follow):
##   tools/godot_run.sh -s res://src/world/graveyard/graveyard_rebake_nav.gd

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Phase8 := preload("res://src/world/graveyard/graveyard_build_phase8.gd")
const SCENE := "res://src/world/graveyard/graveyard.tscn"
const LAYOUT_PATH := "res://data/world/graveyard_layout.json"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var ctx := Ctx.new(self)
	ctx.layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	ctx.cell = float(ctx.layout.ground.cell)
	ctx.build_height_lookup()
	var root := (load(SCENE) as PackedScene).instantiate() as Node3D
	ctx.scene_root = root
	var waypoints := root.get_node("Waypoints") as Node3D
	for m: Node in waypoints.get_children():
		if String(m.name).begins_with("gv_") or String(m.name).begins_with("vw_"):
			waypoints.remove_child(m)
			m.free()
	# The layout waypoints themselves (a moved place) – position and facing as Entities.build_waypoints sets them.
	var facing: Dictionary = ctx.layout.get("waypoint_facing", {})
	for id: String in ctx.layout.waypoints:
		var m := waypoints.get_node_or_null(id) as Marker3D
		if m == null:
			m = Marker3D.new()
			m.name = id
			ctx.add(waypoints, m)
		var p := Ctx.v2(ctx.layout.waypoints[id])
		m.position = Vector3(p.x, ctx.ground_height(p), p.y)
		if facing.has(id):
			m.rotation_degrees.y = float(facing[id])
			m.set_meta(&"facing", true)
	Phase8.bake_nav(ctx, waypoints)
	var ps := PackedScene.new()
	assert(ps.pack(root) == OK)
	assert(ResourceSaver.save(ps, SCENE) == OK)
	print("  saved ", SCENE)
	root.free()
	print("REBAKE OK")
	quit()

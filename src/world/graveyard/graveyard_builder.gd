extends SceneTree
## Generates the vertical-slice world graveyard.tscn (+ grass.scn) from
## data/world/graveyard_layout.json (docs/VERTICAL_SLICE_DESIGN.md §4). Needs a real renderer
## (headless drops MultiMesh data):
##   tools/godot_run.sh -s res://src/world/graveyard/graveyard_builder.gd
## Re-running overwrites graveyard.tscn, grass.scn and ground_shape.res. Tune the layout
## (shared with Blender), not the scene.
## Patterns of the frozen art_prototype_builder.gd: ground height lookup from the painted
## ground mesh, OmniLights at light_* markers (layout "lights"), persistent groups.

const LAYOUT_PATH := "res://data/world/graveyard_layout.json"
const OUT_SCENE := "res://src/world/graveyard/graveyard.tscn"
const OUT_GRASS := "res://src/world/graveyard/grass.scn"
const OUT_GROUND_SHAPE := "res://src/world/graveyard/ground_shape.res"
const MODELS := "res://assets/models/"
const GROUND_ASSET := "ph_env_ground_graveyard"
const GRASS_ASSET := "ph_env_grass_tuft"
const TREE_ASSET := "ph_env_tree_old_oak"
const BUSH_ASSET := "ph_env_bush"
const WORLD_SCRIPT := "res://src/world/graveyard/world_root.gd"
## Scripts are loaded by path: while this -s script compiles the autoloads (EventBus, …) are
## no globals yet, so classes that use them must not be referenced by class_name here.
const CORPSE_MANAGER_SCRIPT := "res://src/systems/corpse/corpse_manager.gd"
const GRAVEYARD_SCRIPT := "res://src/systems/graveyard/graveyard.gd"
const ATMOSPHERE_SCRIPT := "res://src/world/atmosphere/atmosphere_controller.gd"
const CAMERA_SCRIPT := "res://src/world/camera/camera_rig.gd"
const SHADOW_GOVERNOR_SCRIPT := "res://src/world/graveyard/warm_shadow_governor.gd"
## GravePlot collision roles (see grave_plot.gd ROLE_*).
const ROLE_PIT := "pit"
const ROLE_MOUND := "mound"
const ROLE_MARKER := "marker:"
const ROLE_OLD := "old"
const CORPSE_SCENE := "res://src/entities/corpse/corpse.tscn"
const PLOT_SCENE := "res://src/entities/grave/grave_plot.tscn"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"
const UI_SCENE := "res://src/ui/ui_root.tscn"
const ENTITY_SCENES := {
	"morgue_table": "res://src/entities/morgue_table/morgue_table.tscn",
	"workbench": "res://src/entities/workbench/workbench.tscn",
	"dropoff": "res://src/entities/dropoff/dropoff.tscn",
	"resource_node": "res://src/entities/resource_node/resource_node.tscn",
	"hut_door": "res://src/entities/hut_door/hut_door.tscn",
	"npc": "res://src/entities/npc/npc.tscn",
}
## Model of an entity type (for its colliders); resource nodes use params.model.
const ENTITY_ASSETS := {"morgue_table": "ph_prop_morgue_table", "workbench": "ph_prop_workbench",
		"dropoff": "ph_prop_dropoff_bier"}
const PRESET_PATH := "res://data/atmosphere/%s.tres"
const FLICKER := preload("res://src/world/atmosphere/flicker_light.gd")
const WORLD_LAYER := 1

var layout: Dictionary
var scene_root: Node3D
var _heights: Dictionary = {}   # Vector2i(grid) -> height
var _grid_min := Vector2i.ZERO
var _grid_max := Vector2i.ZERO
var _cell: float = 0.3
var _colliders: Node3D
var _collider_count: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame  # autoloads (Database) are ready after the first frame
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_cell = float(layout.ground.cell)
	_build_height_lookup()
	_save_grass(_build_grass())
	_save(_build_world(), OUT_SCENE)
	print("BUILD OK")
	quit()


# --- helpers -----------------------------------------------------------------

func _save(node: Node, path: String) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(node)
	assert(err == OK, "pack failed: %s" % path)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed: %s" % path)
	print("  saved ", path)
	node.free()


func _add(parent: Node, child: Node, owner_node: Node = null) -> Node:
	parent.add_child(child)
	child.owner = owner_node if owner_node != null else scene_root
	return child


func _group(parent: Node, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	_add(parent, n)
	return n


func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _model_path(asset: String) -> String:
	for cat: String in ["props", "environment", "buildings", "characters"]:
		var p := MODELS + cat + "/" + asset + ".glb"
		if ResourceLoader.exists(p):
			return p
	push_error("asset not found: " + asset)
	return ""


func _rel_xform(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _ground_xform(pos: Vector2, rot_y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), Vector3(pos.x, ground_height(pos), pos.y))


## Instance a model at a layout position (x, z) on the ground, attach its lights.
## light_overrides: {marker: {key: value}} replaces values of the layout "lights" table.
func _place(asset: String, parent: Node, pos: Vector2, rot_y: float, node_name: String = "",
		light_overrides: Dictionary = {}) -> Node3D:
	var inst := (load(_model_path(asset)) as PackedScene).instantiate() as Node3D
	inst.name = node_name if node_name != "" else asset.trim_prefix("ph_")
	inst.transform = _ground_xform(pos, rot_y)
	_add(parent, inst)
	_attach_lights(asset, inst, light_overrides)
	return inst


func _attach_lights(asset: String, inst: Node3D, overrides: Dictionary = {}) -> void:
	var cfgs: Dictionary = layout.get("lights", {})
	for marker: Node in inst.find_children("light_*", "", true, false):
		var key := asset + "/" + marker.name
		if not cfgs.has(key):
			continue
		var cfg: Dictionary = (cfgs[key] as Dictionary).duplicate()
		cfg.merge(overrides.get(String(marker.name), {}), true)
		var light := OmniLight3D.new()
		light.name = "Light_" + String(marker.name).trim_prefix("light_")
		light.transform = _rel_xform(marker as Node3D, inst)
		light.light_color = Color(cfg.color)
		light.light_energy = cfg.energy
		light.omni_range = cfg.range
		light.omni_attenuation = 1.4
		light.shadow_enabled = cfg.shadow
		light.shadow_blur = 1.5
		light.set_meta("base_energy", cfg.energy)
		if cfg.flicker:
			light.set_script(FLICKER)
		_add(inst, light)
		light.add_to_group("warm_lights", true)


## Collision shapes of `asset` (layout "colliders") under a new StaticBody3D at `xform`.
## scale: uniform scale of the placed model; stretch_x: fence pieces shortened along X.
func _collider(asset: String, xform: Transform3D, body_name: String, scale: float = 1.0, stretch_x: float = 1.0) -> StaticBody3D:
	var defs: Array = layout.colliders.get(asset, [])
	if defs.is_empty():
		return null
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.transform = xform
	_add(_colliders, body)
	_add_shapes(body, defs, Transform3D.IDENTITY, scale, stretch_x, "")
	_collider_count += 1
	return body


func _add_shapes(body: Node3D, defs: Array, local: Transform3D, scale: float, stretch_x: float, role: String) -> void:
	for def: Dictionary in defs:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape%d" % body.get_child_count()
		var offset := _v3(def.offset) * scale
		offset.x *= stretch_x
		if def.shape == "box":
			var box := BoxShape3D.new()
			var size := _v3(def.size) * scale
			size.x *= stretch_x
			box.size = size
			shape_node.shape = box
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = float(def.radius) * scale
			cyl.height = float(def.height) * scale
			shape_node.shape = cyl
		shape_node.transform = local * Transform3D(Basis.IDENTITY, offset)
		if role != "":
			shape_node.set_meta(&"role", role)
			shape_node.disabled = role != ROLE_OLD
		_add(body, shape_node)


# --- ground height lookup (props sit on the painted, slightly uneven ground) ---

func _build_height_lookup() -> void:
	var scene := (load(_model_path(GROUND_ASSET)) as PackedScene).instantiate()
	var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_grid_min = Vector2i(1 << 30, 1 << 30)
	_grid_max = -_grid_min
	for v: Vector3 in verts:
		var key := Vector2i(roundi(v.x / _cell), roundi(v.z / _cell))
		_heights[key] = v.y
		_grid_min = Vector2i(mini(_grid_min.x, key.x), mini(_grid_min.y, key.y))
		_grid_max = Vector2i(maxi(_grid_max.x, key.x), maxi(_grid_max.y, key.y))
	scene.free()
	print("  ground grid ", _grid_min, " .. ", _grid_max)


func ground_height(p: Vector2) -> float:
	var g := p / _cell
	var x0 := floori(g.x)
	var z0 := floori(g.y)
	var fx := g.x - x0
	var fz := g.y - z0
	var h00: float = _heights.get(Vector2i(x0, z0), 0.0)
	var h10: float = _heights.get(Vector2i(x0 + 1, z0), 0.0)
	var h01: float = _heights.get(Vector2i(x0, z0 + 1), 0.0)
	var h11: float = _heights.get(Vector2i(x0 + 1, z0 + 1), 0.0)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


## Ground collision: a HeightMapShape3D of the same grid (uniform scale = cell size).
func _build_ground_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	_add(scene_root, body)
	var w := _grid_max.x - _grid_min.x + 1
	var d := _grid_max.y - _grid_min.y + 1
	var data := PackedFloat32Array()
	data.resize(w * d)
	for j: int in d:
		for i: int in w:
			data[j * w + i] = float(_heights.get(Vector2i(_grid_min.x + i, _grid_min.y + j), 0.0)) / _cell
	var hm := HeightMapShape3D.new()
	hm.map_width = w
	hm.map_depth = d
	hm.map_data = data
	var err := ResourceSaver.save(hm, OUT_GROUND_SHAPE)  # binary: keeps the .tscn small
	assert(err == OK, "save failed: %s" % OUT_GROUND_SHAPE)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = load(OUT_GROUND_SHAPE)
	var centre := Vector3((_grid_min.x + (w - 1) * 0.5) * _cell, 0.0, (_grid_min.y + (d - 1) * 0.5) * _cell)
	shape.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _cell), centre)
	_add(body, shape)


# --- world -------------------------------------------------------------------

func _build_world() -> Node:
	scene_root = Node3D.new()
	scene_root.name = "Graveyard"
	scene_root.set_script(load(WORLD_SCRIPT))
	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = _make_environment()
	_add(scene_root, env_node)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 1.2
	# One cascade: the fixed 45° camera sees nothing nearer than ~10 m (zoom_min), so the first
	# of the prototype's two splits (0.5–6 m) stayed empty and wasted half the atlas (PERF-03).
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 55.0
	_add(scene_root, sun)
	_add(scene_root, _build_atmosphere(env_node, sun))
	var governor: Node = load(SHADOW_GOVERNOR_SCRIPT).new()
	governor.name = "WarmShadows"
	governor.set("min_scale", float(layout.atmosphere.shadow_min_warm_scale))
	_add(scene_root, governor)

	# (WorldRoot switches the ground's shadow casting off at runtime – see world_root.gd.)
	_place(GROUND_ASSET, scene_root, Vector2.ZERO, 0.0, "Ground").transform = Transform3D.IDENTITY
	_build_ground_collision()
	_colliders = _group(scene_root, "Colliders")

	var systems := _group(scene_root, "Systems")
	var manager: Node = load(CORPSE_MANAGER_SCRIPT).new()
	manager.name = "CorpseManager"
	manager.set("corpse_scene", load(CORPSE_SCENE))
	manager.set("container_path", NodePath("../../Corpses"))
	_add(systems, manager)
	var graveyard: Node = load(GRAVEYARD_SCRIPT).new()
	graveyard.name = "Graveyard"
	_add(systems, graveyard)

	var entities := _group(scene_root, "Entities")
	for plot: Dictionary in layout.plots:
		_build_plot(entities, plot, false)
	for ent: Dictionary in layout.entities:
		_build_entity(entities, ent)

	var decor := _group(scene_root, "Decor")
	var old := _group(decor, "OldGraves")
	for g: Dictionary in layout.old_graves:
		_build_plot(old, g, true)
	_build_decor(decor)

	var waypoints := _group(scene_root, "Waypoints")
	var facing: Dictionary = layout.get("waypoint_facing", {})
	for id: String in layout.waypoints:
		var marker := Marker3D.new()
		marker.name = id
		var p := _v2(layout.waypoints[id])
		marker.position = Vector3(p.x, ground_height(p), p.y)
		if facing.has(id):
			marker.rotation_degrees.y = float(facing[id])
			marker.set_meta(&"facing", true)
		_add(waypoints, marker)
	_group(scene_root, "Corpses")

	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Node3D
	player.name = "Player"
	player.transform = _ground_xform(_v2(layout.player_start.pos), float(layout.player_start.rot_y))
	_add(scene_root, player)
	_build_camera(player)
	var ui := (load(UI_SCENE) as PackedScene).instantiate()
	ui.name = "UI"
	_add(scene_root, ui)
	_build_bounds()
	print("  colliders: ", _collider_count)
	return scene_root


func _build_atmosphere(env_node: WorldEnvironment, sun: DirectionalLight3D) -> Node:
	var cfg: Dictionary = layout.atmosphere
	var atmo: Node = load(ATMOSPHERE_SCRIPT).new()
	atmo.name = "Atmosphere"
	var presets: Array[AtmospherePreset] = []
	for id: String in cfg.presets:
		presets.append(load(PRESET_PATH % id))
	var blend: Array[AtmospherePreset] = []
	for id: String in cfg.blend_presets:
		blend.append(load(PRESET_PATH % id))
	atmo.set("presets", presets)
	atmo.set("blend_presets", blend)
	atmo.set("blend_minutes", PackedInt32Array(cfg.blend_minutes))
	atmo.set("time_driven", true)
	atmo.set("world_environment", env_node)
	atmo.set("sun", sun)
	return atmo


## GravePlot (entity or old grave) with its state-dependent collision shapes.
func _build_plot(parent: Node, g: Dictionary, old: bool) -> void:
	var plot := (load(PLOT_SCENE) as PackedScene).instantiate() as Node3D
	plot.name = g.id
	plot.set("grave_id", g.id)
	plot.set("is_old", old)
	plot.transform = _ground_xform(_v2(g.pos), float(g.rot_y))
	if old:
		plot.set("old_stone", g.stone)
		plot.set("old_mound", g.mound)
	_add(parent, plot)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	_add(plot, body)
	if old:
		_add_shapes(body, layout.colliders["ph_prop_grave_mound_" + String(g.mound)], Transform3D.IDENTITY, 1.0, 1.0, ROLE_OLD)
		_add_shapes(body, layout.colliders["ph_prop_gravestone_" + String(g.stone)],
				Transform3D(Basis.IDENTITY, plot.get("old_stone_offset")), 1.0, 1.0, ROLE_OLD)
		return
	_add_shapes(body, layout.colliders[_asset_of(plot.get("pit_model"))], Transform3D.IDENTITY, 1.0, 1.0, ROLE_PIT)
	_add_shapes(body, layout.colliders[_asset_of(plot.get("mound_model"))],
			Transform3D(Basis.IDENTITY, plot.get("mound_offset")), 1.0, 1.0, ROLE_MOUND)
	var markers: Dictionary = plot.get("marker_models")
	for marker_id: StringName in markers:
		_add_shapes(body, layout.colliders[_asset_of(markers[marker_id])],
				Transform3D(Basis.IDENTITY, plot.get("marker_offset")), 1.0, 1.0, ROLE_MARKER + String(marker_id))


func _asset_of(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename()


func _build_entity(parent: Node, ent: Dictionary) -> void:
	var node := (load(ENTITY_SCENES[ent.type]) as PackedScene).instantiate() as Node3D
	node.name = ent.id
	var pos := _v2(ent.pos)
	node.transform = _ground_xform(pos, float(ent.rot_y))
	var params: Dictionary = ent.get("params", {})
	match String(ent.type):
		"resource_node":
			node.set("save_id", params.save_id)
			node.set("item_id", StringName(params.item_id))
			node.set("daily_amount", int(params.daily_amount))
			node.set("model", load(_model_path(params.model)))
			node.set("action_label", params.get("action_label", ""))
		"npc":
			node.set("save_id", params.save_id)
			node.set("npc_id", StringName(params.npc_id))
			node.set("model", load(_model_path(params.model)))
		"workbench":
			node.set("station", StringName(params.get("station", "workbench")))
	_add(parent, node)
	var asset: String = ENTITY_ASSETS.get(ent.type, params.get("model", "") if ent.type == "resource_node" else "")
	if asset != "":
		_collider(asset, node.transform, ent.id)


func _build_decor(decor: Node3D) -> void:
	_place("ph_bld_gravekeeper_hut", decor, _v2(layout.hut.pos), layout.hut.rot_y, "Hut")
	_collider("ph_bld_gravekeeper_hut", _ground_xform(_v2(layout.hut.pos), layout.hut.rot_y), "Hut")
	_place(TREE_ASSET, decor, _v2(layout.tree.pos), layout.tree.rot_y, "Tree")
	_collider(TREE_ASSET, _ground_xform(_v2(layout.tree.pos), layout.tree.rot_y), "Tree")
	var trees := _group(decor, "Trees")
	var k := 0
	for t: Dictionary in layout.background_trees + layout.forest.trees:
		k += 1
		var tree := _place(TREE_ASSET, trees, _v2(t.pos), t.rot_y, "Tree_%02d" % k)
		tree.scale = Vector3.ONE * float(t.scale)
		_collider(TREE_ASSET, _ground_xform(_v2(t.pos), t.rot_y), "Tree_%02d" % k, float(t.scale))
	var bushes := _group(decor, "Bushes")
	k = 0
	for b: Dictionary in layout.forest.bushes:
		k += 1
		var bush := _place(BUSH_ASSET, bushes, _v2(b.pos), b.rot_y, "Bush_%02d" % k)
		bush.scale = Vector3.ONE * float(b.scale)
		_collider(BUSH_ASSET, _ground_xform(_v2(b.pos), b.rot_y), "Bush_%02d" % k, float(b.scale))
	var posts := _group(decor, "LanternPosts")
	k = 0
	for lp: Dictionary in layout.lantern_posts:
		k += 1
		_place("ph_prop_lantern_post", posts, _v2(lp.pos), lp.rot_y, "LanternPost_%d" % k, lp.get("light_overrides", {}))
		_collider("ph_prop_lantern_post", _ground_xform(_v2(lp.pos), lp.rot_y), "LanternPost_%d" % k)
	_build_fence(_group(decor, "Fence"))
	var props := _group(decor, "Props")
	k = 0
	for pr: Dictionary in layout.props:
		k += 1
		_place(pr.asset, props, _v2(pr.pos), pr.rot_y, "%s_%d" % [String(pr.asset).trim_prefix("ph_prop_"), k])
		_collider(pr.asset, _ground_xform(_v2(pr.pos), pr.rot_y), "Prop_%d" % k)
	var sign_cfg: Dictionary = layout.signpost
	var signpost := _place("ph_prop_signpost", decor, _v2(sign_cfg.pos), sign_cfg.rot_y, "Signpost")
	_collider("ph_prop_signpost", signpost.transform, "Signpost")
	_add_sign_label(signpost, sign_cfg)
	var log_cfg: Dictionary = layout.fallen_log
	var fallen := _place("ph_prop_fallen_log", decor, _v2(log_cfg.pos), log_cfg.rot_y, "FallenLog")
	_collider("ph_prop_fallen_log", fallen.transform, "FallenLog")
	var grass := (load(OUT_GRASS) as PackedScene).instantiate()
	grass.name = "Grass"
	_add(decor, grass)


func _build_fence(fence: Node3D) -> void:
	var piece_len: float = layout.colliders["ph_prop_fence_iron"][0].size[0]
	var k := 0
	for seg: Array in layout.fence.segments:
		var a := _v2(seg[0])
		var b := _v2(seg[1])
		var d := b - a
		var count := ceili(d.length() / piece_len - 0.001)
		for i: int in count:
			k += 1
			var start := a + d.normalized() * piece_len * i
			var rot := rad_to_deg(atan2(-d.y, d.x))
			var piece := _place("ph_prop_fence_iron", fence, start, rot, "fence_%02d" % k)
			var remaining := d.length() - piece_len * i
			var stretch := minf(remaining / piece_len, 1.0)
			if stretch < 1.0:
				piece.scale.x = stretch
			_collider("ph_prop_fence_iron", _ground_xform(start, rot), "Fence_%02d" % k, 1.0, stretch)
	k = 0
	for gp: Array in layout.fence.gate_posts:
		k += 1
		_place("ph_prop_gate_post", fence, _v2(gp), 0.0, "gate_post_%d" % k)
		_collider("ph_prop_gate_post", _ground_xform(_v2(gp), 0.0), "GatePost_%d" % k)


## Label3D "Hollerbrück" on the signpost's label_board marker (front face, +Z).
func _add_sign_label(signpost: Node3D, cfg: Dictionary) -> void:
	var marker := signpost.find_child("label_board", true, false) as Node3D
	if marker == null:
		push_error("signpost has no label_board marker")
		return
	var label := Label3D.new()
	label.name = "Label"
	label.text = cfg.text
	label.font_size = int(cfg.font_size)
	label.pixel_size = float(cfg.pixel_size)
	label.modulate = Color(cfg.color)
	label.outline_size = 0
	label.shaded = true
	label.double_sided = false
	label.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	label.transform = _rel_xform(marker, signpost) * Transform3D(Basis.IDENTITY, Vector3(0, 0, float(cfg.surface_offset)))
	_add(signpost, label)


func _build_camera(player: Node3D) -> void:
	var cfg: Dictionary = layout.camera_bounds
	var rig: Node3D = load(CAMERA_SCRIPT).new()
	rig.name = "CameraRig"
	rig.set("distance", float(cfg.distance))
	rig.set("zoom_min", float(cfg.zoom_min))
	rig.set("zoom_max", float(cfg.zoom_max))
	rig.set("bounds_enabled", true)
	rig.set("bounds_min", _v2(cfg.min))
	rig.set("bounds_max", _v2(cfg.max))
	_add(scene_root, rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	_add(rig, cam)
	rig.set("target", player)


## Invisible walls around walkable_bounds (layer 1).
func _build_bounds() -> void:
	var cfg: Dictionary = layout.walkable_bounds
	var lo := _v2(cfg.min)
	var hi := _v2(cfg.max)
	var h := float(cfg.wall_height)
	var t := float(cfg.wall_thickness)
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	_add(_colliders, body)
	var mid := (lo + hi) * 0.5
	var size := hi - lo
	var walls := {
		"West": [Vector3(lo.x - t * 0.5, h * 0.5, mid.y), Vector3(t, h, size.y + 2.0 * t)],
		"East": [Vector3(hi.x + t * 0.5, h * 0.5, mid.y), Vector3(t, h, size.y + 2.0 * t)],
		"North": [Vector3(mid.x, h * 0.5, lo.y - t * 0.5), Vector3(size.x + 2.0 * t, h, t)],
		"South": [Vector3(mid.x, h * 0.5, hi.y + t * 0.5), Vector3(size.x + 2.0 * t, h, t)],
	}
	for wall_name: String in walls:
		var shape := CollisionShape3D.new()
		shape.name = wall_name
		var box := BoxShape3D.new()
		box.size = walls[wall_name][1]
		shape.shape = box
		shape.position = walls[wall_name][0]
		_add(body, shape)


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.8
	env.glow_enabled = true
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.fog_enabled = true
	env.fog_sky_affect = 0.5
	env.fog_height = 0.4
	env.fog_height_density = 0.12
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_ambient_inject = 0.35
	env.volumetric_fog_anisotropy = 0.3
	env.adjustment_enabled = true
	return env


# --- grass (chunked MultiMeshes so the camera culls what it does not see) -----

func _build_grass() -> Node3D:
	var cfg: Dictionary = layout.grass
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var clump := FastNoiseLite.new()
	clump.seed = int(cfg.seed)
	clump.frequency = 0.18
	var lo := Vector2(_grid_min) * _cell + Vector2(0.5, 0.5)
	var hi := Vector2(_grid_max) * _cell - Vector2(0.5, 0.5)
	var area := (hi.x - lo.x) * (hi.y - lo.y)
	var target := int(float(cfg.density) * area)
	var keep := _grass_keep_out()
	var wb: Dictionary = layout.walkable_bounds
	var inner := Rect2(_v2(wb.min), _v2(wb.max) - _v2(wb.min)).grow(float(cfg.outer_margin))
	var chunk := float(cfg.chunk)
	var chunks: Dictionary = {}   # Vector2i -> Array[Transform3D]
	var placed := 0
	var tries := 0
	while placed < target and tries < target * 20:
		tries += 1
		var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		if clump.get_noise_2d(p.x * 10.0, p.y * 10.0) * 0.5 + 0.5 < rng.randf() * 0.85:
			continue
		if not inner.has_point(p) and rng.randf() > float(cfg.outer_density):
			continue
		if _kept_out(p, keep):
			continue
		if _hidden(p, keep) and rng.randf() > float(cfg.hidden_density):
			continue
		var s := rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		var key := Vector2i(floori(p.x / chunk), floori(p.y / chunk))
		if not chunks.has(key):
			chunks[key] = []
		(chunks[key] as Array).append(Transform3D(basis, Vector3(p.x, ground_height(p) - 0.01, p.y)))
		placed += 1
	var tuft := (load(_model_path(GRASS_ASSET)) as PackedScene).instantiate()
	var mesh := ((tuft.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh).duplicate() as Mesh
	tuft.free()
	var root := Node3D.new()
	root.name = "Grass"
	var keys := chunks.keys()
	keys.sort()
	for key: Vector2i in keys:
		var xforms: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = xforms.size()
		for i: int in xforms.size():
			mm.set_instance_transform(i, xforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Chunk_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = float(cfg.visibility_range)
		root.add_child(mmi)
		mmi.owner = root
	print("  grass tufts: %d in %d chunks" % [placed, keys.size()])
	return root


func _save_grass(root: Node3D) -> void:
	var ps := PackedScene.new()
	var err := ps.pack(root)
	assert(err == OK, "pack failed: grass")
	err = ResourceSaver.save(ps, OUT_GRASS)
	assert(err == OK, "save failed: grass")
	print("  saved ", OUT_GRASS)
	root.free()


## Keep-out shapes: polylines {pts, r}, circles {c, r}, rotated rects {pos, rot, rect}.
func _grass_keep_out() -> Dictionary:
	var cfg: Dictionary = layout.grass
	var lines: Array[Dictionary] = []
	lines.append({"pts": _points(layout.path.points), "r": float(cfg.keep_out_radius_path)})
	lines.append({"pts": _points(layout.road.points), "r": float(cfg.keep_out_radius_road)})
	for route: Array[Vector2] in _npc_routes():
		lines.append({"pts": route, "r": float(cfg.keep_out_route)})
	var circles: Array[Dictionary] = []
	circles.append({"c": _v2(layout.tree.pos), "r": 0.9})
	for t: Dictionary in layout.background_trees + layout.forest.trees:
		circles.append({"c": _v2(t.pos), "r": 1.0 * float(t.scale)})
	for b: Dictionary in layout.forest.bushes:
		circles.append({"c": _v2(b.pos), "r": 0.5 * float(b.scale)})
	circles.append({"c": _v2(layout.hut.pos), "r": float(cfg.keep_out_building)})
	for lp: Dictionary in layout.lantern_posts:
		circles.append({"c": _v2(lp.pos), "r": 0.35})
	for gp: Array in layout.fence.gate_posts:
		circles.append({"c": _v2(gp), "r": 0.35})
	circles.append({"c": _v2(layout.signpost.pos), "r": 0.35})
	for pr: Dictionary in layout.props:
		circles.append({"c": _v2(pr.pos), "r": 0.5})
	var rects: Array[Dictionary] = []
	var plot_rect: Array = layout.ground.plot_flat_rect
	for pl: Dictionary in layout.plots:
		rects.append({"pos": _v2(pl.pos), "rot": float(pl.rot_y),
				"rect": Rect2(plot_rect[0], plot_rect[1], plot_rect[2] - plot_rect[0], plot_rect[3] - plot_rect[1])})
	for g: Dictionary in layout.old_graves:
		rects.append({"pos": _v2(g.pos), "rot": float(g.rot_y), "rect": Rect2(-0.62, -1.35, 1.24, 2.35)})
	var margin := float(cfg.keep_out_station)
	for ent: Dictionary in layout.entities:
		var asset: String = ENTITY_ASSETS.get(ent.type, (ent.params as Dictionary).get("model", ""))
		var defs: Array = layout.colliders.get(asset, [])
		if ent.type == "hut_door":
			rects.append({"pos": _v2(ent.pos), "rot": float(ent.rot_y), "rect": Rect2(-0.9, -1.0, 1.8, 1.8)})
		elif not defs.is_empty():
			var size := _v3(defs[0].size)
			var off := _v3(defs[0].offset)
			rects.append({"pos": _v2(ent.pos), "rot": float(ent.rot_y),
					"rect": Rect2(off.x - size.x * 0.5, off.z - size.z * 0.5, size.x, size.z).grow(margin)})
	var log_def: Dictionary = layout.colliders["ph_prop_fallen_log"][0]
	var log_size := _v3(log_def.size)
	var log_off := _v3(log_def.offset)
	rects.append({"pos": _v2(layout.fallen_log.pos), "rot": float(layout.fallen_log.rot_y),
			"rect": Rect2(log_off.x - log_size.x * 0.5, log_off.z - log_size.z * 0.5, log_size.x, log_size.z).grow(margin)})
	# Ground the camera cannot see: behind tree crowns (north of the trunk) and the hut roof.
	var hidden: Array[Dictionary] = []
	for t: Dictionary in [layout.tree] + layout.background_trees + layout.forest.trees:
		var s := float(t.get("scale", 1.0))
		hidden.append({"c": _v2(t.pos) + Vector2(0.0, -float(cfg.hidden_crown_offset) * s),
				"r": float(cfg.hidden_crown_radius) * s})
	var hut := _v2(layout.hut.pos)
	var hut_rect := Rect2(-2.2, -1.9 - float(cfg.hidden_hut_depth), 4.4, float(cfg.hidden_hut_depth))
	return {"lines": lines, "circles": circles, "rects": rects, "hidden": hidden,
			"hidden_rects": [{"pos": hut, "rot": float(layout.hut.rot_y), "rect": hut_rect}]}


func _hidden(p: Vector2, keep: Dictionary) -> bool:
	for c: Dictionary in keep.hidden:
		if p.distance_to(c.c) < float(c.r):
			return true
	for r: Dictionary in keep.hidden_rects:
		var local := (p - (r.pos as Vector2)).rotated(deg_to_rad(float(r.rot)))
		if (r.rect as Rect2).has_point(local):
			return true
	return false


func _kept_out(p: Vector2, keep: Dictionary) -> bool:
	for line: Dictionary in keep.lines:
		if _dist_to_polyline(p, line.pts) < float(line.r):
			return true
	for c: Dictionary in keep.circles:
		if p.distance_to(c.c) < float(c.r):
			return true
	for r: Dictionary in keep.rects:
		var local := (p - (r.pos as Vector2)).rotated(deg_to_rad(float(r.rot)))
		if (r.rect as Rect2).has_point(local):
			return true
	return false


## Waypoint polylines of every NPC schedule entry (the carter's cart track stays free of grass).
func _npc_routes() -> Array:
	var routes: Array = []
	for ent: Dictionary in layout.entities:
		if ent.type != "npc":
			continue
		# Autoload names are not globals while this -s script compiles: look the node up.
		var sched: Resource = root.get_node(^"Database").call(&"schedule", StringName(ent.params.npc_id))
		if sched == null:
			continue
		for e: Resource in sched.get("entries"):
			var path: PackedStringArray = e.get("path")
			if path.size() < 2:
				continue
			var pts: Array[Vector2] = []
			for id: String in path:
				pts.append(_v2(layout.waypoints[id]))
			routes.append(pts)
	return routes


func _points(raw: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Array in raw:
		out.append(_v2(p))
	return out


func _dist_to_polyline(p: Vector2, pts: Array[Vector2]) -> float:
	var best := INF
	for k: int in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])))
	return best

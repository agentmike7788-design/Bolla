extends SceneTree
## Generates the art-direction prototype scene from data/art_prototype/layout.json.
##   godot --headless --path . -s res://src/world/art_prototype/art_prototype_builder.gd
## Re-running overwrites art_prototype.tscn, player_proto.tscn and grass_multimesh.res.
## Tune the layout in the JSON (single source of truth shared with Blender), not in the scene.

const LAYOUT_PATH := "res://data/art_prototype/layout.json"
const OUT_SCENE := "res://src/world/art_prototype/art_prototype.tscn"
const OUT_PLAYER := "res://src/entities/player/player_proto.tscn"
const OUT_GRASS := "res://src/world/art_prototype/grass_multimesh.res"
const MODELS := "res://assets/models/"
const FLICKER := preload("res://src/world/atmosphere/flicker_light.gd")

var layout: Dictionary
var scene_root: Node3D
var _heights: Dictionary = {}   # Vector2i(grid) -> height
var _cell: float = 0.3


func _initialize() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	_cell = float(layout.ground_cell)
	_build_height_lookup()
	_save(_build_player(), OUT_PLAYER)
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


func _own(node: Node, owner_node: Node) -> void:
	node.owner = owner_node


func _add(parent: Node, child: Node, owner_node: Node = null) -> Node:
	parent.add_child(child)
	child.owner = owner_node if owner_node else scene_root
	return child


func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


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


## Instance a model at a layout position (x, z) on the ground, attach its lights.
func _place(asset: String, parent: Node, pos: Vector2, rot_y: float, owner_node: Node = null,
		node_name: String = "") -> Node3D:
	var own := owner_node if owner_node else scene_root
	var inst := (load(_model_path(asset)) as PackedScene).instantiate() as Node3D
	inst.name = node_name if node_name != "" else asset.trim_prefix("ph_")
	inst.position = Vector3(pos.x, ground_height(pos), pos.y)
	inst.rotation_degrees.y = rot_y
	_add(parent, inst, own)
	_attach_lights(asset, inst, own)
	return inst


func _attach_lights(asset: String, inst: Node3D, owner_node: Node) -> void:
	var cfgs: Dictionary = layout.get("lights", {})
	for marker: Node in inst.find_children("light_*", "", true, false):
		var key := asset + "/" + marker.name
		if not cfgs.has(key):
			continue
		var cfg: Dictionary = cfgs[key]
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
		_add(inst, light, owner_node)
		light.add_to_group("warm_lights", true)


# --- ground height lookup (so props sit on the painted, slightly uneven ground) ---

func _build_height_lookup() -> void:
	var scene := (load(MODELS + "environment/ph_env_ground.glb") as PackedScene).instantiate()
	var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v: Vector3 in verts:
		_heights[Vector2i(roundi(v.x / _cell), roundi(v.z / _cell))] = v.y
	scene.free()


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


# --- player ------------------------------------------------------------------

func _build_player() -> Node:
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.set_script(load("res://src/entities/player/player_proto.gd"))
	p.collision_layer = 2
	p.collision_mask = 1
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	col.shape = cap
	col.position.y = 0.85
	_add(p, col, p)
	var model := Node3D.new()
	model.name = "Model"
	_add(p, model, p)
	_place("ph_chr_gravekeeper", model, Vector2.ZERO, 0.0, p, "Gravekeeper").position = Vector3.ZERO
	return p


# --- world -------------------------------------------------------------------

func _build_world() -> Node:
	scene_root = Node3D.new()
	scene_root.name = "ArtPrototype"
	scene_root.set_script(load("res://src/world/art_prototype/art_prototype.gd"))

	var env_node := WorldEnvironment.new()
	env_node.name = "WorldEnvironment"
	env_node.environment = _make_environment()
	_add(scene_root, env_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.light_angular_distance = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0
	_add(scene_root, sun)

	var atmo: Node = load("res://src/world/atmosphere/atmosphere_controller.gd").new()
	atmo.name = "Atmosphere"
	var presets: Array[AtmospherePreset] = [load("res://data/atmosphere/day.tres"), load("res://data/atmosphere/night.tres")]
	atmo.set("presets", presets)
	atmo.set("world_environment", env_node)
	atmo.set("sun", sun)
	_add(scene_root, atmo)

	# ground + collision
	_place("ph_env_ground", scene_root, Vector2.ZERO, 0.0, null, "Ground").position = Vector3.ZERO
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	_add(scene_root, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = WorldBoundaryShape3D.new()
	_add(body, shape)

	var graves := _add(scene_root, _named(Node3D.new(), "Graves"))
	var i := 0
	for g: Dictionary in layout.graves:
		i += 1
		var plot := _named(Node3D.new(), "Grave_%02d" % i) as Node3D
		var pos := _v2(g.pos)
		plot.position = Vector3(pos.x, ground_height(pos), pos.y)
		plot.rotation_degrees.y = g.rot_y
		_add(graves, plot)
		_place("ph_prop_grave_mound_" + String(g.mound), plot, Vector2.ZERO, 0.0, null, "Mound").position = Vector3.ZERO
		var stone := _place("ph_prop_gravestone_" + String(g.stone), plot, Vector2.ZERO, 0.0, null, "Stone")
		stone.position = Vector3(0, 0, -1.12)

	var fence := _add(scene_root, _named(Node3D.new(), "Fence"))
	for seg: Array in layout.fence.segments:
		var a := _v2(seg[0])
		var b := _v2(seg[1])
		var d := b - a
		var count := ceili(d.length() / 2.0)
		for k: int in count:
			var start := a + d.normalized() * 2.0 * k
			var piece := _place("ph_prop_fence_iron", fence, start, rad_to_deg(atan2(-d.y, d.x)))
			var remaining := d.length() - 2.0 * k
			if remaining < 2.0:
				piece.scale.x = remaining / 2.0
	for gp: Array in layout.fence.gate_posts:
		_place("ph_prop_gate_post", fence, _v2(gp), 0.0)

	_place("ph_bld_gravekeeper_hut", scene_root, _v2(layout.hut.pos), layout.hut.rot_y, null, "Hut")
	_place("ph_env_tree_old_oak", scene_root, _v2(layout.tree.pos), layout.tree.rot_y, null, "Tree")
	var bg := _add(scene_root, _named(Node3D.new(), "BackgroundTrees"))
	for t: Dictionary in layout.background_trees:
		var tree := _place("ph_env_tree_old_oak", bg, _v2(t.pos), t.rot_y)
		tree.scale = Vector3.ONE * float(t.scale)
	_place("ph_prop_lantern_post", scene_root, _v2(layout.lantern_post.pos), layout.lantern_post.rot_y, null, "LanternPost")
	var props := _add(scene_root, _named(Node3D.new(), "Props"))
	for pr: Dictionary in layout.props:
		_place(pr.asset, props, _v2(pr.pos), pr.rot_y)

	_add(scene_root, _build_grass())

	var player := (load(OUT_PLAYER) as PackedScene).instantiate() as Node3D
	player.position = Vector3(layout.player.pos[0], 0.1, layout.player.pos[1])
	(player.get_node("Model") as Node3D).rotation_degrees.y = layout.player.rot_y
	_add(scene_root, player)

	var rig: Node3D = load("res://src/world/camera/camera_rig.gd").new()
	rig.name = "CameraRig"
	_add(scene_root, rig)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	_add(rig, cam)
	rig.set("target", player)

	_build_hud()
	return scene_root


func _named(n: Node, node_name: String) -> Node:
	n.name = node_name
	return n


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


func _build_grass() -> MultiMeshInstance3D:
	var cfg: Dictionary = layout.grass
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	var clump := FastNoiseLite.new()
	clump.seed = int(cfg.seed)
	clump.frequency = 0.18
	var half := float(layout.ground_size) * 0.5 - 0.5
	var path_pts: Array[Vector2] = []
	for p: Array in layout.path.points:
		path_pts.append(_v2(p))
	var blockers: Array[Dictionary] = []  # circles: {c, r}
	blockers.append({"c": _v2(layout.tree.pos), "r": 0.9})
	for t: Dictionary in layout.background_trees:
		blockers.append({"c": _v2(t.pos), "r": 1.0 * float(t.scale)})
	blockers.append({"c": _v2(layout.hut.pos), "r": float(cfg.keep_out_building)})
	blockers.append({"c": _v2(layout.lantern_post.pos), "r": 0.35})
	for gp: Array in layout.fence.gate_posts:
		blockers.append({"c": _v2(gp), "r": 0.35})
	var xforms: Array[Transform3D] = []
	var tries := 0
	while xforms.size() < int(cfg.count) and tries < int(cfg.count) * 20:
		tries += 1
		var p := Vector2(rng.randf_range(-half, half), rng.randf_range(-half, half))
		if clump.get_noise_2d(p.x * 10.0, p.y * 10.0) * 0.5 + 0.5 < rng.randf() * 0.85:
			continue
		if _dist_to_path(p, path_pts) < float(cfg.keep_out_radius_path):
			continue
		if _blocked(p, blockers) or _on_grave(p):
			continue
		var s := rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		xforms.append(Transform3D(basis, Vector3(p.x, ground_height(p) - 0.01, p.y)))
	var tuft := (load(MODELS + "environment/ph_env_grass_tuft.glb") as PackedScene).instantiate()
	var mesh := ((tuft.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh).duplicate() as Mesh
	tuft.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k: int in xforms.size():
		mm.set_instance_transform(k, xforms[k])
	ResourceSaver.save(mm, OUT_GRASS)
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "Grass"
	mmi.multimesh = load(OUT_GRASS)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("  grass tufts: ", xforms.size())
	return mmi


func _dist_to_path(p: Vector2, pts: Array[Vector2]) -> float:
	var best := INF
	for k: int in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])))
	return best


func _blocked(p: Vector2, blockers: Array[Dictionary]) -> bool:
	for b: Dictionary in blockers:
		if p.distance_to(b.c) < b.r:
			return true
	return false


func _on_grave(p: Vector2) -> bool:
	for g: Dictionary in layout.graves:
		var local := (p - _v2(g.pos)).rotated(deg_to_rad(float(g.rot_y)))
		if absf(local.x) < 0.62 and local.y > -1.35 and local.y < 1.0:
			return true
	return false


func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	_add(scene_root, hud)
	var settings := LabelSettings.new()
	settings.font_size = 20
	settings.outline_size = 6
	settings.outline_color = Color(0, 0, 0, 0.8)
	var title := Label.new()
	title.name = "Title"
	title.text = "ART-DIRECTION-PROTOTYP  ·  Phase 1  ·  Platzhalter-Assets"
	title.label_settings = settings
	title.position = Vector2(24, 18)
	_add(hud, title)
	var hint := Label.new()
	hint.name = "Hint"
	hint.label_settings = settings
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 24
	hint.offset_top = -48
	_add(hud, hint)

extends RefCounted
## Shared build state of graveyard_builder.gd (build-time tool, no class_name – the -s script
## preloads it): the parsed layout, the scene root under construction, the ground height
## lookup (props sit on the painted, slightly uneven ground) and the node helpers – add /
## group / place a model on the ground with its OmniLights at light_* markers (layout "lights").
## Must not reference autoload-using classes by class_name (see graveyard_builder.gd).

const MODELS := "res://assets/models/"
const GROUND_ASSET := "ph_env_ground_graveyard"
## Model of an entity type (for its colliders); resource nodes use params.model.
const ENTITY_ASSETS := {"morgue_table": "ph_prop_morgue_table", "workbench": "ph_prop_workbench",
		"dropoff": "ph_prop_dropoff_bier"}
const FLICKER := preload("res://src/world/atmosphere/flicker_light.gd")
const WORLD_LAYER := 1

## The running builder (its root holds the autoloads).
var tree: SceneTree
var layout: Dictionary
var scene_root: Node3D
var heights: Dictionary = {}   # Vector2i(grid) -> height
var grid_min := Vector2i.ZERO
var grid_max := Vector2i.ZERO
var cell: float = 0.3
## "Colliders" group of the world and the number of StaticBody3D placed in it by collider().
var colliders: Node3D
var collider_count: int = 0


func _init(builder: SceneTree) -> void:
	tree = builder


# --- helpers -----------------------------------------------------------------

func add(parent: Node, child: Node, owner_node: Node = null) -> Node:
	parent.add_child(child)
	child.owner = owner_node if owner_node != null else scene_root
	return child


func group(parent: Node, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	add(parent, n)
	return n


static func v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func model_path(asset: String) -> String:
	for cat: String in ["props", "environment", "buildings", "characters"]:
		var p := MODELS + cat + "/" + asset + ".glb"
		if ResourceLoader.exists(p):
			return p
	push_error("asset not found: " + asset)
	return ""


static func rel_xform(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func ground_xform(pos: Vector2, rot_y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), Vector3(pos.x, ground_height(pos), pos.y))


## Instance a model at a layout position (x, z) on the ground, attach its lights.
## light_overrides: {marker: {key: value}} replaces values of the layout "lights" table.
func place(asset: String, parent: Node, pos: Vector2, rot_y: float, node_name: String = "",
		light_overrides: Dictionary = {}) -> Node3D:
	var inst := (load(model_path(asset)) as PackedScene).instantiate() as Node3D
	inst.name = node_name if node_name != "" else asset.trim_prefix("ph_")
	inst.transform = ground_xform(pos, rot_y)
	add(parent, inst)
	attach_lights(asset, inst, light_overrides)
	return inst


func attach_lights(asset: String, inst: Node3D, overrides: Dictionary = {}) -> void:
	var cfgs: Dictionary = layout.get("lights", {})
	for marker: Node in inst.find_children("light_*", "", true, false):
		var key := asset + "/" + marker.name
		if not cfgs.has(key):
			continue
		var cfg: Dictionary = (cfgs[key] as Dictionary).duplicate()
		cfg.merge(overrides.get(String(marker.name), {}), true)
		var light := OmniLight3D.new()
		light.name = "Light_" + String(marker.name).trim_prefix("light_")
		light.transform = rel_xform(marker as Node3D, inst)
		light.light_color = Color(cfg.color)
		light.light_energy = cfg.energy
		light.omni_range = cfg.range
		light.omni_attenuation = 1.4
		light.shadow_enabled = cfg.shadow
		light.shadow_blur = 1.5
		light.set_meta("base_energy", cfg.energy)
		if cfg.flicker:
			light.set_script(FLICKER)
		add(inst, light)
		light.add_to_group("warm_lights", true)


# --- ground height lookup (props sit on the painted, slightly uneven ground) ---

func build_height_lookup() -> void:
	var scene := (load(model_path(GROUND_ASSET)) as PackedScene).instantiate()
	var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var verts: PackedVector3Array = mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	grid_min = Vector2i(1 << 30, 1 << 30)
	grid_max = -grid_min
	for v: Vector3 in verts:
		var key := Vector2i(roundi(v.x / cell), roundi(v.z / cell))
		heights[key] = v.y
		grid_min = Vector2i(mini(grid_min.x, key.x), mini(grid_min.y, key.y))
		grid_max = Vector2i(maxi(grid_max.x, key.x), maxi(grid_max.y, key.y))
	scene.free()
	print("  ground grid ", grid_min, " .. ", grid_max)


func ground_height(p: Vector2) -> float:
	var g := p / cell
	var x0 := floori(g.x)
	var z0 := floori(g.y)
	var fx := g.x - x0
	var fz := g.y - z0
	var h00: float = heights.get(Vector2i(x0, z0), 0.0)
	var h10: float = heights.get(Vector2i(x0 + 1, z0), 0.0)
	var h01: float = heights.get(Vector2i(x0, z0 + 1), 0.0)
	var h11: float = heights.get(Vector2i(x0 + 1, z0 + 1), 0.0)
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)

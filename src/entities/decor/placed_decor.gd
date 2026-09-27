class_name PlacedDecor
extends Node3D
## One placed decor piece (docs/PHASE3_DESIGN.md §3.4): model, optional StaticBody3D (layer 1),
## a warm light at every marker light_* of the model (group warm_lights, never a shadow).
## Created only by DecorationManager (setup()). Model: DecorData.model, else the P5 asset at
## MODEL_PATHS (§8) when it exists, else a small placeholder box – tests never need assets.

const WARM_LIGHTS := &"warm_lights"
const WORLD_LAYER := 1
## §8 asset names (P5, assets/models/decor/). Used while DecorData.model is still empty.
const MODEL_DIR := "res://assets/models/decor"
const MODEL_PATHS: Dictionary[StringName, String] = {
	&"decor_bench_wood": "ph_deco_bench_wood",
	&"decor_bench_stone": "ph_deco_bench_stone",
	&"decor_flowerbed": "ph_deco_flowerbed",
	&"decor_grave_vase": "ph_deco_grave_vase",
	&"decor_lantern": "ph_deco_lantern_small",
	&"decor_path_gravel": "ph_deco_path_gravel",
}
## Second gravel variant (§8 "_02"), chosen per cell for variety.
const GRAVEL_VARIANT := "ph_deco_path_gravel_02"
## Small grave lantern light (presentation, like the layout's light configs).
const LIGHT_COLOR := Color("#ffae55")
const LIGHT_ENERGY := 1.2
const LIGHT_RANGE := 3.5
## Placeholder box height when the decor has no collider size (m).
const PLACEHOLDER_HEIGHT := 0.1
const PLACEHOLDER_COLOR := Color(0.55, 0.47, 0.36)

var uid: String = ""
var decor_id: StringName = &""
## Instanced model (or placeholder MeshInstance3D).
var model: Node3D
var body: StaticBody3D
var lights: Array[OmniLight3D] = []


## Builds the piece for `placement` on `mask` (position = footprint centre, y = 0).
func setup(decor: DecorData, placement: DecorPlacement, mask: BuildMask) -> void:
	uid = placement.uid
	decor_id = placement.decor_id
	name = uid if uid != "" else name
	var size := BuildGrid.rotated_size(decor.footprint, placement.rot)
	var cell := mask.cell if mask != null else 0.5
	var origin := mask.origin if mask != null else Vector2.ZERO
	var centre := origin + (Vector2(placement.cell) + Vector2(size) * 0.5) * cell
	position = Vector3(centre.x, 0.0, centre.y)
	rotation = Vector3(0.0, placement.rot * PI * 0.5, 0.0)
	model = _make_model(decor, placement, cell)
	model.name = "Model"
	add_child(model)
	if decor.collider_size != Vector3.ZERO:
		_add_body(decor.collider_size)
	_add_lights()


## Scene used for `decor` (null = placeholder box).
static func model_scene(decor: DecorData, variant: int = 0) -> PackedScene:
	if decor.model != null:
		return decor.model
	var file: String = MODEL_PATHS.get(decor.id, "")
	if file == "":
		return null
	if decor.id == &"decor_path_gravel" and variant % 2 == 1:
		var alt := MODEL_DIR.path_join(GRAVEL_VARIANT + ".glb")
		if ResourceLoader.exists(alt):
			return load(alt) as PackedScene
	var path := MODEL_DIR.path_join(file + ".glb")
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


func _make_model(decor: DecorData, placement: DecorPlacement, cell: float) -> Node3D:
	var scene := model_scene(decor, absi(placement.cell.x + placement.cell.y))
	if scene != null:
		var inst := scene.instantiate() as Node3D
		if inst != null:
			return inst
	return _placeholder(decor, cell)


## Box over the rot-0 footprint (the node's rotation turns it).
func _placeholder(decor: DecorData, cell: float) -> Node3D:
	var height := decor.collider_size.y if decor.collider_size.y > 0.0 else PLACEHOLDER_HEIGHT
	var box := BoxMesh.new()
	box.size = Vector3(decor.footprint.x * cell * 0.9, height, decor.footprint.y * cell * 0.9)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PLACEHOLDER_COLOR
	box.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.position.y = height * 0.5
	var root := Node3D.new()
	root.add_child(mi)
	return root


func _add_body(size: Vector3) -> void:
	body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	add_child(body)


func _add_lights() -> void:
	for marker: Node in model.find_children("light_*", "", true, false):
		if not marker is Node3D:
			continue
		var light := OmniLight3D.new()
		light.name = "Light_" + String(marker.name).trim_prefix("light_")
		light.light_color = LIGHT_COLOR
		light.light_energy = LIGHT_ENERGY
		light.omni_range = LIGHT_RANGE
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		light.set_meta("base_energy", LIGHT_ENERGY)
		(marker as Node3D).add_child(light)
		light.add_to_group(WARM_LIGHTS, true)
		lights.append(light)

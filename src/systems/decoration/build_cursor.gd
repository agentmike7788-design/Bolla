class_name BuildCursor
extends Node3D
## Build preview (docs/PHASE3_DESIGN.md §3.4, §7): the decor model with the preview material
## (valid: candle amber with a warm rim, 60 % opacity; invalid: dried red #8C2F2B) plus a grid
## overlay of the buildable cells within DecorConfig.grid_overlay_radius around the cursor –
## one ImmediateMesh surface = one draw call, rebuilt only when the cursor cell changes.
## Driven by BuildMode (show_at / hide_cursor); no shadows, no collision.

const VALID_COLOR := Color("#F2A93B")
const INVALID_COLOR := Color("#8C2F2B")
const PREVIEW_ALPHA := 0.6
const GRID_ALPHA := 0.35
## Lift above the ground against z-fighting (m).
const GRID_LIFT := 0.03
const PREVIEW_LIFT := 0.01

var config: DecorConfig
var preview: Node3D
var grid: MeshInstance3D
var valid: bool = true
var shown_decor: StringName = &""

var _valid_mat: StandardMaterial3D
var _invalid_mat: StandardMaterial3D
var _grid_mat: StandardMaterial3D
var _grid_center: Vector2i = Vector2i(-1048576, -1048576)
var _grid_mask: BuildMask


func _init() -> void:
	name = "BuildCursor"
	_valid_mat = preview_material(true)
	_invalid_mat = preview_material(false)
	_grid_mat = StandardMaterial3D.new()
	_grid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grid_mat.vertex_color_use_as_albedo = true
	_grid_mat.albedo_color = Color(1, 1, 1, 1)
	grid = MeshInstance3D.new()
	grid.name = "Grid"
	grid.mesh = ImmediateMesh.new()
	grid.material_override = _grid_mat
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grid.top_level = true
	add_child(grid)
	visible = false


## Preview material: warm amber (valid) or dried red (invalid), 60 % opacity, soft rim.
static func preview_material(is_valid: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var c := VALID_COLOR if is_valid else INVALID_COLOR
	m.albedo_color = Color(c, PREVIEW_ALPHA)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.35 if is_valid else 0.2
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Shows `decor` at the footprint anchored at `cell` (rot quarter turns) on `mask`.
func show_at(decor: DecorData, cell: Vector2i, rot: int, is_valid: bool, mask: BuildMask) -> void:
	if decor == null or mask == null:
		hide_cursor()
		return
	visible = true
	if shown_decor != decor.id or preview == null:
		_rebuild_preview(decor, mask.cell)
	valid = is_valid
	_apply_material(preview, _valid_mat if is_valid else _invalid_mat)
	var size := BuildGrid.rotated_size(decor.footprint, rot)
	var centre := mask.origin + (Vector2(cell) + Vector2(size) * 0.5) * mask.cell
	preview.position = Vector3(centre.x, PREVIEW_LIFT, centre.y)
	preview.rotation = Vector3(0.0, posmod(rot, 4) * PI * 0.5, 0.0)
	update_grid(mask.world_to_cell(centre), mask)


func hide_cursor() -> void:
	visible = false


## Grid lines of the buildable cells within grid_overlay_radius of `center` (one surface).
func update_grid(center: Vector2i, mask: BuildMask) -> void:
	if center == _grid_center and mask == _grid_mask:
		return
	_grid_center = center
	_grid_mask = mask
	var mesh := grid.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var lines := grid_lines(center, mask, config.grid_overlay_radius if config != null else 3.0)
	if lines.is_empty():
		return
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color(VALID_COLOR, GRID_ALPHA))
	for p: Vector2 in lines:
		mesh.surface_add_vertex(Vector3(p.x, GRID_LIFT, p.y))
	mesh.surface_end()


## Pure: line segment end points (pairs, world XZ) of every buildable cell whose centre lies
## within `radius` of the centre of `center`.
static func grid_lines(center: Vector2i, mask: BuildMask, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if mask == null or mask.cell <= 0.0:
		return out
	var reach := ceili(radius / mask.cell)
	var c0 := mask.cell_to_world(center)
	for dz: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var c := center + Vector2i(dx, dz)
			if mask.section_at(c) == 0 or mask.cell_to_world(c).distance_to(c0) > radius:
				continue
			var a := mask.origin + Vector2(c) * mask.cell
			var b := a + Vector2(mask.cell, mask.cell)
			out.append_array([a, Vector2(b.x, a.y), Vector2(b.x, a.y), b, b, Vector2(a.x, b.y), Vector2(a.x, b.y), a])
	return out


func _rebuild_preview(decor: DecorData, cell: float) -> void:
	if preview != null:
		remove_child(preview)
		preview.queue_free()
	var scene := PlacedDecor.model_scene(decor)
	preview = scene.instantiate() as Node3D if scene != null else null
	if preview == null:
		var box := BoxMesh.new()
		var h := decor.collider_size.y if decor.collider_size.y > 0.0 else PlacedDecor.PLACEHOLDER_HEIGHT
		box.size = Vector3(decor.footprint.x * cell * 0.9, h, decor.footprint.y * cell * 0.9)
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position.y = h * 0.5
		preview = Node3D.new()
		preview.add_child(mi)
	preview.name = "Preview"
	# Lights of the real model stay off in the preview.
	for light: Node in preview.find_children("*", "Light3D", true, false):
		(light as Light3D).visible = false
	add_child(preview)
	shown_decor = decor.id


static func _apply_material(root: Node, mat: Material) -> void:
	if root == null:
		return
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g := node as GeometryInstance3D
		g.material_override = mat
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if root is GeometryInstance3D:
		(root as GeometryInstance3D).material_override = mat

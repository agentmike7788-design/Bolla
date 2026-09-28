class_name StonePreview
extends SubViewportContainer
## Live 3D preview of a designed gravestone for the stone panel (docs/PHASE5_DESIGN.md §7, §9):
## its own SubViewport + World3D with the real shape model, ornament and inscription (StoneVisual,
## the same builder the graves use), a patch of earth, a fixed warm side light. Rendered once per
## change only (UPDATE_ONCE) – nothing runs while the design stays the same.

const BACKGROUND := Color("2B2420")
const EARTH := Color("3A3026")
const KEY_COLOR := Color(1.0, 0.9, 0.74)
const FILL_COLOR := Color(0.66, 0.72, 0.84)
const FOV := 28.0
## Share of the frame height the stone fills.
const FILL := 0.8
## Camera pitch (degrees down) and yaw (degrees to the right of the face normal).
const PITCH := 9.0
const YAW := 14.0

@export var view_size: Vector2i = Vector2i(520, 440)

var viewport: SubViewport
var camera: Camera3D
## The stone currently shown (StoneVisual.build), null for an empty design.
var stone: Node3D
## How often a new design was rendered (tests: only on change).
var render_count: int = 0

var _key: String = ""
var _pivot: Node3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_ensure_viewport()


## Shows `design` (with its text). Same design again → nothing is rebuilt or rendered.
func show_design(design: StoneDesign) -> void:
	_ensure_viewport()
	var key := JSON.stringify(design.to_dict()) if design != null else ""
	if key == _key and (stone != null or key == ""):
		return
	_key = key
	if stone != null:
		_pivot.remove_child(stone)
		stone.queue_free()
		stone = null
	if design != null and not design.is_empty():
		stone = StoneVisual.build(design)
		if stone != null:
			_pivot.add_child(stone)
			_frame(_bounds(stone))
	render_count += 1
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## The text lines of the inscription labels shown (tests).
func label_texts() -> PackedStringArray:
	var out := PackedStringArray()
	if stone == null:
		return out
	for node: Node in stone.find_children("*", "Label3D", true, false):
		out.append((node as Label3D).text)
	return out


func _ensure_viewport() -> void:
	if viewport != null:
		return
	custom_minimum_size = Vector2(view_size)
	viewport = SubViewport.new()
	viewport.name = "Viewport"
	viewport.size = view_size
	viewport.own_world_3d = true
	viewport.world_3d = World3D.new()
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = BACKGROUND
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.52, 0.5)
	env.environment.ambient_light_energy = 0.5
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	viewport.add_child(env)
	var key := DirectionalLight3D.new()
	key.name = "Key"
	key.rotation_degrees = Vector3(-24.0, -48.0, 0.0)
	key.light_color = KEY_COLOR
	key.light_energy = 1.35
	key.shadow_enabled = true
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.rotation_degrees = Vector3(-10.0, 60.0, 0.0)
	fill.light_color = FILL_COLOR
	fill.light_energy = 0.35
	viewport.add_child(fill)
	var ground := MeshInstance3D.new()
	ground.name = "Earth"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.25
	disc.height = 0.06
	disc.radial_segments = 24
	ground.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = EARTH
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(0.0, -0.03, 0.0)
	viewport.add_child(ground)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	viewport.add_child(_pivot)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV
	camera.current = true
	viewport.add_child(camera)
	_frame(AABB(Vector3(-0.3, 0.0, -0.1), Vector3(0.6, 1.0, 0.2)))


## Camera in front of the face (+Z), slightly from the right and above, the whole stone in frame.
func _frame(box: AABB) -> void:
	var center := box.get_center()
	var height := maxf(box.size.y, box.size.x * float(view_size.y) / maxf(view_size.x, 1.0))
	var distance := (height * 0.5 / FILL) / tan(deg_to_rad(FOV * 0.5)) + box.size.z * 0.5
	var dir := Vector3(sin(deg_to_rad(YAW)), sin(deg_to_rad(PITCH)), cos(deg_to_rad(YAW))).normalized()
	camera.look_at_from_position(center + dir * distance, center, Vector3.UP)
	camera.near = 0.05
	camera.far = distance * 4.0 + 4.0


static func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var b := _relative(mesh, node) * mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else AABB(Vector3(-0.3, 0.0, -0.1), Vector3(0.6, 1.0, 0.2))


static func _relative(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t

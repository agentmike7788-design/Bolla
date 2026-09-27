class_name GrassClearMask
extends Node
## Systems/GrassClearMask (docs/PHASE3_DESIGN.md §3.4, §3.6): writes the shader globals
## grass_clear_mask (R8 texture, TEXELS_PER_CELL² texels per BuildMask cell = 0.25 m, 1 = hide
## grass under standing obstacles / placed decor) and grass_clear_rect (origin.xz, size.xz;
## (0,0,0,0) = off). Repaints on decor_changed, obstacle_cleared, section_unlocked, world_ready,
## game_loaded and cleanliness_changed; the texture is only uploaded when the painted image
## changed. Leaving the tree switches the mask off again (art prototype unchanged).
## QA readability (W3): a weeds / leaves spot of level ≥ 1 (CleanlinessManager, group
## cleanliness) also clears the grass under it (DIRT_CLEAR_SIZE) – the rosettes, leaves and the
## trampled soil of ph_env_weeds_2/3 / ph_env_leaves_2/3 lie flat and were hidden by the tufts.

const GLOBAL_MASK := &"grass_clear_mask"
const GLOBAL_RECT := &"grass_clear_rect"
## 0.5 m cells → 0.25 m texels.
const TEXELS_PER_CELL := 2
const DEFAULT_TEXTURE := "res://assets/shaders/grass_clear_default.png"
## Side (m) of the grass-free square under a dirt spot, by level (0 keeps the grass).
const DIRT_CLEAR_SIZE: PackedFloat32Array = [0.0, 0.45, 0.7, 1.0]

## Optional; falls back to the DecorationManager's mask (group decorations).
@export var mask: BuildMask

var image: Image
var texture: ImageTexture
var rect: Vector4 = Vector4.ZERO


func _ready() -> void:
	EventBus.decor_changed.connect(_on_changed.unbind(3))
	EventBus.obstacle_cleared.connect(_on_changed.unbind(2))
	EventBus.section_unlocked.connect(_on_changed.unbind(1))
	EventBus.world_ready.connect(_on_changed.unbind(1))
	EventBus.game_loaded.connect(_on_changed.unbind(1))
	EventBus.cleanliness_changed.connect(_on_changed.unbind(2))


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set(GLOBAL_RECT, Vector4.ZERO)
	if ResourceLoader.exists(DEFAULT_TEXTURE):
		RenderingServer.global_shader_parameter_set(GLOBAL_MASK, load(DEFAULT_TEXTURE))


## On decor_changed, obstacle_cleared, section_unlocked, world_ready.
func repaint() -> void:
	var decorations: DecorationManager = null
	if is_inside_tree():
		decorations = get_tree().get_first_node_in_group(&"decorations") as DecorationManager
	var m := mask
	if m == null and decorations != null:
		m = decorations.mask
	if m == null or m.size.x <= 0 or m.size.y <= 0:
		rect = Vector4.ZERO
		RenderingServer.global_shader_parameter_set(GLOBAL_RECT, rect)
		return
	var cells: Array[Vector2i] = []
	var rects: Array[Rect2] = []
	if decorations != null:
		cells = decorations.occupied_cells()
		rects = decorations.blockers()
	rects.append_array(dirt_rects())
	var painted := paint(m, cells, rects)
	if image == null or texture == null or image.get_size() != painted.get_size():
		image = painted
		texture = ImageTexture.create_from_image(image)
	elif image.get_data() != painted.get_data():
		image = painted
		texture.update(image)
	rect = Vector4(m.origin.x, m.origin.y, m.size.x * m.cell, m.size.y * m.cell)
	RenderingServer.global_shader_parameter_set(GLOBAL_MASK, texture)
	RenderingServer.global_shader_parameter_set(GLOBAL_RECT, rect)


## World XZ squares of the grass cleared under dirt spots (level ≥ 1, DIRT_CLEAR_SIZE).
func dirt_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	var clean := get_tree().get_first_node_in_group(&"cleanliness")
	if clean == null or not clean.has_method(&"level"):
		return out
	for node: Node in get_tree().get_nodes_in_group(&"dirt_spot"):
		var spot := node as Node3D
		if spot == null or not spot.is_inside_tree():
			continue
		var lvl := clampi(int(clean.call(&"level", str(spot.get(&"spot_id")))), 0, DIRT_CLEAR_SIZE.size() - 1)
		var side := DIRT_CLEAR_SIZE[lvl]
		if side > 0.0:
			var p := Vector2(spot.global_position.x, spot.global_position.z)
			out.append(Rect2(p - Vector2(side, side) * 0.5, Vector2(side, side)))
	return out


## Pure: R8 image over `m` (TEXELS_PER_CELL per cell); 1 in every texel of `cells` and in every
## texel whose centre lies inside one of the world XZ `rects`.
static func paint(m: BuildMask, cells: Array[Vector2i], rects: Array[Rect2]) -> Image:
	var w := maxi(m.size.x * TEXELS_PER_CELL, 1)
	var h := maxi(m.size.y * TEXELS_PER_CELL, 1)
	var data := PackedByteArray()
	data.resize(w * h)
	data.fill(0)
	for c: Vector2i in cells:
		for dy: int in TEXELS_PER_CELL:
			for dx: int in TEXELS_PER_CELL:
				var x := c.x * TEXELS_PER_CELL + dx
				var y := c.y * TEXELS_PER_CELL + dy
				if x >= 0 and y >= 0 and x < w and y < h:
					data[y * w + x] = 255
	var texel := m.cell / TEXELS_PER_CELL
	for r: Rect2 in rects:
		var x0 := maxi(0, floori((r.position.x - m.origin.x) / texel))
		var y0 := maxi(0, floori((r.position.y - m.origin.y) / texel))
		var x1 := mini(w - 1, ceili((r.end.x - m.origin.x) / texel))
		var y1 := mini(h - 1, ceili((r.end.y - m.origin.y) / texel))
		for y: int in range(y0, y1 + 1):
			for x: int in range(x0, x1 + 1):
				var centre := m.origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * texel
				if r.has_point(centre):
					data[y * w + x] = 255
	return Image.create_from_data(w, h, false, Image.FORMAT_R8, data)


func _on_changed() -> void:
	repaint()

class_name GravePlotVisuals
extends RefCounted
## State visuals and colliders of a GravePlot: rebuilds its "Visual" child (first child) for
## the plot's state / marker_id and enables the builder-made "Collision" shapes whose "role"
## meta matches (pit, mound, marker:<id>, old). Interaction stays in grave_plot.gd.
## Phase 6 (P3): a lifted old grave (OLD → EMPTY) just swaps the models on the same node (no
## rebuild of the plot); DUG with pit_variant &"foot" shows ph_prop_grave_pit_foot.

## Phase 8 (docs/PHASE8_DESIGN.md §2.3, §8.4; P2): the care layer "CareVisual" – grave flowers (fresh /
## wilted), the wax wreath, the visitor's bouquet, the grave candle (glass + flame, emissive; the light comes
## from GraveCare's pool), the mortsafe and the disturbed earth at the foot end. P5's ph_prop_* models when
## present, else small painted placeholder shapes. The coins on the stone are TipStone's.
const CARE_NAME := "CareVisual"
const FLOWERS_PATH := "res://assets/models/props/ph_prop_grave_flowers.glb"
const FLOWERS_WILTED_PATH := "res://assets/models/props/ph_prop_grave_flowers_wilted.glb"
const WREATH_PATH := "res://assets/models/props/ph_prop_wax_wreath.glb"
const BOUQUET_PATH := "res://assets/models/props/ph_prop_bouquet_heath.glb"
const CANDLE_PATH := "res://assets/models/props/ph_prop_grave_candle.glb"
const MORTSAFE_PATH := "res://assets/models/props/ph_prop_mortsafe.glb"
const DISTURBED_PATH := "res://assets/models/props/ph_prop_grave_disturbed.glb"
const FLOWERS_OFFSET := Vector3(0.0, 0.22, 0.15)
const BOUQUET_OFFSET := Vector3(0.18, 0.2, 0.75)
const MORTSAFE_OFFSET := Vector3(0.0, 0.0, 0.1)
const DISTURBED_OFFSET := Vector3(0.0, 0.0, 1.15)
const COLOR_FLOWERS := Color("#7A5A8C")
const COLOR_WILTED := Color("#6E6252")
const COLOR_WREATH := Color("#D8CFC0")
const COLOR_BOUQUET := Color("#8C6E9A")
const COLOR_GLASS := Color("#C9C2A8")
const COLOR_FLAME := Color("#F2A93B")
const COLOR_IRON := Color("#2A2624")
const COLOR_EARTH := Color("#4A3B2E")

var _plot: GravePlot
var _visual: Node3D
var _visual_key: String = ""
var _care: Node3D
var _care_key: String = ""


func _init(plot: GravePlot) -> void:
	_plot = plot


## Rebuilds the visual for the plot's current state (no-op while state, marker and design are
## unchanged).
func apply() -> void:
	var plot := _plot
	var state := plot.state
	var marker_id := plot.marker_id
	var design := StoneDesign.from_dict(plot.design)
	# Phase 8: the lines chiselled on later stand under the carved text (visual only, design stays as stored).
	for line: String in plot.extra_lines:
		design.text.append(line)
	var key := "%d:%s:%s:%s" % [state, marker_id, JSON.stringify(plot.design), ",".join(plot.extra_lines)]
	if key == _visual_key and _visual != null:
		return
	_visual_key = key
	if _visual != null:
		plot.remove_child(_visual)
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	plot.add_child(_visual)
	plot.move_child(_visual, 0)
	var roles: PackedStringArray = []
	match state:
		GraveRecord.State.EMPTY:
			_add_model(plot.empty_model, Vector3.ZERO)
		GraveRecord.State.DUG:
			_add_model(plot.active_pit_model(), Vector3.ZERO)
			roles.append(GravePlot.ROLE_PIT)
		GraveRecord.State.FILLED, GraveRecord.State.MARKED:
			_add_model(plot.mound_model, plot.mound_offset)
			roles.append(GravePlot.ROLE_MOUND)
			if state == GraveRecord.State.MARKED and not design.is_empty():
				# Phase 5 §2.5, §8: designed stone – shape model, ornament, inscription Label3D.
				var stone := StoneVisual.build(design)
				stone.position = plot.marker_offset
				_visual.add_child(stone)
				roles.append(GravePlot.ROLE_MARKER + String(design.shape))
			elif state == GraveRecord.State.MARKED and plot.marker_models.has(marker_id):
				_add_model(plot.marker_models[marker_id], plot.marker_offset)
				roles.append(GravePlot.ROLE_MARKER + String(marker_id))
		GraveRecord.State.OLD:
			_add_model(_load_scene(GravePlot.OLD_MOUND_PATH % plot.old_mound), Vector3.ZERO)
			if not design.is_empty():
				# Phase 7 (§2.5 o_mangold_stone, W-Welt): a new stone set on a rest-period grave
				# (Graveyard.replace_old_marker) stands in place of the weathered one.
				var stone := StoneVisual.build(design)
				stone.position = plot.old_stone_offset
				_visual.add_child(stone)
			else:
				_add_model(_load_scene(GravePlot.OLD_STONE_PATH % plot.old_stone), plot.old_stone_offset)
			roles.append(GravePlot.ROLE_OLD)
	_update_collision(roles)


## Phase 8: rebuilds the care layer from GraveCare (no-op while nothing changed; nothing without GraveCare).
func apply_care() -> void:
	var plot := _plot
	if not plot.is_inside_tree():
		return
	var care := plot.get_tree().get_first_node_in_group(&"grave_care") as GraveCare
	var parts := PackedStringArray()
	if care != null and plot.state in [GraveRecord.State.FILLED, GraveRecord.State.MARKED, GraveRecord.State.OLD]:
		var f := care.flowers_state(plot.grave_id)
		if f != &"":
			parts.append("flowers:" + String(f))
		if care.bouquet_fresh(plot.grave_id):
			parts.append("bouquet")
		if care.candle_lit(plot.grave_id):
			parts.append("candle")
		if care.has_mortsafe(plot.grave_id):
			parts.append("mortsafe")
		if care.is_disturbed(plot.grave_id):
			parts.append("disturbed")
	var key := ",".join(parts)
	if key == _care_key and (_care != null or parts.is_empty()):
		return
	_care_key = key
	if _care != null:
		plot.remove_child(_care)
		_care.queue_free()
		_care = null
	if parts.is_empty():
		return
	_care = Node3D.new()
	_care.name = CARE_NAME
	plot.add_child(_care)
	for part: String in parts:
		match part:
			"flowers:fresh":
				_care_model(FLOWERS_PATH, FLOWERS_OFFSET, "Flowers", _box(Vector3(0.6, 0.12, 1.1), COLOR_FLOWERS))
			"flowers:wilted":
				_care_model(FLOWERS_WILTED_PATH, FLOWERS_OFFSET, "FlowersWilted", _box(Vector3(0.6, 0.08, 1.1), COLOR_WILTED))
			"flowers:wreath":
				_care_model(WREATH_PATH, FLOWERS_OFFSET, "Wreath", _ring(0.22, COLOR_WREATH))
			"bouquet":
				_care_model(BOUQUET_PATH, BOUQUET_OFFSET, "Bouquet", _box(Vector3(0.12, 0.08, 0.35), COLOR_BOUQUET))
			"candle":
				var candle := _care_model(CANDLE_PATH, GraveCare.CANDLE_OFFSET, "Candle", _candle())
				candle.set_meta(&"emissive", true)
			"mortsafe":
				_care_model(MORTSAFE_PATH, MORTSAFE_OFFSET, "Mortsafe", _cage())
			"disturbed":
				_care_model(DISTURBED_PATH, DISTURBED_OFFSET, "Disturbed", _box(Vector3(0.9, 0.25, 0.6), COLOR_EARTH))


## The care layer node (null = nothing on the grave) – tests, screenshots.
func care_node() -> Node3D:
	return _care


func _care_model(path: String, offset: Vector3, node_name: String, fallback: Node3D) -> Node3D:
	var inst: Node3D = null
	if ResourceLoader.exists(path):
		inst = (load(path) as PackedScene).instantiate() as Node3D
		fallback.free()
	else:
		inst = fallback
	inst.name = node_name
	inst.position = offset
	_care.add_child(inst)
	return inst


static func _material(color: Color, emissive: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	if emissive:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.6
	return m


static func _box(size: Vector3, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	mi.mesh = mesh
	mi.position = Vector3(0, size.y * 0.5, 0)
	var root := Node3D.new()
	root.add_child(mi)
	return root


static func _ring(radius: float, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.7
	mesh.outer_radius = radius
	mesh.rings = 12
	mesh.ring_segments = 6
	mesh.material = _material(color)
	mi.mesh = mesh
	var root := Node3D.new()
	root.add_child(mi)
	return root


static func _candle() -> Node3D:
	var root := Node3D.new()
	var glass := MeshInstance3D.new()
	var g := CylinderMesh.new()
	g.top_radius = 0.045
	g.bottom_radius = 0.05
	g.height = 0.12
	g.radial_segments = 8
	g.material = _material(COLOR_GLASS)
	glass.mesh = g
	glass.position = Vector3(0, 0.06, 0)
	root.add_child(glass)
	var flame := MeshInstance3D.new()
	var f := SphereMesh.new()
	f.radius = 0.018
	f.height = 0.05
	f.radial_segments = 6
	f.rings = 3
	f.material = _material(COLOR_FLAME, true)
	flame.mesh = f
	flame.position = Vector3(0, 0.14, 0)
	flame.name = "Flame"
	root.add_child(flame)
	return root


static func _cage() -> Node3D:
	var root := Node3D.new()
	for x: float in [-0.45, 0.45]:
		for z: float in [-0.95, 0.95]:
			var post := _box(Vector3(0.04, 1.0, 0.04), COLOR_IRON)
			post.position = Vector3(x, 0, z)
			root.add_child(post)
	for z: float in [-0.95, -0.47, 0.0, 0.47, 0.95]:
		var bar := _box(Vector3(0.94, 0.03, 0.03), COLOR_IRON)
		bar.position = Vector3(0, 0.97, z)
		root.add_child(bar)
	return root


## Shapes of the plot's "Collision" body that are active (see GravePlot.active_collision_roles).
static func active_roles(plot: GravePlot) -> PackedStringArray:
	var out: PackedStringArray = []
	var body := plot.get_node_or_null(^"Collision")
	if body == null:
		return out
	for shape: Node in body.get_children():
		if shape is CollisionShape3D and not (shape as CollisionShape3D).disabled:
			var role := String(shape.get_meta(GravePlot.ROLE_META, ""))
			if not role in out:
				out.append(role)
	return out


func _add_model(scene: PackedScene, offset: Vector3) -> void:
	if scene == null:
		return
	var inst := scene.instantiate() as Node3D
	inst.position = offset
	_visual.add_child(inst)


func _load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		push_warning("[GravePlot] %s: model '%s' not found" % [_plot.grave_id, path])
		return null
	return load(path) as PackedScene


## Enables the builder-made collision shapes whose "role" meta is in `roles`.
func _update_collision(roles: PackedStringArray) -> void:
	var body := _plot.get_node_or_null(^"Collision")
	if body == null:
		return
	for shape: Node in body.get_children():
		if shape is CollisionShape3D:
			var role := String(shape.get_meta(GravePlot.ROLE_META, ""))
			shape.set_deferred(&"disabled", not role in roles)

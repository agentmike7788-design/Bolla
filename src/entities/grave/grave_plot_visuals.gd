class_name GravePlotVisuals
extends RefCounted
## State visuals and colliders of a GravePlot: rebuilds its "Visual" child (first child) for
## the plot's state / marker_id and enables the builder-made "Collision" shapes whose "role"
## meta matches (pit, mound, marker:<id>, old). Interaction stays in grave_plot.gd.
## Phase 6 (P3): a lifted old grave (OLD → EMPTY) just swaps the models on the same node (no
## rebuild of the plot); DUG with pit_variant &"foot" shows ph_prop_grave_pit_foot.

var _plot: GravePlot
var _visual: Node3D
var _visual_key: String = ""


func _init(plot: GravePlot) -> void:
	_plot = plot


## Rebuilds the visual for the plot's current state (no-op while state, marker and design are
## unchanged).
func apply() -> void:
	var plot := _plot
	var state := plot.state
	var marker_id := plot.marker_id
	var design := StoneDesign.from_dict(plot.design)
	var key := "%d:%s:%s" % [state, marker_id, JSON.stringify(plot.design)]
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
			_add_model(_load_scene(GravePlot.OLD_STONE_PATH % plot.old_stone), plot.old_stone_offset)
			roles.append(GravePlot.ROLE_OLD)
	_update_collision(roles)


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

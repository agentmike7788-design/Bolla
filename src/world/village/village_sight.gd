extends RefCounted
## Sight rays for the p7_vis_* images (docs/PHASE7_DESIGN.md §4.5 / §4.6, §11) – the same check as
## test_village_world / test_graveyard_world: collision copies (PROBE_LAYER) of every visible mesh
## under a root, foliage only where the occlusion cutout (GDScript mirror of painted_foliage.gdshader)
## does not open it; a ray from the gameplay eye to a point is free when it meets nothing else.
## draw_ray() lays the ray as a thin unshaded bar (green free, red hidden) that is read from above.

const PROBE_LAYER := 1 << 19
const FOLIAGE_SHADER := "res://assets/shaders/painted_foliage.gdshader"
const FREE := Color(0.25, 0.85, 0.3)
const HIDDEN := Color(0.95, 0.15, 0.1)

var root: Node3D
var _cut: Dictionary = {}
var _space: PhysicsDirectSpaceState3D
var _mat := {}


func _init(world_root: Node3D) -> void:
	root = world_root
	_space = root.get_world_3d().direct_space_state
	_cut = {"radius": float((ProjectSettings.get_setting("shader_globals/occlusion_radius") as Dictionary).value),
			"softness": 0.45, "rise": 0.35}


## Probe copies of the visible meshes under `under`, skipping paths (relative to `under`) that begin
## with one of `skip` (ground, grass, figures, other regions).
func probe(under: Node3D, skip: PackedStringArray) -> int:
	var n := 0
	for node: Node in under.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var path := String(under.get_path_to(mi))
		var skipped := false
		for s: String in skip:
			if path.begins_with(s):
				skipped = true
		if skipped:
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(mi.mesh.get_faces())
		var body := StaticBody3D.new()
		body.name = "SightProbe"
		body.collision_layer = PROBE_LAYER
		body.collision_mask = 0
		for s: int in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(s) as ShaderMaterial
			if mat != null and mat.shader != null and mat.shader.resource_path == FOLIAGE_SHADER:
				body.set_meta(&"foliage", true)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
		n += 1
	return n


## Removes the probe copies again.
func unprobe(under: Node3D) -> void:
	for node: Node in under.find_children("SightProbe", "StaticBody3D", true, false):
		node.queue_free()


## "" when eye → p is free (but `exclude` subtrees and opened foliage); else the blocker's name.
func blocked(eye: Vector3, p: Vector3, chest: Vector3, exclude: Array = []) -> String:
	var dir := (p - eye).normalized()
	var to := p - dir * 0.05
	var from := eye
	for guard: int in 48:
		var hit := _space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, PROBE_LAYER))
		if hit.is_empty():
			return ""
		var body := hit.collider as Node
		var skip := false
		for e: Node in exclude:
			if e != null and e.is_ancestor_of(body):
				skip = true
		if not skip and body.has_meta(&"foliage") and _cut_at(hit.position, eye, chest) > 0.5:
			skip = true
		if not skip:
			return String(body.get_parent().name)
		from = (hit.position as Vector3) + dir * 0.01
	return ""


## A bar from `a` to `b` (0.12 m thick, unshaded, drawn over everything) under `parent`.
func draw_ray(parent: Node3D, a: Vector3, b: Vector3, free: bool) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var bar := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, length)
	bar.mesh = mesh
	bar.material_override = _material(FREE if free else HIDDEN)
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(bar)
	bar.global_transform = Transform3D(Basis.looking_at(b - a, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.BACK),
			(a + b) * 0.5)


## A small marker sphere (the stand / the target point).
func draw_dot(parent: Node3D, at: Vector3, free: bool, radius: float = 0.3) -> void:
	var dot := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	dot.mesh = mesh
	dot.material_override = _material(FREE if free else HIDDEN)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(dot)
	dot.global_position = at


func _material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mat.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.no_depth_test = true
		m.render_priority = 10
		_mat[key] = m
	return _mat[key]


## GDScript mirror of occlusion_cut() in painted_foliage.gdshader (0 = kept … 1 = fully cut).
func _cut_at(p: Vector3, eye: Vector3, target: Vector3) -> float:
	var axis := target - eye
	var t := (p - eye).dot(axis) / axis.length_squared()
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var radius := float(_cut.radius) * t
	var d := p.distance_to(eye + axis * t)
	var radial := 1.0 - smoothstep(radius * (1.0 - float(_cut.softness)), radius, d)
	return radial * smoothstep(target.y, target.y + float(_cut.rise), p.y)

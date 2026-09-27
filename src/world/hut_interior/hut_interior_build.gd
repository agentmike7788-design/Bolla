extends RefCounted
## Builds the hut interior tree (docs §11) from data/world/hut_interior_layout.json – build-time
## tool, static, preloaded by hut_interior_builder.gd and graveyard_builder.gd (no class_name;
## scripts that use autoloads are loaded by path, see graveyard_builder.gd).
##   HutInterior (hut_interior.gd)
##   ├─ Room (ph_int_room + Light_window_1/_2, Light_ceiling)   ├─ Sun (hidden until inside)
##   ├─ Furniture/ (decor pieces, candle lights)   ├─ Entities/ bed, chest, desk, stove, interior_door
##   ├─ Colliders/ (floor, walls, floor pieces – layer 1)   ├─ Spawn (spawn_inside)   └─ Lighting
## Interactive pieces are entities with their model as child "Model" and a "UsePos" marker.

const LAYOUT_PATH := "res://data/world/hut_interior_layout.json"
const CONFIG_PATH := "res://data/config/interior_config.tres"
const MODEL_DIR := "res://assets/models/interior/"
const ROOT_SCRIPT := "res://src/world/hut_interior/hut_interior.gd"
const LIGHTING_SCRIPT := "res://src/world/hut_interior/interior_lighting.gd"
const FLICKER := "res://src/world/atmosphere/flicker_light.gd"
const ENTITY_SCENES := {
	"bed": "res://src/entities/bed/bed.tscn",
	"chest": "res://src/entities/chest/chest.tscn",
	"desk": "res://src/entities/desk/desk.tscn",
	"stove": "res://src/entities/stove/stove.tscn",
	"interior_door": "res://src/entities/interior_door/interior_door.tscn",
}
const WORLD_LAYER := 1
## Room collision: inner half extents (x, z), wall thickness and height, floor slab depth.
const ROOM_HALF := Vector2(2.3, 1.8)
const WALL_T := 0.3
const WALL_H := 3.0
const FLOOR_T := 0.4
## Interior light roles (InteriorLighting.META_ROLE) per marker name.
const ROLE_OF_MARKER := {"light_window_1": &"window", "light_window_2": &"window",
		"light_ceiling": &"lantern", "light_candle": &"candle"}
const META_ROLE := &"interior_role"
## Layout mounts that block walking (flat rugs, pieces on others and hanging herbs do not).
const COLLIDING_MOUNTS: Array[String] = ["floor", "wall"]


static func load_layout() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))


static func build(layout: Dictionary) -> Node3D:
	var cfg: Resource = load(CONFIG_PATH)
	var root := Node3D.new()
	root.name = "HutInterior"
	root.set_script(load(ROOT_SCRIPT))
	root.set("config", cfg)
	root.set("environment", _environment(cfg))
	var cam: Dictionary = layout.get("camera_bounds", {})
	if cam.has("min"):
		root.set("bounds_min", _v2(cam.min))
		root.set("bounds_max", _v2(cam.max))
	var room := _instance(String(layout.room), "Room")
	_add(root, room, root)
	for marker: Node in room.find_children("light_*", "", true, false):
		_light(root, room, marker as Node3D, cfg)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.visible = false
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.light_angular_distance = 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 18.0
	sun.rotation_degrees = _v3(layout.get("sun_rotation_deg", [-60.0, 25.0, 0.0]))
	_add(root, sun, root)
	var spawn := Marker3D.new()
	spawn.name = "Spawn"
	spawn.transform = _xform(_v2(layout.spawn_inside), 180.0, 0.0)
	_add(root, spawn, root)
	var furniture := _group(root, "Furniture")
	var entities := _group(root, "Entities")
	var colliders := _group(root, "Colliders")
	_room_collision(root, colliders)
	var door := (load(ENTITY_SCENES.interior_door) as PackedScene).instantiate() as Node3D
	door.name = "interior_door"
	door.transform = _xform(_v2(layout.door_inside), 0.0, 0.0)
	_add(entities, door, root)
	var counts := {}
	for item: Dictionary in layout.items:
		var asset := String(item.asset)
		var xform := _xform(_v2(item.pos), float(item.get("rot_y", 0.0)), float(item.get("y", 0.0)))
		var model := _instance(asset, "Model")
		var holder: Node3D = model
		if item.has("interact"):
			var entity := (load(ENTITY_SCENES[String(item.interact)]) as PackedScene).instantiate() as Node3D
			entity.name = String(item.interact)
			entity.transform = xform
			_add(entities, entity, root)
			_add(entity, model, root)
			var use := Marker3D.new()
			use.name = "UsePos"
			var p := _v2(item.use_pos)
			use.transform = Transform3D(Basis.IDENTITY, xform.affine_inverse() * Vector3(p.x, 0.0, p.y))
			_add(entity, use, root)
			holder = entity
		else:
			var n := int(counts.get(asset, 0)) + 1
			counts[asset] = n
			model.name = "%s_%d" % [asset.trim_prefix("ph_int_"), n]
			model.transform = xform
			_add(furniture, model, root)
		for marker: Node in model.find_children("light_*", "", true, false):
			_light(root, model, marker as Node3D, cfg)
		if String(item.get("mount", "floor")) in COLLIDING_MOUNTS:
			_piece_collision(root, colliders, model, xform, String(holder.name))
	var lighting := Node.new()
	lighting.name = "Lighting"
	lighting.set_script(load(LIGHTING_SCRIPT))
	_add(root, lighting, root)
	return root


# --- lights ---------------------------------------------------------------------------------

## OmniLight3D "Light_<marker>" at a light_* marker of `model`: interior role lights (windows,
## lantern, candles – InteriorLighting sets their energy) or the stove fire (warm_lights).
static func _light(root: Node3D, model: Node3D, marker: Node3D, cfg: Resource) -> void:
	var marker_name := String(marker.name)
	var light := OmniLight3D.new()
	light.name = "Light_" + marker_name.trim_prefix("light_")
	light.transform = _rel(marker, model)
	light.omni_attenuation = 1.4
	light.shadow_blur = 1.5
	if marker_name == "light_fire":
		light.light_color = cfg.get("stove_color")
		light.omni_range = cfg.get("stove_range")
		light.shadow_enabled = true
		var night: float = cfg.get("stove_night_energy")
		light.light_energy = night
		light.set_meta(&"base_energy", night)
		light.set_meta(&"min_scale", float(cfg.get("stove_day_energy")) / maxf(night, 0.001))
		light.set_script(load(FLICKER))
		light.set("amount", cfg.get("stove_flicker"))
		_add(model, light, root)
		light.add_to_group(&"warm_lights", true)
		return
	var role: StringName = ROLE_OF_MARKER.get(marker_name, &"")
	if role == &"":
		light.free()
		return
	light.set_meta(META_ROLE, role)
	match role:
		&"window":
			light.light_color = cfg.get("window_day_color")
			light.omni_range = cfg.get("window_range")
			light.light_energy = cfg.get("window_day_energy")
		&"lantern":
			light.light_color = cfg.get("lantern_color")
			light.omni_range = cfg.get("lantern_range")
			light.light_energy = cfg.get("lantern_night_energy")
			light.shadow_enabled = true
			light.set_script(load(FLICKER))
			light.set("amount", 0.06)
		&"candle":
			light.light_color = cfg.get("candle_color")
			light.omni_range = cfg.get("candle_range")
			light.light_energy = cfg.get("candle_night_energy")
			light.set_script(load(FLICKER))
	light.set_meta(&"base_energy", light.light_energy)
	_add(model, light, root)


# --- collision ------------------------------------------------------------------------------

## Floor slab and the four walls (the front wall is closed: the door is used with [E]).
static func _room_collision(root: Node3D, colliders: Node3D) -> void:
	var body := _body(root, colliders, "Room", Transform3D.IDENTITY)
	var hx := ROOM_HALF.x + WALL_T
	var hz := ROOM_HALF.y + WALL_T
	var boxes := {
		"Floor": [Vector3(0.0, -FLOOR_T * 0.5, 0.0), Vector3(2.0 * hx, FLOOR_T, 2.0 * hz)],
		"Back": [Vector3(0.0, WALL_H * 0.5, -ROOM_HALF.y - WALL_T * 0.5), Vector3(2.0 * hx, WALL_H, WALL_T)],
		"Front": [Vector3(0.0, WALL_H * 0.5, ROOM_HALF.y + WALL_T * 0.5), Vector3(2.0 * hx, WALL_H, WALL_T)],
		"Left": [Vector3(-ROOM_HALF.x - WALL_T * 0.5, WALL_H * 0.5, 0.0), Vector3(WALL_T, WALL_H, 2.0 * hz)],
		"Right": [Vector3(ROOM_HALF.x + WALL_T * 0.5, WALL_H * 0.5, 0.0), Vector3(WALL_T, WALL_H, 2.0 * hz)],
	}
	for box_name: String in boxes:
		_box(root, body, box_name, boxes[box_name][0], boxes[box_name][1])


## One box around a floor piece (its mesh bounds, in the piece's own frame).
static func _piece_collision(root: Node3D, colliders: Node3D, model: Node3D, xform: Transform3D, body_name: String) -> void:
	var aabb := _mesh_aabb(model)
	if aabb.size == Vector3.ZERO:
		return
	var body := _body(root, colliders, body_name, xform)
	_box(root, body, "Shape", aabb.get_center(), aabb.size)


static func _body(root: Node3D, parent: Node3D, body_name: String, xform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	body.transform = xform
	_add(parent, body, root)
	return body


static func _box(root: Node3D, body: Node3D, shape_name: String, centre: Vector3, size: Vector3) -> void:
	var shape := CollisionShape3D.new()
	shape.name = shape_name
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	_add(body, shape, root)


# --- environment & helpers ------------------------------------------------------------------

## Camera environment of the room: no fog, own ambient (InteriorLighting animates it).
static func _environment(cfg: Resource) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = cfg.get("background_color")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = cfg.get("ambient_day_color")
	env.ambient_light_energy = cfg.get("ambient_day_energy")
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = cfg.get("exposure")
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.4
	return env


static func _instance(asset: String, node_name: String) -> Node3D:
	var inst := (load(MODEL_DIR + asset + ".glb") as PackedScene).instantiate() as Node3D
	inst.name = node_name
	return inst


static func _group(root: Node3D, node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	_add(root, n, root)
	return n


static func _add(parent: Node, child: Node, root: Node) -> void:
	parent.add_child(child)
	child.owner = root


static func _xform(pos: Vector2, rot_y: float, y: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), Vector3(pos.x, y, pos.y))


static func _rel(node: Node3D, ancestor: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != ancestor and n != null:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _mesh_aabb(model: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var box := _rel(mi, model) * mi.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _v3(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

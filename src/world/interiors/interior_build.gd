extends RefCounted
## Builds a building's interior room (docs/PHASE6_DESIGN.md §4.7, §4.8) from
## data/world/interiors/<room>_layout.json – build-time tool, static, preloaded by
## interior_builder.gd and graveyard_build_phase6.gd (no class_name; scripts that use autoloads
## are loaded by path, see graveyard_builder.gd). Derived from hut_interior_build.gd (same layout
## format: room, door_inside, spawn_inside, walkway, camera_bounds, sun_rotation_deg,
## items[] {asset, pos, rot_y, y, mount, interact, use_pos, min_level, max_level}); the hut keeps
## its own builder unchanged.
##   <Room>Interior (interior_room.gd: room_id, building_id, hide_when_inactive, config, env)
##   ├─ Room (room model + marker lights)   ├─ Sun (soft; hidden until inside)   ├─ Spawn
##   ├─ Furniture/ (decor pieces)   ├─ Entities/ (table, niches, shelf, altar, store, exit, …)
##   ├─ Colliders/ (floor, walls, pieces – layer 1)   ├─ Particles/   ├─ Lighting (InteriorLighting)
##   └─ RiteLights (chapel: altar candles, eternal light, choir spot – chapel_rite_lights.gd)
## Level furniture carries the metas min_level / max_level (InteriorRoom.apply_level shows / hides
## it with its collision). Light roles by marker: light_window_* → window, light_ceiling /
## light_lantern → lantern, light_candle* → candle; an item's "light_roles" overrides them (rite,
## eternal, stain for the chapel). Each room has ≤ 2 shadow lights (§4.8).

const LAYOUT_PATH := "res://data/world/interiors/%s_layout.json"
const OUT_SCENE := "res://src/world/interiors/%s_interior.tscn"
const MODEL_DIRS: Array[String] = ["res://assets/models/interior/", "res://assets/models/props/", "res://assets/models/items/",
		"res://assets/models/characters/", "res://assets/models/decor/"]
const ROOT_SCRIPT := "res://src/world/interiors/interior_room.gd"
const LIGHTING_SCRIPT := "res://src/world/hut_interior/interior_lighting.gd"
const RITE_SCRIPT := "res://src/world/interiors/chapel_rite_lights.gd"
const TABLE_SCRIPT := "res://src/entities/morgue_table/morgue_table.gd"
const MOURNER_SCRIPT := "res://src/entities/mourner_set/mourner_set.gd"
const INTERACTABLE_SCRIPT := "res://src/components/interactable.gd"
const FLICKER := "res://src/world/atmosphere/flicker_light.gd"
const CONFIG_PATH := "res://data/config/interiors/%s.tres"
const SMOKE_TEXTURE := "res://assets/vfx/ph_vfx_smoke_wisp.png"
const SMOKE_MATERIAL := "res://assets/materials/mat_vfx_smoke.tres"
const ENTITY_SCENES := {
	"crypt_niche": "res://src/entities/crypt_niche/crypt_niche.tscn",
	"ossuary_shelf": "res://src/entities/ossuary_shelf/ossuary_shelf.tscn",
	"sealed_passage": "res://src/entities/sealed_passage/sealed_passage.tscn",
	"catafalque": "res://src/entities/catafalque/catafalque.tscn",
	"chapel_altar": "res://src/entities/chapel_altar/chapel_altar.tscn",
	"shed_store": "res://src/entities/shed_store/shed_store.tscn",
	"room_exit": "res://src/world/interiors/room_exit.tscn",
	# Phase 7 (docs/PHASE7_DESIGN.md §2.7, §4.3, §4.6 P1)
	"poor_box": "res://src/entities/poor_box/poor_box.tscn",
	"register_copy": "res://src/entities/register_copy/register_copy.tscn",
	"pult_store": "res://src/entities/pult_store/pult_store.tscn",
	"collection_shelf": "res://src/entities/collection_shelf/collection_shelf.tscn",
	"build_site": "res://src/entities/build_site/build_site.tscn",
}
const WORKBENCH_SCRIPT := "res://src/entities/workbench/workbench.gd"
const LECTURE_SCRIPT := "res://src/entities/lecture_set/lecture_set.gd"
const BUILD_SITE_SLAB := "ph_prop_build_site_slab"
const WORLD_LAYER := 1
const INTERACT_LAYER := 8
const WALL_H := 3.0
const FLOOR_T := 0.4
const META_ROLE := &"interior_role"
const META_MIN := &"min_level"
const META_MAX := &"max_level"
const COLLIDING_MOUNTS: Array[String] = ["floor", "wall"]
## Priority of the room's interactables (like the stations).
const PRIORITY := 5


static func load_layout(room_id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH % room_id))


## Packs and saves the room scene (frees `node`); returns its path.
static func save_scene(node: Node, room_id: String) -> String:
	var path := OUT_SCENE % room_id
	var ps := PackedScene.new()
	var err := ps.pack(node)
	assert(err == OK, "pack failed: %s" % path)
	err = ResourceSaver.save(ps, path)
	assert(err == OK, "save failed: %s" % path)
	print("  saved ", path)
	node.free()
	return path


static func build(layout: Dictionary) -> Node3D:
	var room_id := String(layout.room_id)
	var cfg: Resource = load(CONFIG_PATH % room_id)
	var root := Node3D.new()
	root.name = "%sInterior" % room_id.capitalize()
	root.set_script(load(ROOT_SCRIPT))
	root.set("room_id", StringName(room_id))
	root.set("building_id", StringName(layout.get("building", room_id)))
	root.set("hide_when_inactive", true)
	root.set("config", cfg)
	root.set("environment", _environment(cfg))
	# Phase 7: the village rooms belong to the village region (InteriorRoom.region_id, docs / tests).
	root.set("region_id", StringName(layout.get("region", "graveyard")))
	var cam: Dictionary = layout.get("camera_bounds", {})
	if cam.has("min"):
		root.set("bounds_min", _v2(cam.min))
		root.set("bounds_max", _v2(cam.max))
	var room := _instance(String(layout.room), "Room")
	_add(root, room, root)
	_marker_lights(root, room, String(layout.room), layout.get("light_roles", {}), cfg)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.visible = false
	sun.shadow_enabled = bool(layout.get("sun_shadow", true))
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
	_room_collision(root, colliders, layout)
	var exit := (load(ENTITY_SCENES.room_exit) as PackedScene).instantiate() as Node3D
	exit.name = "room_exit"
	exit.set("building_id", StringName(layout.get("building", room_id)))
	exit.transform = _xform(_v2(layout.door_inside), 0.0, 0.0)
	# Phase 7: a village room leads back to its HouseDoor (RoomExit.door_id; the region stays).
	exit.set("door_id", StringName(layout.get("door_id", "")))
	_add(entities, exit, root)
	var counts := {}
	for item: Dictionary in layout.items:
		_build_item(root, furniture, entities, colliders, item, counts, cfg)
	# Phase 7 (§4.4): the room's NPC spots Waypoints/<id> [x, z, facing°] (RegionRoot finds them by
	# the room's region_id).
	if layout.has("waypoints"):
		var wps := _group(root, "Waypoints")
		for id: String in layout.waypoints:
			var w: Array = layout.waypoints[id]
			var marker := Marker3D.new()
			marker.name = id
			marker.position = Vector3(float(w[0]), 0.0, float(w[1]))
			if w.size() > 2:
				marker.rotation_degrees.y = float(w[2])
				marker.set_meta(&"facing", true)
			_add(wps, marker, root)
	if layout.has("particles"):
		var parts := _group(root, "Particles")
		for p: Dictionary in layout.particles:
			_add(parts, _particles(p), root)
	if layout.has("fill_lights"):
		_fill_lights(root, layout.fill_lights, cfg)
	var lighting := Node.new()
	lighting.name = "Lighting"
	lighting.set_script(load(LIGHTING_SCRIPT))
	_add(root, lighting, root)
	if bool(layout.get("rite_lights", false)):
		var rite := Node.new()
		rite.name = "RiteLights"
		rite.set_script(load(RITE_SCRIPT))
		_add(root, rite, root)
	return root


# --- items ----------------------------------------------------------------------------------

static func _build_item(root: Node3D, furniture: Node3D, entities: Node3D, colliders: Node3D, item: Dictionary,
		counts: Dictionary, cfg: Resource) -> void:
	var kind := String(item.get("interact", ""))
	var params: Dictionary = item.get("params", {})
	var xform := _xform(_v2(item.get("pos", [0.0, 0.0])), float(item.get("rot_y", 0.0)), float(item.get("y", 0.0)))
	if kind == "mourner_set":
		var set_node := _entity(kind, params)
		set_node.name = String(item.get("id", "MournerSet"))
		set_node.transform = xform
		_add(entities, set_node, root)
		_mourners(root, set_node, params)
		_level_metas(set_node, item)
		return
	if kind == "lecture_set":
		_lecture_set(root, entities, item, xform)
		return
	if kind == "pult_station":
		_pult_station(root, entities, colliders, item, xform, cfg)
		return
	var asset := String(item.asset)
	var model := _instance(asset, "Model")
	if item.has("scale"):
		var s: Variant = item.scale
		model.scale = _v3(s) if s is Array else Vector3.ONE * float(s)
	var holder: Node3D = model
	# The model's bounds in the frame of `xform` (collision).
	var bounds := Transform3D(Basis.from_scale(model.scale), Vector3.ZERO) * _mesh_aabb(model)
	if item.has("on"):
		# A piece standing on an entity (the smoke bowl on the crypt table): child of it at the
		# height of its slot_corpse marker, local [x, z].
		var host := entities.get_node(String(item.on)) as Node3D
		var slot := host.find_child("slot_corpse", true, false) as Node3D
		var top := _rel(slot, host).origin.y if slot != null else 0.0
		var local := _v2(item.local)
		model.name = String(item.get("id", asset.trim_prefix("ph_prop_").capitalize().replace(" ", "")))
		model.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(float(item.get("rot_y", 0.0)))), Vector3(local.x, top, local.y))
		_add(host, model, root)
		_level_metas(model, item)
		if item.has("follows_table"):
			model.set_meta(&"follows_table", String(item.follows_table))
		_marker_lights(root, model, asset, item.get("light_roles", {}), cfg)
		return
	if kind != "":
		var entity := _entity(kind, params)
		entity.name = String(item.get("id", kind))
		entity.transform = xform
		_add(entities, entity, root)
		_add(entity, model, root)
		if item.has("use_pos"):
			var use := Marker3D.new()
			use.name = "UsePos"
			var p := _v2(item.use_pos)
			use.transform = Transform3D(Basis.IDENTITY, xform.affine_inverse() * Vector3(p.x, 0.0, p.y))
			_add(entity, use, root)
		_entity_extras(root, entity, model, kind, params, item)
		holder = entity
	else:
		var n := int(counts.get(asset, 0)) + 1
		counts[asset] = n
		model.name = String(item.get("id", "%s_%d" % [asset.trim_prefix("ph_int_").trim_prefix("ph_prop_"), n]))
		model.transform = xform * model.transform
		_add(furniture, model, root)
	_level_metas(holder, item)
	if item.has("follows_table"):
		holder.set_meta(&"follows_table", String(item.follows_table))
	_marker_lights(root, model, asset, item.get("light_roles", {}), cfg)
	if item.has("collide_rects"):
		# Phase 7: only parts of the piece collide (the inn's bar: counter and back shelf, Rosine
		# stands between them) – local rects [x0, z0, x1, z1] at the piece's height.
		var rbody := _body(root, colliders, String(holder.name), xform)
		var k := 0
		for r: Array in item.collide_rects:
			k += 1
			var rr := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
			_box(root, rbody, "Shape%d" % k, Vector3(rr.get_center().x, bounds.size.y * 0.5, rr.get_center().y),
					Vector3(rr.size.x, bounds.size.y, rr.size.y))
		_level_metas(rbody, item)
	elif String(item.get("mount", "floor")) in COLLIDING_MOUNTS and bool(item.get("collide", true)):
		var body := _piece_collision(root, colliders, bounds, xform, String(holder.name), float(item.get("collision_inset", 0.0)))
		if body != null:
			_level_metas(body, item)
			if kind == "crypt_niche":
				body.set_meta(META_MIN, int(params.min_level))  # a sealed niche is only its wall panel


## The entity node of an interactive piece (its model is added as child "Model").
static func _entity(kind: String, params: Dictionary) -> Node3D:
	var node: Node3D
	match kind:
		"morgue_table":
			node = Node3D.new()
			node.set_script(load(TABLE_SCRIPT))
			node.set("room", StringName(params.get("room", "")))
			node.set("requires_level", int(params.get("requires_level", 0)))
			node.set("retire_at_level", int(params.get("retire_at_level", 0)))
			_add_interactable(node, _v3(params.get("reach", [2.3, 1.0, 1.2])))
		"mourner_set":
			node = Node3D.new()
			node.set_script(load(MOURNER_SCRIPT))
		_:
			node = (load(ENTITY_SCENES[kind]) as PackedScene).instantiate() as Node3D
	match kind:
		"crypt_niche":
			node.set("slot_id", String(params.slot_id))
			node.set("min_level", int(params.min_level))
	return node


## Kind-specific children: the sealed niche panel, the passage models, the shelf's name board,
## the mourners on their seats.
static func _entity_extras(root: Node3D, entity: Node3D, model: Node3D, kind: String, params: Dictionary, item: Dictionary) -> void:
	match kind:
		"crypt_niche":
			var lvl := int(params.min_level)
			model.set_meta(META_MIN, lvl)
			if params.has("sealed_asset") and lvl > 1:
				var sealed := _instance(String(params.sealed_asset), "Sealed")
				sealed.position = _v3(params.get("sealed_offset", [0.0, 0.0, 0.0]))
				sealed.set_meta(META_MAX, lvl - 1)
				_add(entity, sealed, root)
		"sealed_passage":
			model.name = "Sealed"
			var grille := _instance(String(params.grille_asset), "Grille")
			grille.visible = false
			_add(entity, grille, root)
		"ossuary_shelf":
			if params.has("name_board"):
				var nb: Dictionary = params.name_board
				var board := _instance(String(nb.asset), "NameBoard")
				board.position = _v3(nb.local)
				board.scale = Vector3(1.0 / model.scale.x, 1.0 / model.scale.y, 1.0 / model.scale.z)
				board.set_meta(META_MIN, int(nb.get("min_level", 3)))
				_add(model, board, root)
	if item.has("reach"):
		var shape := entity.get_node_or_null(^"Interactable/Shape") as CollisionShape3D
		if shape != null:
			root.set_editable_instance(entity, true)
			var box := BoxShape3D.new()
			box.size = _v3(item.reach)
			shape.shape = box
			shape.position = _v3(item.get("reach_offset", [0.0, 0.5, 0.0]))


## Phase 7 (§2.6.4, §4.3): the LectureSet of the surgery – Student1…3 (params.figures cycled over
## params.seats [x, z, rot_y, y], room-local) and the sealed Jar on the lectern (params.jar at
## params.jar_pos [x, y, z]); all hidden until LectureSet.show_lecture. No collision, no Interactable.
static func _lecture_set(root: Node3D, entities: Node3D, item: Dictionary, xform: Transform3D) -> void:
	var params: Dictionary = item.get("params", {})
	var set_node := Node3D.new()
	set_node.name = String(item.get("id", "LectureSet"))
	set_node.set_script(load(LECTURE_SCRIPT))
	set_node.transform = xform
	_add(entities, set_node, root)
	var figures: Array = params.get("figures", [])
	var k := 0
	for seat: Array in params.get("seats", []):
		k += 1
		var fig := _instance(String(figures[(k - 1) % figures.size()]), "Student%d" % k)
		var world := Transform3D(Basis(Vector3.UP, deg_to_rad(float(seat[2]))), Vector3(float(seat[0]), float(seat[3]), float(seat[1])))
		fig.transform = xform.affine_inverse() * world
		fig.visible = false
		_add(set_node, fig, root)
	if params.has("jar"):
		var jar := _instance(String(params.jar), "Jar")
		jar.transform = xform.affine_inverse() * Transform3D(Basis.IDENTITY, _v3(params.jar_pos))
		jar.visible = false
		_add(set_node, jar, root)


## Phase 7 (§2.7, §4.6 P1): the preparation desk in the crypt. A holder "PultPlace" (level metas of
## the item: min_level 1) carries
##   site_pult (BuildSite, station params.station, requires_flag params.requires_flag – hidden before
##   village_open; the stone slab of the Phase-6 sites as its model, collision only while active),
##   station_pult (Workbench station + requires_built: model, collision, Interactable; hidden until
##   built) with PultStore (the slate drawer at the model's marker `cold`) and the CollectionShelf
##   (params.shelf {asset, pos, rot_y}: model, collision, Interactable at its marker `use`).
static func _pult_station(root: Node3D, entities: Node3D, colliders: Node3D, item: Dictionary, xform: Transform3D,
		cfg: Resource) -> void:
	var params: Dictionary = item.get("params", {})
	var holder := Node3D.new()
	holder.name = "PultPlace"
	_add(entities, holder, root)
	_level_metas(holder, item)
	var asset := String(item.asset)
	var probe := _instance(asset, "Probe")
	var bounds := _mesh_aabb(probe)
	var cold := probe.find_child("cold", true, false) as Node3D
	var cold_xf := _rel(cold, probe) if cold != null else Transform3D(Basis.IDENTITY, Vector3(0, 0.7, 0.35))
	probe.free()
	# The build site (before the pult stands).
	var site := (load(ENTITY_SCENES.build_site) as PackedScene).instantiate() as Node3D
	site.name = "site_pult"
	site.set("station_id", StringName(params.station))
	site.set("requires_flag", StringName(params.get("requires_flag", "")))
	site.transform = xform
	_add(holder, site, root)
	var slab := _instance(BUILD_SITE_SLAB, "Model")
	var slab_box := _mesh_aabb(slab)
	if slab_box.size.x > 0.0:
		slab.scale = Vector3(bounds.size.x / slab_box.size.x, 1.0, bounds.size.z / slab_box.size.z)
	slab.position = Vector3(bounds.get_center().x, 0.0, bounds.get_center().z)
	_add(site, slab, root)
	_fit_reach(root, site, bounds, 0.45)
	# The station (Workbench with requires_built).
	var station := Node3D.new()
	station.name = String(item.get("id", "station_pult"))
	station.set_script(load(WORKBENCH_SCRIPT))
	station.set("station", StringName(params.station))
	station.set("requires_built", true)
	station.transform = xform
	_add(holder, station, root)
	var model := _instance(asset, "Model")
	_add(station, model, root)
	_marker_lights(root, model, asset, item.get("light_roles", {}), cfg)
	_add_interactable(station, Vector3(bounds.size.x + 0.5, 1.0, bounds.size.z + 0.9))
	(station.get_node("Interactable/Shape") as Node3D).position = Vector3(bounds.get_center().x, 0.5, bounds.get_center().z + 0.25)
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	_add(station, body, root)
	_box(root, body, "Shape", bounds.get_center(), bounds.size)
	# The cold drawer (PultStore) in the desk front.
	var store := (load(ENTITY_SCENES.pult_store) as PackedScene).instantiate() as Node3D
	store.name = "PultStore"
	store.transform = Transform3D(Basis.IDENTITY, Vector3(cold_xf.origin.x, 0.0, cold_xf.origin.z + 0.3))
	_add(station, store, root)
	# The collection shelf beside it (its own place in the room, child of the station so it stands
	# only once the pult is built).
	var sh: Dictionary = params.get("shelf", {})
	if not sh.is_empty():
		var shelf_xf := _xform(_v2(sh.pos), float(sh.get("rot_y", 0.0)), 0.0)
		var shelf := (load(ENTITY_SCENES.collection_shelf) as PackedScene).instantiate() as Node3D
		shelf.name = "CollectionShelf"
		shelf.transform = xform.affine_inverse() * shelf_xf
		_add(station, shelf, root)
		var smodel := _instance(String(sh.asset), "Model")
		_add(shelf, smodel, root)
		var sbox := _mesh_aabb(smodel)
		var sbody := StaticBody3D.new()
		sbody.name = "Collision"
		sbody.collision_layer = WORLD_LAYER
		sbody.collision_mask = 0
		_add(shelf, sbody, root)
		_box(root, sbody, "Shape", sbox.get_center(), sbox.size)
		_fit_reach(root, shelf, sbox, 0.5)


## The Interactable/Shape of an instanced entity resized around `box` (+ margin, deeper to the front).
static func _fit_reach(root: Node3D, entity: Node3D, box: AABB, margin: float) -> void:
	var shape := entity.get_node_or_null(^"Interactable/Shape") as CollisionShape3D
	if shape == null:
		return
	root.set_editable_instance(entity, true)
	var b := BoxShape3D.new()
	b.size = Vector3(box.size.x + margin * 2.0, 1.0, box.size.z + margin * 2.0 + 0.4)
	shape.shape = b
	shape.position = Vector3(box.get_center().x, 0.5, box.get_center().z + 0.2)


## The mourners: children of the set in show order (MournerSet uses its figure children); seats
## [x, z, rot_y, y] room-local, figures cycled from params.figures. Hidden until a service.
static func _mourners(root: Node3D, set_node: Node3D, params: Dictionary) -> void:
	var figures: Array = params.get("figures", [])
	var k := 0
	for seat: Array in params.get("seats", []):
		k += 1
		var fig := _instance(String(figures[(k - 1) % figures.size()]), "Mourner%d" % k)
		var world := Transform3D(Basis(Vector3.UP, deg_to_rad(float(seat[2]))), Vector3(float(seat[0]), float(seat[3]), float(seat[1])))
		fig.transform = set_node.transform.affine_inverse() * world
		fig.visible = false
		_add(set_node, fig, root)


static func _add_interactable(node: Node3D, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = "Interactable"
	area.collision_layer = INTERACT_LAYER
	area.collision_mask = 0
	area.monitoring = false
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.set("priority", PRIORITY)
	node.add_child(area)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, 0.5, 0)
	area.add_child(shape)


static func _level_metas(node: Node, item: Dictionary) -> void:
	if node == null:
		return
	if item.has("min_level"):
		node.set_meta(META_MIN, int(item.min_level))
	if item.has("max_level"):
		node.set_meta(META_MAX, int(item.max_level))


# --- lights ---------------------------------------------------------------------------------

## Lights at the light_* markers of `model` by role (see the class comment).
static func _marker_lights(root: Node3D, model: Node3D, asset: String, overrides: Dictionary, cfg: Resource) -> void:
	for marker: Node in model.find_children("light_*", "", true, false):
		var marker_name := String(marker.name)
		var role := StringName(overrides.get(marker_name, _default_role(marker_name)))
		if role == &"" or role == &"none":
			continue
		var light: Light3D
		if role == &"stain":
			var spot := SpotLight3D.new()
			spot.spot_range = 4.0
			spot.spot_angle = 26.0
			spot.spot_attenuation = 0.8
			# From the choir window forwards and down onto the floor in front of the altar.
			spot.transform = _rel(marker as Node3D, model) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-55.0)).rotated(Vector3.UP, PI), Vector3.ZERO)
			light = spot
		else:
			var omni := OmniLight3D.new()
			omni.omni_attenuation = 1.4
			omni.transform = _rel(marker as Node3D, model)
			light = omni
		light.name = "Light_" + marker_name.trim_prefix("light_")
		light.shadow_blur = 1.5
		light.set_meta(META_ROLE, role)
		match role:
			&"window":
				light.light_color = cfg.get("window_day_color")
				_range(light, cfg.get("window_range"))
				light.light_energy = cfg.get("window_day_energy")
			&"lantern":
				light.light_color = cfg.get("lantern_color")
				_range(light, cfg.get("lantern_range"))
				light.light_energy = cfg.get("lantern_night_energy")
				light.shadow_enabled = true
				light.set_script(load(FLICKER))
				light.set("amount", 0.06)
			&"candle":
				light.light_color = cfg.get("candle_color")
				_range(light, cfg.get("candle_range"))
				light.light_energy = cfg.get("candle_night_energy")
				light.set_script(load(FLICKER))
			&"rite":
				light.light_color = cfg.get("candle_color")
				_range(light, cfg.get("candle_range"))
				light.light_energy = 0.0
				light.visible = false
				light.set_script(load(FLICKER))
			&"stove":
				# Phase 7 (§4.7): the inn's tiled stove – a steady warm fire light, no shadow.
				light.light_color = cfg.get("stove_color")
				_range(light, cfg.get("stove_range"))
				light.light_energy = float(cfg.get("stove_day_energy"))
				light.set_script(load(FLICKER))
				light.set("amount", float(cfg.get("stove_flicker")))
			&"eternal":
				light.light_color = Color("#FF9A4A")
				_range(light, 1.5)
				light.light_energy = 0.4
				light.visible = false
				light.set_script(load(FLICKER))
				light.set("amount", 0.05)
			&"stain":
				light.light_color = Color("#E8A45A")
				light.light_energy = 0.0
				light.visible = false
		light.set_meta(&"base_energy", light.light_energy)
		_add(model, light, root)


## G7 round 1 (light): FillLights/Fill_<k> at the layout's fill_lights [x, y, z] (room-local) – soft
## warm omni lights without shadow (role fill: InteriorLighting blends fill_night → fill_day).
static func _fill_lights(root: Node3D, points: Array, cfg: Resource) -> void:
	var group := _group(root, "FillLights")
	var k := 0
	for p: Array in points:
		k += 1
		var omni := OmniLight3D.new()
		omni.name = "Fill_%d" % k
		omni.position = _v3(p)
		omni.omni_range = float(cfg.get("fill_range"))
		omni.omni_attenuation = float(cfg.get("fill_attenuation"))
		omni.light_color = cfg.get("fill_day_color")
		omni.light_energy = float(cfg.get("fill_day_energy"))
		omni.shadow_enabled = false
		omni.light_specular = 0.2
		omni.set_meta(META_ROLE, &"fill")
		omni.set_meta(&"base_energy", omni.light_energy)
		_add(group, omni, root)


static func _default_role(marker_name: String) -> StringName:
	if marker_name.begins_with("light_window"):
		return &"window"
	if marker_name == "light_ceiling" or marker_name == "light_lantern":
		return &"lantern"
	if marker_name == "light_stove":
		return &"stove"
	if marker_name.begins_with("light_candle"):
		return &"candle"
	return &""


static func _range(light: Light3D, value: float) -> void:
	if light is OmniLight3D:
		(light as OmniLight3D).omni_range = value


# --- collision ------------------------------------------------------------------------------

## Floor slab and the layout walls [x0, z0, x1, z1] (room-local boxes of wall_height).
static func _room_collision(root: Node3D, colliders: Node3D, layout: Dictionary) -> void:
	var body := _body(root, colliders, "Room", Transform3D.IDENTITY)
	var h := float(layout.get("wall_height", WALL_H))
	var fl: Array = layout.get("floor", [-5.0, -6.0, 5.0, 5.0])
	var fr := Rect2(float(fl[0]), float(fl[1]), float(fl[2]) - float(fl[0]), float(fl[3]) - float(fl[1]))
	_box(root, body, "Floor", Vector3(fr.get_center().x, -FLOOR_T * 0.5, fr.get_center().y), Vector3(fr.size.x, FLOOR_T, fr.size.y))
	var k := 0
	for w: Array in layout.get("walls", []):
		k += 1
		var r := Rect2(float(w[0]), float(w[1]), float(w[2]) - float(w[0]), float(w[3]) - float(w[1]))
		_box(root, body, "Wall_%d" % k, Vector3(r.get_center().x, h * 0.5, r.get_center().y), Vector3(r.size.x, h, r.size.y))


## One box around a piece (`aabb` = its mesh bounds in the frame of `xform`), shrunk by `inset`
## along X (pews: the aisle stays passable).
static func _piece_collision(root: Node3D, colliders: Node3D, aabb: AABB, xform: Transform3D, body_name: String,
		inset: float) -> StaticBody3D:
	if aabb.size == Vector3.ZERO:
		return null
	var body := _body(root, colliders, body_name, xform)
	var size := aabb.size - Vector3(inset * 2.0, 0.0, 0.0)
	_box(root, body, "Shape", aabb.get_center(), Vector3(maxf(size.x, 0.1), size.y, size.z))
	return body


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


# --- particles ------------------------------------------------------------------------------

## A few slow motes (dust in the light shaft, cold breath): {name, pos [x, y, z], box [x, y, z],
## amount, color, lifetime, size}.
static func _particles(p: Dictionary) -> CPUParticles3D:
	var parts := CPUParticles3D.new()
	parts.name = String(p.get("name", "Motes"))
	parts.amount = int(p.get("amount", 8))
	parts.lifetime = float(p.get("lifetime", 6.0))
	parts.preprocess = parts.lifetime
	parts.position = _v3(p.pos)
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	parts.emission_box_extents = _v3(p.box) * 0.5
	parts.gravity = Vector3(0.0, float(p.get("gravity", -0.02)), 0.0)
	parts.direction = Vector3(0.0, -1.0, 0.0)
	parts.spread = 60.0
	parts.initial_velocity_min = 0.02
	parts.initial_velocity_max = 0.06
	parts.scale_amount_min = 0.6
	parts.scale_amount_max = 1.0
	var c := Color(str(p.get("color", "#b8c2cc")))
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(c, 0.0), Color(c, float(p.get("alpha", 0.35))), Color(c, float(p.get("alpha", 0.35)) * 0.8), Color(c, 0.0)])
	parts.color_ramp = ramp
	parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parts.fixed_fps = 30
	parts.visibility_range_end = 40.0
	var mat := (load(SMOKE_MATERIAL) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.resource_name = "mat_vfx_interior_motes"
	mat.albedo_texture = load(SMOKE_TEXTURE) as Texture2D
	var quad := QuadMesh.new()
	var sz := float(p.get("size", 0.25))
	quad.size = Vector2(sz, sz)
	quad.material = mat
	parts.mesh = quad
	parts.emitting = true
	return parts


# --- environment & helpers ------------------------------------------------------------------

## Camera environment of the room (like the hut's); InteriorLighting animates ambient / fog.
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
	if bool(cfg.get("fog_enabled")):
		env.fog_enabled = true
		env.fog_light_color = cfg.get("fog_color")
		env.fog_density = cfg.get("fog_density")
		env.fog_sky_affect = 0.0  # W3: the void around the room keeps the background colour
	return env


static func model_path(asset: String) -> String:
	for dir: String in MODEL_DIRS:
		if ResourceLoader.exists(dir + asset + ".glb"):
			return dir + asset + ".glb"
	push_error("interior asset not found: " + asset)
	return ""


static func _instance(asset: String, node_name: String) -> Node3D:
	var inst := (load(model_path(asset)) as PackedScene).instantiate() as Node3D
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
	for c: Node in child.find_children("*", "", true, false):
		if c.owner == null:
			c.owner = root


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

extends RefCounted
## Collider helpers of graveyard_builder.gd (build-time tool, static, preloaded): the layout
## "colliders" shapes of placed models (layer 1), the GravePlots' state-dependent shapes
## (meta "role"), the ground HeightMapShape3D and the invisible walls around walkable_bounds.

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const OUT_GROUND_SHAPE := "res://src/world/graveyard/ground_shape.res"
## GravePlot collision roles (see grave_plot.gd ROLE_*).
const ROLE_PIT := "pit"
const ROLE_MOUND := "mound"
const ROLE_MARKER := "marker:"
const ROLE_OLD := "old"


## Collision shapes of `asset` (layout "colliders") under a new StaticBody3D at `xform`.
## scale: uniform scale of the placed model; stretch_x: fence pieces shortened along X.
static func collider(ctx: Ctx, asset: String, xform: Transform3D, body_name: String, scale: float = 1.0, stretch_x: float = 1.0) -> StaticBody3D:
	var defs: Array = ctx.layout.colliders.get(asset, [])
	if defs.is_empty():
		return null
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	body.transform = xform
	ctx.add(ctx.colliders, body)
	add_shapes(ctx, body, defs, Transform3D.IDENTITY, scale, stretch_x, "")
	ctx.collider_count += 1
	return body


static func add_shapes(ctx: Ctx, body: Node3D, defs: Array, local: Transform3D, scale: float, stretch_x: float, role: String) -> void:
	for def: Dictionary in defs:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape%d" % body.get_child_count()
		var offset := Ctx.v3(def.offset) * scale
		offset.x *= stretch_x
		if def.shape == "box":
			var box := BoxShape3D.new()
			var size := Ctx.v3(def.size) * scale
			size.x *= stretch_x
			box.size = size
			shape_node.shape = box
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = float(def.radius) * scale
			cyl.height = float(def.height) * scale
			shape_node.shape = cyl
		shape_node.transform = local * Transform3D(Basis.IDENTITY, offset)
		if role != "":
			shape_node.set_meta(&"role", role)
			shape_node.disabled = role != ROLE_OLD
		ctx.add(body, shape_node)


## "Collision" StaticBody3D of a GravePlot with the shapes of every state it can show.
static func build_plot_collision(ctx: Ctx, plot: Node3D, g: Dictionary, old: bool) -> void:
	var colliders: Dictionary = ctx.layout.colliders
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(plot, body)
	if old:
		add_shapes(ctx, body, colliders["ph_prop_grave_mound_" + String(g.mound)], Transform3D.IDENTITY, 1.0, 1.0, ROLE_OLD)
		add_shapes(ctx, body, colliders["ph_prop_gravestone_" + String(g.stone)],
				Transform3D(Basis.IDENTITY, plot.get("old_stone_offset")), 1.0, 1.0, ROLE_OLD)
		return
	add_shapes(ctx, body, colliders[_asset_of(plot.get("pit_model"))], Transform3D.IDENTITY, 1.0, 1.0, ROLE_PIT)
	add_shapes(ctx, body, colliders[_asset_of(plot.get("mound_model"))],
			Transform3D(Basis.IDENTITY, plot.get("mound_offset")), 1.0, 1.0, ROLE_MOUND)
	var markers: Dictionary = plot.get("marker_models")
	for marker_id: StringName in markers:
		add_shapes(ctx, body, colliders[_asset_of(markers[marker_id])],
				Transform3D(Basis.IDENTITY, plot.get("marker_offset")), 1.0, 1.0, ROLE_MARKER + String(marker_id))


## Ground collision: a HeightMapShape3D of the same grid (uniform scale = cell size).
static func build_ground_collision(ctx: Ctx) -> void:
	var body := StaticBody3D.new()
	body.name = "GroundCollision"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(ctx.scene_root, body)
	var w := ctx.grid_max.x - ctx.grid_min.x + 1
	var d := ctx.grid_max.y - ctx.grid_min.y + 1
	var data := PackedFloat32Array()
	data.resize(w * d)
	for j: int in d:
		for i: int in w:
			data[j * w + i] = float(ctx.heights.get(Vector2i(ctx.grid_min.x + i, ctx.grid_min.y + j), 0.0)) / ctx.cell
	var hm := HeightMapShape3D.new()
	hm.map_width = w
	hm.map_depth = d
	hm.map_data = data
	var err := ResourceSaver.save(hm, OUT_GROUND_SHAPE)  # binary: keeps the .tscn small
	assert(err == OK, "save failed: %s" % OUT_GROUND_SHAPE)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	shape.shape = load(OUT_GROUND_SHAPE)
	var centre := Vector3((ctx.grid_min.x + (w - 1) * 0.5) * ctx.cell, 0.0, (ctx.grid_min.y + (d - 1) * 0.5) * ctx.cell)
	shape.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * ctx.cell), centre)
	ctx.add(body, shape)


## Invisible walls around walkable_bounds (layer 1), plus the layout "extra_walls" (same height
## and thickness, centred on their line – Phase 3 §4.1).
static func build_bounds(ctx: Ctx) -> void:
	var cfg: Dictionary = ctx.layout.walkable_bounds
	var lo := Ctx.v2(cfg.min)
	var hi := Ctx.v2(cfg.max)
	var h := float(cfg.wall_height)
	var t := float(cfg.wall_thickness)
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(ctx.colliders, body)
	var mid := (lo + hi) * 0.5
	var size := hi - lo
	var walls := {
		"West": [Vector3(lo.x - t * 0.5, h * 0.5, mid.y), Vector3(t, h, size.y + 2.0 * t)],
		"East": [Vector3(hi.x + t * 0.5, h * 0.5, mid.y), Vector3(t, h, size.y + 2.0 * t)],
		"North": [Vector3(mid.x, h * 0.5, lo.y - t * 0.5), Vector3(size.x + 2.0 * t, h, t)],
		"South": [Vector3(mid.x, h * 0.5, hi.y + t * 0.5), Vector3(size.x + 2.0 * t, h, t)],
	}
	for wall_name: String in walls:
		var shape := CollisionShape3D.new()
		shape.name = wall_name
		var box := BoxShape3D.new()
		box.size = walls[wall_name][1]
		shape.shape = box
		shape.position = walls[wall_name][0]
		ctx.add(body, shape)
	var k := 0
	for seg: Array in ctx.layout.get("extra_walls", []):
		k += 1
		var a := Ctx.v2(seg[0])
		var b := Ctx.v2(seg[1])
		var d := b - a
		var shape := CollisionShape3D.new()
		shape.name = "Extra_%d" % k
		var box := BoxShape3D.new()
		box.size = Vector3(d.length() + t, h, t)
		shape.shape = box
		var mid2 := (a + b) * 0.5
		shape.transform = Transform3D(Basis(Vector3.UP, atan2(-d.y, d.x)), Vector3(mid2.x, h * 0.5, mid2.y))
		ctx.add(body, shape)


static func _asset_of(scene: PackedScene) -> String:
	return scene.resource_path.get_file().get_basename()

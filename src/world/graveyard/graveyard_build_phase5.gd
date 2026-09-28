extends RefCounted
## Phase-5 helpers of graveyard_builder.gd (build-time tool, static, preloaded –
## docs/PHASE5_DESIGN.md §3.1, §4): the new system nodes (Gathering, Workshop, Stonemasonry), the
## workyard next to the hut (three BuildSites with the staked ph_prop_build_site, three stations =
## Workbench with station + requires_built and their model, collision, forge glow, chimney smoke,
## the charcoal kiln and the rack of finished stones), the gather nodes of Am Bruch and the Schlag
## (+ the elder bushes' nodes without a model), the rock edges / hedges / old slab of Am Bruch.
## The Ostpforte and the boulders are layout clearables (graveyard_build_phase3.gd builds them;
## the gate is stretched here). Scripts are loaded by path (see graveyard_builder.gd).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const BUILD_SITE_SCENE := "res://src/entities/build_site/build_site.tscn"
const GATHER_SCENE := "res://src/entities/gather_node/gather_node.tscn"
const WORKBENCH_SCRIPT := "res://src/entities/workbench/workbench.gd"
const INTERACTABLE_SCRIPT := "res://src/components/interactable.gd"
const KILN_SCRIPT := "res://src/world/graveyard/kiln_visual.gd"
const RACK_SCRIPT := "res://src/world/graveyard/stone_rack.gd"
const SMOKE_MATERIAL := "res://assets/materials/mat_vfx_smoke.tres"
const SMOKE_TEXTURE := "res://assets/vfx/ph_vfx_smoke_wisp.png"
const KILN_COLD := "ph_prop_charcoal_kiln"
const KILN_BURNING := "ph_prop_charcoal_kiln_burning"
## §3.1: node name → script (groups / save_id / save_order are set by the scripts themselves:
## gathering 25, workshop 30, stonemasonry 35).
const SYSTEMS := [
	["Gathering", "res://src/systems/gathering/gather_manager.gd"],
	["Workshop", "res://src/systems/workshop/workshop.gd"],
	["Stonemasonry", "res://src/systems/stone/stonemasonry.gd"],
]
## Interactable priority of the stations (like the workbench) and the reach margin (m).
const STATION_PRIORITY := 5
const REACH_MARGIN := 0.35
## §4.1 / §9: chimney and kiln smoke – 3 particles each, warm grey, culled beyond 40 m.
const SMOKE_PARTICLES := 3
const SMOKE_COLOR := Color("8E8478")
const SMOKE_RANGE := 40.0


static func build_systems(ctx: Ctx, systems: Node) -> void:
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		if entry[0] == "Workshop":
			node.set("workyard_rects", workyard_rects(ctx.layout))
		ctx.add(systems, node)


## layout.workyard.blocked_rects as world Rect2 (Workshop.workyard_rects, §5.2 step 5).
static func workyard_rects(layout: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for r: Array in layout.get("workyard", {}).get("blocked_rects", []):
		out.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	return out


## Transform of a build site (on the ground).
static func site_xform(ctx: Ctx, site: Dictionary) -> Transform3D:
	return ctx.ground_xform(Ctx.v2(site.pos), float(site.rot_y))


static func site_of(layout: Dictionary, site_id: String) -> Dictionary:
	for s: Dictionary in layout.workyard.build_sites:
		if s.id == site_id:
			return s
	return {}


static func footprint(site: Dictionary) -> Rect2:
	var fp: Array = site.footprint
	return Rect2(float(fp[0]), float(fp[1]), float(fp[2]), float(fp[3]))


# --- workyard (§4.1) -------------------------------------------------------------------------

static func build_workyard(ctx: Ctx, entities: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.workyard
	for site: Dictionary in cfg.build_sites:
		_build_site(ctx, entities, site, cfg)
	for st: Dictionary in ctx.layout.stations:
		_build_station(ctx, entities, st)


## BuildSite: the staked plot model stretched to the station's footprint (X/Z only), a low
## collision body and the Interactable over the footprint.
static func _build_site(ctx: Ctx, parent: Node3D, site: Dictionary, cfg: Dictionary) -> void:
	var node := (load(BUILD_SITE_SCENE) as PackedScene).instantiate() as Node3D
	node.name = site.id
	node.set("station_id", StringName(site.station))
	node.transform = site_xform(ctx, site)
	ctx.add(parent, node)
	var fp := footprint(site)
	var size := Ctx.v2(cfg.site_model_size)
	var model := (load(Ctx.model_path(String(cfg.site_model))) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	model.transform = Transform3D(Basis.IDENTITY.scaled(Vector3(fp.size.x / size.x, 1.0, fp.size.y / size.y)),
			Vector3(fp.get_center().x, 0.0, fp.get_center().y))
	ctx.add(node, model)
	_add_body(ctx, node, String(cfg.site_model), fp, Vector2(fp.size.x / size.x, fp.size.y / size.y))
	_fit_interactable(ctx, node, fp)


## Entities/station_<id>: a Workbench node (built here, not from workbench.tscn – its model is
## the station's) with station + requires_built, model, collision, Interactable; the forge also
## carries the glow, the chimney smoke and the charcoal kiln; the mason's bench the stone rack.
static func _build_station(ctx: Ctx, parent: Node3D, st: Dictionary) -> void:
	var site := site_of(ctx.layout, String(st.site))
	var node := Node3D.new()
	node.name = st.id
	node.set_script(load(WORKBENCH_SCRIPT))
	node.set("station", StringName(st.station))
	node.set("requires_built", true)
	node.transform = site_xform(ctx, site)
	ctx.add(parent, node)
	var asset := String(st.model)
	var model := (load(Ctx.model_path(asset)) as PackedScene).instantiate() as Node3D
	model.name = "Model"
	ctx.add(node, model)
	ctx.attach_lights(asset, model)
	var fp := footprint(site)
	_add_body(ctx, node, asset, fp, Vector2.ONE)
	var area := Area3D.new()
	area.name = "Interactable"
	area.set_script(load(INTERACTABLE_SCRIPT))
	area.set("priority", STATION_PRIORITY)
	ctx.add(node, area)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = Vector3(fp.size.x + REACH_MARGIN * 2.0, 1.0, fp.size.y + REACH_MARGIN * 2.0)
	shape.shape = box
	shape.position = Vector3(fp.get_center().x, 0.5, fp.get_center().y)
	ctx.add(area, shape)
	var smoke_marker := model.find_child("smoke", true, false) as Node3D
	if smoke_marker != null:
		var smoke := make_smoke("ChimneySmoke", 1.6, 6.0)
		smoke.transform = Ctx.rel_xform(smoke_marker, node)
		smoke.emitting = true
		ctx.add(node, smoke)
	if st.get("kiln", false):
		_build_kiln(ctx, node)
	if String(st.station) == "mason":
		var rack := Node3D.new()
		rack.name = "StoneRack"
		rack.set_script(load(RACK_SCRIPT))
		ctx.add(node, rack)


## The charcoal kiln (§2.1 Meiler) as a child of the forge station (hidden until the forge is
## built): cold / burning model + smoke, switched by kiln_visual.gd from the forge's job.
static func _build_kiln(ctx: Ctx, forge: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.workyard.meiler
	var kiln := Node3D.new()
	kiln.name = "Kiln"
	kiln.set_script(load(KILN_SCRIPT))
	var world_xf := ctx.ground_xform(Ctx.v2(cfg.pos), float(cfg.get("rot_y", 0.0)))
	kiln.transform = forge.transform.affine_inverse() * world_xf
	ctx.add(forge, kiln)
	for entry: Array in [[KILN_COLD, "Cold"], [KILN_BURNING, "Burning"]]:
		var m := (load(Ctx.model_path(String(entry[0]))) as PackedScene).instantiate() as Node3D
		m.name = entry[1]
		ctx.add(kiln, m)
	kiln.get_node("Burning").visible = false
	var marker := kiln.get_node("Burning").find_child("smoke", true, false) as Node3D
	var smoke := make_smoke("Smoke", 1.3, 5.0)
	smoke.transform = Ctx.rel_xform(marker, kiln) if marker != null else Transform3D(Basis.IDENTITY, Vector3(0, 0.86, 0))
	smoke.emitting = false
	smoke.visible = false
	ctx.add(kiln, smoke)
	# The kiln collides (it is not walkable) – as part of the forge, only once built.
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(kiln, body)
	Colliders.add_shapes(ctx, body, ctx.layout.colliders[KILN_COLD], Transform3D.IDENTITY, 1.0, 1.0, "")


## Thin smoke thread (§4.1: juniper smoke texture, warm grey, 3 particles, no shadow, 40 m).
static func make_smoke(node_name: String, width: float, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.amount = SMOKE_PARTICLES
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.direction = Vector3(0.12, 1.0, -0.08)
	p.spread = 10.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.45
	p.angle_min = -25.0
	p.angle_max = 25.0
	p.angular_velocity_min = -6.0
	p.angular_velocity_max = 6.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.45))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	ramp.colors = PackedColorArray([Color(SMOKE_COLOR, 0.0), Color(SMOKE_COLOR, 1.0), Color(SMOKE_COLOR, 0.7), Color(SMOKE_COLOR, 0.0)])
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	p.fixed_fps = 30
	p.visibility_range_end = SMOKE_RANGE
	var mat := (load(SMOKE_MATERIAL) as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.resource_name = "mat_vfx_smoke_workyard"
	mat.albedo_texture = load(SMOKE_TEXTURE) as Texture2D
	var quad := QuadMesh.new()
	quad.size = Vector2(width * 0.6, width)
	quad.material = mat
	p.mesh = quad
	return p


## StaticBody3D "Collision" (child of `node`) from the layout colliders of `asset`, scaled in X/Z
## by `stretch` (build-site model stretched to the footprint).
static func _add_body(ctx: Ctx, node: Node3D, asset: String, fp: Rect2, stretch: Vector2) -> void:
	var defs: Array = ctx.layout.colliders.get(asset, [])
	if defs.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	ctx.add(node, body)
	var centre := Transform3D(Basis.IDENTITY, Vector3(fp.get_center().x, 0.0, fp.get_center().y))
	for def: Dictionary in defs:
		var shape_node := CollisionShape3D.new()
		shape_node.name = "Shape%d" % body.get_child_count()
		var offset := Ctx.v3(def.offset)
		if def.shape == "box":
			var box := BoxShape3D.new()
			var s := Ctx.v3(def.size)
			box.size = Vector3(s.x * stretch.x, s.y, s.z * stretch.y)
			shape_node.shape = box
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = float(def.radius)
			cyl.height = float(def.height)
			shape_node.shape = cyl
		shape_node.transform = centre * Transform3D(Basis.IDENTITY, Vector3(offset.x * stretch.x, offset.y, offset.z * stretch.y))
		ctx.add(body, shape_node)


## The BuildSite's Interactable box (build_site.tscn) resized to the footprint + reach margin.
static func _fit_interactable(ctx: Ctx, node: Node3D, fp: Rect2) -> void:
	var shape := node.get_node("Interactable/Shape") as CollisionShape3D
	ctx.scene_root.set_editable_instance(node, true)
	var box := BoxShape3D.new()
	box.size = Vector3(fp.size.x + REACH_MARGIN * 2.0, 1.0, fp.size.y + REACH_MARGIN * 2.0)
	shape.shape = box
	shape.position = Vector3(fp.get_center().x, 0.5, fp.get_center().y)


# --- gather nodes (§2.2, §4.2–4.4) ----------------------------------------------------------

## Entities/gather_<id>: GatherNode with its stage models from GatherNodeData (runtime) and –
## where the layout has colliders for the full model – a collision body (trunk, rock).
static func build_gather_nodes(ctx: Ctx, entities: Node3D) -> void:
	var db: Node = ctx.tree.root.get_node(^"Database")
	for g: Dictionary in ctx.layout.get("gather_nodes", []):
		var node := _gather_node(g.id, StringName(g.kind), StringName(g.get("section", "")))
		node.transform = ctx.ground_xform(Ctx.v2(g.pos), float(g.rot_y))
		ctx.add(entities, node)
		var data: Resource = db.call(&"gather_kind", StringName(g.kind))
		assert(data != null and data.get("model_full") != null, "gather data / model for " + String(g.kind))
		var asset := (data.get("model_full") as PackedScene).resource_path.get_file().get_basename()
		var defs: Array = ctx.layout.colliders.get(asset, [])
		if not defs.is_empty():
			var body := StaticBody3D.new()
			body.name = "Collision"
			body.collision_layer = Ctx.WORLD_LAYER
			body.collision_mask = 0
			ctx.add(node, body)
			Colliders.add_shapes(ctx, body, defs, Transform3D.IDENTITY, 1.0, 1.0, "")


## §4.4: one GatherNode without a model per elder bush (child of the bush, moved `offset` towards
## the inside so the gravekeeper reaches it over the fence).
static func build_elder_gather(ctx: Ctx, decor: Node3D) -> void:
	var bushes := decor.get_node("ElderBushes")
	var k := 0
	for b: Dictionary in ctx.layout.get("elder_bushes", []):
		k += 1
		if not b.has("gather"):
			continue
		var bush := bushes.get_node("ElderBush_%d" % k) as Node3D
		var node := _gather_node(b.gather.id, &"elder_bush", &"")
		var world := Ctx.v2(b.pos) + Ctx.v2(b.gather.offset)
		var xf := ctx.ground_xform(world, 0.0)
		node.transform = bush.transform.affine_inverse() * xf
		ctx.add(bush, node)


static func _gather_node(id: String, kind: StringName, section: StringName) -> Node3D:
	var node := (load(GATHER_SCENE) as PackedScene).instantiate() as Node3D
	node.name = id
	node.set("node_id", id)
	node.set("kind", kind)
	node.set("section_id", section)
	return node


# --- Am Bruch (§4.2) ------------------------------------------------------------------------

## Rock faces, edge pieces, the southern hedge and the old slab (Decor/Bruch), colliders per
## layout (except "collide": false); the Ostpforte model stretched to 1.6 m.
static func build_bruch(ctx: Ctx, decor: Node3D, entities: Node3D) -> void:
	var group := ctx.group(decor, "Bruch")
	var k := 0
	for e: Dictionary in ctx.layout.get("quarry_edges", []):
		k += 1
		var asset := String(e.asset)
		var node_name := "%s_%02d" % [asset.trim_prefix("ph_env_").trim_prefix("ph_prop_"), k]
		var node := ctx.place(asset, group, Ctx.v2(e.pos), float(e.rot_y), node_name)
		node.scale = Vector3.ONE * float(e.get("scale", 1.0))
		if e.get("collide", true):
			Colliders.collider(ctx, asset, node.transform, "Bruch_%02d" % k, float(e.get("scale", 1.0)))
	for c: Dictionary in ctx.layout.clearables:
		if not c.has("model_scale_x"):
			continue
		var node := entities.get_node(String(c.id)) as Node3D
		var sx := float(c.model_scale_x)
		for child_name: String in ["Model", "Repaired"]:
			var child := node.get_node_or_null(child_name) as Node3D
			if child != null:
				child.scale = Vector3(sx, 1.0, 1.0)
		# Physics bodies take no non-uniform scale: stretch the box shapes instead.
		for shape: Node in node.get_node("Collision").get_children():
			var cs := shape as CollisionShape3D
			var box := (cs.shape as BoxShape3D).duplicate() as BoxShape3D
			box.size.x *= sx
			cs.shape = box
			cs.position.x *= sx

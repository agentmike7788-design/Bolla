extends RefCounted
## Phase-3 helpers of graveyard_builder.gd (build-time tool, static, preloaded –
## docs/PHASE3_DESIGN.md §3.1, §4): the new system nodes, the obstacles of the new sections
## (ClearableObstacle with model, collision and – for fence gaps – the repaired fence), the
## tending spots (22 area spots + one per grave on its mound), the notice board, the birches,
## the fence passage and the baked build mask (src/world/graveyard/build_mask.res).
## Scripts are loaded by path (see graveyard_builder.gd: no class_name of autoload users).

const Ctx := preload("res://src/world/graveyard/graveyard_build_context.gd")
const Colliders := preload("res://src/world/graveyard/graveyard_build_colliders.gd")
const OUT_MASK := "res://src/world/graveyard/build_mask.res"
const MASK_SCRIPT := "res://src/systems/decoration/build_mask.gd"
const CLEARABLE_SCENE := "res://src/entities/clearable/clearable.tscn"
const DIRT_SCENE := "res://src/entities/dirt_spot/dirt_spot.tscn"
const NOTICE_SCENE := "res://src/entities/notice_board/notice_board.tscn"
const GHOST_SCENE := "res://src/entities/ghost/ghost.tscn"
const MOUND_ASSET := "ph_prop_grave_mound_fresh"
const BIRCH_ASSET := "ph_env_birch"
const PASSAGE_ASSET := "ph_prop_fence_passage"
const FENCE_ASSET := "ph_prop_fence_iron"
const FENCE_GAP := "fence_gap"
## Local X of a fence-gap model: the 2 m piece runs along +X from its origin, the obstacle node
## sits in the middle of the gap.
const GAP_HALF := 1.0
const GAP_FOOTPRINT := Rect2(-1.0, -0.3, 2.0, 0.6)
## §3.1: node name → script (save_id / save_order / groups are set by the scripts themselves).
const SYSTEMS := [
	["Expansion", "res://src/systems/expansion/expansion_manager.gd"],
	["Cleanliness", "res://src/systems/cleanliness/cleanliness_manager.gd"],
	["Decorations", "res://src/systems/decoration/decoration_manager.gd"],
	["BuildMode", "res://src/systems/decoration/build_mode.gd"],
	["GrassClearMask", "res://src/systems/decoration/grass_clear_mask.gd"],
	["CemeteryScore", "res://src/systems/graveyard/cemetery_score.gd"],
	["Reputation", "res://src/systems/reputation/reputation.gd"],
	["Ghosts", "res://src/systems/ghosts/ghost_manager.gd"],
]
## GravePlot.footprint / old-grave rect (plot-local XZ) – mirrors grave_plot.gd / the grass.
const PLOT_RECT := Rect2(-0.72, -1.25, 2.32, 2.5)
const OLD_RECT := Rect2(-0.62, -1.35, 1.24, 2.35)
const MARKER_RECT := Rect2(-0.3, -1.25, 0.6, 0.35)
## Hut door access (like the grass keep-out).
const DOOR_RECT := Rect2(-0.9, -1.0, 1.8, 1.8)


# --- system nodes (§3.1) ----------------------------------------------------------------------

## Adds the Phase-3 systems under Systems (after CorpseManager / Graveyard: §3.1 order) and the
## containers Decor/Placed + Decor/Ghosts. Needs the saved build mask (bake_mask first).
static func build_systems(ctx: Ctx, systems: Node, decor: Node3D) -> void:
	ctx.group(decor, "Placed")
	ctx.group(decor, "Ghosts")
	var mask: Resource = load(OUT_MASK)
	for entry: Array in SYSTEMS:
		var node: Node = load(entry[1]).new()
		node.name = entry[0]
		match String(entry[0]):
			"Decorations":
				node.set("mask", mask)
				node.set("container_path", NodePath("../../Decor/Placed"))
			"GrassClearMask":
				node.set("mask", mask)
			"Ghosts":
				node.set("ghost_scene", load(GHOST_SCENE))
				node.set("container_path", NodePath("../../Decor/Ghosts"))
		ctx.add(systems, node)
	# Expansion first (§3.1 table order): move it in front of CorpseManager.
	systems.move_child(systems.get_node("Expansion"), 0)


# --- obstacles --------------------------------------------------------------------------------

## Every obstacle of the layout: "clearables" plus the fence gaps ("fence.ruins").
static func obstacles(layout: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Dictionary in layout.clearables:
		out.append(c)
	for r: Dictionary in layout.fence.ruins:
		var fp := GAP_FOOTPRINT
		out.append({"id": r.obstacle, "kind": FENCE_GAP, "section": r.section, "pos": r.pos, "rot_y": r.rot_y,
				"footprint": [fp.position.x, fp.position.y, fp.size.x, fp.size.y]})
	return out


static func build_obstacles(ctx: Ctx, entities: Node3D) -> void:
	for o: Dictionary in obstacles(ctx.layout):
		_build_obstacle(ctx, entities, o)


static func _build_obstacle(ctx: Ctx, parent: Node3D, o: Dictionary) -> void:
	var node := (load(CLEARABLE_SCENE) as PackedScene).instantiate() as Node3D
	node.name = o.id
	node.set("obstacle_id", o.id)
	node.set("section_id", StringName(o.section))
	node.set("kind", StringName(o.kind))
	var fp: Array = o.footprint
	node.set("footprint", Rect2(fp[0], fp[1], fp[2], fp[3]))
	node.transform = ctx.ground_xform(Ctx.v2(o.pos), float(o.rot_y))
	ctx.add(parent, node)
	var data: Resource = ctx.tree.root.get_node(^"Database").call(&"clearable", StringName(o.kind))
	assert(data != null and data.get("model") != null, "clearable data/model for " + String(o.kind))
	var gap := String(o.kind) == FENCE_GAP
	var local := Transform3D(Basis.IDENTITY, Vector3(-GAP_HALF, 0.0, 0.0)) if gap else Transform3D.IDENTITY
	var model_asset := _asset_of(data.get("model"))
	_add_model(ctx, node, model_asset, "Model", local)
	_add_body(ctx, node, model_asset, "Collision", local, false)
	if gap:
		var repaired_asset := _asset_of(data.get("repaired_model"))
		_add_model(ctx, node, repaired_asset, "Repaired", local).visible = false
		_add_body(ctx, node, repaired_asset, "RepairedCollision", local, true)
	elif data.get("repaired_model") != null:
		# Phase 4: the gate_small shows its open variant once unlocked (walkable, no collision).
		_add_model(ctx, node, _asset_of(data.get("repaired_model")), "Repaired", local).visible = false


static func _add_model(ctx: Ctx, parent: Node3D, asset: String, node_name: String, local: Transform3D) -> Node3D:
	var inst := (load(Ctx.model_path(asset)) as PackedScene).instantiate() as Node3D
	inst.name = node_name
	inst.transform = local
	ctx.add(parent, inst)
	return inst


static func _add_body(ctx: Ctx, parent: Node3D, asset: String, node_name: String, local: Transform3D, disabled: bool) -> void:
	var defs: Array = ctx.layout.colliders.get(asset, [])
	assert(not defs.is_empty(), "colliders for " + asset)
	var body := StaticBody3D.new()
	body.name = node_name
	body.collision_layer = Ctx.WORLD_LAYER
	body.collision_mask = 0
	body.transform = local
	ctx.add(parent, body)
	Colliders.add_shapes(ctx, body, defs, Transform3D.IDENTITY, 1.0, 1.0, "")
	for shape: Node in body.get_children():
		(shape as CollisionShape3D).disabled = disabled


# --- tending spots (§2.4) ---------------------------------------------------------------------

static func build_dirt_spots(ctx: Ctx, entities: Node3D) -> void:
	var layout := ctx.layout
	for d: Dictionary in layout.dirt_spots:
		var spot := _dirt_node(d.id, StringName(d.section), StringName(d.kind), "", float(d.start))
		spot.transform = ctx.ground_xform(Ctx.v2(d.pos), 0.0)
		ctx.add(entities, spot)
	var cfg: Dictionary = layout.grave_dirt
	var local := Ctx.v2(cfg.local)
	var mound_offset := Vector3(0, 0, 0.1)  # GravePlot.mound_offset
	var mound_heights := _mesh_heights(MOUND_ASSET)
	for p: Dictionary in layout.plots:
		var spot := _dirt_node("dirt_" + String(p.id), StringName(p.section), &"weeds", p.id, 0.0)
		var plot_xform := ctx.ground_xform(Ctx.v2(p.pos), float(p.rot_y))
		var h := _height_near(mound_heights, Vector2(local.x - mound_offset.x, local.y - mound_offset.z), 0.12) - float(cfg.mound_inset)
		spot.transform = plot_xform * Transform3D(Basis.IDENTITY, Vector3(local.x, maxf(h, 0.0), local.y))
		ctx.add(entities, spot)
		# Instance-child override: saved only for an editable instance.
		ctx.scene_root.set_editable_instance(spot, true)
		(spot.get_node("Interactable")).set("priority", int(cfg.priority))


static func _dirt_node(id: String, section: StringName, kind: StringName, grave_id: String, start: float) -> Node3D:
	var spot := (load(DIRT_SCENE) as PackedScene).instantiate() as Node3D
	spot.name = id
	spot.set("spot_id", id)
	spot.set("section_id", section)
	spot.set("kind", kind)
	spot.set("grave_id", grave_id)
	spot.set("start_progress", start)
	return spot


## Vertex positions (model-local) of the first mesh of `asset`.
static func _mesh_heights(asset: String) -> PackedVector3Array:
	var scene := (load(Ctx.model_path(asset)) as PackedScene).instantiate()
	var out := PackedVector3Array()
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xf := Ctx.rel_xform(mi, scene)
		for s: int in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				out.append(xf * v)
	scene.free()
	return out


## Highest vertex within `radius` (XZ) of `p` (0 if none).
static func _height_near(verts: PackedVector3Array, p: Vector2, radius: float) -> float:
	var best := 0.0
	for v: Vector3 in verts:
		if Vector2(v.x, v.z).distance_to(p) <= radius:
			best = maxf(best, v.y)
	return best


# --- notice board, birches, passage -----------------------------------------------------------

static func build_notice_board(ctx: Ctx, entities: Node3D) -> void:
	var cfg: Dictionary = ctx.layout.notice_board
	var board := (load(NOTICE_SCENE) as PackedScene).instantiate() as Node3D
	board.name = "notice_board"
	board.transform = ctx.ground_xform(Ctx.v2(cfg.pos), float(cfg.rot_y))
	ctx.add(entities, board)
	Colliders.collider(ctx, String(cfg.asset), board.transform, "notice_board")


static func build_birches(ctx: Ctx, decor: Node3D) -> void:
	var group := ctx.group(decor, "Birches")
	var k := 0
	for b: Dictionary in ctx.layout.birches:
		k += 1
		var tree := ctx.place(BIRCH_ASSET, group, Ctx.v2(b.pos), float(b.rot_y), "Birch_%02d" % k)
		tree.scale = Vector3.ONE * float(b.scale)
		Colliders.collider(ctx, BIRCH_ASSET, ctx.ground_xform(Ctx.v2(b.pos), float(b.rot_y)), "Birch_%02d" % k, float(b.scale))


static func build_passages(ctx: Ctx, fence: Node3D) -> void:
	for p: Dictionary in ctx.layout.fence.passages:
		ctx.place(PASSAGE_ASSET, fence, Ctx.v2(p.pos), float(p.rot_y), String(p.id))
		Colliders.collider(ctx, PASSAGE_ASSET, ctx.ground_xform(Ctx.v2(p.pos), float(p.rot_y)), String(p.id))


## Scenery of the locked sections (layout "overgrowth"): tall weeds and leaf litter scattered
## (seeded) between the obstacles, no collision, no shadow; Decor/Overgrowth/<section> is hidden
## by WorldRoot once the section is unlocked.
static func build_overgrowth(ctx: Ctx, decor: Node3D) -> void:
	var layout := ctx.layout
	var cfg: Dictionary = layout.overgrowth
	var root := ctx.group(decor, "Overgrowth")
	var avoid: Array[Dictionary] = []
	for o: Dictionary in obstacles(layout):
		avoid.append({"c": Ctx.v2(o.pos), "r": float(cfg.keep_out_obstacle) * (0.5 if o.kind == FENCE_GAP else 1.0)})
	for d: Dictionary in layout.dirt_spots:
		avoid.append({"c": Ctx.v2(d.pos), "r": float(cfg.keep_out_spot)})
	for b: Dictionary in layout.birches:
		avoid.append({"c": Ctx.v2(b.pos), "r": 0.6})
	var fences: Array = []
	for seg: Array in layout.fence.segments:
		fences.append([Ctx.v2(seg[0]), Ctx.v2(seg[1])])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg.seed)
	for s: Dictionary in cfg.sections:
		var group := ctx.group(root, String(s.id))
		var rect := Rect2()
		for sec: Dictionary in layout.sections:
			if sec.id == s.id:
				rect = Rect2(sec.rect[0], sec.rect[1], sec.rect[2] - sec.rect[0], sec.rect[3] - sec.rect[1]).grow(-float(cfg.margin))
		var placed := 0
		var tries := 0
		var body: StaticBody3D = null
		while placed < int(s.count) and tries < 2000:
			tries += 1
			var p := Vector2(rng.randf_range(rect.position.x, rect.end.x), rng.randf_range(rect.position.y, rect.end.y))
			if avoid.any(func(a: Dictionary) -> bool: return p.distance_to(a.c) < float(a.r)):
				continue
			if fences.any(func(f: Array) -> bool: return _dist_to_polyline(p, f) < float(cfg.keep_out_fence)):
				continue
			placed += 1
			var assets: Array = s.get("assets", cfg.assets)
			var asset: String = assets[rng.randi() % assets.size()]
			var range_s: Array = cfg.scale.get(asset, cfg.scale.default)
			var scale := rng.randf_range(float(range_s[0]), float(range_s[1]))
			var inst := ctx.place(asset, group, p, rng.randf() * 360.0, "%s_%02d" % [asset.trim_prefix("ph_env_"), placed])
			inst.scale = Vector3.ONE * scale
			if asset == "ph_env_bush":
				if body == null:
					body = StaticBody3D.new()
					body.name = "Collision"
					body.collision_layer = Ctx.WORLD_LAYER
					body.collision_mask = 0
					ctx.add(group, body)
				var shape := CollisionShape3D.new()
				shape.name = "Shape_%02d" % placed
				var cyl := CylinderShape3D.new()
				cyl.radius = float(cfg.bush_radius) * scale
				cyl.height = 1.0
				shape.shape = cyl
				shape.position = Vector3(p.x, ctx.ground_height(p) + 0.5, p.y)
				ctx.add(body, shape)
			else:
				for mesh: Node in inst.find_children("*", "GeometryInstance3D", true, false):
					(mesh as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			avoid.append({"c": p, "r": 0.8})


# --- build mask (§4.3) ------------------------------------------------------------------------

## Bakes and saves the BuildMask: per cell the section order (1 yard, 2 east, 3 north, 4 elder) or 0 =
## blocked (plots, old graves, buildings, stations, trees, fence, fixed colliders), plus the
## GRAVE_RING (0.5 m around plots) and ROUTE flags (earth path, carter route, station access,
## strip at the grave's foot end, passages). Obstacles are not baked (runtime blockers).
static func bake_mask(ctx: Ctx) -> Resource:
	var layout := ctx.layout
	var cfg: Dictionary = layout.build
	var mask: Resource = load(MASK_SCRIPT).new()
	var origin := Ctx.v2(cfg.origin)
	var size := Vector2i(int(cfg.size[0]), int(cfg.size[1]))
	var cell := float(cfg.cell)
	mask.set("origin", origin)
	mask.set("cell", cell)
	mask.set("size", size)
	var shapes := mask_shapes(ctx)
	var cells := PackedByteArray()
	cells.resize(size.x * size.y)
	for cz: int in size.y:
		for cx: int in size.x:
			var p := origin + (Vector2(cx, cz) + Vector2(0.5, 0.5)) * cell
			cells[cz * size.x + cx] = mask_value(p, cell * 0.5, shapes)
	mask.set("cells", cells)
	var err := ResourceSaver.save(mask, OUT_MASK)
	assert(err == OK, "save failed: " + OUT_MASK)
	print("  saved ", OUT_MASK, " (", size, ")")
	return mask


## Shapes of the mask (also used by tests through the layout): {sections: [[order, Rect2]],
## blocked / ring / route: [{kind, ...}]}. Rotated rects {pos, rot, rect}, circles {c, r},
## polylines {pts, r}.
static func mask_shapes(ctx: Ctx) -> Dictionary:
	var layout := ctx.layout
	var cfg: Dictionary = layout.build
	var db: Node = ctx.tree.root.get_node(^"Database")
	var sections: Array = []
	for s: Dictionary in layout.sections:
		var r: Array = s.rect
		var data: Resource = db.call(&"section", StringName(s.id))
		sections.append([int(data.get("order")), Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])])
	var blocked: Array[Dictionary] = []
	var ring: Array[Dictionary] = []
	var route: Array[Dictionary] = []
	var grave_ring := float(cfg.grave_ring)
	for p: Dictionary in layout.plots:
		var xf := {"pos": Ctx.v2(p.pos), "rot": float(p.rot_y)}
		blocked.append(_rect(xf, PLOT_RECT.merge(MARKER_RECT)))
		ring.append(_rect(xf, PLOT_RECT.merge(MARKER_RECT).grow(grave_ring)))
		var foot := Rect2(-0.72, PLOT_RECT.end.y, 1.44, float(cfg.grave_foot_strip))
		route.append(_rect(xf, foot))
	for g: Dictionary in layout.old_graves:
		var xf := {"pos": Ctx.v2(g.pos), "rot": float(g.rot_y)}
		blocked.append(_rect(xf, OLD_RECT))
		ring.append(_rect(xf, OLD_RECT.grow(grave_ring)))
	var bm := float(cfg.building_margin)
	var hut_def: Dictionary = layout.colliders["ph_bld_gravekeeper_hut"][0]
	blocked.append(_rect({"pos": Ctx.v2(layout.hut.pos), "rot": float(layout.hut.rot_y)}, _box_rect(hut_def).grow(bm)))
	var margin := float(cfg.station_margin)
	var access := float(cfg.station_access)
	for ent: Dictionary in layout.entities:
		var xf := {"pos": Ctx.v2(ent.pos), "rot": float(ent.rot_y)}
		var rect := Rect2()
		if ent.type == "hut_door":
			rect = DOOR_RECT
		else:
			var asset: String = Ctx.ENTITY_ASSETS.get(ent.type, (ent.params as Dictionary).get("model", ""))
			var defs: Array = layout.colliders.get(asset, [])
			if defs.is_empty() or (defs[0] as Dictionary).shape != "box":
				continue
			rect = _box_rect(defs[0])
		blocked.append(_rect(xf, rect.grow(margin)))
		route.append(_rect(xf, rect.grow(margin + access)))
	var tree_r := float(cfg.tree_radius)
	blocked.append({"c": Ctx.v2(layout.tree.pos), "r": tree_r * 1.3})
	for t: Dictionary in layout.background_trees + layout.forest.trees + layout.birches:
		blocked.append({"c": Ctx.v2(t.pos), "r": tree_r * float(t.get("scale", 1.0))})
	for b: Dictionary in layout.forest.bushes:
		blocked.append({"c": Ctx.v2(b.pos), "r": 0.5 * float(b.scale)})
	var fence_r := float(cfg.fence_half_width)
	for seg: Array in layout.fence.segments:
		blocked.append({"pts": [Ctx.v2(seg[0]), Ctx.v2(seg[1])], "r": fence_r})
	for r: Dictionary in layout.fence.ruins:
		var dir := Vector2(1, 0).rotated(-deg_to_rad(float(r.rot_y)))
		var c := Ctx.v2(r.pos)
		blocked.append({"pts": [c - dir * GAP_HALF, c + dir * GAP_HALF], "r": fence_r})
	for gp: Array in layout.fence.gate_posts:
		blocked.append({"c": Ctx.v2(gp), "r": 0.45})
	for pa: Dictionary in layout.fence.passages:
		var dir := Vector2(1, 0).rotated(-deg_to_rad(float(pa.rot_y)))
		var a := Ctx.v2(pa.pos)
		var w := float(pa.width)
		blocked.append({"c": a + dir * 0.17, "r": 0.4})
		blocked.append({"c": a + dir * (w - 0.17), "r": 0.4})
		# the way through the passage, 1.5 m on both sides of the fence line
		route.append(_rect({"pos": a, "rot": float(pa.rot_y)}, Rect2(0.0, -1.5, w, 3.0)))
	# Phase 5 (§4.1 V2): the workyard build sites like stations (footprint + margin blocked,
	# + access = ROUTE) and the charcoal kiln.
	var workyard: Dictionary = layout.get("workyard", {})
	for site: Dictionary in workyard.get("build_sites", []):
		var fp: Array = site.footprint
		var xf := {"pos": Ctx.v2(site.pos), "rot": float(site.rot_y)}
		var rect := Rect2(fp[0], fp[1], fp[2], fp[3])
		blocked.append(_rect(xf, rect.grow(margin)))
		route.append(_rect(xf, rect.grow(margin + access)))
	if workyard.has("meiler"):
		blocked.append({"c": Ctx.v2(workyard.meiler.pos), "r": float(workyard.meiler.radius) + margin})
	for lp: Dictionary in layout.lantern_posts:
		blocked.append({"c": Ctx.v2(lp.pos), "r": 0.35})
	for pr: Dictionary in layout.props:
		blocked.append({"c": Ctx.v2(pr.pos), "r": 0.5})
	# Phase 4 (§4.2): the props on the ground (wash basin, wall ledge) and the elder bushes.
	for pr: Dictionary in layout.get("phase4_props", []):
		if not pr.has("on"):
			blocked.append({"c": Ctx.v2(pr.pos), "r": 0.5})
	for b: Dictionary in layout.get("elder_bushes", []):
		blocked.append({"c": Ctx.v2(b.pos), "r": 0.6 * float(b.scale)})
	blocked.append({"c": Ctx.v2(layout.notice_board.pos), "r": 0.8})
	blocked.append({"c": Ctx.v2(layout.signpost.pos), "r": 0.35})
	var half := float(cfg.route_width) * 0.5
	route.append({"pts": _points(layout.path.points), "r": half})
	for pts: Array in _npc_routes(ctx):
		route.append({"pts": pts, "r": half})
	# Phase 4 (§4.2): the strip inside the west wall in front of Ilse's spot.
	if cfg.has("trader_access"):
		var ta: Array = cfg.trader_access
		route.append(_rect({"pos": Vector2.ZERO, "rot": 0.0}, Rect2(ta[0], ta[1], ta[2], ta[3])))
	# The hedge gap (access to the Birkenhang) stays a way once the hedge is gone.
	for c: Dictionary in layout.clearables:
		if c.kind in ["hedge", "gate_small", "gate_east"]:  # Phase 4 §4.2 / Phase 5 §4.2: the gates = ROUTE
			var fp: Array = c.footprint
			route.append(_rect({"pos": Ctx.v2(c.pos), "rot": float(c.rot_y)}, Rect2(fp[0], fp[1] - 0.5, fp[2], fp[3] + 1.0)))
	return {"sections": sections, "blocked": blocked, "ring": ring, "route": route}


## Mask byte of the cell with centre `p` (half = half cell: shapes grown by it ≈ the cell
## touches the shape).
static func mask_value(p: Vector2, half: float, shapes: Dictionary) -> int:
	var section := 0
	for s: Array in shapes.sections:
		if (s[1] as Rect2).has_point(p):
			section = int(s[0])
			break
	if section == 0:
		return 0
	for shape: Dictionary in shapes.blocked:
		if _hits(p, shape, half):
			return 0
	var value := section
	for shape: Dictionary in shapes.ring:
		if _hits(p, shape, 0.0):
			value |= 0x10  # BuildMask.GRAVE_RING
			break
	for shape: Dictionary in shapes.route:
		if _hits(p, shape, 0.0):
			value |= 0x20  # BuildMask.ROUTE
			break
	return value


static func _hits(p: Vector2, shape: Dictionary, grow: float) -> bool:
	if shape.has("rect"):
		var local := (p - (shape.pos as Vector2)).rotated(deg_to_rad(float(shape.rot)))
		return (shape.rect as Rect2).grow(grow).has_point(local)
	if shape.has("pts"):
		return _dist_to_polyline(p, shape.pts) < float(shape.r) + grow
	return p.distance_to(shape.c) < float(shape.r) + grow


static func _rect(xf: Dictionary, rect: Rect2) -> Dictionary:
	return {"pos": xf.pos, "rot": xf.rot, "rect": rect}


## XZ rect of a box collider def (local).
static func _box_rect(def: Dictionary) -> Rect2:
	var size := Ctx.v3(def.size)
	var off := Ctx.v3(def.offset)
	return Rect2(off.x - size.x * 0.5, off.z - size.z * 0.5, size.x, size.z)


static func _npc_routes(ctx: Ctx) -> Array:
	var layout := ctx.layout
	var routes: Array = []
	for ent: Dictionary in layout.entities:
		if ent.type != "npc":
			continue
		var sched: Resource = ctx.tree.root.get_node(^"Database").call(&"schedule", StringName(ent.params.npc_id))
		if sched == null:
			continue
		for e: Resource in sched.get("entries"):
			var path: PackedStringArray = e.get("path")
			if path.size() < 2:
				continue
			var pts: Array = []
			for id: String in path:
				pts.append(Ctx.v2(layout.waypoints[id]))
			routes.append(pts)
	return routes


static func _points(raw: Array) -> Array:
	var out: Array = []
	for p: Array in raw:
		out.append(Ctx.v2(p))
	return out


static func _dist_to_polyline(p: Vector2, pts: Array) -> float:
	var best := INF
	for k: int in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])))
	return best


static func _asset_of(scene: Variant) -> String:
	return (scene as PackedScene).resource_path.get_file().get_basename()
